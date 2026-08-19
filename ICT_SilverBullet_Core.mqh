#ifndef ICT_SILVER_BULLET_CORE_MQH
#define ICT_SILVER_BULLET_CORE_MQH

// Moteur deterministe et sans dependance MT5.
// Ce fichier est inclus par l'EA, l'indicateur et les tests C++.

#define SBL_MAX_CONSUMED 512
#define SBL_MAX_FVG_CANDIDATES 4

enum SblDirection
{
   SBL_SHORT   = -1,
   SBL_NEUTRAL = 0,
   SBL_LONG    = 1
};

enum SblPhase
{
   SBL_PHASE_INACTIVE = 0,
   SBL_PHASE_WAIT_INTERNAL_PIVOT,
   SBL_PHASE_WAIT_TARGET,
   SBL_PHASE_WAIT_MSS,
   SBL_PHASE_WAIT_CONFIRMATION,
   SBL_PHASE_WAIT_RETRACEMENT,
   SBL_PHASE_TRIGGERED,
   SBL_PHASE_INVALID,
   // Alias source-compatible avec les anciens adaptateurs.
   SBL_PHASE_WAIT_BREAK = SBL_PHASE_WAIT_INTERNAL_PIVOT
};

enum SblTrigger
{
   SBL_TRIGGER_NONE = 0,
   SBL_TRIGGER_FVG,
   SBL_TRIGGER_OTE,
   SBL_TRIGGER_EMA
};

enum SblBrokerOffsetMode
{
   SBL_BROKER_OFFSET_CONSTANT = 0,
   SBL_BROKER_DST_EUROPE
};

struct SblBar
{
   long   time;
   int    index;
   double open;
   double high;
   double low;
   double close;
   double emaFast;
   double previousClose;
   long   windowKey;
};

// Pivot interne strict : une ou deux bougies de chaque cote selon strength.
// Pour un LONG, price est un swing high ; pour un SHORT, un swing low.
struct SblPivot
{
   bool   present;
   int    direction;
   double price;
   int    pivotBar;
   long   pivotTime;
   int    confirmedBar;
   long   confirmedTime;
};

struct SblFvg
{
   bool   present;
   int    direction;
   int    formedBar;
   long   formedTime;
   double low;
   double high;
};

struct SblConfig
{
   double minDisplacement;
   double minFvgSize;
   double oteLow;
   double oteHigh;
   int    expiryBars;
   int    maxFvgCandidates;
   bool   requireWindow;
   bool   requireDirectionalRejection;
   bool   allowMssBeforeTarget;
   bool   allowTargetBeforeInternalPivot;
   bool   useFvgTrigger;
   bool   useOteTrigger;
   bool   useEmaTrigger;
};

struct SblSetup
{
   int    id;
   int    direction;
   int    phase;
   int    lastProcessedBar;
   long   lastProcessedTime;

   double refHigh;
   double refLow;
   long   refHighTime;
   long   refLowTime;

   int    purgeBar;
   long   purgeTime;
   double fib0;
   long   windowKey;

   bool   hasInternalPivot;
   double internalPivot;
   int    internalPivotBar;
   long   internalPivotTime;
   int    internalPivotConfirmedBar;
   long   internalPivotConfirmedTime;

   bool   hasPendingMss;
   int    pendingMssBar;
   long   pendingMssTime;

   bool   targetTaken;
   int    targetBar;
   long   targetTime;

   int    breakBar;
   long   breakTime;
   int    mssBar;
   long   mssTime;

   double legExtreme;
   double fib1;
   double equilibrium;
   int    confirmationBar;
   long   confirmationTime;

   bool   hasCandidateFvg;
   double candidateFvgLow;
   double candidateFvgHigh;
   int    candidateFvgBar;
   long   candidateFvgTime;

   // Pool fixe. Les champs candidateFvg* ci-dessus restent le miroir public
   // du premier slot afin de conserver le contrat des anciens adaptateurs.
   int    candidateFvgCount;
   double candidateFvgLows[SBL_MAX_FVG_CANDIDATES];
   double candidateFvgHighs[SBL_MAX_FVG_CANDIDATES];
   int    candidateFvgBars[SBL_MAX_FVG_CANDIDATES];
   long   candidateFvgTimes[SBL_MAX_FVG_CANDIDATES];

   bool   hasContextFvg;
   double fvgLow;
   double fvgHigh;
   int    fvgBar;
   long   fvgTime;

   int    trigger;
   int    triggerBar;
   long   triggerTime;
   double expectedEntry;
};

struct SblDecision
{
   bool   signal;
   int    setupId;
   int    direction;
   int    trigger;
   double expectedEntry;
   bool   consumeTarget;
   long   targetKey;
};

struct SblConsumedRegistry
{
   long longKeys[SBL_MAX_CONSUMED];
   int  longCount;
   long shortKeys[SBL_MAX_CONSUMED];
   int  shortCount;
};

double SblAbs(double value)
{
   return value < 0.0 ? -value : value;
}

double SblMin(double left, double right)
{
   return left < right ? left : right;
}

double SblMax(double left, double right)
{
   return left > right ? left : right;
}

bool SblNearlyEqual(double left, double right, double epsilon)
{
   return SblAbs(left - right) <= epsilon;
}

void SblResetDecision(SblDecision &decision)
{
   decision.signal = false;
   decision.setupId = 0;
   decision.direction = SBL_NEUTRAL;
   decision.trigger = SBL_TRIGGER_NONE;
   decision.expectedEntry = 0.0;
   decision.consumeTarget = false;
   decision.targetKey = 0;
}

void SblResetPivot(SblPivot &pivot)
{
   pivot.present = false;
   pivot.direction = SBL_NEUTRAL;
   pivot.price = 0.0;
   pivot.pivotBar = -1;
   pivot.pivotTime = 0;
   pivot.confirmedBar = -1;
   pivot.confirmedTime = 0;
}

void SblResetFvg(SblFvg &fvg)
{
   fvg.present = false;
   fvg.direction = SBL_NEUTRAL;
   fvg.formedBar = -1;
   fvg.formedTime = 0;
   fvg.low = 0.0;
   fvg.high = 0.0;
}

