#!/usr/bin/env python3
"""
Backtest strategi "Flag Breakout XAU" (tren M30, pola & entry M5).

Aturan yang diuji (sama dengan indikator flag_breakout_xau.pine):
  1. Filter   : jam sesi WIB, tidak ada berita besar (opsional), batas harian/mingguan.
  2. Arah     : candle M30 terakhir yang sudah selesai ditutup di atas EMA50 dan EMA50
                lebih tinggi dari 10 candle sebelumnya -> hanya BUY (kebalikannya SELL).
  3. Pola M5  : impuls >= 2 x ATR dalam <= 6 candle, lalu konsolidasi 4-15 candle
                yang tidak melewati puncak impuls dan koreksinya <= 50% impuls.
  4. Entry    : candle M5 ditutup di luar kotak, badan >= 50% panjang candle,
                panjang candle <= 1,5 x ATR. Masuk di open candle berikutnya.
  5. SL / TP  : SL di sisi kotak yang berlawanan + 0,3 x ATR (lewati bila > 2,5 x ATR).
                TP1 = 1R (tutup 50%, SL ke break even), TP2 = 2R.
                Keluar awal: close kembali ke dalam kotak, atau TP1 belum kena
                setelah 12 candle. Sisa posisi ditutup paksa setelah 48 candle.
  6. Risiko   : 1% per posisi, maks 3 posisi/hari, berhenti setelah 2 kalah
                atau -2% per hari, -5% per minggu.

Asumsi konservatif: data harga = BID; spread dibayar saat BUY masuk dan SELL keluar;
jika SL dan TP tersentuh di candle yang sama, SL dianggap kena lebih dulu.

Contoh:
  python backtest_flag_breakout.py data.csv
  python backtest_flag_breakout.py data.csv --spread 0.3 --equity 1000 --out hasil
  python backtest_flag_breakout.py data.csv --news berita.csv --from 2026-01-01
"""
from __future__ import annotations

import argparse
import math
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path

import numpy as np
import pandas as pd

WIB = "Asia/Jakarta"


# ============================== PARAMETER ==============================
@dataclass
class Params:
    ema_len: int = 50
    slope_lookback: int = 10
    atr_len: int = 14
    impulse_mult: float = 2.0
    impulse_max_bars: int = 6
    cons_min: int = 4
    cons_max: int = 15
    max_retrace: float = 0.5
    body_min: float = 0.5
    max_breakout_atr: float = 1.5
    sl_buffer_atr: float = 0.3
    max_sl_atr: float = 2.5
    tp1_r: float = 1.0
    tp2_r: float = 2.0
    tp1_close_frac: float = 0.5
    exit_on_fail: bool = True     # keluar bila close kembali ke dalam kotak
    time_exit_bars: int = 12
    runner_max_bars: int = 48
    sessions: list = field(default_factory=lambda: [("14:00", "17:00"), ("19:30", "23:00")])
    spread: float = 0.30          # dolar per ons
    equity: float = 1000.0
    risk_pct: float = 1.0
    contract_size: float = 100.0  # ons per 1 lot
    min_lot: float = 0.01
    lot_step: float = 0.01
    allow_min_lot: bool = False   # paksa 0,01 lot walau risiko > risk_pct
    max_trades_day: int = 3
    max_losses_day: int = 2
    max_daily_loss_pct: float = 2.0
    max_weekly_loss_pct: float = 5.0
    news_block_min: int = 30
    news_exit_min: int = 15


