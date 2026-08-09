//+------------------------------------------------------------------+
//| ICT_TopDown_Confluence.mq5                                        |
//| Port MQL5 COMPLET de l'indicateur ICT Top-Down Confluence v2.5   |
//| (TradingView Pine + NinjaTrader 8).                               |
//|                                                                   |
//| Modules :                                                         |
//|  - Biais HTF + 2 confirmations PERSISTANTS (EMA10/20 stacking,    |
//|    l'etat ne s'inverse qu'au stack oppose) + dashboard dynamique  |
//|  - Compte a rebours de cloture de barre (tous TF, D1 inclus)      |
//|  - Structure 2 echelles : BOS/CHoCH (interne) + MSS/BOS (swing)   |
//|  - Zone OTE par cassure : 0.666->0.79, sweet 0.705, repere 0.62,  |
//|    upgrade A+ si biais HTF aligne                                 |
//|  - Killzones Open/Close (5, heure NY, DST auto) + Asian Box       |
//|  - Macros ICT (bandes fines pleine hauteur — adaptation MT5)      |
//|  - NDOG (gap cloture veille -> ouverture jour, N jours, mediane)  |
//|  - Liquidites : BSL/SSL 2 echelles (majeurs pleins / internes     |
//|    tirets), EQH/EQL renforces, purge = trait fin gris au sweep    |
//|                                                                   |
//| Adaptations MT5 (pas de transparence sur les objets) :            |
//|  - fonds killzones/NDOG = couleurs PALES en arriere-plan          |
//|  - macros = fines bandes pleine hauteur tres pales                |
//+------------------------------------------------------------------+
#property copyright "ICT Trading Journal 2026"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_label1  "EMA10"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRoyalBlue
#property indicator_width1  2
#property indicator_label2  "EMA20"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  2

//=================== INPUTS ===================
input group "1. Biais & Confirmations"
input int             InpEmaFast   = 10;               // EMA rapide
input int             InpEmaSlow   = 20;               // EMA lente
input ENUM_TIMEFRAMES InpBiasTF    = PERIOD_D1;        // TF Biais (HTF)
input ENUM_TIMEFRAMES InpConf1TF   = PERIOD_H1;        // TF Confirmation 1
input ENUM_TIMEFRAMES InpConf2TF   = PERIOD_M15;       // TF Confirmation 2
input bool            InpShowEma   = true;             // Afficher EMA10/20 (TF du graphique)

input group "2. Zone OTE"
input bool   InpShowOTE      = true;    // Afficher OTE
input bool   InpShowOTELbl   = true;    // Afficher label OTE
input int    InpStructLen    = 5;       // Longueur structure interne
input bool   InpUseHTFGrade  = true;    // Upgrade A+ si biais HTF aligne
input double InpFib62        = 0.62;    // Fib repere
input double InpFib666       = 0.666;   // Fib haut zone
input double InpFibSweet     = 0.705;   // Sweet spot
input double InpFib79        = 0.79;    // Fib bas zone
input bool   InpShowTarget   = true;    // Afficher cible (extension)
input double InpFibTarget    = -0.5;    // Niveau cible
input int    InpOteFwdBars   = 20;      // Extension OTE (barres)
input color  InpCLong        = clrRoyalBlue;   // Couleur OTE long
input color  InpCShort       = clrRed;         // Couleur OTE short

input group "3. Structure MSS/CHoCH/BOS"
input bool  InpShowStruct = true;       // Afficher structure (lignes)
input bool  InpShowIntern = true;       // Cassures internes (BOS/CHoCH)
input int   InpSwingLen   = 20;         // Longueur swing (MSS)
input color InpCBos       = clrGray;    // Couleur BOS
input color InpCChoch     = clrOrange;  // Couleur CHoCH
input color InpCMss       = clrMagenta; // Couleur MSS

input group "4. Killzones (heure New York, DST auto)"
input int   InpKzDays      = 10;                  // Jours de killzones affiches
input bool  InpShowLonOpen  = true;               // London Open actif
input string InpSessLonOpen = "0200-0500";        // London Open fenetre
input color InpCKzLonOpen   = C'225,235,250';     // London Open couleur (pale)
input bool  InpShowLonClose = true;               // London Close actif
input string InpSessLonClose= "1000-1100";        // London Close fenetre
input color InpCKzLonClose  = C'220,242,240';     // London Close couleur (pale)
input bool  InpShowNyOpen   = true;               // NY Open actif
input string InpSessNyOpen  = "0700-0900";        // NY Open fenetre
input color InpCKzNyOpen    = C'228,246,228';     // NY Open couleur (pale)
input bool  InpShowNyClose  = true;               // NY Close actif
input string InpSessNyClose = "1000-1100";        // NY Close fenetre
input color InpCKzNyClose   = C'250,238,220';     // NY Close couleur (pale)
input bool  InpShowAsia     = false;              // Asie actif
input string InpSessAsia    = "1900-2200";        // Asie fenetre
input color InpCKzAsia      = C'235,235,235';     // Asie couleur (pale)
input bool  InpShowAsianBox = true;               // Asian Box actif
input string InpAsianBoxWin = "1800-2359";        // Asian Box fenetre
input color InpCAsianBox    = clrGold;            // Asian Box couleur (cadre)

