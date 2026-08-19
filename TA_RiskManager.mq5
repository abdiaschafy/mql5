//+------------------------------------------------------------------+
//| TA_RiskManager.mq5                                               |
//| Portage MT5 du RISK MANAGER V7 du Trade Assistant NinjaTrader.   |
//| Couche "compte" intelligente au-dessus du trade manager :        |
//|  - risque par GRADE de setup (A+ 1% / Std 0.5% / CT 0.25% / Man) |
//|  - paliers d'equite : DD >= 3% -> risque x0.5 ; >= 6% -> x0.25   |
//|  - limites FTMO-like : perte jour 5% (alerte 4%), DD max 10%     |
//|    -> CLOSE ALL une fois + VERROU SOUPLE (re-clic pour confirmer)|
//|  - pause apres N pertes consecutives (defaut 3)                  |
//|  - objectif jour atteint -> demi-risque ; cap d'exposition       |
//|  - sizing au risque (lot auto) + lot fixe ; boutons BUY/SELL     |
//|  - JOURNAL CSV de TOUS les trades fermes du compte (meme ceux    |
//|    du Trade Assistant Kravchenko) + dashboard HTML (bouton DASH) |
//| Jour de trading = bascule 18:00 New York (DST auto).             |
//| Etats persistes par compte via variables globales du terminal.   |
//+------------------------------------------------------------------+
#property copyright "ICT_ASIAN_BOT_V1"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

#import "shell32.dll"
int ShellExecuteW(int hwnd, string op, string file, string params, string dir, int show);
#import

//=================== INPUTS ===================
input group    "Risque par grade (% equite)"
input double   InpRiskAplus     = 1.0;    // Grade A+ (%)
input double   InpRiskStd       = 0.5;    // Grade standard (%)
input double   InpRiskCt        = 0.25;   // Grade contre-tendance (%)
input double   InpRiskMan       = 0.5;    // Grade Man : % par defaut (editable au panneau)

input group    "Limites de compte (FTMO-like)"
input double   InpDailyLossPct  = 5.0;    // Limite perte JOUR (%)
input double   InpDailyAlertPct = 4.0;    // Alerte perte jour (%)
input double   InpMaxDdPct      = 10.0;   // Drawdown MAX compte (%)
input int      InpStreakPause   = 3;      // Pause apres N pertes consecutives

input group    "Paliers d'equite (risque adaptatif)"
input double   InpDd1Pct        = 3.0;    // Palier 1 : DD (%)
input double   InpDd1Factor     = 0.5;    // Palier 1 : facteur risque
input double   InpDd2Pct        = 6.0;    // Palier 2 : DD (%)
input double   InpDd2Factor     = 0.25;   // Palier 2 : facteur risque

input group    "Confort"
input double   InpMaxExpoPct    = 2.0;    // Cap exposition globale (%) - 0 = off
input double   InpDailyTarget   = 2.0;    // Objectif jour (%) -> demi-risque - 0 = off
input int      InpConfirmSec    = 6;      // Verrou souple : delai de re-clic (s)

input group    "Ordres"
input int      InpAtrPeriod     = 14;     // SL AUTO : periode ATR
input double   InpAtrCoef       = 2.0;    // SL AUTO : coefficient ATR
input int      InpSlPoints      = 200;    // SL de secours si ATR indisponible (points)
input double   InpRR            = 2.0;    // TP auto = RR x SL (si TP pts = 0)
input long     InpMagic         = 260710; // Magic number

input group    "Trailing stop (positions du magic)"
input int      InpTrailStartPts = 0;      // Armement : profit en points (0 = distance)
input int      InpTrailDistPts  = 0;      // Distance en points (0 = AUTO ATR)

input group    "Break-even (si le Trail est OFF)"
input double   InpBeRR          = 2.0;    // BE quand le profit atteint N x R (0 = off)
input int      InpBeOffsetPts   = 10;     // Offset du BE au-dela de l'entree (points)

input group    "TP partiels : RR par niveau (0 = repartition uniforme)"
input double   InpTp1RR         = 2.0;    // TP1 : RR
input double   InpTp2RR         = 4.0;    // TP2 : RR
input double   InpTp3RR         = 6.0;    // TP3 : RR
input double   InpTp4RR         = 8.0;    // TP4 : RR
input double   InpTp5RR         = 10.0;   // TP5 : RR

//=================== ETAT ===================
#define PFX "TARM_"
CTrade  trade;

int     gmtOff = 0;
int     gradeSel = 3;                 // 0=A+ 1=Std 2=CT 3=Man
double  rmFactor = 1.0;
double  dayPnlPct = 0, ddPct = 0;
int     lossStreak = 0;
bool    dayFlatDone = false, ddFlatDone = false, dayAlertDone = false, targetDone = false;
datetime lockConfirmAt = 0, expoConfirmAt = 0;
bool    collapsed = false;
string  gvBase = "";

// panneau DEPLACABLE : origine + etat du drag (persiste par compte)
int     panX = 8, panY = 4;
bool    panDrag = false, prevLmb = false;
int     dragOffX = 0, dragOffY = 0;
int     hAtr = INVALID_HANDLE;        // SL auto par ATR (volatilite du symbole)
bool    trailOn = false;              // trailing stop (toggle du panneau, persiste)

// suivi des ordres en attente du magic : draguer UNE ligne d'entree deplace
// TOUT le groupe (les parts empilees au meme prix) - SL/TP suivent du meme
// delta (distances conservees), rien n'est cree ni laisse derriere.
ulong   pdId[50];
double  pdEn[50], pdSl[50], pdTp[50];
int     pdN = 0;

// suivi des POSITIONS du magic : consolidation au scaling-in (prix moyen,
// SL unique, TP re-ancres), sync du SL de groupe, break-even.
bool    beOn = false;                 // BE (toggle du panneau, persiste)
ulong   psId[50];
double  psRR[50];                     // RR du TP a la creation (re-ancrage)
double  psR0[50];                     // distance SL a la creation (reference du BE)
double  psSl[50];                     // dernier SL connu (detection du drag)
int     psDir[50];
int     psN = 0;

// suivi du risque des positions ouvertes (pour le R du journal)
ulong   trkId[200];
double  trkRisk[200];                 // risque $ (depuis le SL) au moment du suivi
double  trkVol[200];
double  trkPct[200];                  // % de risque effectif au moment de l'entree
int     trkN = 0;

//=================== HELPERS TEMPS (NY + DST) ===================
datetime DstStartGmt(int y)
{
   datetime d = StringToTime(StringFormat("%d.03.01 00:00", y));
   MqlDateTime s; TimeToStruct(d, s);
   int firstSun = ((7 - s.day_of_week) % 7) + 1;
   return d + (firstSun + 7 - 1) * 86400 + 7 * 3600;
}
datetime DstEndGmt(int y)
{
   datetime d = StringToTime(StringFormat("%d.11.01 00:00", y));
   MqlDateTime s; TimeToStruct(d, s);
   int firstSun = ((7 - s.day_of_week) % 7) + 1;
   return d + (firstSun - 1) * 86400 + 6 * 3600;
}
int NyOffsetSec(datetime gmt)
{
   MqlDateTime s; TimeToStruct(gmt, s);
   bool dst = (gmt >= DstStartGmt(s.year) && gmt < DstEndGmt(s.year));
   return dst ? -4 * 3600 : -5 * 3600;
}
datetime BrokerToNy(datetime bt)
{
   datetime g = bt - gmtOff;
   return g + NyOffsetSec(g);
}
// jour de trading : la journee bascule a 18:00 NY (comme les prop-firms)
long TradingDayStamp()
{
   datetime ny = BrokerToNy(TimeCurrent()) + 6 * 3600;
   MqlDateTime s; TimeToStruct(ny, s);
   return (long)s.year * 10000 + s.mon * 100 + s.day;
}

//=================== PERSISTANCE (variables globales par compte) ===================
double GvGet(string k, double dflt)
{
   string n = gvBase + k;
   if(GlobalVariableCheck(n)) return GlobalVariableGet(n);
   return dflt;
}
void GvSet(string k, double v) { GlobalVariableSet(gvBase + k, v); }