# ============================== DATA ==============================
def load_ohlc(path: str, data_tz: str = "UTC") -> pd.DataFrame:
    """Baca CSV OHLC (Dukascopy, ekspor MT4/MT5, TradingView, dll) lalu ubah ke M5.

    Kolom waktu yang dikenali: timestamp (epoch ms/s), time, datetime, date, atau date + time.
    """
    df = pd.read_csv(path, sep=None, engine="python")
    df.columns = [c.strip().strip("<>").lower() for c in df.columns]

    if "timestamp" in df.columns and np.issubdtype(df["timestamp"].dtype, np.number):
        unit = "ms" if df["timestamp"].iloc[0] > 1e11 else "s"
        ts = pd.to_datetime(df["timestamp"], unit=unit, utc=True)
    else:
        if "date" in df.columns and "time" in df.columns:
            raw = df["date"].astype(str) + " " + df["time"].astype(str)
        else:
            col = next((c for c in ("datetime", "time", "date", "timestamp") if c in df.columns), None)
            if col is None:
                sys.exit(f"Kolom waktu tidak ditemukan. Kolom yang ada: {list(df.columns)}")
            raw = df[col].astype(str)
        ts = pd.to_datetime(raw.str.replace(".", "-", regex=False), utc=False)
        ts = ts.dt.tz_localize(data_tz) if ts.dt.tz is None else ts
        ts = ts.dt.tz_convert("UTC")

    out = pd.DataFrame({c: df[c].astype(float) for c in ("open", "high", "low", "close")})
    out.index = ts
    vol_col = next((c for c in ("volume", "tickvol", "vol") if c in df.columns), None)
    if vol_col:
        out["volume"] = df[vol_col].astype(float).values
    out = out.sort_index()
    out = out[~out.index.duplicated()]

    # Buang candle "mati" (akhir pekan / pasar tutup): volume 0 atau OHLC sama semua
    dead = (out["high"] == out["low"])
    if "volume" in out.columns:
        dead |= out["volume"] <= 0
    out = out[~dead]

    m5 = out.resample("5min", label="left", closed="left").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last"}
    ).dropna()
    m5.index = m5.index.as_unit("ns")
    return m5


def load_news(path: str | None) -> np.ndarray:
    """CSV berita: kolom 'time' (UTC, mis. 2026-03-18 18:00). Kolom lain diabaikan."""
    if not path:
        return np.array([], dtype="datetime64[ns]")
    df = pd.read_csv(path)
    df.columns = [c.strip().lower() for c in df.columns]
    t = pd.to_datetime(df["time"], utc=True)
    return np.sort(t.dt.tz_convert(None).values.astype("datetime64[ns]"))


# ============================== INDIKATOR ==============================
def atr(df: pd.DataFrame, n: int) -> np.ndarray:
    """ATR Wilder (RMA), sama dengan ta.atr di TradingView."""
    prev_close = df["close"].shift(1)
    tr = pd.concat([
        df["high"] - df["low"],
        (df["high"] - prev_close).abs(),
        (df["low"] - prev_close).abs(),
    ], axis=1).max(axis=1)
    tr.iloc[0] = df["high"].iloc[0] - df["low"].iloc[0]
    return tr.ewm(alpha=1.0 / n, adjust=False).mean().values


def trend_m30(m5: pd.DataFrame, p: Params) -> np.ndarray:
    """+1 = hanya BUY, -1 = hanya SELL, 0 = tidak trading.

    Memakai candle M30 terakhir yang SUDAH SELESAI saat candle M5 dibuka
    (sama dengan request.security(..., expr[1], lookahead_on) di Pine).
    """
    m30 = m5.resample("30min", label="left", closed="left").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last"}
    ).dropna()
    ema = m30["close"].ewm(span=p.ema_len, adjust=False).mean()
    up = (m30["close"] > ema) & (ema > ema.shift(p.slope_lookback))
    dn = (m30["close"] < ema) & (ema < ema.shift(p.slope_lookback))
    t = pd.DataFrame({"trend": np.where(up, 1, np.where(dn, -1, 0))},
                     index=m30.index + pd.Timedelta(minutes=30))  # waktu candle M30 selesai
    t = t.iloc[p.ema_len:]  # EMA belum stabil di awal data
    t.index = t.index.as_unit("ns")
    merged = pd.merge_asof(
        pd.DataFrame(index=m5.index), t, left_index=True, right_index=True, direction="backward"
    )
    return merged["trend"].fillna(0).astype(int).values


def session_mask(index: pd.DatetimeIndex, sessions) -> np.ndarray:
    local = index.tz_convert(WIB)
    minutes = local.hour * 60 + local.minute
    mask = np.zeros(len(index), dtype=bool)
    for start, end in sessions:
        sh, sm = map(int, start.split(":"))
        eh, em = map(int, end.split(":"))
        mask |= (minutes >= sh * 60 + sm) & (minutes < eh * 60 + em)
    return mask


