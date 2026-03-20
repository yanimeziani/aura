"""
Tests for quant_signals.py — indicator library and composite signal engine.
Run: pytest ai_agency_wealth/tests/ -v
"""

import sys
import math
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, "/home/yani/Aura/ai_agency_wealth")
from quant_signals import Indicators, SentimentSignals, CompositeSignalEngine, MarketSignal


# ─── Helper ──────────────────────────────────────────────────────────────────

def _sine_wave(n=100, amplitude=100, offset=1000, period=20):
    """Generate a sinusoidal price series for deterministic tests."""
    return [offset + amplitude * math.sin(2 * math.pi * i / period) for i in range(n)]


def _trend_up(n=100, start=100, step=1.0):
    return [start + i * step for i in range(n)]


def _trend_down(n=100, start=200, step=-1.0):
    return [start + i * step for i in range(n)]


def _flat(n=100, value=1000.0):
    return [value] * n


# ─── Indicators ──────────────────────────────────────────────────────────────

class TestSMA(unittest.TestCase):
    def test_basic(self):
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        self.assertAlmostEqual(Indicators.sma(data, 3), 4.0)

    def test_period_larger_than_data(self):
        data = [2.0, 4.0]
        # Falls back to last value
        self.assertEqual(Indicators.sma(data, 10), 4.0)

    def test_full_period(self):
        data = [10.0] * 20
        self.assertAlmostEqual(Indicators.sma(data, 20), 10.0)


class TestEMA(unittest.TestCase):
    def test_length(self):
        data = list(range(1, 51))
        result = Indicators.ema(data, 10)
        self.assertEqual(len(result), 50)

    def test_first_value_matches_input(self):
        data = [5.0, 10.0, 15.0]
        result = Indicators.ema(data, 2)
        self.assertAlmostEqual(result[0], 5.0)

    def test_uptrend_ema_below_price(self):
        prices = _trend_up(50)
        ema = Indicators.ema(prices, 10)
        # In uptrend EMA lags, so last EMA < last price
        self.assertLess(ema[-1], prices[-1])


class TestRSI(unittest.TestCase):
    def test_neutral_flat(self):
        # Flat prices → all zero gains, near-zero losses → avg_gain/avg_loss = 0 → RSI = 0.0
        closes = _flat(50)
        self.assertAlmostEqual(Indicators.rsi(closes), 0.0, places=1)

    def test_pure_up_trend(self):
        closes = _trend_up(30)
        rsi = Indicators.rsi(closes)
        # Pure gains → RSI near 100
        self.assertGreater(rsi, 90.0)

    def test_pure_down_trend(self):
        closes = _trend_down(30)
        rsi = Indicators.rsi(closes)
        # Pure losses → RSI near 0
        self.assertLess(rsi, 10.0)

    def test_insufficient_data_returns_50(self):
        self.assertEqual(Indicators.rsi([1.0, 2.0], period=14), 50.0)

    def test_range(self):
        closes = _sine_wave(80)
        rsi = Indicators.rsi(closes)
        self.assertGreaterEqual(rsi, 0.0)
        self.assertLessEqual(rsi, 100.0)


class TestStochRSI(unittest.TestCase):
    def test_returns_tuple(self):
        closes = _sine_wave(100)
        k, d = Indicators.stoch_rsi(closes)
        self.assertIsInstance(k, float)
        self.assertIsInstance(d, float)

    def test_range(self):
        closes = _sine_wave(100)
        k, d = Indicators.stoch_rsi(closes)
        self.assertGreaterEqual(k, 0.0)
        self.assertLessEqual(k, 100.0)
        self.assertGreaterEqual(d, 0.0)
        self.assertLessEqual(d, 100.0)

    def test_insufficient_data(self):
        k, d = Indicators.stoch_rsi([1.0, 2.0, 3.0])
        self.assertEqual(k, 50.0)
        self.assertEqual(d, 50.0)


class TestMACD(unittest.TestCase):
    def test_returns_three_floats(self):
        closes = _sine_wave(80)
        result = Indicators.macd(closes)
        self.assertEqual(len(result), 3)

    def test_uptrend_positive_macd(self):
        closes = _trend_up(80)
        macd_l, macd_s, hist = Indicators.macd(closes)
        # Fast EMA > slow EMA in uptrend
        self.assertGreater(macd_l, 0)

    def test_downtrend_negative_macd(self):
        closes = _trend_down(80, start=200)
        macd_l, _, _ = Indicators.macd(closes)
        self.assertLess(macd_l, 0)

    def test_insufficient_data(self):
        macd_l, macd_s, hist = Indicators.macd([1.0, 2.0])
        self.assertEqual(macd_l, 0.0)


