//+------------------------------------------------------------------+
//|                                    ICT_SilverBullet_Strategy.mq5  |
//|   Portage MT5 (tout a l'identique) de "ICT Silver Bullet Strategy"|
//|   NinjaTrader.                                                    |
//|                                                                   |
//|   Modele CONTINUATION :                                           |
//|    - Biais = stacking EMA10/20 (close>rapide>lente) sur H1,       |
//|      confirme M5 + M1 (alignement). Filtre tendance Daily.        |
//|      Haussier => Long ; Baissier => Short.                        |
//|    - Sweep = PURGE de la liquidite OPPOSEE :                      |
//|        LONG  : purge d'un ancien swing HIGH -> jambe (swing low   |
//|                d'origine -> nouveau haut) -> entree dans le       |
//|                DISCOUNT de la jambe.                              |
//|        SHORT : purge d'un ancien swing LOW  -> entree PREMIUM.    |
//|    - 3 modeles d'entree INDEPENDANTS (apres sweep + deplacement) :|
//|        1) FVG  ne dans la moitie discount/premium de la jambe     |
//|        2) OTE  62-79 % de la jambe                                |
//|        3) Retest EMA rapide (exec) dans le sens                   |
//|      + cassure de structure (MSS) optionnelle.                    |
//|    - SL STRUCTUREL au-dela de l'extreme du sweep + buffer.        |
//|    - TP1 = 2R (sortie partielle) + BE a 2R ; runner = 4R ou       |
//|      trailing (extreme - TrailR*R).                               |
//|    - Risque 1 %/trade, dynamique (0,5 % apres 1 perte, 0,25 %     |
//|      jusqu'au prochain gain) ; max 3 positions.                   |
//|    - Verrou souple DD 5 %/jour (plus d'entrees le reste du jour). |
//|    - Killzones NY (03-04/10-11/14-15 + macros) DST auto.          |
//|                                                                   |
//|   Exec sur le TF du graphe (M1 conseille). Compte HEDGING pour la |
//|   vraie simultaneite des setups (core/runner emules en 1 position |
//|   + cloture partielle a TP1). Forward-test en SIM d'abord.        |
//+------------------------------------------------------------------+
#property copyright "ICT Silver Bullet - portage MT5"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//====================== ENUMS ======================
enum SbTradeDir { SB_BOTH=0, SB_LONGONLY=1, SB_SHORTONLY=2 };

//====================== INPUTS ======================
input group "== 1. Biais & Alignement =="
input ENUM_TIMEFRAMES InpHtfTF        = PERIOD_H1;   // TF Biais HTF
input ENUM_TIMEFRAMES InpConf1TF      = PERIOD_M5;   // TF Confirmation 1
input ENUM_TIMEFRAMES InpConf2TF      = PERIOD_M1;   // TF Confirmation 2
input int             InpEmaFast      = 10;          // EMA rapide
input int             InpEmaSlow      = 20;          // EMA lente
input bool            InpRequireAlign = true;        // Exiger l'alignement des TF
input SbTradeDir      InpTradeDir     = SB_BOTH;     // Sens des trades
input bool            InpUseTrendFilter = true;      // Filtre tendance
input ENUM_TIMEFRAMES InpTrendTF      = PERIOD_D1;   // TF du filtre tendance

input group "== 2. Modeles d'entree =="
input bool   InpUseOTE       = false;   // Entree OTE (62-79 %)
input bool   InpUseFVG       = true;    // Entree FVG (post-sweep, discount/premium)
input bool   InpUseEmaRetest = true;    // Entree retest EMA
input double InpOteLow       = 0.62;    // OTE bas (62 %)
input double InpOteHigh      = 0.79;    // OTE haut (79 %)
input double InpOteSweet     = 0.705;   // OTE sweet spot (70,5 %)
input int    InpMinDispTicks = 20;      // Deplacement min (ticks)
input int    InpMinFvgTicks  = 1;       // Taille min FVG (ticks)
input int    InpSetupExpiry  = 30;      // Expiration du setup (barres)
input bool   InpRequireMSS   = true;    // Exiger une cassure de structure (MSS)
input int    InpMssLookback  = 15;      // MSS : fenetre de validite (barres)