# ============================== DETEKSI POLA ==============================
def detect(t: int, d: int, o, h, l, c, a, p: Params):
    """Cek apakah candle t adalah breakout valid dari pola flag/kotak.

    d = +1 (BUY) atau -1 (SELL). Mengembalikan (panjang_kotak, atas, bawah) atau None.
    """
    rng = h[t] - l[t]
    if rng <= 0 or abs(c[t] - o[t]) < p.body_min * rng or rng > p.max_breakout_atr * a[t]:
        return None
    if (c[t] - o[t]) * d <= 0:  # candle breakout harus searah
        return None

    for n in range(p.cons_min, p.cons_max + 1):
        s = t - n                       # candle pertama konsolidasi
        e = s - 1                       # candle terakhir impuls
        if e - p.impulse_max_bars + 1 < 0:
            return None
        box_hi = h[s:t].max()
        box_lo = l[s:t].min()
        if d == 1 and c[t] <= box_hi:
            continue
        if d == -1 and c[t] >= box_lo:
            continue

        imp_hi, imp_lo = -math.inf, math.inf
        pos_hi = pos_lo = e
        for k in range(1, p.impulse_max_bars + 1):
            j = e - k + 1               # perluas jendela impuls ke belakang
            if h[j] > imp_hi:
                imp_hi, pos_hi = h[j], j
            if l[j] < imp_lo:
                imp_lo, pos_lo = l[j], j
            move = imp_hi - imp_lo
            if move < p.impulse_mult * a[e]:
                continue
            if d == 1:
                ordered = pos_lo < pos_hi or (pos_lo == pos_hi and c[j] > o[j])
                if ordered and box_hi <= imp_hi and (imp_hi - box_lo) <= p.max_retrace * move:
                    return n, box_hi, box_lo
            else:
                ordered = pos_hi < pos_lo or (pos_lo == pos_hi and c[j] < o[j])
                if ordered and box_lo >= imp_lo and (box_hi - imp_lo) <= p.max_retrace * move:
                    return n, box_hi, box_lo
    return None