//=================== SIZING ===================
double EffRiskPct()
{
   double baseP = InpRiskMan;
   if(gradeSel == 0)      baseP = InpRiskAplus;
   else if(gradeSel == 1) baseP = InpRiskStd;
   else if(gradeSel == 2) baseP = InpRiskCt;
   else
   {
      string t = ObjectGetString(0, PFX "edRisk", OBJPROP_TEXT);
      StringReplace(t, ",", ".");
      double v = StringToDouble(t);
      if(v > 0) baseP = v;
   }
   return baseP * rmFactor;
}
double ValuePerPointPerLot(string sym)
{
   double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(tv <= 0 || ts <= 0 || pt <= 0) return 0;
   return tv * (pt / ts);
}
double LotForRisk(double riskCash, double slPoints)
{
   double vpp = ValuePerPointPerLot(_Symbol);
   if(vpp <= 0 || slPoints <= 0) return 0;
   double perLot = slPoints * vpp;
   double lot = riskCash / perLot;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   lot = MathFloor(lot / step + 1e-9) * step;
   if(lot < mn) return 0;              // risque trop petit pour le lot minimum
   if(lot > mx) lot = mx;
   return NormalizeDouble(lot, 8);
}
double EdDouble(string name, double dflt)
{
   string t = ObjectGetString(0, PFX + name, OBJPROP_TEXT);
   StringReplace(t, ",", ".");
   double v = StringToDouble(t);
   return (t == "" ? dflt : v);
}

// SL AUTO : distance = ATR x coef, ADAPTEE au symbole (fini les points fixes
// absurdes : 200 pts = 2 $ sur BTC -> "invalid stops" + lot demesure).
// Toujours >= distance minimale du broker (stops level) + marge de spread.
double AutoSlPoints()
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pts = 0;
   if(hAtr != INVALID_HANDLE && pt > 0)
   {
      double a[1];
      if(CopyBuffer(hAtr, 0, 0, 1, a) == 1 && a[0] > 0)
         pts = a[0] / pt * InpAtrCoef;
   }
   if(pts <= 0) pts = InpSlPoints;
   long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long sprd  = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double mini = (double)(stops + sprd) * 1.5 + 1;
   if(pts < mini) pts = mini;
   return MathCeil(pts);
}
// SL effectif : champ SL pts > 0 = manuel, 0 = AUTO (ATR)
double EffSlPoints()
{
   double manual = EdDouble("edSL", 0);
   if(manual > 0)
   {
      long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(manual < (double)stops + 1) manual = (double)stops + 1;
      return manual;
   }
   return AutoSlPoints();
}

//=================== EXPOSITION / VERROUS ===================
// risque $ deja engage = somme sur les positions AVEC SL (toutes, tout symbole)
double OpenRiskCash()
{
   double tot = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      double op  = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);
      double vpp = ValuePerPointPerLot(sym);
      if(pt <= 0 || vpp <= 0) continue;
      tot += MathAbs(op - sl) / pt * vpp * vol;
   }
   return tot;
}
string LockReason()
{
   if(dayPnlPct <= -InpDailyLossPct) return "limite de perte du jour";
   if(ddPct >= InpMaxDdPct)          return "drawdown max du compte";
   if(lossStreak >= InpStreakPause)  return IntegerToString(lossStreak) + " pertes consecutives";
   return "";
}
bool ConfirmGate()
{
   string r = LockReason();
   if(r == "") return true;
   if(TimeCurrent() - lockConfirmAt <= InpConfirmSec) { lockConfirmAt = 0; return true; }
   lockConfirmAt = TimeCurrent();
   Alert("TA RM : VERROU (" + r + ") - re-clique sous " + IntegerToString(InpConfirmSec) + " s pour confirmer");
   return false;
}
bool ExposureGate(double newRiskCash)
{
   if(InpMaxExpoPct <= 0) return true;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0) return true;
   double tot = (OpenRiskCash() + newRiskCash) / eq * 100.0;
   if(tot <= InpMaxExpoPct) return true;
   if(TimeCurrent() - expoConfirmAt <= InpConfirmSec) { expoConfirmAt = 0; return true; }
   expoConfirmAt = TimeCurrent();
   Alert(StringFormat("TA RM : EXPO %.1f %% > cap %.1f %% - re-clique sous %d s pour forcer",
         tot, InpMaxExpoPct, InpConfirmSec));
   return false;
}

//=================== ORDRES ===================
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk != 0) trade.PositionClose(tk);
   }
}
//=================== PLAN DE SORTIES PARTIELLES ===================
// UNE SEULE position par entree (lot total, UN SEUL SL, TP = cible finale).
// Les TP intermediaires sont des FERMETURES PARTIELLES declenchees au prix :
// le trade reste UN trade (1 ticket, 1 SL, 1 ligne au journal, 1 seule perte
// pour la serie). Le plan est persiste par ticket (survit a un redemarrage).
string PlanKey(long id) { return "pc" + IntegerToString(id); }
int  PlanCount(long id) { return (int)GvGet(PlanKey(id) + "n", 0); }
double PlanPrice(long id, int i) { return GvGet(PlanKey(id) + "p" + IntegerToString(i), 0); }
double PlanVol(long id, int i)   { return GvGet(PlanKey(id) + "v" + IntegerToString(i), 0); }
void PlanSet(long id, int n, double &prices[], double &vols[])
{
   GvSet(PlanKey(id) + "n", n);
   for(int i = 0; i < n; i++)
   {
      GvSet(PlanKey(id) + "p" + IntegerToString(i), prices[i]);
      GvSet(PlanKey(id) + "v" + IntegerToString(i), vols[i]);
   }
}
void PlanDelete(long id)
{
   int n = PlanCount(id);
   for(int i = 0; i < n; i++)
   {
      GlobalVariableDel(gvBase + PlanKey(id) + "p" + IntegerToString(i));
      GlobalVariableDel(gvBase + PlanKey(id) + "v" + IntegerToString(i));
   }
   GlobalVariableDel(gvBase + PlanKey(id) + "n");
}
// retire le niveau i (les suivants remontent)
void PlanRemove(long id, int idx)
{
   int n = PlanCount(id);
   double p[5], v[5];
   int k = 0;
   for(int i = 0; i < n && k < 5; i++)
   {
      if(i == idx) continue;
      p[k] = PlanPrice(id, i); v[k] = PlanVol(id, i); k++;
   }
   PlanDelete(id);
   if(k > 0) PlanSet(id, k, p, v);
}

