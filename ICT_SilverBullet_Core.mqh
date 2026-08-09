#ifndef ICT_SILVER_BULLET_CORE_MQH
#define ICT_SILVER_BULLET_CORE_MQH

// Moteur deterministe et sans dependance MT5.
// Ce fichier est inclus par l'EA, l'indicateur et les tests C++.

#define SBL_MAX_CONSUMED 512

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

// Pivot interne strict : deux bougies a gauche et deux a droite.
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
   bool   requireWindow;
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

void SblDetectInternalPivot(int direction,
                            const SblBar &twoBefore,
                            const SblBar &oneBefore,
                            const SblBar &candidate,
                            const SblBar &oneAfter,
                            const SblBar &twoAfter,
                            SblPivot &pivot)
{
   SblResetPivot(pivot);
   if(oneBefore.index != twoBefore.index + 1 ||
      candidate.index != oneBefore.index + 1 ||
      oneAfter.index != candidate.index + 1 ||
      twoAfter.index != oneAfter.index + 1 ||
      oneBefore.time <= twoBefore.time ||
      candidate.time <= oneBefore.time ||
      oneAfter.time <= candidate.time ||
      twoAfter.time <= oneAfter.time)
      return;

   bool present = false;
   double price = 0.0;
   if(direction == SBL_LONG)
   {
      present = candidate.high > twoBefore.high &&
                candidate.high > oneBefore.high &&
                candidate.high > oneAfter.high &&
                candidate.high > twoAfter.high;
      price = candidate.high;
   }
   else if(direction == SBL_SHORT)
   {
      present = candidate.low < twoBefore.low &&
                candidate.low < oneBefore.low &&
                candidate.low < oneAfter.low &&
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
   pivot.confirmedBar = twoAfter.index;
   pivot.confirmedTime = twoAfter.time;
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
   if(bar.emaFast <= 0.0 || !SblPriceInValueArea(direction, bar.emaFast, fib0, fib1))
      return false;
   if(bar.low > bar.emaFast || bar.high < bar.emaFast)
      return false;
   if(direction == SBL_LONG)
      return bar.close >= bar.emaFast && bar.close > bar.open;
   if(direction == SBL_SHORT)
      return bar.close <= bar.emaFast && bar.close < bar.open;
   return false;
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

void SblClearCandidateFvg(SblSetup &setup)
{
   setup.hasCandidateFvg = false;
   setup.candidateFvgLow = 0.0;
   setup.candidateFvgHigh = 0.0;
   setup.candidateFvgBar = -1;
   setup.candidateFvgTime = 0;
}

bool SblCacheCandidateFvg(SblSetup &setup, const SblFvg &fvg)
{
   if(!fvg.present || fvg.direction != setup.direction ||
      fvg.formedBar <= setup.purgeBar + 2 ||
      fvg.formedTime <= setup.purgeTime)
      return false;

   double low = SblMin(fvg.low, fvg.high);
   double high = SblMax(fvg.low, fvg.high);

   bool replace = !setup.hasCandidateFvg;
   if(setup.hasCandidateFvg)
   {
      bool currentInValue = SblFvgInValueArea(setup.direction,
                                               setup.candidateFvgLow,
                                               setup.candidateFvgHigh,
                                               setup.fib0,
                                               setup.legExtreme);
      bool newInValue = SblFvgInValueArea(setup.direction,low,high,
                                           setup.fib0,
                                           setup.legExtreme);
      if(newInValue != currentInValue)
         replace = newInValue;
      else if(setup.direction == SBL_LONG)
         replace = high < setup.candidateFvgHigh;
      else
         replace = low > setup.candidateFvgLow;
   }

   if(!replace)
      return true;
   setup.hasCandidateFvg = true;
   setup.candidateFvgLow = low;
   setup.candidateFvgHigh = high;
   setup.candidateFvgBar = fvg.formedBar;
   setup.candidateFvgTime = fvg.formedTime;
   return true;
}

void SblStoreContextFvg(SblSetup &setup, const SblFvg &fvg)
{
   setup.hasContextFvg = true;
   setup.fvgLow = SblMin(fvg.low, fvg.high);
   setup.fvgHigh = SblMax(fvg.low, fvg.high);
   setup.fvgBar = fvg.formedBar;
   setup.fvgTime = fvg.formedTime;
}

bool SblPromoteCandidateFvg(SblSetup &setup)
{
   if(!setup.hasCandidateFvg ||
      !SblFvgInValueArea(setup.direction,
                         setup.candidateFvgLow,
                         setup.candidateFvgHigh,
                         setup.fib0,setup.legExtreme))
      return false;

   setup.hasContextFvg = true;
   setup.fvgLow = setup.candidateFvgLow;
   setup.fvgHigh = setup.candidateFvgHigh;
   setup.fvgBar = setup.candidateFvgBar;
   setup.fvgTime = setup.candidateFvgTime;
   SblClearCandidateFvg(setup);
   return true;
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
   if(!pivot.present || pivot.direction != setup.direction ||
      pivot.price <= 0.0 ||
      pivot.pivotBar <= setup.purgeBar ||
      pivot.pivotTime <= setup.purgeTime ||
      pivot.confirmedBar != pivot.pivotBar + 2 ||
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

bool SblTryTrigger(SblSetup &setup, const SblBar &bar,
                   bool inWindow, const SblConfig &config,
                   SblDecision &decision)
{
   if(bar.index <= setup.confirmationBar)
      return false;
   if(config.requireWindow && !inWindow)
      return false;
   if(!SblDirectionalRejection(setup.direction, bar))
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

   if(trigger == SBL_TRIGGER_NONE && config.useEmaTrigger &&
      SblEmaTrigger(setup.direction, bar, setup.fib0, setup.fib1))
      trigger = SBL_TRIGGER_EMA;

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
      setup.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT &&
      SblExternalTargetSweptBeforePivot(setup,bar);
   bool targetAfterPivot =
      setup.phase == SBL_PHASE_WAIT_TARGET &&
      SblExternalTargetSwept(setup,bar);
   if(targetBeforePivot || targetAfterPivot)
   {
      setup.targetTaken = true;
      setup.targetBar = bar.index;
      setup.targetTime = bar.time;
      setup.breakBar = bar.index;
      setup.breakTime = bar.time;
      SblExposeTargetConsumption(setup,decision);
   }
   if(targetBeforePivot)
   {
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

   if((setup.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT ||
       setup.phase == SBL_PHASE_WAIT_TARGET ||
       setup.phase == SBL_PHASE_WAIT_MSS ||
       setup.phase == SBL_PHASE_WAIT_CONFIRMATION) &&
      SblCandidateFvgInvalidated(setup,bar))
      SblClearCandidateFvg(setup);

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
         SblCacheCandidateFvg(setup,newFvg);
   }

   if(setup.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT)
   {
      if(!SblStoreInternalPivot(setup,newPivot,bar))
         return false;
      // Le pivot n'est connu qu'a la cloture de sa deuxieme bougie droite :
      // cette meme bougie ne peut pas retroactivement prendre le target.
      if(bar.index <= setup.internalPivotConfirmedBar ||
         bar.time <= setup.internalPivotConfirmedTime)
         return false;
   }

   if(setup.phase == SBL_PHASE_WAIT_TARGET)
   {
      bool targetSwept = targetAfterPivot;
      if(!targetSwept && SblInternalMssCrossed(setup,bar))
      {
         // Le MSS n'est causal que s'il suit la prise de cible externe.
         setup.phase = SBL_PHASE_INVALID;
         return false;
      }
      if(!targetSwept)
         return false;
      setup.targetTaken = true;
      setup.targetBar = bar.index;
      setup.targetTime = bar.time;
      setup.breakBar = bar.index;
      setup.breakTime = bar.time;
      setup.phase = SBL_PHASE_WAIT_MSS;
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
      if(!setup.hasContextFvg && !SblPromoteCandidateFvg(setup))
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