input group "5. Macros ICT (segments fins en bas du graphe, comme NT)"
input int    InpMacroMaxMin = 15;                                                            // Macros visibles jusqu'au TF (minutes)
input bool   InpShowMacL  = true;                                                            // Macros Londres
input string InpMacWinL   = "0145-0215;0245-0315;0345-0415;0445-0515";                       // fenetres
input color  InpCMacLon   = clrRoyalBlue;                                                    // couleur segment
input bool   InpShowMacLN = true;                                                            // Macros Londres+NY
input string InpMacWinLN  = "0645-0715;0745-0815;0845-0915;0945-1015;1045-1115;1145-1215";   // fenetres
input color  InpCMacLNy   = clrTeal;                                                         // couleur segment
input bool   InpShowMacP  = true;                                                            // Macros NY PM
input string InpMacWinP   = "1245-1315;1345-1415;1445-1515;1545-1615";                       // fenetres
input color  InpCMacPm    = clrDarkOrange;                                                   // couleur segment
input bool   InpShowMacA  = true;                                                            // Macros Asian
input string InpMacWinA   = "1845-1915;1945-2015;2045-2115;2145-2215;2245-2315;2345-0015;0045-0115"; // fenetres
input color  InpCMacAs    = clrMagenta;                                                      // couleur segment

input group "6. Dashboard"
input bool InpShowDash      = true;     // Afficher dashboard
input bool InpShowCountdown = true;     // Compte a rebours barre

input group "7. NDOG"
input bool  InpShowNdog = true;         // NDOG actif
input bool  InpNdogAll  = false;        // Extension : false = Extend Gaps, true = Prix actuel
input int   InpMaxNdog  = 5;            // Max number (jours)
input color InpCNdog    = clrMediumPurple;   // Couleur (lignes/label)
input color InpCNdogBg  = C'240,232,250';    // Fond (pale)

input group "8. Liquidites"
input bool  InpShowLiqSw = true;        // BSL/SSL swings actifs
input bool  InpShowLiqEq = true;        // EQH/EQL actifs
input int   InpLiqEqTk   = 6;           // Tolerance EQ (ticks)
input int   InpMaxLiq    = 8;           // Pools max (par cote/echelle)
input color InpCBsl      = clrFireBrick;      // Couleur BSL
input color InpCSsl      = clrSeaGreen;       // Couleur SSL
input color InpCEqh      = clrCrimson;        // Couleur EQH
input color InpCEql      = clrMediumSeaGreen; // Couleur EQL
input color InpCSwept    = clrDarkGray;       // Couleur purge (trait fin)

//=================== GLOBALS ===================
#define PFX "ICTTD_"
double  BufE10[], BufE20[];
int     hEmaC10 = INVALID_HANDLE, hEmaC20 = INVALID_HANDLE;
int     hEmaB1 = INVALID_HANDLE, hEmaB2 = INVALID_HANDLE;
int     hEmaC11 = INVALID_HANDLE, hEmaC12 = INVALID_HANDLE;
int     hEmaC21 = INVALID_HANDLE, hEmaC22 = INVALID_HANDLE;
int     gmtOff = 0;                    // decalage broker -> GMT (secondes)
int     objId = 0;                     // compteur de noms d'objets

// structure interne
double  swHb, swHw, swLb, swLw;
datetime swHt = 0, swLt = 0;
bool    hBroken = true, lBroken = true;
int     trendSt = 0;
bool    pendBull = false, pendBear = false;
double  pendOrig = 0.0;
bool    pendOrigSet = false;
// structure swing
double  sgHw, sgLw;
datetime sgHt = 0, sgLt = 0;
bool    sgHBroken = true, sgLBroken = true;
int     sgTrend = 0;
// suivi jour (killzones/ndog)
long    lastKzDay = 0;
long    lastNdogDay = 0;
// macros = segments en bas du graphe (repositionnes selon l'echelle visible)
string  macNm[];
int     macLane[];
// dashboard reductible / fermable / DEPLACABLE (drag par le bandeau-titre)
bool    dashCollapsed = false;
int     dashX = 4, dashY = 30;         // position (distance au bord DROIT, haut)
bool    dashDrag = false, dashPrevLmb = false;
int     dashOffX = 0, dashOffY = 0;
// liquidites (pools)
double   lqPx[];
datetime lqT1[];
bool     lqHigh[], lqMaj[], lqEq[], lqAct[];
string   lqLn[], lqLb[];

//=================== HELPERS TEMPS (NY + DST) ===================
datetime DstStartGmt(int y)
{
   // 2e dimanche de mars, 07:00 GMT (= 02:00 EST)
   datetime d = StringToTime(StringFormat("%d.03.01 00:00", y));
   MqlDateTime s; TimeToStruct(d, s);
   int firstSun = ((7 - s.day_of_week) % 7) + 1;
   return d + (firstSun + 7 - 1) * 86400 + 7 * 3600;
}
datetime DstEndGmt(int y)
{
   // 1er dimanche de novembre, 06:00 GMT (= 02:00 EDT)
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
datetime NyToBroker(datetime nyWall)
{
   // approximation : la regle DST est evaluee sur l'heure NY elle-meme
   datetime g = nyWall - NyOffsetSec(nyWall);
   return g + gmtOff;
}
int MinOfDay(datetime t)
{
   MqlDateTime s; TimeToStruct(t, s);
   return s.hour * 60 + s.min;
}
long DayStamp(datetime t)
{
   MqlDateTime s; TimeToStruct(t, s);
   return (long)s.year * 10000 + s.mon * 100 + s.day;
}
bool ParseWin(const string win, int &sMin, int &eMin)
{
   string p[];
   if(StringSplit(win, '-', p) != 2) return false;
   if(StringLen(p[0]) < 4 || StringLen(p[1]) < 4) return false;
   sMin = (int)StringToInteger(StringSubstr(p[0], 0, 2)) * 60 + (int)StringToInteger(StringSubstr(p[0], 2, 2));
   eMin = (int)StringToInteger(StringSubstr(p[1], 0, 2)) * 60 + (int)StringToInteger(StringSubstr(p[1], 2, 2));
   return true;
}
string MoisEn(int m)
{
   static string n[12] = {"jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"};
   if(m < 1 || m > 12) return "";
   return n[m - 1];
}

//=================== HELPERS OBJETS ===================
void RectBg(string name, datetime t1, double p1, datetime t2, double p2, color c, bool fill, bool back, int width=1)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, back);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
void TrLine(string name, datetime t1, double p1, datetime t2, double p2, color c, ENUM_LINE_STYLE st, int w)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_STYLE, st);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, w);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
void Txt(string name, datetime t, double p, string s, color c, int fontSize, ENUM_ANCHOR_POINT anchor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p);
   ObjectSetString(0, name, OBJPROP_TEXT, s);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
