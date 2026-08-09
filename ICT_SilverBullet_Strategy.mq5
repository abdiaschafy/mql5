//+------------------------------------------------------------------+
//|                                    ICT_SilverBullet_Strategy.mq5 |
//|   Continuation ICT : stack D1/H1/M5/M1 strict, purge reintegree,|
//|   pivot interne 2/2, cible, MSS, FVG CE, puis retracement.       |
//|                                                                  |
//|   LONG  : purge low -> pivot high interne -> cible high -> MSS  |
//|           interne -> FVG en discount -> retracement -> achat.   |
//|   SHORT : sequence exactement symetrique en premium -> vente.   |
//|                                                                  |
//|   Toutes les decisions d'entree utilisent des bougies fermees.  |
//|   Les sorties et le trailing sont controles a chaque tick.      |
//+------------------------------------------------------------------+
#property copyright "ICT Silver Bullet - portage MT5"
#property version   "2.00"
#property strict

#include <Trade/Trade.mqh>
#include "ICT_SilverBullet_Core.mqh"

CTrade trade;

//====================== ENUMS ======================
enum SbTradeDir { SB_BOTH=0, SB_LONGONLY=1, SB_SHORTONLY=2 };
enum SbBrokerTimeMode
{
   SB_BROKER_AUTO_LIVE=0,
   SB_BROKER_FIXED,
   SB_BROKER_EUROPE_DST
};

enum SbModifyPurpose
{
   SB_MODIFY_NONE=0,
   SB_MODIFY_PROTECTION,
   SB_MODIFY_BREAK_EVEN,
   SB_MODIFY_TRAIL
};

//====================== INPUTS ======================
input group "== 1. Biais & Alignement =="
input ENUM_TIMEFRAMES InpHtfTF        = PERIOD_H1;   // TF Biais HTF
input ENUM_TIMEFRAMES InpConf1TF      = PERIOD_M5;   // TF Confirmation 1
input ENUM_TIMEFRAMES InpConf2TF      = PERIOD_M1;   // TF Confirmation 2
input int             InpEmaFast      = 10;          // EMA rapide
input int             InpEmaSlow      = 20;          // EMA lente
input bool            InpRequireAlign = true;        // Compatibilite : alignement toujours exige
input SbTradeDir      InpTradeDir     = SB_BOTH;     // Sens des trades
input bool            InpUseTrendFilter = true;      // Compatibilite : D1 toujours exige
input ENUM_TIMEFRAMES InpTrendTF      = PERIOD_D1;   // Compatibilite : D1 est impose

input group "== 2. Modeles d'entree =="
input bool   InpUseOTE       = false;   // OTE comme declencheur (62-79 %)
input bool   InpUseFVG       = true;    // FVG comme declencheur (contexte FVG toujours requis)
input bool   InpUseEmaRetest = true;    // Retest EMA comme declencheur
input double InpOteLow       = 0.62;    // OTE bas (62 %)
input double InpOteHigh      = 0.79;    // OTE haut (79 %)
input double InpOteSweet     = 0.705;   // Compatibilite preset (zone complete utilisee)
input int    InpMinDispTicks = 20;      // Deplacement min (ticks)
input int    InpMinFvgTicks  = 1;       // Taille min FVG (ticks)
input int    InpSetupExpiry  = 30;      // Expiration depuis la purge (barres)
input bool   InpRequireMSS   = true;    // Compatibilite : MSS toujours exige
input int    InpMssLookback  = 15;      // Compatibilite preset

input group "== 3. Stop / Take profit =="
input int    InpSlBufferTicks = 4;      // Buffer SL au-dela de Fib 0
input double InpTp1R          = 2.0;    // TP1 + BE (R)
input double InpFinalR        = 4.0;    // TP final runner (R)
input double InpTp1Percent    = 50;     // Part sortie TP1 (%)
input bool   InpTrailRunner   = true;   // Trailing du runner
input double InpTrailR        = 2.0;    // Distance de trailing (R)

input group "== 4. Risque & Money =="
input bool   InpUseAccountEquity = true;   // Utiliser l'equity du compte
input double InpAccountSize      = 100000; // Taille compte si equity OFF
input double InpRiskPct          = 1.0;    // Risque / trade (%)
input double InpRiskAfterLossPct = 0.5;    // Risque apres 1 perte (%)
input double InpRiskUntilWinPct  = 0.25;   // Risque jusqu'au prochain gain (%)
input int    InpMaxPositions     = 3;      // Maximum positions + setups actifs
input double InpDailyDDPct       = 5.0;    // Perte realisee max / jour (%)
input double InpMinLots          = 0.0;    // Lots minimum demande (sans sur-risque)

input group "== 5. Filtre horaire New York =="
input bool   InpUseSbWindows      = true;  // Compatibilite : fenetres toujours exigees
input bool   InpAutoDST           = true;  // Compatibilite : DST NY date obligatoire
input int    InpManualGMTOffset   = -4;    // Compatibilite : non utilise (DST auto impose)
input SbBrokerTimeMode InpBrokerTimeMode = SB_BROKER_EUROPE_DST; // Base temps broker
input int    InpBrokerGmtHours    = 2;     // Offset standard broker (Exness : +2)

input group "== 6. Divers =="
input long   InpMagic     = 260711;   // Magic number
input int    InpSlippage  = 20;       // Deviation max (points)
input int    InpBrokerReconcileSeconds = 120; // Delai max de reconciliation broker
input bool   InpVerbose   = false;    // Journal detaille

//====================== ETAT D'EXECUTION ======================
struct StrategySetup
{
   SblSetup logic;

   bool     entered;
   bool     entryPending;
   ulong    entryOrder;
   uint     entryRequestId;
   datetime entryPendingSince;
   long     entryRequestTimeMsc;
   double   requestedLots;
   bool     entryRejected;
   bool     entryCancelPending;
   bool     entryCancelCompletionKnown;
   uint     entryCancelRequestId;
   datetime entryCancelPendingSince;
   bool     entryCancelRejected;
   ulong    entryDeal;
   ulong    positionIdentifier;
   ulong    positionTicket;
   double   entryPx;
   double   sl;
   double   tp1;
   double   tpFinal;
   double   riskDistance;
   double   totalLots;
   double   coreLots;
   bool     coreTaken;
   bool     tp1Confirmed;
   bool     partialPending;
   bool     partialCompletionKnown;
   ulong    partialOrder;
   uint     partialRequestId;
   datetime partialPendingSince;
   bool     partialRejected;
   double   partialBeforeVolume;
   bool     closePending;
   bool     closeCompletionKnown;
   ulong    closeOrder;
   uint     closeRequestId;
   datetime closePendingSince;
   bool     closeRejected;
   double   closeBeforeVolume;
   bool     modifyPending;
   bool     modifyCompletionKnown;
   ulong    modifyOrder;
   uint     modifyRequestId;
   datetime modifyPendingSince;
   bool     modifyRejected;
   double   modifyStop;
   double   modifyTakeProfit;
   int      modifyPurpose;
   bool     beDone;
   bool     forceClose;
   double   highSinceEntry;
   double   lowSinceEntry;
   double   runnerStop;
   string   triggerName;
};

StrategySetup g_setups[];
SblConsumedRegistry g_consumed;

//====================== INDICATEURS ======================
int hExecF=INVALID_HANDLE, hExecS=INVALID_HANDLE;
int hHtfF =INVALID_HANDLE, hHtfS =INVALID_HANDLE;
int hC1F  =INVALID_HANDLE, hC1S  =INVALID_HANDLE;
int hC2F  =INVALID_HANDLE, hC2S  =INVALID_HANDLE;
int hD1F  =INVALID_HANDLE, hD1S  =INVALID_HANDLE;

int g_biasHtf=0, g_biasC1=0, g_biasC2=0, g_biasD1=0;

double   g_lastSwingHigh=0.0, g_lastSwingLow=0.0;
datetime g_lastSwingHighTime=0, g_lastSwingLowTime=0;
bool     g_haveSwingHigh=false, g_haveSwingLow=false;
int      g_lastSwingHighConfirmBar=-1, g_lastSwingLowConfirmBar=-1;

int      g_riskLevel=0;
int      g_currentNyDayKey=0;
double   g_dayRealized=0.0;
bool     g_dayLocked=false;

int      g_sequence=0;
int      g_barIndex=0;
datetime g_lastBarOpen=0;
bool     g_initialized=false;
bool     g_recoveryBlocked=false;

const long SB_STATE_SIGNATURE_V2=0x53424C32;
const long SB_STATE_SIGNATURE_V3=0x53424C33;

//====================== INITIALISATION ======================
bool InputsAreValid()
{
   if(InpHtfTF!=PERIOD_H1 || InpConf1TF!=PERIOD_M5 ||
      InpConf2TF!=PERIOD_M1 || InpTrendTF!=PERIOD_D1 ||
      !InpRequireAlign || !InpUseTrendFilter || !InpRequireMSS ||
      !InpUseSbWindows || !InpAutoDST)
      return false;
   if(InpEmaFast!=10 || InpEmaSlow!=20)
      return false;
   if(!InpUseOTE && !InpUseFVG && !InpUseEmaRetest)
      return false;
   if(MathAbs(InpOteLow-0.62)>1e-9 ||
      MathAbs(InpOteHigh-0.79)>1e-9)
      return false;
   if(InpOteSweet<InpOteLow || InpOteSweet>InpOteHigh)
      return false;
   if(InpMinDispTicks<0 || InpMinFvgTicks<=0 || InpSetupExpiry<=0)
      return false;
   if(InpSlBufferTicks<0 || InpTp1R<=0.0 || InpFinalR<=InpTp1R ||
      InpTp1Percent<0.0 || InpTp1Percent>=100.0 || InpTrailR<=0.0)
      return false;
   if(InpRiskPct<=0.0 || InpRiskAfterLossPct<=0.0 ||
      InpRiskUntilWinPct<=0.0 || InpMaxPositions<=0 ||
      InpDailyDDPct<=0.0 || InpAccountSize<=0.0)
      return false;
   if(InpBrokerGmtHours < -12 || InpBrokerGmtHours > 14 ||
      InpManualGMTOffset < -12 || InpManualGMTOffset > 14 ||
      InpMinLots<0.0 || InpSlippage<0 || InpMagic<0 ||
      InpBrokerReconcileSeconds<10 || InpBrokerReconcileSeconds>3600)
      return false;
   return true;
}

string RegistryFileName()
{
   string server=AccountInfoString(ACCOUNT_SERVER);
   string symbol=_Symbol;
   StringReplace(server,"\\","_"); StringReplace(server,"/","_");
   StringReplace(server,":","_");  StringReplace(server,"*","_");
   StringReplace(server,"?","_");  StringReplace(server,"\"","_");
   StringReplace(server,"<","_");  StringReplace(server,">","_");
   StringReplace(server,"|","_");
   StringReplace(symbol,"\\","_"); StringReplace(symbol,"/","_");
   StringReplace(symbol,":","_");  StringReplace(symbol,"*","_");
   StringReplace(symbol,"?","_");  StringReplace(symbol,"\"","_");
   StringReplace(symbol,"<","_");  StringReplace(symbol,">","_");
   StringReplace(symbol,"|","_");
   long login=AccountInfoInteger(ACCOUNT_LOGIN);
   return StringFormat("ICT_SB_registry_%s_%I64d_%I64d_%s.bin",
                       server,login,InpMagic,symbol);
}