void SblResetSetup(SblSetup &setup)
{
   setup.id = 0;
   setup.direction = SBL_NEUTRAL;
   setup.phase = SBL_PHASE_INACTIVE;
   setup.lastProcessedBar = -1;
   setup.lastProcessedTime = 0;
   setup.refHigh = 0.0;
   setup.refLow = 0.0;
   setup.refHighTime = 0;
   setup.refLowTime = 0;
   setup.purgeBar = -1;
   setup.purgeTime = 0;
   setup.fib0 = 0.0;
   setup.windowKey = 0;
   setup.hasInternalPivot = false;
   setup.internalPivot = 0.0;
   setup.internalPivotBar = -1;
   setup.internalPivotTime = 0;
   setup.internalPivotConfirmedBar = -1;
   setup.internalPivotConfirmedTime = 0;
   setup.hasPendingMss = false;
   setup.pendingMssBar = -1;
   setup.pendingMssTime = 0;
   setup.targetTaken = false;
   setup.targetBar = -1;
   setup.targetTime = 0;
   setup.breakBar = -1;
   setup.breakTime = 0;
   setup.mssBar = -1;
   setup.mssTime = 0;
   setup.legExtreme = 0.0;
   setup.fib1 = 0.0;
   setup.equilibrium = 0.0;
   setup.confirmationBar = -1;
   setup.confirmationTime = 0;
   setup.hasCandidateFvg = false;
   setup.candidateFvgLow = 0.0;
   setup.candidateFvgHigh = 0.0;
   setup.candidateFvgBar = -1;
   setup.candidateFvgTime = 0;
   setup.candidateFvgCount = 0;
   for(int i = 0; i < SBL_MAX_FVG_CANDIDATES; i++)
   {
      setup.candidateFvgLows[i] = 0.0;
      setup.candidateFvgHighs[i] = 0.0;
      setup.candidateFvgBars[i] = -1;
      setup.candidateFvgTimes[i] = 0;
   }
   setup.hasContextFvg = false;
   setup.fvgLow = 0.0;
   setup.fvgHigh = 0.0;
   setup.fvgBar = -1;
   setup.fvgTime = 0;
   setup.trigger = SBL_TRIGGER_NONE;
   setup.triggerBar = -1;
   setup.triggerTime = 0;
   setup.expectedEntry = 0.0;
}

void SblResetRegistry(SblConsumedRegistry &registry)
{
   registry.longCount = 0;
   registry.shortCount = 0;
   for(int i = 0; i < SBL_MAX_CONSUMED; i++)
   {
      registry.longKeys[i] = 0;
      registry.shortKeys[i] = 0;
   }
}

int SblStrictStack(double closePrice, double emaFast, double emaSlow)
{
   if(closePrice <= 0.0 || emaFast <= 0.0 || emaSlow <= 0.0)
      return SBL_NEUTRAL;
   if(closePrice > emaFast && emaFast > emaSlow)
      return SBL_LONG;
   if(closePrice < emaFast && emaFast < emaSlow)
      return SBL_SHORT;
   return SBL_NEUTRAL;
}

int SblAlignedBias(int d1, int h1, int confirmation1, int confirmation2)
{
   if(d1 == SBL_NEUTRAL)
      return SBL_NEUTRAL;
   if(h1 != d1 || confirmation1 != d1 || confirmation2 != d1)
      return SBL_NEUTRAL;
   return d1;
}

bool SblIsUsDstUtcFields(int month, int day, int minuteOfDay,
                         int dayOfWeek)
{
   if(month < 3 || month > 11 || day < 1 ||
      minuteOfDay < 0 || minuteOfDay >= 24 * 60 ||
      dayOfWeek < 0 || dayOfWeek > 6)
      return false;
   if(month > 3 && month < 11)
      return true;

   int firstDayOfWeek = dayOfWeek - ((day - 1) % 7);
   while(firstDayOfWeek < 0)
      firstDayOfWeek += 7;
   int firstSunday = firstDayOfWeek == 0 ? 1 : 8 - firstDayOfWeek;

   if(month == 3)
   {
      int secondSunday = firstSunday + 7;
      if(day < secondSunday)
         return false;
      if(day > secondSunday)
         return true;
      return minuteOfDay >= 7 * 60;
   }

   if(day < firstSunday)
      return true;
   if(day > firstSunday)
      return false;
   return minuteOfDay < 6 * 60;
}

bool SblIsEuropeDstUtcFields(int month, int day, int minuteOfDay,
                             int dayOfWeek)
{
   if(month < 3 || month > 10 || day < 1 || day > 31 ||
      minuteOfDay < 0 || minuteOfDay >= 24 * 60 ||
      dayOfWeek < 0 || dayOfWeek > 6)
      return false;
   if(month > 3 && month < 10)
      return true;

   int daysUntilThirtyFirst = 31 - day;
   int thirtyFirstDayOfWeek = (dayOfWeek + daysUntilThirtyFirst) % 7;
   int lastSunday = 31 - thirtyFirstDayOfWeek;

   if(month == 3)
   {
      if(day < lastSunday)
         return false;
      if(day > lastSunday)
         return true;
      return minuteOfDay >= 60;
   }

   if(day < lastSunday)
      return true;
   if(day > lastSunday)
      return false;
   return minuteOfDay < 60;
}

int SblBrokerUtcOffsetSeconds(int mode, int standardHours,
                              int utcMonth, int utcDay,
                              int utcMinuteOfDay, int utcDayOfWeek)
{
   int offset = standardHours * 3600;
   if(mode == SBL_BROKER_DST_EUROPE &&
      SblIsEuropeDstUtcFields(utcMonth, utcDay, utcMinuteOfDay,
                              utcDayOfWeek))
      offset += 3600;
   return offset;
}

int SblNewYorkUtcOffsetSeconds(int month, int day, int minuteOfDay,
                               int dayOfWeek, bool automaticDst,
                               int manualHours)
{
   if(!automaticDst)
      return manualHours * 3600;
   return SblIsUsDstUtcFields(month, day, minuteOfDay, dayOfWeek)
          ? -4 * 3600
          : -5 * 3600;
}

int SblEntryWindowId(int minuteOfDay)
{
   if(minuteOfDay < 0 || minuteOfDay >= 24 * 60)
      return 0;
   if(minuteOfDay >= 2 * 60 && minuteOfDay < 5 * 60)
      return 1;
   if(minuteOfDay >= 7 * 60 && minuteOfDay < 10 * 60)
      return 2;
   if(minuteOfDay >= 19 * 60 && minuteOfDay < 22 * 60)
      return 3;
   return 0;
}

bool SblInEntryWindowMinutes(int minuteOfDay)
{
   return SblEntryWindowId(minuteOfDay) != 0;
}

// nyDateKey doit identifier la date NY (YYYYMMDD recommande).
long SblEntryWindowKey(int nyDateKey, int minuteOfDay)
{
   int windowId = SblEntryWindowId(minuteOfDay);
   if(nyDateKey <= 0 || windowId == 0)
      return 0;
   return (long)nyDateKey * 10 + windowId;
}

bool SblValidEntryWindowKey(long windowKey)
{
   if(windowKey <= 0)
      return false;
   int windowId = (int)(windowKey % 10);
   if(windowId < 1 || windowId > 3)
      return false;

   long dateKey = windowKey / 10;
   int year = (int)(dateKey / 10000);
   int month = (int)((dateKey / 100) % 100);
   int day = (int)(dateKey % 100);
   if(year < 1970 || year > 9999 || month < 1 || month > 12 || day < 1)
      return false;

   int daysInMonth = 31;
   if(month == 4 || month == 6 || month == 9 || month == 11)
      daysInMonth = 30;
   else if(month == 2)
   {
      bool leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
      daysInMonth = leap ? 29 : 28;
   }
   return day <= daysInMonth;
}

