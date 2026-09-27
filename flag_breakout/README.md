# Flag Breakout XAU: indikator TradingView + backtest Python

Versi terstruktur dari strategi di video *"Cara Baca Candle XAU untuk Scalping"*: tren di M30, pola bendera/kotak di M5, lalu masuk saat breakout. Semua aturannya ditulis sebagai syarat yang bisa dijawab **ya/tidak**.

| File | Kegunaan |
|---|---|
| `flag_breakout_xau.pine` | Indikator TradingView: menggambar kotak konsolidasi, label entry/SL/TP1/TP2, ukuran lot, hasil tiap posisi, panel statistik, dan alert |
| `backtest_flag_breakout.py` | Backtest aturan yang **sama persis** di data historis, dengan spread, batas harian, dan hitungan win rate/ekspektansi |

> **Baca dulu bagian "Hasil backtest" di bawah.** Dengan parameter bawaan, aturan ini **merugi** di data 2021–2026. Kedua alat ini disediakan untuk menguji dan memperbaiki strategi, bukan sebagai sistem siap pakai.

---

## 1. Aturan yang diterapkan

| Langkah | Aturan (contoh BUY; SELL kebalikannya) |
|---|---|
| **Filter** | Jam 14:00–17:00 dan 19:30–23:00 WIB. Tidak ada berita besar ±30 menit (hanya di backtest, lewat `--news`). Maks 3 posisi/hari, berhenti setelah 2 kali kalah atau -2%/hari, -5%/minggu |
| **Arah (M30)** | Candle M30 terakhir yang sudah selesai ditutup di atas EMA 50, **dan** EMA 50 lebih tinggi dari 10 candle sebelumnya |
| **Impuls (M5)** | Harga naik minimal **2 × ATR(14)** dalam paling banyak 6 candle |
| **Konsolidasi** | 4–15 candle setelah impuls. Tidak melewati puncak impuls, koreksi maksimal **50%** dari impuls |
| **Entry** | Candle ditutup di atas kotak, badan ≥ 50% panjang candle, panjang candle ≤ 1,5 × ATR. **Masuk di open candle berikutnya** |
| **Stop Loss** | Low kotak − 0,3 × ATR. Sinyal dilewati jika jarak SL > 2,5 × ATR |
| **Take Profit** | TP1 = 1R: tutup 50%, SL dipindah ke harga entry (break even). TP2 = 2R untuk sisanya |
| **Keluar awal** | Close kembali masuk ke kotak (breakout gagal), atau TP1 belum kena setelah 12 candle. Sisa posisi ditutup paksa setelah 48 candle |
| **Lot** | `Lot = (Modal × 1%) ÷ (Jarak SL dalam $ × 100)`, dibulatkan ke bawah ke 0,01 |

---

## 2. Indikator TradingView

1. Buka chart **XAUUSD** di TradingView, time frame **5 menit**.
2. Buka **Pine Editor**, tempel seluruh isi `flag_breakout_xau.pine`, lalu **Save** → **Add to chart**.
3. Isi **Modal** dan **Risiko per posisi** di pengaturan agar ukuran lot yang ditampilkan sesuai akun Anda.

Tampilan di chart:
- **Kotak hijau/merah**: area konsolidasi (bendera) yang baru saja ditembus.
- **Segitiga**: sinyal di candle breakout. Posisi dibuka di **open candle berikutnya**.
- **Label BUY/SELL**: harga entry, SL, TP1, TP2, dan lot.
- **Garis**: biru = entry, merah = SL (jadi abu-abu setelah pindah ke BE), hijau putus-putus = TP1, hijau tebal = TP2.
- **Label hasil**: `SL -1R`, `TP2 +1.5R`, `Gagal breakout -0.3R`, dan seterusnya.
- **Panel kanan atas**: arah tren saat ini, jumlah transaksi, win rate, dan ekspektansi pada data yang sedang terlihat di chart.

**Alert:** pilih kondisi **"Flag Breakout BUY/SELL"** (saat sinyal muncul), atau **"Any alert() function call"** untuk menerima pesan berisi harga entry, SL, TP, dan lot saat posisi dibuka.

Catatan:
- Panel statistik **tidak menghitung spread**. Hasil nyata akan sedikit lebih buruk; untuk angka yang realistis gunakan backtest Python.
- Filter berita dan batas rugi harian dalam persen tidak ada di indikator. Cek kalender ekonomi (mis. Forex Factory) sebelum masuk.
- Sinyal hanya dihitung saat candle selesai, jadi tidak berubah-ubah (*non-repaint*).

---

## 3. Backtest Python

### Instalasi
```bash
pip install pandas numpy matplotlib
```

### Mendapatkan data XAUUSD
Pilihan paling mudah dan gratis adalah **Dukascopy** (butuh Node.js):
```bash
npx dukascopy-node -i xauusd -from 2021-01-01 -to 2026-09-26 -t m5 -f csv -v true -dir data
```
Bisa juga memakai ekspor **MT4/MT5** (menu *View → Symbols → Bars → Export*). Waktu di MT5 biasanya waktu server broker, jadi tambahkan `--data-tz`, misalnya `--data-tz Etc/GMT-3` untuk server GMT+3. Data M1 otomatis diubah ke M5.

