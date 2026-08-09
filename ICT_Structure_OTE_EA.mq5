//+------------------------------------------------------------------+
//|                                         ICT_Structure_OTE_EA.mq5  |
//|   Portage MT5 de la strategie "ICT Structure OTE" (TradingView).  |
//|   - Structure interne (swings via pivots) -> etat trend BOS/CHoCH |
//|   - OTE (corps) 1 par cassure, tracee au pic confirme             |
//|   - LONG + SHORT, dans killzones/macros Londres-NY                 |
//|   - Filtre A+ : ne trader que dans le sens du biais D1 (EMA10/20)  |
//|   - SL meche du swing origine +/- buffer ; TP en R + break-even   |
//|   - Risque % + echelle anti-DD ; cap perte/jour ; flat 16:15 NY   |
//|   Symbol-agnostic : attacher sur US500 / US30 / USTEC ...         |
//+------------------------------------------------------------------+
#property copyright "ICT Structure OTE"
#property version   "1.10"   // zone OTE realignee 0.666 -> 0.79 (indicateur v2.2)
#property strict

#include <Trade/Trade.mqh>
CTrade         trade;
CPositionInfo  posinfo;

//====================== INPUTS ======================
input group "== Structure & OTE =="
input int    InpStructLen   = 5;      // Longueur structure (pivots)
input double InpOteShallow  = 0.666;  // Fib haut zone (0.666)
input double InpOteDeep     = 0.79;   // Fib bas zone (0.79)
input bool   InpTradeLong   = true;   // Trader Long
input bool   InpTradeShort  = true;   // Trader Short
input int    InpArmBars     = 30;     // Duree d'armement OTE (barres)

input group "== Biais D1 (filtre A+) =="
input bool   InpUseD1Filter = true;   // Ne trader que A+ (aligne biais D1)
input int    InpEmaFast     = 10;     // EMA rapide D1
input int    InpEmaSlow     = 20;     // EMA lente D1

input group "== Killzones (heure New York) =="
input bool   InpUseKZ       = true;   // Restreindre aux KZ + macros Londres/NY
input int    InpNYGMTOffset = -4;     // Decalage GMT de NY (EDT=-4, EST=-5)

input group "== Risque & Sorties =="
input double InpRiskPct     = 1.0;    // Risque par trade (%)
input bool   InpUseLadder   = true;   // Echelle anti-DD (1% ->0.5% ->0.25%)
input double InpSLBuffer    = 5.0;    // Buffer SL (points de prix)
input double InpTPR         = 3.0;    // TP (R)
input double InpBER         = 2.0;    // Break-even a (R)
input double InpBEBuffer    = 5.0;    // BE buffer (points de prix)
input bool   InpUseDailyCap = true;   // Cap perte / jour
input double InpDailyCapPct = 3.0;    // Cap perte jour (%)
input int    InpFlatHour    = 16;     // Flat a l'heure (NY)
input int    InpFlatMin     = 15;     // Flat minute

input group "== Divers =="
input long   InpMagic       = 260709; // Magic number
input int    InpSlippage    = 20;     // Deviation max (points)

//====================== GLOBALS ======================
int      hEmaFast = INVALID_HANDLE;
int      hEmaSlow = INVALID_HANDLE;

// Etat structure interne
double   swHiWick=0, swHiBody=0;   int swHiBroken=0;   datetime swHiTime=0;
double   swLoWick=0, swLoBody=0;   int swLoBroken=0;   datetime swLoTime=0;
bool     haveHi=false, haveLo=false;

int      g_trend=0;
bool     g_pendBull=false, g_pendBear=false;
double   g_pendOrig=0.0, g_pendWick=0.0;

// Armement OTE
bool     g_armActive=false, g_armLong=false, g_armAplus=false;
double   g_armTop=0, g_armBot=0, g_armSL=0;
datetime g_armTime=0;
int      g_armAgeBars=0;

// Suivi position / BE
bool     g_beDone=false;
double   g_posEntry=0, g_posR=0;

// MM
int      g_lossStreak=0;
bool     g_hadPos=false;
datetime g_dayStamp=0;
double   g_dayStartBal=0;

datetime g_lastBar=0;