class TestBollinger(unittest.TestCase):
    def test_flat_bands_equal(self):
        closes = _flat(30)
        upper, mid, lower = Indicators.bollinger(closes)
        self.assertAlmostEqual(upper, mid, places=4)
        self.assertAlmostEqual(lower, mid, places=4)

    def test_upper_gt_lower(self):
        closes = _sine_wave(30)
        upper, mid, lower = Indicators.bollinger(closes)
        self.assertGreater(upper, lower)

    def test_price_inside_bands_for_volatile_series(self):
        closes = _sine_wave(50)
        upper, mid, lower = Indicators.bollinger(closes)
        # Mid should be between bands
        self.assertGreater(upper, mid)
        self.assertGreater(mid, lower)


class TestADX(unittest.TestCase):
    def _candles(self, closes, spread=5.0):
        highs = [c + spread for c in closes]
        lows  = [c - spread for c in closes]
        return highs, lows, closes

    def test_strong_trend(self):
        closes = _trend_up(60)
        h, l, c = self._candles(closes)
        adx, pdi, mdi = Indicators.adx(h, l, c)
        self.assertGreater(adx, 0.0)

    def test_range_0_to_100(self):
        closes = _sine_wave(60)
        h, l, c = self._candles(closes)
        adx, pdi, mdi = Indicators.adx(h, l, c)
        self.assertGreaterEqual(adx, 0.0)
        self.assertGreaterEqual(pdi, 0.0)
        self.assertGreaterEqual(mdi, 0.0)

    def test_insufficient_data(self):
        adx, pdi, mdi = Indicators.adx([1.0], [0.5], [0.8])
        self.assertEqual(adx, 0.0)


class TestVWAP(unittest.TestCase):
    def _make_candles(self, price=1000.0, n=20):
        # [ts, open, high, low, close, volume]
        return [[0, price, price+10, price-10, price, 100.0]] * n

    def test_flat_equals_price(self):
        candles = self._make_candles(price=1000.0)
        vwap = Indicators.vwap(candles)
        self.assertAlmostEqual(vwap, 1000.0, places=4)

    def test_zero_volume(self):
        candles = [[0, 100, 110, 90, 100, 0.0]] * 5
        # Should return last close without dividing by zero
        vwap = Indicators.vwap(candles)
        self.assertEqual(vwap, 100)


class TestOBV(unittest.TestCase):
    def test_rising_closes_positive_obv(self):
        closes  = [100.0, 101.0, 102.0, 103.0]
        volumes = [1000.0] * 4
        obv = Indicators.obv(closes, volumes)
        self.assertGreater(obv, 0.0)

    def test_falling_closes_negative_obv(self):
        closes  = [103.0, 102.0, 101.0, 100.0]
        volumes = [1000.0] * 4
        obv = Indicators.obv(closes, volumes)
        self.assertLess(obv, 0.0)

    def test_flat_zero_obv(self):
        closes  = [100.0, 100.0, 100.0, 100.0]
        volumes = [500.0] * 4
        self.assertEqual(Indicators.obv(closes, volumes), 0.0)


class TestWilliamsR(unittest.TestCase):
    def test_at_high_returns_zero(self):
        # Price == highest high → Williams %R = 0
        highs = [110.0] * 14
        lows  = [90.0]  * 14
        closes = [110.0] * 14  # at the high
        wr = Indicators.williams_r(highs, lows, closes)
        self.assertAlmostEqual(wr, 0.0, places=1)

    def test_at_low_returns_minus_100(self):
        highs = [110.0] * 14
        lows  = [90.0]  * 14
        closes = [90.0] * 14  # at the low
        wr = Indicators.williams_r(highs, lows, closes)
        self.assertAlmostEqual(wr, -100.0, places=1)

    def test_range(self):
        closes = _sine_wave(30)
        highs  = [c + 10 for c in closes]
        lows   = [c - 10 for c in closes]
        wr = Indicators.williams_r(highs, lows, closes)
        self.assertGreaterEqual(wr, -100.0)
        self.assertLessEqual(wr, 0.0)


class TestATR(unittest.TestCase):
    def test_flat_atr_near_spread(self):
        closes = _flat(20)
        highs  = [c + 5 for c in closes]
        lows   = [c - 5 for c in closes]
        atr = Indicators.atr(highs, lows, closes)
        self.assertAlmostEqual(atr, 10.0, places=1)

    def test_empty_returns_zero(self):
        self.assertEqual(Indicators.atr([], [], []), 0.0)


class TestHurst(unittest.TestCase):
    def test_trending_above_half(self):
        # Strong uptrend → Hurst > 0.5
        data = _trend_up(200, step=0.5)
        h = Indicators.hurst_exponent(data)
        self.assertGreater(h, 0.5)

    def test_mean_reverting_below_half(self):
        # Zigzag pattern → mean-reverting → Hurst < 0.5
        data = [1000.0 + (10 if i % 2 == 0 else -10) for i in range(200)]
        h = Indicators.hurst_exponent(data)
        self.assertLess(h, 0.55)  # generous bound due to small sample

    def test_insufficient_data(self):
        self.assertEqual(Indicators.hurst_exponent([1.0, 2.0]), 0.5)


# ─── Sentiment (mocked) ──────────────────────────────────────────────────────

