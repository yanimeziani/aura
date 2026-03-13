"""
Tests for quant_risk.py — risk manager, position lifecycle, Kelly sizing.
Run: pytest ai_agency_wealth/tests/ -v
"""

import sys
import time
import unittest

sys.path.insert(0, "/home/yani/Aura/ai_agency_wealth")
from quant_risk import RiskManager, Position, DailyStats


# ─── DailyStats ──────────────────────────────────────────────────────────────

class TestDailyStats(unittest.TestCase):
    def _stats(self, returns=None):
        s = DailyStats(date="2026-03-12", start_capital=1000.0)
        s.wins = sum(1 for r in (returns or []) if r > 0)
        s.losses = sum(1 for r in (returns or []) if r < 0)
        s.returns = list(returns or [])
        return s

    def test_win_rate_no_trades(self):
        s = self._stats()
        self.assertEqual(s.win_rate, 0.0)

    def test_win_rate_all_wins(self):
        s = self._stats([0.01, 0.02, 0.03])
        self.assertAlmostEqual(s.win_rate, 1.0)

    def test_win_rate_half(self):
        s = self._stats([0.01, -0.01])
        self.assertAlmostEqual(s.win_rate, 0.5)

    def test_sharpe_single_return_is_zero(self):
        s = self._stats([0.01])
        self.assertEqual(s.sharpe, 0.0)

    def test_sharpe_positive_for_consistent_wins(self):
        returns = [0.02] * 20
        s = self._stats(returns)
        # Consistent returns → very high Sharpe (std approaches 0 → big ratio)
        self.assertGreater(s.sharpe, 0.0)

    def test_expectancy_positive(self):
        # Win rate 60%, avg win 2%, avg loss 1%
        s = self._stats([0.02, 0.02, 0.02, -0.01, -0.01])
        s.wins = 3
        s.losses = 2
        exp = s.expectancy
        self.assertGreater(exp, 0.0)

    def test_expectancy_no_trades(self):
        s = self._stats()
        self.assertEqual(s.expectancy, 0.0)


# ─── RiskManager ─────────────────────────────────────────────────────────────

