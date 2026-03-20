"""
quant_backtest.py — Vectorized backtester
Feed OHLCV history → replay strategy → output performance metrics.

Usage:
    python quant_backtest.py --symbol BTC/USDC --days 30 --capital 1000
"""

import argparse
import json
import math
import os
import time
from datetime import datetime, timezone
from dataclasses import dataclass, field

import ccxt
from dotenv import load_dotenv

from quant_signals import Indicators, SentimentSignals

load_dotenv()

# ─── CONFIG ───────────────────────────────────────────────────────────────────

STOP_LOSS_PCT    = 0.015
TAKE_PROFIT_PCT  = 0.03
MAX_RISK_PCT     = 0.02
COMMISSION_PCT   = 0.006    # 0.6% round-trip (Coinbase taker)
SLIPPAGE_PCT     = 0.001    # 0.1% slippage estimate


# ─── BACKTEST TRADE ───────────────────────────────────────────────────────────

@dataclass
class BtTrade:
    direction: str
    entry_idx: int
    entry_price: float
    size: float
    stop: float
    target: float
    exit_idx: int = -1
    exit_price: float = 0.0
    exit_reason: str = ""
    pnl: float = 0.0
    pnl_pct: float = 0.0


# ─── PERFORMANCE METRICS ──────────────────────────────────────────────────────

@dataclass
class BacktestResult:
    symbol: str
    period_days: int
    total_trades: int
    wins: int
    losses: int
    gross_pnl: float
    net_pnl: float
    commissions: float
    max_drawdown_pct: float
    sharpe_ratio: float
    calmar_ratio: float
    win_rate: float
    avg_win_pct: float
    avg_loss_pct: float
    expectancy_pct: float
    profit_factor: float
    best_trade_pct: float
    worst_trade_pct: float
    avg_hold_candles: float
    final_capital: float
    trades: list[BtTrade] = field(default_factory=list)

    def summary(self) -> str:
        lines = [
            f"\n{'═'*60}",
            f"  BACKTEST: {self.symbol}  ({self.period_days}d)",
            f"{'═'*60}",
            f"  Trades      : {self.total_trades}  (W:{self.wins} L:{self.losses})",
            f"  Win Rate    : {self.win_rate*100:.1f}%",
            f"  Avg Win     : +{self.avg_win_pct:.2f}%  Avg Loss: -{abs(self.avg_loss_pct):.2f}%",
            f"  Expectancy  : {self.expectancy_pct:.3f}%/trade",
            f"  Profit Fact : {self.profit_factor:.2f}",
            f"  Net PnL     : ${self.net_pnl:.2f}  (commissions: ${self.commissions:.2f})",
            f"  Final Cap   : ${self.final_capital:.2f}",
            f"  Max Drawdown: {self.max_drawdown_pct*100:.2f}%",
            f"  Sharpe      : {self.sharpe_ratio:.3f}",
            f"  Calmar      : {self.calmar_ratio:.3f}",
            f"  Best Trade  : +{self.best_trade_pct:.2f}%",
            f"  Worst Trade : {self.worst_trade_pct:.2f}%",
            f"  Avg Hold    : {self.avg_hold_candles:.1f} candles",
            f"{'═'*60}",
        ]
        return "\n".join(lines)


# ─── SIGNAL LOGIC (standalone, no live API calls) ─────────────────────────────

