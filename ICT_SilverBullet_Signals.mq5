//+------------------------------------------------------------------+
//|                                     ICT_SilverBullet_Signals.mq5  |
//|   Portage MT5 de l'indicateur "ICT Silver Bullet Signals" (NT).   |
//|   OUTIL DE SIGNAUX (aucun ordre) - moteur partage avec l'EA.      |
//|   LONG : stack strict, purge/reintegration du swing low, MSS      |
//|   interne 1/1 ou 2/2 + deplacement/FVG, puis retracement.         |
//|   SHORT : sequence miroir en premium.                             |
//|   Trace : EMA10/20 (base de la logique), triangle vert (LONG) /   |
//|   rouge (SHORT), lignes SL/TP optionnelles, fenetres NY en TRAITS|
//|   EN BAS (NY EST), dashboard style NT deplacable (- / X, decompte)|
//+------------------------------------------------------------------+
#property copyright "ICT Silver Bullet Signals - portage MT5"
#property version   "2.00"
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

#include "ICT_SilverBullet_Core.mqh"

//====================== ENUMS ======================
enum SbsTradeDir { SBS_BOTH=0, SBS_LONGONLY=1, SBS_SHORTONLY=2 };
enum SbsBrokerTimeMode
{
   SBS_BROKER_AUTO_LIVE=0,
   SBS_BROKER_FIXED=1,
   SBS_BROKER_EU_DST=2
};

//====================== INPUTS ======================
input group "== 1. Biais & Alignement =="
input ENUM_TIMEFRAMES InpHtfTF        = PERIOD_H1;
input ENUM_TIMEFRAMES InpConf1TF      = PERIOD_M5;
input ENUM_TIMEFRAMES InpConf2TF      = PERIOD_M1;
input int             InpEmaFast      = 10;
input int             InpEmaSlow      = 20;
input bool            InpRequireAlign = true; // Compatibilite : doit rester true
input SbsTradeDir     InpTradeDir     = SBS_BOTH;
input bool            InpUseTrendFilter = true; // Compatibilite : D1 reste obligatoire
input ENUM_TIMEFRAMES InpTrendTF      = PERIOD_D1;

input group "== 2. Modeles de signal =="
input bool   InpUseOTE       = false;
input bool   InpUseFVG       = true;
input bool   InpUseEmaRetest = true;
input bool   InpRequireDirectionalRejection = true; // Rejet/couleur directionnels au trigger
input double InpOteLow        = 0.62;
input double InpOteHigh       = 0.79;
input double InpOteSweet      = 0.705;
input int    InpMinDispTicks  = 20;
input int    InpMinFvgTicks   = 1;
input int    InpMaxFvgCandidates = 1; // Candidats FVG conserves (1 a 4)
input int    InpSetupExpiry   = 30;
input int    InpInternalPivotStrength = 1; // Pivot interne strict 1/1 ou 2/2
input int    InpExternalPivotStrength = 2; // Pivot de reference strict 1/1 ou 2/2
input bool   InpAllowMssBeforeTarget = false; // false=strict, true=MSS anticipe memorise
input bool   InpAllowTargetBeforeInternalPivot = false; // false=cible apres pivot obligatoire
input bool   InpRequireMSS    = true; // Compatibilite : MSS toujours obligatoire
input int    InpMssLookback   = 15;   // Compatibilite des anciens presets
input int    InpMaxPositions  = 3;    // Cap des setups candidats de l'indicateur

input group "== 3. Niveaux affiches =="
input int    InpSlBufferTicks = 4;
input double InpTp1R          = 2.0;
input double InpFinalR        = 4.0;
input bool   InpShowSlTp      = false;

input group "== 4. Filtre & visuel =="
input bool   InpUseSbWindows  = true;   // Compatibilite : doit rester true
input bool   InpShowEma       = true;   // Tracer EMA10/20 (base de la logique)
input bool   InpShowWindows   = true;   // Trois fenetres d'entree (traits en bas)
input bool   InpShowMacros    = true;   // Compatibilite anciens presets (sans effet)
input bool   InpShowDashboard = true;   // Tableau de bord (deplacable)
input bool   InpShowCountdown = true;   // Decompte de bougie
input color  InpLongColor     = clrLime;
input color  InpShortColor    = clrRed;
input int    InpArrowWidth    = 2;
input int    InpMaxBarsBack   = 3000;
input int    InpSwingWarmupBars = 500; // Prechauffage des swings avant la zone affichee
input bool   InpAlerts        = true;
input bool   InpPush          = true;   // Notification PUSH mobile (MetaQuotes ID requis)

