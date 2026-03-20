"""
quant_risk.py — Professional risk management
Kelly criterion, correlation-adjusted sizing, daily drawdown circuit breaker,
position aging, portfolio heat, Sharpe tracking.
"""

import math
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone


# ─── POSITION ─────────────────────────────────────────────────────────────────

@dataclass
class Position:
    symbol: str
    side: str               # "BUY" | "SELL"
    entry_price: float
    size: float             # base asset quantity
    stop_loss: float
    take_profit: float
    trailing_stop: float    # current trailing stop level
    opened_at: float = field(default_factory=time.time)
    highest_seen: float = 0.0   # for trailing stop
    lowest_seen: float = 0.0

    def age_hours(self) -> float:
        return (time.time() - self.opened_at) / 3600

    def unrealized_pnl(self, current_price: float) -> float:
        if self.side == "BUY":
            return (current_price - self.entry_price) * self.size
        else:
            return (self.entry_price - current_price) * self.size

    def unrealized_pct(self, current_price: float) -> float:
        return self.unrealized_pnl(current_price) / (self.entry_price * self.size)


# ─── DAILY STATS ──────────────────────────────────────────────────────────────

@dataclass
class DailyStats:
    date: str = ""
    start_capital: float = 0.0
    pnl: float = 0.0
    trades: int = 0
    wins: int = 0
    losses: int = 0
    returns: list[float] = field(default_factory=list)  # per-trade return %

    @property
    def win_rate(self) -> float:
        total = self.wins + self.losses
        return self.wins / total if total else 0.0

    @property
    def sharpe(self) -> float:
        """Annualized Sharpe ratio from per-trade returns."""
        if len(self.returns) < 2:
            return 0.0
        n = len(self.returns)
        mean = sum(self.returns) / n
        variance = sum((r - mean) ** 2 for r in self.returns) / (n - 1)
        std = math.sqrt(variance) if variance > 0 else 1e-10
        # Assume ~8 trades/day × 252 days
        return round((mean / std) * math.sqrt(8 * 252), 4)

    @property
    def expectancy(self) -> float:
        """Expected return per trade = WR × avg_win - LR × avg_loss."""
        wins = [r for r in self.returns if r > 0]
        losses = [r for r in self.returns if r < 0]
        wr = self.win_rate
        avg_win = sum(wins) / len(wins) if wins else 0
        avg_loss = abs(sum(losses) / len(losses)) if losses else 0
        return round(wr * avg_win - (1 - wr) * avg_loss, 6)


# ─── RISK MANAGER ─────────────────────────────────────────────────────────────

