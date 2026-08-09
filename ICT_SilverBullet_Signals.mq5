//+------------------------------------------------------------------+
//|                                     ICT_SilverBullet_Signals.mq5  |
//|   Portage MT5 de l'indicateur "ICT Silver Bullet Signals" (NT).   |
//|   OUTIL DE SIGNAUX (aucun ordre) — modele CONTINUATION identique  |
//|   a l'EA ICT_SilverBullet_Strategy.                               |
//|   Trace : EMA10/20 (base de la logique), triangle vert (LONG) /   |
//|   rouge (SHORT), lignes SL/TP optionnelles, killzones en TRAITS   |
//|   EN BAS (NY EST), dashboard style NT deplacable (- / X, decompte)|
//+------------------------------------------------------------------+
#property copyright "ICT Silver Bullet Signals - portage MT5"
#property version   "1.10"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_label1  "EMA rapide"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label2  "EMA lente"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//====================== ENUMS ======================
enum SbsTradeDir { SBS_BOTH=0, SBS_LONGONLY=1, SBS_SHORTONLY=2 };

//====================== INPUTS ======================
input group "== 1. Biais & Alignement =="
input ENUM_TIMEFRAMES InpHtfTF        = PERIOD_H1;
input ENUM_TIMEFRAMES InpConf1TF      = PERIOD_M5;
input ENUM_TIMEFRAMES InpConf2TF      = PERIOD_M1;
input int             InpEmaFast      = 10;
input int             InpEmaSlow      = 20;
input bool            InpRequireAlign = true;
input SbsTradeDir     InpTradeDir     = SBS_BOTH;
input bool            InpUseTrendFilter = true;
input ENUM_TIMEFRAMES InpTrendTF      = PERIOD_D1;

input group "== 2. Modeles de signal =="
input bool   InpUseOTE       = false;
input bool   InpUseFVG       = true;
input bool   InpUseEmaRetest = true;
input double InpOteLow        = 0.62;
input double InpOteSweet      = 0.705;
input int    InpMinDispTicks  = 20;
input int    InpMinFvgTicks   = 1;
input int    InpSetupExpiry   = 30;
input bool   InpRequireMSS    = true;
input int    InpMssLookback   = 15;

input group "== 3. Niveaux affiches =="
input int    InpSlBufferTicks = 4;
input double InpTp1R          = 2.0;
input double InpFinalR        = 4.0;
input bool   InpShowSlTp      = false;

input group "== 4. Filtre & visuel =="
input bool   InpUseSbWindows  = true;   // Restreindre aux fenetres Silver Bullet
input bool   InpShowEma       = true;   // Tracer EMA10/20 (base de la logique)
input bool   InpShowWindows   = true;   // Killzones (traits en bas)
input bool   InpShowMacros    = true;   // Macros seconde chance (traits en bas)
input bool   InpShowDashboard = true;   // Tableau de bord (deplacable)
input bool   InpShowCountdown = true;   // Decompte de bougie
input color  InpLongColor     = clrLime;
input color  InpShortColor    = clrRed;
input int    InpArrowWidth    = 2;
input int    InpMaxBarsBack   = 3000;
input bool   InpAlerts        = true;
input bool   InpPush          = true;   // Notification PUSH mobile (MetaQuotes ID requis)

input group "== 5. Heure NY (DST) =="
input bool   InpAutoDST         = true;  // Heure NY DST auto (EDT/EST)
input int    InpManualNYOffset  = -4;    // Decalage GMT de NY manuel (si DST auto OFF)
input int    InpBrokerGmtHours  = 99;    // Decalage GMT du broker (99 = auto-detecte)

//====================== SETUP STRUCT ======================
struct SbsSetup
{
   int      dir;
   double   sweepPx, sweepExtreme, legLo, legHi;
   int      sweepBar;
   bool     armed, hasFvg;
   double   fvgTop, fvgBot;
   bool     done;
};
SbsSetup g_setups[];

//====================== GLOBALS ======================
double g_emaFastBuf[], g_emaSlowBuf[];

int hExecF=INVALID_HANDLE, hExecS=INVALID_HANDLE;
int hHtfF =INVALID_HANDLE, hHtfS =INVALID_HANDLE;
int hC1F  =INVALID_HANDLE, hC1S  =INVALID_HANDLE;
int hC2F  =INVALID_HANDLE, hC2S  =INVALID_HANDLE;
int hTrF  =INVALID_HANDLE, hTrS  =INVALID_HANDLE;

int      g_biasHtf=0, g_biasC1=0, g_biasC2=0, g_trendBias=0;
double   g_lastSwingHi=0, g_lastSwingLo=0;
bool     g_haveHi=false, g_haveLo=false;
int      g_mssBias=0, g_mssBar=-1000000;
int      g_alignedDir=0;

int      g_seq=0;
int      g_barIndex=0;
datetime g_lastProcTime=0;
int      g_brokerOff=0;         // decalage broker->GMT (secondes)