bool SblRangesIntersect(double firstLow, double firstHigh,
                        double secondLow, double secondHigh)
{
   double aLow = SblMin(firstLow, firstHigh);
   double aHigh = SblMax(firstLow, firstHigh);
   double bLow = SblMin(secondLow, secondHigh);
   double bHigh = SblMax(secondLow, secondHigh);
   return aHigh >= bLow && aLow <= bHigh;
}

void SblDetectFvg(const SblBar &newest, const SblBar &oldest,
                  double minimumSize, SblFvg &fvg)
{
   SblResetFvg(fvg);
   if(newest.low > oldest.high && newest.low - oldest.high >= minimumSize)
   {
      fvg.present = true;
      fvg.direction = SBL_LONG;
      fvg.formedBar = newest.index;
      fvg.formedTime = newest.time;
      fvg.low = oldest.high;
      fvg.high = newest.low;
      return;
   }
   if(newest.high < oldest.low && oldest.low - newest.high >= minimumSize)
   {
      fvg.present = true;
      fvg.direction = SBL_SHORT;
      fvg.formedBar = newest.index;
      fvg.formedTime = newest.time;
      fvg.low = newest.high;
      fvg.high = oldest.low;
   }
}

void SblDetectInternalPivot(int direction, int strength,
                            const SblBar &twoBefore,
                            const SblBar &oneBefore,
                            const SblBar &candidate,
                            const SblBar &oneAfter,
                            const SblBar &twoAfter,
                            SblPivot &pivot)
{
   SblResetPivot(pivot);
   if(strength != 1 && strength != 2)
      return;

   // Le pivot 1/1 ne depend que de ses trois bougies causales. Les bougies
   // externes restent dans la signature afin que les adaptateurs partagent le
   // meme buffer, mais elles ne doivent ni filtrer ni retarder sa confirmation.
   if(candidate.index != oneBefore.index + 1 ||
      oneAfter.index != candidate.index + 1 ||
      candidate.time <= oneBefore.time ||
      oneAfter.time <= candidate.time)
      return;

   // Pour strength=2, conserver strictement le contrat historique 2/2.
   if(strength == 2 &&
      (oneBefore.index != twoBefore.index + 1 ||
       twoAfter.index != oneAfter.index + 1 ||
       oneBefore.time <= twoBefore.time ||
       twoAfter.time <= oneAfter.time))
      return;

   bool present = false;
   double price = 0.0;
   if(direction == SBL_LONG)
   {
      present = candidate.high > oneBefore.high &&
                candidate.high > oneAfter.high;
      if(strength == 2)
         present = present && candidate.high > twoBefore.high &&
                   candidate.high > twoAfter.high;
      price = candidate.high;
   }
   else if(direction == SBL_SHORT)
   {
      present = candidate.low < oneBefore.low &&
                candidate.low < oneAfter.low;
      if(strength == 2)
         present = present && candidate.low < twoBefore.low &&
                   candidate.low < twoAfter.low;
      price = candidate.low;
   }
   if(!present)
      return;

   pivot.present = true;
   pivot.direction = direction;
   pivot.price = price;
   pivot.pivotBar = candidate.index;
   pivot.pivotTime = candidate.time;
   pivot.confirmedBar = strength == 1 ? oneAfter.index : twoAfter.index;
   pivot.confirmedTime = strength == 1 ? oneAfter.time : twoAfter.time;
}

// Signature historique : les adaptateurs non migres restent strictement 2/2.
void SblDetectInternalPivot(int direction,
                            const SblBar &twoBefore,
                            const SblBar &oneBefore,
                            const SblBar &candidate,
                            const SblBar &oneAfter,
                            const SblBar &twoAfter,
                            SblPivot &pivot)
{
   SblDetectInternalPivot(direction,2,twoBefore,oneBefore,candidate,
                          oneAfter,twoAfter,pivot);
}

// Une outside bar peut etre simultanement le plus haut et le plus bas des
// cinq bougies. Elle ne fournit pas une structure directionnelle non ambigue
// et ferait en plus partager la meme cle temporelle aux liquidites high/low.
void SblRejectAmbiguousDualPivot(SblPivot &highPivot, SblPivot &lowPivot)
{
   if(!highPivot.present || !lowPivot.present)
      return;
   if(highPivot.pivotBar != lowPivot.pivotBar ||
      highPivot.pivotTime != lowPivot.pivotTime)
      return;
   SblResetPivot(highPivot);
   SblResetPivot(lowPivot);
}

double SblFvgConsequentEncroachment(double fvgLow, double fvgHigh)
{
   return (SblMin(fvgLow,fvgHigh) + SblMax(fvgLow,fvgHigh)) * 0.5;
}

bool SblFvgInValueArea(int direction, double fvgLow, double fvgHigh,
                       double fib0, double fib1)
{
   double ce = SblFvgConsequentEncroachment(fvgLow,fvgHigh);
   double equilibrium = (fib0 + fib1) * 0.5;
   if(direction == SBL_LONG)
      return fib1 > fib0 && ce >= fib0 && ce <= equilibrium;
   if(direction == SBL_SHORT)
      return fib0 > fib1 && ce >= equilibrium && ce <= fib0;
   return false;
}

bool SblPriceInValueArea(int direction, double price, double fib0, double fib1)
{
   double equilibrium = (fib0 + fib1) * 0.5;
   if(direction == SBL_LONG)
      return fib1 > fib0 && price >= fib0 && price <= equilibrium;
   if(direction == SBL_SHORT)
      return fib0 > fib1 && price >= equilibrium && price <= fib0;
   return false;
}

void SblOteBounds(int direction, double fib0, double fib1,
                  double oteLow, double oteHigh,
                  double &zoneLow, double &zoneHigh)
{
   double range = SblAbs(fib1 - fib0);
   if(direction == SBL_LONG)
   {
      zoneLow = fib1 - oteHigh * range;
      zoneHigh = fib1 - oteLow * range;
   }
   else
   {
      zoneLow = fib1 + oteLow * range;
      zoneHigh = fib1 + oteHigh * range;
   }
   if(zoneLow > zoneHigh)
   {
      double swap = zoneLow;
      zoneLow = zoneHigh;
      zoneHigh = swap;
   }
}

bool SblDirectionalRejection(int direction, const SblBar &bar)
{
   if(direction == SBL_LONG)
      return bar.close > bar.open;
   if(direction == SBL_SHORT)
      return bar.close < bar.open;
   return false;
}

bool SblEmaTrigger(int direction, const SblBar &bar,
                   double fib0, double fib1)
{
   if(bar.emaFast <= 0.0 ||
      !SblPriceInValueArea(direction,bar.emaFast,fib0,fib1))
      return false;
   if(bar.low > bar.emaFast || bar.high < bar.emaFast)
      return false;
   if(direction == SBL_LONG)
      return bar.close >= bar.emaFast && bar.close > bar.open;
   if(direction == SBL_SHORT)
      return bar.close <= bar.emaFast && bar.close < bar.open;
   return false;
}

