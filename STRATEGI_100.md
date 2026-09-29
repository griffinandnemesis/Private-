# 100 Strategi Scalping — Timeframe 5 Menit

Semua strategi ada di **satu file**: `scalping_100_strategi.pine`.

## Cara mencoba

1. Buka chart **XAUUSD, timeframe 5 menit** (misalnya `OANDA:XAUUSD`).
2. Tempel isi `scalping_100_strategi.pine` di **Pine Editor**, lalu klik **Save** dan **Add to chart**.
3. Buka ⚙️ Settings strategi, lalu ubah **Nomor Strategi** mulai dari 1, 2, 3, dan seterusnya.
4. Setiap kali nomor diganti, lihat hasilnya di tab **Strategy Tester** dan catat di tabel paling bawah.

**Aturan keluar (sama untuk semua strategi):**
- Stop Loss = 1,5 × ATR(14)
- Take Profit = Stop Loss × Risk:Reward. Pilih **1:2** atau **1:3** di Settings.
- Hanya satu posisi terbuka dalam satu waktu.
- Entry hanya pada jam sesi **14:00–23:00 WIB**. Filter ini bisa dimatikan di Settings.

**Sebelum mulai:** di tab **Properties**, isi **Slippage** sesuai spread broker Anda (lihat README), supaya hasil backtest mendekati kenyataan.

Di tabel aturan, hanya aturan **BUY** yang ditulis. Aturan **SELL** adalah kebalikannya: atas ↔ bawah, naik ↔ turun, dan oversold ↔ overbought.

## Daftar strategi

### A. Moving Average (1–17)
| No | Nama | Aturan BUY |
|---|---|---|
| 1 | EMA 9/21 Cross | EMA 9 memotong ke atas EMA 21 |
| 2 | EMA 9/21 Cross + EMA 200 | Sama seperti no. 1, dan harga di atas EMA 200 |
| 3 | EMA 5/13 Cross + EMA 50 | EMA 5 memotong ke atas EMA 13, dan harga di atas EMA 50 |
| 4 | EMA 8/21/55 Ribbon | EMA 8 > 21 > 55 baru saja tersusun rapi |
| 5 | EMA 20 Pullback | EMA 20 > EMA 50, harga turun menyentuh EMA 20, lalu candle hijau ditutup di atasnya |
| 6 | EMA 50 Bounce + EMA 200 | Tren naik (EMA 50 > EMA 200), harga memantul dari EMA 50 |
| 7 | Triple EMA 4/9/18 | EMA 4 > 9 > 18 baru saja tersusun |
| 8 | SMA 10/20 Cross | SMA 10 memotong ke atas SMA 20 |
| 9 | SMA 20/50 Cross | SMA 20 memotong ke atas SMA 50 |
| 10 | HMA 9/21 Cross | Hull MA 9 memotong ke atas Hull MA 21 |
| 11 | HMA 55 Turn | Hull MA 55 berbalik arah naik |
| 12 | DEMA 20 Cross + EMA 200 | Harga memotong ke atas DEMA 20, dan harga di atas EMA 200 |
| 13 | TEMA 20 Cross + EMA 50 | Harga memotong ke atas TEMA 20, dan harga di atas EMA 50 |
| 14 | ZLEMA 21 Cross | Harga memotong ke atas Zero-Lag EMA 21 |
| 15 | ALMA 21 Cross + EMA 200 | Harga memotong ke atas ALMA 21, dan harga di atas EMA 200 |
| 16 | LSMA 25 Turn + EMA 50 | Garis regresi linear 25 berbalik naik, dan harga di atas EMA 50 |
| 17 | VWMA 20 / EMA 20 Cross | VWMA 20 memotong ke atas EMA 20, dan harga di atas EMA 50 |

