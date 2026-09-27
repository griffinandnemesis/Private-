# Scalping Assistant — Indikator TradingView

Indikator scalping untuk TradingView (Pine Script v5), dibuat untuk pemula.
Indikator ini memberi sinyal **BUY/SELL**, lalu otomatis menggambar **Stop Loss (SL)** dan **Take Profit (TP)**.

| File | Kegunaan |
|---|---|
| `scalping_assistant_indicator.pine` | Indikator utama untuk trading sehari-hari: sinyal, garis SL/TP, panel info, dan alert |
| `scalping_assistant_strategy.pine` | Versi backtest. Menguji strategi pada data masa lalu di *Strategy Tester* |

---

## 1. Cara memasang di TradingView

1. Buka chart di TradingView, lalu klik tab **Pine Editor** di bagian bawah layar.
2. Hapus semua kode bawaan, lalu salin seluruh isi `scalping_assistant_indicator.pine` dan tempel ke editor.
3. Klik **Save**, lalu **Add to chart**.
4. Ulangi langkah yang sama untuk `scalping_assistant_strategy.pine` jika ingin melakukan backtest. Hasilnya muncul di tab **Strategy Tester**.

## 2. Cara membaca sinyal

- **Label hijau "BUY"** di bawah candle: peluang beli. Garis merah adalah SL dan garis hijau adalah TP.
- **Label merah "SELL"** di atas candle: peluang jual.
- **Latar hijau atau merah tipis** menunjukkan arah tren. Jika latar kosong, pasar sedang netral, jadi lebih baik menunggu.
- **Panel kanan atas** menampilkan tren, RSI, volatilitas, sesi, dan sinyal terakhir.
- Garis di chart:
  - Biru muda = EMA 9
  - Oranye = EMA 21
  - Putih tebal = EMA 200
  - Titik ungu = VWAP

Sinyal hanya muncul setelah candle **selesai (close)**, jadi sinyal tidak akan hilang atau berubah (*non-repaint*).

## 3. Logika strategi dan sumbernya

Indikator ini menggabungkan beberapa konsep yang paling banyak dipakai dan diajarkan dalam scalping. Sebuah sinyal baru muncul jika **semua syarat** di bawah terpenuhi:

| Lapisan | Aturan | Asal konsep |
|---|---|---|
| **Tren besar** | BUY hanya jika harga di atas EMA 200, SELL hanya jika di bawahnya | Prinsip *trend following*: "trade searah tren". EMA 200 adalah patokan tren yang dipakai sangat luas |
| **Tren kecil** | EMA 9 di atas EMA 21 untuk BUY, dan sebaliknya untuk SELL | Pasangan EMA cepat/lambat yang umum dipakai scalper di timeframe 1–5 menit |
| **VWAP** | BUY di atas VWAP, SELL di bawah VWAP | VWAP adalah acuan harga rata-rata tertimbang volume yang banyak dipakai trader institusi dan day trader |
| **Trigger** | EMA 9 memotong EMA 21, **atau** harga *pullback* menyentuh EMA 9 lalu memantul dengan candle searah tren | Teknik "beli saat koreksi dalam tren naik", bukan mengejar harga |
| **Momentum** | RSI > 50 untuk BUY (tapi < 70), RSI < 50 untuk SELL (tapi > 30) | RSI dan ATR diciptakan J. Welles Wilder (*New Concepts in Technical Trading Systems*, 1978) |
| **Volatilitas** | Tidak ada sinyal saat ATR jauh di bawah rata-ratanya (pasar sepi) | Scalping butuh pergerakan. Pasar yang "mati" biasanya menghasilkan sinyal palsu |
| **Risiko** | SL = 1,5 × ATR, TP = 1,5 × jarak SL | SL mengikuti volatilitas pasar, dan target keuntungan selalu lebih besar dari risiko |

### Tentang "strategi para juara dunia"

Beberapa trader memang pernah menjuarai kompetisi trading resmi. Contohnya **Larry Williams**, juara *World Cup Championship of Futures Trading* 1987, dan **Andrea Unger**, yang menjuarai kompetisi yang sama beberapa kali. Namun strategi lengkap mereka tidak dipublikasikan sebagai "satu indikator ajaib". Hasil kompetisi mereka juga diraih dengan risiko sangat besar dan tidak bisa dijamin terulang.

Yang **konsisten mereka ajarkan** justru prinsip-prinsip berikut, dan indikator ini dibangun di atasnya:

1. **Aturan yang jelas dan sistematis**: masuk dan keluar berdasarkan aturan, bukan emosi.
2. **Selalu memakai Stop Loss**: setiap posisi punya batas rugi sejak awal.
3. **Risiko kecil per transaksi**: umumnya 0,5–1% dari modal per trade.
4. **Uji dulu sebelum dipakai (backtest)**: karena itu disediakan versi strategy.
5. **Hanya trading saat pasar aktif**: karena itu ada filter ATR dan filter sesi.

## 4. Pengaturan yang disarankan untuk pemula

| Pasar | Timeframe | Saran pengaturan |
|---|---|---|
| Forex (EURUSD, GBPUSD) | 5 menit | Aktifkan **filter sesi** (14:00–23:00 WIB, sesi London + New York). Filter VWAP tetap aktif, tapi otomatis diabaikan jika broker tidak menyediakan volume |
| Emas (XAUUSD) | 5 menit | Aktifkan filter sesi. SL bisa dinaikkan ke 2 × ATR karena emas sangat volatil |
| Crypto (BTCUSDT, ETHUSDT) | 1–5 menit | Aktifkan **filter volume**. Filter sesi opsional karena pasar buka 24 jam |
| Saham IDX | 5 menit | Ubah jam sesi ke `0900-1600` |

Mulailah dari timeframe **5 menit**. Timeframe 1 menit menghasilkan lebih banyak sinyal palsu dan lebih sulit untuk pemula.

## 5. Langkah aman sebelum memakai uang sungguhan

1. **Backtest**: pasang versi strategy dan lihat *Net Profit*, *Profit Factor* (idealnya > 1,3), dan *Max Drawdown* di Strategy Tester. Coba beberapa pasar dan timeframe.
2. **Paper trading**: gunakan fitur *Paper Trading* di TradingView (akun demo) minimal 2–4 minggu.
3. **Mulai kecil**: risiko maksimal 1% modal per trade. Contohnya, dengan modal Rp10 juta, rugi maksimal per trade adalah Rp100 ribu.
4. **Catat setiap trade** (jurnal trading) supaya tahu mana yang berhasil dan mana yang tidak.

## 6. Mengatur alert (notifikasi)

1. Klik ikon **jam alarm (Alert)** di TradingView.
2. Pada *Condition*, pilih **Scalping Assistant**, lalu salah satu opsi berikut:
   - **"Any alert() function call"**: pesan otomatis berisi harga entry, SL, dan TP.
   - **Scalping BUY** / **Scalping SELL**: alert khusus satu arah.
3. Pilih notifikasi ke aplikasi HP, email, atau pop-up.

---

## ⚠️ Peringatan risiko

Trading, terutama scalping dengan leverage, **berisiko tinggi** dan sebagian besar trader ritel mengalami kerugian. Tidak ada indikator yang selalu benar, dan hasil backtest tidak menjamin hasil di masa depan. Indikator ini adalah **alat bantu analisis, bukan saran keuangan**. Jangan pernah memakai uang yang tidak siap Anda relakan.
