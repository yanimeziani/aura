"""
trader_daemon.py — Persistent, steerable, logged algo trading daemon

Architecture:
  - Main thread: Unix socket server (IPC control interface)
  - Worker thread: trading loop (scan → signal → execute)
  - Shared state: protected by threading.Lock
  - Logging: rotating JSON + human-readable console

Control via: python trader_ctl.py <command>
Systemd: see aura-trader.service
"""

import json
import logging
import logging.handlers
import os
import signal
import socket
import sys
import threading
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path

import ccxt
from dotenv import load_dotenv

from quant_signals import CompositeSignalEngine, SentimentSignals
from quant_risk import RiskManager

load_dotenv()

# ─── PATHS ────────────────────────────────────────────────────────────────────

BASE_DIR    = Path(__file__).parent
SOCKET_PATH = BASE_DIR / "trader.sock"
LOG_DIR     = BASE_DIR / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE    = LOG_DIR / "trader.log"
TRADE_LOG   = LOG_DIR / "trades.jsonl"   # newline-delimited JSON, easy to grep
STATE_FILE  = BASE_DIR / "trader_state.json"
PID_FILE    = BASE_DIR / "trader.pid"

# ─── DEFAULTS (overridable at runtime via `set` command) ─────────────────────

DEFAULTS = {
    "capital":        float(os.getenv("TRADING_CAPITAL", "1000")),
    "min_confidence": 0.45,
    "scan_interval":  60,       # seconds
    "stop_loss_pct":  0.015,
    "take_profit_pct": 0.030,
    "max_risk_pct":   0.02,
    "max_drawdown":   0.05,
    "max_positions":  2,
    "max_age_hours":  6.0,
    "watchlist":      ["BTC/USDC", "ETH/USDC", "SOL/USDC", "AVAX/USDC"],
    "live":           False,
}

# ─── LOGGING ─────────────────────────────────────────────────────────────────

def setup_logging() -> logging.Logger:
    logger = logging.getLogger("aura.trader")
    logger.setLevel(logging.DEBUG)

    fmt_file    = logging.Formatter(
        '{"ts":"%(asctime)s","level":"%(levelname)s","msg":%(message)s}',
        datefmt="%Y-%m-%dT%H:%M:%SZ",
    )
    fmt_console = logging.Formatter(
        "%(asctime)s  %(levelname)-8s  %(message)s",
        datefmt="%H:%M:%S",
    )

    # Rotating file: 10 MB × 5 files
    fh = logging.handlers.RotatingFileHandler(
        LOG_FILE, maxBytes=10 * 1024 * 1024, backupCount=5, encoding="utf-8"
    )
    fh.setFormatter(fmt_file)
    fh.setLevel(logging.DEBUG)

    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(fmt_console)
    ch.setLevel(logging.INFO)

    logger.addHandler(fh)
    logger.addHandler(ch)
    return logger


def log_trade(record: dict):
    """Append a trade event to the JSONL trade log."""
    record["ts"] = datetime.now(timezone.utc).isoformat()
    with open(TRADE_LOG, "a") as f:
        f.write(json.dumps(record) + "\n")


# ─── SHARED STATE ─────────────────────────────────────────────────────────────