// Entree MARCHE ou EN ATTENTE (pending = true : prix du champ Entree, type
// limit/stop choisi AUTOMATIQUEMENT selon le cote du marche). UNE SEULE
// position : le lot total, un SL unique, la cible finale en TP ; les TP
// partiels 1..n-1 sont enregistres comme fermetures partielles.
void PlaceTrade(bool buy, bool pending)
{
   if(!ConfirmGate()) return;
   double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double entry = pending ? EdDouble("edEntry", 0) : (buy ? ask : bid);
   if(pending && entry <= 0) { Alert("TA RM : renseigne le prix d'Entree pour un ordre en attente"); return; }

   double slPts = EffSlPoints();
   double tpPts = EdDouble("edTP", 0);
   if(tpPts <= 0) tpPts = slPts * InpRR;

   double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   double lot  = EdDouble("edLot", 0);
   bool   man  = lot > 0;
   if(!man) lot = LotForRisk(eq * EffRiskPct() / 100.0, slPts);
   if(lot <= 0) { Alert("TA RM : lot = 0 (risque trop petit pour le lot minimum)"); return; }

   double vpp = ValuePerPointPerLot(_Symbol);
   if(!ExposureGate(slPts * vpp * lot)) return;

   double sl = NormalizeDouble(buy ? entry - slPts * pt : entry + slPts * pt, dg);

   // niveaux de TP : RR configurables (0 = repartition uniforme)
   int parts = (int)MathMax(1, MathMin(5, EdDouble("edTps", 1)));
   double rrLv[5];
   rrLv[0] = InpTp1RR; rrLv[1] = InpTp2RR; rrLv[2] = InpTp3RR; rrLv[3] = InpTp4RR; rrLv[4] = InpTp5RR;
   double lvlPx[5];
   for(int i = 0; i < parts; i++)
   {
      double tpp;
      if(parts == 1)       tpp = tpPts;
      else if(rrLv[i] > 0) tpp = slPts * rrLv[i];
      else                 tpp = tpPts * (double)(i + 1) / (double)parts;
      lvlPx[i] = NormalizeDouble(buy ? entry + tpp * pt : entry - tpp * pt, dg);
   }
   double finalTp = lvlPx[parts - 1];          // la cible la plus lointaine = TP de la position

   // volumes des sorties partielles (le reliquat court jusqu'au TP final)
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(step <= 0) step = 0.01;
   double chunk = MathFloor(lot / parts / step) * step;
   int nLv = 0;
   double plP[5], plV[5];
   if(parts > 1 && chunk >= mn && lot - chunk * (parts - 1) >= mn)
   {
      for(int i = 0; i < parts - 1; i++) { plP[nLv] = lvlPx[i]; plV[nLv] = NormalizeDouble(chunk, 8); nLv++; }
   }
   // (si le lot est trop petit pour etre decoupe : une seule sortie au TP final)

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(20);

   bool ok;
   if(!pending)
      ok = buy ? trade.Buy(lot, _Symbol, 0, sl, finalTp, "TA RM")
               : trade.Sell(lot, _Symbol, 0, sl, finalTp, "TA RM");
   else
   {
      ENUM_ORDER_TYPE typ = buy ? (entry < ask ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP)
                                : (entry > bid ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP);
      ok = trade.OrderOpen(_Symbol, typ, lot, 0, NormalizeDouble(entry, dg), sl, finalTp,
                           ORDER_TIME_GTC, 0, "TA RM");
   }
   if(!ok) { Alert("TA RM : ordre refuse - " + trade.ResultComment()); return; }

   // rattache le plan de sorties partielles au ticket (= identifiant de position
   // une fois l'ordre execute, y compris pour un ordre en attente)
   long pid = 0;
   if(!pending)
   {
      ulong dl = trade.ResultDeal();
      if(dl > 0 && HistoryDealSelect(dl)) pid = HistoryDealGetInteger(dl, DEAL_POSITION_ID);
      if(pid == 0) pid = (long)trade.ResultOrder();
   }
   else pid = (long)trade.ResultOrder();
   if(pid > 0 && nLv > 0) PlanSet(pid, nLv, plP, plV);

   Print("TA RM : ", pending ? "PENDING " : "", (buy ? "BUY " : "SELL "), DoubleToString(lot, 2),
         " lot (1 position), SL ", sl, ", TP final ", finalTp,
         nLv > 0 ? ", " + IntegerToString(nLv) + " sortie(s) partielle(s)" : "");
}
void EnterMarket(bool buy) { PlaceTrade(buy, false); }

//=================== SUIVI DU RISQUE PAR POSITION (pour le R du journal) ===================
void TrackOpenRisks()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      long id = (long)PositionGetInteger(POSITION_IDENTIFIER);
      double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      double op  = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);
      double vpp = ValuePerPointPerLot(sym);
      if(pt <= 0 || vpp <= 0) continue;
      double risk = MathAbs(op - sl) / pt * vpp * vol;
      int f = -1;
      for(int k = 0; k < trkN; k++) if(trkId[k] == (ulong)id) { f = k; break; }
      // le risque de reference est celui de l'ENTREE (il ne doit pas retrecir
      // apres une sortie partielle) -> enregistre une seule fois
      if(f < 0 && trkN < 200)
      {
         f = trkN++; trkId[f] = (ulong)id; trkPct[f] = EffRiskPct();
         trkRisk[f] = risk; trkVol[f] = vol;
      }
   }
}
bool TrackFind(ulong id, double &risk, double &vol, double &pct)
{
   for(int k = 0; k < trkN; k++)
      if(trkId[k] == id) { risk = trkRisk[k]; vol = trkVol[k]; pct = trkPct[k]; return true; }
   return false;
}

//=================== JOURNAL + DASHBOARD ===================
string GradeTxt()
{
   if(gradeSel == 0) return "A+";
   if(gradeSel == 1) return "Std";
   if(gradeSel == 2) return "CT";
   return "Man";
}
void AppendJournal(string line)
{
   int h = FileOpen("TA_Journal.csv", FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      h = FileOpen("TA_Journal.csv", FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(h == INVALID_HANDLE) { Print("TA RM : journal inaccessible ", GetLastError()); return; }
   }
   if(FileSize(h) == 0)
      FileWriteString(h, "Date;Heure;Instrument;Sens;Qty;Entree;Sortie;Resultat;Risque;R;Grade;RisquePct;Solde;JourPct;DDPct;Compte\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\n");
   FileClose(h);
   RegenView();
}
string ReadWholeFile(string name)
{
   int h = FileOpen(name, FILE_READ | FILE_BIN);
   if(h == INVALID_HANDLE) return "";
   int sz = (int)FileSize(h);
   uchar b[];
   ArrayResize(b, sz);
   FileReadArray(h, b, 0, sz);
   FileClose(h);
   return CharArrayToString(b, 0, sz, CP_UTF8);
}
void WriteWholeFile(string name, string content)
{
   int h = FileOpen(name, FILE_WRITE | FILE_BIN);
   if(h == INVALID_HANDLE) return;
   uchar b[];
   int n = StringToCharArray(content, b, 0, -1, CP_UTF8);
   if(n > 0) FileWriteArray(h, b, 0, n - 1);   // sans le 0 terminal
   FileClose(h);
}
// CSV -> payload JS -> TA_View.html (dashboard autonome, donnees inline)
void RegenView()
{
   string login = IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN));
   string pay = "window.ACCOUNTS=[\"" + login + "\"];window.TRADES=[";
   int h = FileOpen("TA_Journal.csv", FILE_READ | FILE_TXT | FILE_ANSI);
   bool first = true;
   if(h != INVALID_HANDLE)
   {
      FileReadString(h);   // entete
      while(!FileIsEnding(h))
      {
         string ln = FileReadString(h);
         string c[];
         int nc = StringSplit(ln, ';', c);
         if(nc < 15) continue;                       // ligne incomplete : ignoree
         string acc = nc >= 16 ? c[15] : "?";        // tolerance anciennes lignes 15 col
         if(!first) pay += ",";
         first = false;
         pay += "{d:\"" + c[0] + "\",t:\"" + c[1] + "\",sym:\"" + c[2] + "\",dir:\"" + c[3] +
                "\",qty:" + c[4] + ",en:" + c[5] + ",ex:" + c[6] + ",pnl:" + c[7] +
                ",risk:" + c[8] + ",r:" + c[9] + ",g:\"" + c[10] + "\",pct:" + c[11] +
                ",bal:" + c[12] + ",day:" + c[13] + ",dd:" + c[14] + ",acc:\"" + acc + "\"}";
      }
      FileClose(h);
   }
   pay += "];";
   string tpl = ReadWholeFile("TradeAssistant_Dashboard.html");
   if(tpl == "") { Print("TA RM : template TradeAssistant_Dashboard.html absent de MQL5\\Files"); return; }
   StringReplace(tpl, "<script src=\"TradeAssistant_Journal.js\"></script>", "<script>" + pay + "</script>");
   WriteWholeFile("TA_View.html", tpl);
}
void OpenDashboard()
{
   RegenView();
   string path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\TA_View.html";
   int r = ShellExecuteW(0, "open", path, "", "", 1);
   if(r <= 32) Alert("TA RM : ouvre manuellement " + path);
}

//=================== PANNEAU ===================
#define PX   8
#define PW   232
#define RH   18
color BgRow  = C'52,58,70';
color BgHdr  = C'34,38,48';
color FgTxt  = clrGainsboro;