bool SblEmaTouched(int direction, const SblBar &bar,
                   double fib0, double fib1)
{
   return bar.emaFast > 0.0 &&
          SblPriceInValueArea(direction,bar.emaFast,fib0,fib1) &&
          bar.low <= bar.emaFast && bar.high >= bar.emaFast;
}

bool SblRegistryContains(const SblConsumedRegistry &registry,
                         int direction, long key)
{
   if(key <= 0)
      return true;
   if(direction == SBL_LONG)
   {
      for(int i = 0; i < registry.longCount; i++)
         if(registry.longKeys[i] == key)
            return true;
      return false;
   }
   if(direction == SBL_SHORT)
   {
      for(int i = 0; i < registry.shortCount; i++)
         if(registry.shortKeys[i] == key)
            return true;
   }
   return false;
}

bool SblRegistryConsume(SblConsumedRegistry &registry,
                        int direction, long key)
{
   if(SblRegistryContains(registry, direction, key))
      return false;
   if(direction == SBL_LONG)
   {
      if(registry.longCount < SBL_MAX_CONSUMED)
      {
         registry.longKeys[registry.longCount] = key;
         registry.longCount++;
      }
      else
      {
         for(int i = 1; i < SBL_MAX_CONSUMED; i++)
            registry.longKeys[i - 1] = registry.longKeys[i];
         registry.longKeys[SBL_MAX_CONSUMED - 1] = key;
      }
      return true;
   }
   if(direction == SBL_SHORT)
   {
      if(registry.shortCount < SBL_MAX_CONSUMED)
      {
         registry.shortKeys[registry.shortCount] = key;
         registry.shortCount++;
      }
      else
      {
         for(int i = 1; i < SBL_MAX_CONSUMED; i++)
            registry.shortKeys[i - 1] = registry.shortKeys[i];
         registry.shortKeys[SBL_MAX_CONSUMED - 1] = key;
      }
      return true;
   }
   return false;
}

bool SblPurgeReintegrated(int direction, const SblBar &bar,
                          double refHigh, double refLow)
{
   if(direction == SBL_LONG)
      return bar.low < refLow && bar.close > refLow;
   if(direction == SBL_SHORT)
      return bar.high > refHigh && bar.close < refHigh;
   return false;
}

bool SblStartSetup(SblSetup &setup, int id, int direction,
                   const SblBar &purgeBar,
                   double refHigh, long refHighTime,
                   double refLow, long refLowTime,
                   SblDecision &decision)
{
   SblResetDecision(decision);
   SblResetSetup(setup);
   if(direction != SBL_LONG && direction != SBL_SHORT)
      return false;
   if(refHigh <= refLow || refHighTime <= 0 || refLowTime <= 0)
      return false;
   if(purgeBar.time <= 0 || refHighTime >= purgeBar.time ||
      refLowTime >= purgeBar.time)
      return false;
   if(!SblValidEntryWindowKey(purgeBar.windowKey) ||
      !SblPurgeReintegrated(direction,purgeBar,refHigh,refLow))
      return false;

   // Une bougie qui purge les deux cotes consomme deja la cible externe :
   // elle ne peut pas initialiser la sequence pivot -> target -> MSS.
   bool targetAlreadySwept = direction == SBL_LONG
                             ? purgeBar.high > refHigh
                             : purgeBar.low < refLow;
   if(targetAlreadySwept)
   {
      decision.setupId = id;
      decision.direction = direction;
      decision.consumeTarget = true;
      decision.targetKey = direction == SBL_LONG ? refHighTime : refLowTime;
      return false;
   }

   setup.id = id;
   setup.direction = direction;
   setup.phase = SBL_PHASE_WAIT_INTERNAL_PIVOT;
   setup.lastProcessedBar = purgeBar.index;
   setup.lastProcessedTime = purgeBar.time;
   setup.refHigh = refHigh;
   setup.refLow = refLow;
   setup.refHighTime = refHighTime;
   setup.refLowTime = refLowTime;
   setup.purgeBar = purgeBar.index;
   setup.purgeTime = purgeBar.time;
   setup.fib0 = direction == SBL_LONG ? purgeBar.low : purgeBar.high;
   setup.windowKey = purgeBar.windowKey;
   setup.legExtreme = setup.fib0;
   return true;
}

bool SblSetupExpired(const SblSetup &setup, const SblBar &bar,
                     const SblConfig &config)
{
   return config.expiryBars >= 0 && bar.index - setup.purgeBar > config.expiryBars;
}

bool SblOriginInvalidated(const SblSetup &setup, const SblBar &bar)
{
   if(setup.direction == SBL_LONG)
      return bar.close < setup.fib0;
   if(setup.direction == SBL_SHORT)
      return bar.close > setup.fib0;
   return true;
}

bool SblContextFvgInvalidated(const SblSetup &setup, const SblBar &bar)
{
   if(!setup.hasContextFvg)
      return false;
   if(setup.direction == SBL_LONG)
      return bar.close < setup.fvgLow;
   return bar.close > setup.fvgHigh;
}

bool SblCandidateFvgInvalidated(const SblSetup &setup, const SblBar &bar)
{
   if(!setup.hasCandidateFvg)
      return false;
   if(setup.direction == SBL_LONG)
      return bar.close < setup.candidateFvgLow;
   return bar.close > setup.candidateFvgHigh;
}

int SblBoundMaxFvgCandidates(int requested)
{
   if(requested < 1)
      return 1;
   if(requested > SBL_MAX_FVG_CANDIDATES)
      return SBL_MAX_FVG_CANDIDATES;
   return requested;
}

void SblResetCandidateFvgSlot(SblSetup &setup, int slot)
{
   if(slot < 0 || slot >= SBL_MAX_FVG_CANDIDATES)
      return;
   setup.candidateFvgLows[slot] = 0.0;
   setup.candidateFvgHighs[slot] = 0.0;
   setup.candidateFvgBars[slot] = -1;
   setup.candidateFvgTimes[slot] = 0;
}

void SblSyncLegacyCandidateFvg(SblSetup &setup)
{
   if(setup.candidateFvgCount <= 0)
   {
      setup.candidateFvgCount = 0;
      setup.hasCandidateFvg = false;
      setup.candidateFvgLow = 0.0;
      setup.candidateFvgHigh = 0.0;
      setup.candidateFvgBar = -1;
      setup.candidateFvgTime = 0;
      return;
   }

   setup.hasCandidateFvg = true;
   setup.candidateFvgLow = setup.candidateFvgLows[0];
   setup.candidateFvgHigh = setup.candidateFvgHighs[0];
   setup.candidateFvgBar = setup.candidateFvgBars[0];
   setup.candidateFvgTime = setup.candidateFvgTimes[0];
}