void LoadConsumedRegistry()
{
   SblResetRegistry(g_consumed);
   g_riskLevel=0;
   g_currentNyDayKey=0;
   g_dayRealized=0.0;
   g_dayLocked=false;
   if((bool)MQLInfoInteger(MQL_TESTER)) return;

   int file=FileOpen(RegistryFileName(),
                     FILE_READ|FILE_BIN|FILE_COMMON|FILE_SHARE_READ);
   if(file==INVALID_HANDLE) return;

   long signature=FileReadLong(file);
   int longCount=(int)FileReadLong(file);
   int shortCount=(int)FileReadLong(file);
   bool valid=(signature==SB_STATE_SIGNATURE_V2 ||
               signature==SB_STATE_SIGNATURE_V3) &&
              longCount>=0 && longCount<=SBL_MAX_CONSUMED &&
              shortCount>=0 && shortCount<=SBL_MAX_CONSUMED;
   if(valid)
   {
      for(int i=0;i<longCount;i++)
      {
         if(FileIsEnding(file)) { valid=false; break; }
         long key=FileReadLong(file);
         if(key<=0) { valid=false; break; }
         g_consumed.longKeys[g_consumed.longCount++]=key;
      }
   }
   if(valid)
   {
      for(int i=0;i<shortCount;i++)
      {
         if(FileIsEnding(file)) { valid=false; break; }
         long key=FileReadLong(file);
         if(key<=0) { valid=false; break; }
         g_consumed.shortKeys[g_consumed.shortCount++]=key;
      }
   }
   int loadedDayKey=0;
   double loadedDayRealized=0.0;
   int loadedRiskLevel=0;
   bool loadedDayLocked=false;
   if(valid && signature==SB_STATE_SIGNATURE_V3)
   {
      if(FileIsEnding(file)) valid=false;
      else loadedDayKey=(int)FileReadLong(file);
      if(valid && FileIsEnding(file)) valid=false;
      else if(valid) loadedDayRealized=FileReadDouble(file);
      if(valid && FileIsEnding(file)) valid=false;
      else if(valid) loadedRiskLevel=(int)FileReadLong(file);
      if(valid && FileIsEnding(file)) valid=false;
      else if(valid) loadedDayLocked=FileReadLong(file)!=0;

      if(valid && (loadedDayKey<0 || loadedRiskLevel<0 ||
                   loadedRiskLevel>2 || !MathIsValidNumber(loadedDayRealized)))
         valid=false;
   }
   FileClose(file);
   if(!valid)
   {
      SblResetRegistry(g_consumed);
      Print("ICT SB : etat persistant invalide, reinitialise");
      return;
   }
   if(signature==SB_STATE_SIGNATURE_V3)
   {
      g_currentNyDayKey=loadedDayKey;
      g_dayRealized=loadedDayRealized;
      g_riskLevel=loadedRiskLevel;
      g_dayLocked=loadedDayLocked;
   }
}

void SaveConsumedRegistry()
{
   if(!g_initialized || (bool)MQLInfoInteger(MQL_TESTER)) return;
   string finalName=RegistryFileName();
   string temporaryName=finalName+".tmp";
   int file=FileOpen(temporaryName,FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(file==INVALID_HANDLE)
   {
      if(InpVerbose) Print("ICT SB : sauvegarde registre impossible err=",GetLastError());
      return;
   }

   FileWriteLong(file,SB_STATE_SIGNATURE_V3);
   FileWriteLong(file,g_consumed.longCount);
   FileWriteLong(file,g_consumed.shortCount);
   for(int i=0;i<g_consumed.longCount;i++)
      FileWriteLong(file,g_consumed.longKeys[i]);
   for(int i=0;i<g_consumed.shortCount;i++)
      FileWriteLong(file,g_consumed.shortKeys[i]);
   FileWriteLong(file,g_currentNyDayKey);
   FileWriteDouble(file,g_dayRealized);
   FileWriteLong(file,g_riskLevel);
   FileWriteLong(file,g_dayLocked ? 1 : 0);
   FileFlush(file);
   FileClose(file);

   if(!FileMove(temporaryName,FILE_COMMON,finalName,
                FILE_COMMON|FILE_REWRITE) && InpVerbose)
      Print("ICT SB : remplacement registre impossible err=",GetLastError());
}

bool ConsumeLiquidity(int direction,long key)
{
   bool added=SblRegistryConsume(g_consumed,direction,key);
   if(added) SaveConsumedRegistry();
   return added;
}

int UnmanagedSymbolPositionCount()
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic &&
         PositionGetString(POSITION_SYMBOL)==_Symbol)
         count++;
   }
   return count;
}

int ActiveMagicSymbolOrderCount()
{
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0) continue;
      if(OrderGetInteger(ORDER_MAGIC)==InpMagic &&
         OrderGetString(ORDER_SYMBOL)==_Symbol)
         count++;
   }
   return count;
}

bool CurrentPositionIsTracked(ulong ticket,ulong identifier,
                              const string comment)
{
   for(int i=0;i<ArraySize(g_setups);i++)
   {
      if(!g_setups[i].entered) continue;
      if((g_setups[i].positionTicket>0 &&
          g_setups[i].positionTicket==ticket) ||
         (g_setups[i].positionIdentifier>0 &&
          g_setups[i].positionIdentifier==identifier) ||
         comment=="SB"+IntegerToString(g_setups[i].logic.id))
         return true;
   }
   return false;
}

int UntrackedMagicSymbolPositionCount()
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetInteger(POSITION_MAGIC)!=InpMagic ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      ulong identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string comment=PositionGetString(POSITION_COMMENT);
      if(!CurrentPositionIsTracked(ticket,identifier,comment)) count++;
   }
   return count;
}

bool CurrentOrderIsTracked(ulong ticket)
{
   for(int i=0;i<ArraySize(g_setups);i++)
   {
      if(!g_setups[i].entered) continue;
      if(g_setups[i].entryOrder==ticket ||
         g_setups[i].partialOrder==ticket ||
         g_setups[i].closeOrder==ticket ||
         g_setups[i].modifyOrder==ticket)
         return true;
   }
   return false;
}

int UntrackedMagicSymbolOrderCount()
{
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || OrderGetInteger(ORDER_MAGIC)!=InpMagic ||
         OrderGetString(ORDER_SYMBOL)!=_Symbol)
         continue;
      if(!CurrentOrderIsTracked(ticket)) count++;
   }
   return count;
}

