//+------------------------------------------------------------------+
//|                                          SniperEntryExitEA.mq5   |
//|  EA dari indikator "Sniper Entry/Exit with SL&TP"                |
//|  BUY  : EMA9 cross up   EMA21 dan harga di ATAS  VWAP            |
//|  SELL : EMA9 cross down EMA21 dan harga di BAWAH VWAP            |
//|  Filter tambahan: Trend Str (ADX 14 > batas, default 25)         |
//|  SL = ATR(14) x multiplier, TP = kelipatan jarak SL (TP1..TP5)   |
//|  Breakeven: SL digeser ke entry setelah harga mencapai TP1       |
//+------------------------------------------------------------------+
#property copyright "EA based on Sniper Entry/Exit indicator"
#property version   "1.00"

#include <Trade\Trade.mqh>

input group "Trade"
input double InpLot           = 0.10;      // Lot tetap (dipakai jika Risk % = 0)
input double InpRiskPct       = 0.0;       // Risk % per trade dari balance (0 = pakai lot tetap)
input ulong  InpMagic         = 20250101;  // Magic number
input int    InpDeviation     = 20;        // Slippage maksimum (points)
input int    InpMaxSpread     = 0;         // Spread maksimum (points), 0 = tanpa batas
input bool   InpCloseOpposite = true;      // Tutup posisi lawan saat sinyal baru

input group "SL & TP (sama dengan indikator)"
input double InpAtrMult       = 1.5;       // SL ATR Multiplier
input int    InpTpLevel       = 2;         // TP memakai level ke- (1..5) x jarak SL

input group "Breakeven"
input bool   InpUseBE         = true;      // Geser SL ke breakeven setelah TP1
input double InpBeTriggerR    = 1.0;       // Trigger: kelipatan jarak SL (1.0 = level TP1)
input int    InpBeOffsetPts   = 0;         // Offset di atas/bawah entry (points) untuk tutup spread/komisi

input group "Filter Trend Strength (Trend Str di dashboard)"
input bool   InpUseAdx        = true;      // Hanya entry jika Trend Str = STRONG
input double InpAdxMin        = 25.0;      // ADX minimum (STRONG jika ADX > nilai ini)

input group "Lainnya"
input int    InpBars          = 1000;      // Jumlah bar historis untuk kalkulasi

#define LEN 14

CTrade g_trade;
datetime g_lastBar = 0;

//+------------------------------------------------------------------+
double Rma(const double prev, const double x, const int n, const int len)
  {
   return (n <= len) ? (prev * (n - 1) + x) / n : (prev * (len - 1) + x) / len;
  }
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTpLevel < 1 || InpTpLevel > 5)
     {
      Print("InpTpLevel harus 1..5");
      return INIT_PARAMETERS_INCORRECT;
     }
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpDeviation);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_lastBar = iTime(_Symbol, _Period, 0);   // jangan trade sinyal lama saat EA dipasang
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//| Hitung sinyal pada bar tertutup terakhir.                        |
//| return: 1 = BUY, -1 = SELL, 0 = tidak ada. atr = ATR(14) RMA.    |
//+------------------------------------------------------------------+
int GetSignal(double &atr)
  {
   MqlRates r[];
   int n = CopyRates(_Symbol, _Period, 1, InpBars, r);   // r[0] terlama, r[n-1] = bar tertutup terakhir
   if(n < 100) return 0;

   double e9 = r[0].close, e21 = r[0].close, pe9 = e9, pe21 = e21;
   double a = r[0].high - r[0].low;
   double cpv = 0, cv = 0;
   double sp = 0, sm = 0, adx = 0;   // smoothed +DM, -DM, ADX

   for(int i = 0; i < n; i++)
     {
      double c = r[i].close;
      if(i > 0)
        {
         pe9 = e9; pe21 = e21;
         e9  += (c - e9)  * 2.0 / (9 + 1);
         e21 += (c - e21) * 2.0 / (21 + 1);
         double tr = MathMax(r[i].high - r[i].low,
                     MathMax(MathAbs(r[i].high - r[i - 1].close), MathAbs(r[i].low - r[i - 1].close)));
         a = Rma(a, tr, i + 1, LEN);

         double up = r[i].high - r[i - 1].high;
         double dn = r[i - 1].low - r[i].low;
         double pdm = (up > dn && up > 0) ? up : 0;
         double mdm = (dn > up && dn > 0) ? dn : 0;
         sp = Rma(sp, pdm, i + 1, LEN);
         sm = Rma(sm, mdm, i + 1, LEN);
         double pl = (a > 0) ? 100.0 * sp / a : 0;
         double mi = (a > 0) ? 100.0 * sm / a : 0;
         double sum = pl + mi;
         double dx = 100.0 * MathAbs(pl - mi) / (sum == 0 ? 1 : sum);
         adx = Rma(adx, dx, i + 1, LEN);
        }
      bool newDay = (i == 0) || (r[i].time / 86400 != r[i - 1].time / 86400);
      double v = (double)r[i].tick_volume; if(v <= 0) v = 1;
      double hlc3 = (r[i].high + r[i].low + c) / 3.0;
      cpv = (newDay ? 0 : cpv) + hlc3 * v;
      cv  = (newDay ? 0 : cv)  + v;
     }

   double vwap = cpv / cv;
   double c = r[n - 1].close;
   atr = a;
   if(InpUseAdx && adx <= InpAdxMin) return 0;   // Trend Str = WEAK, jangan entry

   bool buyCross  = (e9 > e21 && pe9 <= pe21);
   bool sellCross = (e9 < e21 && pe9 >= pe21);

   if(buyCross  && c > vwap) return 1;    // BUY hanya jika harga di atas VWAP
   if(sellCross && c < vwap) return -1;   // SELL hanya jika harga di bawah VWAP
   return 0;
  }