// Importe un eventuel etat legacy initialise directement par un ancien
// adaptateur. Les setups crees par ce moteur possedent deja le pool synchronise.
void SblHydrateCandidateFvgPool(SblSetup &setup)
{
   if(setup.candidateFvgCount > 0 || !setup.hasCandidateFvg)
      return;
   setup.candidateFvgCount = 1;
   setup.candidateFvgLows[0] = SblMin(setup.candidateFvgLow,
                                      setup.candidateFvgHigh);
   setup.candidateFvgHighs[0] = SblMax(setup.candidateFvgLow,
                                       setup.candidateFvgHigh);
   setup.candidateFvgBars[0] = setup.candidateFvgBar;
   setup.candidateFvgTimes[0] = setup.candidateFvgTime;
}

void SblClearCandidateFvg(SblSetup &setup)
{
   for(int i = 0; i < SBL_MAX_FVG_CANDIDATES; i++)
      SblResetCandidateFvgSlot(setup,i);
   setup.candidateFvgCount = 0;
   setup.hasCandidateFvg = false;
   setup.candidateFvgLow = 0.0;
   setup.candidateFvgHigh = 0.0;
   setup.candidateFvgBar = -1;
   setup.candidateFvgTime = 0;
}

void SblSetCandidateFvgSlot(SblSetup &setup, int slot,
                            double low, double high,
                            int formedBar, long formedTime)
{
   if(slot < 0 || slot >= SBL_MAX_FVG_CANDIDATES)
      return;
   setup.candidateFvgLows[slot] = SblMin(low,high);
   setup.candidateFvgHighs[slot] = SblMax(low,high);
   setup.candidateFvgBars[slot] = formedBar;
   setup.candidateFvgTimes[slot] = formedTime;
}

bool SblSameCandidateFvg(const SblSetup &setup, int slot,
                         double low, double high,
                         int formedBar, long formedTime)
{
   return slot >= 0 && slot < setup.candidateFvgCount &&
          setup.candidateFvgLows[slot] == low &&
          setup.candidateFvgHighs[slot] == high &&
          setup.candidateFvgBars[slot] == formedBar &&
          setup.candidateFvgTimes[slot] == formedTime;
}

bool SblCandidateFormationOlder(int firstBar, long firstTime,
                                int secondBar, long secondTime)
{
   if(firstTime != secondTime)
      return firstTime < secondTime;
   return firstBar < secondBar;
}

bool SblCandidateMoreRobust(int direction,
                            double firstLow, double firstHigh,
                            int firstBar, long firstTime,
                            double secondLow, double secondHigh,
                            int secondBar, long secondTime)
{
   if(direction == SBL_LONG)
   {
      if(firstLow != secondLow)
         return firstLow < secondLow;
   }
   else if(direction == SBL_SHORT)
   {
      if(firstHigh != secondHigh)
         return firstHigh > secondHigh;
   }
   return SblCandidateFormationOlder(firstBar,firstTime,
                                     secondBar,secondTime);
}

bool SblCandidatePreferredForPool(const SblSetup &setup,
                                  double firstLow, double firstHigh,
                                  int firstBar, long firstTime,
                                  double secondLow, double secondHigh,
                                  int secondBar, long secondTime)
{
   bool firstInValue = SblFvgInValueArea(setup.direction,
                                          firstLow,firstHigh,
                                          setup.fib0,setup.legExtreme);
   bool secondInValue = SblFvgInValueArea(setup.direction,
                                           secondLow,secondHigh,
                                           setup.fib0,setup.legExtreme);
   if(firstInValue != secondInValue)
      return firstInValue;
   return SblCandidateMoreRobust(setup.direction,
                                 firstLow,firstHigh,firstBar,firstTime,
                                 secondLow,secondHigh,secondBar,secondTime);
}

void SblRemoveCandidateFvgSlot(SblSetup &setup, int slot)
{
   if(slot < 0 || slot >= setup.candidateFvgCount)
      return;
   for(int i = slot + 1; i < setup.candidateFvgCount; i++)
   {
      setup.candidateFvgLows[i - 1] = setup.candidateFvgLows[i];
      setup.candidateFvgHighs[i - 1] = setup.candidateFvgHighs[i];
      setup.candidateFvgBars[i - 1] = setup.candidateFvgBars[i];
      setup.candidateFvgTimes[i - 1] = setup.candidateFvgTimes[i];
   }
   setup.candidateFvgCount--;
   SblResetCandidateFvgSlot(setup,setup.candidateFvgCount);
}

void SblTrimCandidateFvgPool(SblSetup &setup, int requestedMaximum)
{
   int maximum = SblBoundMaxFvgCandidates(requestedMaximum);
   SblHydrateCandidateFvgPool(setup);
   while(setup.candidateFvgCount > maximum)
   {
      int weakest = 0;
      for(int i = 1; i < setup.candidateFvgCount; i++)
      {
         if(SblCandidatePreferredForPool(
               setup,
               setup.candidateFvgLows[weakest],
               setup.candidateFvgHighs[weakest],
               setup.candidateFvgBars[weakest],
               setup.candidateFvgTimes[weakest],
               setup.candidateFvgLows[i],setup.candidateFvgHighs[i],
               setup.candidateFvgBars[i],setup.candidateFvgTimes[i]))
            weakest = i;
      }
      SblRemoveCandidateFvgSlot(setup,weakest);
   }
   SblSyncLegacyCandidateFvg(setup);
}