void Cell(string name, int x, int y, int w, int h, string txt, color bg, color fg, int fs = 8)
{
   string rn = PFX "bg_" + name;
   if(ObjectFind(0, rn) < 0) ObjectCreate(0, rn, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, rn, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, rn, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, rn, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, rn, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, rn, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, rn, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, rn, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, rn, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, rn, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, rn, OBJPROP_HIDDEN, true);
   string ln = PFX "tx_" + name;
   if(ObjectFind(0, ln) < 0) ObjectCreate(0, ln, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ln, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, ln, OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, ln, OBJPROP_YDISTANCE, y + 3);
   ObjectSetString(0, ln, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, ln, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, ln, OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, ln, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, ln, OBJPROP_HIDDEN, true);
}
void Btn(string name, int x, int y, int w, int h, string txt, color bg, color fg)
{
   string n = PFX + name;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}
void Edit(string name, int x, int y, int w, int h, string txt)
{
   string n = PFX + name;
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_EDIT, 0, 0, 0);
      ObjectSetString(0, n, OBJPROP_TEXT, txt);   // valeur initiale seulement
   }
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, C'30,33,40');
   ObjectSetInteger(0, n, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, n, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}
// reduire = SUPPRIMER les lignes (seul le bandeau reste) ; agrandir = tout
// reconstruire - le masquage par OBJPROP_TIMEFRAMES cassait l'ordre de rendu
// (les fonds repassaient au-dessus des textes -> inscriptions invisibles).
string savLot = "0", savSl = "0", savTp = "0";
void CollapsePanel()
{
   savLot = ObjectGetString(0, PFX "edLot", OBJPROP_TEXT);
   savSl  = ObjectGetString(0, PFX "edSL",  OBJPROP_TEXT);
   savTp  = ObjectGetString(0, PFX "edTP",  OBJPROP_TEXT);
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string n = ObjectName(0, i, 0, -1);
      if(StringFind(n, PFX) != 0) continue;
      if(StringFind(n, "hdr") >= 0 || StringFind(n, "btnMin") >= 0 || StringFind(n, "btnX") >= 0) continue;
      ObjectDelete(0, n);
   }
   ChartRedraw();
}
void ExpandPanel()
{
   BuildPanel();
   ObjectSetString(0, PFX "edLot", OBJPROP_TEXT, savLot);
   ObjectSetString(0, PFX "edSL",  OBJPROP_TEXT, savSl);
   ObjectSetString(0, PFX "edTP",  OBJPROP_TEXT, savTp);
   SyncGradeField();
   RefreshPanel();
   ChartRedraw();
}
void BuildHeaderOnly()
{
   int x = panX, y = panY;
   Cell("hdr", x, y, PW, RH, "TA RISK MANAGER", BgHdr, clrWhite, 9);
   Btn("btnMin", x + PW - 36, y + 2, 16, 14, "-", C'228,228,228', C'50,50,50');
   Btn("btnX",   x + PW - 18, y + 2, 16, 14, "x", C'228,228,228', C'50,50,50');
}
void BuildPanel()
{
   BuildHeaderOnly();
   int x = panX, y = panY;
   y += RH + 2;
   Cell("acct", x, y, PW, RH, "...", BgRow, FgTxt); y += RH + 2;

   int bw = (PW - 6) / 4;
   Btn("gA", x,              y, bw, RH, "A+",  BgRow, FgTxt);
   Btn("gS", x + bw + 2,     y, bw, RH, "Std", BgRow, FgTxt);
   Btn("gC", x + 2*(bw + 2), y, bw, RH, "CT",  BgRow, FgTxt);
   Btn("gM", x + 3*(bw + 2), y, bw, RH, "Man", BgRow, FgTxt);
   y += RH + 2;

   Cell("lRisk", x, y, 74, RH, "Risque %", BgRow, FgTxt);
   Edit("edRisk", x + 76, y, 50, RH, DoubleToString(InpRiskMan, 2));
   Cell("lEff", x + 128, y, PW - 128, RH, "", BgRow, FgTxt);
   y += RH + 2;
   Cell("lLot", x, y, 74, RH, "Lot (0=auto)", BgRow, FgTxt);
   Edit("edLot", x + 76, y, 50, RH, "0");
   Cell("lLotV", x + 128, y, PW - 128, RH, "", BgRow, FgTxt);
   y += RH + 2;
   Cell("lSl", x, y, 40, RH, "SL pts", BgRow, FgTxt);
   Edit("edSL", x + 42, y, 60, RH, "0");           // 0 = SL AUTO (ATR)
   Cell("lTp", x + 106, y, 40, RH, "TP pts", BgRow, FgTxt);
   Edit("edTP", x + 148, y, 60, RH, "0");          // 0 = RR x SL
   y += RH + 2;

   // ordres en attente : prix d'entree -> B.LMT / S.LMT (limit ou stop AUTO
   // selon la position du prix par rapport au marche, comme le TA NinjaTrader)
   Cell("lEn", x, y, 46, RH, "Entree", BgRow, FgTxt);
   Edit("edEntry", x + 48, y, 82, RH, "0");
   Btn("bBLmt", x + 132, y, 48, RH, "B.LMT", C'25,90,55',  clrWhite);
   Btn("bSLmt", x + 182, y, PW - 182, RH, "S.LMT", C'115,40,40', clrWhite);
   y += RH + 2;
   // TP partiels (1-5) + trailing + break-even (BE actif seulement si Trail OFF)
   Cell("lTps", x, y, 46, RH, "TPs 1-5", BgRow, FgTxt);
   Edit("edTps", x + 48, y, 34, RH, "1");
   Btn("bTrail", x + 84, y, 72, RH, "TRAIL : OFF", BgRow, FgTxt);
   Btn("bBe",    x + 158, y, PW - 158, RH, "BE : OFF", BgRow, FgTxt);
   y += RH + 2;

   int hw = (PW - 2) / 2;
   Btn("bBuy",  x,          y, hw, RH + 2, "BUY",  C'30,120,70',  clrWhite);
   Btn("bSell", x + hw + 2, y, hw, RH + 2, "SELL", C'150,45,45',  clrWhite);
   y += RH + 4;
   Btn("bClose", x,          y, hw, RH, "CLOSE ALL", C'110,40,40', clrWhite);
   Btn("bDash",  x + hw + 2, y, hw, RH, "DASH",      BgRow,        FgTxt);
   y += RH + 2;

   Cell("rm",   x, y, PW, RH, "", BgRow, FgTxt); y += RH + 2;
   Cell("pos",  x, y, PW, RH, "", BgRow, FgTxt); y += RH + 2;   // position en cours
   Cell("sess", x, y, PW, RH, "", BgRow, FgTxt); y += RH + 2;
}