input group "== 3. Stop / Take profit =="
input int    InpSlBufferTicks = 4;      // Buffer SL structurel (ticks)
input double InpTp1R          = 2.0;    // TP1 + BE (R)
input double InpFinalR        = 4.0;    // TP final runner (R)
input double InpTp1Percent    = 50;     // Part sortie TP1 (%)
input bool   InpTrailRunner   = true;   // Trailing du runner
input double InpTrailR        = 2.0;    // Distance de trailing (R)

input group "== 4. Risque & Money =="
input bool   InpUseAccountEquity = true;   // Utiliser l'equity du compte
input double InpAccountSize      = 100000; // Taille de compte (si equity OFF)
input double InpRiskPct          = 1.0;    // Risque / trade (%)
input double InpRiskAfterLossPct = 0.5;    // Risque apres 1 perte (%)
input double InpRiskUntilWinPct  = 0.25;   // Risque jusqu'au prochain gain (%)
input int    InpMaxPositions     = 3;      // Max positions
input double InpDailyDDPct       = 5.0;    // DD max / jour (%)
input double InpMinLots          = 0.0;    // Lots minimum (0 = min du symbole)

input group "== 5. Filtre horaire (killzones NY) =="
input bool   InpUseSbWindows   = false;    // Restreindre aux fenetres Silver Bullet
input bool   InpAutoDST        = true;     // Heure NY DST auto (EDT/EST)
input int    InpManualGMTOffset = -4;      // Decalage GMT NY manuel (si DST auto OFF)

input group "== 6. Divers =="
input long   InpMagic     = 260711;   // Magic number
input int    InpSlippage  = 20;       // Deviation max (points)
input bool   InpVerbose   = false;    // Journal detaille

//====================== SETUP STRUCT ======================
struct Setup
{
   int      id;
   int      dir;             // 1 long, -1 short
   double   sweepPx;         // niveau de liquidite purge
   double   sweepExtreme;    // origine de la jambe -> base du SL structurel
   double   legLo, legHi;    // jambe de deplacement
   int      sweepBar;        // barre du sweep (compteur interne)
   bool     armed;           // deplacement confirme
   bool     hasFvg;
   double   fvgTop, fvgBot;
   bool     entered;
   double   entryPx, sl, tp1, tp4, R;
   ulong    posId;           // identifiant de position
   double   totalLots, coreLots;
   bool     coreTaken;       // sortie partielle TP1 faite
   bool     beDone;
   double   hiSinceEntry, loSinceEntry, runStop;
   bool     done;
   string   trigger;
};
Setup g_setups[];

//====================== GLOBALS ======================
int hExecF=INVALID_HANDLE, hExecS=INVALID_HANDLE;   // exec (chart TF)
int hHtfF =INVALID_HANDLE, hHtfS =INVALID_HANDLE;   // HTF
int hC1F  =INVALID_HANDLE, hC1S  =INVALID_HANDLE;   // conf1
int hC2F  =INVALID_HANDLE, hC2S  =INVALID_HANDLE;   // conf2
int hTrF  =INVALID_HANDLE, hTrS  =INVALID_HANDLE;   // tendance

int      g_biasHtf=0, g_biasC1=0, g_biasC2=0, g_trendBias=0;

double   g_lastSwingHi=0, g_lastSwingLo=0;
bool     g_haveHi=false, g_haveLo=false;
int      g_mssBias=0, g_mssBar=-1000000;

int      g_riskLevel=0;             // 0=1%, 1=0,5%, 2=0,25%
datetime g_curNyDay=0;
double   g_dayRealized=0;
bool     g_dayLocked=false;

int      g_seq=0;
int      g_barIndex=0;              // compteur de barres exec (= CurrentBar)
datetime g_lastBar=0;