//+------------------------------------------------------------------+
int OnInit()
  {
   hEmaFast = iMA(_Symbol, PERIOD_D1, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow = iMA(_Symbol, PERIOD_D1, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   if(hEmaFast==INVALID_HANDLE || hEmaSlow==INVALID_HANDLE)
     {
      Print("Erreur creation handles EMA D1");
      return(INIT_FAILED);
     }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("ICT_Structure_OTE_EA initialise sur ", _Symbol);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(hEmaFast!=INVALID_HANDLE) IndicatorRelease(hEmaFast);
   if(hEmaSlow!=INVALID_HANDLE) IndicatorRelease(hEmaSlow);
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
datetime NYNow()               { return TimeGMT() + InpNYGMTOffset*3600; }

bool InRangeMin(int m,int lo,int hi){ return (m>=lo && m<hi); }

// Fenetre valide = KZ (Londres/NYam/NYpm) OU macros Londres/NY (heure NY)
bool InValidWindow()
  {
   if(!InpUseKZ) return true;
   MqlDateTime st; TimeToStruct(NYNow(), st);
   int m = st.hour*60 + st.min;
   int lo[]={120,420,810, 105,165,225,285, 405,465,525,585,645,705, 765,825,885,945};
   int hi[]={300,600,960, 135,195,255,315, 435,495,555,615,675,735, 795,855,915,975};
   for(int i=0;i<ArraySize(lo);i++) if(InRangeMin(m,lo[i],hi[i])) return true;
   return false;
  }

bool IsFlatTime()
  {
   MqlDateTime st; TimeToStruct(NYNow(), st);
   int m = st.hour*60 + st.min;
   return (m >= InpFlatHour*60 + InpFlatMin);
  }

// Biais D1 via EMA10/20 (close>EMA10>EMA20 = haussier)
void GetD1Bias(bool &bull, bool &bear)
  {
   bull=false; bear=false;
   double ef[2], es[2];
   if(CopyBuffer(hEmaFast,0,0,2,ef)<2) return;
   if(CopyBuffer(hEmaSlow,0,0,2,es)<2) return;
   double d1c = iClose(_Symbol, PERIOD_D1, 0);
   bull = (d1c>ef[0] && ef[0]>es[0]);
   bear = (d1c<ef[0] && ef[0]<es[0]);
  }

// Pivot haut a l'index 'sh' (bougies fermees), fenetre +/- InpStructLen
bool IsPivotHigh(int sh)
  {
   double hc = iHigh(_Symbol, PERIOD_CURRENT, sh);
   for(int k=1;k<=InpStructLen;k++)
     {
      if(iHigh(_Symbol,PERIOD_CURRENT,sh-k) > hc) return false;
      if(iHigh(_Symbol,PERIOD_CURRENT,sh+k) > hc) return false;
     }
   return true;
  }
bool IsPivotLow(int sh)
  {
   double lc = iLow(_Symbol, PERIOD_CURRENT, sh);
   for(int k=1;k<=InpStructLen;k++)
     {
      if(iLow(_Symbol,PERIOD_CURRENT,sh-k) < lc) return false;
      if(iLow(_Symbol,PERIOD_CURRENT,sh+k) < lc) return false;
     }
   return true;
  }

// Position de cet EA sur ce symbole ?
bool HasPosition()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==InpMagic) return true;
     }
   return false;
  }

// Lots selon le risque % et la distance SL (en prix)
double CalcLots(double slDist)
  {
   if(slDist<=0) return 0.0;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0 || tickVal<=0) return 0.0;
   double riskPct  = InpUseLadder ? InpRiskPct/MathPow(2.0, MathMin(g_lossStreak,2)) : InpRiskPct;
   double riskCash = AccountInfoDouble(ACCOUNT_EQUITY) * riskPct/100.0;
   double lossPerLot = (slDist/tickSize) * tickVal;
   if(lossPerLot<=0) return 0.0;
   double lots = riskCash/lossPerLot;
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots/vstep)*vstep;
   if(lots<vmin) lots=vmin;      // plancher (comme le backtest TV : min 1 unite)
   if(lots>vmax) lots=vmax;
   return lots;
  }

// Met a jour l'echelle anti-DD quand une position vient de se fermer
void UpdateLadderOnClose()
  {
   bool now = HasPosition();
   if(g_hadPos && !now)   // une position s'est fermee
     {
      if(HistorySelect(TimeCurrent()-7*24*3600, TimeCurrent()+60))
        {
         double lastProfit=0; datetime lastT=0;
         for(int i=HistoryDealsTotal()-1;i>=0;i--)
           {
            ulong d=HistoryDealGetTicket(i);
            if(d==0) continue;
            if(HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
            if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol) continue;
            if(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
            datetime t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
            if(t>=lastT){ lastT=t; lastProfit=HistoryDealGetDouble(d,DEAL_PROFIT)
                                                +HistoryDealGetDouble(d,DEAL_SWAP)
                                                +HistoryDealGetDouble(d,DEAL_COMMISSION); }
           }
         if(lastProfit>0) g_lossStreak=0; else g_lossStreak++;
        }
     }
   g_hadPos = now;
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateLadderOnClose();
   ManageOpenPosition();   // BE + flat (a chaque tick pour reactivite)

   datetime cur = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur==g_lastBar) return;   // logique structure = 1x par barre
   g_lastBar = cur;
   OnNewBar();
  }