class DaemonState:
    """Thread-safe shared state for daemon + control interface."""

    def __init__(self):
        self._lock   = threading.Lock()
        self.cfg     = dict(DEFAULTS)
        self.paused  = False
        self.running = True
        self.cycle   = 0
        self.last_scan_ts: float = 0
        self.next_scan_ts: float = 0
        self.errors: list[str]   = []
        self.recent_signals: dict = {}   # symbol → last signal dict
        self.risk: RiskManager | None = None
        self.started_at = datetime.now(timezone.utc).isoformat()

    def with_lock(self, fn):
        with self._lock:
            return fn()

    def snapshot(self) -> dict:
        with self._lock:
            status = self.risk.status() if self.risk else {}
            positions = [
                {
                    "symbol": p.symbol,
                    "side":   p.side,
                    "entry":  p.entry_price,
                    "size":   p.size,
                    "sl":     p.stop_loss,
                    "tp":     p.take_profit,
                    "trail":  p.trailing_stop,
                    "age_h":  round(p.age_hours(), 2),
                }
                for p in (self.risk.positions if self.risk else [])
            ]
            return {
                "started_at":   self.started_at,
                "paused":       self.paused,
                "cycle":        self.cycle,
                "last_scan":    datetime.fromtimestamp(self.last_scan_ts).isoformat() if self.last_scan_ts else None,
                "next_scan":    datetime.fromtimestamp(self.next_scan_ts).isoformat() if self.next_scan_ts else None,
                "cfg":          self.cfg,
                "risk":         status,
                "positions":    positions,
                "signals":      self.recent_signals,
                "last_errors":  self.errors[-5:],
            }

    def set_param(self, key: str, value) -> tuple[bool, str]:
        with self._lock:
            if key not in self.cfg:
                return False, f"Unknown param '{key}'. Valid: {list(self.cfg)}"
            old = self.cfg[key]
            try:
                # Cast to same type as default
                typed = type(DEFAULTS[key])(value)
                self.cfg[key] = typed
                return True, f"{key}: {old} → {typed}"
            except (ValueError, TypeError) as e:
                return False, f"Type error: {e}"

    def record_error(self, msg: str):
        with self._lock:
            self.errors.append(f"{datetime.now().strftime('%H:%M:%S')} {msg}")
            if len(self.errors) > 50:
                self.errors = self.errors[-50:]


# ─── TRADING WORKER ───────────────────────────────────────────────────────────