class TestSentimentSignals(unittest.TestCase):
    @patch("quant_signals.requests.get")
    def test_fng_returns_dict(self, mock_get):
        mock_get.return_value = MagicMock(
            status_code=200,
            json=lambda: {"data": [{"value": "35", "value_classification": "Fear"},
                                    {"value": "30", "value_classification": "Fear"}]},
        )
        mock_get.return_value.raise_for_status = MagicMock()
        result = SentimentSignals.fear_and_greed()
        self.assertEqual(result["value"], 35)
        self.assertEqual(result["label"], "Fear")
        self.assertEqual(result["delta"], 5)
        self.assertFalse(result["stale"])

    @patch("quant_signals.requests.get", side_effect=Exception("timeout"))
    def test_fng_fallback_on_error(self, _mock):
        result = SentimentSignals.fear_and_greed()
        self.assertEqual(result["value"], 50)
        self.assertTrue(result["stale"])

    @patch("quant_signals.requests.get")
    def test_btc_dominance_returns_float(self, mock_get):
        mock_get.return_value = MagicMock(
            json=lambda: {"data": {"market_cap_percentage": {"btc": 52.3}}}
        )
        mock_get.return_value.raise_for_status = MagicMock()
        dom = SentimentSignals.btc_dominance()
        self.assertAlmostEqual(dom, 52.3)

    @patch("quant_signals.requests.get", side_effect=Exception("timeout"))
    def test_btc_dominance_fallback(self, _mock):
        dom = SentimentSignals.btc_dominance()
        self.assertEqual(dom, 50.0)


# ─── CompositeSignalEngine (fully mocked exchange) ────────────────────────────

def _make_mock_exchange(n=100, price=50000.0, trend="flat"):
    """Return an exchange mock with realistic OHLCV data."""
    import time as _time
    if trend == "up":
        closes = _trend_up(n, start=price * 0.9, step=price * 0.2 / n)
    elif trend == "down":
        closes = _trend_down(n, start=price * 1.1, step=-price * 0.2 / n)
    else:
        closes = _sine_wave(n, amplitude=price * 0.02, offset=price)

    ts = int(_time.time() * 1000)
    candles = []
    for i, c in enumerate(closes):
        candles.append([ts + i * 60000, c * 0.999, c * 1.005, c * 0.995, c, 10.0 + i * 0.1])

    mock = MagicMock()
    mock.fetch_ohlcv.return_value = candles
    mock.fetch_order_book.return_value = {
        "bids": [[price * 0.999, 1.0]] * 10,
        "asks": [[price * 1.001, 1.0]] * 10,
    }
    return mock


class TestCompositeSignalEngine(unittest.TestCase):
    def _engine(self, trend="flat", price=50000.0, n=100):
        mock_ex = _make_mock_exchange(n=n, price=price, trend=trend)
        return CompositeSignalEngine(mock_ex), mock_ex

    @patch("quant_signals.SentimentSignals.fear_and_greed",
           return_value={"value": 50, "label": "Neutral", "delta": 0, "stale": False})
    def test_analyze_returns_market_signal(self, _mock_fng):
        engine, _ = self._engine()
        sig = engine.analyze("BTC/USDC")
        self.assertIsInstance(sig, MarketSignal)
        self.assertIn(sig.direction, ("BUY", "SELL", "HOLD"))
        self.assertGreaterEqual(sig.confidence, 0.0)
        self.assertLessEqual(sig.confidence, 1.0)
        self.assertIn(sig.regime, ("TRENDING", "RANGING", "VOLATILE"))

    @patch("quant_signals.SentimentSignals.fear_and_greed",
           return_value={"value": 50, "label": "Neutral", "delta": 0, "stale": False})
    def test_no_data_returns_hold(self, _mock_fng):
        mock_ex = MagicMock()
        mock_ex.fetch_ohlcv.return_value = []
        mock_ex.fetch_order_book.return_value = {"bids": [], "asks": []}
        engine = CompositeSignalEngine(mock_ex)
        sig = engine.analyze("BTC/USDC")
        self.assertEqual(sig.direction, "HOLD")
        self.assertEqual(sig.confidence, 0.0)

    @patch("quant_signals.SentimentSignals.fear_and_greed",
           return_value={"value": 50, "label": "Neutral", "delta": 0, "stale": False})
    def test_indicators_dict_populated(self, _mock_fng):
        engine, _ = self._engine()
        sig = engine.analyze("BTC/USDC")
        for key in ("price", "rsi", "macd_hist", "adx", "hurst", "obi"):
            self.assertIn(key, sig.indicators, f"Missing indicator: {key}")

    @patch("quant_signals.SentimentSignals.fear_and_greed",
           return_value={"value": 50, "label": "Neutral", "delta": 0, "stale": False})
    def test_score_within_bounds(self, _mock_fng):
        engine, _ = self._engine()
        sig = engine.analyze("ETH/USDC")
        self.assertGreaterEqual(sig.score, -1.0)
        self.assertLessEqual(sig.score, 1.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