bool SblCacheCandidateFvg(SblSetup &setup, const SblFvg &fvg,
                          int requestedMaximum)
{
   if(!fvg.present || fvg.direction != setup.direction ||
      fvg.formedBar <= setup.purgeBar + 2 ||
      fvg.formedTime <= setup.purgeTime)
      return false;

   double low = SblMin(fvg.low, fvg.high);
   double high = SblMax(fvg.low, fvg.high);
   int maximum = SblBoundMaxFvgCandidates(requestedMaximum);
   SblHydrateCandidateFvgPool(setup);
   SblTrimCandidateFvgPool(setup,maximum);

   for(int i = 0; i < setup.candidateFvgCount; i++)
      if(SblSameCandidateFvg(setup,i,low,high,
                             fvg.formedBar,fvg.formedTime))
         return true;

   // Capacite 1 : contrat historique strictement inchange.
   if(maximum == 1)
   {
      bool replace = setup.candidateFvgCount == 0;
      if(setup.candidateFvgCount > 0)
      {
         bool currentInValue = SblFvgInValueArea(
            setup.direction,setup.candidateFvgLows[0],
            setup.candidateFvgHighs[0],setup.fib0,setup.legExtreme);
         bool newInValue = SblFvgInValueArea(setup.direction,low,high,
                                              setup.fib0,setup.legExtreme);
         if(newInValue != currentInValue)
            replace = newInValue;
         else if(setup.direction == SBL_LONG)
            replace = high < setup.candidateFvgHighs[0];
         else
            replace = low > setup.candidateFvgLows[0];
      }

      if(replace)
      {
         SblSetCandidateFvgSlot(setup,0,low,high,
                                fvg.formedBar,fvg.formedTime);
         setup.candidateFvgCount = 1;
         SblSyncLegacyCandidateFvg(setup);
      }
      return true;
   }

   if(setup.candidateFvgCount < maximum)
   {
      int slot = setup.candidateFvgCount;
      SblSetCandidateFvgSlot(setup,slot,low,high,
                             fvg.formedBar,fvg.formedTime);
      setup.candidateFvgCount++;
      SblSyncLegacyCandidateFvg(setup);
      return true;
   }

   // Pool plein : remplacer uniquement la candidate la moins utile si la
   // nouvelle est preferable. Le classement reste deterministe.
   int weakest = 0;
   for(int i = 1; i < setup.candidateFvgCount; i++)
   {
      if(SblCandidatePreferredForPool(
            setup,
            setup.candidateFvgLows[weakest],
            setup.candidateFvgHighs[weakest],
            setup.candidateFvgBars[weakest],
            setup.candidateFvgTimes[weakest],
            setup.candidateFvgLows[i],setup.candidateFvgHighs[i],
            setup.candidateFvgBars[i],setup.candidateFvgTimes[i]))
         weakest = i;
   }
   if(SblCandidatePreferredForPool(
         setup,low,high,fvg.formedBar,fvg.formedTime,
         setup.candidateFvgLows[weakest],
         setup.candidateFvgHighs[weakest],
         setup.candidateFvgBars[weakest],
         setup.candidateFvgTimes[weakest]))
      SblSetCandidateFvgSlot(setup,weakest,low,high,
                             fvg.formedBar,fvg.formedTime);
   SblSyncLegacyCandidateFvg(setup);
   return true;
}

// Signature historique : une seule candidate et politique de remplacement
// identique a la revision precedente.
bool SblCacheCandidateFvg(SblSetup &setup, const SblFvg &fvg)
{
   return SblCacheCandidateFvg(setup,fvg,1);
}

bool SblInvalidateCandidateFvgs(SblSetup &setup, const SblBar &bar,
                                int requestedMaximum)
{
   SblHydrateCandidateFvgPool(setup);
   SblTrimCandidateFvgPool(setup,requestedMaximum);
   bool invalidated = false;
   for(int i = setup.candidateFvgCount - 1; i >= 0; i--)
   {
      bool invalid = setup.direction == SBL_LONG
                     ? bar.close < setup.candidateFvgLows[i]
                     : bar.close > setup.candidateFvgHighs[i];
      if(!invalid)
         continue;
      SblRemoveCandidateFvgSlot(setup,i);
      invalidated = true;
   }
   SblSyncLegacyCandidateFvg(setup);
   return invalidated;
}

void SblStoreContextFvg(SblSetup &setup, const SblFvg &fvg)
{
   setup.hasContextFvg = true;
   setup.fvgLow = SblMin(fvg.low, fvg.high);
   setup.fvgHigh = SblMax(fvg.low, fvg.high);
   setup.fvgBar = fvg.formedBar;
   setup.fvgTime = fvg.formedTime;
}

bool SblHasPromotableCandidateFvg(const SblSetup &setup)
{
   int count = setup.candidateFvgCount;
   if(count <= 0 && setup.hasCandidateFvg)
      return SblFvgInValueArea(setup.direction,
                               setup.candidateFvgLow,
                               setup.candidateFvgHigh,
                               setup.fib0,setup.legExtreme);
   if(count > SBL_MAX_FVG_CANDIDATES)
      count = SBL_MAX_FVG_CANDIDATES;
   for(int i = 0; i < count; i++)
      if(SblFvgInValueArea(setup.direction,
                           setup.candidateFvgLows[i],
                           setup.candidateFvgHighs[i],
                           setup.fib0,setup.legExtreme))
         return true;
   return false;
}

bool SblPromoteCandidateFvg(SblSetup &setup, int requestedMaximum)
{
   SblHydrateCandidateFvgPool(setup);
   SblTrimCandidateFvgPool(setup,requestedMaximum);

   int selected = -1;
   for(int i = 0; i < setup.candidateFvgCount; i++)
   {
      if(!SblFvgInValueArea(setup.direction,
                            setup.candidateFvgLows[i],
                            setup.candidateFvgHighs[i],
                            setup.fib0,setup.legExtreme))
         continue;
      if(selected < 0 || SblCandidateMoreRobust(
            setup.direction,
            setup.candidateFvgLows[i],setup.candidateFvgHighs[i],
            setup.candidateFvgBars[i],setup.candidateFvgTimes[i],
            setup.candidateFvgLows[selected],
            setup.candidateFvgHighs[selected],
            setup.candidateFvgBars[selected],
            setup.candidateFvgTimes[selected]))
         selected = i;
   }
   if(selected < 0)
      return false;

   setup.hasContextFvg = true;
   setup.fvgLow = setup.candidateFvgLows[selected];
   setup.fvgHigh = setup.candidateFvgHighs[selected];
   setup.fvgBar = setup.candidateFvgBars[selected];
   setup.fvgTime = setup.candidateFvgTimes[selected];
   SblClearCandidateFvg(setup);
   return true;
}

bool SblPromoteCandidateFvg(SblSetup &setup)
{
   return SblPromoteCandidateFvg(setup,1);
}

bool SblTryStoreContextFvg(SblSetup &setup, const SblFvg &fvg)
{
   if(!fvg.present || fvg.direction != setup.direction)
      return false;
   if(fvg.formedBar <= setup.purgeBar + 2)
      return false;
   if(fvg.formedTime <= setup.purgeTime)
      return false;
   if(!SblFvgInValueArea(setup.direction, fvg.low, fvg.high,
                         setup.fib0, setup.legExtreme))
      return false;
   SblStoreContextFvg(setup, fvg);
   return true;
}

bool SblStoreInternalPivot(SblSetup &setup, const SblPivot &pivot,
                           const SblBar &bar)
{
   if(!pivot.present)
      return false;
   bool validConfirmationDistance =
      pivot.confirmedBar == pivot.pivotBar + 1 ||
      pivot.confirmedBar == pivot.pivotBar + 2;
   if(pivot.direction != setup.direction ||
      pivot.price <= 0.0 ||
      pivot.pivotBar <= setup.purgeBar ||
      pivot.pivotTime <= setup.purgeTime ||
      !validConfirmationDistance ||
      pivot.confirmedTime <= pivot.pivotTime ||
      pivot.confirmedBar > bar.index ||
      pivot.confirmedTime > bar.time)
      return false;

   setup.hasInternalPivot = true;
   setup.internalPivot = pivot.price;
   setup.internalPivotBar = pivot.pivotBar;
   setup.internalPivotTime = pivot.pivotTime;
   setup.internalPivotConfirmedBar = pivot.confirmedBar;
   setup.internalPivotConfirmedTime = pivot.confirmedTime;
   setup.phase = SBL_PHASE_WAIT_TARGET;
   return true;
}

