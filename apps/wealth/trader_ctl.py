"""
trader_ctl.py — Control CLI for the trader daemon

Usage:
  python trader_ctl.py status
  python trader_ctl.py pause
  python trader_ctl.py resume
  python trader_ctl.py scan
  python trader_ctl.py stop
  python trader_ctl.py signals
  python trader_ctl.py positions
  python trader_ctl.py close BTC/USDC
  python trader_ctl.py set min_confidence 0.5
  python trader_ctl.py set scan_interval 30
  python trader_ctl.py set capital 2000
  python trader_ctl.py set live true
  python trader_ctl.py set watchlist '["BTC/USDC","ETH/USDC"]'
  python trader_ctl.py log [N]
  python trader_ctl.py trades [N]
  python trader_ctl.py ping
  python trader_ctl.py watch          # live status refresh every 5s
"""

import json
import socket
import sys
import time
from pathlib import Path

SOCKET_PATH = Path(__file__).parent / "trader.sock"
TIMEOUT     = 10.0


# ─── TRANSPORT ────────────────────────────────────────────────────────────────

def send(payload: dict) -> dict:
    if not SOCKET_PATH.exists():
        print("✗  Daemon is not running (no socket found).")
        print(f"   Expected: {SOCKET_PATH}")
        print("   Start with: python trader_daemon.py")
        sys.exit(1)
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(TIMEOUT)
        sock.connect(str(SOCKET_PATH))
        sock.sendall((json.dumps(payload) + "\n").encode())
        data = b""
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            data += chunk
            if data.endswith(b"\n"):
                break
        sock.close()
        return json.loads(data.decode().strip())
    except ConnectionRefusedError:
        print("✗  Daemon refused connection.")
        sys.exit(1)
    except socket.timeout:
        print("✗  Daemon did not respond in time.")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"✗  Bad response from daemon: {e}")
        sys.exit(1)


# ─── FORMATTERS ───────────────────────────────────────────────────────────────

C_RESET  = "\033[0m"
C_BOLD   = "\033[1m"
C_GREEN  = "\033[32m"
C_RED    = "\033[31m"
C_YELLOW = "\033[33m"
C_CYAN   = "\033[36m"
C_DIM    = "\033[2m"

def _c(text, color): return f"{color}{text}{C_RESET}"