### Menjalankan
```bash
# Dasar
python backtest_flag_breakout.py data/xauusd-m5-bid-2021-01-01-2026-09-26.csv

# Simpan trades.csv, ringkasan.txt, dan grafik equity.png
python backtest_flag_breakout.py data.csv --out hasil

# Atur spread, modal, risiko, periode
python backtest_flag_breakout.py data.csv --spread 0.25 --equity 500 --risk 1 --from 2025-01-01

# Coba ubah parameter apa pun
python backtest_flag_breakout.py data.csv --set max_retrace=0.618 --set cons_max=20 --set tp2_r=3

# Pakai filter berita (CSV dengan kolom 'time' dalam UTC)
python backtest_flag_breakout.py data.csv --news berita.csv
```

Nama parameter untuk `--set` ada di kelas `Params` di bagian atas script, misalnya `impulse_mult`, `cons_min`, `cons_max`, `max_retrace`, `body_min`, `max_breakout_atr`, `sl_buffer_atr`, `max_sl_atr`, `tp1_r`, `tp2_r`, `time_exit_bars`, `runner_max_bars`, `max_trades_day`.

### Asumsi backtest (sengaja konservatif)
- Data harga dianggap **BID**. BUY masuk di harga ask (open + spread); SELL keluar di harga ask.
- Jika SL dan TP tersentuh di candle yang sama, **SL dianggap kena duluan**.
- Order SL/TP terisi tepat di harganya, tanpa *slippage*. Saat pasar bergerak kencang, hasil nyata bisa lebih buruk.
- Jika lot yang dihitung < 0,01 (modal terlalu kecil untuk risiko 1%), sinyal **dilewati**. Pakai `--allow-min-lot` untuk tetap masuk dengan 0,01 lot.

### Membaca hasil
| Angka | Arti |
|---|---|
| **Win rate** | Persentase posisi yang untung |
| **R** | Satuan risiko: 1R = kerugian bila kena SL penuh |
| **Ekspektansi** | Rata-rata hasil per transaksi dalam R. **Harus positif** agar strategi layak dicoba |
| **Profit factor** | Total untung ÷ total rugi. Di atas 1,0 berarti untung, di atas 1,3 cukup baik |
| **Max drawdown** | Penurunan modal terbesar dari puncak |

---

## 4. Hasil backtest

Data: XAUUSD M5 Dukascopy (BID), **4 Januari 2021 – 26 September 2026** (±391 ribu candle M5). Spread $0,30/oz, risiko 1% per posisi, modal awal $1.000.

### Parameter bawaan
| Metrik | Hasil |
|---|---|
| Jumlah transaksi | 160 (±2,3 per bulan) |
| Win rate | 25,0% |
| Rata-rata menang / kalah | +0,77R / −0,40R |
| **Ekspektansi** | **−0,105R per transaksi** |
| Profit factor | 0,65 |
| Kalah beruntun terpanjang | 13 kali |
| Max drawdown | −14,4% |
| Modal akhir | $876,95 (−12,3%) |

Alasan keluar: 112 dari 160 posisi (70%) ditutup karena **breakout gagal** (harga kembali ke dalam kotak), rata-rata −0,38R. Hanya 12 posisi mencapai TP2.

### Variasi parameter
| Variasi | Transaksi | Win rate | Ekspektansi | Profit factor |
|---|---|---|---|---|
| Bawaan | 160 | 25,0% | −0,105R | 0,65 |
| Tanpa keluar saat breakout gagal | 155 | 42,6% | −0,117R | 0,72 |
| Koreksi maks 61,8% | 315 | 26,7% | −0,084R | 0,73 |
| Impuls 1,5 × ATR | 167 | 25,1% | −0,102R | 0,66 |
| Longgar (impuls 1,5 ATR, koreksi 61,8%, konsolidasi ≤ 25) | 333 | 26,7% | −0,083R | 0,73 |
| Longgar + TP2 3R | 333 | 26,7% | −0,083R | 0,73 |
| Longgar, **spread $0** (tidak realistis) | 357 | 29,4% | +0,008R | 1,03 |

### Kesimpulan
- **Tidak ada variasi yang untung setelah spread.** Bahkan tanpa spread sama sekali, hasilnya hanya impas. Artinya pola ini, sebagaimana didefinisikan di sini, **tidak punya keunggulan (edge)** pada XAUUSD M5 selama 2021–2026.
- Masalah utamanya: **sebagian besar breakout di M5 gagal**. Mengganti target TP atau melonggarkan syarat pola tidak mengubah hal ini.
- Hasil ini tidak membuktikan bahwa video tersebut salah. Penjelasan di video bersifat diskresioner (penilaian mata), sedangkan backtest ini menguji **satu versi aturan yang tertulis**. Namun jika aturan pola tidak bisa ditulis dengan jelas, klaim keberhasilannya juga tidak bisa diuji.

### Ide untuk diuji selanjutnya (belum terbukti)
- Entry di **retest** batas kotak setelah breakout, bukan langsung setelah candle breakout.
- Time frame lebih besar (pola di M15, tren di H1/H4), yang biasanya lebih tahan terhadap spread.
- Filter volatilitas (hanya trading saat ATR di atas rata-rata) atau hanya sesi New York.

Setiap perubahan sebaiknya diuji di **sebagian data** (misalnya 2021–2024), lalu dikonfirmasi di **data yang belum pernah dipakai** (2025–2026). Mencoba banyak kombinasi pada data yang sama lalu memilih yang terbaik hampir pasti menghasilkan strategi yang tampak bagus di masa lalu tetapi gagal di masa depan (*overfitting*).

*Materi edukasi, bukan nasihat keuangan.*
