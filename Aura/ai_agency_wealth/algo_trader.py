"""
algo_trader.py — Aura Quant Orchestrator
Multi-signal momentum + regime detection + Kelly sizing + trailing stops

Run modes:
  python algo_trader.py              # paper trading (safe, default)
  python algo_trader.py --live       # LIVE — requires tested strategy
  python algo_trader.py --scan       # one-shot signal scan, no trading
"""

import argparse
import json
import os
import time
import signal
import sys
from datetime import datetime, timezone

import ccxt
from dotenv import load_dotenv

from quant_signals import CompositeSignalEngine, SentimentSignals
from quant_risk import RiskManager

load_dotenv()

# ─── CONFIG ───────────────────────────────────────────────────────────────────

WATCHLIST = [
    "BTC/USDC",
    "ETH/USDC",
    "SOL/USDC",
    "AVAX/USDC",
]

CAPITAL          = float(os.getenv("TRADING_CAPITAL", "1000"))
SCAN_INTERVAL_S  = 60       # seconds between scans
MIN_CONFIDENCE   = 0.45     # minimum signal confidence to enter
STOP_LOSS_PCT    = 0.015
TAKE_PROFIT_PCT  = 0.030
MAX_RISK_PCT     = 0.02
MAX_DRAWDOWN     = 0.05
MAX_POSITIONS    = 2
MAX_AGE_HOURS    = 6.0


# ─── EXCHANGE ─────────────────────────────────────────────────────────────────

def init_exchange(live: bool) -> ccxt.Exchange:
    api_key    = os.getenv("COINBASE_API_KEY")
    api_secret = os.getenv("COINBASE_API_SECRET")

    if not api_key or not api_secret:
        print("⚠  No Coinbase API keys found — running in OFFLINE PAPER mode")
        # Return a minimal mock
        class MockExchange:
            rateLimit = 1000
            def fetch_ohlcv(self, *a, **kw):  return []
            def fetch_order_book(self, *a, **kw): return {"bids":[], "asks":[]}
            def fetch_ticker(self, *a, **kw): return {}
            def create_market_order(self, *a, **kw): pass
        return MockExchange()

    ex = ccxt.coinbaseadvanced({
        "apiKey": api_key,
        "secret": api_secret,
        "enableRateLimit": True,
    })
    return ex


# ─── TRADER ───────────────────────────────────────────────────────────────────