def compute_signals_at(candles: list, idx: int) -> dict:
    """Compute all indicators at a given candle index."""
    window = candles[max(0, idx-99): idx+1]
    if len(window) < 30:
        return {}

    closes  = [c[4] for c in window]
    highs   = [c[2] for c in window]
    lows    = [c[3] for c in window]
    volumes = [c[5] for c in window]

    rsi_val          = Indicators.rsi(closes)
    stoch_k, stoch_d = Indicators.stoch_rsi(closes)
    macd_l, macd_s, macd_h = Indicators.macd(closes)
    bb_up, bb_mid, bb_lo = Indicators.bollinger(closes)
    adx_val, plus_di, minus_di = Indicators.adx(highs, lows, closes)
    vwap_val         = Indicators.vwap(window)
    wr_val           = Indicators.williams_r(highs, lows, closes)
    atr_val          = Indicators.atr(highs, lows, closes)
    price            = closes[-1]

    avg_vol = sum(volumes[-20:]) / min(20, len(volumes))
    vol_spike = volumes[-1] > avg_vol * 2.0

    ema20 = Indicators.ema(closes, 20)[-1] if len(closes) >= 20 else price
    ema50 = Indicators.ema(closes, 50)[-1] if len(closes) >= 50 else price

    # Simple score
    score = 0.0

    if rsi_val < 30:   score += 0.3
    elif rsi_val < 40: score += 0.15
    elif rsi_val > 70: score -= 0.3
    elif rsi_val > 60: score -= 0.15

    if stoch_k < 20 and stoch_d < 20:     score += 0.2
    elif stoch_k > 80 and stoch_d > 80:   score -= 0.2
    elif stoch_k > stoch_d and stoch_k < 80: score += 0.1
    elif stoch_k < stoch_d and stoch_k > 20: score -= 0.1

    if macd_h > 0:   score += 0.15
    elif macd_h < 0: score -= 0.15

    if price < bb_lo: score += 0.2
    elif price > bb_up: score -= 0.2

    if wr_val < -80: score += 0.15
    elif wr_val > -20: score -= 0.15

    if adx_val > 25:
        if plus_di > minus_di: score += 0.15
        else: score -= 0.15

    if ema20 > ema50: score += 0.1
    else: score -= 0.1

    if price < vwap_val * 0.999: score += 0.15
    elif price > vwap_val * 1.001: score -= 0.15

    if vol_spike: score *= 1.2

    if atr_val / price > 0.025:
        score *= 0.7   # volatile regime dampener

    score = max(-1.0, min(1.0, score))
    return {"score": score, "price": price, "atr": atr_val}


# ─── BACKTEST ENGINE ──────────────────────────────────────────────────────────