int OnInit()
{
   if(!InputsAreValid())
   {
      Print("ICT SB : parametres invalides");
      return INIT_PARAMETERS_INCORRECT;
   }
   if((bool)MQLInfoInteger(MQL_TESTER) &&
      InpBrokerTimeMode==SB_BROKER_AUTO_LIVE)
   {
      Print("ICT SB : AUTO_LIVE interdit en Strategy Tester. Choisir FIXED ou EUROPE_DST et renseigner InpBrokerGmtHours.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpBrokerTimeMode==SB_BROKER_AUTO_LIVE)
      Print("ICT SB : AUTO_LIVE utilise l'offset broker actuel ; choisir FIXED ou EUROPE_DST pour toute lecture historique.");

   hExecF = iMA(_Symbol, PERIOD_CURRENT, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hExecS = iMA(_Symbol, PERIOD_CURRENT, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hHtfF  = iMA(_Symbol, InpHtfTF,   InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hHtfS  = iMA(_Symbol, InpHtfTF,   InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hC1F   = iMA(_Symbol, InpConf1TF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hC1S   = iMA(_Symbol, InpConf1TF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hC2F   = iMA(_Symbol, InpConf2TF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hC2S   = iMA(_Symbol, InpConf2TF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hD1F   = iMA(_Symbol, PERIOD_D1, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hD1S   = iMA(_Symbol, PERIOD_D1, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);

   if(hExecF==INVALID_HANDLE || hExecS==INVALID_HANDLE ||
      hHtfF==INVALID_HANDLE  || hHtfS==INVALID_HANDLE  ||
      hC1F==INVALID_HANDLE   || hC1S==INVALID_HANDLE   ||
      hC2F==INVALID_HANDLE   || hC2S==INVALID_HANDLE   ||
      hD1F==INVALID_HANDLE   || hD1S==INVALID_HANDLE)
   {
      Print("ICT SB : erreur creation des handles EMA");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);

   // Les commentaires broker portent l'identifiant du setup. Un germe mele
   // temps, instance de graphique et compte evite qu'un redemarrage reutilise
   // immediatement un ancien commentaire encore present dans l'historique.
   ulong sequenceSeed=(ulong)TimeLocal();
   sequenceSeed^=GetMicrosecondCount();
   sequenceSeed^=(ulong)ChartID();
   sequenceSeed^=(ulong)AccountInfoInteger(ACCOUNT_LOGIN);
   g_sequence=(int)(sequenceSeed%2000000000);
   if(g_sequence<=0) g_sequence=1;

   LoadConsumedRegistry();

   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=
      ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("ICT SB : compte HEDGING obligatoire pour isoler les setups et leurs sorties partielles.");
      return INIT_FAILED;
   }

   g_initialized=true;
   g_recoveryBlocked=UnmanagedSymbolPositionCount()>0 ||
                     ActiveMagicSymbolOrderCount()>0;
   g_lastBarOpen=iTime(_Symbol,PERIOD_CURRENT,0);
   if(g_recoveryBlocked)
      Print("ICT SB : position ou ordre existant non reconstructible ; nouvelles entrees bloquees jusqu'a sa resolution (protections broker conservees).");
   Print("ICT_SilverBullet_Strategy v2 initialise sur ",_Symbol,
         " (exec ",EnumToString((ENUM_TIMEFRAMES)_Period),")");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   SaveConsumedRegistry();
   IndicatorRelease(hExecF); IndicatorRelease(hExecS);
   IndicatorRelease(hHtfF);  IndicatorRelease(hHtfS);
   IndicatorRelease(hC1F);   IndicatorRelease(hC1S);
   IndicatorRelease(hC2F);   IndicatorRelease(hC2S);
   IndicatorRelease(hD1F);   IndicatorRelease(hD1S);
}

//====================== TEMPS BROKER / UTC / NEW YORK ======================
int AutoBrokerOffsetSeconds()
{
   datetime server=TimeTradeServer();
   if(server<=0) server=TimeCurrent();
   datetime utc=TimeGMT();
   if(server<=0 || utc<=0) return InpBrokerGmtHours*3600;
   double quarterHours=MathRound((double)(server-utc)/900.0);
   return (int)quarterHours*900;
}

int HistoricalBrokerOffsetSeconds(datetime serverTime)
{
   if(InpBrokerTimeMode==SB_BROKER_AUTO_LIVE)
      return AutoBrokerOffsetSeconds();
   if(InpBrokerTimeMode==SB_BROKER_FIXED)
      return InpBrokerGmtHours*3600;

   datetime utcCandidate=serverTime-InpBrokerGmtHours*3600;
   MqlDateTime fields;
   ZeroMemory(fields);
   TimeToStruct(utcCandidate,fields);
   return SblBrokerUtcOffsetSeconds(SBL_BROKER_DST_EUROPE,
                                    InpBrokerGmtHours,
                                    fields.mon,fields.day,
                                    fields.hour*60+fields.min,
                                    fields.day_of_week);
}

datetime ServerToUtc(datetime serverTime)
{
   int offset=HistoricalBrokerOffsetSeconds(serverTime);
   datetime utc=serverTime-offset;

   // Une seconde passe resout correctement le candidat GMT+2/+3.
   if(InpBrokerTimeMode==SB_BROKER_EUROPE_DST)
   {
      MqlDateTime fields;
      ZeroMemory(fields);
      TimeToStruct(utc,fields);
      offset=SblBrokerUtcOffsetSeconds(SBL_BROKER_DST_EUROPE,
                                       InpBrokerGmtHours,
                                       fields.mon,fields.day,
                                       fields.hour*60+fields.min,
                                       fields.day_of_week);
      utc=serverTime-offset;
   }
   return utc;
}

datetime ServerToNewYork(datetime serverTime)
{
   datetime utc=ServerToUtc(serverTime);
   MqlDateTime fields;
   ZeroMemory(fields);
   TimeToStruct(utc,fields);
   int offset=SblNewYorkUtcOffsetSeconds(fields.mon,fields.day,
                                         fields.hour*60+fields.min,
                                         fields.day_of_week,
                                         InpAutoDST,
                                         InpManualGMTOffset);
   return utc+offset;
}

long EntryWindowKey(datetime decisionServerTime)
{
   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(ServerToNewYork(decisionServerTime),ny);
   int minuteOfDay=ny.hour*60+ny.min;
   if(!SblInEntryWindowMinutes(minuteOfDay)) return 0;
   int dayKey=ny.year*10000+ny.mon*100+ny.day;
   return SblEntryWindowKey(dayKey,minuteOfDay);
}

bool InEntryWindow(datetime decisionServerTime)
{
   return EntryWindowKey(decisionServerTime)>0;
}

long CurrentExecutableWindowKey()
{
   MqlTick quote;
   ZeroMemory(quote);
   datetime executableTime=0;
   if(SymbolInfoTick(_Symbol,quote) && quote.time>0)
      executableTime=(datetime)quote.time;
   if(executableTime<=0) executableTime=TimeTradeServer();
   if(executableTime<=0) executableTime=TimeCurrent();
   return executableTime>0 ? EntryWindowKey(executableTime) : 0;
}

int NewYorkDayKey(datetime serverTime)
{
   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(ServerToNewYork(serverTime),ny);
   return ny.year*10000+ny.mon*100+ny.day;
}

void UpdateTradingDay(datetime serverTime)
{
   if(serverTime<=0) return;
   int key=NewYorkDayKey(serverTime);
   if(key!=g_currentNyDayKey)
   {
      g_currentNyDayKey=key;
      g_dayRealized=0.0;
      g_dayLocked=false;
      SaveConsumedRegistry();
   }
}

//====================== DONNEES DE MARCHE ======================
double TickSize()
{
   double value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return value>0.0 ? value : _Point;
}

double NormalizePrice(double price)
{
   double tick=TickSize();
   if(tick<=0.0) return NormalizeDouble(price,_Digits);
   return NormalizeDouble(MathRound(price/tick)*tick,_Digits);
}

double EquityBase()
{
   return InpUseAccountEquity ? AccountInfoDouble(ACCOUNT_EQUITY)
                              : InpAccountSize;
}

double EffectiveRiskPct()
{
   if(g_riskLevel<=0) return InpRiskPct;
   if(g_riskLevel==1) return InpRiskAfterLossPct;
   return InpRiskUntilWinPct;
}

double SymbolMinimumLots()
{
   return SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
}

double VolumeFloor(double lots)
{
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step<=0.0 || maximum<=0.0 || lots<=0.0) return 0.0;
   double result=MathFloor((lots+1e-12)/step)*step;
   if(result>maximum) result=maximum;
   return NormalizeDouble(result,8);
}

double RiskBasedLots(int direction,double entry,double stop)
{
   double oneLotPnl=0.0;
   ENUM_ORDER_TYPE type=direction==SBL_LONG ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(type,_Symbol,1.0,entry,stop,oneLotPnl))
      return 0.0;
   double lossPerLot=MathAbs(oneLotPnl);
   if(lossPerLot<=0.0) return 0.0;

   double raw=EquityBase()*EffectiveRiskPct()/100.0/lossPerLot;
   double lots=VolumeFloor(raw);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double required=MathMax(SymbolMinimumLots(),InpMinLots);
   if(step>0.0) required=MathCeil((required-1e-12)/step)*step;

   // Ne jamais forcer le minimum si cela depasse le risque calcule.
   if(lots+1e-9<required) return 0.0;
   return lots;
}

int ClosedShiftAtTime(ENUM_TIMEFRAMES timeframe,datetime decisionTime)
{
   int shift=iBarShift(_Symbol,timeframe,decisionTime,false);
   if(shift<0) return -1;
   datetime barOpen=iTime(_Symbol,timeframe,shift);
   int duration=PeriodSeconds(timeframe);
   if(barOpen>0 && barOpen+duration<=decisionTime) return shift;
   return shift+1;
}

bool ReadStackAtTime(int fastHandle,int slowHandle,
                     ENUM_TIMEFRAMES timeframe,datetime decisionTime,
                     int &bias)
{
   int shift=ClosedShiftAtTime(timeframe,decisionTime);
   if(shift<0) return false;
   double fast[1],slow[1];
   if(CopyBuffer(fastHandle,0,shift,1,fast)!=1 ||
      CopyBuffer(slowHandle,0,shift,1,slow)!=1)
      return false;
   double closePrice=iClose(_Symbol,timeframe,shift);
   if(closePrice<=0.0) return false;
   bias=SblStrictStack(closePrice,fast[0],slow[0]);
   return true;
}

bool ReadAlignedBias(datetime decisionTime,int &aligned)
{
   int d1=0,h1=0,c1=0,c2=0;
   if(!ReadStackAtTime(hD1F,hD1S,PERIOD_D1,decisionTime,d1) ||
      !ReadStackAtTime(hHtfF,hHtfS,InpHtfTF,decisionTime,h1) ||
      !ReadStackAtTime(hC1F,hC1S,InpConf1TF,decisionTime,c1) ||
      !ReadStackAtTime(hC2F,hC2S,InpConf2TF,decisionTime,c2))
      return false;

   g_biasD1=d1; g_biasHtf=h1; g_biasC1=c1; g_biasC2=c2;
   aligned=SblAlignedBias(d1,h1,c1,c2);
   return true;
}

bool ReadExecEmaFast(int shift,double &value)
{
   double buffer[1];
   if(shift<1 || CopyBuffer(hExecF,0,shift,1,buffer)!=1) return false;
   value=buffer[0];
   return value>0.0;
}

bool BuildClosedBar(int shift,int index,SblBar &bar)
{
   if(shift<1) return false;
   datetime openTime=iTime(_Symbol,_Period,shift);
   int duration=PeriodSeconds(PERIOD_CURRENT);
   if(openTime<=0 || duration<=0) return false;
   datetime closeTime=openTime+duration;
   bar.time=(long)closeTime;              // timestamp de decision = cloture
   bar.index=index;
   bar.open=iOpen(_Symbol,_Period,shift);
   bar.high=iHigh(_Symbol,_Period,shift);
   bar.low=iLow(_Symbol,_Period,shift);
   bar.close=iClose(_Symbol,_Period,shift);
   bar.emaFast=0.0;
   bar.previousClose=iClose(_Symbol,_Period,shift+1);
   bar.windowKey=EntryWindowKey(closeTime);
   return bar.high>0.0 && bar.low>0.0 && bar.high>=bar.low &&
          bar.previousClose>0.0;
}

void UpdateReferenceSwings(const SblPivot &highPivot,
                           const SblPivot &lowPivot)
{
   if(highPivot.present && highPivot.direction==SBL_LONG &&
      highPivot.pivotTime>g_lastSwingHighTime)
   {
      g_lastSwingHigh=highPivot.price;
      g_lastSwingHighTime=(datetime)highPivot.pivotTime;
      g_lastSwingHighConfirmBar=highPivot.confirmedBar;
      g_haveSwingHigh=true;
   }
   if(lowPivot.present && lowPivot.direction==SBL_SHORT &&
      lowPivot.pivotTime>g_lastSwingLowTime)
   {
      g_lastSwingLow=lowPivot.price;
      g_lastSwingLowTime=(datetime)lowPivot.pivotTime;
      g_lastSwingLowConfirmBar=lowPivot.confirmedBar;
      g_haveSwingLow=true;
   }
}

void BuildLogicConfig(SblConfig &config)
{
   config.minDisplacement=InpMinDispTicks*TickSize();
   config.minFvgSize=InpMinFvgTicks*TickSize();
   config.oteLow=InpOteLow;
   config.oteHigh=InpOteHigh;
   config.expiryBars=InpSetupExpiry;
   config.requireWindow=true;
   config.useFvgTrigger=InpUseFVG;
   config.useOteTrigger=InpUseOTE;
   config.useEmaTrigger=InpUseEmaRetest;
}

//====================== SETUPS ======================
void ResetStrategySetup(StrategySetup &setup)
{
   SblResetSetup(setup.logic);
   setup.entered=false;
   setup.entryPending=false;
   setup.entryOrder=0;
   setup.entryRequestId=0;
   setup.entryPendingSince=0;
   setup.entryRequestTimeMsc=0;
   setup.requestedLots=0.0;
   setup.entryRejected=false;
   setup.entryCancelPending=false;
   setup.entryCancelCompletionKnown=false;
   setup.entryCancelRequestId=0;
   setup.entryCancelPendingSince=0;
   setup.entryCancelRejected=false;
   setup.entryDeal=0;
   setup.positionIdentifier=0;
   setup.positionTicket=0;
   setup.entryPx=0.0;
   setup.sl=0.0;
   setup.tp1=0.0;
   setup.tpFinal=0.0;
   setup.riskDistance=0.0;
   setup.totalLots=0.0;
   setup.coreLots=0.0;
   setup.coreTaken=false;
   setup.tp1Confirmed=false;
   setup.partialPending=false;
   setup.partialCompletionKnown=false;
   setup.partialOrder=0;
   setup.partialRequestId=0;
   setup.partialPendingSince=0;
   setup.partialRejected=false;
   setup.partialBeforeVolume=0.0;
   setup.closePending=false;
   setup.closeCompletionKnown=false;
   setup.closeOrder=0;
   setup.closeRequestId=0;
   setup.closePendingSince=0;
   setup.closeRejected=false;
   setup.closeBeforeVolume=0.0;
   setup.modifyPending=false;
   setup.modifyCompletionKnown=false;
   setup.modifyOrder=0;
   setup.modifyRequestId=0;
   setup.modifyPendingSince=0;
   setup.modifyRejected=false;
   setup.modifyStop=0.0;
   setup.modifyTakeProfit=0.0;
   setup.modifyPurpose=SB_MODIFY_NONE;
   setup.beDone=false;
   setup.forceClose=false;
   setup.highSinceEntry=0.0;
   setup.lowSinceEntry=0.0;
   setup.runnerStop=0.0;
   setup.triggerName="";
}

void RemoveSetup(int index)
{
   int count=ArraySize(g_setups);
   for(int i=index;i<count-1;i++) g_setups[i]=g_setups[i+1];
   ArrayResize(g_setups,count-1);
}

int PendingSetupCount()
{
   int count=0;
   for(int i=0;i<ArraySize(g_setups);i++)
      if(!g_setups[i].entered &&
         g_setups[i].logic.phase!=SBL_PHASE_INVALID &&
         g_setups[i].logic.phase!=SBL_PHASE_INACTIVE)
         count++;
   return count;
}

int PendingEntryRequestCount()
{
   int count=0;
   for(int i=0;i<ArraySize(g_setups);i++)
      if(g_setups[i].entered && g_setups[i].entryPending)
         count++;
   return count;
}

int OpenTradeCount()
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic) count++;
   }
   return count;
}

bool HasSetupForLiquidity(int direction,long initialKey,long targetKey)
{
   for(int i=0;i<ArraySize(g_setups);i++)
   {
      if(g_setups[i].entered || g_setups[i].logic.direction!=direction)
         continue;
      long setupInitial=direction==SBL_LONG
                        ? g_setups[i].logic.refLowTime
                        : g_setups[i].logic.refHighTime;
      long setupTarget=direction==SBL_LONG
                       ? g_setups[i].logic.refHighTime
                       : g_setups[i].logic.refLowTime;
      if(setupInitial==initialKey || setupTarget==targetKey)
         return true;
   }
   return false;
}

bool DirectionAllowed(int direction)
{
   if(direction==SBL_LONG) return InpTradeDir!=SB_SHORTONLY;
   if(direction==SBL_SHORT) return InpTradeDir!=SB_LONGONLY;
   return false;
}

bool CreateSetupAfterPurge(int direction,const SblBar &bar)
{
   long initialKey=direction==SBL_LONG
                   ? (long)g_lastSwingLowTime
                   : (long)g_lastSwingHighTime;
   long targetKey=direction==SBL_LONG
                  ? (long)g_lastSwingHighTime
                  : (long)g_lastSwingLowTime;

   if(initialKey<=0 || targetKey<=0 ||
      SblRegistryContains(g_consumed,direction,initialKey) ||
      SblRegistryContains(g_consumed,direction,targetKey) ||
      HasSetupForLiquidity(direction,initialKey,targetKey))
      return false;

   StrategySetup candidate;
   ResetStrategySetup(candidate);
   SblDecision startDecision;
   bool started=SblStartSetup(candidate.logic,++g_sequence,direction,bar,
                              g_lastSwingHigh,(long)g_lastSwingHighTime,
                              g_lastSwingLow,(long)g_lastSwingLowTime,
                              startDecision);
   if(startDecision.consumeTarget && startDecision.targetKey>0)
      ConsumeLiquidity(startDecision.direction,startDecision.targetKey);
   if(!started)
      return false;

   if(!ConsumeLiquidity(direction,initialKey))
      return false;
   int count=ArraySize(g_setups);
   ArrayResize(g_setups,count+1);
   g_setups[count]=candidate;

   if(InpVerbose)
      PrintFormat("ICT SB : setup #%d %s, purge=%.5f refLow=%.5f refHigh=%.5f",
                  candidate.logic.id,direction==SBL_LONG?"LONG":"SHORT",
                  candidate.logic.fib0,candidate.logic.refLow,
                  candidate.logic.refHigh);
   return true;
}

string TriggerName(int trigger)
{
   if(trigger==SBL_TRIGGER_FVG) return "FVG";
   if(trigger==SBL_TRIGGER_OTE) return "OTE";
   if(trigger==SBL_TRIGGER_EMA) return "RetestEMA";
   return "Unknown";
}

//====================== EXECUTION BROKER ======================
bool IsTradeRetcodeSuccessful(bool allowNoChanges=false)
{
   uint code=trade.ResultRetcode();
   return code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL ||
          (allowNoChanges && code==TRADE_RETCODE_NO_CHANGES);
}

bool IsTradeRetcodePending(uint code)
{
   return code==TRADE_RETCODE_PLACED ||
          code==TRADE_RETCODE_TIMEOUT ||
          code==TRADE_RETCODE_LOCKED ||
          code==TRADE_RETCODE_DONE_PARTIAL;
}

bool IsTradeRetcodeDefinitiveFailure(uint code)
{
   if(code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL ||
      IsTradeRetcodePending(code))
      return false;
   return code!=0;
}

bool BrokerReconcileExpired(datetime started)
{
   if(started<=0) return false;
   datetime now=TimeTradeServer();
   if(now<=0) now=TimeCurrent();
   return now>started && now-started>=InpBrokerReconcileSeconds;
}

bool ActiveOrderExists(ulong ticket)
{
   return ticket>0 && OrderSelect(ticket);
}

bool HistoricalOrderRejected(ulong ticket)
{
   if(ticket==0 || !HistoryOrderSelect(ticket)) return false;
   ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(
      ticket,ORDER_STATE);
   return state==ORDER_STATE_CANCELED || state==ORDER_STATE_REJECTED ||
          state==ORDER_STATE_EXPIRED;
}

bool HistoricalOrderExecutionFinished(ulong ticket)
{
   if(ticket==0 || !HistoryOrderSelect(ticket)) return false;
   ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(
      ticket,ORDER_STATE);
   return state==ORDER_STATE_FILLED || state==ORDER_STATE_CANCELED ||
          state==ORDER_STATE_REJECTED || state==ORDER_STATE_EXPIRED;
}

bool FindEntryDealByIdentity(StrategySetup &setup)
{
   datetime now=TimeTradeServer();
   if(now<=0) now=TimeCurrent();
   datetime from=setup.entryRequestTimeMsc>0
                 ? (datetime)(setup.entryRequestTimeMsc/1000)
                 : setup.entryPendingSince;
   if(now<=0 || !HistorySelect(from,now+60)) return false;

   string expectedComment="SB"+IntegerToString(setup.logic.id);
   for(int i=HistoryDealsTotal()-1;i>=0;i--)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0 ||
         HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic ||
         HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol ||
         HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN ||
         (datetime)HistoryDealGetInteger(deal,DEAL_TIME)<from)
         continue;

      ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
      string comment=HistoryDealGetString(deal,DEAL_COMMENT);
      if(setup.entryOrder>0)
      {
         // Une fois le ticket d'ordre connu, lui seul fait foi. Le commentaire
         // ne doit jamais permettre d'adopter le deal d'une ancienne instance.
         if(order!=setup.entryOrder) continue;
      }
      else
      {
         long dealTimeMsc=HistoryDealGetInteger(deal,DEAL_TIME_MSC);
         ENUM_DEAL_TYPE expectedType=setup.logic.direction==SBL_LONG
                                     ? DEAL_TYPE_BUY : DEAL_TYPE_SELL;
         ENUM_DEAL_TYPE dealType=(ENUM_DEAL_TYPE)HistoryDealGetInteger(
            deal,DEAL_TYPE);
         double dealVolume=HistoryDealGetDouble(deal,DEAL_VOLUME);
         double volumeTolerance=MathMax(
            1e-8,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)*0.5);
         if(setup.entryRequestTimeMsc<=0 ||
            dealTimeMsc<setup.entryRequestTimeMsc ||
            dealType!=expectedType || dealVolume<=0.0 ||
            setup.requestedLots<=0.0 ||
            dealVolume>setup.requestedLots+volumeTolerance ||
            comment!=expectedComment)
            continue;
      }

      setup.entryDeal=deal;
      setup.positionIdentifier=
         (ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      return setup.positionIdentifier>0;
   }
   return false;
}

bool FindPositionByIdentifier(ulong identifier,ulong &ticket)
{
   if(identifier==0) return false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong current=PositionGetTicket(i);
      if(current==0) continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==identifier &&
         PositionGetInteger(POSITION_MAGIC)==InpMagic)
      {
         ticket=current;
         return true;
      }
   }
   return false;
}

bool FindPositionByComment(const string comment,ulong &ticket,
                           ulong &identifier)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong current=PositionGetTicket(i);
      if(current==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic &&
         PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetString(POSITION_COMMENT)==comment)
      {
         ticket=current;
         identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
         return true;
      }
   }
   return false;
}

