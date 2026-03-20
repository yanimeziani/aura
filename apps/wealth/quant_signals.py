"""
quant_signals.py — Professional signal engine
Indicators: MACD, Bollinger Bands, Stoch RSI, ADX, VWAP, OBV, Williams %R
Sentiment: Fear & Greed, Whale Alerts, CoinGlass liquidations
"""

import logging
import math
import time
import requests
from dataclasses import dataclass, field

log = logging.getLogger(__name__)

# ─── INDICATOR LIBRARY ────────────────────────────────────────────────────────

class Indicators:

    @staticmethod
    def sma(data: list[float], period: int) -> float:
        if len(data) < period:
            return data[-1]
        return sum(data[-period:]) / period

    @staticmethod
    def ema(data: list[float], period: int) -> list[float]:
        k = 2 / (period + 1)
        result = [data[0]]
        for v in data[1:]:
            result.append(v * k + result[-1] * (1 - k))
        return result

    @staticmethod
    def rsi(closes: list[float], period=14) -> float:
        if len(closes) < period + 1:
            return 50.0
        deltas = [closes[i] - closes[i-1] for i in range(1, len(closes))]
        gains = [d if d > 0 else 0 for d in deltas[-period:]]
        losses = [-d if d < 0 else 0 for d in deltas[-period:]]
        avg_gain = sum(gains) / period
        avg_loss = sum(losses) / period or 1e-10
        rs = avg_gain / avg_loss
        return 100 - (100 / (1 + rs))

    @staticmethod
    def stoch_rsi(closes: list[float], rsi_period=14, stoch_period=14,
                   smooth_k=3, smooth_d=3) -> tuple[float, float]:
        """Returns (K%, D%) — both 0-100."""
        if len(closes) < rsi_period + stoch_period + smooth_k + smooth_d:
            return 50.0, 50.0
        rsi_series = []
        for i in range(rsi_period, len(closes)):
            rsi_series.append(Indicators.rsi(closes[:i+1], rsi_period))
        if len(rsi_series) < stoch_period:
            return 50.0, 50.0
        raw_k = []
        for i in range(stoch_period - 1, len(rsi_series)):
            window = rsi_series[i - stoch_period + 1: i + 1]
            lo, hi = min(window), max(window)
            raw_k.append(((rsi_series[i] - lo) / (hi - lo + 1e-10)) * 100)
        k_ema = Indicators.ema(raw_k, smooth_k)
        d_ema = Indicators.ema(k_ema, smooth_d)
        return round(k_ema[-1], 2), round(d_ema[-1], 2)

    @staticmethod
    def macd(closes: list[float], fast=12, slow=26, signal=9) -> tuple[float, float, float]:
        """Returns (macd_line, signal_line, histogram)."""
        if len(closes) < slow + signal:
            return 0.0, 0.0, 0.0
        ema_fast = Indicators.ema(closes, fast)
        ema_slow = Indicators.ema(closes, slow)
        macd_line = [f - s for f, s in zip(ema_fast[-len(ema_slow):], ema_slow)]
        if len(macd_line) < signal:
            return macd_line[-1], macd_line[-1], 0.0
        signal_line = Indicators.ema(macd_line, signal)
        hist = macd_line[-1] - signal_line[-1]
        return round(macd_line[-1], 6), round(signal_line[-1], 6), round(hist, 6)

    @staticmethod
    def bollinger(closes: list[float], period=20, std_mult=2.0) -> tuple[float, float, float]:
        """Returns (upper, mid, lower)."""
        if len(closes) < period:
            p = closes[-1]
            return p, p, p
        window = closes[-period:]
        mid = sum(window) / period
        variance = sum((x - mid) ** 2 for x in window) / period
        std = math.sqrt(variance)
        return round(mid + std_mult * std, 6), round(mid, 6), round(mid - std_mult * std, 6)

    @staticmethod
    def adx(highs: list[float], lows: list[float], closes: list[float],
             period=14) -> tuple[float, float, float]:
        """Returns (ADX, +DI, -DI). ADX > 25 = trending."""
        if len(closes) < period + 1:
            return 0.0, 0.0, 0.0
        tr_list, plus_dm, minus_dm = [], [], []
        for i in range(1, len(closes)):
            h, l, pc = highs[i], lows[i], closes[i-1]
            tr = max(h - l, abs(h - pc), abs(l - pc))
            tr_list.append(tr)
            up = highs[i] - highs[i-1]
            dn = lows[i-1] - lows[i]
            plus_dm.append(up if up > dn and up > 0 else 0)
            minus_dm.append(dn if dn > up and dn > 0 else 0)

        def wilder_smooth(data, n):
            s = sum(data[:n])
            result = [s]
            for v in data[n:]:
                s = s - s / n + v
                result.append(s)
            return result

        n = period
        atr = wilder_smooth(tr_list, n)
        pdi = wilder_smooth(plus_dm, n)
        mdi = wilder_smooth(minus_dm, n)
        dx_list = []
        for a, p, m in zip(atr[-len(pdi):], pdi, mdi):
            pdi_val = (p / a * 100) if a else 0
            mdi_val = (m / a * 100) if a else 0
            dx = abs(pdi_val - mdi_val) / (pdi_val + mdi_val + 1e-10) * 100
            dx_list.append(dx)
        if len(dx_list) < n:
            return 0.0, 0.0, 0.0
        adx_val = sum(dx_list[-n:]) / n
        last_atr = atr[-1]
        plus_di = (pdi[-1] / last_atr * 100) if last_atr else 0
        minus_di = (mdi[-1] / last_atr * 100) if last_atr else 0
        return round(adx_val, 2), round(plus_di, 2), round(minus_di, 2)

    @staticmethod
    def vwap(candles: list) -> float:
        """VWAP = Σ(typical_price × volume) / Σvolume."""
        num, den = 0.0, 0.0
        for c in candles:
            tp = (c[2] + c[3] + c[4]) / 3  # high + low + close / 3
            vol = c[5]
            num += tp * vol
            den += vol
        return round(num / den, 6) if den else candles[-1][4]

    @staticmethod
    def obv(closes: list[float], volumes: list[float]) -> float:
        """On-Balance Volume — positive OBV = accumulation."""
        obv = 0.0
        for i in range(1, len(closes)):
            if closes[i] > closes[i-1]:
                obv += volumes[i]
            elif closes[i] < closes[i-1]:
                obv -= volumes[i]
        return obv

    @staticmethod
    def williams_r(highs: list[float], lows: list[float],
                    closes: list[float], period=14) -> float:
        """Williams %R: -100 to 0. Below -80 = oversold, above -20 = overbought."""
        if len(closes) < period:
            return -50.0
        hh = max(highs[-period:])
        ll = min(lows[-period:])
        return round(((hh - closes[-1]) / (hh - ll + 1e-10)) * -100, 2)

    @staticmethod
    def atr(highs: list[float], lows: list[float],
             closes: list[float], period=14) -> float:
        """Average True Range — volatility measure."""
        tr_list = []
        for i in range(1, len(closes)):
            tr = max(highs[i]-lows[i], abs(highs[i]-closes[i-1]), abs(lows[i]-closes[i-1]))
            tr_list.append(tr)
        if not tr_list:
            return 0.0
        return round(sum(tr_list[-period:]) / min(period, len(tr_list)), 6)

    @staticmethod
    def hurst_exponent(data: list[float], max_lag=20) -> float:
        """
        Hurst exponent:
          H > 0.55 → trending (momentum works)
          H ~ 0.5  → random walk
          H < 0.45 → mean-reverting
        """
        if len(data) < max_lag * 2:
            return 0.5
        lags = range(2, max_lag)
        tau = [math.sqrt(abs(
            sum((data[i + lag] - data[i]) ** 2 for i in range(len(data) - lag)) / (len(data) - lag)
        )) for lag in lags]
        if not tau or tau[0] == 0:
            return 0.5
        log_lags = [math.log(l) for l in lags]
        log_tau = [math.log(t + 1e-10) for t in tau]
        n = len(log_lags)
        sx = sum(log_lags)
        sy = sum(log_tau)
        sxy = sum(x * y for x, y in zip(log_lags, log_tau))
        sxx = sum(x * x for x in log_lags)
        slope = (n * sxy - sx * sy) / (n * sxx - sx * sx + 1e-10)
        return round(slope, 4)