// Cellule du dashboard, coin HAUT-DROIT. x = distance du bord droit au BORD DROIT
// de la cellule ; le RECTANGLE_LABEL en corner droit s'etend vers la DROITE depuis
// son ancre (= bord gauche) -> XDISTANCE du rectangle = x + w.
void DashCell(string name, int x, int y, int w, int h, string txt, color bg, color fg)
{
   string rn = PFX "dashbg_" + name;
   if(ObjectFind(0, rn) < 0)
      ObjectCreate(0, rn, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, rn, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, rn, OBJPROP_XDISTANCE, x + w);
   ObjectSetInteger(0, rn, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, rn, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, rn, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, rn, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, rn, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, rn, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, rn, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, rn, OBJPROP_HIDDEN, true);
   string ln = PFX "dashtx_" + name;
   if(ObjectFind(0, ln) < 0)
      ObjectCreate(0, ln, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ln, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, ln, OBJPROP_XDISTANCE, x + 6);   // texte aligne a droite dans la cellule
   ObjectSetInteger(0, ln, OBJPROP_YDISTANCE, y + 3);
   ObjectSetInteger(0, ln, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetString(0, ln, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, ln, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, ln, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, ln, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, ln, OBJPROP_HIDDEN, true);
}

//=================== BIAIS PERSISTANT ===================
// Etat = direction du DERNIER stack complet (close>E10>E20 / close<E10<E20)
// trouve en remontant le TF : persiste jusqu'au stack oppose (= apres croisement EMA).
int StackState(ENUM_TIMEFRAMES tf, int hFast, int hSlow)
{
   double f[], s[];
   int nb = MathMin(400, Bars(_Symbol, tf) - 1);
   if(nb < InpEmaSlow + 2) return 0;
   if(CopyBuffer(hFast, 0, 0, nb, f) < nb) return 0;
   if(CopyBuffer(hSlow, 0, 0, nb, s) < nb) return 0;
   ArraySetAsSeries(f, true);
   ArraySetAsSeries(s, true);
   for(int i = 0; i < nb; i++)
   {
      double c = iClose(_Symbol, tf, i);
      if(c > f[i] && f[i] > s[i]) return 1;
      if(c < f[i] && f[i] < s[i]) return -1;
   }
   return 0;
}

//=================== LIQUIDITES ===================
void LiqAdd(double px, datetime t1, bool isHigh, bool major)
{
   if(!InpShowLiqSw) return;
   double tol = InpLiqEqTk * _Point;
   int n = ArraySize(lqPx);
   for(int i = n - 1; i >= 0; i--)
   {
      if(!lqAct[i] || lqHigh[i] != isHigh) continue;
      if(MathAbs(lqPx[i] - px) <= tol)
      {
         if(lqT1[i] == t1) { lqMaj[i] = lqMaj[i] || major; return; }   // meme swing, 2 echelles
         if(InpShowLiqEq)
         {
            lqEq[i] = true;
            lqPx[i] = isHigh ? MathMax(lqPx[i], px) : MathMin(lqPx[i], px);
            color ce = isHigh ? InpCEqh : InpCEql;
            ObjectSetDouble(0, lqLn[i], OBJPROP_PRICE, 0, lqPx[i]);
            ObjectSetDouble(0, lqLn[i], OBJPROP_PRICE, 1, lqPx[i]);
            ObjectSetInteger(0, lqLn[i], OBJPROP_COLOR, ce);
            ObjectSetInteger(0, lqLn[i], OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lqLn[i], OBJPROP_WIDTH, 2);
            ObjectSetString(0, lqLb[i], OBJPROP_TEXT, (isHigh ? "EQH " : "EQL ") + DoubleToString(lqPx[i], _Digits));
            ObjectSetInteger(0, lqLb[i], OBJPROP_COLOR, ce);
            ObjectSetDouble(0, lqLb[i], OBJPROP_PRICE, 0, lqPx[i]);
         }
         return;
      }
   }
   // nouveau pool
   objId++;
   string ln = PFX "liq_" + (string)objId;
   string lb = PFX "liqt_" + (string)objId;
   color fam = isHigh ? InpCBsl : InpCSsl;
   TrLine(ln, t1, px, TimeCurrent(), px, fam, major ? STYLE_SOLID : STYLE_DASH, 1);
   // BSL au-dessus a gauche / SSL en-dessous a gauche, SANS prix
   Txt(lb, t1, px, isHigh ? "BSL" : "SSL", fam, 7, isHigh ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
   int n2 = ArraySize(lqPx);
   ArrayResize(lqPx, n2 + 1);   ArrayResize(lqT1, n2 + 1);
   ArrayResize(lqHigh, n2 + 1); ArrayResize(lqMaj, n2 + 1);
   ArrayResize(lqEq, n2 + 1);   ArrayResize(lqAct, n2 + 1);
   ArrayResize(lqLn, n2 + 1);   ArrayResize(lqLb, n2 + 1);
   lqPx[n2] = px; lqT1[n2] = t1; lqHigh[n2] = isHigh; lqMaj[n2] = major;
   lqEq[n2] = false; lqAct[n2] = true; lqLn[n2] = ln; lqLb[n2] = lb;
   // cap par (cote, echelle)
   int cnt = 0;
   for(int i = ArraySize(lqPx) - 1; i >= 0; i--)
   {
      if(lqHigh[i] == isHigh && lqMaj[i] == major)
      {
         cnt++;
         if(cnt > MathMax(2, InpMaxLiq)) LiqRemove(i);
      }
   }
}
void LiqRemove(int i)
{
   ObjectDelete(0, lqLn[i]);
   ObjectDelete(0, lqLb[i]);
   int n = ArraySize(lqPx);
   for(int k = i; k < n - 1; k++)
   {
      lqPx[k] = lqPx[k+1]; lqT1[k] = lqT1[k+1]; lqHigh[k] = lqHigh[k+1];
      lqMaj[k] = lqMaj[k+1]; lqEq[k] = lqEq[k+1]; lqAct[k] = lqAct[k+1];
      lqLn[k] = lqLn[k+1]; lqLb[k] = lqLb[k+1];
   }
   ArrayResize(lqPx, n - 1);   ArrayResize(lqT1, n - 1);
   ArrayResize(lqHigh, n - 1); ArrayResize(lqMaj, n - 1);
   ArrayResize(lqEq, n - 1);   ArrayResize(lqAct, n - 1);
   ArrayResize(lqLn, n - 1);   ArrayResize(lqLb, n - 1);
}
void LiqSweepAndExtend(double hi, double lo, datetime t)
{
   int n = ArraySize(lqPx);
   for(int i = 0; i < n; i++)
   {
      if(!lqAct[i]) continue;
      ObjectSetInteger(0, lqLn[i], OBJPROP_TIME, 1, t);
      bool swept = lqHigh[i] ? hi > lqPx[i] : lo < lqPx[i];
      if(swept)
      {
         // PURGE : trait FIN grise, stoppe a la bougie du sweep
         lqAct[i] = false;
         ObjectSetInteger(0, lqLn[i], OBJPROP_COLOR, InpCSwept);
         ObjectSetInteger(0, lqLn[i], OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lqLn[i], OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lqLb[i], OBJPROP_COLOR, InpCSwept);
      }
   }
}

//=================== KILLZONES / MACROS / ASIAN BOX (par jour NY) ===================
void DrawDayWindow(string tag, long dayNy, const string win, color c, bool fill)
{
   int sMin, eMin;
   if(!ParseWin(win, sMin, eMin)) return;
   int y = (int)(dayNy / 10000), mo = (int)((dayNy / 100) % 100), d = (int)(dayNy % 100);
   datetime nyBase = StringToTime(StringFormat("%04d.%02d.%02d 00:00", y, mo, d));
   datetime t1 = NyToBroker(nyBase + sMin * 60);
   datetime t2 = NyToBroker(nyBase + (eMin > sMin ? eMin : eMin + 1440) * 60);
   double top = iHigh(_Symbol, PERIOD_D1, 0) * 3.0;
   RectBg(PFX "kz_" + tag + "_" + (string)dayNy, t1, 0.0, t2, top, c, fill, true, 1);
}
// macros = SEGMENTS fins en bas du graphe (lanes 0/1/2 comme NT), repositionnes
// en Y a chaque tick de timer selon l'echelle visible (CHART_PRICE_MIN/MAX)
void DrawMacroSet(string tag, long dayNy, const string wins, color c, int lane)
{
   string parts[];
   int n = StringSplit(wins, ';', parts);
   int y = (int)(dayNy / 10000), mo = (int)((dayNy / 100) % 100), d = (int)(dayNy % 100);
   datetime nyBase = StringToTime(StringFormat("%04d.%02d.%02d 00:00", y, mo, d));
   for(int i = 0; i < n; i++)
   {
      int sMin, eMin;
      if(!ParseWin(parts[i], sMin, eMin)) continue;
      datetime t1 = NyToBroker(nyBase + sMin * 60);
      datetime t2 = NyToBroker(nyBase + (eMin > sMin ? eMin : eMin + 1440) * 60);
      string nm = PFX "mac_" + tag + "_" + (string)dayNy + "_" + (string)i;
      TrLine(nm, t1, 0.0, t2, 0.0, c, STYLE_SOLID, 3);
      int k = ArraySize(macNm);
      ArrayResize(macNm, k + 1);
      ArrayResize(macLane, k + 1);
      macNm[k] = nm;
      macLane[k] = lane;
   }
}
void RepositionMacros()
{
   int n = ArraySize(macNm);
   if(n == 0) return;
   double pMin = ChartGetDouble(0, CHART_PRICE_MIN);
   double pMax = ChartGetDouble(0, CHART_PRICE_MAX);
   if(pMax <= pMin) return;
   double rng = pMax - pMin;
   for(int i = 0; i < n; i++)
   {
      // lanes bien decollees du bord bas et espacees (visibilite)
      double yy = pMin + rng * (0.022 + 0.024 * macLane[i]);
      ObjectSetDouble(0, macNm[i], OBJPROP_PRICE, 0, yy);
      ObjectSetDouble(0, macNm[i], OBJPROP_PRICE, 1, yy);
   }
}
void DrawAsianBox(long dayNy)
{
   int sMin, eMin;
   if(!ParseWin(InpAsianBoxWin, sMin, eMin)) return;
   int y = (int)(dayNy / 10000), mo = (int)((dayNy / 100) % 100), d = (int)(dayNy % 100);
   datetime nyBase = StringToTime(StringFormat("%04d.%02d.%02d 00:00", y, mo, d));
   datetime t1 = NyToBroker(nyBase + sMin * 60);
   datetime t2 = NyToBroker(nyBase + eMin * 60);
   int i1 = iBarShift(_Symbol, PERIOD_CURRENT, t1);
   int i2 = iBarShift(_Symbol, PERIOD_CURRENT, t2);
   if(i1 < 0 || i2 < 0 || i1 <= i2) return;
   int cnt = i1 - i2 + 1;
   int hiIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, cnt, i2);
   int loIdx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, cnt, i2);
   if(hiIdx < 0 || loIdx < 0) return;
   double hi = iHigh(_Symbol, PERIOD_CURRENT, hiIdx);
   double lo = iLow(_Symbol, PERIOD_CURRENT, loIdx);
   // cadre net (pas de fond : lisibilite des bougies)
   RectBg(PFX "ab_" + (string)dayNy, t1, hi, t2, lo, InpCAsianBox, false, true, 2);
}