class RiskManager:
    """
    Parameters
    ----------
    capital         : Starting capital in USD
    max_risk_pct    : Max capital risked per trade (default 2%)
    stop_loss_pct   : Hard stop loss (default 1.5%)
    take_profit_pct : Hard take profit (default 3%)
    max_drawdown    : Daily drawdown circuit breaker (default 5%)
    max_positions   : Maximum simultaneous open positions
    max_age_hours   : Force-close positions older than N hours
    trailing_pct    : Trailing stop activation (% of take-profit distance)
    """

    def __init__(
        self,
        capital: float,
        max_risk_pct: float = 0.02,
        stop_loss_pct: float = 0.015,
        take_profit_pct: float = 0.03,
        max_drawdown: float = 0.05,
        max_positions: int = 2,
        max_age_hours: float = 6.0,
        trailing_pct: float = 0.5,     # trailing stop kicks in at 50% of way to TP
    ):
        self.capital = capital
        self.initial_capital = capital
        self.max_risk_pct = max_risk_pct
        self.stop_loss_pct = stop_loss_pct
        self.take_profit_pct = take_profit_pct
        self.max_drawdown = max_drawdown
        self.max_positions = max_positions
        self.max_age_hours = max_age_hours
        self.trailing_pct = trailing_pct

        self.positions: list[Position] = []
        self.daily = DailyStats(
            date=datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            start_capital=capital,
        )
        self.all_time_pnl = 0.0
        self.circuit_open = False       # True = stop trading today

    # ── Sizing ────────────────────────────────────────────────────────────────

    def kelly_size(self, confidence: float, win_rate: float = 0.55,
                    rr: float = 2.0) -> float:
        """
        Full Kelly = (WR × RR - LR) / RR
        Using half-Kelly for safety.
        Adjusted by signal confidence.
        """
        lr = 1 - win_rate
        kelly = max(0, (win_rate * rr - lr) / rr)
        half_kelly = kelly * 0.5 * confidence
        return min(half_kelly, self.max_risk_pct)

    def position_size(self, price: float, confidence: float,
                       win_rate: float = 0.55) -> float:
        """Returns position size in base asset units."""
        risk_fraction = self.kelly_size(confidence, win_rate)
        risk_usd = self.capital * risk_fraction
        size = risk_usd / (price * self.stop_loss_pct)
        return round(size, 6)

    def stop_and_target(self, price: float, side: str) -> tuple[float, float]:
        if side == "BUY":
            stop   = price * (1 - self.stop_loss_pct)
            target = price * (1 + self.take_profit_pct)
        else:
            stop   = price * (1 + self.stop_loss_pct)
            target = price * (1 - self.take_profit_pct)
        return round(stop, 6), round(target, 6)

    def initial_trailing_stop(self, price: float, side: str) -> float:
        """Trailing stop starts at same level as hard stop."""
        if side == "BUY":
            return price * (1 - self.stop_loss_pct)
        return price * (1 + self.stop_loss_pct)

    # ── Checks ────────────────────────────────────────────────────────────────

    def can_trade(self) -> tuple[bool, str]:
        """Returns (ok, reason)."""
        if self.circuit_open:
            return False, "Daily circuit breaker open — max drawdown hit"
        daily_dd = (self.daily.start_capital - self.capital) / self.daily.start_capital
        if daily_dd >= self.max_drawdown:
            self.circuit_open = True
            return False, f"Circuit breaker triggered: daily drawdown {daily_dd*100:.1f}%"
        if len(self.positions) >= self.max_positions:
            return False, f"Max positions ({self.max_positions}) reached"
        return True, "OK"

    def correlation_penalty(self, symbol: str) -> float:
        """
        If we already hold a correlated asset, reduce new position size.
        Simple heuristic: BTC and ETH are highly correlated.
        """
        correlated = {
            "BTC/USDC": ["ETH/USDC"],
            "ETH/USDC": ["BTC/USDC"],
            "SOL/USDC": ["BTC/USDC", "ETH/USDC"],
        }
        held_symbols = [p.symbol for p in self.positions]
        overlaps = sum(1 for s in correlated.get(symbol, []) if s in held_symbols)
        # Each correlation overlap reduces size by 30%
        return max(0.4, 1.0 - overlaps * 0.3)

    # ── Position lifecycle ────────────────────────────────────────────────────

    def open_position(self, symbol: str, side: str, price: float,
                       confidence: float) -> Position:
        corr_factor = self.correlation_penalty(symbol)
        size = self.position_size(price, confidence) * corr_factor
        stop, target = self.stop_and_target(price, side)
        trail = self.initial_trailing_stop(price, side)
        pos = Position(
            symbol=symbol, side=side, entry_price=price,
            size=round(size, 6), stop_loss=stop, take_profit=target,
            trailing_stop=trail,
            highest_seen=price, lowest_seen=price,
        )
        self.positions.append(pos)
        return pos

    def update_trailing_stop(self, pos: Position, current_price: float):
        """Ratchet trailing stop as price moves in our favor."""
        if pos.side == "BUY":
            pos.highest_seen = max(pos.highest_seen, current_price)
            # Trail distance = stop_loss_pct of current high
            new_trail = pos.highest_seen * (1 - self.stop_loss_pct)
            pos.trailing_stop = max(pos.trailing_stop, new_trail)
        else:
            pos.lowest_seen = min(pos.lowest_seen, current_price)
            new_trail = pos.lowest_seen * (1 + self.stop_loss_pct)
            pos.trailing_stop = min(pos.trailing_stop, new_trail)

    def check_exit(self, pos: Position, current_price: float) -> str | None:
        """Returns exit reason or None."""
        self.update_trailing_stop(pos, current_price)

        if pos.side == "BUY":
            if current_price <= pos.trailing_stop:
                return "TRAIL_STOP"
            if current_price <= pos.stop_loss:
                return "STOP_LOSS"
            if current_price >= pos.take_profit:
                return "TAKE_PROFIT"
        else:
            if current_price >= pos.trailing_stop:
                return "TRAIL_STOP"
            if current_price >= pos.stop_loss:
                return "STOP_LOSS"
            if current_price <= pos.take_profit:
                return "TAKE_PROFIT"

        if pos.age_hours() > self.max_age_hours:
            return "TIME_EXIT"

        return None

    def close_position(self, pos: Position, exit_price: float,
                        exit_reason: str) -> dict:
        pnl = pos.unrealized_pnl(exit_price)
        ret_pct = pos.unrealized_pct(exit_price)

        self.capital += pnl
        self.all_time_pnl += pnl
        self.daily.pnl += pnl
        self.daily.trades += 1
        self.daily.returns.append(ret_pct)

        if pnl > 0:
            self.daily.wins += 1
        else:
            self.daily.losses += 1

        self.positions.remove(pos)

        return {
            "symbol": pos.symbol,
            "side": pos.side,
            "entry": pos.entry_price,
            "exit": exit_price,
            "size": pos.size,
            "pnl_usd": round(pnl, 4),
            "pnl_pct": round(ret_pct * 100, 3),
            "reason": exit_reason,
            "age_h": round(pos.age_hours(), 2),
        }

    def reset_daily(self):
        """Call at midnight to reset daily stats."""
        self.daily = DailyStats(
            date=datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            start_capital=self.capital,
        )
        self.circuit_open = False

    # ── Reporting ─────────────────────────────────────────────────────────────

    def portfolio_heat(self) -> float:
        """Total unrealized risk as % of capital (rough estimate)."""
        risk = sum(p.size * p.entry_price * self.stop_loss_pct for p in self.positions)
        return round(risk / self.capital * 100, 2) if self.capital else 0

    def status(self) -> dict:
        return {
            "capital": round(self.capital, 2),
            "all_time_pnl": round(self.all_time_pnl, 2),
            "daily_pnl": round(self.daily.pnl, 2),
            "daily_trades": self.daily.trades,
            "win_rate": round(self.daily.win_rate * 100, 1),
            "sharpe": self.daily.sharpe,
            "expectancy": self.daily.expectancy,
            "open_positions": len(self.positions),
            "portfolio_heat_pct": self.portfolio_heat(),
            "circuit_open": self.circuit_open,
        }