# ─── SENTIMENT SIGNALS ───────────────────────────────────────────────────────

class SentimentSignals:
    # Track last-success timestamps for staleness detection
    _fng_last_ok: float = 0.0
    _btc_dom_last_ok: float = 0.0
    _coinglass_last_ok: float = 0.0
    STALE_AFTER_S: float = 300.0  # warn if data older than 5 minutes

    @staticmethod
    def fear_and_greed() -> dict:
        """Returns value (0-100) and classification. Logs on failure."""
        try:
            r = requests.get("https://api.alternative.me/fng/?limit=2", timeout=5)
            r.raise_for_status()
            data = r.json()["data"]
            current = int(data[0]["value"])
            previous = int(data[1]["value"]) if len(data) > 1 else current
            SentimentSignals._fng_last_ok = time.time()
            return {
                "value": current,
                "label": data[0]["value_classification"],
                "delta": current - previous,
                "stale": False,
            }
        except Exception as exc:
            age = time.time() - SentimentSignals._fng_last_ok
            log.warning("F&G API unavailable (%.0fs stale): %s — using neutral default", age, exc)
            return {"value": 50, "label": "Neutral", "delta": 0, "stale": True}

    @staticmethod
    def coinglass_liquidations(symbol="BTC") -> dict:
        """
        Fetch recent liquidation data from CoinGlass public API.
        High liquidations = volatility incoming. Logs on failure.
        """
        try:
            url = f"https://open-api.coinglass.com/public/v2/liquidation_history?symbol={symbol}&time_type=h4"
            r = requests.get(url, timeout=5)
            if r.status_code == 200:
                data = r.json().get("data", [])
                if data:
                    latest = data[-1]
                    SentimentSignals._coinglass_last_ok = time.time()
                    return {
                        "long_liq_usd": float(latest.get("longLiquidationUsd", 0)),
                        "short_liq_usd": float(latest.get("shortLiquidationUsd", 0)),
                        "dominant": "longs" if float(latest.get("longLiquidationUsd", 0)) >
                                               float(latest.get("shortLiquidationUsd", 0)) else "shorts",
                        "stale": False,
                    }
            log.warning("CoinGlass returned status %d for %s", r.status_code, symbol)
        except Exception as exc:
            age = time.time() - SentimentSignals._coinglass_last_ok
            log.warning("CoinGlass API unavailable (%.0fs stale): %s", age, exc)
        return {"long_liq_usd": 0, "short_liq_usd": 0, "dominant": "unknown", "stale": True}

    @staticmethod
    def btc_dominance() -> float:
        """BTC dominance % from CoinGecko global data. Logs on failure."""
        try:
            r = requests.get("https://api.coingecko.com/api/v3/global", timeout=5)
            r.raise_for_status()
            dom = round(r.json()["data"]["market_cap_percentage"].get("btc", 50.0), 2)
            SentimentSignals._btc_dom_last_ok = time.time()
            return dom
        except Exception as exc:
            age = time.time() - SentimentSignals._btc_dom_last_ok
            log.warning("BTC dominance API unavailable (%.0fs stale): %s — defaulting to 50%%", age, exc)
            return 50.0

    @staticmethod
    def whale_alert_recent(min_usd=1_000_000) -> list[dict]:
        """
        Public whale-alert style from blockchain APIs.
        Uses free CryptoQuant-style data via open endpoints.
        """
        # NOTE: Whale Alert API requires a key for real data.
        # Using CoinGecko large tx as proxy (free, no key needed).
        try:
            r = requests.get(
                "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart"
                "?vs_currency=usd&days=1&interval=hourly",
                timeout=5
            )
            r.raise_for_status()
            volumes = r.json().get("total_volumes", [])
            if not volumes:
                return []
            recent_vol = volumes[-1][1]
            avg_vol = sum(v[1] for v in volumes) / len(volumes)
            if recent_vol > avg_vol * 1.5:
                return [{"type": "volume_spike", "usd": recent_vol,
                          "vs_avg": round(recent_vol / avg_vol, 2)}]
        except Exception as exc:
            log.warning("Whale alert proxy unavailable: %s", exc)
        return []