bool SelectSetupPosition(StrategySetup &setup)
{
   if(setup.positionTicket>0 && PositionSelectByTicket(setup.positionTicket))
      return true;
   ulong ticket=0;
   if(FindPositionByIdentifier(setup.positionIdentifier,ticket))
   {
      setup.positionTicket=ticket;
      return PositionSelectByTicket(ticket);
   }
   ulong identifier=setup.positionIdentifier;
   string comment="SB"+IntegerToString(setup.logic.id);
   if(FindPositionByComment(comment,ticket,identifier))
   {
      setup.positionTicket=ticket;
      setup.positionIdentifier=identifier;
      return PositionSelectByTicket(ticket);
   }
   return false;
}

bool BrokerProtectionMatches(int direction,double stop,double takeProfit)
{
   double tolerance=MathMax(_Point*0.5,TickSize()*0.5);
   double brokerStop=PositionGetDouble(POSITION_SL);
   double brokerTakeProfit=PositionGetDouble(POSITION_TP);
   bool stopProtects=brokerStop>0.0 &&
      (direction==SBL_LONG
       ? brokerStop>=stop-tolerance
       : brokerStop<=stop+tolerance);
   return stopProtects &&
          MathAbs(brokerTakeProfit-takeProfit)<=tolerance;
}

void ApplyConfirmedModification(StrategySetup &setup,int purpose,
                                double stop)
{
   if(purpose==SB_MODIFY_BREAK_EVEN)
      setup.beDone=true;
   if(purpose==SB_MODIFY_PROTECTION ||
      purpose==SB_MODIFY_BREAK_EVEN || purpose==SB_MODIFY_TRAIL)
      setup.runnerStop=stop;
}

void ClearPendingModification(StrategySetup &setup)
{
   setup.modifyPending=false;
   setup.modifyCompletionKnown=false;
   setup.modifyOrder=0;
   setup.modifyRequestId=0;
   setup.modifyPendingSince=0;
   setup.modifyRejected=false;
   setup.modifyStop=0.0;
   setup.modifyTakeProfit=0.0;
   setup.modifyPurpose=SB_MODIFY_NONE;
}

bool ModifyPositionChecked(int setupIndex,double stop,double takeProfit,
                           int purpose)
{
   if(setupIndex<0 || setupIndex>=ArraySize(g_setups) ||
      g_setups[setupIndex].modifyPending)
      return false;
   if(!SelectSetupPosition(g_setups[setupIndex])) return false;

   double normalizedStop=NormalizePrice(stop);
   double normalizedTakeProfit=takeProfit>0.0
                               ? NormalizePrice(takeProfit) : 0.0;
   int direction=g_setups[setupIndex].logic.direction;
   double existingStop=PositionGetDouble(POSITION_SL);
   if(existingStop>0.0)
   {
      if(direction==SBL_LONG && existingStop>normalizedStop)
         normalizedStop=existingStop;
      else if(direction==SBL_SHORT && existingStop<normalizedStop)
         normalizedStop=existingStop;
   }
   if(BrokerProtectionMatches(direction,normalizedStop,
                              normalizedTakeProfit))
   {
      double confirmedStop=PositionGetDouble(POSITION_SL);
      ApplyConfirmedModification(g_setups[setupIndex],purpose,
                                 confirmedStop);
      return true;
   }

   bool sent=trade.PositionModify(g_setups[setupIndex].positionTicket,
                                  normalizedStop,
                                  normalizedTakeProfit);
   MqlTradeResult modifyResult;
   ZeroMemory(modifyResult);
   trade.Result(modifyResult);
   bool requestCompleted=sent &&
      (modifyResult.retcode==TRADE_RETCODE_DONE ||
       modifyResult.retcode==TRADE_RETCODE_NO_CHANGES);

   bool selected=SelectSetupPosition(g_setups[setupIndex]);
   bool confirmed=selected &&
                  BrokerProtectionMatches(direction,normalizedStop,
                                          normalizedTakeProfit);
   if(confirmed)
   {
      double confirmedStop=PositionGetDouble(POSITION_SL);
      ApplyConfirmedModification(g_setups[setupIndex],purpose,
                                 confirmedStop);
      return true;
   }

   bool mayStillComplete=requestCompleted ||
                         IsTradeRetcodePending(modifyResult.retcode) ||
                         modifyResult.order>0;
   if(mayStillComplete)
   {
      g_setups[setupIndex].modifyPending=true;
      g_setups[setupIndex].modifyCompletionKnown=requestCompleted;
      g_setups[setupIndex].modifyOrder=modifyResult.order;
      g_setups[setupIndex].modifyRequestId=modifyResult.request_id;
      datetime requestTime=TimeTradeServer();
      if(requestTime<=0) requestTime=TimeCurrent();
      g_setups[setupIndex].modifyPendingSince=requestTime;
      g_setups[setupIndex].modifyRejected=false;
      g_setups[setupIndex].modifyStop=normalizedStop;
      g_setups[setupIndex].modifyTakeProfit=normalizedTakeProfit;
      g_setups[setupIndex].modifyPurpose=purpose;
      return false;
   }

   if(InpVerbose)
   {
      PrintFormat("ICT SB : echec modification ticket %I64u ret=%u",
                  g_setups[setupIndex].positionTicket,
                  modifyResult.retcode);
   }
   return false;
}