# ============================== SIMULASI ==============================
def backtest(m5: pd.DataFrame, p: Params, news: np.ndarray) -> tuple[pd.DataFrame, pd.Series]:
    o, h, l, c = (m5[x].values for x in ("open", "high", "low", "close"))
    a = atr(m5, p.atr_len)
    trend = trend_m30(m5, p)
    in_sess = session_mask(m5.index, p.sessions)
    times = m5.index.tz_convert(None).values.astype("datetime64[ns]")
    local = m5.index.tz_convert(WIB)
    day_key = local.strftime("%Y-%m-%d").values
    week_key = (local.isocalendar().year.astype(str) + "-" + local.isocalendar().week.astype(str)).values

    block = np.timedelta64(p.news_block_min, "m")
    exit_before = np.timedelta64(p.news_exit_min, "m")

    def near_news(ts) -> bool:
        if news.size == 0:
            return False
        i = np.searchsorted(news, ts)
        return any(abs(news[j] - ts) <= block for j in (i - 1, i) if 0 <= j < news.size)

    def news_soon(ts) -> bool:
        if news.size == 0:
            return False
        i = np.searchsorted(news, ts)
        return i < news.size and news[i] - ts <= exit_before

    equity = p.equity
    trades, eq_curve = [], []
    cur_day = cur_week = None
    day_start_eq = week_start_eq = equity
    trades_today = losses_today = 0
    pos = None
    skipped = {"sl_terlalu_lebar": 0, "modal_kurang": 0}
    warmup = max(p.atr_len, p.cons_max + p.impulse_max_bars + 2)

    for i in range(warmup, len(m5)):
        if day_key[i] != cur_day:
            cur_day, day_start_eq, trades_today, losses_today = day_key[i], equity, 0, 0
        if week_key[i] != cur_week:
            cur_week, week_start_eq = week_key[i], equity

        # ---------- buka posisi dari sinyal candle sebelumnya ----------
        if pos is not None and pos["state"] == "pending":
            d = pos["dir"]
            entry = o[i] + (p.spread if d == 1 else 0.0)
            sl = (pos["box_lo"] - p.sl_buffer_atr * pos["atr"]) if d == 1 \
                else (pos["box_hi"] + p.sl_buffer_atr * pos["atr"])
            risk = (entry - sl) * d
            if risk <= 0 or risk > p.max_sl_atr * pos["atr"]:
                skipped["sl_terlalu_lebar"] += 1
                pos = None
            else:
                lot_raw = equity * p.risk_pct / 100 / (risk * p.contract_size)
                lot = math.floor(lot_raw / p.lot_step + 1e-9) * p.lot_step
                if lot < p.min_lot:
                    if p.allow_min_lot:
                        lot = p.min_lot
                    else:
                        skipped["modal_kurang"] += 1
                        pos = None
                if pos is not None:
                    pos.update(state="open", entry=entry, sl=sl, sl0=sl, risk=risk, lot=round(lot, 2),
                               tp1=entry + d * p.tp1_r * risk, tp2=entry + d * p.tp2_r * risk,
                               entry_i=i, tp1_hit=False, realized=0.0, remaining=1.0)
                    trades_today += 1

        # ---------- kelola posisi terbuka ----------
        if pos is not None and pos["state"] == "open":
            d = pos["dir"]
            # harga keluar: BUY keluar di BID, SELL keluar di ASK (= BID + spread)
            adj = 0.0 if d == 1 else p.spread
            hi, lo, cl = h[i] + adj, l[i] + adj, c[i] + adj
            bars_in = i - pos["entry_i"] + 1
            exit_px, reason = None, None
            fav, adv = (hi, lo) if d == 1 else (lo, hi)

            if (adv - pos["sl"]) * d <= 0:
                exit_px, reason = pos["sl"], ("BE" if pos["tp1_hit"] else "SL")
            elif not pos["tp1_hit"] and (fav - pos["tp1"]) * d >= 0:
                pos["realized"] += p.tp1_close_frac * (pos["tp1"] - pos["entry"]) * d
                pos["remaining"] -= p.tp1_close_frac
                pos["tp1_hit"] = True
                pos["sl"] = pos["entry"]
            elif pos["tp1_hit"] and (fav - pos["tp2"]) * d >= 0:
                exit_px, reason = pos["tp2"], "TP2"

            if exit_px is None:
                back_inside = (c[i] <= pos["box_hi"]) if d == 1 else (c[i] >= pos["box_lo"])
                if p.exit_on_fail and not pos["tp1_hit"] and back_inside:
                    exit_px, reason = cl, "Gagal breakout"
                elif not pos["tp1_hit"] and bars_in >= p.time_exit_bars:
                    exit_px, reason = cl, "Waktu habis"
                elif pos["tp1_hit"] and bars_in >= p.runner_max_bars:
                    exit_px, reason = cl, "Waktu habis (sisa)"
                elif i + 1 < len(m5) and news_soon(times[i + 1]):
                    exit_px, reason = cl, "Berita"

            if exit_px is not None:
                pnl_px = pos["realized"] + pos["remaining"] * (exit_px - pos["entry"]) * d
                r_mult = pnl_px / pos["risk"]
                pnl_usd = pnl_px * pos["lot"] * p.contract_size
                equity += pnl_usd
                if r_mult < 0:
                    losses_today += 1
                trades.append({
                    "waktu_sinyal_wib": local[pos["sig_i"]].strftime("%Y-%m-%d %H:%M"),
                    "waktu_keluar_wib": local[i].strftime("%Y-%m-%d %H:%M"),
                    "arah": "BUY" if d == 1 else "SELL",
                    "entry": round(pos["entry"], 3), "sl": round(pos["sl0"], 3),
                    "tp1": round(pos["tp1"], 3), "tp2": round(pos["tp2"], 3),
                    "risk_usd_per_oz": round(pos["risk"], 3), "lot": pos["lot"],
                    "tp1_kena": pos["tp1_hit"], "alasan_keluar": reason,
                    "harga_keluar": round(exit_px, 3), "candle": bars_in,
                    "hasil_R": round(r_mult, 3), "pnl_usd": round(pnl_usd, 2),
                    "equity": round(equity, 2),
                })
                pos = None

        eq_curve.append(equity)

        # ---------- cari sinyal baru (di close candle i) ----------
        if pos is not None or i + 1 >= len(m5):
            continue
        d = trend[i]
        if d == 0 or not in_sess[i]:
            continue
        if trades_today >= p.max_trades_day or losses_today >= p.max_losses_day:
            continue
        if equity <= day_start_eq * (1 - p.max_daily_loss_pct / 100):
            continue
        if equity <= week_start_eq * (1 - p.max_weekly_loss_pct / 100):
            continue
        if near_news(times[i]) or near_news(times[i + 1]):
            continue
        found = detect(i, d, o, h, l, c, a, p)
        if found:
            n, box_hi, box_lo = found
            pos = {"state": "pending", "dir": d, "sig_i": i, "box_hi": box_hi, "box_lo": box_lo,
                   "atr": a[i], "box_len": n}

    curve = pd.Series(eq_curve, index=m5.index[warmup:warmup + len(eq_curve)])
    tdf = pd.DataFrame(trades)
    tdf.attrs["skipped"] = skipped
    return tdf, curve