### B. VWAP (18–20)
| No | Nama | Aturan BUY |
|---|---|---|
| 18 | VWAP Cross + EMA 200 | Harga memotong ke atas VWAP, dan harga di atas EMA 200 |
| 19 | VWAP Pullback | EMA 9 > EMA 21, harga menyentuh VWAP lalu candle hijau ditutup di atasnya |
| 20 | VWAP + RSI 50 | Harga di atas VWAP, dan RSI 14 memotong ke atas 50 |

### C. RSI & Stochastic (21–31)
| No | Nama | Aturan BUY |
|---|---|---|
| 21 | RSI 14 Cross 50 + EMA 200 | RSI 14 memotong ke atas 50, dan harga di atas EMA 200 |
| 22 | RSI 2 Pullback (Connors) | Harga di atas EMA 200, dan RSI 2 turun ke bawah 10 |
| 23 | RSI 7 30/70 + EMA 50 | RSI 7 naik keluar dari bawah 30, dan harga di atas EMA 50 |
| 24 | RSI 14 30/70 Reversal | RSI 14 naik keluar dari bawah 30 |
| 25 | RSI 14 Pullback 40/60 | Tren naik (harga > EMA 200, EMA 21 > EMA 50), RSI 14 naik melewati 40 |
| 26 | EMA 9/21 + RSI 50 | EMA 9 memotong ke atas EMA 21, dan RSI 14 > 50 |
| 27 | Stoch 14 Cross 20/80 | %K memotong ke atas %D di bawah level 20 |
| 28 | Stoch Cross + EMA 200 | %K memotong ke atas %D di bawah 30, dan harga di atas EMA 200 |
| 29 | Stoch Exit Zone + EMA 50 | %K naik keluar dari bawah 20, dan harga di atas EMA 50 |
| 30 | Stoch RSI Cross + EMA 50 | Stoch RSI %K memotong ke atas %D di bawah 20, dan harga di atas EMA 50 |
| 31 | Stoch RSI 50 + EMA 200 | Stoch RSI naik melewati 50, dan harga di atas EMA 200 |

### D. MACD (32–37)
| No | Nama | Aturan BUY |
|---|---|---|
| 32 | MACD Signal Cross | Garis MACD memotong ke atas garis signal |
| 33 | MACD Cross + EMA 200 | Cross MACD terjadi di bawah nol, dan harga di atas EMA 200 |
| 34 | MACD Zero Cross | Garis MACD naik melewati nol |
| 35 | MACD Histogram Turn | Histogram masih negatif tapi mulai naik, dan harga di atas EMA 200 |
| 36 | MACD Fast 5/13/6 | MACD cepat memotong ke atas signal, dan harga di atas EMA 50 |
| 37 | MACD + RSI 50 | MACD memotong ke atas signal, dan RSI 14 > 50 |

### E. Oscillator Lain (38–49)
| No | Nama | Aturan BUY |
|---|---|---|
| 38 | CCI 20 +/-100 Breakout | CCI 20 naik melewati +100 |
| 39 | CCI 20 Reversal + EMA 200 | CCI naik melewati -100, dan harga di atas EMA 200 |
| 40 | CCI Zero + EMA 50 | CCI naik melewati 0, dan harga di atas EMA 50 |
| 41 | Williams %R 80/20 + EMA 200 | %R naik melewati -80, dan harga di atas EMA 200 |
| 42 | Williams %R Momentum | %R naik melewati -20, dan EMA 21 > EMA 50 |
| 43 | MFI 20/80 + EMA 50 | Money Flow Index naik melewati 20, dan harga di atas EMA 50 |
| 44 | ROC 9 Zero + EMA 200 | Rate of Change naik melewati 0, dan harga di atas EMA 200 |
| 45 | Momentum 10 + EMA 21 Slope | Momentum naik melewati 0, dan EMA 21 sedang naik |
| 46 | CMO 50 + EMA 200 | Chande Momentum naik melewati -50, dan harga di atas EMA 200 |
| 47 | TSI Signal + EMA 200 | TSI memotong ke atas signal, dan harga di atas EMA 200 |
| 48 | Awesome Osc Zero Cross | Awesome Oscillator naik melewati 0 |
| 49 | Awesome Osc Saucer | AO di atas 0: dua bar turun lalu satu bar naik |