bool SblExternalTargetSwept(const SblSetup &setup, const SblBar &bar)
{
   if(!setup.hasInternalPivot ||
      bar.index <= setup.internalPivotConfirmedBar ||
      bar.time <= setup.internalPivotConfirmedTime)
      return false;
   if(setup.direction == SBL_LONG)
      return bar.high > setup.refHigh;
   if(setup.direction == SBL_SHORT)
      return bar.low < setup.refLow;
   return false;
}

bool SblExternalTargetSweptBeforePivot(const SblSetup &setup,
                                       const SblBar &bar)
{
   if(setup.direction == SBL_LONG)
      return bar.high > setup.refHigh;
   if(setup.direction == SBL_SHORT)
      return bar.low < setup.refLow;
   return false;
}

void SblExposeTargetConsumption(const SblSetup &setup,
                                SblDecision &decision)
{
   decision.setupId = setup.id;
   decision.direction = setup.direction;
   decision.consumeTarget = true;
   decision.targetKey = setup.direction == SBL_LONG
                        ? setup.refHighTime : setup.refLowTime;
}

// La premiere prise de cible est un fait immuable. Cette centralisation evite
// qu'une meche ulterieure rehorodate la cible ou la reconsomme pendant que le
// setup flexible attend encore son pivot interne.
bool SblRecordTargetOnce(SblSetup &setup, const SblBar &bar,
                         SblDecision &decision)
{
   if(setup.targetTaken)
      return false;
   setup.targetTaken = true;
   setup.targetBar = bar.index;
   setup.targetTime = bar.time;
   setup.breakBar = bar.index;
   setup.breakTime = bar.time;
   SblExposeTargetConsumption(setup,decision);
   return true;
}

bool SblInternalMssCrossed(const SblSetup &setup, const SblBar &bar)
{
   if(!setup.hasInternalPivot || bar.previousClose <= 0.0)
      return false;
   if(setup.direction == SBL_LONG)
      return bar.previousClose <= setup.internalPivot &&
             bar.close > setup.internalPivot;
   if(setup.direction == SBL_SHORT)
      return bar.previousClose >= setup.internalPivot &&
             bar.close < setup.internalPivot;
   return false;
}

void SblClearPendingMss(SblSetup &setup)
{
   setup.hasPendingMss = false;
   setup.pendingMssBar = -1;
   setup.pendingMssTime = 0;
}

// Un MSS anticipe ne peut etre observe qu'apres la cloture ayant confirme le
// pivot interne. Les deux axes (index et temps) sont controles pour empecher
// qu'un buffer mal indexe ne rende un evenement futur retroactif.
bool SblBarAfterInternalPivotConfirmation(const SblSetup &setup,
                                           const SblBar &bar)
{
   return setup.hasInternalPivot &&
          bar.index > setup.internalPivotConfirmedBar &&
          bar.time > setup.internalPivotConfirmedTime &&
          bar.index > setup.purgeBar &&
          bar.time > setup.purgeTime;
}

// Memorise uniquement le premier vrai croisement. Les champs mssBar/mssTime
// restent reserves a un MSS confirme par la prise de cible externe.
bool SblStorePendingMss(SblSetup &setup, const SblBar &bar)
{
   if(setup.phase != SBL_PHASE_WAIT_TARGET || setup.hasPendingMss ||
      !SblBarAfterInternalPivotConfirmation(setup,bar) ||
      !SblInternalMssCrossed(setup,bar))
      return false;
   setup.hasPendingMss = true;
   setup.pendingMssBar = bar.index;
   setup.pendingMssTime = bar.time;
   return true;
}

bool SblPendingMssPrecedesTarget(const SblSetup &setup)
{
   return setup.hasPendingMss && setup.targetTaken &&
          setup.pendingMssBar > setup.internalPivotConfirmedBar &&
          setup.pendingMssTime > setup.internalPivotConfirmedTime &&
          setup.pendingMssBar > setup.purgeBar &&
          setup.pendingMssTime > setup.purgeTime &&
          setup.pendingMssBar < setup.targetBar &&
          setup.pendingMssTime < setup.targetTime;
}

bool SblPromotePendingMss(SblSetup &setup)
{
   if(!SblPendingMssPrecedesTarget(setup))
      return false;
   const int pendingBar = setup.pendingMssBar;
   const long pendingTime = setup.pendingMssTime;
   SblClearPendingMss(setup);
   setup.mssBar = pendingBar;
   setup.mssTime = pendingTime;
   return true;
}

bool SblTryTrigger(SblSetup &setup, const SblBar &bar,
                   bool inWindow, const SblConfig &config,
                   SblDecision &decision)
{
   if(bar.index <= setup.confirmationBar)
      return false;
   if(config.requireWindow && !inWindow)
      return false;
   // Une FVG de contexte reste obligatoire, quel que soit le mecanisme de
   // retracement retenu (CE, OTE ou EMA).
   if(!setup.hasContextFvg)
      return false;
   if(config.requireDirectionalRejection &&
      !SblDirectionalRejection(setup.direction,bar))
      return false;

   int trigger = SBL_TRIGGER_NONE;
   if(config.useFvgTrigger)
   {
      double ce = SblFvgConsequentEncroachment(setup.fvgLow,setup.fvgHigh);
      if(bar.low <= ce && bar.high >= ce)
         trigger = SBL_TRIGGER_FVG;
   }

   double oteZoneLow = 0.0;
   double oteZoneHigh = 0.0;
   SblOteBounds(setup.direction, setup.fib0, setup.fib1,
                config.oteLow, config.oteHigh,
                oteZoneLow, oteZoneHigh);
   if(trigger == SBL_TRIGGER_NONE && config.useOteTrigger &&
      SblRangesIntersect(bar.low, bar.high, oteZoneLow, oteZoneHigh))
      trigger = SBL_TRIGGER_OTE;

   if(trigger == SBL_TRIGGER_NONE && config.useEmaTrigger)
   {
      bool emaTriggered = config.requireDirectionalRejection
                          ? SblEmaTrigger(setup.direction,bar,
                                         setup.fib0,setup.fib1)
                          : SblEmaTouched(setup.direction,bar,
                                         setup.fib0,setup.fib1);
      if(emaTriggered)
         trigger = SBL_TRIGGER_EMA;
   }

   if(trigger == SBL_TRIGGER_NONE)
      return false;
   if(!SblPriceInValueArea(setup.direction, bar.close,
                           setup.fib0, setup.fib1))
      return false;

   setup.phase = SBL_PHASE_TRIGGERED;
   setup.trigger = trigger;
   setup.triggerBar = bar.index;
   setup.triggerTime = bar.time;
   setup.expectedEntry = bar.close;
   decision.signal = true;
   decision.setupId = setup.id;
   decision.direction = setup.direction;
   decision.trigger = trigger;
   decision.expectedEntry = bar.close;
   return true;
}