def fmt_status(data: dict):
    risk = data.get("risk", {})
    cfg  = data.get("cfg", {})
    pos  = data.get("positions", [])
    sigs = data.get("signals", {})
    errs = data.get("last_errors", [])

    paused = data.get("paused", False)
    mode   = _c("PAPER", C_YELLOW) if not cfg.get("live") else _c("LIVE", C_RED + C_BOLD)
    state  = _c("PAUSED", C_YELLOW) if paused else _c("RUNNING", C_GREEN)

    print(f"\n{C_BOLD}{'━'*65}{C_RESET}")
    print(f"  {C_BOLD}AURA TRADER DAEMON{C_RESET}  [{mode}]  [{state}]")
    print(f"  Started : {data.get('started_at','?')}")
    print(f"  Cycle   : {data.get('cycle', 0)}  |  "
          f"Last scan: {data.get('last_scan','—')}  |  "
          f"Next: {data.get('next_scan','—')}")
    print(f"{'━'*65}")

    print(f"\n  {C_BOLD}Portfolio{C_RESET}")
    cap     = risk.get("capital", 0)
    at_pnl  = risk.get("all_time_pnl", 0)
    day_pnl = risk.get("daily_pnl", 0)
    heat    = risk.get("portfolio_heat_pct", 0)
    wr      = risk.get("win_rate", 0)
    sharpe  = risk.get("sharpe", 0)

    pnl_color = C_GREEN if at_pnl >= 0 else C_RED
    print(f"    Capital      : ${cap:>10,.2f}")
    print(f"    All-time PnL : {_c(f'${at_pnl:+,.2f}', pnl_color)}")
    print(f"    Today PnL    : {_c(f'${day_pnl:+,.2f}', C_GREEN if day_pnl>=0 else C_RED)}")
    print(f"    Heat         : {heat:.1f}%  |  Win rate: {wr:.1f}%  |  Sharpe: {sharpe:.4f}")
    cb = risk.get("circuit_open", False)
    if cb:
        print(f"    {_c('⚠  CIRCUIT BREAKER OPEN', C_RED + C_BOLD)}")

    print(f"\n  {C_BOLD}Config{C_RESET}")
    for k, v in cfg.items():
        print(f"    {k:<20} {v}")

    if pos:
        print(f"\n  {C_BOLD}Open Positions ({len(pos)}){C_RESET}")
        for p in pos:
            pnl_est = "—"
            side_c = C_GREEN if p["side"] == "BUY" else C_RED
            print(
                f"    {_c(p['symbol'], C_CYAN)}  {_c(p['side'], side_c)}  "
                f"entry=${p['entry']:.4f}  "
                f"sl=${p['sl']:.4f}  tp=${p['tp']:.4f}  "
                f"trail=${p['trail']:.4f}  "
                f"age={p['age_h']:.1f}h"
            )
    else:
        print(f"\n  {C_DIM}No open positions{C_RESET}")

    if sigs:
        print(f"\n  {C_BOLD}Last Signals{C_RESET}")
        for sym, s in sigs.items():
            dir_c = C_GREEN if s["direction"] == "BUY" else (
                    C_RED if s["direction"] == "SELL" else C_DIM)
            print(
                f"    {_c(sym, C_CYAN):20s}  {_c(s['direction'], dir_c):6s}  "
                f"conf={s['confidence']:.2f}  score={s['score']:+.4f}  "
                f"regime={s['regime']}"
            )

    if errs:
        print(f"\n  {C_BOLD}{_c('Recent Errors', C_RED)}{C_RESET}")
        for e in errs:
            print(f"    {C_DIM}{e}{C_RESET}")

    print(f"\n{'━'*65}\n")


def fmt_positions(data: list):
    if not data:
        print("  No open positions.")
        return
    print(f"\n  {'Symbol':<14} {'Side':<6} {'Entry':>10} {'SL':>10} {'TP':>10} {'Trail':>10} {'Age':>6}")
    print(f"  {'─'*14} {'─'*6} {'─'*10} {'─'*10} {'─'*10} {'─'*10} {'─'*6}")
    for p in data:
        side_c = C_GREEN if p["side"] == "BUY" else C_RED
        print(
            f"  {_c(p['symbol'],''):<14} "
            f"{_c(p['side'], side_c):<6}  "
            f"${p['entry']:>9.4f}  "
            f"${p['sl']:>9.4f}  "
            f"${p['tp']:>9.4f}  "
            f"${p['trail']:>9.4f}  "
            f"{p['age_h']:>4.1f}h"
        )
    print()


def fmt_signals(data: dict):
    if not data:
        print("  No signals yet.")
        return
    print()
    for sym, s in data.items():
        dir_c = C_GREEN if s["direction"] == "BUY" else (
                C_RED if s["direction"] == "SELL" else C_DIM)
        print(
            f"  {_c(sym, C_CYAN):<15}  {_c(s['direction'], dir_c):<8}  "
            f"conf={s['confidence']:.2f}  score={s['score']:+.4f}  "
            f"regime={s['regime']}"
        )
        for r in s.get("reasons", []):
            print(f"    {C_DIM}• {r}{C_RESET}")
    print()


def fmt_trades(data: list):
    if not data:
        print("  No trades recorded yet.")
        return
    print()
    for t in data:
        event = t.get("event", "?")
        sym   = t.get("symbol", "?")
        side  = t.get("side", "?")
        price = t.get("price") or t.get("exit", 0)
        pnl   = t.get("pnl_usd", 0)
        pnl_s = f"{pnl:+.4f}" if pnl else ""
        ts    = t.get("ts", "")[:19]
        pnl_c = C_GREEN if pnl > 0 else (C_RED if pnl < 0 else C_DIM)
        print(
            f"  {C_DIM}{ts}{C_RESET}  "
            f"{_c(event, C_BOLD):<14}  "
            f"{_c(sym, C_CYAN):<14}  "
            f"{side:<5}  "
            f"${price:<12.4f}  "
            f"{_c(pnl_s, pnl_c)}"
        )
    print()