input group "== 5. Heure NY (DST) =="
input bool   InpAutoDST         = true;  // Compatibilite : DST NY date obligatoire
input int    InpManualNYOffset  = -4;    // Compatibilite preset (non utilise en v2)
input SbsBrokerTimeMode InpBrokerTimeMode = SBS_BROKER_EU_DST;
input int    InpBrokerGmtHours       = 2; // Offset fixe ou heure standard Europe

//====================== MOTEUR PARTAGE ======================
SblSetup            g_setups[];
SblConsumedRegistry g_consumed;
SblConfig           g_coreConfig;

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
datetime g_lastSwingHiTime=0, g_lastSwingLoTime=0;
int      g_lastSwingHiConfirmBar=-1, g_lastSwingLoConfirmBar=-1;
int      g_alignedDir=0;

int      g_nextSetupId=0;
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
const int ROWH=19, COLW1=82, COLW2=248;
const int NROWS=5;   // Biais, Tendance, Fenetre, Signal, Bougie

const string PFX="SBS_";

string MssOrderModeName()
{
   return InpAllowMssBeforeTarget ? "FLEXIBLE" : "STRICT";
}

string TargetPivotOrderModeName()
{
   return InpAllowTargetBeforeInternalPivot ? "FLEXIBLE" : "STRICT";
}

string DirectionalRejectionModeName()
{
   return InpRequireDirectionalRejection ? "STRICT" : "FLEXIBLE";
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpHtfTF!=PERIOD_H1 || InpConf1TF!=PERIOD_M5 ||
      InpConf2TF!=PERIOD_M1 || InpTrendTF!=PERIOD_D1)
   {
      Print("ICT SB Signals : le stacking cible exige D1 + H1 + M5 + M1");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(!InpUseSbWindows)
   {
      Print("ICT SB Signals : InpUseSbWindows est conserve pour compatibilite "
            "mais doit rester true dans la logique v2");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpEmaFast!=10 || InpEmaSlow!=20 || !InpAutoDST ||
      !InpRequireAlign || !InpUseTrendFilter || !InpRequireMSS ||
      MathAbs(InpOteLow-0.62)>1e-9 ||
      MathAbs(InpOteHigh-0.79)>1e-9 ||
      InpOteSweet<InpOteLow || InpOteSweet>InpOteHigh ||
      InpMinDispTicks<0 || InpMinFvgTicks<=0 || InpSetupExpiry<=0 ||
      InpMaxFvgCandidates<1 || InpMaxFvgCandidates>4 ||
      InpInternalPivotStrength<1 || InpInternalPivotStrength>2 ||
      InpExternalPivotStrength<1 || InpExternalPivotStrength>2 ||
      InpMssLookback<=0 || InpMaxPositions<=0 ||
      InpSlBufferTicks<0 || InpTp1R<=0 || InpFinalR<=InpTp1R ||
      InpMaxBarsBack<InpEmaSlow+10 ||
      InpSwingWarmupBars<10 ||
      InpManualNYOffset<-12 || InpManualNYOffset>14 ||
      InpBrokerGmtHours<-12 || InpBrokerGmtHours>14 ||
      (!InpUseOTE && !InpUseFVG && !InpUseEmaRetest))
   {
      Print("ICT SB Signals : parametres invalides");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpBrokerTimeMode==SBS_BROKER_AUTO_LIVE &&
      (bool)MQLInfoInteger(MQL_TESTER))
   {
      Print("ICT SB Signals : AUTO_LIVE interdit en testeur ; choisir FIXED ou EU_DST");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpBrokerTimeMode==SBS_BROKER_AUTO_LIVE)
      Print("ICT SB Signals : AUTO_LIVE utilise l'offset broker actuel. "
            "Les signaux historiques peuvent etre decales ; utiliser FIXED ou EU_DST.");

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
   if(hExecF==INVALID_HANDLE||hExecS==INVALID_HANDLE||
      hHtfF==INVALID_HANDLE ||hHtfS==INVALID_HANDLE ||
      hC1F==INVALID_HANDLE  ||hC1S==INVALID_HANDLE  ||
      hC2F==INVALID_HANDLE  ||hC2S==INVALID_HANDLE  ||
      hTrF==INVALID_HANDLE  ||hTrS==INVALID_HANDLE)
   { Print("ICT SB Signals : erreur handles EMA"); return(INIT_FAILED); }

   g_brokerOff=InpBrokerTimeMode==SBS_BROKER_AUTO_LIVE
               ? DetectLiveBrokerOffset()
               : 0;
   g_coreConfig.minDisplacement=InpMinDispTicks*Tick();
   g_coreConfig.minFvgSize=InpMinFvgTicks*Tick();
   g_coreConfig.maxFvgCandidates=InpMaxFvgCandidates;
   g_coreConfig.oteLow=InpOteLow;
   g_coreConfig.oteHigh=InpOteHigh;
   g_coreConfig.expiryBars=InpSetupExpiry;
   g_coreConfig.requireWindow=true;
   g_coreConfig.requireDirectionalRejection=
      InpRequireDirectionalRejection;
   g_coreConfig.allowMssBeforeTarget=InpAllowMssBeforeTarget;
   g_coreConfig.allowTargetBeforeInternalPivot=
      InpAllowTargetBeforeInternalPivot;
   g_coreConfig.useFvgTrigger=InpUseFVG;
   g_coreConfig.useOteTrigger=InpUseOTE;
   g_coreConfig.useEmaTrigger=InpUseEmaRetest;
   SblResetRegistry(g_consumed);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("ICT SBS P%d/%d EP%d/%d MSS:%s C/P:%s DR:%s FVC:%d",
                                   InpInternalPivotStrength,
                                   InpInternalPivotStrength,
                                   InpExternalPivotStrength,
                                   InpExternalPivotStrength,
                                   MssOrderModeName(),
                                   TargetPivotOrderModeName(),
                                   DirectionalRejectionModeName(),
                                   InpMaxFvgCandidates));
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
int DetectLiveBrokerOffset()
{
   datetime g=TimeGMT(), s=TimeTradeServer();
   if(g<=0||s<=0) return 0;
   return (int)MathRound((double)(s-g)/900.0)*900;
}