class Backtester:

    def __init__(self, capital: float = 1000.0):
        self.capital = capital

    def fetch_history(self, exchange, symbol: str, days: int,
                       timeframe="5m") -> list:
        """Download OHLCV history."""
        limit_per_req = 300
        ms_per_candle = {"1m": 60000, "5m": 300000, "15m": 900000, "1h": 3600000}
        ms = ms_per_candle.get(timeframe, 300000)
        total_candles = (days * 24 * 60 * 60 * 1000) // ms

        all_candles = []
        since = int(time.time() * 1000) - total_candles * ms

        print(f"Downloading {total_candles} × {timeframe} candles for {symbol}…")
        while len(all_candles) < total_candles:
            batch = exchange.fetch_ohlcv(symbol, timeframe, since=since, limit=limit_per_req)
            if not batch:
                break
            all_candles.extend(batch)
            since = batch[-1][0] + ms
            if len(batch) < limit_per_req:
                break
            time.sleep(exchange.rateLimit / 1000)

        print(f"  → {len(all_candles)} candles loaded")
        return all_candles

    def run(self, candles: list, symbol: str, min_confidence: float = 0.35) -> BacktestResult:
        capital = self.capital
        peak = capital
        max_dd = 0.0
        trades: list[BtTrade] = []
        equity_curve: list[float] = [capital]
        returns: list[float] = []
        commissions_total = 0.0

        in_trade: BtTrade | None = None

        for i in range(60, len(candles)):
            sig = compute_signals_at(candles, i)
            if not sig:
                continue

            price = sig["price"]
            score = sig["score"]
            confidence = abs(score)

            # ── Check exit ───────────────────────────────────────
            if in_trade:
                c = candles[i]
                hi, lo = c[2], c[3]
                exit_price = None
                exit_reason = ""

                if in_trade.direction == "BUY":
                    if lo <= in_trade.stop:
                        exit_price, exit_reason = in_trade.stop, "STOP_LOSS"
                    elif hi >= in_trade.target:
                        exit_price, exit_reason = in_trade.target, "TAKE_PROFIT"
                else:
                    if hi >= in_trade.stop:
                        exit_price, exit_reason = in_trade.stop, "STOP_LOSS"
                    elif lo <= in_trade.target:
                        exit_price, exit_reason = in_trade.target, "TAKE_PROFIT"

                # Time exit: 48 candles (4h on 5m)
                if not exit_price and (i - in_trade.entry_idx) > 48:
                    exit_price, exit_reason = price, "TIME_EXIT"

                if exit_price:
                    slip = exit_price * SLIPPAGE_PCT
                    comm = exit_price * in_trade.size * COMMISSION_PCT
                    commissions_total += comm

                    if in_trade.direction == "BUY":
                        pnl = (exit_price - slip - in_trade.entry_price) * in_trade.size - comm
                    else:
                        pnl = (in_trade.entry_price - exit_price - slip) * in_trade.size - comm

                    pnl_pct = pnl / (in_trade.entry_price * in_trade.size)
                    in_trade.exit_idx = i
                    in_trade.exit_price = exit_price
                    in_trade.exit_reason = exit_reason
                    in_trade.pnl = pnl
                    in_trade.pnl_pct = pnl_pct
                    trades.append(in_trade)
                    capital += pnl
                    returns.append(pnl_pct)
                    in_trade = None

                    peak = max(peak, capital)
                    dd = (peak - capital) / peak
                    max_dd = max(max_dd, dd)
                    equity_curve.append(capital)

            # ── Check entry ──────────────────────────────────────
            if not in_trade and confidence >= min_confidence:
                direction = "BUY" if score > 0 else "SELL"
                entry_price = price * (1 + SLIPPAGE_PCT if direction == "BUY" else 1 - SLIPPAGE_PCT)
                risk_usd = capital * MAX_RISK_PCT * confidence
                size = risk_usd / (entry_price * STOP_LOSS_PCT)
                entry_comm = entry_price * size * COMMISSION_PCT / 2
                commissions_total += entry_comm

                if direction == "BUY":
                    stop   = entry_price * (1 - STOP_LOSS_PCT)
                    target = entry_price * (1 + TAKE_PROFIT_PCT)
                else:
                    stop   = entry_price * (1 + STOP_LOSS_PCT)
                    target = entry_price * (1 - TAKE_PROFIT_PCT)

                in_trade = BtTrade(
                    direction=direction, entry_idx=i, entry_price=entry_price,
                    size=size, stop=stop, target=target,
                )

        # ── Statistics ──────────────────────────────────────────
        if not trades:
            return BacktestResult(
                symbol=symbol, period_days=len(candles)//288, total_trades=0,
                wins=0, losses=0, gross_pnl=0, net_pnl=0, commissions=0,
                max_drawdown_pct=0, sharpe_ratio=0, calmar_ratio=0,
                win_rate=0, avg_win_pct=0, avg_loss_pct=0, expectancy_pct=0,
                profit_factor=0, best_trade_pct=0, worst_trade_pct=0,
                avg_hold_candles=0, final_capital=capital, trades=[],
            )

        wins   = [t for t in trades if t.pnl > 0]
        losses = [t for t in trades if t.pnl <= 0]
        gross_pnl = sum(t.pnl for t in trades)
        net_pnl = gross_pnl  # commissions already subtracted

        win_pcts  = [t.pnl_pct * 100 for t in wins]
        loss_pcts = [t.pnl_pct * 100 for t in losses]
        all_pcts  = [t.pnl_pct * 100 for t in trades]

        avg_win  = sum(win_pcts)  / len(win_pcts)  if win_pcts  else 0
        avg_loss = sum(loss_pcts) / len(loss_pcts) if loss_pcts else 0
        wr = len(wins) / len(trades)
        expectancy = wr * avg_win + (1 - wr) * avg_loss

        gross_wins   = sum(t.pnl for t in wins)
        gross_losses = abs(sum(t.pnl for t in losses))
        profit_factor = gross_wins / gross_losses if gross_losses else 999.0

        # Sharpe
        n = len(returns)
        if n >= 2:
            mean_r = sum(returns) / n
            var_r  = sum((r - mean_r)**2 for r in returns) / (n-1)
            std_r  = math.sqrt(var_r) if var_r > 0 else 1e-10
            # Annualize: assume 288 candles/day on 5m → trades/day ≈ n / (days)
            trades_per_day = n / max(1, len(candles) / 288)
            sharpe = (mean_r / std_r) * math.sqrt(trades_per_day * 252)
        else:
            sharpe = 0.0

        # Calmar = net return / max drawdown
        total_return = (capital - self.capital) / self.capital
        calmar = total_return / max_dd if max_dd > 0 else 0.0

        avg_hold = sum(t.exit_idx - t.entry_idx for t in trades) / len(trades)
        period_days = len(candles) // 288  # 5m candles per day

        return BacktestResult(
            symbol=symbol,
            period_days=period_days,
            total_trades=len(trades),
            wins=len(wins),
            losses=len(losses),
            gross_pnl=round(gross_pnl, 2),
            net_pnl=round(net_pnl, 2),
            commissions=round(commissions_total, 2),
            max_drawdown_pct=round(max_dd, 4),
            sharpe_ratio=round(sharpe, 4),
            calmar_ratio=round(calmar, 4),
            win_rate=round(wr, 4),
            avg_win_pct=round(avg_win, 4),
            avg_loss_pct=round(avg_loss, 4),
            expectancy_pct=round(expectancy, 4),
            profit_factor=round(profit_factor, 4),
            best_trade_pct=round(max(all_pcts), 4),
            worst_trade_pct=round(min(all_pcts), 4),
            avg_hold_candles=round(avg_hold, 1),
            final_capital=round(capital, 2),
            trades=trades,
        )