//=================== NDOG ===================
void DrawNdogs()
{
   if(!InpShowNdog || _Period >= PERIOD_D1) return;
   for(int d = 0; d < InpMaxNdog; d++)
   {
      double cPrev = iClose(_Symbol, PERIOD_D1, d + 1);
      double oNew  = iOpen(_Symbol, PERIOD_D1, d);
      datetime t1  = iTime(_Symbol, PERIOD_D1, d);
      if(cPrev <= 0 || oNew <= 0 || t1 == 0) continue;
      datetime t2  = (d == 0 || InpNdogAll) ? TimeCurrent() : iTime(_Symbol, PERIOD_D1, d - 1);
      double hi = MathMax(cPrev, oNew), lo = MathMin(cPrev, oNew);
      datetime ny = BrokerToNy(t1);
      MqlDateTime s; TimeToStruct(ny, s);
      string txt = StringFormat("NDOG ETH - %s, %d %d", MoisEn(s.mon), s.day, s.year);
      string id = (string)DayStamp(ny);
      bool flat = (hi - lo) < _Point / 2.0;
      if(flat)
         TrLine(PFX "ndF_" + id, t1, hi, t2, hi, InpCNdog, STYLE_SOLID, 2);
      else
      {
         RectBg(PFX "ndB_" + id, t1, hi, t2, lo, InpCNdogBg, true, true, 1);
         TrLine(PFX "ndH_" + id, t1, hi, t2, hi, InpCNdog, STYLE_SOLID, 1);
         TrLine(PFX "ndL_" + id, t1, lo, t2, lo, InpCNdog, STYLE_SOLID, 1);
         TrLine(PFX "ndM_" + id, t1, (hi + lo) / 2, t2, (hi + lo) / 2, InpCNdog, STYLE_DOT, 1);
      }
      // label unique a l'extremite droite, centre sur le gap
      Txt(PFX "ndT_" + id, t2, (hi + lo) / 2, txt, InpCNdog, 8, ANCHOR_LEFT);
   }
}

