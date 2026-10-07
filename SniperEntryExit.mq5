//+------------------------------------------------------------------+
//|                                            SniperEntryExit.mq5   |
//|        Konversi dari TradingView "Sniper Entry/Exit with SL&TP"  |
//+------------------------------------------------------------------+
#property copyright "Converted from TradingView Pine v6"
#property version   "1.00"
#property description "EMA 9/21 cross + dual score dashboard + ATR based SL & TP1-TP5"
#property indicator_chart_window
#property indicator_buffers 13
#property indicator_plots   7

//--- plot 0 : EMA ribbon (fill)
#property indicator_label1  "EMA Ribbon"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'110,190,120',C'225,120,120'
//--- plot 1 : EMA 9
#property indicator_label2  "EMA 9"
#property indicator_type2   DRAW_LINE
#property indicator_color2  C'76,175,80'
#property indicator_width2  1
//--- plot 2 : EMA 21
#property indicator_label3  "EMA 21"
#property indicator_type3   DRAW_LINE
#property indicator_color3  C'244,67,54'
#property indicator_width3  1
//--- plot 3 : VWAP (hijau di atas harga, merah di bawah)
#property indicator_label4  "VWAP"
#property indicator_type4   DRAW_COLOR_LINE
#property indicator_color4  C'76,175,80',C'244,67,54'
#property indicator_width4  2
//--- plot 4 : BUY arrow
#property indicator_label5  "BUY"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  C'46,160,67'
#property indicator_width5  3
//--- plot 5 : SELL arrow
#property indicator_label6  "SELL"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  C'220,50,47'
#property indicator_width6  3
//--- plot 6 : warna candle (signal = hitam, retest = oranye)
#property indicator_label7  "Signal/Retest Candle"
#property indicator_type7   DRAW_COLOR_CANDLES
#property indicator_color7  clrBlack,clrOrange
#property indicator_width7  1

//--- inputs
enum ENUM_TXT_SIZE { TXT_TINY, TXT_SMALL, TXT_NORMAL, TXT_LARGE, TXT_HUGE };

input group "Visuals & UI"
input ENUM_TXT_SIZE InpDashSize       = TXT_SMALL;   // Dashboard Font Size
input ENUM_TXT_SIZE InpTradeSize      = TXT_SMALL;   // Trade Label Size
input bool          InpShowDashboard  = true;        // Tampilkan Dashboard
input bool          InpShowRibbon     = true;        // Tampilkan EMA Ribbon (fill)
input bool          InpShowSignalText = true;        // Tampilkan teks BUY / SELL
input bool          InpColorCandles   = true;        // Warnai candle signal/retest
input color         InpSignalBarColor = clrBlack;    // Warna candle signal
input color         InpRetestBarColor = clrOrange;   // Warna candle retest
input int           InpLabelOffset    = 12;          // Label Right Offset (Bars)

input group "Risk Management"
input double        InpAtrMult        = 1.5;         // SL ATR Multiplier

input group "Alerts"
input bool          InpAlerts         = true;        // Alert saat BUY/SELL baru

//--- konstanta
#define PFX        "SNP_"
#define LEN        14
#define ROWS       16
const color C_GRN  = C'46,160,67';
const color C_RED  = C'220,50,47';
const color C_GRY  = C'128,128,128';
const color C_TURQ = C'64,224,208';   // #40E0D0 (target tercapai)
const color C_BG   = C'255,249,196';  // #FFF9C4 (latar dashboard)

//--- buffers
double B_F1[], B_F2[];                 // fill
double B_E9[], B_E21[];
double B_VW[], B_VWC[];
double B_BUY[], B_SELL[];
double B_CO[], B_CH[], B_CL[], B_CC[], B_CCOL[];

//--- array kalkulasi internal (per bar)
double g_e12[], g_e26[], g_macd[], g_msig[];
double g_gain[], g_loss[], g_rsi[], g_atr[];
double g_smTR[], g_smP[], g_smM[], g_adx[];
double g_cpv[], g_cv[], g_r5[];

//--- state trade
struct STrade
  {
   int      sig;       // 1 buy, -1 sell, 0 belum ada
   double   entry, sl;
   double   tp[5];
   bool     hit[5];
   datetime t;         // waktu bar signal
  };
STrade   g_com;        // state yang sudah "committed" (sampai bar sebelum bar terakhir)
STrade   g_fin;        // state akhir (setelah bar terakhir) untuk digambar
int      g_h5 = INVALID_HANDLE;
datetime g_lastAlert = 0;