### F. Bollinger, Keltner, Donchian (50–59)
| No | Nama | Aturan BUY |
|---|---|---|
| 50 | Bollinger Bounce + EMA 200 | Harga menyentuh band bawah lalu ditutup di atasnya, dan harga di atas EMA 200 |
| 51 | Bollinger Breakout + ADX | Harga ditutup di atas band atas, dan ADX > 20 |
| 52 | Bollinger Mid Pullback | Garis tengah BB naik, harga menyentuh garis tengah lalu candle hijau |
| 53 | BB/Keltner Squeeze Breakout | Squeeze (BB di dalam Keltner) baru lepas, dan momentum positif |
| 54 | Bollinger Re-entry | Candle sebelumnya ditutup di bawah band bawah, sekarang kembali masuk |
| 55 | Keltner Breakout | Harga ditutup di atas Keltner atas |
| 56 | Keltner Mid Pullback | Garis tengah Keltner naik, harga menyentuhnya lalu candle hijau |
| 57 | Donchian 20 Breakout | Harga menembus high tertinggi 20 bar (gaya Turtle) |
| 58 | Donchian 10 + EMA 200 | Harga menembus high 10 bar, dan harga di atas EMA 200 |
| 59 | Donchian 55 Breakout | Harga menembus high tertinggi 55 bar |

### G. Trend Indicator (60–75)
| No | Nama | Aturan BUY |
|---|---|---|
| 60 | DMI Cross + ADX 20 | +DI memotong ke atas -DI, dan ADX > 20 |
| 61 | ADX 25 + EMA 9/21 | ADX > 25 dan naik, EMA 9 > EMA 21, harga menembus EMA 9 ke atas |
| 62 | Supertrend 10/3 Flip | Supertrend (10,3) berubah menjadi hijau |
| 63 | Supertrend 7/2 + EMA 200 | Supertrend (7,2) berubah hijau, dan harga di atas EMA 200 |
| 64 | Double Supertrend | Supertrend (10,3) dan (7,2) sama-sama hijau, salah satunya baru berubah |
| 65 | Supertrend + RSI 50 | Supertrend hijau, dan RSI 14 naik melewati 50 |
| 66 | Parabolic SAR + EMA 200 | Titik SAR pindah ke bawah harga, dan harga di atas EMA 200 |
| 67 | Parabolic SAR + MACD | SAR pindah ke bawah harga, dan MACD di atas signal |
| 68 | Ichimoku TK Cross | Tenkan memotong ke atas Kijun, dan harga di atas awan |
| 69 | Ichimoku Kumo Breakout | Harga menembus ke atas awan Ichimoku |
| 70 | Ichimoku Kijun Bounce | Harga di atas awan, menyentuh Kijun lalu candle hijau |
| 71 | Heikin Ashi Flip + EMA 50 | Candle Heikin Ashi berubah hijau, dan harga di atas EMA 50 |
| 72 | Heikin Ashi Strong + EMA 21 | Candle Heikin Ashi hijau tanpa ekor bawah (tren kuat), dan harga di atas EMA 21 |
| 73 | Aroon 15 Cross | Aroon Up memotong ke atas Aroon Down, dan Aroon Up > 70 |
| 74 | Vortex 14 Cross | VI+ memotong ke atas VI- |
| 75 | Elder Ray | EMA 13 naik, Bear Power masih negatif tapi mulai naik |

### H. Volume & Statistik (76–79)
| No | Nama | Aturan BUY |
|---|---|---|
| 76 | OBV / EMA 20 + EMA 50 | OBV memotong ke atas EMA 20-nya, dan harga di atas EMA 50 |
| 77 | Volume Spike Breakout | Volume > 2× rata-rata, candle hijau menembus high sebelumnya, dan harga di atas EMA 200 |
| 78 | Squeeze Momentum + EMA 200 | Momentum squeeze (gaya LazyBear) naik melewati 0, dan harga di atas EMA 200 |
| 79 | Z-Score 2 Reversion | Z-score harga naik kembali dari bawah -2 |