// grade -> le champ Risque % AFFICHE le prereglage ; editable seulement en Man
void SyncGradeField()
{
   string n = PFX "edRisk";
   if(gradeSel == 0)      ObjectSetString(0, n, OBJPROP_TEXT, DoubleToString(InpRiskAplus, 2));
   else if(gradeSel == 1) ObjectSetString(0, n, OBJPROP_TEXT, DoubleToString(InpRiskStd, 2));
   else if(gradeSel == 2) ObjectSetString(0, n, OBJPROP_TEXT, DoubleToString(InpRiskCt, 2));
   else                   ObjectSetString(0, n, OBJPROP_TEXT, DoubleToString(GvGet("manPct", InpRiskMan), 2));
   ObjectSetInteger(0, n, OBJPROP_READONLY, gradeSel != 3);
   ObjectSetInteger(0, n, OBJPROP_COLOR, gradeSel != 3 ? clrSilver : clrWhite);
}
void RefreshPanel()
{
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   ObjectSetString(0, PFX "tx_acct", OBJPROP_TEXT,
      StringFormat("%I64d  ·  bal %.0f $  ·  eq %.0f $", login, bal, eq));

   // surbrillance du grade actif
   color on = C'90,70,160', off = BgRow;
   ObjectSetInteger(0, PFX "gA", OBJPROP_BGCOLOR, gradeSel == 0 ? on : off);
   ObjectSetInteger(0, PFX "gS", OBJPROP_BGCOLOR, gradeSel == 1 ? on : off);
   ObjectSetInteger(0, PFX "gC", OBJPROP_BGCOLOR, gradeSel == 2 ? on : off);
   ObjectSetInteger(0, PFX "gM", OBJPROP_BGCOLOR, gradeSel == 3 ? on : off);

   double pct = EffRiskPct();
   ObjectSetString(0, PFX "tx_lEff", OBJPROP_TEXT,
      StringFormat("eff %.2f %%%s", pct, rmFactor < 1 ? StringFormat(" (x%.2f)", rmFactor) : ""));

   double slPts = EffSlPoints();
   double lotMan = EdDouble("edLot", 0);
   double lot = lotMan > 0 ? lotMan : LotForRisk(eq * pct / 100.0, slPts);
   double vpp = ValuePerPointPerLot(_Symbol);
   double riskCash = lot * slPts * vpp;
   ObjectSetString(0, PFX "tx_lLotV", OBJPROP_TEXT,
      StringFormat("%s%.2f · R %.0f $", lotMan > 0 ? "fixe " : "", lot, riskCash));
   // SL resolu affiche dans son libelle (auto = ATR du symbole)
   ObjectSetString(0, PFX "tx_lSl", OBJPROP_TEXT,
      EdDouble("edSL", 0) > 0 ? "SL pts" : StringFormat("SL~%d", (int)slPts));

   // etat des boutons trailing / break-even (idempotent)
   ObjectSetString(0, PFX "bTrail", OBJPROP_TEXT, trailOn ? "TRAIL : ON" : "TRAIL : OFF");
   ObjectSetInteger(0, PFX "bTrail", OBJPROP_BGCOLOR, trailOn ? C'90,70,160' : BgRow);
   ObjectSetString(0, PFX "bBe", OBJPROP_TEXT, beOn ? "BE : ON" : "BE : OFF");
   ObjectSetInteger(0, PFX "bBe", OBJPROP_BGCOLOR, beOn ? C'90,70,160' : BgRow);

   string reason = LockReason();
   ObjectSetString(0, PFX "tx_rm", OBJPROP_TEXT,
      StringFormat("Jour %+.1f %% · Serie %dP · DD %.1f %%%s%s",
         dayPnlPct, lossStreak, ddPct,
         rmFactor < 1 ? StringFormat(" · x%.2f", rmFactor) : "",
         reason != "" ? " · VERROU" : ""));
   ObjectSetInteger(0, PFX "tx_rm", OBJPROP_COLOR,
      reason != "" ? clrOrangeRed : (dayPnlPct <= -InpDailyAlertPct || rmFactor < 1 ? clrOrange : FgTxt));

   // position en cours sur CE symbole : lot, risque $ (depuis le SL), RR de la position
   double pVol = 0, pRisk = 0, pRR = 0, upnl = 0;
   bool hasPos = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      hasPos = true;
      double v  = PositionGetDouble(POSITION_VOLUME);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double ps = PositionGetDouble(POSITION_SL);
      double pp = PositionGetDouble(POSITION_TP);
      pVol += v;
      upnl += PositionGetDouble(POSITION_PROFIT);
      double vp2 = ValuePerPointPerLot(_Symbol);
      double pt2 = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ps > 0 && pt2 > 0 && vp2 > 0) pRisk += MathAbs(op - ps) / pt2 * vp2 * v;
      if(pRR == 0 && ps > 0 && pp > 0 && MathAbs(op - ps) > 0)
         pRR = MathAbs(pp - op) / MathAbs(op - ps);
   }
   string posTxt = !hasPos ? "Position : flat"
      : StringFormat("Pos %.2f lot · R %.0f $%s · %+.0f $",
         pVol, pRisk, pRR > 0 ? StringFormat(" · RR %.1f", pRR) : "", upnl);
   ObjectSetString(0, PFX "tx_pos", OBJPROP_TEXT, posTxt);
   ObjectSetInteger(0, PFX "tx_pos", OBJPROP_COLOR, !hasPos ? FgTxt : (upnl >= 0 ? clrMediumSeaGreen : clrTomato));

   int    dTrades = (int)GvGet("dayTrades", 0);
   int    dWins   = (int)GvGet("dayWins", 0);
   double dR      = GvGet("dayR", 0);
   double expo    = eq > 0 ? OpenRiskCash() / eq * 100.0 : 0;
   string sess = dTrades == 0 ? "Session : 0 trade"
      : StringFormat("Session : %d trd · %d %% · %+.1f R", dTrades, (int)MathRound(100.0 * dWins / dTrades), dR);
   if(expo > 0.005) sess += StringFormat(" · Expo %.1f %%", expo);
   ObjectSetString(0, PFX "tx_sess", OBJPROP_TEXT, sess);
   ChartRedraw();
}

//=================== MOTEUR RM ===================
void RunEngine()
{
   gmtOff = (int)(MathRound(((long)TimeTradeServer() - (long)TimeGMT()) / 1800.0) * 1800);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0) return;

   long ds = TradingDayStamp();
   double peak   = GvGet("peak", eq);
   double dayEq  = GvGet("dayEq", eq);
   long   gvDs   = (long)GvGet("dayStamp", 0);
   lossStreak    = (int)GvGet("streak", 0);

   // rollover 18:00 NY : reset des limites + stats du jour
   if(gvDs != ds)
   {
      GvSet("dayStamp", (double)ds);
      dayEq = eq; GvSet("dayEq", eq);
      lossStreak = 0; GvSet("streak", 0);
      GvSet("dayTrades", 0); GvSet("dayWins", 0); GvSet("dayR", 0);
      dayFlatDone = false; ddFlatDone = false; dayAlertDone = false; targetDone = false;
   }
   // garde anti-aberration (depot/retrait, autre echelle) : repartir de l'equite courante
   if(dayEq > 0 && (eq > dayEq * 3 || eq < dayEq * 0.3))
   {
      dayEq = eq; GvSet("dayEq", eq);
      peak = eq;  GvSet("peak", eq);
   }
   if(eq > peak) { peak = eq; GvSet("peak", eq); }

   dayPnlPct = dayEq > 0 ? (eq - dayEq) / dayEq * 100.0 : 0;
   ddPct     = peak  > 0 ? (peak - eq) / peak * 100.0   : 0;
   rmFactor  = ddPct >= InpDd2Pct ? InpDd2Factor : (ddPct >= InpDd1Pct ? InpDd1Factor : 1.0);
   if(InpDailyTarget > 0 && dayPnlPct >= InpDailyTarget)
   {
      rmFactor *= 0.5;
      if(!targetDone) { targetDone = true; Alert(StringFormat("TA RM : objectif jour %+.1f %% atteint - risque reduit de moitie", dayPnlPct)); }
   }
   if(!dayAlertDone && dayPnlPct <= -InpDailyAlertPct)
   {
      dayAlertDone = true;
      Alert(StringFormat("TA RM : ALERTE perte du jour %.1f %% (limite -%.1f %%)", dayPnlPct, InpDailyLossPct));
      PlaySound("alert.wav");
   }
   if(!dayFlatDone && dayPnlPct <= -InpDailyLossPct)
   {
      dayFlatDone = true;
      CloseAllPositions();
      Alert(StringFormat("TA RM : LIMITE JOUR %.1f %% - positions fermees, confirmation requise pour trader", dayPnlPct));
      PlaySound("stops.wav");
   }
   if(!ddFlatDone && ddPct >= InpMaxDdPct)
   {
      ddFlatDone = true;
      CloseAllPositions();
      Alert(StringFormat("TA RM : DRAWDOWN MAX %.1f %% - positions fermees, confirmation requise pour trader", ddPct));
      PlaySound("stops.wav");
   }
   SyncPendingDrag();
   ManagePartialCloses();
   ManageGroup();
   TrailPositions();
   UpdateLineLabels();
   TrackOpenRisks();
   if(!collapsed) RefreshPanel();
}