# ============================== LAPORAN ==============================
def max_streak(values, cond) -> int:
    best = cur = 0
    for v in values:
        cur = cur + 1 if cond(v) else 0
        best = max(best, cur)
    return best


def report(tdf: pd.DataFrame, curve: pd.Series, p: Params, m5: pd.DataFrame) -> str:
    local = m5.index.tz_convert(WIB)
    lines = [
        "=" * 60,
        " HASIL BACKTEST - Flag Breakout XAU",
        "=" * 60,
        f"Periode data     : {local[0]:%Y-%m-%d} s/d {local[-1]:%Y-%m-%d} ({len(m5):,} candle M5)",
        f"Spread diasumsikan: ${p.spread:.2f}/oz | Risiko {p.risk_pct}%/posisi | Modal awal ${p.equity:,.2f}",
        f"Sinyal dilewati  : {tdf.attrs.get('skipped', {})}",
    ]
    if tdf.empty:
        lines.append("Tidak ada transaksi. Coba periode data lebih panjang atau cek parameter.")
        return "\n".join(lines)

    r = tdf["hasil_R"]
    wins, losses = r[r > 0], r[r < 0]
    win_rate = len(wins) / len(r)
    loss_rate = len(losses) / len(r)
    avg_win = wins.mean() if len(wins) else 0.0
    avg_loss = losses.mean() if len(losses) else 0.0
    expectancy = win_rate * avg_win + loss_rate * avg_loss  # = r.mean()
    pf = wins.sum() / abs(losses.sum()) if len(losses) else math.inf
    peak = curve.cummax()
    dd = ((curve - peak) / peak).min() * 100
    final = tdf["equity"].iloc[-1]
    months = max((m5.index[-1] - m5.index[0]).days / 30.44, 1e-9)

    lines += [
        "-" * 60,
        f"Jumlah transaksi : {len(r)}  (~{len(r) / months:.1f} per bulan)",
        f"Win rate         : {win_rate * 100:.1f}%   (menang {len(wins)}, kalah {len(losses)}, impas {len(r) - len(wins) - len(losses)})",
        f"Rata-rata menang : +{avg_win:.2f} R",
        f"Rata-rata kalah  : {avg_loss:.2f} R",
        f"EKSPEKTANSI      : {expectancy:+.3f} R per transaksi",
        f"Profit factor    : {pf:.2f}",
        f"Total            : {r.sum():+.2f} R",
        f"Kalah beruntun   : maks {max_streak(r, lambda v: v < 0)} kali",
        f"Max drawdown     : {dd:.1f}%",
        f"Modal akhir      : ${final:,.2f} ({(final / p.equity - 1) * 100:+.1f}%)",
        "-" * 60,
        "Per arah:",
    ]
    for side, g in tdf.groupby("arah"):
        lines.append(f"  {side:<5} {len(g):>4} trx | win {(g['hasil_R'] > 0).mean() * 100:5.1f}% | "
                     f"ekspektansi {g['hasil_R'].mean():+.3f} R")
    lines.append("Per alasan keluar:")
    for why, g in tdf.groupby("alasan_keluar"):
        lines.append(f"  {why:<20} {len(g):>4} trx | rata-rata {g['hasil_R'].mean():+.2f} R")
    lines.append("Per bulan (total R):")
    month = pd.to_datetime(tdf["waktu_keluar_wib"]).dt.strftime("%Y-%m")
    for m, g in tdf.groupby(month):
        lines.append(f"  {m}  {len(g):>3} trx  {g['hasil_R'].sum():+6.2f} R")
    lines.append("-" * 60)
    verdict = ("POSITIF: layak diuji lanjut di akun demo." if expectancy > 0
               else "NEGATIF: jangan dipakai dengan uang sungguhan; ubah parameter lalu uji ulang.")
    lines.append(f"Kesimpulan: ekspektansi {verdict}")
    if len(r) < 100:
        lines.append(f"Catatan: baru {len(r)} transaksi (< 100), hasil belum bisa diandalkan secara statistik.")
    return "\n".join(lines)