string   g_lastSignal="-";
datetime g_lastSignalTime=0;

// dashboard
int   g_dashX=-1, g_dashY=8;
bool  g_collapsed=false, g_hidden=false;
bool  g_dragging=false;
int   g_grabDX=0, g_grabDY=0;
const int ROWH=19, COLW1=82, COLW2=178;
const int NROWS=5;   // Biais, Tendance, Fenetre, Signal, Bougie

const string PFX="SBS_";

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0,g_emaFastBuf,INDICATOR_DATA);
   SetIndexBuffer(1,g_emaSlowBuf,INDICATOR_DATA);
   ArraySetAsSeries(g_emaFastBuf,true);
   ArraySetAsSeries(g_emaSlowBuf,true);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetString(0,PLOT_LABEL,"EMA"+IntegerToString(InpEmaFast));
   PlotIndexSetString(1,PLOT_LABEL,"EMA"+IntegerToString(InpEmaSlow));

   hExecF=iMA(_Symbol,PERIOD_CURRENT,InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
   hExecS=iMA(_Symbol,PERIOD_CURRENT,InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
   hHtfF =iMA(_Symbol,InpHtfTF,  InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
   hHtfS =iMA(_Symbol,InpHtfTF,  InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
   hC1F  =iMA(_Symbol,InpConf1TF,InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
   hC1S  =iMA(_Symbol,InpConf1TF,InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
   hC2F  =iMA(_Symbol,InpConf2TF,InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
   hC2S  =iMA(_Symbol,InpConf2TF,InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
   hTrF  =iMA(_Symbol,InpTrendTF,InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
   hTrS  =iMA(_Symbol,InpTrendTF,InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
   if(hExecF==INVALID_HANDLE||hHtfF==INVALID_HANDLE||hC1F==INVALID_HANDLE||
      hC2F==INVALID_HANDLE||hTrF==INVALID_HANDLE)
   { Print("ICT SB Signals : erreur handles EMA"); return(INIT_FAILED); }

   g_brokerOff=DetectBrokerOffset();

   IndicatorSetString(INDICATOR_SHORTNAME,"ICT SB Signals");
   ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,true);

   if(InpShowDashboard)
   {
      int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
      g_dashX=MathMax(0,(cw-(COLW1+COLW2))/2);   // defaut = haut-centre
      g_dashY=8;
      BuildDashboard();
      LayoutDashboard();
   }
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0,PFX);
   IndicatorRelease(hExecF); IndicatorRelease(hExecS);
   IndicatorRelease(hHtfF);  IndicatorRelease(hHtfS);
   IndicatorRelease(hC1F);   IndicatorRelease(hC1S);
   IndicatorRelease(hC2F);   IndicatorRelease(hC2S);
   IndicatorRelease(hTrF);   IndicatorRelease(hTrS);
   ChartRedraw();
}

//=================== heure NY / DST ===================
int DetectBrokerOffset()
{
   if(InpBrokerGmtHours!=99) return InpBrokerGmtHours*3600;
   datetime g=TimeGMT(), s=TimeTradeServer();
   if(g<=0||s<=0) return 0;
   return (int)MathRound((double)(s-g)/3600.0)*3600;
}
bool IsUSDST(datetime g)
{
   MqlDateTime t; TimeToStruct(g,t);
   int month=t.mon, day=t.day;
   if(month<3||month>11) return false;
   if(month>3&&month<11) return true;
   MqlDateTime m; m.year=t.year; m.mon=month; m.day=1; m.hour=0; m.min=0; m.sec=0;
   datetime first=StructToTime(m);
   MqlDateTime fw; TimeToStruct(first,fw);
   int dow1=fw.day_of_week;
   int firstSunday=(dow1==0)?1:(8-dow1);
   if(month==3)  { int secondSunday=firstSunday+7; return (day>=secondSunday); }
   if(month==11) { return (day<firstSunday); }
   return false;
}
// heure serveur -> heure NY (via GMT, avec offset broker)
datetime ToNY(datetime server)
{
   datetime gmt=server-g_brokerOff;
   int nyOff=InpAutoDST?(IsUSDST(gmt)?-4:-5):InpManualNYOffset;
   return gmt+nyOff*3600;
}
// heure "NY" -> heure serveur
datetime FromNY(datetime ny)
{
   int nyOff=InpAutoDST?(IsUSDST(ny)?-4:-5):InpManualNYOffset;
   datetime gmt=ny-nyOff*3600;
   return gmt+g_brokerOff;
}
bool InSbWindow(datetime ny)
{
   MqlDateTime st; TimeToStruct(ny,st);
   double t=st.hour+st.min/60.0;
   if(t>=3&&t<4)   return true;
   if(t>=10&&t<11) return true;
   if(t>=14&&t<15) return true;
   if(t>=3.75&&t<4.25)   return true;
   if(t>=10.75&&t<11.25) return true;
   if(t>=14.75&&t<15.25) return true;
   return false;
}
string ActiveWinName(datetime ny)
{
   MqlDateTime st; TimeToStruct(ny,st);
   double t=st.hour+st.min/60.0;
   if(t>=3&&t<4.25)   return "London Open";
   if(t>=10&&t<11.25) return "AM";
   if(t>=14&&t<15.25) return "PM";
   return "";
}
double Tick(){ double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); return (ts>0?ts:_Point); }

int TfClosedShift(ENUM_TIMEFRAMES tf, datetime tclose)
{
   int sh=iBarShift(_Symbol,tf,tclose,false);
   if(sh<0) return -1;
   datetime bopen=iTime(_Symbol,tf,sh);
   int tfs=PeriodSeconds(tf);
   if(bopen+tfs<=tclose) return sh;
   return sh+1;
}
int TfBias(int hF,int hS,ENUM_TIMEFRAMES tf,datetime tclose,int prev)
{
   int sh=TfClosedShift(tf,tclose);
   if(sh<0) return prev;
   double f[1],s[1];
   if(CopyBuffer(hF,0,sh,1,f)<1) return prev;
   if(CopyBuffer(hS,0,sh,1,s)<1) return prev;
   double c=iClose(_Symbol,tf,sh);
   if(c>0&&c>f[0]&&f[0]>s[0]) return 1;
   if(c>0&&c<f[0]&&f[0]<s[0]) return -1;
   return prev;
}

//=================== gestion setups ===================
void AddSetup(int dir,double sweepPx,double extreme,double legLo,double legHi,int bar)
{
   int n=ArraySize(g_setups); ArrayResize(g_setups,n+1);
   g_setups[n].dir=dir; g_setups[n].sweepPx=sweepPx; g_setups[n].sweepExtreme=extreme;
   g_setups[n].legLo=legLo; g_setups[n].legHi=legHi; g_setups[n].sweepBar=bar;
   g_setups[n].armed=false; g_setups[n].hasFvg=false; g_setups[n].fvgTop=0; g_setups[n].fvgBot=0; g_setups[n].done=false;
}
void RemoveSetup(int idx)
{
   int n=ArraySize(g_setups);
   for(int i=idx;i<n-1;i++) g_setups[i]=g_setups[i+1];
   ArrayResize(g_setups,n-1);
}
bool AlreadySwept(double lvl,int dir)
{
   double tk=Tick();
   for(int i=0;i<ArraySize(g_setups);i++)
      if(g_setups[i].dir==dir && MathAbs(g_setups[i].sweepPx-lvl)<=tk) return true;
   return false;
}

//=================== dessin signal ===================
void DrawSeg(string nm,datetime t1,double p1,datetime t2,double p2,color c,int style,int w)
{
   if(ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_TREND,0,t1,p1,t2,p2);
   ObjectSetInteger(0,nm,OBJPROP_TIME,0,t1); ObjectSetDouble(0,nm,OBJPROP_PRICE,0,p1);
   ObjectSetInteger(0,nm,OBJPROP_TIME,1,t2); ObjectSetDouble(0,nm,OBJPROP_PRICE,1,p2);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
   ObjectSetInteger(0,nm,OBJPROP_STYLE,style);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,w);
   ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,nm,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
}
void DrawSignal(int dir,datetime t,double priceLow,double priceHigh,double entry,
                double sl,double tp1,double tp4,string trig,bool live)
{
   g_seq++;
   double rng=priceHigh-priceLow; if(rng<=0) rng=10*Tick();
   string nm=PFX+"sig"+IntegerToString(g_seq);
   double y=(dir>0)?priceLow-rng*0.6:priceHigh+rng*0.6;
   ObjectCreate(0,nm,OBJ_ARROW,0,t,y);
   ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,(dir>0)?233:234);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,(dir>0)?InpLongColor:InpShortColor);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,MathMax(1,InpArrowWidth));
   ObjectSetInteger(0,nm,OBJPROP_ANCHOR,(dir>0)?ANCHOR_TOP:ANCHOR_BOTTOM);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   ObjectSetString(0,nm,OBJPROP_TOOLTIP,(dir>0?"LONG ":"SHORT ")+trig);

   if(InpShowSlTp)
   {
      datetime t2=t+PeriodSeconds(_Period)*8;
      DrawSeg(nm+"_sl", t,sl, t2,sl,  clrRed,       STYLE_DOT,1);
      DrawSeg(nm+"_t1", t,tp1,t2,tp1, clrGoldenrod, STYLE_DASH,1);
      DrawSeg(nm+"_t4", t,tp4,t2,tp4, (dir>0)?InpLongColor:InpShortColor, STYLE_SOLID,1);
   }
   g_lastSignal=(dir>0?"LONG ":"SHORT ")+trig;
   g_lastSignalTime=t;
   if(live)
   {
      string tfs=EnumToString((ENUM_TIMEFRAMES)_Period); StringReplace(tfs,"PERIOD_","");
      string msg="ICT SB "+g_lastSignal+" "+_Symbol+" "+tfs
                +" @ "+DoubleToString(entry,_Digits)
                +" SL "+DoubleToString(sl,_Digits)
                +" TP1 "+DoubleToString(tp1,_Digits)
                +" TP "+DoubleToString(tp4,_Digits);
      if(InpAlerts) Alert(msg);
      if(InpPush)
      {
         if(!SendNotification(msg))
            Print("ICT SB : echec push (MetaQuotes ID configure ? Options>Notifications) err=",GetLastError());
      }
   }
}

//=================== killzones = TRAITS EN BAS ===================
void RebuildLanes()
{
   ObjectsDeleteAll(0,PFX+"kz");
   ObjectsDeleteAll(0,PFX+"mac");
   if(!InpShowWindows && !InpShowMacros) return;

   int bars=Bars(_Symbol,_Period); if(bars<10) return;
   long fvb=ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR,0);
   long vb =ChartGetInteger(0,CHART_VISIBLE_BARS,0);
   int leftIdx =(int)MathMin(bars-1,fvb);
   int rightIdx=(int)MathMax(0,(int)(fvb-vb+1));
   datetime tLeft =iTime(_Symbol,_Period,leftIdx);
   datetime tRight=iTime(_Symbol,_Period,rightIdx);
   if(tLeft<=0||tRight<=0) return;

   double pmin=ChartGetDouble(0,CHART_PRICE_MIN,0);
   double pmax=ChartGetDouble(0,CHART_PRICE_MAX,0);
   if(pmax<=pmin) return;
   double laneKZ =pmin+(pmax-pmin)*0.045;
   double laneMac=pmin+(pmax-pmin)*0.085;

   color kzc[3]; kzc[0]=clrSteelBlue; kzc[1]=clrMediumSeaGreen; kzc[2]=clrGoldenrod;
   string kzn[3]; kzn[0]="London"; kzn[1]="AM"; kzn[2]="PM";
   int    kzh[3]; kzh[0]=3; kzh[1]=10; kzh[2]=14;

   // iterer par jour NY couvrant [tLeft,tRight]
   datetime nyL=ToNY(tLeft), nyR=ToNY(tRight);
   MqlDateTime d; TimeToStruct(nyL,d); d.hour=0; d.min=0; d.sec=0;
   datetime nyDay=StructToTime(d)-86400;
   datetime nyEndLoop=nyR+86400;

   for(; nyDay<=nyEndLoop; nyDay+=86400)
   {
      MqlDateTime dk; TimeToStruct(nyDay,dk);
      string dkey=StringFormat("%04d%02d%02d",dk.year,dk.mon,dk.day);
      for(int k=0;k<3;k++)
      {
         // killzone principale [k:00, k+1:00] NY
         if(InpShowWindows)
         {
            datetime a=FromNY(nyDay+kzh[k]*3600);
            datetime b=FromNY(nyDay+(kzh[k]+1)*3600);
            if(b>=tLeft && a<=tRight)
            {
               datetime aa=(a<tLeft)?tLeft:a;
               datetime bb=(b>tRight)?tRight:b;
               string nm=PFX+"kz"+dkey+"_"+IntegerToString(k);
               ObjectCreate(0,nm,OBJ_TREND,0,aa,laneKZ,bb,laneKZ);
               ObjectSetInteger(0,nm,OBJPROP_COLOR,kzc[k]);
               ObjectSetInteger(0,nm,OBJPROP_WIDTH,4);
               ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,false);
               ObjectSetInteger(0,nm,OBJPROP_RAY_LEFT,false);
               ObjectSetInteger(0,nm,OBJPROP_BACK,false);
               ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
               // etiquette de session
               string lt=PFX+"kzL"+dkey+"_"+IntegerToString(k);
               ObjectCreate(0,lt,OBJ_TEXT,0,aa,laneKZ);
               ObjectSetString(0,lt,OBJPROP_TEXT," "+kzn[k]);
               ObjectSetInteger(0,lt,OBJPROP_COLOR,kzc[k]);
               ObjectSetInteger(0,lt,OBJPROP_FONTSIZE,7);
               ObjectSetInteger(0,lt,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
               ObjectSetInteger(0,lt,OBJPROP_SELECTABLE,false);
               // renommer pour effacement groupe kz
               ObjectSetString(0,lt,OBJPROP_NAME,lt);
            }
         }
         // macro seconde chance [k:45, k+1:15] NY
         if(InpShowMacros)
         {
            datetime a=FromNY(nyDay+kzh[k]*3600+45*60);
            datetime b=FromNY(nyDay+(kzh[k]+1)*3600+15*60);
            if(b>=tLeft && a<=tRight)
            {
               datetime aa=(a<tLeft)?tLeft:a;
               datetime bb=(b>tRight)?tRight:b;
               string nm=PFX+"mac"+dkey+"_"+IntegerToString(k);
               ObjectCreate(0,nm,OBJ_TREND,0,aa,laneMac,bb,laneMac);
               ObjectSetInteger(0,nm,OBJPROP_COLOR,kzc[k]);
               ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
               ObjectSetInteger(0,nm,OBJPROP_STYLE,STYLE_DOT);
               ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,false);
               ObjectSetInteger(0,nm,OBJPROP_RAY_LEFT,false);
               ObjectSetInteger(0,nm,OBJPROP_BACK,false);
               ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
            }
         }
      }
   }
}