int BrokerOffsetAtUtc(datetime utc)
{
   if(InpBrokerTimeMode==SBS_BROKER_AUTO_LIVE) return g_brokerOff;
   MqlDateTime value;
   TimeToStruct(utc,value);
   int mode=InpBrokerTimeMode==SBS_BROKER_EU_DST
            ? SBL_BROKER_DST_EUROPE
            : SBL_BROKER_OFFSET_CONSTANT;
   return SblBrokerUtcOffsetSeconds(mode,InpBrokerGmtHours,
                                    value.mon,value.day,
                                    value.hour*60+value.min,
                                    value.day_of_week);
}

datetime ServerToUtc(datetime server)
{
   if(InpBrokerTimeMode==SBS_BROKER_AUTO_LIVE)
      return server-g_brokerOff;
   if(InpBrokerTimeMode==SBS_BROKER_FIXED)
      return server-InpBrokerGmtHours*3600;

   datetime utc=server-InpBrokerGmtHours*3600;
   int offset=BrokerOffsetAtUtc(utc);
   utc=server-offset;
   int correctedOffset=BrokerOffsetAtUtc(utc);
   if(correctedOffset!=offset)
      utc=server-correctedOffset;
   return utc;
}

int NewYorkOffsetAtUtc(datetime utc)
{
   MqlDateTime value;
   TimeToStruct(utc,value);
   int minuteOfDay=value.hour*60+value.min;
   return SblNewYorkUtcOffsetSeconds(value.mon,value.day,minuteOfDay,
                                      value.day_of_week,InpAutoDST,
                                      InpManualNYOffset);
}
// heure serveur -> heure NY (via GMT, avec offset broker)
datetime ToNY(datetime server)
{
   datetime utc=ServerToUtc(server);
   return utc+NewYorkOffsetAtUtc(utc);
}
// heure "NY" -> heure serveur
datetime FromNY(datetime ny)
{
   if(!InpAutoDST)
   {
      datetime utc=ny-InpManualNYOffset*3600;
      return utc+BrokerOffsetAtUtc(utc);
   }

   // Tester d'abord l'interpretation EDT, puis EST. Les fenetres
   // d'entree ne traversent pas l'heure locale ambigue 01:00-02:00.
   datetime utc=ny+4*3600;
   if(NewYorkOffsetAtUtc(utc)!=-4*3600)
      utc=ny+5*3600;
   return utc+BrokerOffsetAtUtc(utc);
}
bool InSbWindow(datetime ny)
{
   MqlDateTime st; TimeToStruct(ny,st);
   return SblInEntryWindowMinutes(st.hour*60+st.min);
}
string ActiveWinName(datetime ny)
{
   MqlDateTime st; TimeToStruct(ny,st);
   int minuteOfDay=st.hour*60+st.min;
   if(minuteOfDay>=2*60 && minuteOfDay<5*60)  return "London 02-05";
   if(minuteOfDay>=7*60 && minuteOfDay<10*60) return "New York 07-10";
   if(minuteOfDay>=19*60 && minuteOfDay<22*60)return "Asia 19-22";
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
bool TryTfBias(int hF,int hS,ENUM_TIMEFRAMES tf,datetime tclose,
               int &bias)
{
   int sh=TfClosedShift(tf,tclose);
   if(sh<0) return false;
   double f[1],s[1];
   if(CopyBuffer(hF,0,sh,1,f)<1) return false;
   if(CopyBuffer(hS,0,sh,1,s)<1) return false;
   double c=iClose(_Symbol,tf,sh);
   if(c<=0.0) return false;
   bias=SblStrictStack(c,f[0],s[0]);
   return true;
}

//=================== gestion setups ===================
void ResetSignalEngine(bool clearSignalObjects)
{
   ArrayResize(g_setups,0);
   SblResetRegistry(g_consumed);
   g_biasHtf=SBL_NEUTRAL;
   g_biasC1=SBL_NEUTRAL;
   g_biasC2=SBL_NEUTRAL;
   g_trendBias=SBL_NEUTRAL;
   g_alignedDir=SBL_NEUTRAL;
   g_lastSwingHi=0.0;
   g_lastSwingLo=0.0;
   g_haveHi=false;
   g_haveLo=false;
   g_lastSwingHiTime=0;
   g_lastSwingLoTime=0;
   g_lastSwingHiConfirmBar=-1;
   g_lastSwingLoConfirmBar=-1;
   g_nextSetupId=0;
   g_barIndex=0;
   g_lastProcTime=0;
   g_lastSignal="-";
   g_lastSignalTime=0;
   if(clearSignalObjects)
      ObjectsDeleteAll(0,PFX+"sig");
}

void RemoveSetup(int idx)
{
   int n=ArraySize(g_setups);
   for(int i=idx;i<n-1;i++) g_setups[i]=g_setups[i+1];
   ArrayResize(g_setups,n-1);
}

bool HasSetupForLiquidity(int direction,long initialKey,long targetKey)
{
   for(int i=0;i<ArraySize(g_setups);i++)
   {
      if(g_setups[i].direction!=direction)
         continue;
      long setupInitial=direction==SBL_LONG
                        ? g_setups[i].refLowTime
                        : g_setups[i].refHighTime;
      long setupTarget=direction==SBL_LONG
                       ? g_setups[i].refHighTime
                       : g_setups[i].refLowTime;
      if(setupInitial==initialKey || setupTarget==targetKey)
         return true;
   }
   return false;
}

bool TryCreateSignalSetup(int direction,const SblBar &bar)
{
   long initialKey=direction==SBL_LONG
                   ? (long)g_lastSwingLoTime
                   : (long)g_lastSwingHiTime;
   long targetKey=direction==SBL_LONG
                  ? (long)g_lastSwingHiTime
                  : (long)g_lastSwingLoTime;
   if(ArraySize(g_setups)>=InpMaxPositions ||
      SblRegistryContains(g_consumed,direction,initialKey) ||
      SblRegistryContains(g_consumed,direction,targetKey) ||
      HasSetupForLiquidity(direction,initialKey,targetKey))
      return false;

   SblSetup setup;
   int setupId=g_nextSetupId+1;
   SblDecision startDecision;
   bool started=SblStartSetup(setup,setupId,direction,bar,
                              g_lastSwingHi,(long)g_lastSwingHiTime,
                              g_lastSwingLo,(long)g_lastSwingLoTime,
                              startDecision);
   if(startDecision.consumeTarget)
      SblRegistryConsume(g_consumed,startDecision.direction,
                         startDecision.targetKey);
   if(!started || !SblRegistryConsume(g_consumed,direction,initialKey))
      return false;

   int count=ArraySize(g_setups);
   ArrayResize(g_setups,count+1);
   g_setups[count]=setup;
   g_nextSetupId=setupId;
   return true;
}

string TriggerName(int trigger)
{
   if(trigger==SBL_TRIGGER_FVG) return "FVG";
   if(trigger==SBL_TRIGGER_OTE) return "OTE";
   if(trigger==SBL_TRIGGER_EMA) return "RetestEMA";
   return "";
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
void DrawSignal(int setupId,int dir,datetime t,double priceLow,double priceHigh,double entry,
                double sl,double tp1,double tp4,string trig,bool live)
{
   double rng=priceHigh-priceLow; if(rng<=0) rng=10*Tick();
   string nm=PFX+"sig"+IntegerToString(setupId);
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

//=================== fenetres d'entree = TRAITS EN BAS ===================
void RebuildLanes()
{
   ObjectsDeleteAll(0,PFX+"kz");
   // Nettoyage des objets produits par les versions anterieures.
   ObjectsDeleteAll(0,PFX+"mac");
   if(!InpShowWindows) return;

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
   double laneKZ=pmin+(pmax-pmin)*0.045;

   color kzc[3];
   kzc[0]=clrSteelBlue;
   kzc[1]=clrMediumSeaGreen;
   kzc[2]=clrMediumPurple;
   string kzn[3];
   kzn[0]="London 02:00-05:00";
   kzn[1]="New York 07:00-10:00";
   kzn[2]="Asia 19:00-22:00";
   int kzStartMin[3];
   kzStartMin[0]=2*60;
   kzStartMin[1]=7*60;
   kzStartMin[2]=19*60;
   int kzEndMin[3];
   kzEndMin[0]=5*60;
   kzEndMin[1]=10*60;
   kzEndMin[2]=22*60;

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
         datetime a=FromNY(nyDay+kzStartMin[k]*60);
         datetime b=FromNY(nyDay+kzEndMin[k]*60);
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
            string lt=PFX+"kzL"+dkey+"_"+IntegerToString(k);
            ObjectCreate(0,lt,OBJ_TEXT,0,aa,laneKZ);
            ObjectSetString(0,lt,OBJPROP_TEXT," "+kzn[k]);
            ObjectSetInteger(0,lt,OBJPROP_COLOR,kzc[k]);
            ObjectSetInteger(0,lt,OBJPROP_FONTSIZE,7);
            ObjectSetInteger(0,lt,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
            ObjectSetInteger(0,lt,OBJPROP_SELECTABLE,false);
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
   MkLabel(PFX+"title",
           StringFormat("SB P%d/%d EP%d/%d MSS:%s C/P:%s DR:%s FVC:%d",
                        InpInternalPivotStrength,
                        InpInternalPivotStrength,
                        InpExternalPivotStrength,
                        InpExternalPivotStrength,
                        MssOrderModeName(),
                        TargetPivotOrderModeName(),
                        DirectionalRejectionModeName(),
                        InpMaxFvgCandidates),
           clrWhite,8,true);
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

   MkLabel(PFX+"kt1","Stack",clrWhite,8,false);
   bool aligned=(g_alignedDir!=SBL_NEUTRAL);
   MkLabel(PFX+"vt1",BiasTxt(g_alignedDir)+"  "+trs+"·"+htf+"·"+c1+"·"+c2,clrWhite,8,false);
   ObjectSetInteger(0,PFX+"v1",OBJPROP_BGCOLOR,aligned?BiasCol(g_alignedDir):C'90,90,90');

   MkLabel(PFX+"kt2","Biais "+trs,clrWhite,8,false);
   MkLabel(PFX+"vt2",BiasTxt(g_trendBias)+" [STRICT]",clrWhite,8,false);
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
   if(InpBrokerTimeMode==SBS_BROKER_AUTO_LIVE)
   {
      int detected=DetectLiveBrokerOffset();
      if(detected!=g_brokerOff)
      {
         g_brokerOff=detected;
         if(InpShowWindows) RebuildLanes();
      }
   }
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
   ArraySetAsSeries(time,false);
   ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false);

   if(rates_total<InpEmaSlow+10) return(0);
   if(BarsCalculated(hExecF)<InpEmaSlow+2 || BarsCalculated(hExecS)<InpEmaSlow+2 ||
      BarsCalculated(hHtfF)<InpEmaSlow+2  || BarsCalculated(hHtfS)<InpEmaSlow+2  ||
      BarsCalculated(hC1F)<InpEmaSlow+2   || BarsCalculated(hC1S)<InpEmaSlow+2   ||
      BarsCalculated(hC2F)<InpEmaSlow+2   || BarsCalculated(hC2S)<InpEmaSlow+2   ||
      BarsCalculated(hTrF)<InpEmaSlow+2   || BarsCalculated(hTrS)<InpEmaSlow+2)
      return(prev_calculated);

   // --- EMA10/20 sur le graphe ---
   int toCopy=(prev_calculated==0)?rates_total:(rates_total-prev_calculated+2);
   if(toCopy>rates_total) toCopy=rates_total;
   if(toCopy<1) toCopy=1;
   if(InpShowEma)
   {
      if(CopyBuffer(hExecF,0,0,toCopy,g_emaFastBuf)!=toCopy ||
         CopyBuffer(hExecS,0,0,toCopy,g_emaSlowBuf)!=toCopy)
         return(prev_calculated);
   }
   else
   {
      for(int j=0;j<toCopy;j++){ g_emaFastBuf[j]=EMPTY_VALUE; g_emaSlowBuf[j]=EMPTY_VALUE; }
   }

   double tk=Tick();
   g_coreConfig.minDisplacement=InpMinDispTicks*tk;
   g_coreConfig.minFvgSize=InpMinFvgTicks*tk;

   bool rebuilding=(prev_calculated==0 || prev_calculated>rates_total || g_lastProcTime==0);
   int outputStart=MathMax(6,rates_total-1-InpMaxBarsBack);
   int start=0;
   if(rebuilding)
   {
      ResetSignalEngine(true);
      int warmup=MathMax(InpSwingWarmupBars,InpSetupExpiry+10);
      start=MathMax(6,outputStart-warmup);
   }
   else
   {
      // Rechercher uniquement les bougies nouvelles. Cette forme reste correcte
      // lorsque rates_total est plafonne et que l'index de l'historique glisse.
      int cursor=rates_total-2;
      while(cursor>=6 && time[cursor]>g_lastProcTime)
         cursor--;
      start=cursor+1;
   }

   int processedBars=0;
   int periodSeconds=PeriodSeconds(PERIOD_CURRENT);
   if(periodSeconds<=0) return(prev_calculated);
   for(int b=start;b<=rates_total-2;b++)
   {
      if(time[b]<=g_lastProcTime) continue;

      double h1=high[b],l1=low[b];

      // Une fermeture est l'heure d'ouverture + la duree du timeframe. Utiliser
      // l'ouverture suivante classerait la derniere bougie avant un gap avec
      // l'heure de reouverture (week-end/session) et fausserait la fenetre NY.
      datetime tclose=time[b]+periodSeconds;

      int biasHtf=SBL_NEUTRAL;
      int biasC1=SBL_NEUTRAL;
      int biasC2=SBL_NEUTRAL;
      int trendBias=SBL_NEUTRAL;
      if(!TryTfBias(hHtfF,hHtfS,InpHtfTF,tclose,biasHtf) ||
         !TryTfBias(hC1F,hC1S,InpConf1TF,tclose,biasC1) ||
         !TryTfBias(hC2F,hC2S,InpConf2TF,tclose,biasC2) ||
         !TryTfBias(hTrF,hTrS,InpTrendTF,tclose,trendBias))
         return(prev_calculated);

      double execEmaF=0.0;
      double ev[1];
      int shExec=(rates_total-1)-b;
      if(CopyBuffer(hExecF,0,shExec,1,ev)<1 || ev[0]<=0.0)
         return(prev_calculated);
      execEmaF=ev[0];

      // La barre n'est acquittee qu'apres toutes les lectures multi-TF.
      // Une indisponibilite temporaire sera ainsi rejouee au prochain appel.
      g_lastProcTime=time[b];
      g_barIndex++;
      processedBars++;
      g_biasHtf=biasHtf;
      g_biasC1=biasC1;
      g_biasC2=biasC2;
      g_trendBias=trendBias;
      int alignedDir=SblAlignedBias(trendBias,biasHtf,biasC1,biasC2);
      g_alignedDir=alignedDir;

      // Les pivots externes et internes partagent uniquement l'historique brut.
      // Leurs forces et leurs mappings causaux restent independants ci-dessous.
      SblBar pivotBars[5];
      for(int offset=0;offset<5;offset++)
      {
         int source=b-4+offset;
         datetime sourceClose=time[source]+periodSeconds;
         datetime sourceNy=ToNY(sourceClose);
         MqlDateTime sourceNyFields;
         TimeToStruct(sourceNy,sourceNyFields);
         int sourceMinute=sourceNyFields.hour*60+sourceNyFields.min;

         pivotBars[offset].time=(long)sourceClose;
         pivotBars[offset].index=g_barIndex-4+offset;
         pivotBars[offset].open=open[source];
         pivotBars[offset].high=high[source];
         pivotBars[offset].low=low[source];
         pivotBars[offset].close=close[source];
         pivotBars[offset].emaFast=0.0;
         pivotBars[offset].previousClose=close[source-1];
         pivotBars[offset].windowKey=SblEntryWindowKey(
            sourceNyFields.year*10000+sourceNyFields.mon*100+sourceNyFields.day,
            sourceMinute);
      }

      // Les references externes suivent leur propre buffer causal. En 1/1,
      // b-1 est le candidat et b le confirme ; en 2/2, b-2 reste le candidat.
      SblBar externalTwoBefore,externalOneBefore,externalCandidate,
             externalOneAfter,externalTwoAfter;
      externalTwoBefore=pivotBars[0];
      externalOneBefore=pivotBars[1];
      externalCandidate=pivotBars[2];
      externalOneAfter=pivotBars[3];
      externalTwoAfter=pivotBars[4];
      if(InpExternalPivotStrength==1)
      {
         externalTwoBefore=pivotBars[1]; // Ignore par le Core en mode 1/1.
         externalOneBefore=pivotBars[2];
         externalCandidate=pivotBars[3];
         externalOneAfter=pivotBars[4];
         externalTwoAfter=pivotBars[4];  // Ignore par le Core en mode 1/1.
      }

      SblPivot externalHighPivot,externalLowPivot;
      SblDetectInternalPivot(SBL_LONG,InpExternalPivotStrength,
                             externalTwoBefore,externalOneBefore,
                             externalCandidate,externalOneAfter,
                             externalTwoAfter,externalHighPivot);
      SblDetectInternalPivot(SBL_SHORT,InpExternalPivotStrength,
                             externalTwoBefore,externalOneBefore,
                             externalCandidate,externalOneAfter,
                             externalTwoAfter,externalLowPivot);
      SblRejectAmbiguousDualPivot(externalHighPivot,externalLowPivot);

      // Le buffer interne est entierement independant du reglage externe.
      SblBar internalTwoBefore,internalOneBefore,internalCandidate,
             internalOneAfter,internalTwoAfter;
      internalTwoBefore=pivotBars[0];
      internalOneBefore=pivotBars[1];
      internalCandidate=pivotBars[2];
      internalOneAfter=pivotBars[3];
      internalTwoAfter=pivotBars[4];
      if(InpInternalPivotStrength==1)
      {
         internalTwoBefore=pivotBars[1]; // Ignore par le Core en mode 1/1.
         internalOneBefore=pivotBars[2];
         internalCandidate=pivotBars[3];
         internalOneAfter=pivotBars[4];
         internalTwoAfter=pivotBars[4];  // Ignore par le Core en mode 1/1.
      }

      SblPivot internalHighPivot,internalLowPivot;
      SblDetectInternalPivot(SBL_LONG,InpInternalPivotStrength,
                             internalTwoBefore,internalOneBefore,
                             internalCandidate,internalOneAfter,
                             internalTwoAfter,internalHighPivot);
      SblDetectInternalPivot(SBL_SHORT,InpInternalPivotStrength,
                             internalTwoBefore,internalOneBefore,
                             internalCandidate,internalOneAfter,
                             internalTwoAfter,internalLowPivot);
      SblRejectAmbiguousDualPivot(internalHighPivot,internalLowPivot);

      SblBar bar;
      bar=pivotBars[4];
      bar.emaFast=execEmaF;

      SblFvg newFvg;
      SblDetectFvg(bar,pivotBars[2],g_coreConfig.minFvgSize,newFvg);
      bool inWindow=bar.windowKey>0;
      datetime serverNow=TimeCurrent();
      bool recent=serverNow>=tclose && serverNow-tclose<=periodSeconds;
      bool live=(!rebuilding && b==rates_total-2 && recent);

      for(int i=ArraySize(g_setups)-1;i>=0;i--)
      {
         SblPivot setupPivot;
         if(g_setups[i].direction==SBL_LONG)
            setupPivot=internalHighPivot;
         else
            setupPivot=internalLowPivot;
         SblDecision decision;
         SblAdvanceSetup(g_setups[i],bar,alignedDir,setupPivot,newFvg,inWindow,
                         g_coreConfig,decision);

         if(decision.consumeTarget)
            SblRegistryConsume(g_consumed,decision.direction,
                               decision.targetKey);

         if(decision.signal)
         {
            double entry=decision.expectedEntry;
            double sl=decision.direction==SBL_LONG
                      ? g_setups[i].fib0-InpSlBufferTicks*tk
                      : g_setups[i].fib0+InpSlBufferTicks*tk;
            double risk=MathAbs(entry-sl);
            if(risk>=tk && b>=outputStart)
            {
               double tp1=decision.direction==SBL_LONG
                          ? entry+InpTp1R*risk : entry-InpTp1R*risk;
               double tp4=decision.direction==SBL_LONG
                          ? entry+InpFinalR*risk : entry-InpFinalR*risk;
               DrawSignal(decision.setupId,decision.direction,
                          (datetime)g_setups[i].triggerTime,l1,h1,entry,sl,tp1,tp4,
                          TriggerName(decision.trigger),live);
            }
            RemoveSetup(i);
            continue;
         }

         if(g_setups[i].phase==SBL_PHASE_INVALID ||
            g_setups[i].phase==SBL_PHASE_TRIGGERED)
            RemoveSetup(i);
      }

      bool allowLong =(InpTradeDir!=SBS_SHORTONLY);
      bool allowShort=(InpTradeDir!=SBS_LONGONLY);
      bool highConfirmedEarlier=g_haveHi &&
                                g_barIndex>g_lastSwingHiConfirmBar;
      bool lowConfirmedEarlier=g_haveLo &&
                               g_barIndex>g_lastSwingLoConfirmBar;
      bool refsConfirmedEarlier=highConfirmedEarlier && lowConfirmedEarlier;
      long highKey=(long)g_lastSwingHiTime;
      long lowKey=(long)g_lastSwingLoTime;
      bool rawHigh=highConfirmedEarlier && bar.high>g_lastSwingHi;
      bool rawLow=lowConfirmedEarlier && bar.low<g_lastSwingLo;

      // Une cible reservee est exposee par SblAdvanceSetup. Sans reservation,
      // la meche brute consomme directement la liquidite directionnelle.
      if(rawHigh && !HasSetupForLiquidity(SBL_LONG,0,highKey))
         SblRegistryConsume(g_consumed,SBL_LONG,highKey);
      if(rawLow && !HasSetupForLiquidity(SBL_SHORT,0,lowKey))
         SblRegistryConsume(g_consumed,SBL_SHORT,lowKey);

      bool longPurge=lowConfirmedEarlier &&
                     SblPurgeReintegrated(SBL_LONG,bar,
                                          g_lastSwingHi,g_lastSwingLo);
      bool shortPurge=highConfirmedEarlier &&
                      SblPurgeReintegrated(SBL_SHORT,bar,
                                           g_lastSwingHi,g_lastSwingLo);

      if(longPurge)
         if(inWindow && refsConfirmedEarlier && alignedDir==SBL_LONG &&
            allowLong)
            TryCreateSignalSetup(SBL_LONG,bar);
      if(shortPurge)
         if(inWindow && refsConfirmedEarlier && alignedDir==SBL_SHORT &&
            allowShort)
            TryCreateSignalSetup(SBL_SHORT,bar);

      // Toute meche de purge consomme son origine, meme si biais, fenetre ou
      // capacite refusent le setup. Si la creation a reussi, cet appel est un
      // no-op ; une bougie double-side consomme donc cible et origine.
      if(rawLow)
         SblRegistryConsume(g_consumed,SBL_LONG,lowKey);
      if(rawHigh)
         SblRegistryConsume(g_consumed,SBL_SHORT,highKey);

      // Un pivot externe confirme a cette cloture n'etait pas connaissable
      // pendant la bougie. Il devient donc une reference seulement pour la
      // suivante ; le core a deja pu l'utiliser comme pivot interne ci-dessus.
      if(externalHighPivot.present &&
         externalHighPivot.pivotTime>(long)g_lastSwingHiTime)
      {
         g_lastSwingHi=externalHighPivot.price;
         g_lastSwingHiTime=(datetime)externalHighPivot.pivotTime;
         g_lastSwingHiConfirmBar=externalHighPivot.confirmedBar;
         g_haveHi=true;
      }
      if(externalLowPivot.present &&
         externalLowPivot.pivotTime>(long)g_lastSwingLoTime)
      {
         g_lastSwingLo=externalLowPivot.price;
         g_lastSwingLoTime=(datetime)externalLowPivot.pivotTime;
         g_lastSwingLoConfirmBar=externalLowPivot.confirmedBar;
         g_haveLo=true;
      }
   }

   if(InpShowWindows && (rebuilding||processedBars>0))
      RebuildLanes();
   UpdateDashboard();
   return(rates_total);
}
//+------------------------------------------------------------------+