//--- forward declarations
void SignalText(const datetime t, const bool isBuy, const double price);
void DrawTrade(const STrade &st, const datetime lastTime);
void DrawDashboard(const double bullPct, const double bearPct, const string biasText,
                   const color biasCol, const double c, const double vw, const double rsi,
                   const double m, const double s, const double adx, const double atr,
                   const bool hiVol, const double r5, const bool trig);

//+------------------------------------------------------------------+
int FontSize(const ENUM_TXT_SIZE s)
  {
   switch(s)
     {
      case TXT_TINY:   return 7;
      case TXT_SMALL:  return 9;
      case TXT_NORMAL: return 11;
      case TXT_LARGE:  return 14;
     }
   return 18;
  }
//+------------------------------------------------------------------+
void ResetState(STrade &s)
  {
   s.sig = 0; s.entry = 0; s.sl = 0; s.t = 0;
   for(int k = 0; k < 5; k++) { s.tp[k] = 0; s.hit[k] = false; }
  }
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, B_F1,  INDICATOR_DATA);
   SetIndexBuffer(1, B_F2,  INDICATOR_DATA);
   SetIndexBuffer(2, B_E9,  INDICATOR_DATA);
   SetIndexBuffer(3, B_E21, INDICATOR_DATA);
   SetIndexBuffer(4, B_VW,  INDICATOR_DATA);
   SetIndexBuffer(5, B_VWC, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(6, B_BUY, INDICATOR_DATA);
   SetIndexBuffer(7, B_SELL,INDICATOR_DATA);
   SetIndexBuffer(8, B_CO,  INDICATOR_DATA);
   SetIndexBuffer(9, B_CH,  INDICATOR_DATA);
   SetIndexBuffer(10,B_CL,  INDICATOR_DATA);
   SetIndexBuffer(11,B_CC,  INDICATOR_DATA);
   SetIndexBuffer(12,B_CCOL,INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(4, PLOT_ARROW, 233);   // panah naik
   PlotIndexSetInteger(5, PLOT_ARROW, 234);   // panah turun
   for(int p = 0; p < 7; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(6, PLOT_LINE_COLOR, 0, InpSignalBarColor);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, 1, InpRetestBarColor);
   if(!InpShowRibbon)   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   if(!InpColorCandles) PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE);

   g_h5 = iRSI(_Symbol, PERIOD_M5, LEN, PRICE_CLOSE);
   if(g_h5 == INVALID_HANDLE)
     {
      Print("Gagal membuat handle RSI M5");
      return INIT_FAILED;
     }
   ResetState(g_com);
   ResetState(g_fin);
   IndicatorSetString(INDICATOR_SHORTNAME, "Sniper Entry/Exit");
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
   if(g_h5 != INVALID_HANDLE) IndicatorRelease(g_h5);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
double Rma(const double prev, const double x, const int n, const int len)
  {
   return (n <= len) ? (prev * (n - 1) + x) / n : (prev * (len - 1) + x) / len;
  }
//+------------------------------------------------------------------+
void RS(double &a[], const int n) { ArrayResize(a, n); }
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   if(rates_total < 50) return 0;
   if(BarsCalculated(g_h5) <= 0) return 0;

   int start = (prev_calculated <= 1) ? 0 : prev_calculated - 1;
   if(prev_calculated == 0) { ResetState(g_com); ResetState(g_fin); }

   RS(g_e12, rates_total);  RS(g_e26, rates_total);  RS(g_macd, rates_total); RS(g_msig, rates_total);
   RS(g_gain, rates_total); RS(g_loss, rates_total); RS(g_rsi, rates_total);  RS(g_atr, rates_total);
   RS(g_smTR, rates_total); RS(g_smP, rates_total);  RS(g_smM, rates_total);  RS(g_adx, rates_total);
   RS(g_cpv, rates_total);  RS(g_cv, rates_total);   RS(g_r5, rates_total);

   //--- RSI 5 menit (request.security "5")
   int off = (PeriodSeconds() > 300) ? PeriodSeconds() - 1 : 0;
   int n0 = iBarShift(_Symbol, PERIOD_M5, time[start] + off, false);
   int need = (n0 >= 0) ? n0 + 2 : BarsCalculated(g_h5);
   double r5arr[];
   ArraySetAsSeries(r5arr, true);
   int copied = CopyBuffer(g_h5, 0, 0, need, r5arr);
   if(copied < 0) copied = 0;

   bool   lastTrig = false;
   double bullPct = 0, bearPct = 0;
   double a_close = 0, a_vw = 0, a_rsi = 0, a_m = 0, a_s = 0, a_adx = 0, a_atr = 0, a_r5 = 50;
   bool   a_hiVol = false;

   for(int i = start; i < rates_total; i++)
     {
      bool isLast = (i == rates_total - 1);
      double c = close[i];

      //--- VWAP (hlc3, reset tiap hari)
      double hlc3 = (high[i] + low[i] + c) / 3.0;
      double vv = (double)tick_volume[i]; if(vv <= 0) vv = 1;
      bool newDay = (i == 0) || (time[i] / 86400 != time[i - 1] / 86400);
      g_cpv[i] = (newDay ? 0 : g_cpv[i - 1]) + hlc3 * vv;
      g_cv[i]  = (newDay ? 0 : g_cv[i - 1]) + vv;
      double vw = g_cpv[i] / g_cv[i];
      B_VW[i]  = vw;
      B_VWC[i] = (c > vw) ? 0 : 1;

      //--- RSI 5m
      {
       int sh = iBarShift(_Symbol, PERIOD_M5, time[i] + off, false);
       double r = (sh >= 0 && sh < copied) ? r5arr[sh] : EMPTY_VALUE;
       if(r == EMPTY_VALUE || r > 100 || r < 0) r = (i > 0) ? g_r5[i - 1] : 50;
       g_r5[i] = r;
      }

      double tr;
      if(i == 0)
        {
         B_E9[0] = c; B_E21[0] = c;
         g_e12[0] = c; g_e26[0] = c; g_macd[0] = 0; g_msig[0] = 0;
         g_gain[0] = 0; g_loss[0] = 0; g_rsi[0] = 50;
         tr = high[0] - low[0];
         g_atr[0] = tr; g_smTR[0] = tr; g_smP[0] = 0; g_smM[0] = 0; g_adx[0] = 0;
         B_F1[0] = B_F2[0] = B_BUY[0] = B_SELL[0] = EMPTY_VALUE;
         B_CO[0] = B_CH[0] = B_CL[0] = B_CC[0] = EMPTY_VALUE; B_CCOL[0] = 0;
         continue;
        }

      //--- EMA 9 / 21
      B_E9[i]  = B_E9[i - 1]  + (c - B_E9[i - 1])  * 2.0 / (9 + 1);
      B_E21[i] = B_E21[i - 1] + (c - B_E21[i - 1]) * 2.0 / (21 + 1);

      //--- MACD 12/26/9
      g_e12[i]  = g_e12[i - 1] + (c - g_e12[i - 1]) * 2.0 / 13.0;
      g_e26[i]  = g_e26[i - 1] + (c - g_e26[i - 1]) * 2.0 / 27.0;
      g_macd[i] = g_e12[i] - g_e26[i];
      g_msig[i] = g_msig[i - 1] + (g_macd[i] - g_msig[i - 1]) * 2.0 / 10.0;

      //--- RSI 14 (Wilder)
      double ch = c - close[i - 1];
      g_gain[i] = Rma(g_gain[i - 1], MathMax(ch, 0), i, LEN);
      g_loss[i] = Rma(g_loss[i - 1], MathMax(-ch, 0), i, LEN);
      if(g_gain[i] + g_loss[i] == 0)  g_rsi[i] = 50;
      else if(g_loss[i] == 0)         g_rsi[i] = 100;
      else                            g_rsi[i] = 100.0 - 100.0 / (1.0 + g_gain[i] / g_loss[i]);

      //--- ATR 14 (RMA) + ADX 14
      tr = MathMax(high[i] - low[i], MathMax(MathAbs(high[i] - close[i - 1]), MathAbs(low[i] - close[i - 1])));
      g_atr[i] = Rma(g_atr[i - 1], tr, i + 1, LEN);

      double up = high[i] - high[i - 1];
      double dn = low[i - 1] - low[i];
      double pdm = (up > dn && up > 0) ? up : 0;
      double mdm = (dn > up && dn > 0) ? dn : 0;
      g_smTR[i] = Rma(g_smTR[i - 1], tr,  i + 1, LEN);
      g_smP[i]  = Rma(g_smP[i - 1],  pdm, i + 1, LEN);
      g_smM[i]  = Rma(g_smM[i - 1],  mdm, i + 1, LEN);
      double pl = (g_smTR[i] > 0) ? 100.0 * g_smP[i] / g_smTR[i] : 0;
      double mi = (g_smTR[i] > 0) ? 100.0 * g_smM[i] / g_smTR[i] : 0;
      double sm = pl + mi;
      double dx = 100.0 * MathAbs(pl - mi) / (sm == 0 ? 1 : sm);
      g_adx[i] = Rma(g_adx[i - 1], dx, i + 1, LEN);

      //--- rata-rata volume 20
      int nv = MathMin(20, i + 1);
      double sv = 0;
      for(int k = 0; k < nv; k++) sv += (double)tick_volume[i - k];
      double vavg = sv / nv;
      bool hiVol = ((double)tick_volume[i] > vavg);

      double e9 = B_E9[i], e21 = B_E21[i];
      double rsi = g_rsi[i], m = g_macd[i], s = g_msig[i], adx = g_adx[i], atr = g_atr[i], r5 = g_r5[i];

      //--- dual score
      double bS = 0, rS = 0;
      bS += (c > vw ? 1 : 0); bS += (rsi > 50 ? 1 : 0); bS += (m > s ? 1 : 0);
      bS += (e9 > e21 ? 1 : 0); bS += (adx > 25 && c > e9 ? 1 : 0);
      bS += (hiVol && c > open[i] ? 1 : 0); bS += (r5 > 50 ? 1 : 0);
      rS += (c < vw ? 1 : 0); rS += (rsi < 50 ? 1 : 0); rS += (m < s ? 1 : 0);
      rS += (e9 < e21 ? 1 : 0); rS += (adx > 25 && c < e9 ? 1 : 0);
      rS += (hiVol && c < open[i] ? 1 : 0); rS += (r5 < 50 ? 1 : 0);

      //--- signal & trade setup
      STrade st = g_com;
      bool buyC  = (e9 > e21 && B_E9[i - 1] <= B_E21[i - 1]);
      bool sellC = (e9 < e21 && B_E9[i - 1] >= B_E21[i - 1]);
      bool trigB = buyC  && st.sig <= 0;
      bool trigS = sellC && st.sig >= 0;
      if(trigB || trigS)
        {
         st.sig = trigB ? 1 : -1;
         st.entry = c;
         double risk = atr * InpAtrMult;
         st.sl = trigB ? c - risk : c + risk;
         for(int k = 0; k < 5; k++)
           {
            st.tp[k] = trigB ? c + risk * (k + 1) : c - risk * (k + 1);
            st.hit[k] = false;
           }
         st.t = time[i];
        }
      //--- deteksi target tercapai
      if(st.sig == 1)
         for(int k = 0; k < 5; k++) if(high[i] >= st.tp[k]) st.hit[k] = true;
      if(st.sig == -1)
         for(int k = 0; k < 5; k++) if(low[i] <= st.tp[k]) st.hit[k] = true;

      if(isLast) g_fin = st; else g_com = st;

      //--- buffer plot
      if(InpShowRibbon) { B_F1[i] = e9; B_F2[i] = e21; }
      else              { B_F1[i] = EMPTY_VALUE; B_F2[i] = EMPTY_VALUE; }
      B_BUY[i]  = trigB ? low[i]  - atr * 0.3 : EMPTY_VALUE;
      B_SELL[i] = trigS ? high[i] + atr * 0.3 : EMPTY_VALUE;

      if(InpShowSignalText)
        {
         if(trigB)       SignalText(time[i], true,  low[i]  - atr * 0.6);
         else if(trigS)  SignalText(time[i], false, high[i] + atr * 0.6);
         else if(isLast) ObjectDelete(0, PFX "SG" + IntegerToString((long)time[i]));
        }

      bool retest = (st.sig == 1  && low[i]  <= e9 && low[i]  > e21) ||
                    (st.sig == -1 && high[i] >= e9 && high[i] < e21);
      if(InpColorCandles && (trigB || trigS || retest))
        {
         B_CO[i] = open[i]; B_CH[i] = high[i]; B_CL[i] = low[i]; B_CC[i] = c;
         B_CCOL[i] = (trigB || trigS) ? 0 : 1;
        }
      else
        {
         B_CO[i] = EMPTY_VALUE; B_CH[i] = EMPTY_VALUE; B_CL[i] = EMPTY_VALUE; B_CC[i] = EMPTY_VALUE;
         B_CCOL[i] = 0;
        }

      if(isLast)
        {
         lastTrig = (trigB || trigS);
         bullPct = bS / 7.0 * 100.0; bearPct = rS / 7.0 * 100.0;
         a_close = c; a_vw = vw; a_rsi = rsi; a_m = m; a_s = s; a_adx = adx; a_atr = atr;
         a_r5 = r5; a_hiVol = hiVol;

         if(InpAlerts && prev_calculated > 0 && lastTrig && g_lastAlert != time[i])
           {
            g_lastAlert = time[i];
            Alert(_Symbol, " ", EnumToString((ENUM_TIMEFRAMES)Period()), ": ",
                  trigB ? "BUY" : "SELL", " @ ", DoubleToString(c, _Digits),
                  "  SL ", DoubleToString(st.sl, _Digits),
                  "  TP1 ", DoubleToString(st.tp[0], _Digits));
           }
        }
     }

   //--- bias
   string biasText = (bullPct - bearPct) >= 40 ? "STRONG BULL" :
                     (bearPct - bullPct) >= 40 ? "STRONG BEAR" :
                     bullPct > bearPct ? "MILD BULL" : "MILD BEAR";
   color biasCol = biasText == "STRONG BULL" ? C_GRN : biasText == "STRONG BEAR" ? C_RED : C_GRY;

   DrawTrade(g_fin, time[rates_total - 1]);
   if(InpShowDashboard)
      DrawDashboard(bullPct, bearPct, biasText, biasCol, a_close, a_vw, a_rsi, a_m, a_s,
                    a_adx, a_atr, a_hiVol, a_r5, lastTrig);
   ChartRedraw();
   return rates_total;
  }