# ─── WATCH MODE ───────────────────────────────────────────────────────────────

def watch(interval: int = 5):
    print(f"Watching daemon (refresh every {interval}s) — Ctrl+C to exit\n")
    try:
        while True:
            print("\033[2J\033[H", end="")   # clear screen
            resp = send({"action": "status"})
            if resp.get("ok"):
                fmt_status(resp["data"])
            else:
                print(f"Error: {resp.get('error')}")
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\nWatch stopped.")


# ─── CLI ──────────────────────────────────────────────────────────────────────

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(0)

    action = args[0].lower()

    # ── Simple actions ────────────────────────────────────────
    if action in ("ping", "pause", "resume", "scan", "stop"):
        resp = send({"action": action})
        if resp.get("ok"):
            print(f"✓  {resp.get('msg', 'OK')}")
            if "cycle" in resp:
                print(f"   Cycle: {resp['cycle']}")
        else:
            print(f"✗  {resp.get('error', 'Unknown error')}")

    # ── Status ────────────────────────────────────────────────
    elif action == "status":
        resp = send({"action": "status"})
        if resp.get("ok"):
            fmt_status(resp["data"])
        else:
            print(f"✗  {resp.get('error')}")

    # ── Positions ─────────────────────────────────────────────
    elif action == "positions":
        resp = send({"action": "positions"})
        if resp.get("ok"):
            fmt_positions(resp["data"])
        else:
            print(f"✗  {resp.get('error')}")

    # ── Signals ───────────────────────────────────────────────
    elif action == "signals":
        resp = send({"action": "signals"})
        if resp.get("ok"):
            fmt_signals(resp["data"])
        else:
            print(f"✗  {resp.get('error')}")

    # ── Close position ────────────────────────────────────────
    elif action == "close":
        if len(args) < 2:
            print("Usage: python trader_ctl.py close <SYMBOL>")
            sys.exit(1)
        symbol = args[1].upper()
        resp = send({"action": "close", "symbol": symbol})
        if resp.get("ok"):
            d = resp["data"]
            pnl_c = C_GREEN if d.get("pnl_usd", 0) > 0 else C_RED
            pnl_val = d.get("pnl_usd", 0)
            print(f"✓  Closed {symbol}  PnL: {_c(f'{pnl_val:+.4f}', pnl_c)}")
        else:
            print(f"✗  {resp.get('error')}")

    # ── Set param ─────────────────────────────────────────────
    elif action == "set":
        if len(args) < 3:
            print("Usage: python trader_ctl.py set <key> <value>")
            sys.exit(1)
        key   = args[1]
        value = args[2]
        # Try to parse JSON for complex values (lists, booleans)
        try:
            value = json.loads(value)
        except (json.JSONDecodeError, ValueError):
            pass
        resp = send({"action": "set", "key": key, "value": value})
        if resp.get("ok"):
            print(f"✓  {resp.get('msg')}")
        else:
            print(f"✗  {resp.get('msg') or resp.get('error')}")

    # ── Log tail ──────────────────────────────────────────────
    elif action == "log":
        n = int(args[1]) if len(args) > 1 else 50
        resp = send({"action": "log", "n": n})
        if resp.get("ok"):
            for line in resp["data"]:
                print(line)
        else:
            print(f"✗  {resp.get('error')}")

    # ── Trade history ─────────────────────────────────────────
    elif action == "trades":
        n = int(args[1]) if len(args) > 1 else 20
        resp = send({"action": "trades", "n": n})
        if resp.get("ok"):
            fmt_trades(resp["data"])
        else:
            print(f"✗  {resp.get('error')}")

    # ── Watch mode ────────────────────────────────────────────
    elif action == "watch":
        interval = int(args[1]) if len(args) > 1 else 5
        watch(interval)

    else:
        print(f"Unknown command: {action}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