class TradingWorker(threading.Thread):
    """Background thread: runs the trading loop."""

    def __init__(self, state: DaemonState, logger: logging.Logger):
        super().__init__(name="TradingWorker", daemon=True)
        self.state  = state
        self.log    = logger
        self._force_scan = threading.Event()

    def force_scan(self):
        """Signal an immediate scan cycle."""
        self._force_scan.set()

    def _init_components(self):
        cfg = self.state.cfg
        api_key    = os.getenv("COINBASE_API_KEY")
        api_secret = os.getenv("COINBASE_API_SECRET")

        if api_key and api_secret:
            exchange = ccxt.coinbaseadvanced({
                "apiKey": api_key, "secret": api_secret,
                "enableRateLimit": True,
            })
        else:
            self.log.warning('"No Coinbase API keys — offline paper mode"')
            exchange = None

        risk = RiskManager(
            capital         = cfg["capital"],
            max_risk_pct    = cfg["max_risk_pct"],
            stop_loss_pct   = cfg["stop_loss_pct"],
            take_profit_pct = cfg["take_profit_pct"],
            max_drawdown    = cfg["max_drawdown"],
            max_positions   = cfg["max_positions"],
            max_age_hours   = cfg["max_age_hours"],
        )
        self.state.risk = risk
        return exchange, risk, CompositeSignalEngine(exchange) if exchange else None

    def _current_price(self, exchange, symbol: str) -> float:
        if not exchange:
            return 0.0
        try:
            t = exchange.fetch_ticker(symbol)
            return float(t.get("last") or 0)
        except Exception:
            return 0.0

    def _execute_order(self, exchange, symbol: str, side: str,
                        size: float, price: float):
        live = self.state.cfg["live"]
        tag  = "LIVE" if live else "PAPER"
        self.log.info(f'"{tag} {side} {size:.6f} {symbol} @ {price:.4f}"')
        if live and exchange:
            try:
                exchange.create_market_order(symbol, side.lower(), size)
            except Exception as e:
                self.log.error(f'"Order failed: {e}"')
                self.state.record_error(f"Order {side} {symbol}: {e}")

    def _check_day_reset(self, risk: RiskManager):
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        if risk.daily.date and risk.daily.date != today:
            self.log.info(f'"New day — resetting daily stats"')
            risk.reset_daily()

    def run(self):
        self.log.info('"Trading worker started"')
        exchange, risk, signals = self._init_components()

        while self.state.running:
            try:
                # Wait for interval or forced scan
                interval = self.state.cfg["scan_interval"]
                self.state.next_scan_ts = time.time() + interval
                triggered = self._force_scan.wait(timeout=interval)
                if triggered:
                    self._force_scan.clear()
                    self.log.info('"Forced scan triggered"')

                if not self.state.running:
                    break

                if self.state.paused:
                    self.log.debug('"Paused — skipping cycle"')
                    continue

                self._run_cycle(exchange, risk, signals)

            except Exception as e:
                msg = f"Worker exception: {e}\n{traceback.format_exc()}"
                self.log.error(f'"{msg}"')
                self.state.record_error(str(e))
                time.sleep(5)

        self.log.info('"Trading worker stopped"')

    def _run_cycle(self, exchange, risk: RiskManager,
                    signals: CompositeSignalEngine | None):
        cfg = self.state.cfg
        self._check_day_reset(risk)

        with self.state._lock:
            self.state.cycle += 1
            cycle = self.state.cycle
            self.state.last_scan_ts = time.time()

        fng = SentimentSignals.fear_and_greed()
        st  = risk.status()

        self.log.info(
            f'"cycle={cycle} capital={st["capital"]:.2f} '
            f'daily_pnl={st["daily_pnl"]:+.2f} '
            f'positions={st["open_positions"]} '
            f'fng={fng["value"]} heat={st["portfolio_heat_pct"]}%"'
        )

        # ── Exits ─────────────────────────────────────────────────
        for pos in risk.positions[:]:
            price = self._current_price(exchange, pos.symbol)
            if not price:
                continue
            reason = risk.check_exit(pos, price)
            if reason:
                closed = risk.close_position(pos, price, reason)
                exit_side = "SELL" if pos.side == "BUY" else "BUY"
                self._execute_order(exchange, pos.symbol, exit_side, pos.size, price)
                log_trade({**closed, "event": "EXIT"})
                self.log.info(
                    f'"EXIT {pos.symbol} [{reason}] '
                    f'pnl={closed["pnl_usd"]:+.4f} '
                    f'pnl_pct={closed["pnl_pct"]:+.3f}%"'
                )

        # ── Circuit breaker ───────────────────────────────────────
        can_trade, cb_reason = risk.can_trade()
        if not can_trade:
            self.log.warning(f'"Circuit breaker: {cb_reason}"')
            return

        if not signals:
            return

        # ── Entries ───────────────────────────────────────────────
        held = {p.symbol for p in risk.positions}
        for symbol in cfg["watchlist"]:
            if symbol in held:
                continue
            can_trade, _ = risk.can_trade()
            if not can_trade:
                break

            try:
                sig = signals.analyze(symbol)
            except Exception as e:
                self.log.error(f'"Signal error {symbol}: {e}"')
                continue

            sig_dict = {
                "direction":  sig.direction,
                "confidence": sig.confidence,
                "score":      sig.score,
                "regime":     sig.regime,
                "reasons":    sig.reasons[:5],
            }
            with self.state._lock:
                self.state.recent_signals[symbol] = sig_dict

            self.log.debug(
                f'"{symbol} {sig.direction} conf={sig.confidence:.2f} '
                f'regime={sig.regime} score={sig.score:+.4f}"'
            )

            if (sig.direction in ("BUY", "SELL")
                    and sig.confidence >= cfg["min_confidence"]):
                price = self._current_price(exchange, symbol)
                if not price:
                    continue
                pos = risk.open_position(symbol, sig.direction, price, sig.confidence)
                self._execute_order(exchange, symbol, sig.direction, pos.size, price)
                log_trade({
                    "event":      "ENTER",
                    "symbol":     symbol,
                    "side":       sig.direction,
                    "price":      price,
                    "size":       pos.size,
                    "sl":         pos.stop_loss,
                    "tp":         pos.take_profit,
                    "confidence": sig.confidence,
                    "regime":     sig.regime,
                    "score":      sig.score,
                })
                self.log.info(
                    f'"ENTER {sig.direction} {symbol} @ {price:.4f} '
                    f'size={pos.size:.6f} sl={pos.stop_loss:.4f} '
                    f'tp={pos.take_profit:.4f} conf={sig.confidence:.2f}"'
                )

        # ── Persist state ─────────────────────────────────────────
        try:
            snap = self.state.snapshot()
            with open(STATE_FILE, "w") as f:
                json.dump(snap, f, indent=2, default=str)
        except Exception as e:
            self.log.debug(f'"State persist error: {e}"')