bool EnterSetup(int index,const SblDecision &decision)
{
   StrategySetup setup=g_setups[index];
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote)) return false;

   double entry=setup.logic.direction==SBL_LONG ? quote.ask : quote.bid;
   if(entry<=0.0 ||
      !SblPriceInValueArea(setup.logic.direction,entry,
                           setup.logic.fib0,setup.logic.fib1))
      return false;

   double stop=setup.logic.direction==SBL_LONG
               ? setup.logic.fib0-InpSlBufferTicks*TickSize()
               : setup.logic.fib0+InpSlBufferTicks*TickSize();
   stop=NormalizePrice(stop);
   double risk=setup.logic.direction==SBL_LONG ? entry-stop : stop-entry;
   if(risk<TickSize()) return false;

   long stopLevelPoints=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(stopLevelPoints>0 && risk<stopLevelPoints*_Point) return false;

   double riskBudget=EquityBase()*EffectiveRiskPct()/100.0;
   double lots=RiskBasedLots(setup.logic.direction,entry,stop);
   if(lots<=0.0)
   {
      if(InpVerbose)
         PrintFormat("ICT SB : setup #%d refuse, lot risque sous le minimum",
                     setup.logic.id);
      return false;
   }

   double provisionalTp=setup.logic.direction==SBL_LONG
                         ? entry+InpFinalR*risk
                         : entry-InpFinalR*risk;
   string comment="SB"+IntegerToString(setup.logic.id);

   // Le signal appartient a une plage NY precise. La cotation effectivement
   // executable doit encore porter cette meme identite juste avant l'envoi.
   datetime executableTime=(datetime)quote.time;
   if(executableTime<=0) executableTime=TimeTradeServer();
   if(executableTime<=0) executableTime=TimeCurrent();
   long executableWindowKey=executableTime>0
                            ? EntryWindowKey(executableTime) : 0;
   if(executableWindowKey<=0 ||
      executableWindowKey!=setup.logic.windowKey)
      return false;

   setup.entryRequestTimeMsc=quote.time_msc>0
                             ? quote.time_msc
                             : (long)executableTime*1000;
   setup.requestedLots=lots;
   bool sent=setup.logic.direction==SBL_LONG
             ? trade.Buy(lots,_Symbol,0.0,stop,NormalizePrice(provisionalTp),comment)
             : trade.Sell(lots,_Symbol,0.0,stop,NormalizePrice(provisionalTp),comment);
   MqlTradeResult openResult;
   ZeroMemory(openResult);
   trade.Result(openResult);
   uint openRetcode=openResult.retcode;
   bool requestCompleted=sent && openRetcode==TRADE_RETCODE_DONE;
   bool requestPending=IsTradeRetcodePending(openRetcode);

   setup.entryOrder=openResult.order;
   setup.entryRequestId=openResult.request_id;
   setup.entryDeal=openResult.deal;
   // Prix d'execution confirme ; l'historique puis la moyenne de position
   // l'affinent si le broker a produit plusieurs deals.
   double fill=openResult.price;
   if(setup.entryDeal>0 && HistoryDealSelect(setup.entryDeal))
   {
      setup.positionIdentifier=
         (ulong)HistoryDealGetInteger(setup.entryDeal,DEAL_POSITION_ID);
      fill=HistoryDealGetDouble(setup.entryDeal,DEAL_PRICE);
   }

   bool positionFound=FindPositionByIdentifier(setup.positionIdentifier,
                                               setup.positionTicket);
   if(!positionFound)
   {
      ulong identifier=setup.positionIdentifier;
      positionFound=FindPositionByComment(comment,setup.positionTicket,
                                          identifier);
      setup.positionIdentifier=identifier;
   }

   // Un retour negatif ou incertain peut masquer une execution deja acceptee
   // par le serveur. Rechercher d'abord le deal/la position. Sans preuve
   // d'execution, invalider l'opportunite au lieu de la rearmer et de risquer
   // un second ordre sur une reponse broker tardive.
   bool executionFound=setup.entryDeal>0 || setup.entryOrder>0 ||
                       positionFound;
   bool mustReconcile=requestPending ||
                      (!requestCompleted && executionFound);
   if(mustReconcile)
   {
      // PLACED/timeout/DONE_PARTIAL : conserver une sentinelle jusqu'a ce que le
      // deal, la position ou un rejet historique soit observable. Elle bloque
      // la capacite et fermera toute execution tardive au lieu de la laisser
      // orpheline ou de renvoyer la meme decision.
      setup.entered=true;
      setup.entryPending=true;
      setup.entryPendingSince=TimeCurrent();
      setup.forceClose=true;
      setup.sl=stop;
      setup.triggerName=TriggerName(decision.trigger);
      g_setups[index]=setup;
      PrintFormat("ICT SB : ouverture setup #%d en attente de reconciliation ret=%u ordre=%I64u",
                  setup.logic.id,openRetcode,setup.entryOrder);
      return true;
   }
   if(!requestCompleted)
   {
      if(InpVerbose)
         PrintFormat("ICT SB : echec ouverture setup #%d ret=%u",
                     setup.logic.id,openRetcode);
      return false;
   }

   double actualVolume=0.0;
   if(setup.positionTicket>0 && PositionSelectByTicket(setup.positionTicket))
   {
      // POSITION_PRICE_OPEN est la moyenne ponderee de la position et doit
      // toujours primer sur ResultDeal() en cas de remplissage multiple.
      fill=PositionGetDouble(POSITION_PRICE_OPEN);
      actualVolume=PositionGetDouble(POSITION_VOLUME);
   }

   // Un ordre execute sans fill ou volume reconciliable ne peut pas etre gere.
   if(fill<=0.0 || actualVolume<=0.0)
   {
      setup.entered=true;
      setup.entryPending=true;
      setup.entryPendingSince=TimeCurrent();
      setup.forceClose=true;
      setup.triggerName=TriggerName(decision.trigger);
      g_setups[index]=setup;
      PrintFormat("ICT SB : setup #%d fill/volume introuvable, fermeture de securite",
                  setup.logic.id);
      return true;
   }

   setup.entered=true; // L'ordre a ete execute : ne jamais permettre un doublon.
   setup.entryPending=false;
   setup.entryPx=fill;
   setup.sl=stop;
   setup.riskDistance=setup.logic.direction==SBL_LONG ? fill-stop : stop-fill;
   setup.tp1=setup.logic.direction==SBL_LONG
             ? fill+InpTp1R*setup.riskDistance
             : fill-InpTp1R*setup.riskDistance;
   setup.tpFinal=setup.logic.direction==SBL_LONG
                 ? fill+InpFinalR*setup.riskDistance
                 : fill-InpFinalR*setup.riskDistance;
   setup.totalLots=actualVolume;
   setup.highSinceEntry=fill;
   setup.lowSinceEntry=fill;
   setup.runnerStop=stop;
   setup.triggerName=TriggerName(decision.trigger);

   double minimum=SymbolMinimumLots();
   double core=VolumeFloor(actualVolume*InpTp1Percent/100.0);
   if(core<minimum || actualVolume-core<minimum) core=0.0;
   setup.coreLots=core;
   setup.coreTaken=core<=0.0;
   setup.tp1Confirmed=false;
   setup.beDone=false;
   g_setups[index]=setup;

   double actualStopPnl=0.0;
   ENUM_ORDER_TYPE orderType=setup.logic.direction==SBL_LONG
                             ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   bool riskCalculated=OrderCalcProfit(orderType,_Symbol,actualVolume,
                                       fill,stop,actualStopPnl);
   double actualRisk=MathAbs(actualStopPnl);
   double riskTolerance=MathMax(0.01,riskBudget*1e-6);
   bool riskValid=riskCalculated &&
                  actualRisk<=riskBudget+riskTolerance;
   bool fillValid=setup.riskDistance>=TickSize() && riskValid &&
      SblPriceInValueArea(setup.logic.direction,fill,
                          setup.logic.fib0,setup.logic.fib1);
   bool protectionValid=false;
   if(fillValid && setup.positionTicket>0)
      protectionValid=ModifyPositionChecked(index,setup.sl,setup.tpFinal,
                                             SB_MODIFY_PROTECTION);
   bool protectionPending=g_setups[index].modifyPending;
   if(!fillValid || (!protectionValid && !protectionPending))
   {
      g_setups[index].forceClose=true;
      PrintFormat("ICT SB : setup #%d execution invalide, fermeture de securite",
                  setup.logic.id);
      return true;
   }

   if(InpVerbose)
      PrintFormat("ICT SB : %s #%d %s fill=%.5f SL=%.5f TP1=%.5f TPf=%.5f lots=%.2f",
                  setup.logic.direction==SBL_LONG?"LONG":"SHORT",
                  setup.logic.id,setup.triggerName,fill,setup.sl,
                  setup.tp1,setup.tpFinal,actualVolume);
   return true;
}