# ============================== CLI ==============================
def main():
    ap = argparse.ArgumentParser(description="Backtest strategi Flag Breakout XAU (M30 tren, M5 entry)")
    ap.add_argument("csv", help="CSV data harga XAUUSD (M1 atau M5)")
    ap.add_argument("--data-tz", default="UTC", help="zona waktu kolom waktu di CSV (default UTC; MT5 biasanya waktu server, mis. Etc/GMT-3)")
    ap.add_argument("--from", dest="date_from", help="mulai tanggal (YYYY-MM-DD)")
    ap.add_argument("--to", dest="date_to", help="sampai tanggal (YYYY-MM-DD)")
    ap.add_argument("--news", help="CSV jadwal berita besar, kolom 'time' dalam UTC")
    ap.add_argument("--spread", type=float, default=Params.spread)
    ap.add_argument("--equity", type=float, default=Params.equity)
    ap.add_argument("--risk", type=float, default=Params.risk_pct, help="risiko per posisi dalam %")
    ap.add_argument("--allow-min-lot", action="store_true", help="tetap masuk 0,01 lot walau risiko > --risk")
    ap.add_argument("--no-session", action="store_true", help="matikan filter jam sesi")
    ap.add_argument("--tp2", type=float, default=Params.tp2_r, help="TP2 dalam R")
    ap.add_argument("--impulse", type=float, default=Params.impulse_mult, help="impuls minimal (x ATR)")
    ap.add_argument("--set", action="append", default=[], metavar="NAMA=NILAI",
                    help="ubah parameter apa pun, mis. --set max_retrace=0.618 --set cons_max=20")
    ap.add_argument("--out", help="folder output (trades.csv, ringkasan.txt, equity.png)")
    args = ap.parse_args()

    p = Params(spread=args.spread, equity=args.equity, risk_pct=args.risk,
               allow_min_lot=args.allow_min_lot, tp2_r=args.tp2, impulse_mult=args.impulse)
    for item in args.set:
        key, _, val = item.partition("=")
        if not hasattr(p, key) or key == "sessions":
            sys.exit(f"Parameter tidak dikenal: {key}")
        cur = getattr(p, key)
        setattr(p, key, val.lower() in ("1", "true", "ya") if isinstance(cur, bool) else type(cur)(val))
    if args.no_session:
        p.sessions = [("00:00", "24:00")]

    m5 = load_ohlc(args.csv, args.data_tz)
    if args.date_from:
        m5 = m5[m5.index >= pd.Timestamp(args.date_from, tz=WIB)]
    if args.date_to:
        m5 = m5[m5.index < pd.Timestamp(args.date_to, tz=WIB) + pd.Timedelta(days=1)]
    if len(m5) < 1000:
        sys.exit(f"Data terlalu sedikit ({len(m5)} candle M5). Butuh minimal beberapa minggu data.")

    tdf, curve = backtest(m5, p, load_news(args.news))
    text = report(tdf, curve, p, m5)
    print(text)

    if args.out:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        tdf.to_csv(out / "trades.csv", index=False)
        (out / "ringkasan.txt").write_text(text + "\n\nParameter:\n" +
                                           "\n".join(f"  {k} = {v}" for k, v in asdict(p).items()))
        try:
            import matplotlib
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt
            fig, ax = plt.subplots(figsize=(10, 4))
            curve.tz_convert(WIB).plot(ax=ax, color="#2563eb", lw=1.2)
            ax.axhline(p.equity, color="#888", lw=0.8, ls="--")
            ax.set_title("Kurva modal - Flag Breakout XAU")
            ax.set_ylabel("Modal ($)")
            ax.grid(alpha=0.3)
            fig.tight_layout()
            fig.savefig(out / "equity.png", dpi=120)
        except ImportError:
            pass
        print(f"\nFile disimpan di: {out.resolve()}")


if __name__ == "__main__":
    main()