### I. Price Action (80–89)
| No | Nama | Aturan BUY |
|---|---|---|
| 80 | Engulfing + EMA 200 | Bullish engulfing, dan harga di atas EMA 200 |
| 81 | Engulfing at EMA 21 | Bullish engulfing yang menyentuh EMA 21, dan EMA 21 > EMA 50 |
| 82 | Pin Bar at EMA 20 | Pin bar bullish (ekor bawah panjang) di EMA 20, dan EMA 20 > EMA 50 |
| 83 | Pin Bar at Bollinger | Pin bar bullish yang menyentuh band bawah BB |
| 84 | Inside Bar Breakout + EMA 200 | Setelah inside bar, harga menembus high-nya, dan harga di atas EMA 200 |
| 85 | NR7 Breakout | Setelah candle dengan range tersempit dalam 7 bar, harga menembus high-nya, dan EMA 21 > EMA 50 |
| 86 | 3 Soldiers / 3 Crows + EMA 50 | Tiga candle hijau berturut-turut yang makin tinggi, dan harga di atas EMA 50 |
| 87 | 3-Bar Pullback + EMA 200 | Tren naik, 3 penutupan turun berturut-turut, lalu harga menembus high sebelumnya |
| 88 | Fractal Breakout | Harga menembus fractal high terakhir, dan EMA 21 > EMA 50 |
| 89 | Fair Value Gap + EMA 200 | Terbentuk FVG bullish (celah 3 candle), dan harga di atas EMA 200 |

### J. Level & Sesi (90–95)
| No | Nama | Aturan BUY |
|---|---|---|
| 90 | Previous Day High/Low Breakout | Harga menembus high hari kemarin |
| 91 | Daily Pivot Bounce | Harga menyentuh Pivot harian lalu candle hijau, dan harga di atas EMA 50 |
| 92 | Pivot R1/S1 Breakout | Harga menembus R1 harian |
| 93 | London Opening Range Breakout | Menembus high 14:00–14:15 WIB, antara 14:15–18:00 WIB |
| 94 | New York Opening Range Breakout | Menembus high 20:30–20:45 WIB, antara 20:45–23:00 WIB |
| 95 | Asian Range Breakout | Menembus high sesi Asia (07:00–14:00 WIB), antara 14:00–18:00 WIB |

### K. Multi-Timeframe & Gabungan (96–100)
| No | Nama | Aturan BUY |
|---|---|---|
| 96 | H1 EMA 50 + EMA 9/21 | Harga di atas EMA 50 timeframe 1 jam, dan EMA 9 memotong ke atas EMA 21 |
| 97 | M15 EMA 21 + RSI 7 | Harga di atas EMA 21 timeframe 15 menit, dan RSI 7 naik melewati 40 |
| 98 | EMA 200 Retest | EMA 50 > EMA 200, harga menyentuh EMA 200 lalu candle hijau |
| 99 | Confluence EMA+MACD+RSI+VWAP | Keempatnya baru saja kompak bullish: EMA 9 > 21, MACD > signal, RSI > 50, harga > VWAP |
| 100 | Scalping Assistant | Logika indikator utama kita (EMA + VWAP + RSI + filter ATR) |

---

## Tabel hasil backtest

Isi setelah mencoba setiap strategi. Gunakan simbol, timeframe, periode, dan pengaturan yang sama untuk semua strategi supaya perbandingannya adil.

Simbol: ______  TF: 5m  Periode: ______  RR: 1:__  Slippage: ___