class AlgoTrader:

    def __init__(self, live: bool = False):
        self.live      = live
        self.exchange  = init_exchange(live)
        self.signals   = CompositeSignalEngine(self.exchange)
        self.risk      = RiskManager(
            capital=CAPITAL,
            max_risk_pct=MAX_RISK_PCT,
            stop_loss_pct=STOP_LOSS_PCT,
            take_profit_pct=TAKE_PROFIT_PCT,
            max_drawdown=MAX_DRAWDOWN,
            max_positions=MAX_POSITIONS,
            max_age_hours=MAX_AGE_HOURS,
        )
        self.trade_log: list[dict] = []
        self.cycle      = 0

        # Graceful shutdown
        signal.signal(signal.SIGINT,  self._shutdown)
        signal.signal(signal.SIGTERM, self._shutdown)

    # ── Execution ─────────────────────────────────────────────────────────────

    def _execute(self, symbol: str, side: str, size: float, price: float):
        tag = "[LIVE]" if self.live else "[PAPER]"
        print(f"  {tag} {side:4s} {size:.6f} {symbol} @ ${price:,.4f}")
        if self.live:
            try:
                self.exchange.create_market_order(symbol, side.lower(), size)
            except Exception as e:
                print(f"  ⚠ Order failed: {e}")

    def _log(self, action: str, symbol: str, price: float, size: float,
              pnl: float = 0.0, detail: str = ""):
        entry = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "action": action, "symbol": symbol,
            "price": round(price, 4), "size": round(size, 6),
            "pnl_usd": round(pnl, 4), "detail": detail,
        }
        self.trade_log.append(entry)

    # ── Price fetcher ─────────────────────────────────────────────────────────

    def _current_price(self, symbol: str) -> float:
        try:
            t = self.exchange.fetch_ticker(symbol)
            return float(t.get("last", 0) or 0)
        except Exception:
            return 0.0

    # ── Daily reset check ─────────────────────────────────────────────────────

    def _check_day_reset(self):
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        if self.risk.daily.date and self.risk.daily.date != today:
            print(f"\n  New day detected — resetting daily stats (was {self.risk.daily.date})")
            self.risk.reset_daily()

    # ── Main cycle ────────────────────────────────────────────────────────────

    def run_cycle(self):
        self.cycle += 1
        self._check_day_reset()

        fng = SentimentSignals.fear_and_greed()
        status = self.risk.status()

        print(f"\n{'─'*65}")
        print(
            f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}]  "
            f"Cycle #{self.cycle}  |  "
            f"Capital=${status['capital']:,.2f}  |  "
            f"PnL today=${status['daily_pnl']:+.2f}  |  "
            f"F&G={fng['value']} ({fng['label']})  |  "
            f"Heat={status['portfolio_heat_pct']}%"
        )

        # ── 1. Process exits ──────────────────────────────────────
        for pos in self.risk.positions[:]:
            price = self._current_price(pos.symbol)
            if not price:
                continue

            exit_reason = self.risk.check_exit(pos, price)
            if exit_reason:
                closed = self.risk.close_position(pos, price, exit_reason)
                exit_side = "SELL" if pos.side == "BUY" else "BUY"
                self._execute(pos.symbol, exit_side, pos.size, price)
                self._log("EXIT", pos.symbol, price, pos.size,
                           pnl=closed["pnl_usd"],
                           detail=f"{exit_reason} | {closed['pnl_pct']:+.2f}%")
                icon = "✅" if closed["pnl_usd"] > 0 else "❌"
                print(
                    f"  {icon} CLOSED {pos.symbol} [{exit_reason}]  "
                    f"PnL=${closed['pnl_usd']:+.2f} ({closed['pnl_pct']:+.3f}%)  "
                    f"held {closed['age_h']:.1f}h"
                )

        # ── 2. Check circuit breaker ──────────────────────────────
        can_trade, reason = self.risk.can_trade()
        if not can_trade:
            print(f"  🛑 {reason}")
            return

        # ── 3. Scan for entries ───────────────────────────────────
        held = {p.symbol for p in self.risk.positions}
        for symbol in WATCHLIST:
            if symbol in held:
                continue

            can_trade, reason = self.risk.can_trade()
            if not can_trade:
                break

            sig = self.signals.analyze(symbol)
            ind = sig.indicators

            print(
                f"  {symbol:12s} | {sig.direction:4s} conf={sig.confidence:.2f}  "
                f"regime={sig.regime:8s}  score={sig.score:+.3f}  "
                f"RSI={ind.get('rsi',0):.1f}  ADX={ind.get('adx',0):.1f}"
            )
            for r in sig.reasons[:3]:  # top 3 reasons
                print(f"               → {r}")

            if sig.direction in ("BUY", "SELL") and sig.confidence >= MIN_CONFIDENCE:
                price = self._current_price(symbol)
                if not price:
                    continue

                pos = self.risk.open_position(symbol, sig.direction, price, sig.confidence)
                self._execute(symbol, sig.direction, pos.size, price)
                self._log(
                    f"OPEN_{sig.direction}", symbol, price, pos.size,
                    detail=(
                        f"conf={sig.confidence:.2f} regime={sig.regime} "
                        f"SL={pos.stop_loss:.4f} TP={pos.take_profit:.4f}"
                    )
                )
                print(
                    f"  🎯 ENTERED {sig.direction} {symbol} @ ${price:,.4f}  "
                    f"size={pos.size:.6f}  SL=${pos.stop_loss:,.4f}  "
                    f"TP=${pos.take_profit:,.4f}"
                )

        # ── 4. Report open positions ──────────────────────────────
        if self.risk.positions:
            print(f"\n  Open positions ({len(self.risk.positions)}):")
            for p in self.risk.positions:
                price = self._current_price(p.symbol)
                upnl  = p.unrealized_pnl(price) if price else 0
                print(
                    f"    {p.symbol} {p.side:4s} "
                    f"entry=${p.entry_price:,.4f}  now=${price:,.4f}  "
                    f"uPnL=${upnl:+.2f}  age={p.age_hours():.1f}h  "
                    f"trail=${p.trailing_stop:,.4f}"
                )

    # ── Save & Shutdown ───────────────────────────────────────────────────────

    def save_log(self):
        with open("trade_log.json", "w") as f:
            json.dump(self.trade_log, f, indent=2)

    def print_summary(self):
        st = self.risk.status()
        print(f"\n{'═'*65}")
        print(f"  SESSION SUMMARY")
        print(f"{'═'*65}")
        print(f"  Capital       : ${st['capital']:,.2f}")
        print(f"  All-time PnL  : ${st['all_time_pnl']:+,.2f}")
        print(f"  Today PnL     : ${st['daily_pnl']:+,.2f}")
        print(f"  Trades today  : {st['daily_trades']}")
        print(f"  Win rate      : {st['win_rate']:.1f}%")
        print(f"  Sharpe        : {st['sharpe']:.4f}")
        print(f"  Expectancy    : {st['expectancy']:.4f}")
        print(f"  Circuit open  : {st['circuit_open']}")
        print(f"{'═'*65}")

    def _shutdown(self, *_):
        print("\n\nShutting down gracefully…")
        self.print_summary()
        self.save_log()
        print("Trade log saved to trade_log.json")
        sys.exit(0)


