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
   config.maxFvgCandidates = 1;
   config.requireWindow = true;
   config.requireDirectionalRejection = true;
   config.allowMssBeforeTarget = false;
   config.allowTargetBeforeInternalPivot = false;
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

void TestConfigurableInternalPivotStrength()
{
   const SblBar longTwoBefore =
      Bar(40, 101.0, 104.0, 99.0, 102.0, 101.0);
   const SblBar longOneBefore =
      Bar(41, 102.0, 106.0, 100.0, 104.0, 102.0);
   const SblBar longCandidate =
      Bar(42, 104.0, 110.0, 101.0, 106.0, 104.0);
   const SblBar longOneAfter =
      Bar(43, 106.0, 108.0, 102.0, 105.0, 106.0);
   const SblBar longTwoAfter =
      Bar(44, 105.0, 107.0, 101.0, 103.0, 105.0);

   SblPivot longOne;
   SblPivot longTwo;
   SblPivot longLegacy;
   SblDetectInternalPivot(SBL_LONG,1,longTwoBefore,longOneBefore,
                          longCandidate,longOneAfter,longTwoAfter,longOne);
   SblDetectInternalPivot(SBL_LONG,2,longTwoBefore,longOneBefore,
                          longCandidate,longOneAfter,longTwoAfter,longTwo);
   SblDetectInternalPivot(SBL_LONG,longTwoBefore,longOneBefore,longCandidate,
                          longOneAfter,longTwoAfter,longLegacy);
   CHECK(longOne.present);
   CHECK(longOne.direction == SBL_LONG);
   CHECK_NEAR(longOne.price, 110.0, 1e-12);
   CHECK(longOne.pivotBar == longCandidate.index);
   CHECK(longOne.pivotTime == longCandidate.time);
   CHECK(longOne.confirmedBar == longOneAfter.index);
   CHECK(longOne.confirmedTime == longOneAfter.time);
   CHECK(longTwo.present);
   CHECK(longTwo.confirmedBar == longTwoAfter.index);
   CHECK(longTwo.confirmedTime == longTwoAfter.time);
   CHECK(longLegacy.present == longTwo.present);
   CHECK(longLegacy.direction == longTwo.direction);
   CHECK_NEAR(longLegacy.price, longTwo.price, 1e-12);
   CHECK(longLegacy.pivotBar == longTwo.pivotBar);
   CHECK(longLegacy.pivotTime == longTwo.pivotTime);
   CHECK(longLegacy.confirmedBar == longTwo.confirmedBar);
   CHECK(longLegacy.confirmedTime == longTwo.confirmedTime);

   const SblBar shortTwoBefore =
      Bar(50, 109.0, 111.0, 104.0, 107.0, 109.0);
   const SblBar shortOneBefore =
      Bar(51, 107.0, 110.0, 100.0, 104.0, 107.0);
   const SblBar shortCandidate =
      Bar(52, 104.0, 108.0, 97.0, 100.0, 104.0);
   const SblBar shortOneAfter =
      Bar(53, 100.0, 107.0, 99.0, 103.0, 100.0);
   const SblBar shortTwoAfter =
      Bar(54, 103.0, 109.0, 101.0, 105.0, 103.0);

   SblPivot shortOne;
   SblPivot shortTwo;
   SblPivot shortLegacy;
   SblDetectInternalPivot(SBL_SHORT,1,shortTwoBefore,shortOneBefore,
                          shortCandidate,shortOneAfter,shortTwoAfter,shortOne);
   SblDetectInternalPivot(SBL_SHORT,2,shortTwoBefore,shortOneBefore,
                          shortCandidate,shortOneAfter,shortTwoAfter,shortTwo);
   SblDetectInternalPivot(SBL_SHORT,shortTwoBefore,shortOneBefore,
                          shortCandidate,shortOneAfter,shortTwoAfter,
                          shortLegacy);
   CHECK(shortOne.present);
   CHECK(shortOne.direction == SBL_SHORT);
   CHECK_NEAR(shortOne.price, 97.0, 1e-12);
   CHECK(shortOne.pivotBar == shortCandidate.index);
   CHECK(shortOne.pivotTime == shortCandidate.time);
   CHECK(shortOne.confirmedBar == shortOneAfter.index);
   CHECK(shortOne.confirmedTime == shortOneAfter.time);
   CHECK(shortTwo.present);
   CHECK(shortTwo.confirmedBar == shortTwoAfter.index);
   CHECK(shortTwo.confirmedTime == shortTwoAfter.time);
   CHECK(shortLegacy.present == shortTwo.present);
   CHECK(shortLegacy.direction == shortTwo.direction);
   CHECK_NEAR(shortLegacy.price, shortTwo.price, 1e-12);
   CHECK(shortLegacy.pivotBar == shortTwo.pivotBar);
   CHECK(shortLegacy.pivotTime == shortTwo.pivotTime);
   CHECK(shortLegacy.confirmedBar == shortTwo.confirmedBar);
   CHECK(shortLegacy.confirmedTime == shortTwo.confirmedTime);

   // Les voisins immediats suffisent en 1/1, tandis qu'un voisin externe plus
   // extreme doit faire echouer exactement la meme candidate en 2/2.
   const SblBar higherOuter =
      Bar(40, 101.0, 111.0, 99.0, 102.0, 101.0);
   SblDetectInternalPivot(SBL_LONG,1,higherOuter,longOneBefore,longCandidate,
                          longOneAfter,longTwoAfter,longOne);
   SblDetectInternalPivot(SBL_LONG,2,higherOuter,longOneBefore,longCandidate,
                          longOneAfter,longTwoAfter,longTwo);
   CHECK(longOne.present);
   CHECK(!longTwo.present);

   const SblBar lowerOuter =
      Bar(50, 109.0, 111.0, 96.0, 107.0, 109.0);
   SblDetectInternalPivot(SBL_SHORT,1,lowerOuter,shortOneBefore,
                          shortCandidate,shortOneAfter,shortTwoAfter,shortOne);
   SblDetectInternalPivot(SBL_SHORT,2,lowerOuter,shortOneBefore,
                          shortCandidate,shortOneAfter,shortTwoAfter,shortTwo);
   CHECK(shortOne.present);
   CHECK(!shortTwo.present);

   // Les deux arguments externes sont volontairement hors contrat en 1/1.
   SblBar ignoredOuterBefore = higherOuter;
   SblBar ignoredOuterAfter = longTwoAfter;
   ignoredOuterBefore.index = 900;
   ignoredOuterBefore.time = longCandidate.time + 5000;
   ignoredOuterAfter.index = -4;
   ignoredOuterAfter.time = 1;
   SblDetectInternalPivot(SBL_LONG,1,ignoredOuterBefore,longOneBefore,
                          longCandidate,longOneAfter,ignoredOuterAfter,longOne);
   CHECK(longOne.present);
   CHECK(longOne.confirmedBar == longOneAfter.index);

   // Egalites, chronologie utile invalide, direction et strength invalides.
   const SblBar equalLong =
      Bar(42, 104.0, 106.0, 101.0, 105.0, 104.0);
   SblDetectInternalPivot(SBL_LONG,1,longTwoBefore,longOneBefore,equalLong,
                          longOneAfter,longTwoAfter,longOne);
   CHECK(!longOne.present);
   const SblBar equalShort =
      Bar(52, 104.0, 108.0, 100.0, 101.0, 104.0);
   SblDetectInternalPivot(SBL_SHORT,1,shortTwoBefore,shortOneBefore,equalShort,
                          shortOneAfter,shortTwoAfter,shortOne);
   CHECK(!shortOne.present);

   SblBar lateOneAfter = longOneAfter;
   lateOneAfter.index = longCandidate.index + 2;
   SblDetectInternalPivot(SBL_LONG,1,longTwoBefore,longOneBefore,
                          longCandidate,lateOneAfter,longTwoAfter,longOne);
   CHECK(!longOne.present);
   SblDetectInternalPivot(SBL_NEUTRAL,1,longTwoBefore,longOneBefore,
                          longCandidate,longOneAfter,longTwoAfter,longOne);
   CHECK(!longOne.present);

   SblPivot invalidStrength = Pivot(SBL_LONG,42,43,110.0);
   SblDetectInternalPivot(SBL_LONG,0,longTwoBefore,longOneBefore,
                          longCandidate,longOneAfter,longTwoAfter,
                          invalidStrength);
   CHECK(!invalidStrength.present);
   CHECK(invalidStrength.direction == SBL_NEUTRAL);
   CHECK(invalidStrength.pivotBar == -1);
   CHECK(invalidStrength.confirmedBar == -1);
   invalidStrength = Pivot(SBL_LONG,42,43,110.0);
   SblDetectInternalPivot(SBL_LONG,3,longTwoBefore,longOneBefore,
                          longCandidate,longOneAfter,longTwoAfter,
                          invalidStrength);
   CHECK(!invalidStrength.present);
   CHECK(invalidStrength.direction == SBL_NEUTRAL);

   // La machine doit accepter la distance de confirmation +1 produite par le
   // detecteur, sans relacher les autres controles de causalite.
   SblSetup setup = StartedLong(77);
   const SblBar purge = Bar(10, 102.0, 104.0, 99.0, 101.0, 101.5);
   const SblBar candidate = Bar(11, 104.0, 110.0, 103.0, 108.0, 101.0);
   const SblBar confirmation =
      Bar(12, 108.0, 108.5, 104.0, 108.0, 108.0);
   SblPivot detectedOne;
   SblDetectInternalPivot(SBL_LONG,1,longTwoBefore,purge,candidate,
                          confirmation,confirmation,detectedOne);
   CHECK(detectedOne.present);
   SblDecision decision;
   CHECK(!SblAdvanceSetup(setup,confirmation,SBL_LONG,detectedOne,NoFvg(),
                          true,Config(),decision));
   CHECK(setup.hasInternalPivot);
   CHECK(setup.internalPivotConfirmedBar == confirmation.index);
   CHECK(setup.phase == SBL_PHASE_WAIT_TARGET);
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

void TestTargetBeforeInternalPivotPolicy()
{
   SblDecision decision;
   SblConfig strict = Config();
   CHECK(!strict.allowTargetBeforeInternalPivot);

   // Mode strict historique : la premiere cible prise avant le pivot est
   // exposee puis invalide immediatement le setup, dans les deux directions.
   SblSetup strictLong = StartedLong(70);
   CHECK(!SblAdvanceSetup(strictLong,
                          Bar(11,108.0,121.0,105.0,109.0,101.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,strict,decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == strictLong.refHighTime);
   CHECK(strictLong.targetTaken);
   CHECK(strictLong.targetBar == 11);
   CHECK(strictLong.phase == SBL_PHASE_INVALID);

   SblSetup strictShort = StartedShort(71);
   CHECK(!SblAdvanceSetup(strictShort,
                          Bar(11,112.0,116.0,99.0,111.0,119.0),
                          SBL_SHORT,NoPivot(),NoFvg(),true,strict,decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == strictShort.refLowTime);
   CHECK(strictShort.targetTaken);
   CHECK(strictShort.targetBar == 11);
   CHECK(strictShort.phase == SBL_PHASE_INVALID);

   SblConfig flexible = Config();
   flexible.allowTargetBeforeInternalPivot = true;

   // Sans pivot, la premiere cible reste memorisee en WAIT_INTERNAL. Le meme
   // appel et les meches ulterieures sont idempotents : ni rehorodatage, ni
   // nouvelle consommation.
   SblSetup noPivot = StartedLong(72);
   const SblBar firstTarget =
      Bar(11,108.0,121.0,105.0,109.0,101.0);
   CHECK(!SblAdvanceSetup(noPivot,firstTarget,SBL_LONG,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(decision.targetKey == noPivot.refHighTime);
   CHECK(noPivot.targetTaken);
   CHECK(noPivot.targetBar == firstTarget.index);
   CHECK(noPivot.targetTime == firstTarget.time);
   CHECK(noPivot.breakBar == firstTarget.index);
   CHECK(noPivot.breakTime == firstTarget.time);
   CHECK(noPivot.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT);
   CHECK(!noPivot.hasInternalPivot);

   CHECK(!SblAdvanceSetup(noPivot,firstTarget,SBL_LONG,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(!decision.consumeTarget);
   CHECK(noPivot.targetBar == firstTarget.index);
   CHECK(noPivot.targetTime == firstTarget.time);

   CHECK(!SblAdvanceSetup(noPivot,
                          Bar(12,109.0,124.0,106.0,110.0,109.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!decision.consumeTarget);
   CHECK(noPivot.targetBar == firstTarget.index);
   CHECK(noPivot.targetTime == firstTarget.time);
   CHECK(noPivot.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT);
   CHECK(!noPivot.hasInternalPivot);

   CHECK(!SblAdvanceSetup(noPivot,
                          Bar(13,110.0,118.0,107.0,111.0,110.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!decision.consumeTarget);
   CHECK(noPivot.phase == SBL_PHASE_WAIT_INTERNAL_PIVOT);
   CHECK(noPivot.mssBar == -1);

   // LONG end-to-end : cible avant le candidat, pivot confirme plus tard,
   // MSS seulement sur une bougie posterieure, puis FVG et trigger CE.
   SblSetup longSetup = StartedLong(73);
   const SblBar longEarlyTarget =
      Bar(11,108.0,125.0,105.0,108.0,101.0);
   CHECK(!SblAdvanceSetup(longSetup,longEarlyTarget,SBL_LONG,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(!SblAdvanceSetup(longSetup,
                          Bar(12,108.0,110.0,104.0,109.0,108.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!SblAdvanceSetup(longSetup,
                          Bar(13,109.0,109.5,106.0,108.0,109.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   const SblBar longConfirmation =
      Bar(14,108.0,109.0,106.0,109.0,108.0);
   CHECK(!SblAdvanceSetup(longSetup,longConfirmation,SBL_LONG,
                          Pivot(SBL_LONG,12,14,110.0),
                          Fvg(SBL_LONG,14,104.0,108.0),true,flexible,
                          decision));
   CHECK(!decision.consumeTarget);
   CHECK(longSetup.hasInternalPivot);
   CHECK(longSetup.targetBar == 11);
   CHECK(longSetup.phase == SBL_PHASE_WAIT_MSS);
   CHECK(longSetup.mssBar == -1);

   CHECK(!SblAdvanceSetup(longSetup,
                          Bar(15,109.0,126.0,108.0,112.0,109.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!decision.consumeTarget);
   CHECK(longSetup.mssBar == 15);
   CHECK(longSetup.mssTime == Bar(15,109.0,126.0,108.0,112.0,109.0).time);
   CHECK(longSetup.phase == SBL_PHASE_WAIT_RETRACEMENT);
   CHECK(longSetup.hasContextFvg);
   CHECK_NEAR(longSetup.fvgLow,104.0,1e-12);
   CHECK_NEAR(longSetup.fvgHigh,108.0,1e-12);
   CHECK(SblAdvanceSetup(longSetup,
                         Bar(16,105.0,108.0,104.0,107.0,112.0),
                         SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(decision.signal);
   CHECK(decision.trigger == SBL_TRIGGER_FVG);

   // Miroir SHORT complet.
   SblSetup shortSetup = StartedShort(74);
   const SblBar shortEarlyTarget =
      Bar(11,112.0,116.0,95.0,111.0,119.0);
   CHECK(!SblAdvanceSetup(shortSetup,shortEarlyTarget,SBL_SHORT,NoPivot(),
                          NoFvg(),true,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(!SblAdvanceSetup(shortSetup,
                          Bar(12,111.0,116.0,110.0,112.0,111.0),
                          SBL_SHORT,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!SblAdvanceSetup(shortSetup,
                          Bar(13,112.0,115.0,111.0,113.0,112.0),
                          SBL_SHORT,NoPivot(),NoFvg(),true,flexible,decision));
   const SblBar shortConfirmation =
      Bar(14,113.0,115.0,111.0,111.0,113.0);
   CHECK(!SblAdvanceSetup(shortSetup,shortConfirmation,SBL_SHORT,
                          Pivot(SBL_SHORT,12,14,110.0),
                          Fvg(SBL_SHORT,14,112.0,116.0),true,flexible,
                          decision));
   CHECK(!decision.consumeTarget);
   CHECK(shortSetup.hasInternalPivot);
   CHECK(shortSetup.targetBar == 11);
   CHECK(shortSetup.phase == SBL_PHASE_WAIT_MSS);
   CHECK(shortSetup.mssBar == -1);

   CHECK(!SblAdvanceSetup(shortSetup,
                          Bar(15,111.0,112.0,94.0,108.0,111.0),
                          SBL_SHORT,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!decision.consumeTarget);
   CHECK(shortSetup.mssBar == 15);
   CHECK(shortSetup.phase == SBL_PHASE_WAIT_RETRACEMENT);
   CHECK(shortSetup.hasContextFvg);
   CHECK_NEAR(shortSetup.fvgLow,112.0,1e-12);
   CHECK_NEAR(shortSetup.fvgHigh,116.0,1e-12);
   CHECK(SblAdvanceSetup(shortSetup,
                         Bar(16,115.0,116.0,112.0,113.0,108.0),
                         SBL_SHORT,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(decision.signal);
   CHECK(decision.trigger == SBL_TRIGGER_FVG);

   // Cible sur la future bougie candidate : son horodatage reste celui du
   // candidat lorsque le pivot est finalement confirme deux bougies apres.
   SblSetup onCandidate = StartedLong(75);
   const SblBar candidateAndTarget =
      Bar(11,108.0,125.0,104.0,119.0,101.0);
   CHECK(!SblAdvanceSetup(onCandidate,candidateAndTarget,SBL_LONG,NoPivot(),
                          NoFvg(),true,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(!SblAdvanceSetup(onCandidate,
                          Bar(12,119.0,124.0,115.0,120.0,119.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!decision.consumeTarget);
   CHECK(!SblAdvanceSetup(onCandidate,
                          Bar(13,120.0,123.0,116.0,121.0,120.0),
                          SBL_LONG,Pivot(SBL_LONG,11,13,125.0),NoFvg(),true,
                          flexible,decision));
   CHECK(!decision.consumeTarget);
   CHECK(onCandidate.targetBar == candidateAndTarget.index);
   CHECK(onCandidate.targetTime == candidateAndTarget.time);
   CHECK(onCandidate.phase == SBL_PHASE_WAIT_MSS);
   CHECK(onCandidate.mssBar == -1);
   CHECK(!SblAdvanceSetup(onCandidate,
                          Bar(14,121.0,127.0,119.0,126.0,121.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(onCandidate.mssBar == 14);
   CHECK(onCandidate.phase == SBL_PHASE_WAIT_CONFIRMATION);

   // Cible et livraison du pivot sur la meme bougie de confirmation : meme si
   // OHLC/previousClose ressemblent a un croisement, le MSS doit attendre une
   // bougie strictement ulterieure.
   SblSetup onConfirmation = StartedLong(76);
   CHECK(!SblAdvanceSetup(onConfirmation,
                          Bar(11,104.0,110.0,103.0,108.0,101.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!SblAdvanceSetup(onConfirmation,
                          Bar(12,108.0,109.0,104.0,109.0,108.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   const SblBar targetAndConfirmation =
      Bar(13,109.0,121.0,107.0,111.0,109.0);
   CHECK(!SblAdvanceSetup(onConfirmation,targetAndConfirmation,SBL_LONG,
                          Pivot(SBL_LONG,11,13,110.0),NoFvg(),true,flexible,
                          decision));
   CHECK(decision.consumeTarget);
   CHECK(onConfirmation.targetBar == 13);
   CHECK(onConfirmation.phase == SBL_PHASE_WAIT_MSS);
   CHECK(onConfirmation.mssBar == -1);
   CHECK(!SblAdvanceSetup(onConfirmation,targetAndConfirmation,SBL_LONG,
                          Pivot(SBL_LONG,11,13,110.0),NoFvg(),true,flexible,
                          decision));
   CHECK(!decision.consumeTarget);
   CHECK(onConfirmation.mssBar == -1);
   CHECK(!SblAdvanceSetup(onConfirmation,
                          Bar(14,111.0,114.0,108.0,109.0,111.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(onConfirmation.mssBar == -1);
   CHECK(!SblAdvanceSetup(onConfirmation,
                          Bar(15,109.0,116.0,108.0,112.0,109.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(onConfirmation.mssBar == 15);
   CHECK(onConfirmation.phase == SBL_PHASE_WAIT_CONFIRMATION);

   // L'assouplissement ne contourne aucun garde structurel. Le fait de marche
   // est consomme, puis fenetre, biais ou origine invalident normalement.
   SblSetup badWindow = StartedLong(77);
   CHECK(!SblAdvanceSetup(badWindow,
                          Bar(11,108.0,121.0,105.0,109.0,101.0,
                              0.0,0,0),
                          SBL_LONG,NoPivot(),NoFvg(),false,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(badWindow.targetTaken);
   CHECK(badWindow.phase == SBL_PHASE_INVALID);

   SblSetup badBias = StartedShort(78);
   CHECK(!SblAdvanceSetup(badBias,
                          Bar(11,112.0,116.0,99.0,111.0,119.0),
                          SBL_NEUTRAL,NoPivot(),NoFvg(),true,flexible,
                          decision));
   CHECK(decision.consumeTarget);
   CHECK(badBias.targetTaken);
   CHECK(badBias.phase == SBL_PHASE_INVALID);

   SblSetup badOrigin = StartedLong(79);
   CHECK(!SblAdvanceSetup(badOrigin,
                          Bar(11,108.0,121.0,97.0,98.0,101.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(badOrigin.targetTaken);
   CHECK(badOrigin.phase == SBL_PHASE_INVALID);
}

void TestMssBeforeTargetPolicy()
{
   SblDecision decision;
   SblConfig strict = Config();
   CHECK(!strict.allowMssBeforeTarget);

   // Le mode strict conserve exactement l'invalidation historique, dans les
   // deux directions, lorsqu'un vrai croisement precede la cible externe.
   SblSetup strictLong = StartedLong(51);
   LockLongPivot(strictLong, strict, NoFvg());
   CHECK(!SblAdvanceSetup(strictLong,
                          Bar(14,109.0,115.0,107.0,111.0,109.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,strict,decision));
   CHECK(strictLong.phase == SBL_PHASE_INVALID);
   CHECK(!strictLong.hasPendingMss);
   CHECK(strictLong.mssBar == -1);

   SblSetup strictShort = StartedShort(52);
   LockShortPivot(strictShort, strict, NoFvg());
   CHECK(!SblAdvanceSetup(strictShort,
                          Bar(14,111.0,113.0,105.0,109.0,111.0),
                          SBL_SHORT,NoPivot(),NoFvg(),true,strict,decision));
   CHECK(strictShort.phase == SBL_PHASE_INVALID);
   CHECK(!strictShort.hasPendingMss);
   CHECK(strictShort.mssBar == -1);

   SblConfig flexible = Config();
   flexible.allowMssBeforeTarget = true;

   // LONG : le premier croisement est memorise, mais pas encore publie comme
   // MSS. Une cible strictement ulterieure le promeut sans second croisement.
   SblSetup longSetup = StartedLong(53);
   LockLongPivot(longSetup, flexible);
   const SblBar longEarlyMss =
      Bar(14,109.0,115.0,107.0,111.0,109.0);
   CHECK(!SblAdvanceSetup(longSetup,longEarlyMss,SBL_LONG,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(longSetup.phase == SBL_PHASE_WAIT_TARGET);
   CHECK(longSetup.hasPendingMss);
   CHECK(longSetup.pendingMssBar == 14);
   CHECK(longSetup.pendingMssTime == longEarlyMss.time);
   CHECK(longSetup.mssBar == -1);
   CHECK(!longSetup.targetTaken);
   CHECK(!decision.consumeTarget);

   // La meme bougie est idempotente et ne peut ni dupliquer ni effacer le
   // premier evenement memorise.
   CHECK(!SblAdvanceSetup(longSetup,longEarlyMss,SBL_LONG,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(longSetup.hasPendingMss);
   CHECK(longSetup.pendingMssBar == 14);
   CHECK(!decision.consumeTarget);

   const SblBar longLaterTarget =
      Bar(15,111.0,122.0,108.0,112.0,111.0);
   CHECK(!SblInternalMssCrossed(longSetup,longLaterTarget));
   CHECK(!SblAdvanceSetup(longSetup,longLaterTarget,SBL_LONG,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(longSetup.targetBar == 15);
   CHECK(longSetup.mssBar == 14);
   CHECK(longSetup.mssTime == longEarlyMss.time);
   CHECK(!longSetup.hasPendingMss);
   CHECK(longSetup.pendingMssBar == -1);
   CHECK(longSetup.phase == SBL_PHASE_WAIT_RETRACEMENT);
   CHECK(longSetup.hasContextFvg);
   CHECK(longSetup.confirmationBar == 15);

   // Miroir SHORT avec promotion sans recroisement sur la bougie cible.
   SblSetup shortSetup = StartedShort(54);
   LockShortPivot(shortSetup, flexible);
   const SblBar shortEarlyMss =
      Bar(14,111.0,113.0,105.0,109.0,111.0);
   CHECK(!SblAdvanceSetup(shortSetup,shortEarlyMss,SBL_SHORT,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(shortSetup.phase == SBL_PHASE_WAIT_TARGET);
   CHECK(shortSetup.hasPendingMss);
   CHECK(shortSetup.pendingMssBar == 14);
   CHECK(shortSetup.mssBar == -1);
   const SblBar shortLaterTarget =
      Bar(15,109.0,111.0,98.0,108.0,109.0);
   CHECK(!SblInternalMssCrossed(shortSetup,shortLaterTarget));
   CHECK(!SblAdvanceSetup(shortSetup,shortLaterTarget,SBL_SHORT,NoPivot(),
                          NoFvg(),true,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(shortSetup.targetBar == 15);
   CHECK(shortSetup.mssBar == 14);
   CHECK(shortSetup.mssTime == shortEarlyMss.time);
   CHECK(!shortSetup.hasPendingMss);
   CHECK(shortSetup.phase == SBL_PHASE_WAIT_RETRACEMENT);
   CHECK(shortSetup.hasContextFvg);

   // Le premier croisement gagne : un retour sous le pivot puis un second
   // croisement avant cible ne doit jamais reecrire l'horodatage pending.
   SblSetup firstWins = StartedLong(55);
   LockLongPivot(firstWins, flexible, NoFvg());
   CHECK(!SblAdvanceSetup(firstWins,longEarlyMss,SBL_LONG,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(!SblAdvanceSetup(firstWins,
                          Bar(15,111.0,114.0,108.0,109.0,111.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!SblAdvanceSetup(firstWins,
                          Bar(16,109.0,118.0,108.0,112.0,109.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(firstWins.hasPendingMss);
   CHECK(firstWins.pendingMssBar == 14);
   CHECK(!SblAdvanceSetup(firstWins,
                          Bar(17,112.0,122.0,109.0,113.0,112.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(firstWins.mssBar == 14);
   CHECK(firstWins.phase == SBL_PHASE_WAIT_CONFIRMATION);

   // Une meche seule, ou un prix deja situe au-dela du pivot, ne constitue
   // jamais un vrai croisement et ne cree donc aucun pending.
   SblSetup noCross = StartedLong(56);
   LockLongPivot(noCross, flexible, NoFvg());
   CHECK(!SblAdvanceSetup(noCross,
                          Bar(14,109.0,115.0,107.0,110.0,109.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!noCross.hasPendingMss);
   CHECK(noCross.phase == SBL_PHASE_WAIT_TARGET);
   CHECK(!SblAdvanceSetup(noCross,
                          Bar(15,111.0,116.0,109.0,112.0,111.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!noCross.hasPendingMss);
   CHECK(noCross.phase == SBL_PHASE_WAIT_TARGET);

   // Une egalite avec la cible n'est pas une prise de liquidite et conserve
   // le pending sans le promouvoir.
   SblSetup targetEquality = StartedLong(57);
   LockLongPivot(targetEquality, flexible, NoFvg());
   CHECK(!SblAdvanceSetup(targetEquality,longEarlyMss,SBL_LONG,NoPivot(),
                          NoFvg(),true,flexible,decision));
   CHECK(!SblAdvanceSetup(targetEquality,
                          Bar(15,111.0,120.0,108.0,112.0,111.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!decision.consumeTarget);
   CHECK(targetEquality.hasPendingMss);
   CHECK(targetEquality.pendingMssBar == 14);
   CHECK(targetEquality.mssBar == -1);
   CHECK(targetEquality.phase == SBL_PHASE_WAIT_TARGET);

   // Sans pending, cible et MSS sur la meme bougie conservent le contrat
   // historique ; ce n'est pas un MSS anticipe.
   SblSetup sameBar = StartedLong(58);
   LockLongPivot(sameBar, flexible, NoFvg());
   CHECK(!SblAdvanceSetup(sameBar,
                          Bar(14,109.0,122.0,107.0,112.0,109.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(sameBar.targetBar == 14);
   CHECK(sameBar.mssBar == 14);
   CHECK(!sameBar.hasPendingMss);
   CHECK(sameBar.phase == SBL_PHASE_WAIT_CONFIRMATION);

   // La bougie de confirmation du pivot est explicitement exclue, meme si
   // ses prix ressemblent a un croisement valide.
   SblSetup confirmationBar = StartedLong(59);
   const SblBar pivotConfirmation =
      Bar(13,109.0,115.0,107.0,111.0,109.0);
   CHECK(!SblAdvanceSetup(confirmationBar,pivotConfirmation,SBL_LONG,
                          Pivot(SBL_LONG,11,13,110.0),NoFvg(),true,flexible,
                          decision));
   CHECK(confirmationBar.hasInternalPivot);
   CHECK(confirmationBar.phase == SBL_PHASE_WAIT_TARGET);
   CHECK(!confirmationBar.hasPendingMss);
   CHECK(confirmationBar.mssBar == -1);

   // Une cible constatee lors d'une sortie de fenetre reste consommable mais
   // ne peut pas promouvoir le pending d'un setup desormais invalide.
   SblSetup windowExit = StartedLong(60);
   LockLongPivot(windowExit, flexible, NoFvg());
   CHECK(!SblAdvanceSetup(windowExit,longEarlyMss,SBL_LONG,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(!SblAdvanceSetup(windowExit,
                          Bar(15,111.0,122.0,108.0,112.0,111.0,
                              0.0,0,0),
                          SBL_LONG,NoPivot(),NoFvg(),false,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(windowExit.targetTaken);
   CHECK(windowExit.phase == SBL_PHASE_INVALID);
   CHECK(windowExit.mssBar == -1);
   CHECK(!windowExit.hasPendingMss);

   // Une perte de biais avant la cible annule egalement le pending.
   SblSetup biasLoss = StartedShort(61);
   LockShortPivot(biasLoss, flexible, NoFvg());
   CHECK(!SblAdvanceSetup(biasLoss,shortEarlyMss,SBL_SHORT,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(biasLoss.hasPendingMss);
   CHECK(!SblAdvanceSetup(biasLoss,
                          Bar(15,109.0,111.0,105.0,108.0,109.0),
                          SBL_NEUTRAL,NoPivot(),NoFvg(),true,flexible,
                          decision));
   CHECK(biasLoss.phase == SBL_PHASE_INVALID);
   CHECK(!biasLoss.hasPendingMss);
   CHECK(biasLoss.mssBar == -1);

   // Expiration et invalidation de l'origine ont la meme priorite : la cible
   // eventuellement observee est exposee, mais aucun pending n'est promu.
   SblConfig expiring = flexible;
   expiring.expiryBars = 4;
   SblSetup expiry = StartedLong(64);
   LockLongPivot(expiry, expiring, NoFvg());
   CHECK(!SblAdvanceSetup(expiry,longEarlyMss,SBL_LONG,NoPivot(),NoFvg(),
                          true,expiring,decision));
   CHECK(expiry.hasPendingMss);
   CHECK(!SblAdvanceSetup(expiry,
                          Bar(15,111.0,122.0,108.0,112.0,111.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,expiring,decision));
   CHECK(decision.consumeTarget);
   CHECK(expiry.phase == SBL_PHASE_INVALID);
   CHECK(expiry.mssBar == -1);
   CHECK(!expiry.hasPendingMss);

   SblSetup originLoss = StartedLong(65);
   LockLongPivot(originLoss, flexible, NoFvg());
   CHECK(!SblAdvanceSetup(originLoss,longEarlyMss,SBL_LONG,NoPivot(),NoFvg(),
                          true,flexible,decision));
   CHECK(originLoss.hasPendingMss);
   CHECK(!SblAdvanceSetup(originLoss,
                          Bar(15,111.0,118.0,97.0,98.0,111.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(!decision.consumeTarget);
   CHECK(originLoss.phase == SBL_PHASE_INVALID);
   CHECK(originLoss.mssBar == -1);
   CHECK(!originLoss.hasPendingMss);

   // Un pending corrompu/non causal ne doit pas etre promu. La cible reste
   // consommee et la machine attend alors un MSS causal normal.
   SblSetup corrupt = StartedLong(62);
   LockLongPivot(corrupt, flexible, NoFvg());
   corrupt.hasPendingMss = true;
   corrupt.pendingMssBar = corrupt.internalPivotConfirmedBar;
   corrupt.pendingMssTime = corrupt.internalPivotConfirmedTime;
   CHECK(!SblAdvanceSetup(corrupt,
                          Bar(14,111.0,122.0,108.0,112.0,111.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,flexible,decision));
   CHECK(decision.consumeTarget);
   CHECK(corrupt.phase == SBL_PHASE_WAIT_MSS);
   CHECK(corrupt.mssBar == -1);
   CHECK(!corrupt.hasPendingMss);

   // Contrats unitaires des helpers : reset sentinelles, causalite stricte et
   // ordre pending < cible sur index et temps.
   SblSetup helper = StartedLong(63);
   CHECK(!helper.hasPendingMss);
   CHECK(helper.pendingMssBar == -1);
   CHECK(helper.pendingMssTime == 0);
   LockLongPivot(helper, flexible, NoFvg());
   CHECK(!SblBarAfterInternalPivotConfirmation(
      helper,Bar(13,109.0,115.0,107.0,111.0,109.0)));
   CHECK(SblStorePendingMss(helper,longEarlyMss));
   CHECK(!SblStorePendingMss(helper,
                             Bar(15,109.0,116.0,108.0,112.0,109.0)));
   helper.targetTaken = true;
   helper.targetBar = 14;
   helper.targetTime = longEarlyMss.time;
   CHECK(!SblPendingMssPrecedesTarget(helper));
   CHECK(!SblPromotePendingMss(helper));
   helper.targetBar = 15;
   helper.targetTime = Bar(15,111.0,122.0,108.0,112.0,111.0).time;
   CHECK(SblPendingMssPrecedesTarget(helper));
   CHECK(SblPromotePendingMss(helper));
   CHECK(helper.mssBar == 14);
   CHECK(!helper.hasPendingMss);
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

void TestOptionalDirectionalRejection()
{
   SblDecision decision;

   SblConfig strictFvg = Config();
   strictFvg.useFvgTrigger = true;
   strictFvg.useOteTrigger = false;
   strictFvg.useEmaTrigger = false;
   CHECK(strictFvg.requireDirectionalRejection);

   // Mode historique : un toucher CE et une cloture dans la bonne moitie ne
   // suffisent pas si le corps de bougie rejette dans le mauvais sens.
   const SblBar bearishLongCe =
      Bar(15,108.0,108.0,104.0,107.0,112.0);
   SblSetup strictLong = StartedLong(80);
   ConfirmLong(strictLong,strictFvg);
   CHECK(!SblAdvanceSetup(strictLong,bearishLongCe,SBL_LONG,NoPivot(),NoFvg(),
                          true,strictFvg,decision));
   CHECK(!decision.signal);
   CHECK(strictLong.phase == SBL_PHASE_WAIT_RETRACEMENT);

   const SblBar bullishShortCe =
      Bar(15,112.0,116.0,112.0,114.0,108.0);
   SblSetup strictShort = StartedShort(81);
   ConfirmShort(strictShort,strictFvg);
   CHECK(!SblAdvanceSetup(strictShort,bullishShortCe,SBL_SHORT,NoPivot(),
                          NoFvg(),true,strictFvg,decision));
   CHECK(!decision.signal);
   CHECK(strictShort.phase == SBL_PHASE_WAIT_RETRACEMENT);

   // Mode relache : les memes bougies sont admises, car le CE est reellement
   // touche et la cloture reste respectivement en discount/premium.
   SblConfig relaxedFvg = strictFvg;
   relaxedFvg.requireDirectionalRejection = false;
   SblSetup relaxedLong = StartedLong(82);
   ConfirmLong(relaxedLong,relaxedFvg);
   CHECK(SblAdvanceSetup(relaxedLong,bearishLongCe,SBL_LONG,NoPivot(),NoFvg(),
                         true,relaxedFvg,decision));
   CHECK(decision.signal);
   CHECK(decision.trigger == SBL_TRIGGER_FVG);

   SblSetup relaxedShort = StartedShort(83);
   ConfirmShort(relaxedShort,relaxedFvg);
   CHECK(SblAdvanceSetup(relaxedShort,bullishShortCe,SBL_SHORT,NoPivot(),
                         NoFvg(),true,relaxedFvg,decision));
   CHECK(decision.signal);
   CHECK(decision.trigger == SBL_TRIGGER_FVG);

   // Le relachement ne fabrique pas de toucher et ne contourne jamais la
   // bonne moitie de la jambe.
   SblSetup noLongCeTouch = StartedLong(84);
   ConfirmLong(noLongCeTouch,relaxedFvg);
   CHECK(!SblAdvanceSetup(noLongCeTouch,
                          Bar(15,108.0,108.0,107.0,107.5,112.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,relaxedFvg,
                          decision));
   CHECK(!decision.signal);
   CHECK(noLongCeTouch.phase == SBL_PHASE_WAIT_RETRACEMENT);

   SblSetup wrongLongHalf = StartedLong(85);
   ConfirmLong(wrongLongHalf,relaxedFvg);
   CHECK(!SblAdvanceSetup(wrongLongHalf,
                          Bar(15,114.0,114.0,105.0,113.0,112.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,relaxedFvg,
                          decision));
   CHECK(!decision.signal);
   CHECK(wrongLongHalf.phase == SBL_PHASE_WAIT_RETRACEMENT);

   SblSetup wrongShortHalf = StartedShort(86);
   ConfirmShort(wrongShortHalf,relaxedFvg);
   CHECK(!SblAdvanceSetup(wrongShortHalf,
                          Bar(15,106.0,115.0,105.0,107.0,108.0),
                          SBL_SHORT,NoPivot(),NoFvg(),true,relaxedFvg,
                          decision));
   CHECK(!decision.signal);
   CHECK(wrongShortHalf.phase == SBL_PHASE_WAIT_RETRACEMENT);

   // OTE : intersection reelle sans exigence de couleur de bougie.
   SblConfig relaxedOte = Config();
   relaxedOte.requireDirectionalRejection = false;
   relaxedOte.useFvgTrigger = false;
   relaxedOte.useOteTrigger = true;
   relaxedOte.useEmaTrigger = false;
   SblSetup ote = StartedLong(87);
   ConfirmLong(ote,relaxedOte);
   CHECK(SblAdvanceSetup(ote,
                         Bar(15,108.0,109.0,104.0,106.0,112.0),
                         SBL_LONG,NoPivot(),NoFvg(),true,relaxedOte,
                         decision));
   CHECK(decision.trigger == SBL_TRIGGER_OTE);

   SblSetup noOteTouch = StartedLong(88);
   ConfirmLong(noOteTouch,relaxedOte);
   CHECK(!SblAdvanceSetup(noOteTouch,
                          Bar(15,111.0,111.0,110.0,110.5,112.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,relaxedOte,
                          decision));
   CHECK(!decision.signal);
   CHECK(noOteTouch.phase == SBL_PHASE_WAIT_RETRACEMENT);

   // EMA : en mode relache, le contrat devient toucher physique de l'EMA +
   // EMA et cloture dans la bonne moitie, sans rejet directionnel implicite.
   SblConfig relaxedEma = Config();
   relaxedEma.requireDirectionalRejection = false;
   relaxedEma.useFvgTrigger = false;
   relaxedEma.useOteTrigger = false;
   relaxedEma.useEmaTrigger = true;
   SblSetup emaLong = StartedLong(89);
   ConfirmLong(emaLong,relaxedEma);
   CHECK(SblAdvanceSetup(emaLong,
                         Bar(15,108.0,109.0,105.0,107.0,112.0,106.0),
                         SBL_LONG,NoPivot(),NoFvg(),true,relaxedEma,
                         decision));
   CHECK(decision.trigger == SBL_TRIGGER_EMA);

   SblSetup emaShort = StartedShort(90);
   ConfirmShort(emaShort,relaxedEma);
   CHECK(SblAdvanceSetup(emaShort,
                         Bar(15,112.0,116.0,111.0,113.0,108.0,114.0),
                         SBL_SHORT,NoPivot(),NoFvg(),true,relaxedEma,
                         decision));
   CHECK(decision.trigger == SBL_TRIGGER_EMA);

   SblSetup noEmaTouch = StartedLong(91);
   ConfirmLong(noEmaTouch,relaxedEma);
   CHECK(!SblAdvanceSetup(noEmaTouch,
                          Bar(15,109.0,109.0,107.0,108.0,112.0,106.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,relaxedEma,
                          decision));
   CHECK(!decision.signal);
   CHECK(noEmaTouch.phase == SBL_PHASE_WAIT_RETRACEMENT);

   // Meme en presence d'un toucher OTE valide, une FVG de contexte manquante
   // interdit explicitement le signal.
   SblSetup missingContextFvg = StartedLong(92);
   ConfirmLong(missingContextFvg,relaxedOte);
   missingContextFvg.hasContextFvg = false;
   CHECK(!SblAdvanceSetup(missingContextFvg,
                          Bar(15,108.0,109.0,104.0,106.0,112.0),
                          SBL_LONG,NoPivot(),NoFvg(),true,relaxedOte,
                          decision));
   CHECK(!decision.signal);
   CHECK(missingContextFvg.phase == SBL_PHASE_WAIT_RETRACEMENT);
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

void TestBoundedFvgCandidatePoolAndLegacyMode()
{
   CHECK(SblBoundMaxFvgCandidates(-1) == 1);
   CHECK(SblBoundMaxFvgCandidates(0) == 1);
   CHECK(SblBoundMaxFvgCandidates(1) == 1);
   CHECK(SblBoundMaxFvgCandidates(4) == 4);
   CHECK(SblBoundMaxFvgCandidates(5) == 4);

   // Capacite 1 : conserver exactement l'ancienne politique. Pour un LONG,
   // la seconde candidate remplace la premiere car sa borne haute est basse,
   // meme si sa borne d'invalidation est moins robuste.
   SblSetup legacyLong = StartedLong(100);
   legacyLong.legExtreme = 125.0;
   const SblFvg longFirst = Fvg(SBL_LONG,13,100.0,110.0);
   const SblFvg longSecond = Fvg(SBL_LONG,14,105.0,109.0);
   CHECK(SblCacheCandidateFvg(legacyLong,longFirst,1));
   CHECK(SblCacheCandidateFvg(legacyLong,longSecond,1));
   CHECK(legacyLong.candidateFvgCount == 1);
   CHECK_NEAR(legacyLong.candidateFvgLow,105.0,1e-12);
   CHECK_NEAR(legacyLong.candidateFvgHigh,109.0,1e-12);
   CHECK(legacyLong.candidateFvgBar == 14);

   // Rejouer strictement la meme FVG est idempotent.
   CHECK(SblCacheCandidateFvg(legacyLong,longSecond,1));
   CHECK(legacyLong.candidateFvgCount == 1);
   CHECK(legacyLong.candidateFvgBar == 14);

   // Miroir SHORT de la politique historique (borne basse la plus haute).
   SblSetup legacyShort = StartedShort(101);
   legacyShort.legExtreme = 95.0;
   const SblFvg shortFirst = Fvg(SBL_SHORT,13,112.0,120.0);
   const SblFvg shortSecond = Fvg(SBL_SHORT,14,113.0,118.0);
   CHECK(SblCacheCandidateFvg(legacyShort,shortFirst,1));
   CHECK(SblCacheCandidateFvg(legacyShort,shortSecond,1));
   CHECK(legacyShort.candidateFvgCount == 1);
   CHECK_NEAR(legacyShort.candidateFvgLow,113.0,1e-12);
   CHECK_NEAR(legacyShort.candidateFvgHigh,118.0,1e-12);
   CHECK(legacyShort.candidateFvgBar == 14);

   // Une capacite 2 garde les deux meilleures candidates. Une troisieme plus
   // robuste remplace deterministiquement la moins robuste, sans depasser la
   // borne configuree.
   SblSetup capacity = StartedLong(102);
   capacity.legExtreme = 130.0;
   CHECK(SblCacheCandidateFvg(capacity,Fvg(SBL_LONG,13,102.0,110.0),2));
   CHECK(SblCacheCandidateFvg(capacity,Fvg(SBL_LONG,14,104.0,109.0),2));
   CHECK(capacity.candidateFvgCount == 2);
   CHECK(SblCacheCandidateFvg(capacity,Fvg(SBL_LONG,15,100.0,108.0),2));
   CHECK(capacity.candidateFvgCount == 2);
   bool keptLow100 = false;
   bool keptLow102 = false;
   bool keptLow104 = false;
   for(int i = 0; i < capacity.candidateFvgCount; i++)
   {
      if(capacity.candidateFvgLows[i] == 100.0) keptLow100 = true;
      if(capacity.candidateFvgLows[i] == 102.0) keptLow102 = true;
      if(capacity.candidateFvgLows[i] == 104.0) keptLow104 = true;
   }
   CHECK(keptLow100);
   CHECK(keptLow102);
   CHECK(!keptLow104);

   // Toute valeur superieure a quatre est bornee par le stockage fixe.
   SblSetup bounded = StartedLong(103);
   bounded.legExtreme = 140.0;
   for(int i = 0; i < 6; i++)
      CHECK(SblCacheCandidateFvg(
         bounded,Fvg(SBL_LONG,13 + i,100.0 + i,108.0 + i),99));
   CHECK(bounded.candidateFvgCount == SBL_MAX_FVG_CANDIDATES);
}

void TestFvgCandidatePoolInvalidationAndRobustPromotion()
{
   // LONG : la candidate profonde survit tandis que l'autre est invalidee.
   // En capacite 1 historique, la premiere aurait deja ete perdue.
   SblSetup longInvalidation = StartedLong(104);
   longInvalidation.legExtreme = 125.0;
   CHECK(SblCacheCandidateFvg(
      longInvalidation,Fvg(SBL_LONG,13,100.0,110.0),4));
   CHECK(SblCacheCandidateFvg(
      longInvalidation,Fvg(SBL_LONG,14,105.0,109.0),4));
   CHECK(longInvalidation.candidateFvgCount == 2);
   CHECK(SblInvalidateCandidateFvgs(
      longInvalidation,Bar(15,105.0,107.0,103.0,104.0,105.0),4));
   CHECK(longInvalidation.candidateFvgCount == 1);
   CHECK_NEAR(longInvalidation.candidateFvgLow,100.0,1e-12);
   CHECK_NEAR(longInvalidation.candidateFvgHigh,110.0,1e-12);
   CHECK(SblHasPromotableCandidateFvg(longInvalidation));
   CHECK(SblPromoteCandidateFvg(longInvalidation,4));
   CHECK(longInvalidation.hasContextFvg);
   CHECK_NEAR(longInvalidation.fvgLow,100.0,1e-12);
   CHECK_NEAR(longInvalidation.fvgHigh,110.0,1e-12);
   CHECK(longInvalidation.candidateFvgCount == 0);
   CHECK(!longInvalidation.hasCandidateFvg);

   // Selection LONG : borne basse la plus basse, puis formation la plus
   // ancienne lorsque cette borne est identique. Une CE hors discount reste
   // exclue, quelle que soit la capacite.
   SblSetup longSelection = StartedLong(105);
   longSelection.legExtreme = 125.0; // EQ = 112
   CHECK(SblCacheCandidateFvg(
      longSelection,Fvg(SBL_LONG,13,101.0,109.0),4));
   CHECK(SblCacheCandidateFvg(
      longSelection,Fvg(SBL_LONG,14,100.0,110.0),4));
   CHECK(SblCacheCandidateFvg(
      longSelection,Fvg(SBL_LONG,15,100.0,108.0),4));
   CHECK(SblCacheCandidateFvg(
      longSelection,Fvg(SBL_LONG,16,113.0,115.0),4));
   CHECK(SblPromoteCandidateFvg(longSelection,4));
   CHECK(longSelection.fvgBar == 14);
   CHECK_NEAR(longSelection.fvgLow,100.0,1e-12);
   CHECK_NEAR(longSelection.fvgHigh,110.0,1e-12);

   // Miroir SHORT de l'invalidation individuelle.
   SblSetup shortInvalidation = StartedShort(106);
   shortInvalidation.legExtreme = 95.0;
   CHECK(SblCacheCandidateFvg(
      shortInvalidation,Fvg(SBL_SHORT,13,112.0,120.0),4));
   CHECK(SblCacheCandidateFvg(
      shortInvalidation,Fvg(SBL_SHORT,14,113.0,118.0),4));
   CHECK(SblInvalidateCandidateFvgs(
      shortInvalidation,Bar(15,118.0,120.0,117.0,119.0,118.0),4));
   CHECK(shortInvalidation.candidateFvgCount == 1);
   CHECK_NEAR(shortInvalidation.candidateFvgLow,112.0,1e-12);
   CHECK_NEAR(shortInvalidation.candidateFvgHigh,120.0,1e-12);
   CHECK(SblHasPromotableCandidateFvg(shortInvalidation));
   CHECK(SblPromoteCandidateFvg(shortInvalidation,4));
   CHECK_NEAR(shortInvalidation.fvgLow,112.0,1e-12);
   CHECK_NEAR(shortInvalidation.fvgHigh,120.0,1e-12);

   // Selection SHORT : borne haute la plus haute, puis candidate la plus
   // ancienne en cas d'egalite.
   SblSetup shortSelection = StartedShort(107);
   shortSelection.legExtreme = 95.0; // EQ = 108
   CHECK(SblCacheCandidateFvg(
      shortSelection,Fvg(SBL_SHORT,13,112.0,119.0),4));
   CHECK(SblCacheCandidateFvg(
      shortSelection,Fvg(SBL_SHORT,14,111.0,120.0),4));
   CHECK(SblCacheCandidateFvg(
      shortSelection,Fvg(SBL_SHORT,15,113.0,120.0),4));
   CHECK(SblCacheCandidateFvg(
      shortSelection,Fvg(SBL_SHORT,16,100.0,104.0),4));
   CHECK(SblPromoteCandidateFvg(shortSelection,4));
   CHECK(shortSelection.fvgBar == 14);
   CHECK_NEAR(shortSelection.fvgLow,111.0,1e-12);
   CHECK_NEAR(shortSelection.fvgHigh,120.0,1e-12);

   // Integration machine d'etat : le pool permet a une FVG survivante de
   // confirmer le setup, tandis que la capacite historique 1 reste bloquee
   // apres l'invalidation de la candidate de remplacement.
   SblConfig pooledConfig = Config();
   pooledConfig.maxFvgCandidates = 4;
   pooledConfig.minDisplacement = 27.0;
   const SblFvg machineLongFirst = Fvg(SBL_LONG,13,100.0,110.0);
   const SblFvg machineLongSecond = Fvg(SBL_LONG,14,105.0,109.0);
   SblSetup pooledMachine = StartedLong(108);
   LockLongPivot(pooledMachine,pooledConfig,machineLongFirst);
   SblDecision decision;
   CHECK(!SblAdvanceSetup(
      pooledMachine,Bar(14,109.0,125.0,107.0,112.0,109.0),
      SBL_LONG,NoPivot(),machineLongSecond,true,pooledConfig,decision));
   CHECK(pooledMachine.phase == SBL_PHASE_WAIT_CONFIRMATION);
   CHECK(pooledMachine.candidateFvgCount == 2);
   CHECK(!SblAdvanceSetup(
      pooledMachine,Bar(15,112.0,126.0,103.0,104.0,112.0),
      SBL_LONG,NoPivot(),NoFvg(),true,pooledConfig,decision));
   CHECK(pooledMachine.phase == SBL_PHASE_WAIT_RETRACEMENT);
   CHECK_NEAR(pooledMachine.fvgLow,100.0,1e-12);
   CHECK_NEAR(pooledMachine.fvgHigh,110.0,1e-12);

   SblConfig legacyConfig = pooledConfig;
   legacyConfig.maxFvgCandidates = 1;
   SblSetup legacyMachine = StartedLong(109);
   LockLongPivot(legacyMachine,legacyConfig,machineLongFirst);
   CHECK(!SblAdvanceSetup(
      legacyMachine,Bar(14,109.0,125.0,107.0,112.0,109.0),
      SBL_LONG,NoPivot(),machineLongSecond,true,legacyConfig,decision));
   CHECK(legacyMachine.phase == SBL_PHASE_WAIT_CONFIRMATION);
   CHECK(legacyMachine.candidateFvgCount == 1);
   CHECK_NEAR(legacyMachine.candidateFvgLow,105.0,1e-12);
   CHECK(!SblAdvanceSetup(
      legacyMachine,Bar(15,112.0,126.0,103.0,104.0,112.0),
      SBL_LONG,NoPivot(),NoFvg(),true,legacyConfig,decision));
   CHECK(legacyMachine.phase == SBL_PHASE_WAIT_CONFIRMATION);
   CHECK(!legacyMachine.hasContextFvg);
   CHECK(legacyMachine.candidateFvgCount == 0);
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
      {"configurable internal pivot strength",
       TestConfigurableInternalPivotStrength},
      {"FVG detection and CE value area", TestFvgDetectionAndCeValueArea},
      {"valid LONG and SHORT machines", TestValidLongAndShortMachines},
      {"target and MSS chronology", TestTargetAndMssChronology},
      {"target before internal pivot policy",
       TestTargetBeforeInternalPivotPolicy},
      {"MSS before target policy", TestMssBeforeTargetPolicy},
      {"window identity invalidation", TestWindowIdentityInvalidatesImmediately},
      {"CE touch and alternative triggers", TestFvgCeTouchAndAlternativeTriggers},
      {"optional directional rejection", TestOptionalDirectionalRejection},
      {"end-to-end FVG, CE and displacement guards",
       TestEndToEndFvgCeAndDisplacementGuards},
      {"bounded FVG candidate pool and legacy mode",
       TestBoundedFvgCandidatePoolAndLegacyMode},
      {"FVG candidate invalidation and robust promotion",
       TestFvgCandidatePoolInvalidationAndRobustPromotion},
      {"invalidations, candidates and expiry", TestInvalidationsCandidatesAndExpiry},
      {"consumed liquidity registry", TestConsumedRegistry},
   };

   for(const auto &test : tests)
      Run(test.first, test.second);

   std::cout << g_assertions << " assertions, " << g_failures
             << " failure(s)\n";
   return g_failures == 0 ? 0 : 1;
}