//+------------------------------------------------------------------+
//| Nouvelle barre : structure + armement + entree                  |
//+------------------------------------------------------------------+
void OnNewBar()
  {
   int piv = InpStructLen + 1;   // pivot evalue a cet index (bougies fermees)

   bool newHi=false, newLo=false;

   // --- Detection swing HAUT ---
   if(Bars(_Symbol,PERIOD_CURRENT) > 2*InpStructLen+3 && IsPivotHigh(piv))
     {
      datetime t = iTime(_Symbol,PERIOD_CURRENT,piv);
      if(t!=swHiTime)
        {
         swHiWick = iHigh(_Symbol,PERIOD_CURRENT,piv);
         swHiBody = MathMax(iOpen(_Symbol,PERIOD_CURRENT,piv), iClose(_Symbol,PERIOD_CURRENT,piv));
         swHiTime = t; swHiBroken=0; haveHi=true; newHi=true;
        }
     }
   // --- Detection swing BAS ---
   if(Bars(_Symbol,PERIOD_CURRENT) > 2*InpStructLen+3 && IsPivotLow(piv))
     {
      datetime t = iTime(_Symbol,PERIOD_CURRENT,piv);
      if(t!=swLoTime)
        {
         swLoWick = iLow(_Symbol,PERIOD_CURRENT,piv);
         swLoBody = MathMin(iOpen(_Symbol,PERIOD_CURRENT,piv), iClose(_Symbol,PERIOD_CURRENT,piv));
         swLoTime = t; swLoBroken=0; haveLo=true; newLo=true;
        }
     }

   // --- Cassures (BOS/CHoCH) sur cloture de la derniere bougie (shift 1) ---
   double c1 = iClose(_Symbol,PERIOD_CURRENT,1);
   if(haveHi && swHiBroken==0 && c1 > swHiWick)
     {
      g_trend=1; swHiBroken=1;
      g_pendBull=true; g_pendBear=false;
      g_pendOrig=swLoBody; g_pendWick=swLoWick;
     }
   if(haveLo && swLoBroken==0 && c1 < swLoWick)
     {
      g_trend=-1; swLoBroken=1;
      g_pendBear=true; g_pendBull=false;
      g_pendOrig=swHiBody; g_pendWick=swHiWick;
     }

   // --- Armement OTE au pic confirme (1er pivot oppose apres la cassure) ---
   bool bull=false, bear=false; GetD1Bias(bull,bear);
   if(g_pendBull && newHi && g_pendOrig>0)
     {
      double term=swHiBody, orig=g_pendOrig, rng=term-orig;
      double p62=term-InpOteShallow*rng, p79=term-InpOteDeep*rng;
      g_armTop=MathMax(p62,p79); g_armBot=MathMin(p62,p79);
      g_armLong=true; g_armSL=g_pendWick-InpSLBuffer;
      g_armAplus=bull; g_armActive=true; g_armTime=iTime(_Symbol,PERIOD_CURRENT,0); g_armAgeBars=0;
      g_pendBull=false;
     }
   if(g_pendBear && newLo && g_pendOrig>0)
     {
      double term=swLoBody, orig=g_pendOrig, rng=term-orig;   // rng<0 pour un short
      double p62=term-InpOteShallow*rng, p79=term-InpOteDeep*rng;
      g_armTop=MathMax(p62,p79); g_armBot=MathMin(p62,p79);
      g_armLong=false; g_armSL=g_pendWick+InpSLBuffer;
      g_armAplus=bear; g_armActive=true; g_armTime=iTime(_Symbol,PERIOD_CURRENT,0); g_armAgeBars=0;
      g_pendBear=false;
     }

   // --- Expiration / invalidation de l'armement ---
   if(g_armActive)
     {
      g_armAgeBars++;
      double lo1=iLow(_Symbol,PERIOD_CURRENT,1), hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
      if(g_armAgeBars>InpArmBars) g_armActive=false;
      else if(g_armLong  && lo1 < g_armSL) g_armActive=false;
      else if(!g_armLong && hi1 > g_armSL) g_armActive=false;
     }

   // --- Cap perte/jour + reset quotidien ---
   MqlDateTime st; TimeToStruct(NYNow(), st); st.hour=0; st.min=0; st.sec=0;
   datetime dstamp = StructToTime(st);
   if(dstamp!=g_dayStamp){ g_dayStamp=dstamp; g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); }
   double dayPnL = AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBal;
   bool capOk = (!InpUseDailyCap) || (dayPnL > -InpDailyCapPct/100.0*g_dayStartBal);

   // --- Entree (tap de l'OTE sur la derniere bougie) ---
   if(!HasPosition() && g_armActive && capOk && !IsFlatTime() && InValidWindow())
     {
      if(!InpUseD1Filter || g_armAplus)
        {
         double lo1=iLow(_Symbol,PERIOD_CURRENT,1), hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
         double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         if(g_armLong && InpTradeLong && lo1<=g_armTop && bid>g_armSL)
           {
            double entry=ask;
            double dist=entry-g_armSL;
            if(dist>0)
              {
               double lots=CalcLots(dist);
               double tp=entry+InpTPR*dist;
               if(lots>0 && trade.Buy(lots,_Symbol,0.0,g_armSL,tp,"ICT OTE long"))
                 { g_posEntry=entry; g_posR=dist; g_beDone=false; g_armActive=false; }
              }
           }
         else if(!g_armLong && InpTradeShort && hi1>=g_armBot && ask<g_armSL)
           {
            double entry=bid;
            double dist=g_armSL-entry;
            if(dist>0)
              {
               double lots=CalcLots(dist);
               double tp=entry-InpTPR*dist;
               if(lots>0 && trade.Sell(lots,_Symbol,0.0,g_armSL,tp,"ICT OTE short"))
                 { g_posEntry=entry; g_posR=dist; g_beDone=false; g_armActive=false; }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Gestion position ouverte : break-even + flat 16:15              |
//+------------------------------------------------------------------+
void ManageOpenPosition()
  {
   if(!posinfo.SelectByMagic(_Symbol, InpMagic)) return;

   double entry = posinfo.PriceOpen();
   double sl    = posinfo.StopLoss();
   double tp    = posinfo.TakeProfit();
   long   type  = posinfo.PositionType();
   double bid   = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   // Flat 16:15 NY
   if(IsFlatTime()){ trade.PositionClose(_Symbol); return; }

   // Break-even a +BER (R = distance initiale au SL)
   if(!g_beDone && g_posR>0)
     {
      if(type==POSITION_TYPE_BUY && bid >= entry + InpBER*g_posR)
        {
         double nsl=entry+InpBEBuffer;
         if(nsl>sl){ trade.PositionModify(_Symbol,nsl,tp); g_beDone=true; }
        }
      else if(type==POSITION_TYPE_SELL && ask <= entry - InpBER*g_posR)
        {
         double nsl=entry-InpBEBuffer;
         if(nsl<sl || sl==0){ trade.PositionModify(_Symbol,nsl,tp); g_beDone=true; }
        }
     }
  }

//+------------------------------------------------------------------+
//| Ecrit le resume du backtest dans Common\Files\ict_bt_stats.txt   |
//+------------------------------------------------------------------+
double OnTester()
  {
   double init = TesterStatistics(STAT_INITIAL_DEPOSIT);
   double prof = TesterStatistics(STAT_PROFIT);
   double pf   = TesterStatistics(STAT_PROFIT_FACTOR);
   double tr   = TesterStatistics(STAT_TRADES);
   double wins = TesterStatistics(STAT_PROFIT_TRADES);
   double loss = TesterStatistics(STAT_LOSS_TRADES);
   double ddp  = TesterStatistics(STAT_EQUITYDD_PERCENT);
   double ddm  = TesterStatistics(STAT_EQUITY_DD);
   double ep   = TesterStatistics(STAT_EXPECTED_PAYOFF);
   double wr   = (tr>0) ? 100.0*wins/tr : 0.0;
   double pctp = (init>0) ? 100.0*prof/init : 0.0;
   int fh = FileOpen("ict_bt_stats.txt", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(fh!=INVALID_HANDLE)
     {
      FileWrite(fh, "=== ICT Structure OTE EA - Backtest ===");
      FileWrite(fh, "Symbole="+_Symbol+" TF="+EnumToString((ENUM_TIMEFRAMES)Period()));
      FileWrite(fh, "Depot_initial="+DoubleToString(init,2));
      FileWrite(fh, "Profit_net="+DoubleToString(prof,2));
      FileWrite(fh, "Profit_pct="+DoubleToString(pctp,2));
      FileWrite(fh, "Trades="+DoubleToString(tr,0));
      FileWrite(fh, "Gagnants="+DoubleToString(wins,0));
      FileWrite(fh, "Perdants="+DoubleToString(loss,0));
      FileWrite(fh, "WinRate_pct="+DoubleToString(wr,2));
      FileWrite(fh, "ProfitFactor="+DoubleToString(pf,3));
      FileWrite(fh, "DD_max_pct="+DoubleToString(ddp,2));
      FileWrite(fh, "DD_max_cash="+DoubleToString(ddm,2));
      FileWrite(fh, "Esperance_par_trade="+DoubleToString(ep,2));
      FileClose(fh);
     }
   return 0.0;
  }
//+------------------------------------------------------------------+