//=================== DASHBOARD ===================
string TfName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_MN1: return "MN";
      case PERIOD_W1:  return "W";
      case PERIOD_D1:  return "D";
      case PERIOD_H4:  return "H4";
      case PERIOD_H1:  return "H1";
      case PERIOD_M30: return "M30";
      case PERIOD_M15: return "M15";
      case PERIOD_M5:  return "M5";
      case PERIOD_M2:  return "M2";
      case PERIOD_M1:  return "M1";
   }
   return EnumToString(tf);
}
string CountdownTxt()
{
   long per = PeriodSeconds(PERIOD_CURRENT);
   long rem = per - ((long)TimeCurrent() - (long)iTime(_Symbol, PERIOD_CURRENT, 0));
   if(rem < 0) rem = 0;
   if(rem >= 3600) return StringFormat("%02d:%02d:%02d", (int)(rem / 3600), (int)((rem % 3600) / 60), (int)(rem % 60));
   return StringFormat("%02d:%02d", (int)(rem / 60), (int)(rem % 60));
}
// bouton du dashboard (—/✕), coin haut-droit, style chrome
void DashButton(string name, int x, int y, int w, int h, string txt)
{
   string n = PFX + name;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x + w);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString(0, n, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, C'228,228,228');
   ObjectSetInteger(0, n, OBJPROP_COLOR, C'50,50,50');
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void UpdateDashboard()
{
   if(!InpShowDash) return;
   int bias = StackState(InpBiasTF, hEmaB1, hEmaB2);
   int c1   = StackState(InpConf1TF, hEmaC11, hEmaC12);
   int c2   = StackState(InpConf2TF, hEmaC21, hEmaC22);
   bool conf1Ok = (bias == 1 && c1 == 1) || (bias == -1 && c1 == -1);
   bool conf2Ok = (bias == 1 && c2 == 1) || (bias == -1 && c2 == -1);
   bool fullL = bias == 1 && c1 == 1 && c2 == 1;
   bool fullS = bias == -1 && c1 == -1 && c2 == -1;
   color cGrn = C'0,128,0', cRed = C'178,34,34', cGry = C'90,90,90', cHdr = C'30,60,160', cDark = C'40,40,46';
   int w1 = 96, w2 = 86, h = 18, x2 = dashX, x1 = x2 + w2, yy = dashY;   // position deplacable
   DashCell("t0", x2, yy, w1 + w2, h, "ICT CONFLUENCE", cHdr, clrWhite);
   ObjectSetInteger(0, PFX "dashtx_t0", OBJPROP_XDISTANCE, x2 + 56);   // titre ~centre (place aux boutons)
   // boutons — / ✕ dans le coin du bandeau : reduire / fermer en un clic
   DashButton("btnMin", x2 + 22, yy + 1, 18, 16, "-");
   DashButton("btnX",   x2 + 2,  yy + 1, 18, 16, "x");
   yy += h;
   if(dashCollapsed) return;   // reduit : seul le bandeau (et ses boutons) reste
   DashCell("k1", x1, yy, w1, h, "Biais " + TfName(InpBiasTF), cDark, clrWhite);
   DashCell("v1", x2, yy, w2, h, bias == 1 ? "HAUSSIER" : bias == -1 ? "BAISSIER" : "NEUTRE", bias == 1 ? cGrn : bias == -1 ? cRed : cGry, clrWhite);
   yy += h;
   DashCell("k2", x1, yy, w1, h, "Conf " + TfName(InpConf1TF), cDark, clrWhite);
   DashCell("v2", x2, yy, w2, h, conf1Ok ? "OK" : "X", conf1Ok ? cGrn : cRed, clrWhite);
   yy += h;
   DashCell("k3", x1, yy, w1, h, "Conf " + TfName(InpConf2TF), cDark, clrWhite);
   DashCell("v3", x2, yy, w2, h, conf2Ok ? "OK" : "X", conf2Ok ? cGrn : cRed, clrWhite);
   yy += h;
   DashCell("k4", x1, yy, w1, h, "Structure", cDark, clrWhite);
   DashCell("v4", x2, yy, w2, h, trendSt == 1 ? "HAUSSIER" : trendSt == -1 ? "BAISSIER" : "-", trendSt == 1 ? cGrn : trendSt == -1 ? cRed : cGry, clrWhite);
   yy += h;
   DashCell("k5", x1, yy, w1, h, "SIGNAL", cDark, clrWhite);
   DashCell("v5", x2, yy, w2, h, fullL ? "LONG" : fullS ? "SHORT" : "-", fullL ? cGrn : fullS ? cRed : cGry, clrWhite);
   yy += h;
   if(InpShowCountdown)
   {
      DashCell("k6", x1, yy, w1, h, "Bougie", cDark, clrWhite);
      DashCell("v6", x2, yy, w2, h, CountdownTxt(), C'45,45,55', clrWhite);
   }
}