bool SblAdvanceSetup(SblSetup &setup, const SblBar &bar,
                     int alignedBias, const SblPivot &newPivot,
                     const SblFvg &newFvg,
                     bool inWindow, const SblConfig &config,
                     SblDecision &decision)
{
   SblResetDecision(decision);
   if(setup.phase == SBL_PHASE_INACTIVE ||
      setup.phase == SBL_PHASE_TRIGGERED ||
      setup.phase == SBL_PHASE_INVALID)
      return false;
   if(bar.index <= setup.lastProcessedBar ||
      bar.time <= setup.lastProcessedTime)
      return false;
   setup.lastProcessedBar = bar.index;
   setup.lastProcessedTime = bar.time;

   // Une cible externe est un fait de marche : elle doit etre exposee meme si
   // cette meme bougie fait perdre le biais, expire le setup ou sort de plage.
   bool targetBeforePivot =
      !setup.targetTaken &&
      setup.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT &&
      SblExternalTargetSweptBeforePivot(setup,bar);
   bool targetAfterPivot =
      !setup.targetTaken && setup.phase == SBL_PHASE_WAIT_TARGET &&
      SblExternalTargetSwept(setup,bar);
   if(targetBeforePivot || targetAfterPivot)
      SblRecordTargetOnce(setup,bar,decision);
   if(targetBeforePivot && !config.allowTargetBeforeInternalPivot)
   {
      SblClearPendingMss(setup);
      setup.phase = SBL_PHASE_INVALID;
      return false;
   }

   // Les fenetres sont obligatoires : un setup ne traverse jamais une borne,
   // une autre plage autorisee, ni un changement de date NY.
   if(!inWindow || !SblValidEntryWindowKey(bar.windowKey) ||
      bar.windowKey != setup.windowKey ||
      alignedBias != setup.direction ||
      SblSetupExpired(setup, bar, config) ||
      SblOriginInvalidated(setup, bar))
   {
      SblClearPendingMss(setup);
      setup.phase = SBL_PHASE_INVALID;
      return false;
   }

   if((setup.phase == SBL_PHASE_WAIT_CONFIRMATION ||
       setup.phase == SBL_PHASE_WAIT_RETRACEMENT) &&
      SblContextFvgInvalidated(setup, bar))
   {
      setup.phase = SBL_PHASE_INVALID;
      return false;
   }

   if(setup.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT ||
      setup.phase == SBL_PHASE_WAIT_TARGET ||
      setup.phase == SBL_PHASE_WAIT_MSS ||
      setup.phase == SBL_PHASE_WAIT_CONFIRMATION)
      SblInvalidateCandidateFvgs(setup,bar,config.maxFvgCandidates);

   if(setup.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT ||
      setup.phase == SBL_PHASE_WAIT_TARGET ||
      setup.phase == SBL_PHASE_WAIT_MSS ||
      setup.phase == SBL_PHASE_WAIT_CONFIRMATION)
   {
      if(setup.direction == SBL_LONG)
         setup.legExtreme = SblMax(setup.legExtreme,bar.high);
      else
         setup.legExtreme = SblMin(setup.legExtreme,bar.low);

      if(newFvg.formedBar <= bar.index && newFvg.formedTime <= bar.time)
         SblCacheCandidateFvg(setup,newFvg,config.maxFvgCandidates);
   }

   if(setup.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT)
   {
      if(!SblStoreInternalPivot(setup,newPivot,bar))
         return false;

      // En mode flexible, une cible deja memorisee permet d'attendre le MSS
      // des la confirmation du pivot. Elle ne rend toutefois jamais causal un
      // croisement observe sur la bougie meme qui confirme ce pivot.
      if(setup.targetTaken)
         setup.phase = SBL_PHASE_WAIT_MSS;
      if(bar.index <= setup.internalPivotConfirmedBar ||
         bar.time <= setup.internalPivotConfirmedTime)
         return false;
   }

   if(setup.phase == SBL_PHASE_WAIT_TARGET)
   {
      bool targetSwept = targetAfterPivot;
      if(!targetSwept)
      {
         if(!SblInternalMssCrossed(setup,bar))
            return false;
         if(config.allowMssBeforeTarget)
         {
            SblStorePendingMss(setup,bar);
            return false;
         }

         // Mode strict historique : tout MSS precedant la cible invalide.
         SblClearPendingMss(setup);
         setup.phase = SBL_PHASE_INVALID;
         return false;
      }
      if(config.allowMssBeforeTarget && SblPromotePendingMss(setup))
         setup.phase = SBL_PHASE_WAIT_CONFIRMATION;
      else
      {
         // Un pending incomplet ou non causal ne doit jamais etre promu. Le
         // croisement de la bougie cible reste evaluable juste en dessous.
         SblClearPendingMss(setup);
         setup.phase = SBL_PHASE_WAIT_MSS;
      }
   }

   // Target et MSS peuvent etre confirmes par la meme bougie, a condition
   // que le pivot interne ait ete confirme sur une bougie anterieure.
   if(setup.phase == SBL_PHASE_WAIT_MSS)
   {
      if(!SblInternalMssCrossed(setup,bar))
         return false;
      setup.mssBar = bar.index;
      setup.mssTime = bar.time;
      setup.phase = SBL_PHASE_WAIT_CONFIRMATION;
   }

   if(setup.phase == SBL_PHASE_WAIT_CONFIRMATION)
   {
      double displacement = SblAbs(setup.legExtreme - setup.fib0);
      if(displacement < config.minDisplacement)
         return false;
      if(!setup.hasContextFvg &&
         !SblPromoteCandidateFvg(setup,config.maxFvgCandidates))
         return false;
      setup.fib1 = setup.legExtreme;
      setup.equilibrium = (setup.fib0 + setup.fib1) * 0.5;
      setup.confirmationBar = bar.index;
      setup.confirmationTime = bar.time;
      setup.phase = SBL_PHASE_WAIT_RETRACEMENT;
      return false;
   }

   if(setup.phase == SBL_PHASE_WAIT_RETRACEMENT)
      return SblTryTrigger(setup, bar, inWindow, config, decision);
   return false;
}

// Surcharge de transition : les anciens adaptateurs compilent, mais aucun
// pivot implicite n'est fabrique. Ils doivent migrer vers la surcharge claire
// ci-dessus pour pouvoir faire progresser un nouveau setup.
bool SblAdvanceSetup(SblSetup &setup, const SblBar &bar,
                     int alignedBias, const SblFvg &newFvg,
                     bool inWindow, const SblConfig &config,
                     SblDecision &decision)
{
   SblPivot noPivot;
   SblResetPivot(noPivot);
   return SblAdvanceSetup(setup,bar,alignedBias,noPivot,newFvg,
                          inWindow,config,decision);
}

#endif