// ===== SORTIES PARTIELLES (TP intermediaires d'UNE position) =====
// Le prix atteint un niveau du plan -> on ferme la fraction prevue. La position
// reste UNE position (meme ticket, meme SL) : le trade n'est comptabilise
// qu'a sa fermeture complete.
void ManagePartialCloses()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      long id = (long)PositionGetInteger(POSITION_IDENTIFIER);
      int n = PlanCount(id);
      if(n <= 0) continue;

      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double cur   = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double mn    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      for(int k = 0; k < n; k++)
      {
         double lp = PlanPrice(id, k);
         bool reached = isBuy ? (cur >= lp) : (cur <= lp);
         if(!reached) continue;
         double v = PlanVol(id, k);
         if(v > vol - mn) v = vol;             // reliquat trop petit : on solde
         if(v < mn) { PlanRemove(id, k); break; }
         if(trade.PositionClosePartial(tk, v))
         {
            Print("TA RM : TP partiel atteint (", DoubleToString(lp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
                  ") - ", DoubleToString(v, 2), " lot ferme");
            PlanRemove(id, k);
         }
         break;                                // une sortie par passage
      }
   }
}

// ===== GESTION DU GROUPE DE POSITIONS (magic, ce symbole) =====
// 1) SCALING-IN : une nouvelle position qui s'ajoute a un groupe existant du
//    meme sens ne vit pas sa vie - le groupe est CONSOLIDE : prix moyen pondere,
//    SL UNIQUE (celui du groupe), TP re-ancres sur le prix moyen en conservant
//    le RR de chaque part (comportement du TA NinjaTrader V5).
// 2) SYNC SL : draguer le SL d'UNE position aligne tout le groupe du meme sens.
// 3) BREAK-EVEN (si Trail OFF) : profit >= InpBeRR x R initial -> SL a
//    l'entree +/- offset ; ne recule jamais.
void ManageGroup()
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(pt <= 0) return;

   // inventaire courant du groupe (magic + symbole)
   ulong  ids[50]; double ops[50], vols[50], sls[50], tps[50]; int dirs[50];
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0 && n < 50; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      ids[n] = tk;
      ops[n] = PositionGetDouble(POSITION_PRICE_OPEN);
      vols[n]= PositionGetDouble(POSITION_VOLUME);
      sls[n] = PositionGetDouble(POSITION_SL);
      tps[n] = PositionGetDouble(POSITION_TP);
      dirs[n]= (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      n++;
   }

   // 2) drag manuel du SL d'une position connue -> nouveau SL de groupe (par sens)
   double dragSl[2] = {0, 0};   // [0]=long [1]=short
   for(int i = 0; i < n; i++)
      for(int k = 0; k < psN; k++)
         if(psId[k] == ids[i] && sls[i] > 0 && psSl[k] > 0 && MathAbs(sls[i] - psSl[k]) > pt * 0.5)
            dragSl[dirs[i] > 0 ? 0 : 1] = sls[i];

   // 1) consolidation par sens si une position NOUVELLE rejoint un groupe connu
   for(int d = 0; d < 2; d++)
   {
      int sgn = (d == 0) ? 1 : -1;
      int cnt = 0, knowns = 0, news = 0;
      double sumPV = 0, sumV = 0, slRef = 0;
      for(int i = 0; i < n; i++)
      {
         if(dirs[i] != sgn) continue;
         cnt++;
         sumPV += ops[i] * vols[i]; sumV += vols[i];
         bool known = false;
         for(int k = 0; k < psN; k++) if(psId[k] == ids[i]) { known = true; break; }
         if(known) { knowns++; if(slRef == 0 && sls[i] > 0) slRef = sls[i]; }
         else news++;
      }
      if(dragSl[d] > 0) slRef = dragSl[d];   // le SL dragge fait foi
      bool consolidate = (news > 0 && knowns > 0 && sumV > 0 && slRef > 0);
      bool syncSl      = (dragSl[d] > 0 && cnt > 0);
      if(!consolidate && !syncSl) continue;

      double avg = sumV > 0 ? sumPV / sumV : 0;
      double R   = MathAbs(avg - slRef);
      for(int i = 0; i < n; i++)
      {
         if(dirs[i] != sgn) continue;
         double rr = 0;
         for(int k = 0; k < psN; k++) if(psId[k] == ids[i]) { rr = psRR[k]; break; }
         if(rr <= 0 && sls[i] > 0 && tps[i] > 0 && MathAbs(ops[i] - sls[i]) > 0)
            rr = MathAbs(tps[i] - ops[i]) / MathAbs(ops[i] - sls[i]);   // part nouvelle
         double nSl = NormalizeDouble(slRef, dg);
         double nTp = tps[i];
         if(consolidate && rr > 0 && R > 0)
            nTp = NormalizeDouble(sgn > 0 ? avg + rr * R : avg - rr * R, dg);
         if(MathAbs(nSl - sls[i]) > pt * 0.5 || MathAbs(nTp - tps[i]) > pt * 0.5)
            trade.PositionModify(ids[i], nSl, nTp);
      }
      if(consolidate) Print("TA RM : scaling-in consolide (moy ", DoubleToString(avg, dg), ", SL ", DoubleToString(slRef, dg), ")");
   }

   // 3) break-even (uniquement si le Trail est OFF)
   if(beOn && !trailOn && InpBeRR > 0)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      for(int i = 0; i < n; i++)
      {
         double r0 = 0;
         for(int k = 0; k < psN; k++) if(psId[k] == ids[i]) { r0 = psR0[k]; break; }
         if(r0 <= 0) continue;
         if(dirs[i] > 0)
         {
            double be = NormalizeDouble(ops[i] + InpBeOffsetPts * pt, dg);
            if(sls[i] < ops[i] - pt * 0.5 && bid - ops[i] >= InpBeRR * r0)
               trade.PositionModify(ids[i], be, tps[i]);
         }
         else
         {
            double be = NormalizeDouble(ops[i] - InpBeOffsetPts * pt, dg);
            if((sls[i] > ops[i] + pt * 0.5 || sls[i] <= 0) && ops[i] - ask >= InpBeRR * r0)
               trade.PositionModify(ids[i], be, tps[i]);
         }
      }
   }

   // 4) re-memorise (les nouvelles positions entrent avec leur RR et R0 d'origine)
   for(int i = 0; i < n; i++)
   {
      int f = -1;
      for(int k = 0; k < psN; k++) if(psId[k] == ids[i]) { f = k; break; }
      if(f < 0 && psN < 50)
      {
         f = psN++;
         psId[f] = ids[i];
         psRR[f] = (sls[i] > 0 && tps[i] > 0 && MathAbs(ops[i] - sls[i]) > 0)
                   ? MathAbs(tps[i] - ops[i]) / MathAbs(ops[i] - sls[i]) : 0;
         psR0[f] = sls[i] > 0 ? MathAbs(ops[i] - sls[i]) : 0;
         psDir[f] = dirs[i];
      }
      if(f >= 0) psSl[f] = PositionSelectByTicket(ids[i]) ? PositionGetDouble(POSITION_SL) : sls[i];
   }
   // purge des tickets disparus
   for(int k = psN - 1; k >= 0; k--)
   {
      bool alive = false;
      for(int i = 0; i < n; i++) if(ids[i] == psId[k]) { alive = true; break; }
      if(!alive)
      {
         psId[k] = psId[psN-1]; psRR[k] = psRR[psN-1]; psR0[k] = psR0[psN-1];
         psSl[k] = psSl[psN-1]; psDir[k] = psDir[psN-1];
         psN--;
      }
   }
}