class TestRiskManager(unittest.TestCase):
    def _rm(self, capital=10000.0, **kwargs):
        return RiskManager(
            capital=capital,
            max_risk_pct=0.02,
            stop_loss_pct=0.015,
            take_profit_pct=0.030,
            max_drawdown=0.05,
            max_positions=2,
            max_age_hours=6.0,
            **kwargs,
        )

    # ── Kelly sizing ──────────────────────────────────────────────────────────

    def test_kelly_positive_edge(self):
        rm = self._rm()
        k = rm.kelly_size(confidence=0.6, win_rate=0.55, rr=2.0)
        self.assertGreater(k, 0.0)

    def test_kelly_clipped_to_max_risk(self):
        rm = self._rm()
        k = rm.kelly_size(confidence=1.0, win_rate=0.99, rr=10.0)
        self.assertLessEqual(k, rm.max_risk_pct)

    def test_kelly_zero_confidence(self):
        rm = self._rm()
        k = rm.kelly_size(confidence=0.0)
        self.assertEqual(k, 0.0)

    def test_position_size_positive(self):
        rm = self._rm()
        size = rm.position_size(price=50000.0, confidence=0.6)
        self.assertGreater(size, 0.0)

    def test_position_size_reduces_with_lower_confidence(self):
        rm = self._rm()
        # Use very low confidence values that don't hit the max_risk_pct cap
        # Full Kelly ~32.5% → half-Kelly ~16.25% → confidence 0.1 gives 1.6% < cap 2%
        size_high = rm.position_size(50000.0, confidence=0.1)
        size_low  = rm.position_size(50000.0, confidence=0.05)
        self.assertGreater(size_high, size_low)

    # ── Stop & target ─────────────────────────────────────────────────────────

    def test_buy_stop_below_entry(self):
        rm = self._rm()
        stop, target = rm.stop_and_target(price=1000.0, side="BUY")
        self.assertLess(stop, 1000.0)
        self.assertGreater(target, 1000.0)

    def test_sell_stop_above_entry(self):
        rm = self._rm()
        stop, target = rm.stop_and_target(price=1000.0, side="SELL")
        self.assertGreater(stop, 1000.0)
        self.assertLess(target, 1000.0)

    def test_rr_ratio_approximately_2(self):
        rm = self._rm()
        stop, target = rm.stop_and_target(1000.0, "BUY")
        risk   = 1000.0 - stop
        reward = target - 1000.0
        self.assertAlmostEqual(reward / risk, 2.0, places=1)

    # ── can_trade ─────────────────────────────────────────────────────────────

    def test_can_trade_initially_ok(self):
        rm = self._rm()
        ok, reason = rm.can_trade()
        self.assertTrue(ok)

    def test_max_positions_blocks_trading(self):
        rm = self._rm(capital=10000.0)
        rm.positions = [object(), object()]  # 2 mock positions
        ok, _ = rm.can_trade()
        self.assertFalse(ok)

    def test_circuit_breaker_manual_trigger(self):
        rm = self._rm()
        rm.circuit_open = True
        ok, reason = rm.can_trade()
        self.assertFalse(ok)
        self.assertIn("circuit", reason.lower())

    def test_drawdown_triggers_circuit_breaker(self):
        rm = self._rm(capital=10000.0)
        rm.daily.start_capital = 10000.0
        rm.capital = 9400.0  # 6% drawdown > 5% max
        ok, _ = rm.can_trade()
        self.assertFalse(ok)
        self.assertTrue(rm.circuit_open)

    def test_drawdown_within_limit_ok(self):
        rm = self._rm(capital=10000.0)
        rm.daily.start_capital = 10000.0
        rm.capital = 9600.0  # 4% drawdown < 5% max
        ok, _ = rm.can_trade()
        self.assertTrue(ok)

    # ── Position lifecycle ────────────────────────────────────────────────────

    def test_open_position_adds_to_list(self):
        rm = self._rm()
        pos = rm.open_position("BTC/USDC", "BUY", price=50000.0, confidence=0.6)
        self.assertIn(pos, rm.positions)
        self.assertEqual(len(rm.positions), 1)

    def test_open_position_sets_correct_side(self):
        rm = self._rm()
        pos = rm.open_position("ETH/USDC", "SELL", price=2000.0, confidence=0.5)
        self.assertEqual(pos.side, "SELL")

    def test_close_position_updates_capital(self):
        rm = self._rm(capital=10000.0)
        pos = rm.open_position("BTC/USDC", "BUY", price=50000.0, confidence=0.6)
        entry = pos.entry_price
        exit_price = entry * 1.03  # +3% → should hit TP zone
        result = rm.close_position(pos, exit_price, "TAKE_PROFIT")
        self.assertGreater(rm.capital, 10000.0)  # profitable
        self.assertGreater(result["pnl_usd"], 0)

    def test_close_position_loss_reduces_capital(self):
        rm = self._rm(capital=10000.0)
        pos = rm.open_position("BTC/USDC", "BUY", price=50000.0, confidence=0.6)
        entry = pos.entry_price
        exit_price = entry * 0.97  # -3% loss
        result = rm.close_position(pos, exit_price, "STOP_LOSS")
        self.assertLess(rm.capital, 10000.0)
        self.assertLess(result["pnl_usd"], 0)

    def test_close_position_removes_from_list(self):
        rm = self._rm()
        pos = rm.open_position("SOL/USDC", "BUY", price=100.0, confidence=0.5)
        rm.close_position(pos, 103.0, "TAKE_PROFIT")
        self.assertNotIn(pos, rm.positions)

    # ── Trailing stop ─────────────────────────────────────────────────────────

    def test_trailing_stop_ratchets_up_on_buy(self):
        rm = self._rm()
        pos = rm.open_position("BTC/USDC", "BUY", price=50000.0, confidence=0.6)
        initial_trail = pos.trailing_stop
        # Price moves up significantly
        rm.update_trailing_stop(pos, 52000.0)
        self.assertGreater(pos.trailing_stop, initial_trail)

    def test_trailing_stop_never_moves_against_buy(self):
        rm = self._rm()
        pos = rm.open_position("BTC/USDC", "BUY", price=50000.0, confidence=0.6)
        rm.update_trailing_stop(pos, 52000.0)
        high_trail = pos.trailing_stop
        # Price drops — trailing stop must NOT drop
        rm.update_trailing_stop(pos, 48000.0)
        self.assertEqual(pos.trailing_stop, high_trail)

    def test_trailing_stop_ratchets_down_on_sell(self):
        rm = self._rm()
        pos = rm.open_position("BTC/USDC", "SELL", price=50000.0, confidence=0.6)
        initial_trail = pos.trailing_stop
        rm.update_trailing_stop(pos, 48000.0)  # price falls in favor of SELL
        self.assertLess(pos.trailing_stop, initial_trail)

    # ── check_exit ────────────────────────────────────────────────────────────

    def test_take_profit_exit(self):
        rm = self._rm()
        pos = rm.open_position("BTC/USDC", "BUY", price=50000.0, confidence=0.6)
        tp_price = pos.take_profit * 1.001  # just above TP
        reason = rm.check_exit(pos, tp_price)
        self.assertEqual(reason, "TAKE_PROFIT")

    def test_stop_loss_exit(self):
        rm = self._rm()
        pos = rm.open_position("BTC/USDC", "BUY", price=50000.0, confidence=0.6)
        sl_price = pos.stop_loss * 0.999  # just below SL
        reason = rm.check_exit(pos, sl_price)
        self.assertIn(reason, ("STOP_LOSS", "TRAIL_STOP"))

    def test_no_exit_within_bounds(self):
        rm = self._rm()
        pos = rm.open_position("BTC/USDC", "BUY", price=50000.0, confidence=0.6)
        mid_price = pos.entry_price * 1.01  # +1%, between SL and TP
        reason = rm.check_exit(pos, mid_price)
        self.assertIsNone(reason)

    def test_time_exit_old_position(self):
        rm = self._rm()
        pos = rm.open_position("ETH/USDC", "BUY", price=2000.0, confidence=0.5)
        pos.opened_at = time.time() - 7 * 3600  # 7 hours old > max_age_hours=6
        # Price at neutral (no SL/TP hit)
        mid_price = pos.entry_price * 1.005
        reason = rm.check_exit(pos, mid_price)
        self.assertEqual(reason, "TIME_EXIT")

    # ── Correlation penalty ───────────────────────────────────────────────────

    def test_no_correlation_penalty_clean_slate(self):
        rm = self._rm()
        penalty = rm.correlation_penalty("BTC/USDC")
        self.assertAlmostEqual(penalty, 1.0)

    def test_correlation_penalty_with_eth_held(self):
        rm = self._rm()
        # Open ETH — correlated with BTC
        rm.open_position("ETH/USDC", "BUY", price=2000.0, confidence=0.5)
        penalty = rm.correlation_penalty("BTC/USDC")
        self.assertLess(penalty, 1.0)

    # ── Portfolio heat ────────────────────────────────────────────────────────

    def test_portfolio_heat_zero_no_positions(self):
        rm = self._rm()
        self.assertEqual(rm.portfolio_heat(), 0.0)

    def test_portfolio_heat_positive_with_positions(self):
        rm = self._rm()
        rm.open_position("BTC/USDC", "BUY", price=50000.0, confidence=0.6)
        heat = rm.portfolio_heat()
        self.assertGreater(heat, 0.0)

    # ── Daily reset ───────────────────────────────────────────────────────────

    def test_reset_daily_clears_circuit_breaker(self):
        rm = self._rm()
        rm.circuit_open = True
        rm.reset_daily()
        self.assertFalse(rm.circuit_open)

    def test_reset_daily_updates_date(self):
        from datetime import datetime, timezone
        rm = self._rm()
        rm.reset_daily()
        expected_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        self.assertEqual(rm.daily.date, expected_date)

    # ── Status dict ───────────────────────────────────────────────────────────

    def test_status_has_required_keys(self):
        rm = self._rm()
        status = rm.status()
        for key in ("capital", "all_time_pnl", "daily_pnl", "daily_trades",
                    "win_rate", "sharpe", "expectancy", "open_positions",
                    "portfolio_heat_pct", "circuit_open"):
            self.assertIn(key, status, f"Missing key: {key}")

    def test_status_capital_matches(self):
        rm = self._rm(capital=5000.0)
        self.assertAlmostEqual(rm.status()["capital"], 5000.0)