//====================== GESTION DES POSITIONS ======================
bool FinalizeSetup(int index)
{
   StrategySetup setup=g_setups[index];
   if(setup.positionIdentifier==0 && setup.entryDeal>0 &&
      HistoryDealSelect(setup.entryDeal))
   {
      setup.positionIdentifier=
         (ulong)HistoryDealGetInteger(setup.entryDeal,DEAL_POSITION_ID);
      g_setups[index].positionIdentifier=setup.positionIdentifier;
   }
   if(setup.positionIdentifier==0 ||
      !HistorySelectByPosition(setup.positionIdentifier))
      return false;

   double pnl=0.0;
   double enteredVolume=0.0;
   double exitedVolume=0.0;
   int deals=HistoryDealsTotal();
   if(deals<=0) return false;
   for(int i=0;i<deals;i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0) continue;
      long entryType=HistoryDealGetInteger(deal,DEAL_ENTRY);
      double dealVolume=HistoryDealGetDouble(deal,DEAL_VOLUME);
      if(entryType==DEAL_ENTRY_IN) enteredVolume+=dealVolume;
      else if(entryType==DEAL_ENTRY_OUT || entryType==DEAL_ENTRY_OUT_BY)
         exitedVolume+=dealVolume;
      pnl+=HistoryDealGetDouble(deal,DEAL_PROFIT)
          +HistoryDealGetDouble(deal,DEAL_SWAP)
          +HistoryDealGetDouble(deal,DEAL_COMMISSION)
          +HistoryDealGetDouble(deal,DEAL_FEE);
   }
   double volumeTolerance=
      MathMax(1e-8,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)*0.5);
   if(enteredVolume<=0.0 || exitedVolume+volumeTolerance<enteredVolume)
      return false;

   if(pnl>0.0) g_riskLevel=0;
   else if(pnl<0.0) g_riskLevel=MathMin(2,g_riskLevel+1);
   g_dayRealized+=pnl;
   double limit=EquityBase()*InpDailyDDPct/100.0;
   if(-g_dayRealized>=limit) g_dayLocked=true;
   SaveConsumedRegistry();

   if(InpVerbose)
      PrintFormat("ICT SB : setup #%d clos pnl=%.2f riskLevel=%d day=%.2f%s",
                  setup.logic.id,pnl,g_riskLevel,g_dayRealized,
                  g_dayLocked?" [VERROUILLE]":"");
   return true;
}

void ManageOpenPositionsEveryTick()
{
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote)) return;

   for(int i=ArraySize(g_setups)-1;i>=0;i--)
   {
      if(!g_setups[i].entered) continue;
      if(g_setups[i].entryPending)
         FindEntryDealByIdentity(g_setups[i]);
      bool selected=SelectSetupPosition(g_setups[i]);

      if(g_setups[i].entryPending && selected)
      {
         // Une execution tardive n'est jamais adoptee silencieusement : les
         // controles de fill/risque n'ont pas pu etre acheves, donc fermeture.
         g_setups[i].forceClose=true;
      }

      // Une modification de protection est confirmee exclusivement par les
      // valeurs de la position. Tant que son resultat reste ambigu, aucune
      // nouvelle modification, sortie partielle ou action de gestion normale
      // n'est envoyee.
      bool modificationResolvedThisTick=false;
      if(selected && g_setups[i].modifyPending)
      {
         double brokerStop=PositionGetDouble(POSITION_SL);
         double brokerTakeProfit=PositionGetDouble(POSITION_TP);
         double priceTolerance=MathMax(_Point*0.5,TickSize()*0.5);
         int modifyDirection=g_setups[i].logic.direction;
         bool stopProtects=brokerStop>0.0 &&
            (modifyDirection==SBL_LONG
             ? brokerStop>=g_setups[i].modifyStop-priceTolerance
             : brokerStop<=g_setups[i].modifyStop+priceTolerance);
         bool protectionApplied=stopProtects &&
            MathAbs(brokerTakeProfit-
                    g_setups[i].modifyTakeProfit)<=priceTolerance;
         bool rejected=g_setups[i].modifyRejected ||
                       HistoricalOrderRejected(g_setups[i].modifyOrder);
         bool finished=HistoricalOrderExecutionFinished(
            g_setups[i].modifyOrder);
         bool expired=BrokerReconcileExpired(
            g_setups[i].modifyPendingSince) &&
            !ActiveOrderExists(g_setups[i].modifyOrder);
         int purpose=g_setups[i].modifyPurpose;
         double confirmedStop=brokerStop;

         if(protectionApplied)
         {
            if(purpose==SB_MODIFY_BREAK_EVEN)
               g_setups[i].beDone=true;
            if(purpose==SB_MODIFY_PROTECTION ||
               purpose==SB_MODIFY_BREAK_EVEN ||
               purpose==SB_MODIFY_TRAIL)
               g_setups[i].runnerStop=confirmedStop;
            ClearPendingModification(g_setups[i]);
            modificationResolvedThisTick=true;
         }
         else if(rejected || finished || expired)
         {
            ClearPendingModification(g_setups[i]);
            modificationResolvedThisTick=true;
            if(purpose==SB_MODIFY_PROTECTION)
               g_setups[i].forceClose=true;
         }

         if(g_setups[i].modifyPending && !g_setups[i].forceClose)
            continue;
         if(modificationResolvedThisTick)
            continue;
      }

      // Un ordre d'entree partiellement rempli peut conserver un reliquat
      // actif. Son annulation est une operation propre, correlee et serialisee.
      // Aucune fermeture de securite ne part avant sa terminaison observable.
      bool entryRemainderReady=true;
      bool cancellationResolvedThisTick=false;
      bool cancelRequired=g_setups[i].entryCancelPending ||
         ((g_setups[i].entryPending || g_setups[i].forceClose) &&
          g_setups[i].entryOrder>0);
      if(cancelRequired)
      {
         bool entryOrderActive=ActiveOrderExists(g_setups[i].entryOrder);
         if(g_setups[i].entryCancelPending)
         {
            bool cancelFinished=HistoricalOrderExecutionFinished(
               g_setups[i].entryOrder);
            bool cancelExpired=BrokerReconcileExpired(
               g_setups[i].entryCancelPendingSince);
            bool cancelTerminal=!entryOrderActive &&
               (g_setups[i].entryCancelCompletionKnown ||
                cancelFinished || g_setups[i].entryCancelRejected ||
                cancelExpired);
            bool retryAllowed=g_setups[i].entryCancelRejected ||
                              cancelExpired;
            if(cancelTerminal || retryAllowed)
            {
               g_setups[i].entryCancelPending=false;
               g_setups[i].entryCancelCompletionKnown=false;
               g_setups[i].entryCancelRequestId=0;
               g_setups[i].entryCancelPendingSince=0;
               g_setups[i].entryCancelRejected=false;
               cancellationResolvedThisTick=true;
               entryRemainderReady=!entryOrderActive;
            }
            else
               entryRemainderReady=false;
         }

         if(!g_setups[i].entryCancelPending && entryOrderActive &&
            !cancellationResolvedThisTick)
         {
            bool cancelSent=trade.OrderDelete(g_setups[i].entryOrder);
            MqlTradeResult cancelResult;
            ZeroMemory(cancelResult);
            trade.Result(cancelResult);
            bool cancelDone=cancelSent &&
               (cancelResult.retcode==TRADE_RETCODE_DONE ||
                cancelResult.retcode==TRADE_RETCODE_NO_CHANGES);

            // Meme un rejet est conserve jusqu'au tick suivant : une seule
            // requete d'annulation peut donc exister par setup et par cycle.
            g_setups[i].entryCancelPending=true;
            g_setups[i].entryCancelCompletionKnown=cancelDone;
            g_setups[i].entryCancelRequestId=cancelResult.request_id;
            datetime cancelTime=TimeTradeServer();
            if(cancelTime<=0) cancelTime=TimeCurrent();
            g_setups[i].entryCancelPendingSince=cancelTime;
            g_setups[i].entryCancelRejected=
               !cancelDone &&
               IsTradeRetcodeDefinitiveFailure(cancelResult.retcode);
            entryRemainderReady=false;

            if(InpVerbose && g_setups[i].entryCancelRejected)
               PrintFormat("ICT SB : echec annulation reliquat #%d ret=%u",
                           g_setups[i].logic.id,cancelResult.retcode);
         }
         else if(entryOrderActive)
            entryRemainderReady=false;
      }
      if(!entryRemainderReady)
         continue;

      if(g_setups[i].entryPending)
      {
         if(!selected)
         {
            bool rejected=g_setups[i].entryRejected ||
                          HistoricalOrderRejected(g_setups[i].entryOrder);
            bool finished=HistoricalOrderExecutionFinished(
               g_setups[i].entryOrder);
            bool expired=BrokerReconcileExpired(
               g_setups[i].entryPendingSince) &&
               !ActiveOrderExists(g_setups[i].entryOrder);
            bool terminal=rejected || finished || expired;
            if(terminal && FinalizeSetup(i))
            {
               RemoveSetup(i);
               continue;
            }
            bool noExecutionIdentity=g_setups[i].entryDeal==0 &&
                                     g_setups[i].positionIdentifier==0;
            if((rejected || expired) && noExecutionIdentity)
            {
               PrintFormat("ICT SB : reconciliation entree #%d terminee sans execution",
                           g_setups[i].logic.id);
               RemoveSetup(i);
            }
            continue;
         }
      }

      if(!selected)
      {
         if(FinalizeSetup(i)) RemoveSetup(i);
         continue;
      }

      if(g_setups[i].forceClose)
      {
         double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
         double tolerance=MathMax(1e-8,step*0.5);
         double currentVolume=PositionGetDouble(POSITION_VOLUME);

         if(g_setups[i].closePending)
         {
            bool volumeChanged=
               currentVolume<g_setups[i].closeBeforeVolume-tolerance;
            bool rejected=g_setups[i].closeRejected ||
                          HistoricalOrderRejected(g_setups[i].closeOrder);
            bool finished=HistoricalOrderExecutionFinished(
               g_setups[i].closeOrder);
            bool expired=BrokerReconcileExpired(
               g_setups[i].closePendingSince) &&
               !ActiveOrderExists(g_setups[i].closeOrder);
            if(rejected || expired ||
               ((finished || g_setups[i].closeCompletionKnown) &&
                volumeChanged))
            {
               g_setups[i].closePending=false;
               g_setups[i].closeCompletionKnown=false;
               g_setups[i].closeOrder=0;
               g_setups[i].closeRequestId=0;
               g_setups[i].closePendingSince=0;
               g_setups[i].closeRejected=false;
               g_setups[i].closeBeforeVolume=0.0;
            }
            continue;
         }

         bool closeSent=trade.PositionClose(g_setups[i].positionTicket);
         MqlTradeResult closeResult;
         ZeroMemory(closeResult);
         trade.Result(closeResult);
         bool closeDone=closeSent &&
                        closeResult.retcode==TRADE_RETCODE_DONE;
         bool responsePending=IsTradeRetcodePending(closeResult.retcode);
         bool mayStillExecute=responsePending || closeResult.order>0 ||
                              closeDone;
         bool volumeConfirmed=SelectSetupPosition(g_setups[i]);
         double remaining=volumeConfirmed
                          ? PositionGetDouble(POSITION_VOLUME) : 0.0;
         bool volumeChanged=volumeConfirmed &&
                            remaining<currentVolume-tolerance;

         if(volumeConfirmed &&
            (responsePending || (mayStillExecute && !volumeChanged)))
         {
            g_setups[i].closePending=true;
            g_setups[i].closeCompletionKnown=closeDone;
            g_setups[i].closeOrder=closeResult.order;
            g_setups[i].closeRequestId=closeResult.request_id;
            g_setups[i].closePendingSince=TimeCurrent();
            g_setups[i].closeRejected=false;
            g_setups[i].closeBeforeVolume=currentVolume;
         }
         else if(!volumeConfirmed && mayStillExecute)
         {
            // La position peut deja etre fermee ; FinalizeSetup tranchera au
            // prochain tick sans qu'une seconde requete soit envoyee.
            g_setups[i].closePending=true;
            g_setups[i].closeCompletionKnown=closeDone;
            g_setups[i].closeOrder=closeResult.order;
            g_setups[i].closeRequestId=closeResult.request_id;
            g_setups[i].closePendingSince=TimeCurrent();
            g_setups[i].closeRejected=false;
            g_setups[i].closeBeforeVolume=currentVolume;
         }
         else if(!closeDone && !volumeChanged && InpVerbose)
            PrintFormat("ICT SB : echec fermeture securite #%d ret=%u",
                        g_setups[i].logic.id,closeResult.retcode);
         continue;
      }

      int direction=g_setups[i].logic.direction;
      double executable=direction==SBL_LONG ? quote.bid : quote.ask;
      g_setups[i].highSinceEntry=
         MathMax(g_setups[i].highSinceEntry,executable);
      g_setups[i].lowSinceEntry=
         MathMin(g_setups[i].lowSinceEntry,executable);

      bool tp1Reached=direction==SBL_LONG
                      ? executable>=g_setups[i].tp1
                      : executable<=g_setups[i].tp1;
      double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      double tolerance=MathMax(1e-8,step*0.5);
      double currentVolume=PositionGetDouble(POSITION_VOLUME);
      double targetRunner=g_setups[i].totalLots-g_setups[i].coreLots;

      // La reponse d'une sortie partielle reste a reconciler meme si le prix
      // est revenu sous TP1. Sa resolution ne peut jamais provoquer une
      // seconde cloture au cours du meme tick.
      if(g_setups[i].partialPending)
      {
         bool volumeChanged=
            currentVolume<g_setups[i].partialBeforeVolume-tolerance;
         bool rejected=g_setups[i].partialRejected ||
                       HistoricalOrderRejected(g_setups[i].partialOrder);
         bool finished=HistoricalOrderExecutionFinished(
            g_setups[i].partialOrder);
         bool expired=BrokerReconcileExpired(
            g_setups[i].partialPendingSince) &&
            !ActiveOrderExists(g_setups[i].partialOrder);
         bool executionTerminal=
            (finished || g_setups[i].partialCompletionKnown) &&
            volumeChanged;
         if(!rejected && !executionTerminal && !expired)
            continue;

         bool targetConfirmed=volumeChanged &&
                              currentVolume<=targetRunner+tolerance;
         if(targetConfirmed)
         {
            g_setups[i].coreTaken=true;
            g_setups[i].tp1Confirmed=true;
         }

         g_setups[i].partialPending=false;
         g_setups[i].partialCompletionKnown=false;
         g_setups[i].partialOrder=0;
         g_setups[i].partialRequestId=0;
         g_setups[i].partialPendingSince=0;
         g_setups[i].partialRejected=false;
         g_setups[i].partialBeforeVolume=0.0;
         continue;
      }

      if(tp1Reached && g_setups[i].coreTaken &&
         !g_setups[i].tp1Confirmed)
         g_setups[i].tp1Confirmed=true;

      if(tp1Reached && !g_setups[i].coreTaken)
      {

         double volumeToClose=VolumeFloor(currentVolume-targetRunner);

         if(currentVolume<=targetRunner+tolerance ||
            volumeToClose<tolerance)
         {
            g_setups[i].coreTaken=true;
            g_setups[i].tp1Confirmed=true;
         }
         else
         {
            bool closed=trade.PositionClosePartial(
               g_setups[i].positionTicket,volumeToClose);
            MqlTradeResult partialResult;
            ZeroMemory(partialResult);
            trade.Result(partialResult);
            uint partialRetcode=partialResult.retcode;
            ulong partialOrder=partialResult.order;
            bool requestDone=closed &&
                             partialRetcode==TRADE_RETCODE_DONE;
            bool requestPending=IsTradeRetcodePending(partialRetcode) ||
                                (!requestDone && partialOrder>0);

            bool volumeConfirmed=SelectSetupPosition(g_setups[i]);
            double remaining=volumeConfirmed
                             ? PositionGetDouble(POSITION_VOLUME) : 0.0;
            bool volumeChanged=volumeConfirmed &&
                               remaining<currentVolume-tolerance;
            if(requestPending || (requestDone && !volumeChanged))
            {
               // Ne jamais renvoyer une cloture dont l'effet n'est pas encore
               // visible. DONE_PARTIAL attend aussi un etat d'ordre terminal ;
               // PLACED/timeout attend l'historique ou le delai de securite.
               g_setups[i].partialPending=true;
               g_setups[i].partialCompletionKnown=
                  requestDone;
               g_setups[i].partialOrder=partialOrder;
               g_setups[i].partialRequestId=partialResult.request_id;
               g_setups[i].partialPendingSince=TimeCurrent();
               g_setups[i].partialRejected=false;
               g_setups[i].partialBeforeVolume=currentVolume;
            }
            else if(requestDone && volumeConfirmed &&
                    remaining<=targetRunner+tolerance)
            {
               g_setups[i].coreTaken=true;
               g_setups[i].tp1Confirmed=true;
            }
            else if(!requestDone && InpVerbose)
               PrintFormat("ICT SB : echec TP1 partiel #%d ret=%u",
                           g_setups[i].logic.id,partialRetcode);
         }
      }

      // Meme sans volume partiel, le reliquat passe a BE des que la prise du
      // core est confirmee ; un retour de prix sous TP1 ne doit pas le bloquer.
      if(g_setups[i].tp1Confirmed && g_setups[i].coreTaken &&
         !g_setups[i].beDone &&
         SelectSetupPosition(g_setups[i]))
      {
         double takeProfit=InpTrailRunner ? 0.0 : g_setups[i].tpFinal;
         ModifyPositionChecked(i,g_setups[i].entryPx,takeProfit,
                               SB_MODIFY_BREAK_EVEN);
         continue;
      }

      if(InpTrailRunner && g_setups[i].beDone &&
         SelectSetupPosition(g_setups[i]))
      {
         double trail=direction==SBL_LONG
                      ? g_setups[i].highSinceEntry-
                        InpTrailR*g_setups[i].riskDistance
                      : g_setups[i].lowSinceEntry+
                        InpTrailR*g_setups[i].riskDistance;
         bool improves=direction==SBL_LONG
                       ? trail>g_setups[i].runnerStop+TickSize()*0.5
                       : trail<g_setups[i].runnerStop-TickSize()*0.5;
         bool valid=direction==SBL_LONG ? trail<quote.bid : trail>quote.ask;
         if(improves && valid &&
            ModifyPositionChecked(i,trail,0.0,SB_MODIFY_TRAIL))
            continue;
      }
   }
}