# ─── CONTROL SERVER (Unix socket) ─────────────────────────────────────────────

class ControlServer(threading.Thread):
    """
    Listens on a Unix domain socket for control commands.
    Protocol: newline-terminated JSON  → newline-terminated JSON response.
    """

    def __init__(self, state: DaemonState, worker: TradingWorker,
                  logger: logging.Logger):
        super().__init__(name="ControlServer", daemon=True)
        self.state  = state
        self.worker = worker
        self.log    = logger

    def run(self):
        if SOCKET_PATH.exists():
            SOCKET_PATH.unlink()

        srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        srv.bind(str(SOCKET_PATH))
        srv.listen(5)
        SOCKET_PATH.chmod(0o600)
        self.log.info(f'"Control socket: {SOCKET_PATH}"')

        while self.state.running:
            try:
                srv.settimeout(1.0)
                try:
                    conn, _ = srv.accept()
                except socket.timeout:
                    continue
                threading.Thread(
                    target=self._handle,
                    args=(conn,),
                    daemon=True,
                ).start()
            except Exception as e:
                if self.state.running:
                    self.log.error(f'"Control server error: {e}"')

        srv.close()
        if SOCKET_PATH.exists():
            SOCKET_PATH.unlink()

    def _handle(self, conn: socket.socket):
        try:
            data = b""
            conn.settimeout(5.0)
            while not data.endswith(b"\n"):
                chunk = conn.recv(4096)
                if not chunk:
                    break
                data += chunk

            if not data:
                return

            try:
                cmd = json.loads(data.decode().strip())
            except json.JSONDecodeError:
                self._reply(conn, {"ok": False, "error": "Invalid JSON"})
                return

            response = self._dispatch(cmd)
            self._reply(conn, response)

        except Exception as e:
            self.log.debug(f'"Control handler error: {e}"')
        finally:
            conn.close()

    def _reply(self, conn: socket.socket, data: dict):
        try:
            conn.sendall((json.dumps(data, default=str) + "\n").encode())
        except Exception:
            pass

    def _dispatch(self, cmd: dict) -> dict:
        action = cmd.get("action", "").lower()
        self.log.debug(f'"Control command: {action}"')

        if action == "status":
            return {"ok": True, "data": self.state.snapshot()}

        elif action == "pause":
            self.state.paused = True
            self.log.info('"Trading paused via control"')
            return {"ok": True, "msg": "Trading paused"}

        elif action == "resume":
            self.state.paused = False
            self.log.info('"Trading resumed via control"')
            return {"ok": True, "msg": "Trading resumed"}

        elif action == "scan":
            self.worker.force_scan()
            return {"ok": True, "msg": "Forced scan triggered"}

        elif action == "stop":
            self.log.info('"Stop command received"')
            self.state.running = False
            return {"ok": True, "msg": "Daemon stopping…"}

        elif action == "set":
            key   = cmd.get("key", "")
            value = cmd.get("value")
            ok, msg = self.state.set_param(key, value)
            if ok:
                self.log.info(f'"Config changed: {msg}"')
            return {"ok": ok, "msg": msg}

        elif action == "close":
            symbol = cmd.get("symbol", "").upper()
            return self._force_close(symbol)

        elif action == "positions":
            if not self.state.risk:
                return {"ok": True, "data": []}
            with self.state._lock:
                positions = [
                    {
                        "symbol": p.symbol,
                        "side":   p.side,
                        "entry":  p.entry_price,
                        "size":   p.size,
                        "sl":     p.stop_loss,
                        "tp":     p.take_profit,
                        "trail":  p.trailing_stop,
                        "age_h":  round(p.age_hours(), 2),
                    }
                    for p in self.state.risk.positions
                ]
            return {"ok": True, "data": positions}

        elif action == "log":
            n = int(cmd.get("n", 50))
            return {"ok": True, "data": self._tail_log(n)}

        elif action == "trades":
            n = int(cmd.get("n", 20))
            return {"ok": True, "data": self._tail_trades(n)}

        elif action == "signals":
            with self.state._lock:
                return {"ok": True, "data": self.state.recent_signals}

        elif action == "ping":
            return {"ok": True, "msg": "pong", "cycle": self.state.cycle}

        else:
            return {
                "ok": False,
                "error": f"Unknown action '{action}'",
                "actions": [
                    "status", "pause", "resume", "scan", "stop",
                    "set", "close", "positions", "log", "trades",
                    "signals", "ping",
                ],
            }

    def _force_close(self, symbol: str) -> dict:
        risk = self.state.risk
        if not risk:
            return {"ok": False, "error": "Risk manager not initialized"}
        with self.state._lock:
            pos = next((p for p in risk.positions if p.symbol == symbol), None)
        if not pos:
            return {"ok": False, "error": f"No open position for {symbol}"}
        # Use last known price from state
        sig = self.state.recent_signals.get(symbol, {})
        price = sig.get("indicators", {}).get("price", pos.entry_price)
        closed = risk.close_position(pos, price, "MANUAL_CLOSE")
        log_trade({**closed, "event": "MANUAL_CLOSE"})
        self.log.info(f'"MANUAL CLOSE {symbol} pnl={closed["pnl_usd"]:+.4f}"')
        return {"ok": True, "data": closed}

    def _tail_log(self, n: int) -> list[str]:
        try:
            lines = LOG_FILE.read_text().splitlines()
            return lines[-n:]
        except Exception:
            return []

    def _tail_trades(self, n: int) -> list[dict]:
        try:
            lines = TRADE_LOG.read_text().splitlines()
            return [json.loads(l) for l in lines[-n:] if l]
        except Exception:
            return []


# ─── DAEMON MAIN ──────────────────────────────────────────────────────────────

def main():
    logger = setup_logging()
    state  = DaemonState()

    # Write PID file
    PID_FILE.write_text(str(os.getpid()))
    logger.info(f'"Daemon started pid={os.getpid()} live={state.cfg["live"]}"')

    worker = TradingWorker(state, logger)
    server = ControlServer(state, worker, logger)

    def shutdown(sig, frame):
        logger.info(f'"Signal {sig} received — shutting down"')
        state.running = False

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT,  shutdown)

    worker.start()
    server.start()

    # Keep main thread alive
    while state.running:
        time.sleep(0.5)

    # Cleanup
    logger.info('"Daemon stopped"')
    if PID_FILE.exists():
        PID_FILE.unlink()


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Aura Trader Daemon")
    parser.add_argument("--live",     action="store_true")
    parser.add_argument("--capital",  type=float, default=None)
    parser.add_argument("--interval", type=int,   default=None)
    args = parser.parse_args()

    if args.live:
        DEFAULTS["live"] = True
    if args.capital:
        DEFAULTS["capital"] = args.capital
    if args.interval:
        DEFAULTS["scan_interval"] = args.interval

    main()
