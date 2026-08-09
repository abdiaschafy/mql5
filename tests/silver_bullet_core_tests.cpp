#include "../ICT_SilverBullet_Core.mqh"

#include <cmath>
#include <functional>
#include <iostream>
#include <string>
#include <vector>

namespace
{
int g_assertions = 0;
int g_failures = 0;

void Check(bool condition, const char *expression, const char *file, int line)
{
   ++g_assertions;
   if(condition)
      return;
   ++g_failures;
   std::cerr << file << ':' << line << ": CHECK failed: " << expression << '\n';
}

void CheckNear(double actual, double expected, double tolerance,
               const char *actualExpression, const char *expectedExpression,
               const char *file, int line)
{
   ++g_assertions;
   if(std::fabs(actual - expected) <= tolerance)
      return;
   ++g_failures;
   std::cerr << file << ':' << line << ": CHECK_NEAR failed: "
             << actualExpression << '=' << actual << ", "
             << expectedExpression << '=' << expected
             << ", tolerance=" << tolerance << '\n';
}

#define CHECK(expression) Check((expression), #expression, __FILE__, __LINE__)
#define CHECK_NEAR(actual, expected, tolerance) \
   CheckNear((actual), (expected), (tolerance), #actual, #expected, __FILE__, __LINE__)

const int NY_DATE = 20260809;
const long LONDON_KEY = 202608091L;
const long NEW_YORK_KEY = 202608092L;

SblBar Bar(int index, double open, double high, double low, double close,
           double previousClose, double emaFast = 0.0, long time = 0,
           long windowKey = LONDON_KEY)
{
   SblBar bar;
   bar.time = time > 0 ? time : 100000L + static_cast<long>(index) * 60L;
   bar.index = index;
   bar.open = open;
   bar.high = high;
   bar.low = low;
   bar.close = close;
   bar.emaFast = emaFast;
   bar.previousClose = previousClose;
   bar.windowKey = windowKey;
   return bar;
}

SblPivot NoPivot()
{
   SblPivot pivot;
   SblResetPivot(pivot);
   return pivot;
}

SblPivot Pivot(int direction, int pivotBar, int confirmedBar, double price)
{
   SblPivot pivot;
   pivot.present = true;
   pivot.direction = direction;
   pivot.price = price;
   pivot.pivotBar = pivotBar;
   pivot.pivotTime = 100000L + static_cast<long>(pivotBar) * 60L;
   pivot.confirmedBar = confirmedBar;
   pivot.confirmedTime = 100000L + static_cast<long>(confirmedBar) * 60L;
   return pivot;
}

SblFvg NoFvg()
{
   SblFvg fvg;
   SblResetFvg(fvg);
   return fvg;
}

SblFvg Fvg(int direction, int formedBar, double low, double high)
{
   SblFvg fvg;
   fvg.present = true;
   fvg.direction = direction;
   fvg.formedBar = formedBar;
   fvg.formedTime = 100000L + static_cast<long>(formedBar) * 60L;
   fvg.low = low;
   fvg.high = high;
   return fvg;
}

SblConfig Config()
{
   SblConfig config;
   config.minDisplacement = 20.0;
   config.minFvgSize = 1.0;
   config.oteLow = 0.62;
   config.oteHigh = 0.79;
   config.expiryBars = 30;
   config.requireWindow = true;
   config.useFvgTrigger = true;
   config.useOteTrigger = true;
   config.useEmaTrigger = true;
   return config;
}

SblSetup StartedLong(int id = 1)
{
   SblSetup setup;
   SblResetSetup(setup);
   SblDecision decision;
   const SblBar purge = Bar(10, 102.0, 104.0, 99.0, 101.0, 101.5);
   CHECK(SblStartSetup(setup, id, SBL_LONG, purge,
                       120.0, 90000L, 100.0, 90100L, decision));
   return setup;
}

SblSetup StartedShort(int id = 2)
{
   SblSetup setup;
   SblResetSetup(setup);
   SblDecision decision;
   const SblBar purge = Bar(10, 118.0, 121.0, 116.0, 119.0, 118.5);
   CHECK(SblStartSetup(setup, id, SBL_SHORT, purge,
                       120.0, 90000L, 100.0, 90100L, decision));
   return setup;
}

void LockLongPivot(SblSetup &setup, const SblConfig &config,
                   const SblFvg &candidate = Fvg(SBL_LONG, 13, 104.0, 108.0))
{
   SblDecision decision;
   const SblBar twoBefore = Bar(9, 104.0, 106.0, 102.0, 104.0, 103.0);
   const SblBar oneBefore = Bar(10, 102.0, 104.0, 99.0, 101.0, 101.5);
   const SblBar pivotBar = Bar(11, 104.0, 110.0, 103.0, 108.0, 101.0);
   const SblBar oneAfter = Bar(12, 108.0, 108.5, 104.0, 108.0, 108.0);
   const SblBar confirmation = Bar(13, 108.0, 109.0, 106.0, 109.0, 108.0);
   SblPivot detected;
   SblDetectInternalPivot(SBL_LONG,twoBefore,oneBefore,pivotBar,
                          oneAfter,confirmation,detected);
   CHECK(detected.present);
   CHECK(!SblAdvanceSetup(setup, confirmation, SBL_LONG,
                          detected, candidate,
                          true, config, decision));
   CHECK(setup.phase == SBL_PHASE_WAIT_TARGET);
   CHECK(setup.hasInternalPivot);
}

void LockShortPivot(SblSetup &setup, const SblConfig &config,
                    const SblFvg &candidate = Fvg(SBL_SHORT, 13, 112.0, 116.0))
{
   SblDecision decision;
   const SblBar twoBefore = Bar(9, 114.0, 118.0, 114.0, 116.0, 115.0);
   const SblBar oneBefore = Bar(10, 118.0, 121.0, 116.0, 119.0, 118.5);
   const SblBar pivotBar = Bar(11, 115.0, 116.0, 110.0, 112.0, 119.0);
   const SblBar oneAfter = Bar(12, 112.0, 116.0, 112.0, 112.0, 112.0);
   const SblBar confirmation = Bar(13, 112.0, 115.0, 111.0, 111.0, 112.0);
   SblPivot detected;
   SblDetectInternalPivot(SBL_SHORT,twoBefore,oneBefore,pivotBar,
                          oneAfter,confirmation,detected);
   CHECK(detected.present);
   CHECK(!SblAdvanceSetup(setup, confirmation, SBL_SHORT,
                          detected, candidate,
                          true, config, decision));
   CHECK(setup.phase == SBL_PHASE_WAIT_TARGET);
   CHECK(setup.hasInternalPivot);
}

void ConfirmLong(SblSetup &setup, const SblConfig &config,
                 const SblFvg &candidate = Fvg(SBL_LONG, 13, 104.0, 108.0))
{
   LockLongPivot(setup, config, candidate);
   SblDecision decision;
   const SblBar targetAndMss = Bar(14, 109.0, 125.0, 107.0, 112.0, 109.0);
   CHECK(!SblAdvanceSetup(setup, targetAndMss, SBL_LONG, NoPivot(), NoFvg(),
                          true, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == setup.refHighTime);
   CHECK(setup.phase == SBL_PHASE_WAIT_RETRACEMENT);
}

void ConfirmShort(SblSetup &setup, const SblConfig &config,
                  const SblFvg &candidate = Fvg(SBL_SHORT, 13, 112.0, 116.0))
{
   LockShortPivot(setup, config, candidate);
   SblDecision decision;
   const SblBar targetAndMss = Bar(14, 111.0, 113.0, 95.0, 108.0, 111.0);
   CHECK(!SblAdvanceSetup(setup, targetAndMss, SBL_SHORT, NoPivot(), NoFvg(),
                          true, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == setup.refLowTime);
   CHECK(setup.phase == SBL_PHASE_WAIT_RETRACEMENT);
}

void TestStrictStackAndAlignment()
{
   CHECK(SblStrictStack(120.0, 110.0, 100.0) == SBL_LONG);
   CHECK(SblStrictStack(80.0, 90.0, 100.0) == SBL_SHORT);
   CHECK(SblStrictStack(110.0, 110.0, 100.0) == SBL_NEUTRAL);
   CHECK(SblStrictStack(120.0, 100.0, 100.0) == SBL_NEUTRAL);
   CHECK(SblStrictStack(0.0, 110.0, 100.0) == SBL_NEUTRAL);
   CHECK(SblAlignedBias(SBL_LONG, SBL_LONG, SBL_LONG, SBL_LONG) == SBL_LONG);
   CHECK(SblAlignedBias(SBL_SHORT, SBL_SHORT, SBL_SHORT, SBL_SHORT) == SBL_SHORT);
   CHECK(SblAlignedBias(SBL_LONG, SBL_LONG, SBL_NEUTRAL, SBL_LONG) == SBL_NEUTRAL);
   CHECK(SblAlignedBias(SBL_SHORT, SBL_SHORT, SBL_SHORT, SBL_LONG) == SBL_NEUTRAL);
}

void TestEntryWindowsAndIdentity()
{
   int accepted = 0;
   for(int minute = 0; minute < 24 * 60; ++minute)
   {
      const int expectedId = minute >= 120 && minute < 300 ? 1
                           : minute >= 420 && minute < 600 ? 2
                           : minute >= 1140 && minute < 1320 ? 3 : 0;
      CHECK(SblEntryWindowId(minute) == expectedId);
      CHECK(SblInEntryWindowMinutes(minute) == (expectedId != 0));
      if(expectedId != 0)
         ++accepted;
   }
   CHECK(accepted == 540);
   CHECK(SblEntryWindowId(-1) == 0);
   CHECK(SblEntryWindowId(1440) == 0);
   CHECK(!SblInEntryWindowMinutes(119));
   CHECK(SblInEntryWindowMinutes(120));
   CHECK(SblInEntryWindowMinutes(299));
   CHECK(!SblInEntryWindowMinutes(300));
   CHECK(SblInEntryWindowMinutes(420));
   CHECK(!SblInEntryWindowMinutes(600));
   CHECK(SblInEntryWindowMinutes(1140));
   CHECK(!SblInEntryWindowMinutes(1320));
   CHECK(SblEntryWindowKey(NY_DATE, 120) == LONDON_KEY);
   CHECK(SblEntryWindowKey(NY_DATE, 420) == NEW_YORK_KEY);
   CHECK(SblEntryWindowKey(NY_DATE, 1140) == 202608093L);
   CHECK(SblEntryWindowKey(NY_DATE, 300) == 0L);
   CHECK(SblEntryWindowKey(0, 120) == 0L);
   CHECK(SblEntryWindowKey(NY_DATE + 1, 120) != LONDON_KEY);
   CHECK(SblValidEntryWindowKey(LONDON_KEY));
   CHECK(SblValidEntryWindowKey(202402291L));
   CHECK(!SblValidEntryWindowKey(11L));
   CHECK(!SblValidEntryWindowKey(202602291L));
   CHECK(!SblValidEntryWindowKey(202602301L));
   CHECK(!SblValidEntryWindowKey(202613011L));
   CHECK(!SblValidEntryWindowKey(202608094L));
}

void TestDstBoundaries2026()
{
   CHECK(!SblIsUsDstUtcFields(3, 8, 6 * 60 + 59, 0));
   CHECK(SblIsUsDstUtcFields(3, 8, 7 * 60, 0));
   CHECK(SblNewYorkUtcOffsetSeconds(3, 8, 6 * 60 + 59, 0, true, -9) == -5 * 3600);
   CHECK(SblNewYorkUtcOffsetSeconds(3, 8, 7 * 60, 0, true, -9) == -4 * 3600);
   CHECK(SblIsUsDstUtcFields(11, 1, 5 * 60 + 59, 0));
   CHECK(!SblIsUsDstUtcFields(11, 1, 6 * 60, 0));
   CHECK(SblNewYorkUtcOffsetSeconds(11, 1, 5 * 60 + 59, 0, true, -9) == -4 * 3600);
   CHECK(SblNewYorkUtcOffsetSeconds(11, 1, 6 * 60, 0, true, -9) == -5 * 3600);

   CHECK(!SblIsEuropeDstUtcFields(3, 29, 59, 0));
   CHECK(SblIsEuropeDstUtcFields(3, 29, 60, 0));
   CHECK(SblBrokerUtcOffsetSeconds(SBL_BROKER_DST_EUROPE, 2,
                                   3, 29, 59, 0) == 2 * 3600);
   CHECK(SblBrokerUtcOffsetSeconds(SBL_BROKER_DST_EUROPE, 2,
                                   3, 29, 60, 0) == 3 * 3600);
   CHECK(SblIsEuropeDstUtcFields(10, 25, 59, 0));
   CHECK(!SblIsEuropeDstUtcFields(10, 25, 60, 0));
}

void TestPurgeRequiresClosedReintegration()
{
   SblSetup setup;
   SblResetSetup(setup);
   SblDecision decision;
   CHECK(SblStartSetup(setup, 1, SBL_LONG,
                       Bar(10, 102.0, 104.0, 99.0, 101.0, 101.5),
                       120.0, 90000L, 100.0, 90100L, decision));
   CHECK(setup.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT);
   CHECK_NEAR(setup.fib0, 99.0, 1e-12);
   CHECK(setup.windowKey == LONDON_KEY);

   CHECK(!SblStartSetup(setup, 2, SBL_LONG,
                        Bar(10, 102.0, 104.0, 99.0, 99.5, 101.5),
                        120.0, 90000L, 100.0, 90100L, decision));
   CHECK(!SblStartSetup(setup, 3, SBL_LONG,
                        Bar(10, 102.0, 104.0, 99.0, 100.0, 101.5),
                        120.0, 90000L, 100.0, 90100L, decision));
   CHECK(!SblStartSetup(setup, 4, SBL_LONG,
                        Bar(10, 102.0, 104.0, 100.0, 101.0, 101.5),
                        120.0, 90000L, 100.0, 90100L, decision));
   // La norme porte sur la meche et la cloture de reintegration. Dans les
   // adaptateurs, une prise anterieure est bloquee par le registre consomme,
   // pas par une troisieme condition implicite sur PreviousClose.
   CHECK(SblStartSetup(setup, 5, SBL_LONG,
                       Bar(10, 102.0, 104.0, 99.0, 101.0, 99.0),
                       120.0, 90000L, 100.0, 90100L, decision));
   CHECK(!SblStartSetup(setup, 6, SBL_LONG,
                        Bar(10, 102.0, 104.0, 99.0, 101.0, 101.5,
                            0.0, 0, 0),
                        120.0, 90000L, 100.0, 90100L, decision));

   CHECK(SblStartSetup(setup, 7, SBL_SHORT,
                       Bar(10, 118.0, 121.0, 116.0, 119.0, 118.5),
                       120.0, 90000L, 100.0, 90100L, decision));
   CHECK_NEAR(setup.fib0, 121.0, 1e-12);
   CHECK(!SblStartSetup(setup, 8, SBL_SHORT,
                        Bar(10, 118.0, 121.0, 116.0, 120.0, 118.5),
                        120.0, 90000L, 100.0, 90100L, decision));
   CHECK(!SblStartSetup(setup, 9, SBL_SHORT,
                        Bar(10, 118.0, 120.0, 116.0, 119.0, 118.5),
                        120.0, 90000L, 100.0, 90100L, decision));

   CHECK(!SblStartSetup(setup, 10, SBL_LONG,
                        Bar(10, 102.0, 121.0, 99.0, 101.0, 101.5),
                        120.0, 90000L, 100.0, 90100L, decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == 90000L);
   CHECK(!SblStartSetup(setup, 11, SBL_SHORT,
                        Bar(10, 118.0, 121.0, 99.0, 119.0, 118.5),
                        120.0, 90000L, 100.0, 90100L, decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == 90100L);
}

void TestInternalPivotDetection()
{
   const SblBar longA = Bar(11, 100.0, 104.0, 98.0, 102.0, 101.0);
   const SblBar longB = Bar(12, 102.0, 106.0, 99.0, 104.0, 102.0);
   const SblBar longC = Bar(13, 104.0, 110.0, 99.5, 105.0, 104.0);
   const SblBar longD = Bar(14, 105.0, 108.0, 100.0, 104.0, 105.0);
   const SblBar longE = Bar(15, 104.0, 107.0, 101.0, 103.0, 104.0);
   SblPivot longPivot;
   SblPivot oppositePivot;
   SblDetectInternalPivot(SBL_LONG, longA, longB, longC, longD, longE,
                          longPivot);
   CHECK(longPivot.present);
   CHECK(longPivot.direction == SBL_LONG);
   CHECK_NEAR(longPivot.price, 110.0, 1e-12);
   CHECK(longPivot.pivotBar == 13);
   CHECK(longPivot.confirmedBar == 15);
   SblDetectInternalPivot(SBL_SHORT, longA, longB, longC, longD, longE,
                          oppositePivot);
   CHECK(!oppositePivot.present);

   const SblBar shortA = Bar(21, 105.0, 108.0, 101.0, 104.0, 105.0);
   const SblBar shortB = Bar(22, 104.0, 107.0, 100.0, 103.0, 104.0);
   const SblBar shortC = Bar(23, 102.0, 106.0, 97.0, 99.0, 103.0);
   const SblBar shortD = Bar(24, 99.0, 109.0, 99.0, 104.0, 99.0);
   const SblBar shortE = Bar(25, 104.0, 108.0, 100.0, 105.0, 104.0);
   SblPivot shortPivot;
   SblDetectInternalPivot(SBL_SHORT, shortA, shortB, shortC, shortD, shortE,
                          shortPivot);
   CHECK(shortPivot.present);
   CHECK(shortPivot.direction == SBL_SHORT);
   CHECK_NEAR(shortPivot.price, 97.0, 1e-12);
   SblDetectInternalPivot(SBL_LONG, shortA, shortB, shortC, shortD, shortE,
                          oppositePivot);
   CHECK(!oppositePivot.present);

   const SblBar equalHigh = Bar(13, 104.0, 108.0, 99.5, 105.0, 104.0);
   SblDetectInternalPivot(SBL_LONG, longA, longB, equalHigh, longD, longE,
                          oppositePivot);
   CHECK(!oppositePivot.present);
   const SblBar equalLow = Bar(23, 102.0, 106.0, 99.0, 99.0, 103.0);
   SblDetectInternalPivot(SBL_SHORT, shortA, shortB, equalLow, shortD, shortE,
                          oppositePivot);
   CHECK(!oppositePivot.present);
   SblDetectInternalPivot(SBL_NEUTRAL, longA, longB, longC, longD, longE,
                          oppositePivot);
   CHECK(!oppositePivot.present);

   // Une outside bar stricte des deux cotes ne doit devenir ni pivot high,
   // ni pivot low : les deux liquidites partageraient sinon la meme cle temps.
   const SblBar dualA = Bar(31, 100.0, 104.0, 98.0, 102.0, 101.0);
   const SblBar dualB = Bar(32, 102.0, 106.0, 100.0, 104.0, 102.0);
   const SblBar dualC = Bar(33, 104.0, 110.0, 97.0, 105.0, 104.0);
   const SblBar dualD = Bar(34, 105.0, 108.0, 99.0, 104.0, 105.0);
   const SblBar dualE = Bar(35, 104.0, 107.0, 100.0, 103.0, 104.0);
   SblPivot dualHigh;
   SblPivot dualLow;
   SblDetectInternalPivot(SBL_LONG, dualA, dualB, dualC, dualD, dualE,
                          dualHigh);
   SblDetectInternalPivot(SBL_SHORT, dualA, dualB, dualC, dualD, dualE,
                          dualLow);
   CHECK(dualHigh.present);
   CHECK(dualLow.present);
   SblRejectAmbiguousDualPivot(dualHigh,dualLow);
   CHECK(!dualHigh.present);
   CHECK(!dualLow.present);

   SblSetup setup = StartedLong();
   SblDecision decision;
   const SblPivot oldPivot = Pivot(SBL_LONG, 10, 12, 110.0);
   CHECK(!SblAdvanceSetup(setup,
                          Bar(13, 108.0, 115.0, 106.0, 109.0, 108.0),
                          SBL_LONG, oldPivot, NoFvg(), true, Config(), decision));
   CHECK(setup.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT);
   CHECK(!setup.hasInternalPivot);
}

void TestFvgDetectionAndCeValueArea()
{
   SblFvg fvg;
   SblDetectFvg(Bar(3, 107.0, 110.0, 106.0, 109.0, 107.0),
                Bar(1, 102.0, 105.0, 100.0, 103.0, 102.0), 1.0, fvg);
   CHECK(fvg.present);
   CHECK(fvg.direction == SBL_LONG);
   CHECK_NEAR(fvg.low, 105.0, 1e-12);
   CHECK_NEAR(fvg.high, 106.0, 1e-12);

   SblDetectFvg(Bar(6, 103.0, 105.0, 100.0, 101.0, 103.0),
                Bar(4, 108.0, 110.0, 106.0, 107.0, 108.0), 1.0, fvg);
   CHECK(fvg.present);
   CHECK(fvg.direction == SBL_SHORT);
   CHECK_NEAR(fvg.low, 105.0, 1e-12);
   CHECK_NEAR(fvg.high, 106.0, 1e-12);

   CHECK_NEAR(SblFvgConsequentEncroachment(109.0, 111.0), 110.0, 1e-12);
   CHECK(SblFvgInValueArea(SBL_LONG, 109.0, 111.0, 100.0, 120.0));
   CHECK(SblFvgInValueArea(SBL_LONG, 98.0, 110.0, 100.0, 120.0));
   CHECK(!SblFvgInValueArea(SBL_LONG, 110.0, 112.0, 100.0, 120.0));
   CHECK(!SblFvgInValueArea(SBL_LONG, 98.0, 101.0, 100.0, 120.0));
   CHECK(SblFvgInValueArea(SBL_SHORT, 109.0, 111.0, 120.0, 100.0));
   CHECK(SblFvgInValueArea(SBL_SHORT, 110.0, 122.0, 120.0, 100.0));
   CHECK(!SblFvgInValueArea(SBL_SHORT, 108.0, 110.0, 120.0, 100.0));
   CHECK(!SblFvgInValueArea(SBL_SHORT, 121.0, 123.0, 120.0, 100.0));
}

void TestValidLongAndShortMachines()
{
   const SblConfig config = Config();
   SblDecision decision;

   SblSetup longSetup = StartedLong(41);
   ConfirmLong(longSetup, config);
   CHECK(longSetup.targetTaken);
   CHECK(longSetup.targetBar == 14);
   CHECK(longSetup.mssBar == 14);
   CHECK_NEAR(longSetup.internalPivot, 110.0, 1e-12);
   CHECK_NEAR(longSetup.fib0, 99.0, 1e-12);
   CHECK_NEAR(longSetup.fib1, 125.0, 1e-12);
   CHECK_NEAR(longSetup.equilibrium, 112.0, 1e-12);
   CHECK(SblAdvanceSetup(longSetup,
                         Bar(15, 105.0, 108.0, 104.0, 107.0, 112.0, 106.0),
                         SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.signal);
   CHECK(decision.setupId == 41);
   CHECK(decision.trigger == SBL_TRIGGER_FVG);
   CHECK(longSetup.phase == SBL_PHASE_TRIGGERED);
   CHECK(!SblAdvanceSetup(longSetup,
                          Bar(16, 106.0, 108.0, 105.0, 107.0, 107.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(!decision.signal);

   SblSetup shortSetup = StartedShort(42);
   ConfirmShort(shortSetup, config);
   CHECK(shortSetup.targetTaken);
   CHECK(shortSetup.mssBar == 14);
   CHECK_NEAR(shortSetup.internalPivot, 110.0, 1e-12);
   CHECK_NEAR(shortSetup.fib0, 121.0, 1e-12);
   CHECK_NEAR(shortSetup.fib1, 95.0, 1e-12);
   CHECK_NEAR(shortSetup.equilibrium, 108.0, 1e-12);
   CHECK(SblAdvanceSetup(shortSetup,
                         Bar(15, 115.0, 116.0, 112.0, 114.0, 108.0, 114.5),
                         SBL_SHORT, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.signal);
   CHECK(decision.setupId == 42);
   CHECK(decision.trigger == SBL_TRIGGER_FVG);
}

void TestTargetAndMssChronology()
{
   const SblConfig config = Config();
   SblDecision decision;

   SblSetup targetBeforePivot = StartedLong();
   CHECK(!SblAdvanceSetup(targetBeforePivot,
                          Bar(11, 108.0, 121.0, 105.0, 109.0, 101.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == targetBeforePivot.refHighTime);
   CHECK(targetBeforePivot.phase == SBL_PHASE_INVALID);

   SblSetup targetAtPivotConfirmation = StartedLong();
   CHECK(!SblAdvanceSetup(targetAtPivotConfirmation,
                          Bar(13, 108.0, 121.0, 106.0, 109.0, 108.0),
                          SBL_LONG, Pivot(SBL_LONG, 11, 13, 110.0), NoFvg(),
                          true, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(targetAtPivotConfirmation.phase == SBL_PHASE_INVALID);

   SblSetup shortTargetBeforePivot = StartedShort();
   CHECK(!SblAdvanceSetup(shortTargetBeforePivot,
                          Bar(11, 111.0, 119.0, 99.0, 110.0, 119.0),
                          SBL_SHORT, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == shortTargetBeforePivot.refLowTime);
   CHECK(shortTargetBeforePivot.phase == SBL_PHASE_INVALID);

   SblSetup longTargetEquality = StartedLong();
   LockLongPivot(longTargetEquality, config, NoFvg());
   CHECK(!SblAdvanceSetup(longTargetEquality,
                          Bar(14, 109.0, 120.0, 107.0, 109.5, 109.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(!decision.consumeTarget);
   CHECK(longTargetEquality.phase == SBL_PHASE_WAIT_TARGET);

   SblSetup shortTargetEquality = StartedShort();
   LockShortPivot(shortTargetEquality, config, NoFvg());
   CHECK(!SblAdvanceSetup(shortTargetEquality,
                          Bar(14, 111.0, 113.0, 100.0, 110.5, 111.0),
                          SBL_SHORT, NoPivot(), NoFvg(), true, config, decision));
   CHECK(!decision.consumeTarget);
   CHECK(shortTargetEquality.phase == SBL_PHASE_WAIT_TARGET);

   // Le target est une meche stricte courante. PreviousClose ne fait partie
   // que du vrai croisement MSS, pas de la prise de cible externe.
   SblSetup longTargetIgnoresPreviousClose = StartedLong();
   LockLongPivot(longTargetIgnoresPreviousClose, config, NoFvg());
   const SblBar longTarget = Bar(14, 121.0, 122.0, 108.0, 109.5, 121.0);
   CHECK(!SblAdvanceSetup(longTargetIgnoresPreviousClose, longTarget,
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(longTargetIgnoresPreviousClose.phase == SBL_PHASE_WAIT_MSS);
   CHECK(!SblAdvanceSetup(longTargetIgnoresPreviousClose, longTarget,
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(!decision.consumeTarget);
   CHECK(longTargetIgnoresPreviousClose.phase == SBL_PHASE_WAIT_MSS);

   SblSetup shortTargetIgnoresPreviousClose = StartedShort();
   LockShortPivot(shortTargetIgnoresPreviousClose, config, NoFvg());
   CHECK(!SblAdvanceSetup(shortTargetIgnoresPreviousClose,
                          Bar(14, 99.0, 113.0, 98.0, 110.5, 99.0),
                          SBL_SHORT, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(shortTargetIgnoresPreviousClose.phase == SBL_PHASE_WAIT_MSS);

   CHECK(!SblInternalMssCrossed(longTargetIgnoresPreviousClose,
                                Bar(15, 111.0, 113.0, 110.5, 112.0, 111.0)));
   CHECK(SblInternalMssCrossed(longTargetIgnoresPreviousClose,
                               Bar(15, 110.0, 112.0, 109.5, 111.0, 110.0)));
   CHECK(!SblInternalMssCrossed(shortTargetIgnoresPreviousClose,
                                Bar(15, 109.0, 109.5, 107.0, 108.0, 109.0)));
   CHECK(SblInternalMssCrossed(shortTargetIgnoresPreviousClose,
                               Bar(15, 110.0, 110.5, 108.0, 109.0, 110.0)));

   // La consommation du target reste observable meme si la meme bougie
   // invalide ensuite le setup en quittant sa fenetre.
   SblSetup targetOnWindowExit = StartedLong();
   LockLongPivot(targetOnWindowExit, config, NoFvg());
   CHECK(!SblAdvanceSetup(targetOnWindowExit,
                          Bar(14, 109.0, 121.0, 107.0, 109.5, 109.0,
                              0.0, 0, 0),
                          SBL_LONG, NoPivot(), NoFvg(), false, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == targetOnWindowExit.refHighTime);
   CHECK(targetOnWindowExit.phase == SBL_PHASE_INVALID);

   SblSetup mssBeforeTarget = StartedLong();
   LockLongPivot(mssBeforeTarget, config, NoFvg());
   CHECK(!SblAdvanceSetup(mssBeforeTarget,
                          Bar(14, 109.0, 115.0, 107.0, 111.0, 109.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(!decision.consumeTarget);
   CHECK(mssBeforeTarget.phase == SBL_PHASE_INVALID);

   SblSetup separated = StartedLong();
   LockLongPivot(separated, config);
   CHECK(!SblAdvanceSetup(separated,
                          Bar(14, 109.0, 122.0, 107.0, 109.5, 109.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(separated.phase == SBL_PHASE_WAIT_MSS);
   CHECK(!SblAdvanceSetup(separated,
                          Bar(15, 109.5, 126.0, 108.0, 112.0, 109.5),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(separated.mssBar == 15);
   CHECK(separated.phase == SBL_PHASE_WAIT_RETRACEMENT);

   SblSetup wickOnly = StartedShort();
   LockShortPivot(wickOnly, config);
   CHECK(!SblAdvanceSetup(wickOnly,
                          Bar(14, 111.0, 113.0, 95.0, 110.0, 111.0),
                          SBL_SHORT, NoPivot(), NoFvg(), true, config, decision));
   CHECK(wickOnly.phase == SBL_PHASE_WAIT_MSS);
   CHECK(!SblAdvanceSetup(wickOnly,
                          Bar(15, 110.0, 112.0, 108.0, 110.0, 110.0),
                          SBL_SHORT, NoPivot(), NoFvg(), true, config, decision));
   CHECK(wickOnly.phase == SBL_PHASE_WAIT_MSS);
}

void TestWindowIdentityInvalidatesImmediately()
{
   const SblConfig config = Config();
   SblDecision decision;

   SblSetup outside = StartedLong();
   CHECK(!SblAdvanceSetup(outside,
                          Bar(11, 102.0, 105.0, 100.0, 103.0, 101.0,
                              0.0, 0, 0),
                          SBL_LONG, NoPivot(), NoFvg(), false, config, decision));
   CHECK(outside.phase == SBL_PHASE_INVALID);

   SblSetup nextWindow = StartedLong();
   CHECK(!SblAdvanceSetup(nextWindow,
                          Bar(11, 102.0, 105.0, 100.0, 103.0, 101.0,
                              0.0, 0, NEW_YORK_KEY),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(nextWindow.phase == SBL_PHASE_INVALID);

   SblSetup nextDay = StartedLong();
   CHECK(!SblAdvanceSetup(nextDay,
                          Bar(11, 102.0, 105.0, 100.0, 103.0, 101.0,
                              0.0, 0, 202608101L),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(nextDay.phase == SBL_PHASE_INVALID);

   SblSetup sameKeyButOutside = StartedLong();
   CHECK(!SblAdvanceSetup(sameKeyButOutside,
                          Bar(11, 102.0, 105.0, 100.0, 103.0, 101.0),
                          SBL_LONG, NoPivot(), NoFvg(), false,
                          config, decision));
   CHECK(sameKeyButOutside.phase == SBL_PHASE_INVALID);

   SblConfig allegedlyOptional = Config();
   allegedlyOptional.requireWindow = false;
   SblSetup mandatory = StartedLong();
   CHECK(!SblAdvanceSetup(mandatory,
                          Bar(11, 102.0, 105.0, 100.0, 103.0, 101.0,
                              0.0, 0, 0),
                          SBL_LONG, NoPivot(), NoFvg(), false,
                          allegedlyOptional, decision));
   CHECK(mandatory.phase == SBL_PHASE_INVALID);
}

void TestFvgCeTouchAndAlternativeTriggers()
{
   SblDecision decision;
   SblConfig fvgConfig = Config();
   fvgConfig.useOteTrigger = false;
   fvgConfig.useEmaTrigger = false;
   SblSetup fvg = StartedLong();
   ConfirmLong(fvg, fvgConfig);
   CHECK_NEAR(SblFvgConsequentEncroachment(fvg.fvgLow, fvg.fvgHigh),
              106.0, 1e-12);
   CHECK(!SblAdvanceSetup(fvg,
                          Bar(15, 104.5, 105.5, 104.0, 105.0, 112.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, fvgConfig, decision));
   CHECK(fvg.phase == SBL_PHASE_WAIT_RETRACEMENT);
   CHECK(!SblAdvanceSetup(fvg,
                          Bar(16, 106.0, 106.5, 104.5, 106.0, 105.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, fvgConfig, decision));
   CHECK(!decision.signal); // doji: CE touchee, mais aucun rejet directionnel
   CHECK(SblAdvanceSetup(fvg,
                         Bar(17, 105.0, 107.0, 104.5, 106.5, 106.0),
                         SBL_LONG, NoPivot(), NoFvg(), true, fvgConfig, decision));
   CHECK(decision.trigger == SBL_TRIGGER_FVG);

   SblConfig oteConfig = Config();
   oteConfig.useFvgTrigger = false;
   oteConfig.useOteTrigger = true;
   oteConfig.useEmaTrigger = false;
   SblSetup ote = StartedLong();
   ConfirmLong(ote, oteConfig);
   double oteLow = 0.0;
   double oteHigh = 0.0;
   SblOteBounds(SBL_LONG, ote.fib0, ote.fib1, 0.62, 0.79, oteLow, oteHigh);
   CHECK_NEAR(oteLow, 104.46, 1e-12);
   CHECK_NEAR(oteHigh, 108.88, 1e-12);
   double shortOteLow = 0.0;
   double shortOteHigh = 0.0;
   SblOteBounds(SBL_SHORT, 120.0, 100.0, 0.62, 0.79,
                shortOteLow, shortOteHigh);
   CHECK_NEAR(shortOteLow, 112.4, 1e-12);
   CHECK_NEAR(shortOteHigh, 115.8, 1e-12);
   CHECK(SblRangesIntersect(112.4, 112.4, shortOteLow, shortOteHigh));
   CHECK(SblRangesIntersect(115.8, 115.8, shortOteLow, shortOteHigh));
   CHECK(!SblRangesIntersect(112.39, 112.39, shortOteLow, shortOteHigh));
   CHECK(!SblRangesIntersect(115.81, 115.81, shortOteLow, shortOteHigh));
   CHECK(SblAdvanceSetup(ote,
                         Bar(15, 105.0, 107.0, 104.0, 106.0, 112.0),
                         SBL_LONG, NoPivot(), NoFvg(), true, oteConfig, decision));
   CHECK(decision.trigger == SBL_TRIGGER_OTE);

   SblConfig emaConfig = Config();
   emaConfig.useFvgTrigger = false;
   emaConfig.useOteTrigger = false;
   emaConfig.useEmaTrigger = true;
   SblSetup ema = StartedShort();
   ConfirmShort(ema, emaConfig);
   CHECK(SblAdvanceSetup(ema,
                         Bar(15, 115.0, 116.0, 112.0, 113.0, 108.0, 114.0),
                         SBL_SHORT, NoPivot(), NoFvg(), true, emaConfig, decision));
   CHECK(decision.trigger == SBL_TRIGGER_EMA);

   SblSetup badEma = StartedLong();
   ConfirmLong(badEma, emaConfig);
   CHECK(!SblAdvanceSetup(badEma,
                          Bar(15, 114.0, 116.0, 113.0, 115.0, 112.0, 114.5),
                          SBL_LONG, NoPivot(), NoFvg(), true, emaConfig, decision));
   CHECK(badEma.phase == SBL_PHASE_WAIT_RETRACEMENT);
}

void TestEndToEndFvgCeAndDisplacementGuards()
{
   const SblConfig config = Config();
   SblDecision decision;

   // Meme avec target, MSS et deplacement, aucune transition vers le
   // retracement n'est possible sans FVG directionnelle post-purge.
   SblSetup noFvg = StartedLong();
   LockLongPivot(noFvg, config, NoFvg());
   CHECK(!SblAdvanceSetup(noFvg,
                          Bar(14, 109.0, 125.0, 107.0, 112.0, 109.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.consumeTarget);
   CHECK(noFvg.phase == SBL_PHASE_WAIT_CONFIRMATION);
   CHECK(!noFvg.hasContextFvg);
   CHECK(!SblAdvanceSetup(noFvg,
                          Bar(15, 112.0, 124.0, 108.0, 113.0, 112.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(noFvg.phase == SBL_PHASE_WAIT_CONFIRMATION);
   CHECK(!decision.signal);

   // La FVG ne contourne pas le seuil de deplacement. L'egalite au seuil est
   // ensuite admise et promeut la candidate deja memorisee.
   SblConfig displacementConfig = Config();
   displacementConfig.minDisplacement = 27.0;
   SblSetup insufficientDisplacement = StartedLong();
   LockLongPivot(insufficientDisplacement, displacementConfig);
   CHECK(!SblAdvanceSetup(insufficientDisplacement,
                          Bar(14, 109.0, 125.0, 107.0, 112.0, 109.0),
                          SBL_LONG, NoPivot(), NoFvg(), true,
                          displacementConfig, decision));
   CHECK(insufficientDisplacement.phase == SBL_PHASE_WAIT_CONFIRMATION);
   CHECK(insufficientDisplacement.hasCandidateFvg);
   CHECK(!insufficientDisplacement.hasContextFvg);
   CHECK(!SblAdvanceSetup(insufficientDisplacement,
                          Bar(15, 112.0, 126.0, 110.0, 113.0, 112.0),
                          SBL_LONG, NoPivot(), NoFvg(), true,
                          displacementConfig, decision));
   CHECK(insufficientDisplacement.phase == SBL_PHASE_WAIT_RETRACEMENT);
   CHECK(insufficientDisplacement.hasContextFvg);

   // Une CE au-dessus de l'EQ LONG bloque la confirmation, puis une nouvelle
   // FVG dont la CE est en discount permet de reprendre la sequence.
   SblSetup wrongCe = StartedLong();
   LockLongPivot(wrongCe, config, Fvg(SBL_LONG, 13, 113.0, 115.0));
   CHECK(!SblAdvanceSetup(wrongCe,
                          Bar(14, 109.0, 125.0, 107.0, 114.0, 109.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(wrongCe.phase == SBL_PHASE_WAIT_CONFIRMATION);
   CHECK(!wrongCe.hasContextFvg);
   CHECK(!SblAdvanceSetup(wrongCe,
                          Bar(15, 114.0, 124.0, 104.0, 114.0, 114.0),
                          SBL_LONG, NoPivot(), Fvg(SBL_LONG, 15, 104.0, 108.0),
                          true, config, decision));
   CHECK(wrongCe.phase == SBL_PHASE_WAIT_RETRACEMENT);
   CHECK(wrongCe.hasContextFvg);

   // Une FVG peut traverser EQ si sa CE reste en discount. Le toucher exact
   // de cette CE par le high du retracement est inclusif.
   SblSetup crossingEq = StartedLong();
   ConfirmLong(crossingEq, config, Fvg(SBL_LONG, 13, 105.0, 115.0));
   CHECK_NEAR(crossingEq.equilibrium, 112.0, 1e-12);
   CHECK(crossingEq.fvgHigh > crossingEq.equilibrium);
   CHECK_NEAR(SblFvgConsequentEncroachment(crossingEq.fvgLow,
                                           crossingEq.fvgHigh),
              110.0, 1e-12);
   CHECK(SblAdvanceSetup(crossingEq,
                         Bar(15, 109.0, 110.0, 108.5, 109.5, 112.0),
                         SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.trigger == SBL_TRIGGER_FVG);

   // Miroir SHORT : le low egal a la CE constitue lui aussi un toucher reel.
   SblSetup exactShortCe = StartedShort();
   ConfirmShort(exactShortCe, config);
   CHECK_NEAR(SblFvgConsequentEncroachment(exactShortCe.fvgLow,
                                           exactShortCe.fvgHigh),
              114.0, 1e-12);
   CHECK(SblAdvanceSetup(exactShortCe,
                         Bar(15, 115.0, 115.5, 114.0, 114.5, 108.0),
                         SBL_SHORT, NoPivot(), NoFvg(), true, config, decision));
   CHECK(decision.trigger == SBL_TRIGGER_FVG);

   // Toucher la CE ne suffit pas si la cloture sort de la bonne moitie.
   SblSetup wrongCloseHalf = StartedLong();
   ConfirmLong(wrongCloseHalf, config);
   CHECK(!SblAdvanceSetup(wrongCloseHalf,
                          Bar(15, 105.0, 114.0, 105.0, 113.0, 112.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(!decision.signal);
   CHECK(wrongCloseHalf.phase == SBL_PHASE_WAIT_RETRACEMENT);
}

void TestInvalidationsCandidatesAndExpiry()
{
   const SblConfig config = Config();
   SblDecision decision;

   SblSetup lostStack = StartedLong();
   CHECK(!SblAdvanceSetup(lostStack,
                          Bar(11, 102.0, 105.0, 100.0, 103.0, 101.0),
                          SBL_NEUTRAL, NoPivot(), NoFvg(), true, config, decision));
   CHECK(lostStack.phase == SBL_PHASE_INVALID);

   SblSetup originEquality = StartedLong();
   CHECK(!SblAdvanceSetup(originEquality,
                          Bar(11, 100.0, 103.0, 98.0, 99.0, 101.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(originEquality.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT);
   CHECK(!SblAdvanceSetup(originEquality,
                          Bar(12, 99.0, 101.0, 97.0, 98.99, 99.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(originEquality.phase == SBL_PHASE_INVALID);

   SblConfig expiryConfig = Config();
   expiryConfig.expiryBars = 3;
   SblSetup expiry = StartedLong();
   CHECK(!SblAdvanceSetup(expiry,
                          Bar(13, 102.0, 105.0, 100.0, 103.0, 101.0),
                          SBL_LONG, NoPivot(), NoFvg(), true,
                          expiryConfig, decision));
   CHECK(expiry.phase != SBL_PHASE_INVALID);
   CHECK(!SblAdvanceSetup(expiry,
                          Bar(14, 102.0, 105.0, 100.0, 103.0, 103.0),
                          SBL_LONG, NoPivot(), NoFvg(), true,
                          expiryConfig, decision));
   CHECK(expiry.phase == SBL_PHASE_INVALID);

   SblSetup oldFvg = StartedLong();
   LockLongPivot(oldFvg, config, Fvg(SBL_LONG, 12, 104.0, 108.0));
   CHECK(!oldFvg.hasCandidateFvg);

   SblSetup invalidContext = StartedLong();
   ConfirmLong(invalidContext, config);
   CHECK(!SblAdvanceSetup(invalidContext,
                          Bar(15, 105.0, 106.0, 101.0, 103.0, 112.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(invalidContext.phase == SBL_PHASE_INVALID);

   SblSetup replacement = StartedLong();
   LockLongPivot(replacement, config, Fvg(SBL_LONG, 13, 104.0, 108.0));
   CHECK(replacement.hasCandidateFvg);
   CHECK(!SblAdvanceSetup(replacement,
                          Bar(14, 109.0, 118.0, 101.0, 103.0, 109.0),
                          SBL_LONG, NoPivot(), NoFvg(), true, config, decision));
   CHECK(!replacement.hasCandidateFvg);
   CHECK(replacement.phase == SBL_PHASE_WAIT_TARGET);
   CHECK(!SblAdvanceSetup(replacement,
                          Bar(15, 108.0, 125.0, 104.0, 112.0, 103.0),
                          SBL_LONG, NoPivot(), Fvg(SBL_LONG, 15, 104.0, 108.0),
                          true, config, decision));
   CHECK(replacement.phase == SBL_PHASE_WAIT_RETRACEMENT);
   CHECK(replacement.hasContextFvg);
}

void TestConsumedRegistry()
{
   SblConsumedRegistry registry;
   SblResetRegistry(registry);
   CHECK(SblRegistryContains(registry, SBL_LONG, 0L));
   CHECK(!SblRegistryConsume(registry, SBL_LONG, 0L));
   CHECK(SblRegistryConsume(registry, SBL_LONG, 101L));
   CHECK(SblRegistryContains(registry, SBL_LONG, 101L));
   CHECK(!SblRegistryConsume(registry, SBL_LONG, 101L));
   CHECK(SblRegistryConsume(registry, SBL_SHORT, 101L));
   CHECK(SblRegistryContains(registry, SBL_SHORT, 101L));

   SblResetRegistry(registry);
   for(long key = 1; key <= SBL_MAX_CONSUMED + 1L; ++key)
      CHECK(SblRegistryConsume(registry, SBL_LONG, key));
   CHECK(registry.longCount == SBL_MAX_CONSUMED);
   CHECK(!SblRegistryContains(registry, SBL_LONG, 1L));
   CHECK(SblRegistryContains(registry, SBL_LONG, 2L));
   CHECK(SblRegistryContains(registry, SBL_LONG, SBL_MAX_CONSUMED + 1L));
}

void Run(const std::string &name, const std::function<void()> &test)
{
   const int failuresBefore = g_failures;
   test();
   std::cout << (g_failures == failuresBefore ? "[PASS] " : "[FAIL] ")
             << name << '\n';
}
} // namespace

int main()
{
   const std::vector<std::pair<std::string, std::function<void()>>> tests = {
      {"strict stack and alignment", TestStrictStackAndAlignment},
      {"entry windows and identity", TestEntryWindowsAndIdentity},
      {"DST boundaries 2026", TestDstBoundaries2026},
      {"closed purge reintegration", TestPurgeRequiresClosedReintegration},
      {"internal pivot detection", TestInternalPivotDetection},
      {"FVG detection and CE value area", TestFvgDetectionAndCeValueArea},
      {"valid LONG and SHORT machines", TestValidLongAndShortMachines},
      {"target and MSS chronology", TestTargetAndMssChronology},
      {"window identity invalidation", TestWindowIdentityInvalidatesImmediately},
      {"CE touch and alternative triggers", TestFvgCeTouchAndAlternativeTriggers},
      {"end-to-end FVG, CE and displacement guards",
       TestEndToEndFvgCeAndDisplacementGuards},
      {"invalidations, candidates and expiry", TestInvalidationsCandidatesAndExpiry},
      {"consumed liquidity registry", TestConsumedRegistry},
   };

   for(const auto &test : tests)
      Run(test.first, test.second);

   std::cout << g_assertions << " assertions, " << g_failures
             << " failure(s)\n";
   return g_failures == 0 ? 0 : 1;
}