//+------------------------------------------------------------------+
bool FindPosition(ENUM_POSITION_TYPE &type, ulong &ticket)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = tk;
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
double CalcLot(const double slDist)
  {
   double lot = InpLot;
   if(InpRiskPct > 0)
     {
      double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tv > 0 && ts > 0 && slDist > 0)
        {
         double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
         lot = riskMoney / (slDist / ts * tv);
        }
     }
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0) lot = MathFloor(lot / step) * step;
   lot = MathMax(vmin, MathMin(vmax, lot));
   return NormalizeDouble(lot, 2);
  }
//+------------------------------------------------------------------+
//| Geser SL ke entry (+offset) saat harga mencapai level TP1.       |
//| Jarak risiko awal dihitung dari TP: risk = |TP - open| / TpLevel |
//+------------------------------------------------------------------+
void ManageBreakeven()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      if(tp <= 0) continue;

      double risk   = MathAbs(tp - open) / InpTpLevel;
      double offset = InpBeOffsetPts * _Point;
      double minDist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1) * _Point;
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(type == POSITION_TYPE_BUY)
        {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSl = NormalizeDouble(open + offset, _Digits);
         if(bid >= open + risk * InpBeTriggerR && (sl == 0 || sl < newSl) && bid - newSl >= minDist)
            if(!g_trade.PositionModify(tk, newSl, tp))
               Print("Breakeven BUY gagal: ", g_trade.ResultRetcodeDescription());
        }
      else
        {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSl = NormalizeDouble(open - offset, _Digits);
         if(ask <= open - risk * InpBeTriggerR && (sl == 0 || sl > newSl) && newSl - ask >= minDist)
            if(!g_trade.PositionModify(tk, newSl, tp))
               Print("Breakeven SELL gagal: ", g_trade.ResultRetcodeDescription());
        }
     }
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   if(InpUseBE) ManageBreakeven();   // dicek setiap tick

   datetime bar = iTime(_Symbol, _Period, 0);
   if(bar == g_lastBar) return;      // proses sekali per bar baru
   g_lastBar = bar;

   double atr = 0;
   int sig = GetSignal(atr);
   if(sig == 0 || atr <= 0) return;

   //--- posisi yang sudah ada
   ENUM_POSITION_TYPE ptype; ulong ticket;
   if(FindPosition(ptype, ticket))
     {
      bool opposite = (sig == 1 && ptype == POSITION_TYPE_SELL) || (sig == -1 && ptype == POSITION_TYPE_BUY);
      if(!opposite) return;                 // sudah ada posisi searah
      if(!InpCloseOpposite) return;
      if(!g_trade.PositionClose(ticket))
        {
         Print("Gagal menutup posisi lawan: ", g_trade.ResultRetcodeDescription());
         return;
        }
     }

   //--- filter spread
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(InpMaxSpread > 0 && (ask - bid) / _Point > InpMaxSpread)
     {
      Print("Spread terlalu lebar, entry dilewati");
      return;
     }

   //--- SL & TP mengikuti indikator
   double risk = atr * InpAtrMult;
   double minDist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1) * _Point;
   if(risk < minDist) risk = minDist;

   double lot = CalcLot(risk);
   if(sig == 1)
     {
      double sl = NormalizeDouble(ask - risk, _Digits);
      double tp = NormalizeDouble(ask + risk * InpTpLevel, _Digits);
      if(!g_trade.Buy(lot, _Symbol, 0, sl, tp, "Sniper BUY"))
         Print("BUY gagal: ", g_trade.ResultRetcodeDescription());
     }
   else
     {
      double sl = NormalizeDouble(bid + risk, _Digits);
      double tp = NormalizeDouble(bid - risk * InpTpLevel, _Digits);
      if(!g_trade.Sell(lot, _Symbol, 0, sl, tp, "Sniper SELL"))
         Print("SELL gagal: ", g_trade.ResultRetcodeDescription());
     }
  }
//+------------------------------------------------------------------+