// ===== DRAG DES ORDRES EN ATTENTE (magic) =====
// L'user drague la ligne d'entree d'un pending sur le chart : on detecte le
// changement de prix par rapport a la memoire et on REALIGNE tout le groupe
// du symbole sur le meme delta, SL/TP compris (les distances sont conservees).
bool IsOurPending(ulong tk)
{
   if(tk == 0) return false;
   if(OrderGetString(ORDER_SYMBOL) != _Symbol) return false;
   if(OrderGetInteger(ORDER_MAGIC) != InpMagic) return false;
   long typ = OrderGetInteger(ORDER_TYPE);
   return typ == ORDER_TYPE_BUY_LIMIT || typ == ORDER_TYPE_BUY_STOP
       || typ == ORDER_TYPE_SELL_LIMIT || typ == ORDER_TYPE_SELL_STOP;
}
void SyncPendingDrag()
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(pt <= 0) return;

   // 1) un ticket connu a-t-il ete deplace (drag manuel de la ligne) ?
   double delta = 0; bool moved = false;
   for(int i = OrdersTotal() - 1; i >= 0 && !moved; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(!IsOurPending(tk)) continue;
      for(int k = 0; k < pdN; k++)
         if(pdId[k] == tk)
         {
            double en = OrderGetDouble(ORDER_PRICE_OPEN);
            if(MathAbs(en - pdEn[k]) > pt * 0.5) { moved = true; delta = en - pdEn[k]; }
            break;
         }
   }
   // 2) realigne TOUT le groupe du meme delta (entree + SL + TP)
   if(moved)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong tk = OrderGetTicket(i);
         if(!IsOurPending(tk)) continue;
         int f = -1;
         for(int k = 0; k < pdN; k++) if(pdId[k] == tk) { f = k; break; }
         if(f < 0) continue;
         double nEn = NormalizeDouble(pdEn[f] + delta, dg);
         double nSl = pdSl[f] > 0 ? NormalizeDouble(pdSl[f] + delta, dg) : 0;
         double nTp = pdTp[f] > 0 ? NormalizeDouble(pdTp[f] + delta, dg) : 0;
         trade.OrderModify(tk, nEn, nSl, nTp, ORDER_TIME_GTC, 0);
      }
      Print("TA RM : entree du groupe pending ajustee de ", DoubleToString(delta / pt, 0), " points");
   }
   // 3) rememorise l'etat courant
   pdN = 0;
   for(int i = OrdersTotal() - 1; i >= 0 && pdN < 50; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(!IsOurPending(tk)) continue;
      pdId[pdN] = tk;
      pdEn[pdN] = OrderGetDouble(ORDER_PRICE_OPEN);
      pdSl[pdN] = OrderGetDouble(ORDER_SL);
      pdTp[pdN] = OrderGetDouble(ORDER_TP);
      pdN++;
   }
}

// ===== TRAILING STOP (positions du magic sur ce symbole) =====
// distance = points fixes ou AUTO (ATR x coef) ; arme quand le profit atteint
// le seuil (defaut = la distance) ; le SL ne recule JAMAIS.
void TrailPositions()
{
   if(!trailOn) return;
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(pt <= 0) return;
   double dist  = InpTrailDistPts > 0 ? InpTrailDistPts : AutoSlPoints();
   double start = InpTrailStartPts > 0 ? InpTrailStartPts : dist;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      long   typ = PositionGetInteger(POSITION_TYPE);
      double op  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl  = PositionGetDouble(POSITION_SL);
      double tp  = PositionGetDouble(POSITION_TP);
      if(typ == POSITION_TYPE_BUY)
      {
         if((bid - op) / pt < start) continue;
         double ns = NormalizeDouble(bid - dist * pt, dg);
         if(sl <= 0 || ns > sl + pt * 0.5)
            trade.PositionModify(tk, ns, tp);
      }
      else
      {
         if((op - ask) / pt < start) continue;
         double ns = NormalizeDouble(ask + dist * pt, dg);
         if(sl <= 0 || ns < sl - pt * 0.5)
            trade.PositionModify(tk, ns, tp);
      }
   }
}

// ===== ETIQUETTES SUR LES LIGNES (entree / SL / TP) =====
// A cote de chaque niveau : sens + quantite sur l'entree, RISQUE $ sur le SL,
// GAIN $ potentiel sur chaque TP. Positions ET ordres en attente du symbole.
void LineLabel(string id, double price, string txt, color cl)
{
   string n = PFX "lb_" + id;
   datetime t = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 3;
   if(ObjectFind(0, n) < 0)
   {
      ObjectCreate(0, n, OBJ_TEXT, 0, t, price);
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, n, OBJPROP_TIME, t);
   ObjectSetDouble(0, n, OBJPROP_PRICE, price);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, cl);
}
void UpdateLineLabels()
{
   double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double vpp = ValuePerPointPerLot(_Symbol);
   if(pt <= 0 || vpp <= 0) return;
   // purge : on marque les etiquettes existantes, on recree celles qui vivent
   int tot = ObjectsTotal(0, 0, OBJ_TEXT);
   for(int i = tot - 1; i >= 0; i--)
   {
      string n = ObjectName(0, i, 0, OBJ_TEXT);
      if(StringFind(n, PFX "lb_") == 0) ObjectDelete(0, n);
   }
   // positions du symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long   typ = PositionGetInteger(POSITION_TYPE);
      double op  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl  = PositionGetDouble(POSITION_SL);
      double tp  = PositionGetDouble(POSITION_TP);
      double vol = PositionGetDouble(POSITION_VOLUME);
      string sid = IntegerToString((long)tk);
      bool isBuy = (typ == POSITION_TYPE_BUY);
      LineLabel(sid + "e", op, (isBuy ? "BUY " : "SELL ") + DoubleToString(vol, 2), isBuy ? clrDodgerBlue : clrOrange);
      if(sl > 0) LineLabel(sid + "s", sl, "-" + DoubleToString(MathAbs(op - sl) / pt * vpp * vol, 0) + " $", clrTomato);
      if(tp > 0) LineLabel(sid + "t", tp, "+" + DoubleToString(MathAbs(tp - op) / pt * vpp * vol, 0) + " $", clrMediumSeaGreen);
      // niveaux de sortie PARTIELLE encore a venir (TP1..TPn-1)
      long pid = (long)PositionGetInteger(POSITION_IDENTIFIER);
      int np = PlanCount(pid);
      for(int k = 0; k < np; k++)
      {
         double lp = PlanPrice(pid, k), lv = PlanVol(pid, k);
         if(lp <= 0 || lv <= 0) continue;
         LineLabel(sid + "q" + IntegerToString(k), lp,
                   "TP" + IntegerToString(k + 1) + " " + DoubleToString(lv, 2) + " (+" +
                   DoubleToString(MathAbs(lp - op) / pt * vpp * lv, 0) + " $)", clrMediumSeaGreen);
      }
   }
   // ordres en attente du symbole
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      double op  = OrderGetDouble(ORDER_PRICE_OPEN);
      double sl  = OrderGetDouble(ORDER_SL);
      double tp  = OrderGetDouble(ORDER_TP);
      double vol = OrderGetDouble(ORDER_VOLUME_CURRENT);
      long   typ = OrderGetInteger(ORDER_TYPE);
      bool isBuy = (typ == ORDER_TYPE_BUY_LIMIT || typ == ORDER_TYPE_BUY_STOP);
      string sid = "o" + IntegerToString((long)tk);
      LineLabel(sid + "e", op, (isBuy ? "B.PEND " : "S.PEND ") + DoubleToString(vol, 2), clrGold);
      if(sl > 0) LineLabel(sid + "s", sl, "-" + DoubleToString(MathAbs(op - sl) / pt * vpp * vol, 0) + " $", clrTomato);
      if(tp > 0) LineLabel(sid + "t", tp, "+" + DoubleToString(MathAbs(tp - op) / pt * vpp * vol, 0) + " $", clrMediumSeaGreen);
   }
}