//====================== TRAITEMENT D'UNE BOUGIE FERMEE ======================
bool ProcessClosedBar(int closedShift,datetime decisionTime,int nextBarIndex,
                      bool allowExecution,bool allowSetupCreation)
{
   if(closedShift<1 ||
      Bars(_Symbol,PERIOD_CURRENT)<InpEmaSlow+closedShift+7)
      return false;

   SblBar twoBefore,oneBefore,candidate,oneAfter,newest;
   if(!BuildClosedBar(closedShift+4,nextBarIndex-4,twoBefore) ||
      !BuildClosedBar(closedShift+3,nextBarIndex-3,oneBefore) ||
      !BuildClosedBar(closedShift+2,nextBarIndex-2,candidate) ||
      !BuildClosedBar(closedShift+1,nextBarIndex-1,oneAfter) ||
      !BuildClosedBar(closedShift,nextBarIndex,newest))
      return false;
   newest.time=(long)decisionTime;
   newest.previousClose=oneAfter.close;
   newest.windowKey=EntryWindowKey(decisionTime);
   if(!ReadExecEmaFast(closedShift,newest.emaFast)) return false;

   int alignedBias=0;
   if(!ReadAlignedBias(decisionTime,alignedBias)) return false;

   SblPivot highPivot,lowPivot;
   SblDetectInternalPivot(SBL_LONG,twoBefore,oneBefore,candidate,
                          oneAfter,newest,highPivot);
   SblDetectInternalPivot(SBL_SHORT,twoBefore,oneBefore,candidate,
                          oneAfter,newest,lowPivot);
   SblRejectAmbiguousDualPivot(highPivot,lowPivot);

   SblConfig config;
   BuildLogicConfig(config);
   SblFvg newFvg;
   SblDetectFvg(newest,candidate,config.minFvgSize,newFvg);
   bool inWindow=InEntryWindow(decisionTime) && newest.windowKey>0;

   for(int i=ArraySize(g_setups)-1;i>=0;i--)
   {
      if(g_setups[i].entered) continue;

      // Un trigger dont l'envoi a ete refuse au changement de plage reste
      // verrouille jusqu'a la prochaine cloture ; il ne peut alors qu'etre
      // rearme dans la meme plage ou invalide par la nouvelle identite.
      if(g_setups[i].logic.phase==SBL_PHASE_TRIGGERED)
      {
         if(!inWindow || newest.windowKey!=g_setups[i].logic.windowKey)
         {
            g_setups[i].logic.phase=SBL_PHASE_INVALID;
            RemoveSetup(i);
            continue;
         }
         g_setups[i].logic.phase=SBL_PHASE_WAIT_RETRACEMENT;
         g_setups[i].logic.trigger=SBL_TRIGGER_NONE;
         g_setups[i].logic.triggerBar=-1;
         g_setups[i].logic.triggerTime=0;
         g_setups[i].logic.expectedEntry=0.0;
      }

      SblPivot setupPivot;
      if(g_setups[i].logic.direction==SBL_LONG)
         setupPivot=highPivot;
      else
         setupPivot=lowPivot;

      SblDecision decision;
      bool signaled=SblAdvanceSetup(g_setups[i].logic,newest,
                                    alignedBias,setupPivot,newFvg,inWindow,
                                    config,decision);
      if(decision.consumeTarget && decision.targetKey>0)
         ConsumeLiquidity(decision.direction,decision.targetKey);

      if(g_dayLocked)
         g_setups[i].logic.phase=SBL_PHASE_INVALID;

      if(g_setups[i].logic.phase==SBL_PHASE_INVALID)
      {
         RemoveSetup(i);
         continue;
      }

      if(signaled)
      {
         // Une opportunite constatee pendant un rattrapage est deja perimee :
         // elle reconstruit l'historique, mais ne doit jamais trader au prix live.
         if(!allowExecution)
         {
            RemoveSetup(i);
            continue;
         }
         bool capacity=OpenTradeCount()+PendingEntryRequestCount()<
                       InpMaxPositions;
         if(capacity && EnterSetup(i,decision))
            continue;

         // Une requete broker non confirmee n'est jamais rejouee : elle peut
         // avoir ete executee tardivement malgre le retcode local.
         if(g_setups[i].logic.phase==SBL_PHASE_INVALID)
         {
            RemoveSetup(i);
            continue;
         }

         // Prix/capacite non valides : un nouveau retracement n'est permis que
         // tant que l'heure executable appartient encore a la meme plage.
         // Sinon le trigger reste verrouille et sera invalide a la cloture.
         if(CurrentExecutableWindowKey()!=g_setups[i].logic.windowKey)
            continue;
         g_setups[i].logic.phase=SBL_PHASE_WAIT_RETRACEMENT;
         g_setups[i].logic.trigger=SBL_TRIGGER_NONE;
         g_setups[i].logic.triggerBar=-1;
         g_setups[i].logic.triggerTime=0;
         g_setups[i].logic.expectedEntry=0.0;
      }
   }

   bool highAvailable=g_haveSwingHigh &&
                      nextBarIndex>g_lastSwingHighConfirmBar &&
                      (long)g_lastSwingHighTime<newest.time;
   bool lowAvailable=g_haveSwingLow &&
                     nextBarIndex>g_lastSwingLowConfirmBar &&
                     (long)g_lastSwingLowTime<newest.time;
   long highKey=(long)g_lastSwingHighTime;
   long lowKey=(long)g_lastSwingLowTime;
   bool rawHigh=highAvailable && newest.high>g_lastSwingHigh;
   bool rawLow=lowAvailable && newest.low<g_lastSwingLow;

   // Les cibles reservees sont consommees exclusivement via SblDecision.
   // Sans setup reserve, une meche ayant reellement traite la liquidite
   // externe la consomme tout de meme et interdit son recyclage ulterieur.
   if(rawHigh && !HasSetupForLiquidity(SBL_LONG,0,highKey))
      ConsumeLiquidity(SBL_LONG,highKey);
   if(rawLow && !HasSetupForLiquidity(SBL_SHORT,0,lowKey))
      ConsumeLiquidity(SBL_SHORT,lowKey);

   bool capacity=OpenTradeCount()+PendingSetupCount()+
                 PendingEntryRequestCount()<InpMaxPositions;
   bool longPurge=rawLow &&
                  SblPurgeReintegrated(SBL_LONG,newest,
                                       g_lastSwingHigh,g_lastSwingLow);
   bool shortPurge=rawHigh &&
                   SblPurgeReintegrated(SBL_SHORT,newest,
                                        g_lastSwingHigh,g_lastSwingLow);
   if(longPurge)
   {
      bool created=allowSetupCreation && inWindow && highAvailable &&
                   alignedBias==SBL_LONG &&
                   !g_dayLocked && capacity && DirectionAllowed(SBL_LONG) &&
                   CreateSetupAfterPurge(SBL_LONG,newest);
      if(InpVerbose && !created)
         Print("ICT SB : purge LONG ignoree (fenetre, biais, capacite ou liquidite)");
   }
   if(shortPurge)
   {
      capacity=OpenTradeCount()+PendingSetupCount()+
               PendingEntryRequestCount()<InpMaxPositions;
      bool created=allowSetupCreation && inWindow && lowAvailable &&
                   alignedBias==SBL_SHORT &&
                   !g_dayLocked && capacity && DirectionAllowed(SBL_SHORT) &&
                   CreateSetupAfterPurge(SBL_SHORT,newest);
      if(InpVerbose && !created)
         Print("ICT SB : purge SHORT ignoree (fenetre, biais, capacite ou liquidite)");
   }

   // Une origine balayee est consommee meme si la reintegration, le biais,
   // la fenetre ou la capacite ont empeche la creation. Apres un Start
   // reussi ces appels sont volontairement des no-op dans le registre.
   if(rawLow) ConsumeLiquidity(SBL_LONG,lowKey);
   if(rawHigh) ConsumeLiquidity(SBL_SHORT,highKey);

   // Un pivot confirme a cette cloture n'etait pas encore connaissable
   // pendant la bougie : il ne devient une reference externe qu'ensuite.
   // Le meme evenement a deja pu servir de pivot interne au core ci-dessus.
   UpdateReferenceSwings(highPivot,lowPivot);
   return true;
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime serverNow=TimeTradeServer();
   if(serverNow<=0) serverNow=TimeCurrent();
   UpdateTradingDay(serverNow);
   ManageOpenPositionsEveryTick();

   if(!g_recoveryBlocked &&
      (UntrackedMagicSymbolPositionCount()>0 ||
       UntrackedMagicSymbolOrderCount()>0))
   {
      g_recoveryBlocked=true;
      Print("ICT SB : execution broker non suivie detectee ; nouvelles entrees bloquees jusqu'a resolution.");
   }

   if(g_recoveryBlocked)
   {
      if(UnmanagedSymbolPositionCount()>0 ||
         ActiveMagicSymbolOrderCount()>0) return;
      g_recoveryBlocked=false;
      g_lastBarOpen=iTime(_Symbol,PERIOD_CURRENT,0);
      Print("ICT SB : exposition broker preexistante resolue ; detection reprise a la prochaine bougie.");
      return;
   }

   datetime currentBar=iTime(_Symbol,PERIOD_CURRENT,0);
   if(currentBar<=0 || currentBar==g_lastBarOpen) return;

   int firstClosedShift=1;
   if(g_lastBarOpen>0)
   {
      firstClosedShift=iBarShift(_Symbol,PERIOD_CURRENT,g_lastBarOpen,true);
      if(firstClosedShift<1)
      {
         for(int i=ArraySize(g_setups)-1;i>=0;i--)
            if(!g_setups[i].entered) RemoveSetup(i);
         g_lastBarOpen=currentBar;
         Print("ICT SB : historique de rattrapage indisponible, setups en attente annules");
         return;
      }
   }

   // Rejouer dans l'ordre toutes les bougies fermees pendant une coupure.
   for(int shift=firstClosedShift;shift>=1;shift--)
   {
      datetime closedBarOpen=iTime(_Symbol,PERIOD_CURRENT,shift);
      datetime nextBarOpen=iTime(_Symbol,PERIOD_CURRENT,shift-1);
      int periodSeconds=PeriodSeconds(PERIOD_CURRENT);
      if(closedBarOpen<=0 || nextBarOpen<=closedBarOpen || periodSeconds<=0)
         return;
      datetime decisionTime=closedBarOpen+periodSeconds;
      bool fresh=shift==1 && serverNow>=decisionTime &&
                 serverNow-decisionTime<=periodSeconds;
      bool currentTradingDay=NewYorkDayKey(decisionTime)==g_currentNyDayKey;
      int nextBarIndex=g_barIndex+1;
      if(!ProcessClosedBar(shift,decisionTime,nextBarIndex,fresh,
                           currentTradingDay)) return;
      g_barIndex=nextBarIndex;
      g_lastBarOpen=nextBarOpen;
   }
}