//+------------------------------------------------------------------+
//| Helper objek                                                     |
//+------------------------------------------------------------------+
void PutLine(const string name, const datetime t1, const datetime t2, const double p,
             const color clr, const ENUM_LINE_STYLE style, const int width)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p, t2, p);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
  }
//+------------------------------------------------------------------+
void PutText(const string name, const datetime t, const double p, const string txt, const color clr)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
     }
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize(InpTradeSize));
  }
//+------------------------------------------------------------------+
void SignalText(const datetime t, const bool isBuy, const double price)
  {
   string name = PFX "SG" + IntegerToString((long)t);
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
     }
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
   ObjectSetString(0, name, OBJPROP_TEXT, isBuy ? "BUY" : "SELL");
   ObjectSetInteger(0, name, OBJPROP_COLOR, isBuy ? C_GRN : C_RED);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize(InpTradeSize));
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBuy ? ANCHOR_UPPER : ANCHOR_LOWER);
  }
//+------------------------------------------------------------------+
void DrawTrade(const STrade &st, const datetime lastTime)
  {
   if(st.sig == 0) { ObjectsDeleteAll(0, PFX "T"); return; }

   datetime t1 = st.t;
   datetime t2 = st.t + (datetime)(PeriodSeconds() * 20);
   datetime tx = lastTime + (datetime)(PeriodSeconds() * InpLabelOffset);

   PutLine(PFX "TE",  t1, t2, st.entry, C'41,121,255', STYLE_SOLID, 2);
   PutLine(PFX "TSL", t1, t2, st.sl,    C_RED,         STYLE_SOLID, 2);

   color base[5] = { C_GRN, C_GRN, C_GRN, C'0,100,0', C'0,70,0' };
   int   wd[5]   = { 1, 1, 1, 2, 3 };
   for(int k = 0; k < 5; k++)
     {
      color clr = st.hit[k] ? C_TURQ : base[k];
      PutLine(PFX "TT" + IntegerToString(k + 1), t1, t2, st.tp[k], clr,
              k < 3 ? STYLE_DASH : STYLE_SOLID, wd[k]);
      PutText(PFX "TLT" + IntegerToString(k + 1), tx, st.tp[k],
              "TP" + IntegerToString(k + 1) + ": " + DoubleToString(st.tp[k], _Digits) +
              (st.hit[k] ? "  [HIT]" : ""), clr);
     }
   PutText(PFX "TLE",  tx, st.entry, "ENTRY: " + DoubleToString(st.entry, _Digits), C'41,121,255');
   PutText(PFX "TLSL", tx, st.sl,    "SL: "    + DoubleToString(st.sl, _Digits),    C_RED);
  }