//=================== dashboard (style NT, deplacable) ===================
void MkRect(string nm,color bg)
{
   if(ObjectFind(0,nm)<0)
   {
      ObjectCreate(0,nm,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,nm,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,C'60,60,60');
      ObjectSetInteger(0,nm,OBJPROP_BACK,false);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   }
   ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,bg);
}
void MkLabel(string nm,string txt,color c,int fs,bool bold)
{
   if(ObjectFind(0,nm)<0)
   {
      ObjectCreate(0,nm,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,nm,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   }
   ObjectSetString(0,nm,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,fs);
   ObjectSetString(0,nm,OBJPROP_FONT,bold?"Arial Bold":"Arial");
}
void MkButton(string nm,string txt)
{
   if(ObjectFind(0,nm)<0)
   {
      ObjectCreate(0,nm,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,C'228,228,228');
      ObjectSetInteger(0,nm,OBJPROP_COLOR,C'40,40,40');
      ObjectSetInteger(0,nm,OBJPROP_BORDER_COLOR,C'90,90,90');
      ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,nm,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,nm,OBJPROP_XSIZE,16);
      ObjectSetInteger(0,nm,OBJPROP_YSIZE,15);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   }
   ObjectSetString(0,nm,OBJPROP_TEXT,txt);
}
void BuildDashboard()
{
   MkRect(PFX+"hdr",C'30,60,160');
   MkLabel(PFX+"title","ICT SB - SIGNAUX",clrWhite,9,true);
   MkButton(PFX+"btnMin","-");
   MkButton(PFX+"btnClose","x");
   for(int i=1;i<=NROWS;i++)
   {
      MkRect(PFX+"k"+IntegerToString(i),C'20,20,20');
      MkRect(PFX+"v"+IntegerToString(i),C'90,90,90');
      MkLabel(PFX+"kt"+IntegerToString(i),"",clrWhite,8,false);
      MkLabel(PFX+"vt"+IntegerToString(i),"",clrWhite,8,false);
   }
}
void SetVis(string nm,bool vis)
{
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES, vis?OBJ_ALL_PERIODS:OBJ_NO_PERIODS);
}
void LayoutDashboard()
{
   if(!InpShowDashboard) return;
   int x=g_dashX, y=g_dashY, W=COLW1+COLW2;

   // header
   ObjectSetInteger(0,PFX+"hdr",OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,PFX+"hdr",OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,PFX+"hdr",OBJPROP_XSIZE,W);
   ObjectSetInteger(0,PFX+"hdr",OBJPROP_YSIZE,ROWH);
   ObjectSetInteger(0,PFX+"title",OBJPROP_XDISTANCE,x+6);
   ObjectSetInteger(0,PFX+"title",OBJPROP_YDISTANCE,y+4);
   ObjectSetInteger(0,PFX+"btnClose",OBJPROP_XDISTANCE,x+W-18);
   ObjectSetInteger(0,PFX+"btnClose",OBJPROP_YDISTANCE,y+2);
   ObjectSetInteger(0,PFX+"btnMin",OBJPROP_XDISTANCE,x+W-36);
   ObjectSetInteger(0,PFX+"btnMin",OBJPROP_YDISTANCE,y+2);

   bool hid=g_hidden;
   SetVis(PFX+"hdr",!hid); SetVis(PFX+"title",!hid);
   SetVis(PFX+"btnMin",!hid); SetVis(PFX+"btnClose",!hid);

   for(int i=1;i<=NROWS;i++)
   {
      int ry=y+i*ROWH;
      string ki=IntegerToString(i);
      ObjectSetInteger(0,PFX+"k"+ki,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,PFX+"k"+ki,OBJPROP_YDISTANCE,ry);
      ObjectSetInteger(0,PFX+"k"+ki,OBJPROP_XSIZE,COLW1);
      ObjectSetInteger(0,PFX+"k"+ki,OBJPROP_YSIZE,ROWH-1);
      ObjectSetInteger(0,PFX+"v"+ki,OBJPROP_XDISTANCE,x+COLW1);
      ObjectSetInteger(0,PFX+"v"+ki,OBJPROP_YDISTANCE,ry);
      ObjectSetInteger(0,PFX+"v"+ki,OBJPROP_XSIZE,COLW2);
      ObjectSetInteger(0,PFX+"v"+ki,OBJPROP_YSIZE,ROWH-1);
      ObjectSetInteger(0,PFX+"kt"+ki,OBJPROP_XDISTANCE,x+5);
      ObjectSetInteger(0,PFX+"kt"+ki,OBJPROP_YDISTANCE,ry+4);
      ObjectSetInteger(0,PFX+"vt"+ki,OBJPROP_XDISTANCE,x+COLW1+5);
      ObjectSetInteger(0,PFX+"vt"+ki,OBJPROP_YDISTANCE,ry+4);

      bool rowVis = !hid && !g_collapsed && (i<NROWS || InpShowCountdown);
      SetVis(PFX+"k"+ki,rowVis); SetVis(PFX+"v"+ki,rowVis);
      SetVis(PFX+"kt"+ki,rowVis); SetVis(PFX+"vt"+ki,rowVis);
   }
}
string BiasTxt(int b){ return b>0?"HAUSSIER":(b<0?"BAISSIER":"neutre"); }
color  BiasCol(int b){ return b>0?C'0,128,0':(b<0?C'178,34,34':C'90,90,90'); }
string TfShort(ENUM_TIMEFRAMES tf){ string s=EnumToString(tf); StringReplace(s,"PERIOD_",""); return s; }