# ─── CLI ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Backtest quant strategy")
    parser.add_argument("--symbol",     default="BTC/USDC",  help="Trading pair")
    parser.add_argument("--days",       type=int, default=30, help="History days")
    parser.add_argument("--capital",    type=float, default=1000.0, help="Starting capital")
    parser.add_argument("--tf",         default="5m",  help="Timeframe (1m/5m/15m/1h)")
    parser.add_argument("--confidence", type=float, default=0.35, help="Min signal confidence")
    parser.add_argument("--save",       action="store_true", help="Save trades to JSON")
    args = parser.parse_args()

    api_key    = os.getenv("COINBASE_API_KEY")
    api_secret = os.getenv("COINBASE_API_SECRET")

    exchange = ccxt.coinbaseadvanced({
        "apiKey": api_key,
        "secret": api_secret,
        "enableRateLimit": True,
    })

    bt = Backtester(capital=args.capital)
    candles = bt.fetch_history(exchange, args.symbol, args.days, args.tf)

    if not candles:
        print("No data fetched. Check your API keys and symbol.")
        exit(1)

    result = bt.run(candles, args.symbol, min_confidence=args.confidence)
    print(result.summary())

    if args.save:
        filename = f"backtest_{args.symbol.replace('/', '_')}_{args.days}d.json"
        out = {
            "symbol": result.symbol,
            "period_days": result.period_days,
            "win_rate": result.win_rate,
            "sharpe": result.sharpe_ratio,
            "net_pnl": result.net_pnl,
            "final_capital": result.final_capital,
            "trades": [
                {
                    "dir": t.direction,
                    "entry": t.entry_price,
                    "exit": t.exit_price,
                    "pnl": t.pnl,
                    "pnl_pct": t.pnl_pct,
                    "reason": t.exit_reason,
                }
                for t in result.trades
            ],
        }
        with open(filename, "w") as f:
            json.dump(out, f, indent=2)
        print(f"\nTrades saved to {filename}")