# ─── SCAN MODE (one-shot, no trading) ────────────────────────────────────────

def run_scan():
    exchange = init_exchange(live=False)
    engine   = CompositeSignalEngine(exchange)
    fng      = SentimentSignals.fear_and_greed()
    dom      = SentimentSignals.btc_dominance()

    print(f"\n{'═'*65}")
    print(f"  MARKET SCAN  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Fear & Greed : {fng['value']} ({fng['label']}) Δ={fng['delta']:+d}")
    print(f"  BTC Dominance: {dom}%")
    print(f"{'═'*65}")

    for symbol in WATCHLIST:
        print(f"\n  {symbol}")
        sig = engine.analyze(symbol)
        ind = sig.indicators
        print(f"    Signal     : {sig.direction} (confidence={sig.confidence:.2f}, score={sig.score:+.4f})")
        print(f"    Regime     : {sig.regime}  |  Hurst={ind.get('hurst', '?')}")
        print(f"    RSI={ind.get('rsi',0):.1f}  StochK={ind.get('stoch_k',0):.1f}  "
              f"MACD_hist={ind.get('macd_hist',0):.6f}")
        print(f"    ADX={ind.get('adx',0):.1f}  +DI={ind.get('+DI',0):.1f}  -DI={ind.get('-DI',0):.1f}")
        print(f"    OBI={ind.get('obi',0):.3f}  Spread={ind.get('spread_pct',0):.4f}%")
        print(f"    Williams%R={ind.get('williams_r',0):.1f}  ATR={ind.get('atr',0):.6f}")
        print(f"    Reasons:")
        for r in sig.reasons:
            print(f"      • {r}")


# ─── ENTRY POINT ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Aura Algo Trader")
    parser.add_argument("--live",     action="store_true", help="Enable live trading (USE WITH CAUTION)")
    parser.add_argument("--scan",     action="store_true", help="One-shot market scan, no trading")
    parser.add_argument("--capital",  type=float, default=None, help="Override capital")
    parser.add_argument("--interval", type=int,   default=SCAN_INTERVAL_S, help="Scan interval seconds")
    args = parser.parse_args()

    if args.capital:
        CAPITAL = args.capital

    if args.scan:
        run_scan()
        sys.exit(0)

    if args.live:
        print("\n" + "!" * 65)
        print("  WARNING: LIVE TRADING MODE")
        print("  Real money will be used. Ensure you have:")
        print("  1. Backtested this strategy (python quant_backtest.py)")
        print("  2. Verified your API keys have trade permissions")
        print("  3. Accepted the risk of total capital loss")
        answer = input("\n  Type 'I ACCEPT' to continue: ")
        if answer.strip() != "I ACCEPT":
            print("  Aborted.")
            sys.exit(0)

    mode = "LIVE" if args.live else "PAPER"
    print(f"\n{'═'*65}")
    print(f"  AURA ALGO TRADER — {mode} MODE")
    print(f"  Capital: ${CAPITAL:,.2f}  |  Risk/trade: {MAX_RISK_PCT*100:.1f}%")
    print(f"  SL: {STOP_LOSS_PCT*100:.1f}%  TP: {TAKE_PROFIT_PCT*100:.1f}%  "
          f"Max DD: {MAX_DRAWDOWN*100:.1f}%")
    print(f"  Watchlist: {', '.join(WATCHLIST)}")
    print(f"  Min confidence: {MIN_CONFIDENCE}")
    print(f"  Scan interval: {args.interval}s")
    print(f"{'═'*65}")
    print(f"  Press Ctrl+C to stop and see summary\n")

    trader = AlgoTrader(live=args.live)

    while True:
        try:
            trader.run_cycle()
        except Exception as e:
            print(f"  ⚠ Cycle error: {e}")
        trader.save_log()
        time.sleep(args.interval)