# ─── Position dataclass ───────────────────────────────────────────────────────

class TestPosition(unittest.TestCase):
    def _pos(self, side="BUY", entry=1000.0, size=1.0):
        return Position(
            symbol="BTC/USDC", side=side,
            entry_price=entry, size=size,
            stop_loss=entry * 0.985,
            take_profit=entry * 1.03,
            trailing_stop=entry * 0.985,
            highest_seen=entry, lowest_seen=entry,
        )

    def test_unrealized_pnl_buy_profit(self):
        pos = self._pos(side="BUY", entry=1000.0, size=1.0)
        self.assertAlmostEqual(pos.unrealized_pnl(1050.0), 50.0)

    def test_unrealized_pnl_buy_loss(self):
        pos = self._pos(side="BUY", entry=1000.0, size=1.0)
        self.assertAlmostEqual(pos.unrealized_pnl(950.0), -50.0)

    def test_unrealized_pnl_sell_profit(self):
        pos = self._pos(side="SELL", entry=1000.0, size=1.0)
        self.assertAlmostEqual(pos.unrealized_pnl(950.0), 50.0)

    def test_unrealized_pnl_sell_loss(self):
        pos = self._pos(side="SELL", entry=1000.0, size=1.0)
        self.assertAlmostEqual(pos.unrealized_pnl(1050.0), -50.0)

    def test_age_hours_just_opened(self):
        pos = self._pos()
        self.assertAlmostEqual(pos.age_hours(), 0.0, places=2)

    def test_age_hours_simulated(self):
        pos = self._pos()
        pos.opened_at = time.time() - 3600  # 1 hour ago
        self.assertAlmostEqual(pos.age_hours(), 1.0, delta=0.01)


if __name__ == "__main__":
    unittest.main(verbosity=2)