//+------------------------------------------------------------------+
void PutRect(const string name, const int x, const int y, const int w, const int h, const color bg)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_COLOR, C'170,170,170');
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
  }
//+------------------------------------------------------------------+
void PutLabel(const string name, const string txt, const int x, const int y,
              const ENUM_ANCHOR_POINT anc, const color clr, const int fs)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
     }
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anc);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
  }
//+------------------------------------------------------------------+
void DrawDashboard(const double bullPct, const double bearPct, const string biasText,
                   const color biasCol, const double c, const double vw, const double rsi,
                   const double m, const double s, const double adx, const double atr,
                   const bool hiVol, const double r5, const bool trig)
  {
   int fs = FontSize(InpDashSize);
   int rowH = fs * 2 + 6;
   int w = fs * 24;
   int mar = 10, top = 20;

   string t[ROWS], v[ROWS];
   color  tc[ROWS], vc[ROWS], tb[ROWS], vb[ROWS];
   for(int r = 0; r < ROWS; r++) { tc[r] = clrBlack; tb[r] = C_BG; vb[r] = C_BG; }

   t[0] = "BULL SCORE";  v[0] = DoubleToString(bullPct, 0) + "%";
   tc[0] = vc[0] = clrWhite; tb[0] = vb[0] = C_GRN;
   t[1] = "BEAR SCORE";  v[1] = DoubleToString(bearPct, 0) + "%";
   tc[1] = vc[1] = clrWhite; tb[1] = vb[1] = C_RED;
   t[2] = "MARKET BIAS"; v[2] = biasText;
   tc[2] = vc[2] = clrWhite; tb[2] = clrBlack; vb[2] = biasCol;

   t[3]  = "Price/VWAP"; v[3]  = c > vw ? "ABOVE" : "BELOW";            vc[3]  = c > vw ? C_GRN : C_RED;
   t[4]  = "RSI (14)";   v[4]  = DoubleToString(rsi, 1);                vc[4]  = rsi > 50 ? C_GRN : C_RED;
   t[5]  = "MACD Trend"; v[5]  = m > s ? "BULL" : "BEAR";               vc[5]  = m > s ? C_GRN : C_RED;
   t[6]  = "ADX Power";  v[6]  = DoubleToString(adx, 1);                vc[6]  = adx > 25 ? C_GRN : C_GRY;
   t[7]  = "EMA Cross";  v[7]  = B_E9[ArraySize(B_E9) - 1] > B_E21[ArraySize(B_E21) - 1] ? "BULL" : "BEAR";
   vc[7] = v[7] == "BULL" ? C_GRN : C_RED;
   t[8]  = "ATR 14";     v[8]  = DoubleToString(atr, _Digits);          vc[8]  = clrBlack;
   t[9]  = "Vol Status"; v[9]  = hiVol ? "HIGH" : "LOW";                vc[9]  = hiVol ? C_GRN : C_GRY;
   t[10] = "5m RSI";     v[10] = DoubleToString(r5, 1);                 vc[10] = r5 > 50 ? C_GRN : C_RED;
   t[11] = "MACD Main";  v[11] = DoubleToString(m, _Digits + 1);        vc[11] = clrBlack;
   t[12] = "MACD Sig";   v[12] = DoubleToString(s, _Digits + 1);        vc[12] = clrBlack;
   t[13] = "Trend Str";  v[13] = adx > 25 ? "STRONG" : "WEAK";          vc[13] = adx > 25 ? C_GRN : C_RED;
   t[14] = "Status";     v[14] = trig ? "NEW" : "WAIT";                 vc[14] = clrBlack;
   t[15] = "Sniper Mode";v[15] = "KHANSAAB V.02";                       vc[15] = clrBlue;

   for(int r = 0; r < ROWS; r++)
     {
      int y = top + r * rowH;
      string id = IntegerToString(r);
      PutRect(PFX "DRL" + id, mar + w / 2, y, w / 2, rowH, tb[r]);
      PutRect(PFX "DRR" + id, mar,         y, w / 2, rowH, vb[r]);
      PutLabel(PFX "DT" + id, t[r], mar + w - 6, y + 3, ANCHOR_LEFT_UPPER,  tc[r], fs);
      PutLabel(PFX "DV" + id, v[r], mar + 6,     y + 3, ANCHOR_RIGHT_UPPER, vc[r], fs);
     }
  }
//+------------------------------------------------------------------+