//=================== INIT / DEINIT ===================
int OnInit()
{
   SetIndexBuffer(0, BufE10, INDICATOR_DATA);
   SetIndexBuffer(1, BufE20, INDICATOR_DATA);
   ArraySetAsSeries(BufE10, false);
   ArraySetAsSeries(BufE20, false);
   // dashboard deplacable : position memorisee + evenements souris
   if(GlobalVariableCheck("ICTTD_dashX")) dashX = (int)GlobalVariableGet("ICTTD_dashX");
   if(GlobalVariableCheck("ICTTD_dashY")) dashY = (int)GlobalVariableGet("ICTTD_dashY");
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
   if(!InpShowEma)
   {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   hEmaC10 = iMA(_Symbol, PERIOD_CURRENT, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaC20 = iMA(_Symbol, PERIOD_CURRENT, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hEmaB1  = iMA(_Symbol, InpBiasTF,  InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaB2  = iMA(_Symbol, InpBiasTF,  InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hEmaC11 = iMA(_Symbol, InpConf1TF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaC12 = iMA(_Symbol, InpConf1TF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hEmaC21 = iMA(_Symbol, InpConf2TF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaC22 = iMA(_Symbol, InpConf2TF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   IndicatorSetString(INDICATOR_SHORTNAME, "ICT TopDown Confluence");   // pour le ✕ (ChartIndicatorDelete)
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, PFX);
}
void OnTimer()
{
   gmtOff = (int)(MathRound(((long)TimeTradeServer() - (long)TimeGMT()) / 1800.0) * 1800);
   RepositionMacros();   // suit l'echelle visible (zoom/scroll)
   UpdateDashboard();
   ChartRedraw(0);
}

// clics sur les boutons — / ✕ du dashboard + DRAG par le bandeau-titre
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int  mx  = (int)lparam, my = (int)dparam;
      bool lmb = (((int)StringToInteger(sparam)) & 1) != 0;
      int  chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      int  fx = chartW - mx;                       // distance au bord DROIT (corner du dashboard)
      if(!dashDrag && lmb && !dashPrevLmb
         && fx >= dashX + 42 && fx <= dashX + 182  // bandeau, hors zone des boutons - / x
         && my >= dashY && my <= dashY + 18)
      {
         dashDrag = true;
         dashOffX = fx - dashX; dashOffY = my - dashY;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
      }
      else if(dashDrag && lmb)
      {
         dashX = (int)MathMax(0, fx - dashOffX);
         dashY = (int)MathMax(0, my - dashOffY);
         UpdateDashboard();
         ChartRedraw(0);
      }
      else if(dashDrag && !lmb)
      {
         dashDrag = false;
         GlobalVariableSet("ICTTD_dashX", dashX);
         GlobalVariableSet("ICTTD_dashY", dashY);
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
      }
      dashPrevLmb = lmb;
      return;
   }
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(sparam == PFX "btnMin")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      dashCollapsed = !dashCollapsed;
      if(dashCollapsed) ClearDashRows();
      UpdateDashboard();
      ChartRedraw(0);
   }
   else if(sparam == PFX "btnX")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      // ✕ = FERMER l'indicateur en un clic (OnDeinit purge tous les objets)
      ChartIndicatorDelete(0, 0, "ICT TopDown Confluence");
   }
}

void ClearDashRows()
{
   string keys[12] = {"k1","v1","k2","v2","k3","v3","k4","v4","k5","v5","k6","v6"};
   for(int i = 0; i < 12; i++)
   {
      ObjectDelete(0, PFX "dashbg_" + keys[i]);
      ObjectDelete(0, PFX "dashtx_" + keys[i]);
   }
}

//=================== CALCUL PRINCIPAL ===================
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   if(rates_total < MathMax(InpSwingLen * 2 + 2, InpEmaSlow + 2)) return 0;
   gmtOff = (int)(MathRound(((long)TimeTradeServer() - (long)TimeGMT()) / 1800.0) * 1800);

   // EMAs du chart
   if(CopyBuffer(hEmaC10, 0, 0, rates_total, BufE10) < 0) return prev_calculated;
   if(CopyBuffer(hEmaC20, 0, 0, rates_total, BufE20) < 0) return prev_calculated;

   int start = prev_calculated > 1 ? prev_calculated - 1 : 0;
   if(prev_calculated == 0)
   {
      // recalcul complet : purge et reset
      ObjectsDeleteAll(0, PFX);
      ArrayResize(lqPx, 0);   ArrayResize(lqT1, 0);
      ArrayResize(lqHigh, 0); ArrayResize(lqMaj, 0);
      ArrayResize(lqEq, 0);   ArrayResize(lqAct, 0);
      ArrayResize(lqLn, 0);   ArrayResize(lqLb, 0);
      hBroken = true; lBroken = true; trendSt = 0;
      sgHBroken = true; sgLBroken = true; sgTrend = 0;
      pendBull = false; pendBear = false; pendOrigSet = false;
      lastKzDay = 0; lastNdogDay = 0; objId = 0;
      swHt = 0; swLt = 0; sgHt = 0; sgLt = 0;
      ArrayResize(macNm, 0); ArrayResize(macLane, 0);
      // ne traite que les ~5000 dernieres barres (perf)
      start = MathMax(0, rates_total - 5000);
   }

   int p = InpStructLen, q = InpSwingLen;
   bool intraday = _Period < PERIOD_D1;

   for(int i = start; i < rates_total; i++)
   {
      // ----- pivots internes (confirmes p barres plus tard) -----
      int j = i - p;
      if(j >= p)
      {
         bool isPh = true, isPl = true;
         for(int k = j - p; k <= j + p && (isPh || isPl); k++)
         {
            if(k == j) continue;
            if(high[k] >= high[j]) isPh = false;
            if(low[k]  <= low[j])  isPl = false;
         }
         if(isPh && time[j] != swHt)
         {
            swHb = MathMax(open[j], close[j]); swHw = high[j]; swHt = time[j]; hBroken = false;
            LiqAdd(high[j], time[j], true, false);
            // armement OTE bull : pic confirme apres cassure
            if(pendBull && pendOrigSet) DrawOte(true, time[i], i);
         }
         if(isPl && time[j] != swLt)
         {
            swLb = MathMin(open[j], close[j]); swLw = low[j]; swLt = time[j]; lBroken = false;
            LiqAdd(low[j], time[j], false, false);
            if(pendBear && pendOrigSet) DrawOte(false, time[i], i);
         }
      }
      // ----- cassures internes BOS / CHoCH -----
      if(swHt > 0 && !hBroken && close[i] > swHw)
      {
         bool isRev = trendSt == -1;
         trendSt = 1; hBroken = true;
         pendBull = true; pendBear = false; pendOrig = swLb; pendOrigSet = (swLt > 0);
         if(InpShowStruct && InpShowIntern)
            DrawBreak(swHw, swHt, time[i], isRev ? "CHoCH" : "BOS", isRev ? InpCChoch : InpCBos, false);
      }
      if(swLt > 0 && !lBroken && close[i] < swLw)
      {
         bool isRev = trendSt == 1;
         trendSt = -1; lBroken = true;
         pendBear = true; pendBull = false; pendOrig = swHb; pendOrigSet = (swHt > 0);
         if(InpShowStruct && InpShowIntern)
            DrawBreak(swLw, swLt, time[i], isRev ? "CHoCH" : "BOS", isRev ? InpCChoch : InpCBos, false);
      }
      // ----- pivots swing (MSS / BOS majeur) -----
      int jq = i - q;
      if(jq >= q)
      {
         bool isPh = true, isPl = true;
         for(int k = jq - q; k <= jq + q && (isPh || isPl); k++)
         {
            if(k == jq) continue;
            if(high[k] >= high[jq]) isPh = false;
            if(low[k]  <= low[jq])  isPl = false;
         }
         if(isPh && time[jq] != sgHt)
         {
            sgHw = high[jq]; sgHt = time[jq]; sgHBroken = false;
            LiqAdd(high[jq], time[jq], true, true);
         }
         if(isPl && time[jq] != sgLt)
         {
            sgLw = low[jq]; sgLt = time[jq]; sgLBroken = false;
            LiqAdd(low[jq], time[jq], false, true);
         }
      }
      if(sgHt > 0 && !sgHBroken && close[i] > sgHw)
      {
         bool isRev = sgTrend == -1;
         sgTrend = 1; sgHBroken = true;
         if(InpShowStruct) DrawBreak(sgHw, sgHt, time[i], isRev ? "MSS" : "BOS", isRev ? InpCMss : InpCBos, true);
      }
      if(sgLt > 0 && !sgLBroken && close[i] < sgLw)
      {
         bool isRev = sgTrend == 1;
         sgTrend = -1; sgLBroken = true;
         if(InpShowStruct) DrawBreak(sgLw, sgLt, time[i], isRev ? "MSS" : "BOS", isRev ? InpCMss : InpCBos, true);
      }
      // ----- liquidites : extension + sweep -----
      LiqSweepAndExtend(high[i], low[i], time[i]);
      // ----- killzones / macros / asian box : une fois par jour NY -----
      if(intraday)
      {
         long dNy = DayStamp(BrokerToNy(time[i]));
         if(dNy != lastKzDay)
         {
            lastKzDay = dNy;
            long cutoff = DayStamp(BrokerToNy(TimeCurrent())) ;
            // ne dessine que les InpKzDays derniers jours (approx. par difference brute)
            if(cutoff - dNy <= InpKzDays + 20)
            {
               if(InpShowLonOpen)  DrawDayWindow("LO", dNy, InpSessLonOpen,  InpCKzLonOpen,  true);
               if(InpShowNyOpen)   DrawDayWindow("NO", dNy, InpSessNyOpen,   InpCKzNyOpen,   true);
               if(InpShowLonClose) DrawDayWindow("LC", dNy, InpSessLonClose, InpCKzLonClose, true);
               if(InpShowNyClose)  DrawDayWindow("NC", dNy, InpSessNyClose,  InpCKzNyClose,  true);
               if(InpShowAsia)     DrawDayWindow("AS", dNy, InpSessAsia,     InpCKzAsia,     true);
               // macros : LTF uniquement (<= InpMacroMaxMin minutes), comme TV/NT
               bool macroOk = PeriodSeconds(PERIOD_CURRENT) <= InpMacroMaxMin * 60;
               if(macroOk && InpShowMacL)  DrawMacroSet("mL", dNy, InpMacWinL,  InpCMacLon, 0);
               if(macroOk && InpShowMacLN) DrawMacroSet("mN", dNy, InpMacWinLN, InpCMacLNy, 1);
               if(macroOk && InpShowMacP)  DrawMacroSet("mP", dNy, InpMacWinP,  InpCMacPm,  2);
               if(macroOk && InpShowMacA)  DrawMacroSet("mA", dNy, InpMacWinA,  InpCMacAs,  3);
               if(InpShowAsianBox) DrawAsianBox(dNy);
            }
         }
      }
   }

   // Asian Box du jour : range vivant
   if(intraday && InpShowAsianBox && lastKzDay > 0) DrawAsianBox(lastKzDay);
   // NDOG : redessine (le gap du jour suit le prix)
   long dToday = DayStamp(TimeCurrent());
   if(dToday != lastNdogDay || prev_calculated != rates_total)
   {
      lastNdogDay = dToday;
      DrawNdogs();
   }
   RepositionMacros();
   UpdateDashboard();
   return rates_total;
}

//=================== STRUCTURE / OTE (dessins) ===================
void DrawBreak(double lvl, datetime tFrom, datetime tTo, string tag, color c, bool bold)
{
   objId++;
   TrLine(PFX "brk_" + (string)objId, tFrom, lvl, tTo, lvl, c, bold ? STYLE_SOLID : STYLE_DASH, bold ? 2 : 1);
   datetime mid = tFrom + (tTo - tFrom) / 2;
   bool above = (tag == "CHoCH");
   Txt(PFX "brkT_" + (string)objId, mid, lvl, tag, c, 7, above ? ANCHOR_LOWER : ANCHOR_UPPER);
}
void DrawOte(bool isLong, datetime tNow, int barIdx)
{
   double orig = pendOrig;
   double term = isLong ? swHb : swLb;
   datetime tEnd = isLong ? swHt : swLt;
   double rng = term - orig;
   if(MathAbs(rng) < _Point) { if(isLong) pendBull = false; else pendBear = false; return; }
   double p62  = term - InpFib62    * rng;
   double p666 = term - InpFib666   * rng;
   double p705 = term - InpFibSweet * rng;
   double p79  = term - InpFib79    * rng;
   double top = MathMax(p666, p79), bot = MathMin(p666, p79);
   // A+ : biais HTF aligne (etat persistant au moment du trace)
   int bias = StackState(InpBiasTF, hEmaB1, hEmaB2);
   bool a1 = InpUseHTFGrade && ((isLong && bias == 1) || (!isLong && bias == -1));
   color dcol = isLong ? InpCLong : InpCShort;
   datetime tFwd = tNow + (datetime)(InpOteFwdBars * PeriodSeconds(PERIOD_CURRENT));
   objId++;
   string id = (string)objId;
   if(InpShowOTE)
   {
      RectBg(PFX "ote_" + id, tEnd, top, tFwd, bot, dcol, false, true, a1 ? 2 : 1);
      TrLine(PFX "ote705_" + id, tEnd, p705, tFwd, p705, dcol, STYLE_DASH, 1);
      TrLine(PFX "ote62_" + id,  tEnd, p62,  tFwd, p62,  dcol, STYLE_DOT, 1);
      if(InpShowTarget)
      {
         double tgt = term - InpFibTarget * rng;
         TrLine(PFX "oteTgt_" + id, tEnd, tgt, tFwd, tgt, clrGreen, STYLE_DOT, 1);
      }
   }
   if(InpShowOTELbl)
   {
      string txt = (isLong ? "OTE long" : "OTE short") + (a1 ? " A+" : "");
      Txt(PFX "oteT_" + id, tNow, isLong ? bot : top, txt, dcol, 8, isLong ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER);
   }
   if(isLong) pendBull = false; else pendBear = false;
}
//+------------------------------------------------------------------+