//=================== EVENEMENTS ===================
int OnInit()
{
   gvBase = "TARM_" + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) + "_";
   gradeSel = (int)GvGet("grade", 3);
   panX = (int)GvGet("panX", 8);
   panY = (int)GvGet("panY", 4);
   trailOn = GvGet("trail", 0) > 0.5;
   beOn    = GvGet("be", 0) > 0.5;
   trade.SetExpertMagicNumber(InpMagic);
   hAtr = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);   // SL auto par volatilite
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);   // drag du panneau par le bandeau
   BuildPanel();
   SyncGradeField();
   EventSetTimer(1);
   RunEngine();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, PFX);
   ChartRedraw();
}
void OnTimer() { RunEngine(); }
void OnTick() {}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // ----- drag du panneau par le bandeau-titre -----
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int  mx  = (int)lparam, my = (int)dparam;
      bool lmb = (((int)StringToInteger(sparam)) & 1) != 0;
      if(!panDrag && lmb && !prevLmb
         && mx >= panX && mx <= panX + PW - 40   // bandeau (hors boutons - / x)
         && my >= panY && my <= panY + RH)
      {
         panDrag = true;
         dragOffX = mx - panX; dragOffY = my - panY;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
      }
      else if(panDrag && lmb)
      {
         panX = MathMax(0, mx - dragOffX);
         panY = MathMax(0, my - dragOffY);
         if(collapsed) BuildHeaderOnly(); else BuildPanel();
         ChartRedraw();
      }
      else if(panDrag && !lmb)
      {
         panDrag = false;
         GvSet("panX", panX); GvSet("panY", panY);
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
      }
      prevLmb = lmb;
      return;
   }

   // ----- saisie manuelle du % (mode Man uniquement) -----
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == PFX "edRisk")
   {
      if(gradeSel == 3)
      {
         double v = EdDouble("edRisk", InpRiskMan);
         if(v > 0) GvSet("manPct", v);
      }
      RefreshPanel();
      return;
   }

   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(StringFind(sparam, PFX) != 0) return;
   string n = StringSubstr(sparam, StringLen(PFX));
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

   if(n == "btnX")   { ExpertRemove(); return; }
   if(n == "btnMin") { collapsed = !collapsed; if(collapsed) CollapsePanel(); else ExpandPanel(); return; }
   if(n == "gA") { gradeSel = 0; GvSet("grade", 0); SyncGradeField(); }
   if(n == "gS") { gradeSel = 1; GvSet("grade", 1); SyncGradeField(); }
   if(n == "gC") { gradeSel = 2; GvSet("grade", 2); SyncGradeField(); }
   if(n == "gM") { gradeSel = 3; GvSet("grade", 3); SyncGradeField(); }
   if(n == "bBuy")   PlaceTrade(true,  false);
   if(n == "bSell")  PlaceTrade(false, false);
   if(n == "bBLmt")  PlaceTrade(true,  true);
   if(n == "bSLmt")  PlaceTrade(false, true);
   if(n == "bTrail")
   {
      trailOn = !trailOn; GvSet("trail", trailOn ? 1 : 0);
      ObjectSetString(0, PFX "bTrail", OBJPROP_TEXT, trailOn ? "TRAIL : ON" : "TRAIL : OFF");
      ObjectSetInteger(0, PFX "bTrail", OBJPROP_BGCOLOR, trailOn ? C'90,70,160' : BgRow);
   }
   if(n == "bBe")
   {
      beOn = !beOn; GvSet("be", beOn ? 1 : 0);
      ObjectSetString(0, PFX "bBe", OBJPROP_TEXT, beOn ? "BE : ON" : "BE : OFF");
      ObjectSetInteger(0, PFX "bBe", OBJPROP_BGCOLOR, beOn ? C'90,70,160' : BgRow);
   }
   if(n == "bClose") { CloseAllPositions(); Print("TA RM : Close All"); }
   if(n == "bDash")  OpenDashboard();
   RefreshPanel();
}

// journal : chaque deal de SORTIE (toutes origines, tout symbole) est enregistre
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dt = trans.deal;
   if(dt == 0 || !HistoryDealSelect(dt)) return;
   long entry = HistoryDealGetInteger(dt, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;

   long  posId = HistoryDealGetInteger(dt, DEAL_POSITION_ID);
   // UN TRADE = UNE POSITION. Une sortie PARTIELLE (TP intermediaire) laisse la
   // position ouverte : on n'enregistre RIEN tant qu'elle vit. Le trade n'est
   // comptabilise (journal, serie de pertes, stats) qu'a sa cloture COMPLETE,
   // avec le resultat TOTAL de toutes ses sorties.
   if(PositionSelectByTicket((ulong)posId)) return;
   PlanDelete(posId);                       // plan de sorties partielles devenu inutile

   string sym  = HistoryDealGetString(dt, DEAL_SYMBOL);
   long   dTyp = HistoryDealGetInteger(dt, DEAL_TYPE);
   // le deal de sortie est du cote OPPOSE a la position
   string sens = (dTyp == DEAL_TYPE_SELL) ? "LONG" : "SHORT";

   // agrege TOUS les deals de la position : PnL total, volume d'entree,
   // prix d'entree et prix de sortie MOYENS (ponderes par le volume)
   double pnl = 0, enSum = 0, enV = 0, exSum = 0, exV = 0;
   if(HistorySelectByPosition(posId))
   {
      int nd = HistoryDealsTotal();
      for(int i = 0; i < nd; i++)
      {
         ulong  d2 = HistoryDealGetTicket(i);
         long   e2 = HistoryDealGetInteger(d2, DEAL_ENTRY);
         double v2 = HistoryDealGetDouble(d2, DEAL_VOLUME);
         double p2 = HistoryDealGetDouble(d2, DEAL_PRICE);
         pnl += HistoryDealGetDouble(d2, DEAL_PROFIT) + HistoryDealGetDouble(d2, DEAL_SWAP)
              + HistoryDealGetDouble(d2, DEAL_COMMISSION);
         if(e2 == DEAL_ENTRY_IN) { enSum += p2 * v2; enV += v2; }
         else                    { exSum += p2 * v2; exV += v2; }
      }
   }
   double vol  = enV > 0 ? enV : exV;
   double enPx = enV > 0 ? enSum / enV : 0;
   double exPx = exV > 0 ? exSum / exV : 0;
   // risque de reference = celui de l'ENTREE, sur la position ENTIERE
   // (le R realise compare le gain total au risque total initial)
   double risk = 0, tVol = 0, tPct = 0;
   TrackFind((ulong)posId, risk, tVol, tPct);
   double r = risk > 0.01 ? pnl / risk : 0;

   // serie de pertes + stats du jour
   if(pnl < -0.01) { lossStreak++; GvSet("streak", lossStreak); }
   else if(pnl > 0.01) { lossStreak = 0; GvSet("streak", 0); }
   GvSet("dayTrades", GvGet("dayTrades", 0) + 1);
   if(pnl > 0.01) GvSet("dayWins", GvGet("dayWins", 0) + 1);
   if(risk > 0.01) GvSet("dayR", GvGet("dayR", 0) + pnl / risk);
   if(lossStreak >= InpStreakPause)
      Alert("TA RM : PAUSE - " + IntegerToString(lossStreak) + " pertes consecutives, confirmation requise");

   MqlDateTime s; TimeToStruct(TimeCurrent(), s);
   // 14 champs texte apres la date/heure (le dernier = compte) - NE PAS en oublier :
   // un %s manquant fait sauter la colonne Compte (bug corrige ici).
   string line = StringFormat("%04d-%02d-%02d;%02d:%02d:%02d;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%s",
      s.year, s.mon, s.day, s.hour, s.min, s.sec,
      sym, sens,
      DoubleToString(vol, 2),
      DoubleToString(enPx, 5), DoubleToString(exPx, 5),
      DoubleToString(pnl, 2), DoubleToString(risk, 2), DoubleToString(r, 3),
      GradeTxt(), DoubleToString(tPct > 0 ? tPct : EffRiskPct(), 3),
      DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
      DoubleToString(dayPnlPct, 3), DoubleToString(ddPct, 3),
      IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)));
   AppendJournal(line);
}
//+------------------------------------------------------------------+