//+------------------------------------------------------------------+
//| Reconciliation des resultats recus apres le retour de CTrade     |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_REQUEST)
      return;

   for(int i=0;i<ArraySize(g_setups);i++)
   {
      bool entryCancelMatch=g_setups[i].entryCancelPending &&
         ((g_setups[i].entryCancelRequestId>0 &&
           g_setups[i].entryCancelRequestId==result.request_id) ||
          (g_setups[i].entryCancelRequestId==0 &&
           g_setups[i].entryOrder>0 &&
           g_setups[i].entryOrder==result.order));
      if(entryCancelMatch)
      {
         if(result.retcode==TRADE_RETCODE_DONE ||
            result.retcode==TRADE_RETCODE_NO_CHANGES)
            g_setups[i].entryCancelCompletionKnown=true;
         else if(IsTradeRetcodeDefinitiveFailure(result.retcode))
            g_setups[i].entryCancelRejected=true;
      }

      bool entryMatch=false;
      if(g_setups[i].entryPending && !g_setups[i].entryCancelPending)
      {
         if(g_setups[i].entryRequestId>0)
            entryMatch=g_setups[i].entryRequestId==result.request_id;
         else if(g_setups[i].entryOrder>0)
            entryMatch=g_setups[i].entryOrder==result.order;
      }
      if(entryMatch)
      {
         if(result.order>0) g_setups[i].entryOrder=result.order;
         if(result.deal>0)
         {
            g_setups[i].entryDeal=result.deal;
            if(HistoryDealSelect(result.deal))
               g_setups[i].positionIdentifier=(ulong)HistoryDealGetInteger(
                  result.deal,DEAL_POSITION_ID);
         }
         if(IsTradeRetcodeDefinitiveFailure(result.retcode))
            g_setups[i].entryRejected=true;
      }

      bool partialMatch=g_setups[i].partialPending &&
         ((g_setups[i].partialRequestId>0 &&
           g_setups[i].partialRequestId==result.request_id) ||
          (g_setups[i].partialRequestId==0 &&
           g_setups[i].partialOrder>0 &&
           g_setups[i].partialOrder==result.order));
      if(partialMatch)
      {
         if(result.order>0) g_setups[i].partialOrder=result.order;
         if(result.retcode==TRADE_RETCODE_DONE)
            g_setups[i].partialCompletionKnown=true;
         if(IsTradeRetcodeDefinitiveFailure(result.retcode))
            g_setups[i].partialRejected=true;
      }

      bool modifyMatch=g_setups[i].modifyPending &&
         ((g_setups[i].modifyRequestId>0 &&
           g_setups[i].modifyRequestId==result.request_id) ||
          (g_setups[i].modifyRequestId==0 &&
           g_setups[i].modifyOrder>0 &&
           g_setups[i].modifyOrder==result.order));
      if(modifyMatch)
      {
         if(result.order>0) g_setups[i].modifyOrder=result.order;
         if(result.retcode==TRADE_RETCODE_DONE ||
            result.retcode==TRADE_RETCODE_NO_CHANGES)
            g_setups[i].modifyCompletionKnown=true;
         else if(IsTradeRetcodeDefinitiveFailure(result.retcode))
            g_setups[i].modifyRejected=true;
      }

      bool closeMatch=g_setups[i].closePending &&
         ((g_setups[i].closeRequestId>0 &&
           g_setups[i].closeRequestId==result.request_id) ||
          (g_setups[i].closeRequestId==0 &&
           g_setups[i].closeOrder>0 &&
           g_setups[i].closeOrder==result.order));
      if(closeMatch)
      {
         if(result.order>0) g_setups[i].closeOrder=result.order;
         if(result.retcode==TRADE_RETCODE_DONE)
            g_setups[i].closeCompletionKnown=true;
         if(IsTradeRetcodeDefinitiveFailure(result.retcode))
            g_setups[i].closeRejected=true;
      }
   }
}

//+------------------------------------------------------------------+
//| OnTester : statistiques de chaque passe                          |
//+------------------------------------------------------------------+
double OnTester()
{
   double profit = TesterStatistics(STAT_PROFIT);
   double pf     = TesterStatistics(STAT_PROFIT_FACTOR);
   double ddpct  = TesterStatistics(STAT_EQUITYDD_PERCENT);
   double trades = TesterStatistics(STAT_TRADES);
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   double payoff = TesterStatistics(STAT_EXPECTED_PAYOFF);
   string fn=StringFormat("SBopt_v2_%s_O%dF%dE%dW%d_B%dG%d_t%.0f_f%.0f_r%.0f_s%d_d%d_p%.0f.csv",
                          _Symbol,(int)InpUseOTE,(int)InpUseFVG,
                          (int)InpUseEmaRetest,(int)InpUseSbWindows,
                          (int)InpBrokerTimeMode,InpBrokerGmtHours,
                          InpTp1R*10,InpFinalR*10,InpTrailR*10,
                          InpSlBufferTicks,InpMinDispTicks,
                          InpTp1Percent);
   int file=FileOpen(fn,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,',');
   if(file!=INVALID_HANDLE)
   {
      FileWrite(file,_Symbol,(int)InpUseOTE,(int)InpUseFVG,
                (int)InpUseEmaRetest,(int)InpUseSbWindows,
                (int)InpBrokerTimeMode,InpBrokerGmtHours,
                DoubleToString(InpTp1R,1),DoubleToString(InpFinalR,1),
                DoubleToString(InpTrailR,1),InpSlBufferTicks,
                InpMinDispTicks,DoubleToString(InpTp1Percent,0),
                DoubleToString(profit,2),DoubleToString(pf,3),
                DoubleToString(ddpct,2),(int)trades,
                DoubleToString(sharpe,3),DoubleToString(payoff,4));
      FileClose(file);
   }
   return profit;
}
//+------------------------------------------------------------------+