| No | Net Profit | Profit Factor | Win Rate | Max Drawdown | Total Trades | Catatan |
|---|---|---|---|---|---|---|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| 4 | | | | | | |
| 5 | | | | | | |
| 6 | | | | | | |
| 7 | | | | | | |
| 8 | | | | | | |
| 9 | | | | | | |
| 10 | | | | | | |
| 11 | | | | | | |
| 12 | | | | | | |
| 13 | | | | | | |
| 14 | | | | | | |
| 15 | | | | | | |
| 16 | | | | | | |
| 17 | | | | | | |
| 18 | | | | | | |
| 19 | | | | | | |
| 20 | | | | | | |
| 21 | | | | | | |
| 22 | | | | | | |
| 23 | | | | | | |
| 24 | | | | | | |
| 25 | | | | | | |
| 26 | | | | | | |
| 27 | | | | | | |
| 28 | | | | | | |
| 29 | | | | | | |
| 30 | | | | | | |
| 31 | | | | | | |
| 32 | | | | | | |
| 33 | | | | | | |
| 34 | | | | | | |
| 35 | | | | | | |
| 36 | | | | | | |
| 37 | | | | | | |
| 38 | | | | | | |
| 39 | | | | | | |
| 40 | | | | | | |
| 41 | | | | | | |
| 42 | | | | | | |
| 43 | | | | | | |
| 44 | | | | | | |
| 45 | | | | | | |
| 46 | | | | | | |
| 47 | | | | | | |
| 48 | | | | | | |
| 49 | | | | | | |
| 50 | | | | | | |
| 51 | | | | | | |
| 52 | | | | | | |
| 53 | | | | | | |
| 54 | | | | | | |
| 55 | | | | | | |
| 56 | | | | | | |
| 57 | | | | | | |
| 58 | | | | | | |
| 59 | | | | | | |
| 60 | | | | | | |
| 61 | | | | | | |
| 62 | | | | | | |
| 63 | | | | | | |
| 64 | | | | | | |
| 65 | | | | | | |
| 66 | | | | | | |
| 67 | | | | | | |
| 68 | | | | | | |
| 69 | | | | | | |
| 70 | | | | | | |
| 71 | | | | | | |
| 72 | | | | | | |
| 73 | | | | | | |
| 74 | | | | | | |
| 75 | | | | | | |
| 76 | | | | | | |
| 77 | | | | | | |
| 78 | | | | | | |
| 79 | | | | | | |
| 80 | | | | | | |
| 81 | | | | | | |
| 82 | | | | | | |
| 83 | | | | | | |
| 84 | | | | | | |
| 85 | | | | | | |
| 86 | | | | | | |
| 87 | | | | | | |
| 88 | | | | | | |
| 89 | | | | | | |
| 90 | | | | | | |
| 91 | | | | | | |
| 92 | | | | | | |
| 93 | | | | | | |
| 94 | | | | | | |
| 95 | | | | | | |
| 96 | | | | | | |
| 97 | | | | | | |
| 98 | | | | | | |
| 99 | | | | | | |
| 100 | | | | | | |

### Cara menilai hasil

- **Total Trades minimal 100.** Kurang dari itu, hasilnya bisa jadi hanya kebetulan.
- **Profit Factor > 1,3** sudah cukup baik. Jika di atas 3, curigai hasilnya dan cek ulang.
- **Win rate** tidak perlu tinggi. Dengan RR 1:2, win rate 40% sudah bisa untung, dan dengan RR 1:3 cukup sekitar 30%.
- **Max Drawdown** sebaiknya di bawah 20%.

### ⚠️ Jebakan saat menguji 100 strategi sekaligus

Jika Anda mencoba 100 strategi, beberapa di antaranya **pasti** terlihat bagus **hanya karena kebetulan**. Untuk menghindari jebakan ini:

1. Pilih 5–10 strategi terbaik.
2. **Uji ulang** strategi-strategi itu pada periode data yang berbeda. Contohnya: jika tadi Anda memakai 3 bulan terakhir, sekarang pakai 3 bulan sebelumnya.
3. Uji juga di pasar lain, misalnya EURUSD. Strategi yang bagus biasanya tetap untung, walaupun tidak sebesar di emas.
4. Strategi yang lolos semua langkah di atas, jalankan dulu di **Paper Trading** selama 2–4 minggu sebelum memakai uang sungguhan.