# ─── COMPOSITE SIGNAL ─────────────────────────────────────────────────────────

@dataclass
class MarketSignal:
    symbol: str
    direction: str          # "BUY" | "SELL" | "HOLD"
    confidence: float       # 0.0 – 1.0
    regime: str             # "TRENDING" | "RANGING" | "VOLATILE"
    score: float            # raw score before clamping
    reasons: list[str] = field(default_factory=list)
    indicators: dict = field(default_factory=dict)


class CompositeSignalEngine:
    """
    Weights (total = 1.0):
      Technical momentum  0.40
      Microstructure      0.25
      Sentiment           0.20
      On-chain / macro    0.15
    """

    def __init__(self, exchange):
        self.exchange = exchange

    def _fetch_candles(self, symbol: str, tf="5m", limit=100) -> list:
        try:
            return self.exchange.fetch_ohlcv(symbol, tf, limit=limit)
        except Exception:
            return []

    def _fetch_book(self, symbol: str, depth=20) -> dict:
        try:
            return self.exchange.fetch_order_book(symbol, limit=depth)
        except Exception:
            return {"bids": [], "asks": []}

    def _book_imbalance(self, book: dict) -> float:
        bids = book.get("bids", [])[:10]
        asks = book.get("asks", [])[:10]
        bv = sum(b[1] for b in bids)
        av = sum(a[1] for a in asks)
        total = bv + av
        return (bv - av) / total if total else 0.0

    def _spread_pct(self, book: dict) -> float:
        bids = book.get("bids", [])
        asks = book.get("asks", [])
        if not bids or not asks:
            return 1.0
        return (asks[0][0] - bids[0][0]) / bids[0][0] * 100

    def analyze(self, symbol: str, candles_5m: list = None,
                 candles_1h: list = None) -> MarketSignal:

        if candles_5m is None:
            candles_5m = self._fetch_candles(symbol, "5m", 100)
        if candles_1h is None:
            candles_1h = self._fetch_candles(symbol, "1h", 60)

        if not candles_5m:
            return MarketSignal(symbol, "HOLD", 0.0, "UNKNOWN", 0.0, ["No data"])

        # ── Extract series ──────────────────────────────────────
        closes  = [c[4] for c in candles_5m]
        highs   = [c[2] for c in candles_5m]
        lows    = [c[3] for c in candles_5m]
        volumes = [c[5] for c in candles_5m]
        price   = closes[-1]

        closes_1h = [c[4] for c in candles_1h] if candles_1h else closes

        # ── Compute indicators ──────────────────────────────────
        rsi_val          = Indicators.rsi(closes)
        stoch_k, stoch_d = Indicators.stoch_rsi(closes)
        macd_l, macd_s, macd_h = Indicators.macd(closes)
        bb_up, bb_mid, bb_lo = Indicators.bollinger(closes)
        adx_val, plus_di, minus_di = Indicators.adx(highs, lows, closes)
        vwap_val         = Indicators.vwap(candles_5m)
        obv_val          = Indicators.obv(closes, volumes)
        wr_val           = Indicators.williams_r(highs, lows, closes)
        atr_val          = Indicators.atr(highs, lows, closes)
        hurst            = Indicators.hurst_exponent(closes_1h)

        # Volume spike
        avg_vol = sum(volumes[-20:]) / min(20, len(volumes))
        vol_spike = volumes[-1] > avg_vol * 2.0

        # EMA trend (higher TF)
        ema20_1h = Indicators.ema(closes_1h, 20)[-1] if len(closes_1h) >= 20 else price
        ema50_1h = Indicators.ema(closes_1h, 50)[-1] if len(closes_1h) >= 50 else price

        # ── Regime detection ───────────────────────────────────
        if atr_val / price > 0.025:
            regime = "VOLATILE"
        elif adx_val > 25 and hurst > 0.52:
            regime = "TRENDING"
        else:
            regime = "RANGING"

        # ── Sentiment ──────────────────────────────────────────
        fng = SentimentSignals.fear_and_greed()
        book = self._fetch_book(symbol)
        obi = self._book_imbalance(book)
        spread = self._spread_pct(book)

        # ── Score assembly ─────────────────────────────────────
        score = 0.0
        reasons = []
        indicators_snapshot = {
            "price": price, "rsi": rsi_val, "stoch_k": stoch_k, "stoch_d": stoch_d,
            "macd_hist": macd_h, "bb_upper": bb_up, "bb_lower": bb_lo,
            "adx": adx_val, "+DI": plus_di, "-DI": minus_di,
            "vwap": vwap_val, "obv": obv_val, "williams_r": wr_val,
            "atr": atr_val, "hurst": hurst, "obi": obi, "spread_pct": spread,
            "fng": fng["value"], "vol_spike": vol_spike, "regime": regime,
        }

        # ── BLOCK: Technical momentum (weight 0.40) ──────────────
        tech_score = 0.0

        # RSI
        if rsi_val < 30:
            tech_score += 0.3; reasons.append(f"RSI oversold ({rsi_val:.1f})")
        elif rsi_val < 40:
            tech_score += 0.15; reasons.append(f"RSI approaching oversold ({rsi_val:.1f})")
        elif rsi_val > 70:
            tech_score -= 0.3; reasons.append(f"RSI overbought ({rsi_val:.1f})")
        elif rsi_val > 60:
            tech_score -= 0.15; reasons.append(f"RSI approaching overbought ({rsi_val:.1f})")

        # Stochastic RSI
        if stoch_k < 20 and stoch_d < 20:
            tech_score += 0.2; reasons.append(f"StochRSI oversold K={stoch_k} D={stoch_d}")
        elif stoch_k > 80 and stoch_d > 80:
            tech_score -= 0.2; reasons.append(f"StochRSI overbought K={stoch_k} D={stoch_d}")
        elif stoch_k > stoch_d and stoch_k < 80:
            tech_score += 0.1; reasons.append("StochRSI bullish cross")
        elif stoch_k < stoch_d and stoch_k > 20:
            tech_score -= 0.1; reasons.append("StochRSI bearish cross")

        # MACD
        if macd_h > 0 and macd_l > macd_s:
            tech_score += 0.2; reasons.append(f"MACD bullish (hist={macd_h:.5f})")
        elif macd_h < 0 and macd_l < macd_s:
            tech_score -= 0.2; reasons.append(f"MACD bearish (hist={macd_h:.5f})")

        # Bollinger Bands
        if price < bb_lo:
            tech_score += 0.2; reasons.append(f"Below Bollinger lower band")
        elif price > bb_up:
            tech_score -= 0.2; reasons.append(f"Above Bollinger upper band")

        # Williams %R
        if wr_val < -80:
            tech_score += 0.15; reasons.append(f"Williams %R oversold ({wr_val})")
        elif wr_val > -20:
            tech_score -= 0.15; reasons.append(f"Williams %R overbought ({wr_val})")

        # ADX + DI
        if adx_val > 25:
            if plus_di > minus_di:
                tech_score += 0.15; reasons.append(f"Strong uptrend ADX={adx_val:.1f} +DI>{minus_di:.1f}")
            else:
                tech_score -= 0.15; reasons.append(f"Strong downtrend ADX={adx_val:.1f} -DI>{plus_di:.1f}")

        # 1H EMA trend
        if ema20_1h > ema50_1h:
            tech_score += 0.1; reasons.append("1H uptrend (EMA20>EMA50)")
        else:
            tech_score -= 0.1; reasons.append("1H downtrend (EMA20<EMA50)")

        tech_score = max(-1.0, min(1.0, tech_score))
        score += tech_score * 0.40

        # ── BLOCK: Microstructure (weight 0.25) ──────────────────
        micro_score = 0.0

        # VWAP position
        if price < vwap_val * 0.999:
            micro_score += 0.3; reasons.append(f"Price below VWAP (discount)")
        elif price > vwap_val * 1.001:
            micro_score -= 0.3; reasons.append(f"Price above VWAP (premium)")

        # Order book imbalance
        if obi > 0.2:
            micro_score += 0.4; reasons.append(f"Strong bid pressure OBI={obi:.2f}")
        elif obi > 0.1:
            micro_score += 0.2; reasons.append(f"Mild bid pressure OBI={obi:.2f}")
        elif obi < -0.2:
            micro_score -= 0.4; reasons.append(f"Strong ask pressure OBI={obi:.2f}")
        elif obi < -0.1:
            micro_score -= 0.2; reasons.append(f"Mild ask pressure OBI={obi:.2f}")

        # Volume spike amplifies direction
        if vol_spike:
            micro_score *= 1.3; reasons.append("Volume spike — institutional activity")

        # Tight spread = liquid = trust the signal more
        if spread > 0.05:
            micro_score *= 0.7; reasons.append(f"Wide spread {spread:.3f}% — reduced confidence")

        micro_score = max(-1.0, min(1.0, micro_score))
        score += micro_score * 0.25

        # ── BLOCK: Sentiment (weight 0.20) ───────────────────────
        sent_score = 0.0
        fv = fng["value"]

        if fv <= 20:
            # Extreme fear → strong contrarian buy
            sent_score += 0.8; reasons.append(f"Extreme fear F&G={fv} → contrarian BUY")
        elif fv <= 35:
            sent_score += 0.4; reasons.append(f"Fear F&G={fv} → mild contrarian BUY")
        elif fv >= 80:
            sent_score -= 0.6; reasons.append(f"Extreme greed F&G={fv} → caution/SELL")
        elif fv >= 65:
            sent_score -= 0.3; reasons.append(f"Greed F&G={fv} → mild caution")

        # F&G momentum (rising vs falling)
        if fng["delta"] > 5:
            sent_score -= 0.2; reasons.append(f"Greed accelerating (Δ={fng['delta']})")
        elif fng["delta"] < -5:
            sent_score += 0.2; reasons.append(f"Fear accelerating (Δ={fng['delta']}) → reversal soon")

        sent_score = max(-1.0, min(1.0, sent_score))
        score += sent_score * 0.20

        # ── BLOCK: On-chain / macro (weight 0.15) ────────────────
        macro_score = 0.0

        # OBV trend (5-period vs 20-period)
        obv_series = []
        for i in range(1, len(closes)):
            prev = obv_series[-1] if obv_series else 0
            obv_series.append(prev + (volumes[i] if closes[i] > closes[i-1] else -volumes[i]))
        if len(obv_series) >= 20:
            obv_5  = sum(obv_series[-5:]) / 5
            obv_20 = sum(obv_series[-20:]) / 20
            if obv_5 > obv_20 * 1.05:
                macro_score += 0.4; reasons.append("OBV rising — accumulation")
            elif obv_5 < obv_20 * 0.95:
                macro_score -= 0.4; reasons.append("OBV falling — distribution")

        # Hurst exponent
        if hurst > 0.6:
            macro_score += 0.2 * math.copysign(1, score)
            reasons.append(f"Hurst={hurst} → trending market, momentum favored")
        elif hurst < 0.4:
            macro_score -= 0.2 * math.copysign(1, score)
            reasons.append(f"Hurst={hurst} → mean-reversion market")

        macro_score = max(-1.0, min(1.0, macro_score))
        score += macro_score * 0.15

        # ── Regime override ────────────────────────────────────
        if regime == "VOLATILE":
            # In extreme volatility, reduce conviction — widen filter
            score *= 0.6
            reasons.append("VOLATILE regime — conviction dampened")

        # ── Final decision ─────────────────────────────────────
        score = max(-1.0, min(1.0, score))
        confidence = abs(score)

        if score >= 0.35:
            direction = "BUY"
        elif score <= -0.35:
            direction = "SELL"
        else:
            direction = "HOLD"

        return MarketSignal(
            symbol=symbol,
            direction=direction,
            confidence=round(confidence, 3),
            regime=regime,
            score=round(score, 4),
            reasons=reasons,
            indicators=indicators_snapshot,
        )