void UpdateDashboard()
{
   if(!InpShowDashboard || g_hidden) return;
   string htf=TfShort(InpHtfTF), c1=TfShort(InpConf1TF), c2=TfShort(InpConf2TF), trs=TfShort(InpTrendTF);

   MkLabel(PFX+"kt1","Biais "+htf,clrWhite,8,false);
   bool aligned = g_biasHtf!=0 && (!InpRequireAlign || (g_biasC1==g_biasHtf && g_biasC2==g_biasHtf));
   MkLabel(PFX+"vt1",BiasTxt(g_biasHtf)+"  "+c1+"·"+c2,clrWhite,8,false);
   ObjectSetInteger(0,PFX+"v1",OBJPROP_BGCOLOR, aligned?BiasCol(g_biasHtf):C'90,90,90');

   MkLabel(PFX+"kt2","Tendance "+trs,clrWhite,8,false);
   MkLabel(PFX+"vt2",BiasTxt(g_trendBias)+(InpUseTrendFilter?" [ON]":""),clrWhite,8,false);
   ObjectSetInteger(0,PFX+"v2",OBJPROP_BGCOLOR,BiasCol(g_trendBias));

   datetime ny=ToNY(TimeCurrent());
   bool inkz=InSbWindow(ny);
   string wn=ActiveWinName(ny);
   MkLabel(PFX+"kt3","Fenetre",clrWhite,8,false);
   MkLabel(PFX+"vt3",inkz?(wn+" ACTIVE"):"hors fenetre",clrWhite,8,false);
   ObjectSetInteger(0,PFX+"v3",OBJPROP_BGCOLOR,inkz?(color)C'150,120,20':(color)C'90,90,90');

   int sdir=(StringFind(g_lastSignal,"LONG")==0)?1:((StringFind(g_lastSignal,"SHORT")==0)?-1:0);
   MkLabel(PFX+"kt4","Signal",clrWhite,8,false);
   MkLabel(PFX+"vt4",g_lastSignal,clrWhite,8,false);
   ObjectSetInteger(0,PFX+"v4",OBJPROP_BGCOLOR,BiasCol(sdir));

   MkLabel(PFX+"kt5","Bougie",clrWhite,8,false);
   if(InpShowCountdown)
   {
      int rem=(int)(PeriodSeconds(_Period)-(TimeCurrent()%PeriodSeconds(_Period)));
      if(rem<0) rem=0;
      MkLabel(PFX+"vt5",StringFormat("%02d:%02d",rem/60,rem%60),clrWhite,8,false);
   }
   else MkLabel(PFX+"vt5","",clrWhite,8,false);
   ObjectSetInteger(0,PFX+"v5",OBJPROP_BGCOLOR,C'45,45,55');
}