//+------------------------------------------------------------------+
int OnInit()
{
   hExecF = iMA(_Symbol, PERIOD_CURRENT, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hExecS = iMA(_Symbol, PERIOD_CURRENT, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hHtfF  = iMA(_Symbol, InpHtfTF,   InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hHtfS  = iMA(_Symbol, InpHtfTF,   InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hC1F   = iMA(_Symbol, InpConf1TF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hC1S   = iMA(_Symbol, InpConf1TF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hC2F   = iMA(_Symbol, InpConf2TF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hC2S   = iMA(_Symbol, InpConf2TF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hTrF   = iMA(_Symbol, InpTrendTF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hTrS   = iMA(_Symbol, InpTrendTF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);

   if(hExecF==INVALID_HANDLE || hExecS==INVALID_HANDLE ||
      hHtfF==INVALID_HANDLE  || hHtfS==INVALID_HANDLE  ||
      hC1F==INVALID_HANDLE   || hC1S==INVALID_HANDLE   ||
      hC2F==INVALID_HANDLE   || hC2S==INVALID_HANDLE   ||
      hTrF==INVALID_HANDLE   || hTrS==INVALID_HANDLE)
   {
      Print("ICT SB : erreur creation des handles EMA");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   Print("ICT_SilverBullet_Strategy initialise sur ", _Symbol,
         "  (exec ", EnumToString((ENUM_TIMEFRAMES)_Period), ")");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hExecF); IndicatorRelease(hExecS);
   IndicatorRelease(hHtfF);  IndicatorRelease(hHtfS);
   IndicatorRelease(hC1F);   IndicatorRelease(hC1S);
   IndicatorRelease(hC2F);   IndicatorRelease(hC2S);
   IndicatorRelease(hTrF);   IndicatorRelease(hTrS);
}

//=================== helpers heure NY / DST ===================
bool IsUSDST(datetime g)
{
   MqlDateTime t; TimeToStruct(g, t);
   int month=t.mon, day=t.day;
   if(month<3 || month>11) return false;
   if(month>3 && month<11) return true;
   MqlDateTime m; m.year=t.year; m.mon=month; m.day=1; m.hour=0; m.min=0; m.sec=0;
   datetime first=StructToTime(m);
   MqlDateTime fw; TimeToStruct(first, fw);
   int dow1=fw.day_of_week;                       // 0=dimanche
   int firstSunday = (dow1==0) ? 1 : (8-dow1);
   if(month==3)  { int secondSunday=firstSunday+7; return (day>=secondSunday); }
   if(month==11) { return (day<firstSunday); }
   return false;
}
datetime NYNow()
{
   datetime g=TimeGMT();
   int off = InpAutoDST ? (IsUSDST(g) ? -4 : -5) : InpManualGMTOffset;
   return g + off*3600;
}
bool InSbWindow(datetime ny)
{
   MqlDateTime st; TimeToStruct(ny, st);
   double t = st.hour + st.min/60.0;
   if(t>=3  && t<4)    return true;
   if(t>=10 && t<11)   return true;
   if(t>=14 && t<15)   return true;
   if(t>=3.75  && t<4.25)  return true;   // macros seconde chance
   if(t>=10.75 && t<11.25) return true;
   if(t>=14.75 && t<15.25) return true;
   return false;
}

//=================== helpers marche ===================
double Tick()       { double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); return (ts>0?ts:_Point); }
double Equity()     { return InpUseAccountEquity ? AccountInfoDouble(ACCOUNT_EQUITY) : InpAccountSize; }
double EffRiskPct()
{
   if(g_riskLevel<=0) return InpRiskPct;
   if(g_riskLevel==1) return InpRiskAfterLossPct;
   return InpRiskUntilWinPct;
}
double MinLot()
{
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   return (InpMinLots>0 ? MathMax(InpMinLots, vmin) : vmin);
}
double NormLots(double lots)
{
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double vstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(vstep<=0) vstep=vmin;
   lots = MathFloor(lots/vstep)*vstep;
   if(lots<vmin) lots=vmin;
   if(lots>vmax) lots=vmax;
   return lots;
}

// bias persistant : close>rapide>lente = +1 ; close<rapide<lente = -1 ; sinon garde prev
int StackBias(int hF, int hS, ENUM_TIMEFRAMES tf, int prev)
{
   double f[1], s[1];
   if(CopyBuffer(hF,0,1,1,f)<1) return prev;
   if(CopyBuffer(hS,0,1,1,s)<1) return prev;
   double c = iClose(_Symbol, tf, 1);
   if(c>0 && c>f[0] && f[0]>s[0]) return 1;
   if(c>0 && c<f[0] && f[0]<s[0]) return -1;
   return prev;
}
double ExecEmaFast()   // EMA rapide exec sur la barre fermee (index 1)
{
   double v[1];
   if(CopyBuffer(hExecF,0,1,1,v)<1) return 0.0;
   return v[0];
}

//=================== comptage setups ===================
int OpenTradeCount()
{
   int n=0;
   for(int i=0;i<ArraySize(g_setups);i++)
      if(g_setups[i].entered && !g_setups[i].done && PositionSelectByTicket(g_setups[i].posId)) n++;
   return n;
}
int PendingCount()
{
   int n=0;
   for(int i=0;i<ArraySize(g_setups);i++)
      if(!g_setups[i].entered && !g_setups[i].done) n++;
   return n;
}
bool AlreadySwept(double lvl, int dir)
{
   double tk=Tick();
   for(int i=0;i<ArraySize(g_setups);i++)
      if(g_setups[i].dir==dir && MathAbs(g_setups[i].sweepPx-lvl)<=tk) return true;
   return false;
}
void RemoveSetup(int idx)
{
   int n=ArraySize(g_setups);
   for(int i=idx;i<n-1;i++) g_setups[i]=g_setups[i+1];
   ArrayResize(g_setups, n-1);
}

//=================== fermeture d'un setup -> risque dynamique + DD ===================
void FinalizeSetup(int idx)
{
   Setup s=g_setups[idx];
   double pnl=0;
   if(HistorySelectByPosition(s.posId))
   {
      int dn=HistoryDealsTotal();
      for(int i=0;i<dn;i++)
      {
         ulong d=HistoryDealGetTicket(i);
         if(d==0) continue;
         if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN) continue;   // ignorer l'entree
         pnl += HistoryDealGetDouble(d,DEAL_PROFIT)
              + HistoryDealGetDouble(d,DEAL_SWAP)
              + HistoryDealGetDouble(d,DEAL_COMMISSION);
      }
   }
   // classement gain/perte -> palier de risque
   if(pnl>0) g_riskLevel=0;
   else      g_riskLevel=MathMin(2, g_riskLevel+1);

   g_dayRealized += pnl;
   double limit=Equity()*InpDailyDDPct/100.0;
   if(-g_dayRealized >= limit) g_dayLocked=true;

   if(InpVerbose)
      PrintFormat("ICT SB : setup #%d cloture pnl=%.2f  riskLevel=%d  dayRealized=%.2f%s",
                  s.id, pnl, g_riskLevel, g_dayRealized, g_dayLocked?"  [JOUR VERROUILLE]":"");
}

//=================== ouverture (sizing core/runner emule) ===================
bool EnterSetup(int idx, double entry, string trig)
{
   double tk=Tick();
   Setup s=g_setups[idx];

   double sl = s.dir>0 ? s.sweepExtreme - InpSlBufferTicks*tk
                       : s.sweepExtreme + InpSlBufferTicks*tk;
   double r  = MathAbs(entry - sl);
   if(r < tk) return false;

   // sizing par risque
   double tickVal  = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize = Tick();
   if(tickVal<=0 || tickSize<=0) return false;
   double lossPerLot = (r/tickSize)*tickVal;
   if(lossPerLot<=0) return false;
   double riskCash = Equity()*EffRiskPct()/100.0;
   double total = NormLots(riskCash/lossPerLot);
   double minlot = MinLot();
   if(total<minlot) total=minlot;
   if(total<=0) return false;

   // split core / runner (core = sortie partielle a TP1)
   double coreLots=0;
   if(total>minlot+1e-9)
   {
      coreLots = NormLots(total*InpTp1Percent/100.0);
      if(coreLots<minlot) coreLots=minlot;
      if(coreLots>total-minlot) coreLots=total-minlot;
      if(coreLots<minlot) coreLots=0;   // pas de partielle possible -> tout runner
   }

   double tp1 = s.dir>0 ? entry + InpTp1R  * r : entry - InpTp1R  * r;
   double tp4 = s.dir>0 ? entry + InpFinalR* r : entry - InpFinalR* r;

   // ouverture au marche, SL structurel + TP final (runner). Core sorti a TP1 par cloture partielle.
   double slN =NormalizeDouble(sl, _Digits);
   double tp4N=NormalizeDouble(tp4,_Digits);
   bool ok=false;
   string cmt="SB"+IntegerToString(s.id);
   if(s.dir>0) ok=trade.Buy (total,_Symbol,0.0,slN,tp4N,cmt);
   else        ok=trade.Sell(total,_Symbol,0.0,slN,tp4N,cmt);
   if(!ok)
   {
      if(InpVerbose) PrintFormat("ICT SB : echec ouverture setup #%d ret=%d", s.id, trade.ResultRetcode());
      return false;
   }

   ulong posId=0;
   ulong deal=trade.ResultDeal();
   if(deal>0 && HistoryDealSelect(deal))
      posId=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   if(posId==0) posId=trade.ResultOrder();   // repli

   s.entryPx=entry; s.sl=sl; s.tp1=tp1; s.tp4=tp4; s.R=r; s.trigger=trig;
   s.hiSinceEntry=entry; s.loSinceEntry=entry; s.runStop=sl;
   s.posId=posId; s.totalLots=total; s.coreLots=coreLots;
   s.coreTaken=(coreLots<minlot); s.beDone=false; s.entered=true;
   g_setups[idx]=s;

   if(InpVerbose)
      PrintFormat("ICT SB : %s #%d %s  entry=%.5f SL=%.5f R=%.5f tp1=%.5f tp4=%.5f lots=%.2f core=%.2f",
                  s.dir>0?"LONG":"SHORT", s.id, trig, entry, sl, r, tp1, tp4, total, coreLots);
   return true;
}

//=================== creation d'un setup ===================
void CreateSetup(int dir, double sweepPx, double extreme, double legLo, double legHi)
{
   int n=ArraySize(g_setups);
   ArrayResize(g_setups, n+1);
   Setup s;
   s.id=++g_seq; s.dir=dir; s.sweepPx=sweepPx; s.sweepExtreme=extreme;
   s.legLo=legLo; s.legHi=legHi; s.sweepBar=g_barIndex;
   s.armed=false; s.hasFvg=false; s.fvgTop=0; s.fvgBot=0;
   s.entered=false; s.entryPx=0; s.sl=0; s.tp1=0; s.tp4=0; s.R=0;
   s.posId=0; s.totalLots=0; s.coreLots=0; s.coreTaken=false; s.beDone=false;
   s.hiSinceEntry=0; s.loSinceEntry=0; s.runStop=0; s.done=false; s.trigger="";
   g_setups[n]=s;
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   // logique une fois par barre fermee (= NinjaTrader Calculate.OnBarClose)
   datetime cur=iTime(_Symbol,PERIOD_CURRENT,0);
   if(cur==g_lastBar) return;
   g_lastBar=cur;
   g_barIndex++;

   if(Bars(_Symbol,PERIOD_CURRENT) < InpEmaSlow+8) return;

   double tk=Tick();

   // indices barres fermees (NT [k] -> MT5 [k+1])
   double h1=iHigh(_Symbol,_Period,1),  l1=iLow(_Symbol,_Period,1),  c1=iClose(_Symbol,_Period,1),  o1=iOpen(_Symbol,_Period,1);
   double h2=iHigh(_Symbol,_Period,2),  l2=iLow(_Symbol,_Period,2);
   double h3=iHigh(_Symbol,_Period,3);
   double h4=iHigh(_Symbol,_Period,4),  l4=iLow(_Symbol,_Period,4);
   double h5=iHigh(_Symbol,_Period,5);
   double h6=iHigh(_Symbol,_Period,6);
   double l3=iLow(_Symbol,_Period,3),   l5=iLow(_Symbol,_Period,5), l6=iLow(_Symbol,_Period,6);

   // --- reset journalier (DD) sur la date NY ---
   datetime ny=NYNow();
   MqlDateTime nyst; TimeToStruct(ny,nyst);
   MqlDateTime dd; dd=nyst; dd.hour=0; dd.min=0; dd.sec=0;
   datetime nyDay=StructToTime(dd);
   if(nyDay!=g_curNyDay) { g_curNyDay=nyDay; g_dayRealized=0; g_dayLocked=false; }

   // --- biais persistant par TF ---
   g_biasHtf   = StackBias(hHtfF, hHtfS, InpHtfTF,   g_biasHtf);
   g_biasC1    = StackBias(hC1F,  hC1S,  InpConf1TF, g_biasC1);
   g_biasC2    = StackBias(hC2F,  hC2S,  InpConf2TF, g_biasC2);
   g_trendBias = StackBias(hTrF,  hTrS,  InpTrendTF, g_trendBias);

   // direction alignee
   int alignedDir=g_biasHtf;
   if(InpRequireAlign)
   {
      if(g_biasHtf!=0 && g_biasC1==g_biasHtf && g_biasC2==g_biasHtf) alignedDir=g_biasHtf;
      else alignedDir=0;
   }
   // filtre tendance : n'autorise que le sens de la tendance de fond
   if(InpUseTrendFilter && (g_trendBias==0 || alignedDir!=g_trendBias)) alignedDir=0;

   // --- structure : swings fractals sur [3] (=index 4) + cassure (MSS) ---
   if(h4>h2 && h4>h3 && h4>h5 && h4>h6) { g_lastSwingHi=h4; g_haveHi=true; }
   if(l4<l2 && l4<l3 && l4<l5 && l4<l6) { g_lastSwingLo=l4; g_haveLo=true; }
   if(g_haveHi && c1>g_lastSwingHi) { g_mssBias=1;  g_mssBar=g_barIndex; }
   if(g_haveLo && c1<g_lastSwingLo) { g_mssBias=-1; g_mssBar=g_barIndex; }

   // --- FVG (gap de meches [1][2][3] NT = index 2/4 MT5) ---
   bool bullFvg = (l2>h4) && ((l2-h4) >= InpMinFvgTicks*tk);
   bool bearFvg = (h2<l4) && ((l4-h2) >= InpMinFvgTicks*tk);
   double fvgTop=0, fvgBot=0;
   if(bullFvg) { fvgTop=l2; fvgBot=h4; }
   if(bearFvg) { fvgTop=h2; fvgBot=l4; }

   double execEmaF = ExecEmaFast();

   // ============ gestion des setups existants ============
   for(int i=ArraySize(g_setups)-1; i>=0; i--)
   {
      // securite : setup deja marque done
      if(g_setups[i].done) { RemoveSetup(i); continue; }

      if(!g_setups[i].entered)
      {
         // maj de la jambe
         if(g_setups[i].dir>0) g_setups[i].legHi=MathMax(g_setups[i].legHi, h1);
         else                  g_setups[i].legLo=MathMin(g_setups[i].legLo, l1);

         // FVG dans le sens de la jambe : garder le plus PROFOND
         if(g_setups[i].dir>0 && bullFvg && (!g_setups[i].hasFvg || fvgTop<g_setups[i].fvgTop))
            { g_setups[i].hasFvg=true; g_setups[i].fvgTop=fvgTop; g_setups[i].fvgBot=fvgBot; }
         if(g_setups[i].dir<0 && bearFvg && (!g_setups[i].hasFvg || fvgBot>g_setups[i].fvgBot))
            { g_setups[i].hasFvg=true; g_setups[i].fvgTop=fvgTop; g_setups[i].fvgBot=fvgBot; }

         // deplacement confirme
         if(!g_setups[i].armed)
         {
            double disp = g_setups[i].dir>0 ? (g_setups[i].legHi-g_setups[i].sweepExtreme)
                                            : (g_setups[i].sweepExtreme-g_setups[i].legLo);
            if(g_setups[i].hasFvg || disp >= InpMinDispTicks*tk) g_setups[i].armed=true;
         }

         // invalidation : cloture au-dela de l'extreme, biais perdu, expiration
         bool invalid = (g_setups[i].dir>0 && c1<g_setups[i].sweepExtreme) ||
                        (g_setups[i].dir<0 && c1>g_setups[i].sweepExtreme);
         if(invalid || alignedDir!=g_setups[i].dir || (g_barIndex-g_setups[i].sweepBar)>InpSetupExpiry)
            { RemoveSetup(i); continue; }

         // ---- declencheurs d'entree (1er modele actif) ----
         if(g_setups[i].armed && !g_dayLocked && OpenTradeCount()<InpMaxPositions)
         {
            bool mssOk = !InpRequireMSS || (g_mssBias==g_setups[i].dir && (g_barIndex-g_mssBar)<=InpMssLookback);
            if((!InpUseSbWindows || InSbWindow(ny)) && mssOk)
            {
               double entry=EMPTY_VALUE; string trig="";
               double legLo=g_setups[i].legLo, legHi=g_setups[i].legHi;
               double mid = legLo + 0.5*(legHi-legLo);

               // 1) FVG (dans la moitie discount/premium)
               if(InpUseFVG && g_setups[i].hasFvg)
               {
                  if(g_setups[i].dir>0 && g_setups[i].fvgTop<=mid && l1<=g_setups[i].fvgTop && h1>=g_setups[i].fvgBot)
                     { entry=MathMin(o1, g_setups[i].fvgTop); trig="FVG"; }
                  if(g_setups[i].dir<0 && g_setups[i].fvgBot>=mid && h1>=g_setups[i].fvgBot && l1<=g_setups[i].fvgTop)
                     { entry=MathMax(o1, g_setups[i].fvgBot); trig="FVG"; }
               }
               // 2) OTE 62-79 %
               if(entry==EMPTY_VALUE && InpUseOTE)
               {
                  double rng=legHi-legLo;
                  if(rng>0)
                  {
                     if(g_setups[i].dir>0)
                     {
                        double zHi=legHi-InpOteLow*rng;       // 62 %
                        double sweet=legHi-InpOteSweet*rng;
                        if(l1<=zHi) { entry=MathMin(o1, sweet>zHi?zHi:sweet); trig="OTE"; }
                     }
                     else
                     {
                        double zLo=legLo+InpOteLow*rng;
                        double sweet=legLo+InpOteSweet*rng;
                        if(h1>=zLo) { entry=MathMax(o1, sweet<zLo?zLo:sweet); trig="OTE"; }
                     }
                  }
               }
               // 3) Retest EMA rapide (exec)
               if(entry==EMPTY_VALUE && InpUseEmaRetest && execEmaF>0)
               {
                  if(g_setups[i].dir>0 && l1<=execEmaF && c1>=o1) { entry=c1; trig="RetestEMA"; }
                  if(g_setups[i].dir<0 && h1>=execEmaF && c1<=o1) { entry=c1; trig="RetestEMA"; }
               }

               if(entry!=EMPTY_VALUE && trig!="")
                  EnterSetup(i, entry, trig);
            }
         }
      }
      else
      {
         // ---- gestion de la position (core/runner emules) ----
         if(!PositionSelectByTicket(g_setups[i].posId))
         {
            // position totalement fermee -> classement risque + DD
            FinalizeSetup(i);
            RemoveSetup(i);
            continue;
         }

         // suivi des extremes
         g_setups[i].hiSinceEntry=MathMax(g_setups[i].hiSinceEntry, h1);
         g_setups[i].loSinceEntry=MathMin(g_setups[i].loSinceEntry, l1);

         // sortie partielle TP1 (core) + passage BE quand le prix atteint 2R
         if(!g_setups[i].coreTaken)
         {
            bool reached = g_setups[i].dir>0 ? h1>=g_setups[i].tp1 : l1<=g_setups[i].tp1;
            if(reached)
            {
               if(g_setups[i].coreLots>=MinLot()-1e-9 && g_setups[i].coreLots>0)
                  trade.PositionClosePartial(g_setups[i].posId, g_setups[i].coreLots);
               g_setups[i].coreTaken=true;
               // BE : remonter le SL a l'entree
               double be=NormalizeDouble(g_setups[i].entryPx,_Digits);
               double curTP = InpTrailRunner ? 0.0 : NormalizeDouble(g_setups[i].tp4,_Digits);
               if(PositionSelectByTicket(g_setups[i].posId))
                  trade.PositionModify(g_setups[i].posId, be, curTP);
               g_setups[i].runStop=g_setups[i].entryPx;
               g_setups[i].beDone=true;
            }
         }
         else if(InpTrailRunner && g_setups[i].beDone)
         {
            // trailing du runner apres BE : SL suit l'extreme a TrailR*R
            double trail = g_setups[i].dir>0 ? g_setups[i].hiSinceEntry-InpTrailR*g_setups[i].R
                                             : g_setups[i].loSinceEntry+InpTrailR*g_setups[i].R;
            if(g_setups[i].dir>0 && trail>g_setups[i].runStop)
            {
               if(PositionSelectByTicket(g_setups[i].posId))
                  trade.PositionModify(g_setups[i].posId, NormalizeDouble(trail,_Digits), 0.0);
               g_setups[i].runStop=trail;
            }
            if(g_setups[i].dir<0 && trail<g_setups[i].runStop)
            {
               if(PositionSelectByTicket(g_setups[i].posId))
                  trade.PositionModify(g_setups[i].posId, NormalizeDouble(trail,_Digits), 0.0);
               g_setups[i].runStop=trail;
            }
         }
      }
   }

   // ============ nouveau sweep -> nouveau setup ============
   bool allowLong  = (InpTradeDir!=SB_SHORTONLY);
   bool allowShort = (InpTradeDir!=SB_LONGONLY);
   if(alignedDir!=0 && !g_dayLocked &&
      PendingCount()<InpMaxPositions &&
      (OpenTradeCount()+PendingCount())<InpMaxPositions+1)
   {
      if(alignedDir>0 && allowLong && g_haveHi && g_haveLo)
      {
         // LONG continuation : PURGE d'un ancien swing HIGH -> jambe (swing low d'origine -> nouveau haut)
         if(h1>g_lastSwingHi && !AlreadySwept(g_lastSwingHi,1))
            CreateSetup(1, g_lastSwingHi, g_lastSwingLo, g_lastSwingLo, h1);
      }
      else if(alignedDir<0 && allowShort && g_haveLo && g_haveHi)
      {
         // SHORT continuation : PURGE d'un ancien swing LOW -> entree PREMIUM
         if(l1<g_lastSwingLo && !AlreadySwept(g_lastSwingLo,-1))
            CreateSetup(-1, g_lastSwingLo, g_lastSwingHi, l1, g_lastSwingHi);
      }
   }
}

//+------------------------------------------------------------------+
//| OnTester : ecrit les stats de CHAQUE passe (optimisation) dans   |
//| un fichier UNIQUE par config (Common\Files) => parallel-safe.    |
//+------------------------------------------------------------------+
double OnTester()
{
   double profit = TesterStatistics(STAT_PROFIT);
   double pf     = TesterStatistics(STAT_PROFIT_FACTOR);
   double ddpct  = TesterStatistics(STAT_EQUITYDD_PERCENT);
   double trades = TesterStatistics(STAT_TRADES);
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   double payoff = TesterStatistics(STAT_EXPECTED_PAYOFF);
   string fn = StringFormat("SBopt_%s_O%dF%dE%dM%dT%dW%d_t%.0f_f%.0f_r%.0f_s%d_d%d_p%.0f.csv", _Symbol,
                  (int)InpUseOTE,(int)InpUseFVG,(int)InpUseEmaRetest,
                  (int)InpRequireMSS,(int)InpUseTrendFilter,(int)InpUseSbWindows,
                  InpTp1R*10,InpFinalR*10,InpTrailR*10,InpSlBufferTicks,InpMinDispTicks,InpTp1Percent);
   int h=FileOpen(fn, FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
   if(h!=INVALID_HANDLE)
   {
      FileWrite(h,_Symbol,(int)InpUseOTE,(int)InpUseFVG,(int)InpUseEmaRetest,
                (int)InpRequireMSS,(int)InpUseTrendFilter,(int)InpUseSbWindows,
                DoubleToString(InpTp1R,1),DoubleToString(InpFinalR,1),DoubleToString(InpTrailR,1),
                InpSlBufferTicks,InpMinDispTicks,DoubleToString(InpTp1Percent,0),
                DoubleToString(profit,2),DoubleToString(pf,3),DoubleToString(ddpct,2),
                (int)trades,DoubleToString(sharpe,3),DoubleToString(payoff,4));
      FileClose(h);
   }
   return(profit);
}
//+------------------------------------------------------------------+