void OnTimer()
{
   if(InpShowDashboard){ UpdateDashboard(); ChartRedraw(); }
}

//=================== evenements souris / boutons ===================
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam==PFX+"btnMin"){ g_collapsed=!g_collapsed; LayoutDashboard(); ObjectSetInteger(0,sparam,OBJPROP_STATE,false); ChartRedraw(); }
      else if(sparam==PFX+"btnClose"){ g_hidden=true; LayoutDashboard(); ObjectSetInteger(0,sparam,OBJPROP_STATE,false); ChartRedraw(); }
      return;
   }
   if(id==CHARTEVENT_MOUSE_MOVE)
   {
      int x=(int)lparam, y=(int)dparam;
      int st=(int)StringToInteger(sparam);
      bool leftDown=((st&1)==1);
      int W=COLW1+COLW2;
      if(leftDown && !g_hidden)
      {
         if(!g_dragging && x>=g_dashX && x<=g_dashX+W-40 && y>=g_dashY && y<=g_dashY+ROWH)
         { g_dragging=true; g_grabDX=x-g_dashX; g_grabDY=y-g_dashY; }
         if(g_dragging)
         {
            g_dashX=x-g_grabDX; g_dashY=y-g_grabDY;
            int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
            int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
            if(g_dashX<0) g_dashX=0; if(g_dashX>cw-W) g_dashX=cw-W;
            if(g_dashY<0) g_dashY=0; if(g_dashY>ch-ROWH) g_dashY=ch-ROWH;
            LayoutDashboard(); ChartRedraw();
         }
      }
      else g_dragging=false;
      return;
   }
   if(id==CHARTEVENT_CHART_CHANGE)
   {
      RebuildLanes();
      ChartRedraw();
      return;
   }
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total<InpEmaSlow+10) return(rates_total);

   // --- EMA10/20 sur le graphe ---
   int toCopy=(prev_calculated==0)?rates_total:(rates_total-prev_calculated+2);
   if(toCopy>rates_total) toCopy=rates_total;
   if(toCopy<1) toCopy=1;
   if(InpShowEma)
   {
      CopyBuffer(hExecF,0,0,toCopy,g_emaFastBuf);
      CopyBuffer(hExecS,0,0,toCopy,g_emaSlowBuf);
   }
   else
   {
      for(int j=0;j<toCopy;j++){ g_emaFastBuf[j]=EMPTY_VALUE; g_emaSlowBuf[j]=EMPTY_VALUE; }
   }

   double tk=Tick();

   for(int b=MathMax(6, (g_lastProcTime==0? rates_total-1-InpMaxBarsBack : 6)); b<=rates_total-2; b++)
   {
      if(time[b]<=g_lastProcTime) continue;
      g_lastProcTime=time[b];
      g_barIndex++;

      double h1=high[b],  l1=low[b],  c1=close[b], o1=open[b];
      double h2=high[b-1],l2=low[b-1];
      double h3=high[b-2],l3=low[b-2];
      double h4=high[b-3],l4=low[b-3];
      double h5=high[b-4],l5=low[b-4];
      double h6=high[b-5],l6=low[b-5];

      datetime tclose=time[b]+PeriodSeconds(_Period);
      datetime ny=ToNY(time[b]);

      g_biasHtf  =TfBias(hHtfF,hHtfS,InpHtfTF,  tclose,g_biasHtf);
      g_biasC1   =TfBias(hC1F, hC1S, InpConf1TF,tclose,g_biasC1);
      g_biasC2   =TfBias(hC2F, hC2S, InpConf2TF,tclose,g_biasC2);
      g_trendBias=TfBias(hTrF, hTrS, InpTrendTF,tclose,g_trendBias);

      int alignedDir=g_biasHtf;
      if(InpRequireAlign)
      {
         if(g_biasHtf!=0 && g_biasC1==g_biasHtf && g_biasC2==g_biasHtf) alignedDir=g_biasHtf;
         else alignedDir=0;
      }
      if(InpUseTrendFilter && (g_trendBias==0 || alignedDir!=g_trendBias)) alignedDir=0;
      g_alignedDir=alignedDir;

      if(h4>h2 && h4>h3 && h4>h5 && h4>h6){ g_lastSwingHi=h4; g_haveHi=true; }
      if(l4<l2 && l4<l3 && l4<l5 && l4<l6){ g_lastSwingLo=l4; g_haveLo=true; }
      if(g_haveHi && c1>g_lastSwingHi){ g_mssBias=1;  g_mssBar=g_barIndex; }
      if(g_haveLo && c1<g_lastSwingLo){ g_mssBias=-1; g_mssBar=g_barIndex; }

      bool bullFvg=(l2>h4)&&((l2-h4)>=InpMinFvgTicks*tk);
      bool bearFvg=(h2<l4)&&((l4-h2)>=InpMinFvgTicks*tk);
      double fvgTop=0,fvgBot=0;
      if(bullFvg){ fvgTop=l2; fvgBot=h4; }
      if(bearFvg){ fvgTop=h2; fvgBot=l4; }

      double execEmaF=0; double ev[1];
      int shExec=(rates_total-1)-b;
      if(CopyBuffer(hExecF,0,shExec,1,ev)>=1) execEmaF=ev[0];

      bool live=(b==rates_total-2);

      for(int i=ArraySize(g_setups)-1;i>=0;i--)
      {
         if(g_setups[i].done){ RemoveSetup(i); continue; }

         if(g_setups[i].dir>0) g_setups[i].legHi=MathMax(g_setups[i].legHi,h1);
         else                  g_setups[i].legLo=MathMin(g_setups[i].legLo,l1);

         if(g_setups[i].dir>0 && bullFvg && (!g_setups[i].hasFvg || fvgTop<g_setups[i].fvgTop))
            { g_setups[i].hasFvg=true; g_setups[i].fvgTop=fvgTop; g_setups[i].fvgBot=fvgBot; }
         if(g_setups[i].dir<0 && bearFvg && (!g_setups[i].hasFvg || fvgBot>g_setups[i].fvgBot))
            { g_setups[i].hasFvg=true; g_setups[i].fvgTop=fvgTop; g_setups[i].fvgBot=fvgBot; }

         if(!g_setups[i].armed)
         {
            double disp=g_setups[i].dir>0?(g_setups[i].legHi-g_setups[i].sweepExtreme)
                                         :(g_setups[i].sweepExtreme-g_setups[i].legLo);
            if(g_setups[i].hasFvg || disp>=InpMinDispTicks*tk) g_setups[i].armed=true;
         }

         bool invalid=(g_setups[i].dir>0 && c1<g_setups[i].sweepExtreme) ||
                      (g_setups[i].dir<0 && c1>g_setups[i].sweepExtreme);
         if(invalid || alignedDir!=g_setups[i].dir || (g_barIndex-g_setups[i].sweepBar)>InpSetupExpiry)
            { RemoveSetup(i); continue; }

         if(g_setups[i].armed)
         {
            bool mssOk=!InpRequireMSS || (g_mssBias==g_setups[i].dir && (g_barIndex-g_mssBar)<=InpMssLookback);
            if((!InpUseSbWindows || InSbWindow(ny)) && mssOk)
            {
               double entry=EMPTY_VALUE; string trig="";
               double legLo=g_setups[i].legLo, legHi=g_setups[i].legHi;
               double mid=legLo+0.5*(legHi-legLo);

               if(InpUseFVG && g_setups[i].hasFvg)
               {
                  if(g_setups[i].dir>0 && g_setups[i].fvgTop<=mid && l1<=g_setups[i].fvgTop && h1>=g_setups[i].fvgBot)
                     { entry=MathMin(o1,g_setups[i].fvgTop); trig="FVG"; }
                  if(g_setups[i].dir<0 && g_setups[i].fvgBot>=mid && h1>=g_setups[i].fvgBot && l1<=g_setups[i].fvgTop)
                     { entry=MathMax(o1,g_setups[i].fvgBot); trig="FVG"; }
               }
               if(entry==EMPTY_VALUE && InpUseOTE)
               {
                  double rng=legHi-legLo;
                  if(rng>0)
                  {
                     if(g_setups[i].dir>0)
                     {
                        double zHi=legHi-InpOteLow*rng, sweet=legHi-InpOteSweet*rng;
                        if(l1<=zHi){ entry=MathMin(o1,sweet>zHi?zHi:sweet); trig="OTE"; }
                     }
                     else
                     {
                        double zLo=legLo+InpOteLow*rng, sweet=legLo+InpOteSweet*rng;
                        if(h1>=zLo){ entry=MathMax(o1,sweet<zLo?zLo:sweet); trig="OTE"; }
                     }
                  }
               }
               if(entry==EMPTY_VALUE && InpUseEmaRetest && execEmaF>0)
               {
                  if(g_setups[i].dir>0 && l1<=execEmaF && c1>=o1){ entry=c1; trig="RetestEMA"; }
                  if(g_setups[i].dir<0 && h1>=execEmaF && c1<=o1){ entry=c1; trig="RetestEMA"; }
               }

               if(entry!=EMPTY_VALUE && trig!="")
               {
                  double sl=g_setups[i].dir>0?g_setups[i].sweepExtreme-InpSlBufferTicks*tk
                                             :g_setups[i].sweepExtreme+InpSlBufferTicks*tk;
                  double r=MathAbs(entry-sl);
                  if(r>=tk)
                  {
                     double tp1=g_setups[i].dir>0?entry+InpTp1R*r:entry-InpTp1R*r;
                     double tp4=g_setups[i].dir>0?entry+InpFinalR*r:entry-InpFinalR*r;
                     DrawSignal(g_setups[i].dir,time[b],l1,h1,entry,sl,tp1,tp4,trig,live);
                  }
                  RemoveSetup(i);
                  continue;
               }
            }
         }
      }

      bool allowLong =(InpTradeDir!=SBS_SHORTONLY);
      bool allowShort=(InpTradeDir!=SBS_LONGONLY);
      if(alignedDir!=0)
      {
         if(alignedDir>0 && allowLong && g_haveHi && g_haveLo)
         {
            if(h1>g_lastSwingHi && !AlreadySwept(g_lastSwingHi,1))
               AddSetup(1,g_lastSwingHi,g_lastSwingLo,g_lastSwingLo,h1,g_barIndex);
         }
         else if(alignedDir<0 && allowShort && g_haveLo && g_haveHi)
         {
            if(l1<g_lastSwingLo && !AlreadySwept(g_lastSwingLo,-1))
               AddSetup(-1,g_lastSwingLo,g_lastSwingHi,l1,g_lastSwingHi,g_barIndex);
         }
      }
   }

   if(InpShowWindows||InpShowMacros) RebuildLanes();
   UpdateDashboard();
   return(rates_total);
}
//+------------------------------------------------------------------+
