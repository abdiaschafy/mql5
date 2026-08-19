#!/usr/bin/env python3
"""Structural checks keeping both MT5 adapters on the shared decision core."""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STRATEGY = ROOT / "ICT_SilverBullet_Strategy.mq5"
SIGNALS = ROOT / "ICT_SilverBullet_Signals.mq5"
CORE = ROOT / "ICT_SilverBullet_Core.mqh"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class SharedCoreContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.strategy = read(STRATEGY)
        cls.signals = read(SIGNALS)
        cls.core = read(CORE)

    def assert_contains_regex(self, source: str, pattern: str, message: str) -> None:
        if re.search(pattern, source) is None:
            self.fail(message)

    def assert_uses_core(self, source: str, component: str) -> None:
        self.assert_contains_regex(
            source,
            r'#include\s*[<"]ICT_SilverBullet_Core\.mqh[>"]',
            f"{component} must include the shared Silver Bullet core",
        )
        required_calls = (
            "SblStrictStack",
            "SblAlignedBias",
            "SblBrokerUtcOffsetSeconds",
            "SblNewYorkUtcOffsetSeconds",
            "SblInEntryWindowMinutes",
            "SblEntryWindowKey",
            "SblDetectInternalPivot",
            "SblRejectAmbiguousDualPivot",
            "SblDetectFvg",
            "SblPurgeReintegrated",
            "SblStartSetup",
            "SblAdvanceSetup",
            "SblResetRegistry",
            "SblRegistryContains",
            "SblRegistryConsume",
        )
        for function in required_calls:
            self.assert_contains_regex(
                source,
                rf"\b{function}\s*\(",
                f"{component} must call {function} instead of duplicating it",
            )

        required_types = (
            "SblConfig",
            "SblSetup",
            "SblPivot",
            "SblDecision",
            "SblConsumedRegistry",
        )
        for type_name in required_types:
            self.assert_contains_regex(
                source,
                rf"\b{type_name}\b",
                f"{component} must keep its state in {type_name}",
            )

    def test_strategy_uses_shared_core(self) -> None:
        self.assert_uses_core(self.strategy, "strategy")

    def test_indicator_uses_shared_core(self) -> None:
        self.assert_uses_core(self.signals, "indicator")

    def test_strategy_maps_core_decisions_to_orders(self) -> None:
        self.assert_contains_regex(
            self.strategy, r"\bSblDecision\b", "strategy must consume SblDecision"
        )
        self.assert_contains_regex(
            self.strategy, r"\btrade\.Buy\s*\(", "strategy must map LONG to trade.Buy"
        )
        self.assert_contains_regex(
            self.strategy, r"\btrade\.Sell\s*\(", "strategy must map SHORT to trade.Sell"
        )

    def test_indicator_maps_core_decisions_to_signals(self) -> None:
        self.assert_contains_regex(
            self.signals, r"\bSblDecision\b", "indicator must consume SblDecision"
        )
        self.assert_contains_regex(
            self.signals,
            r"\bDrawSignal\s*\(",
            "indicator must map decisions to DrawSignal",
        )

    def test_core_remains_platform_independent(self) -> None:
        forbidden_platform_symbols = (
            "CTrade",
            "CopyBuffer",
            "iOpen",
            "iHigh",
            "iLow",
            "iClose",
            "PositionSelect",
            "ObjectCreate",
            "TimeCurrent",
            "TimeGMT",
        )
        for symbol in forbidden_platform_symbols:
            if re.search(rf"\b{re.escape(symbol)}\b", self.core) is not None:
                self.fail(f"shared core must not depend on MT5 platform symbol {symbol}")

    def test_core_has_no_order_or_drawing_side_effects(self) -> None:
        self.assertNotIn("trade.", self.core)
        self.assertNotIn("DrawSignal(", self.core)

    def test_strict_ema_and_stack_contract_is_not_optional(self) -> None:
        for source, component in (
            (self.strategy, "strategy"),
            (self.signals, "indicator"),
        ):
            self.assertRegex(source, r"InpEmaFast\s*!=\s*10")
            self.assertRegex(source, r"InpEmaSlow\s*!=\s*20")
            self.assertRegex(source, r"InpHtfTF\s*!=\s*PERIOD_H1")
            self.assertRegex(source, r"InpConf1TF\s*!=\s*PERIOD_M5")
            self.assertRegex(source, r"InpConf2TF\s*!=\s*PERIOD_M1")
            self.assertRegex(source, r"InpTrendTF\s*!=\s*PERIOD_D1")
            self.assertIn("!InpRequireAlign", source, component)
            self.assertIn("!InpUseTrendFilter", source, component)
            self.assertIn("!InpRequireMSS", source, component)
            self.assertRegex(source, r"MathAbs\(InpOteLow-0\.62\)>1e-9")
            self.assertRegex(source, r"MathAbs\(InpOteHigh-0\.79\)>1e-9")
            self.assertRegex(source, r"InpUseSbWindows\s*=\s*true")

    def test_dated_new_york_dst_is_mandatory_in_both_adapters(self) -> None:
        strategy_validation_start = self.strategy.index("bool InputsAreValid(")
        strategy_validation_end = self.strategy.index(
            "string RegistryFileName(", strategy_validation_start
        )
        strategy_validation = self.strategy[
            strategy_validation_start:strategy_validation_end
        ]
        self.assertIn(
            "!InpAutoDST",
            strategy_validation,
            "strategy must reject manual NY offset compatibility mode",
        )

        indicator_init_start = self.signals.index("int OnInit(")
        indicator_init_end = self.signals.index(
            "void OnDeinit(", indicator_init_start
        )
        indicator_validation = self.signals[indicator_init_start:indicator_init_end]
        self.assertIn(
            "!InpAutoDST",
            indicator_validation,
            "indicator must reject manual NY offset compatibility mode",
        )

    def test_indicator_retries_temporarily_unavailable_data(self) -> None:
        self.assertRegex(self.signals, r"bool\s+TryTfBias\s*\(")
        self.assertNotRegex(self.signals, r"int\s+TfBias\s*\(")
        read_guard = self.signals.index("!TryTfBias(hHtfF")
        commit_time = self.signals.index("g_lastProcTime=time[b]", read_guard)
        commit_index = self.signals.index("g_barIndex++", read_guard)
        self.assertLess(read_guard, commit_time)
        self.assertLess(read_guard, commit_index)
        self.assertIn("datetime tclose=time[b]+periodSeconds", self.signals)
        self.assertNotIn("datetime tclose=time[b+1]", self.signals)

    def test_strategy_retries_bar_before_committing_it(self) -> None:
        retry = self.strategy.index(
            "if(!ProcessClosedBar(shift,decisionTime,nextBarIndex,fresh,"
        )
        commit_index = self.strategy.index("g_barIndex=nextBarIndex", retry)
        commit_time = self.strategy.index("g_lastBarOpen=nextBarOpen", retry)
        self.assertLess(retry, commit_index)
        self.assertLess(retry, commit_time)

    def test_adapters_use_nominal_bar_close_across_session_gaps(self) -> None:
        self.assertIn("datetime decisionTime=closedBarOpen+periodSeconds", self.strategy)
        self.assertIn("datetime tclose=time[b]+periodSeconds", self.signals)
        self.assertIn("datetime closeTime=openTime+duration", self.strategy)
        self.assertIn("datetime sourceClose=time[source]+periodSeconds", self.signals)
        self.assertNotIn("datetime tclose=time[b+1]", self.signals)

    def test_adapters_build_the_same_closed_bar_event(self) -> None:
        for source, component in (
            (self.strategy, "strategy"),
            (self.signals, "indicator"),
        ):
            self.assertRegex(source, r"\.previousClose\s*=")
            self.assertRegex(source, r"\.windowKey\s*=")
            self.assertRegex(source, r"SblDetectInternalPivot\(SBL_LONG")
            self.assertRegex(source, r"SblDetectInternalPivot\(SBL_SHORT")
            self.assertRegex(
                source,
                r"SblAdvanceSetup\([^;]+setupPivot[^;]+newFvg",
                f"{component} must pass the shared internal pivot to the core",
            )

    def test_indicator_exposes_and_forwards_internal_pivot_strength(self) -> None:
        self.assertRegex(
            self.signals,
            r"input\s+int\s+InpInternalPivotStrength\s*=\s*1\s*;",
        )
        self.assertRegex(
            self.signals,
            r"input\s+int\s+InpExternalPivotStrength\s*=\s*2\s*;",
        )
        self.assertRegex(
            self.signals,
            r"input\s+bool\s+InpAllowMssBeforeTarget\s*=\s*false\s*;",
        )
        self.assertRegex(
            self.signals,
            r"input\s+bool\s+InpAllowTargetBeforeInternalPivot\s*=\s*"
            r"false\s*;",
        )
        self.assertRegex(
            self.signals,
            r"input\s+bool\s+InpRequireDirectionalRejection\s*=\s*true\s*;",
        )
        self.assertRegex(
            self.signals,
            r"input\s+int\s+InpMaxFvgCandidates\s*=\s*1\s*;",
        )

        init_start = self.signals.index("int OnInit(")
        init_end = self.signals.index("void OnDeinit(", init_start)
        validation = self.signals[init_start:init_end]
        self.assertRegex(
            validation,
            r"InpInternalPivotStrength\s*<\s*1\s*\|\|\s*"
            r"InpInternalPivotStrength\s*>\s*2",
        )
        self.assertRegex(
            validation,
            r"InpExternalPivotStrength\s*<\s*1\s*\|\|\s*"
            r"InpExternalPivotStrength\s*>\s*2",
        )
        self.assertRegex(
            validation,
            r"InpMaxFvgCandidates\s*<\s*1\s*\|\|\s*"
            r"InpMaxFvgCandidates\s*>\s*4",
        )
        self.assertIn(
            "g_coreConfig.maxFvgCandidates=InpMaxFvgCandidates",
            validation,
        )
        self.assertIn(
            "g_coreConfig.allowMssBeforeTarget=InpAllowMssBeforeTarget",
            validation,
        )
        self.assertRegex(
            validation,
            r"g_coreConfig\.allowTargetBeforeInternalPivot\s*=\s*"
            r"InpAllowTargetBeforeInternalPivot",
        )
        self.assertRegex(
            validation,
            r"g_coreConfig\.requireDirectionalRejection\s*=\s*"
            r"InpRequireDirectionalRejection",
        )

        pivot_start = self.signals.index("SblBar externalTwoBefore")
        pivot_end = self.signals.index("SblBar bar;", pivot_start)
        pivot_logic = self.signals[pivot_start:pivot_end]
        for prefix, strength in (
            ("external", "InpExternalPivotStrength"),
            ("internal", "InpInternalPivotStrength"),
        ):
            with self.subTest(buffer=prefix):
                self.assertIn(f"if({strength}==1)", pivot_logic)
                self.assertIn(
                    f"{prefix}Candidate=pivotBars[3]", pivot_logic
                )
                self.assertIn(
                    f"{prefix}OneAfter=pivotBars[4]", pivot_logic
                )
                self.assertIn(
                    f"{prefix}TwoAfter=pivotBars[4]", pivot_logic
                )

        pairs = (
            (
                "SBL_LONG",
                "InpExternalPivotStrength",
                "external",
                "externalHighPivot",
            ),
            (
                "SBL_SHORT",
                "InpExternalPivotStrength",
                "external",
                "externalLowPivot",
            ),
            (
                "SBL_LONG",
                "InpInternalPivotStrength",
                "internal",
                "internalHighPivot",
            ),
            (
                "SBL_SHORT",
                "InpInternalPivotStrength",
                "internal",
                "internalLowPivot",
            ),
        )
        for direction, strength, prefix, output in pairs:
            with self.subTest(direction=direction, role=prefix):
                self.assertRegex(
                    pivot_logic,
                    rf"SblDetectInternalPivot\(\s*{direction}\s*,\s*"
                    rf"{strength}\s*,\s*{prefix}TwoBefore\s*,\s*"
                    rf"{prefix}OneBefore\s*,\s*{prefix}Candidate\s*,\s*"
                    rf"{prefix}OneAfter\s*,\s*{prefix}TwoAfter\s*,\s*"
                    rf"{output}\s*\)",
                    "external and internal pivots must keep independent buffers",
                )

        self.assertEqual(pivot_logic.count("InpExternalPivotStrength"), 3)
        self.assertEqual(pivot_logic.count("InpInternalPivotStrength"), 3)

        self.assertIn(
            "SblRejectAmbiguousDualPivot(externalHighPivot,externalLowPivot)",
            self.signals,
        )
        self.assertIn(
            "SblRejectAmbiguousDualPivot(internalHighPivot,internalLowPivot)",
            self.signals,
        )
        self.assertIn("setupPivot=internalHighPivot", self.signals)
        self.assertIn("setupPivot=internalLowPivot", self.signals)
        self.assertIn("g_lastSwingHi=externalHighPivot.price", self.signals)
        self.assertIn("g_lastSwingLo=externalLowPivot.price", self.signals)
        self.assertRegex(
            self.signals,
            r'return\s+InpAllowMssBeforeTarget\s*\?\s*"FLEXIBLE"\s*:\s*"STRICT"',
        )
        self.assertRegex(
            self.signals,
            r'return\s+InpAllowTargetBeforeInternalPivot\s*\?\s*'
            r'"FLEXIBLE"\s*:\s*"STRICT"',
        )
        self.assertRegex(
            self.signals,
            r'return\s+InpRequireDirectionalRejection\s*\?\s*'
            r'"STRICT"\s*:\s*"FLEXIBLE"',
        )
        self.assertIn(
            'StringFormat("ICT SBS P%d/%d EP%d/%d MSS:%s C/P:%s DR:%s FVC:%d"',
            self.signals,
        )
        self.assertIn(
            'StringFormat("SB P%d/%d EP%d/%d MSS:%s C/P:%s DR:%s FVC:%d"',
            self.signals,
        )

    def test_strategy_exposes_and_records_internal_pivot_strength(self) -> None:
        self.assertRegex(
            self.strategy,
            r"input\s+int\s+InpInternalPivotStrength\s*=\s*1\s*;",
        )
        self.assertRegex(
            self.strategy,
            r"input\s+int\s+InpExternalPivotStrength\s*=\s*2\s*;",
        )
        self.assertRegex(
            self.strategy,
            r"input\s+bool\s+InpAllowMssBeforeTarget\s*=\s*false\s*;",
        )
        self.assertRegex(
            self.strategy,
            r"input\s+bool\s+InpAllowTargetBeforeInternalPivot\s*=\s*false\s*;",
        )
        self.assertRegex(
            self.strategy,
            r"input\s+bool\s+InpRequireDirectionalRejection\s*=\s*true\s*;",
        )
        self.assertRegex(
            self.strategy,
            r"input\s+int\s+InpMaxFvgCandidates\s*=\s*1\s*;",
        )
        self.assertRegex(
            self.strategy,
            r"input\s+int\s+InpEntryEqToleranceTicks\s*=\s*0\s*;",
        )

        validation_start = self.strategy.index("bool InputsAreValid(")
        validation_end = self.strategy.index(
            "string RegistryFileName(", validation_start
        )
        validation = self.strategy[validation_start:validation_end]
        self.assertIn("InpInternalPivotStrength!=1", validation)
        self.assertIn("InpInternalPivotStrength!=2", validation)
        self.assertIn("InpExternalPivotStrength!=1", validation)
        self.assertIn("InpExternalPivotStrength!=2", validation)
        self.assertRegex(
            validation,
            r"InpMaxFvgCandidates\s*<\s*1\s*\|\|\s*"
            r"InpMaxFvgCandidates\s*>\s*4",
        )
        self.assertRegex(
            validation,
            r"InpEntryEqToleranceTicks\s*<\s*0\s*\|\|\s*"
            r"InpEntryEqToleranceTicks\s*>\s*50",
        )

        process_start = self.strategy.index("bool ProcessClosedBar(")
        process_end = self.strategy.index(
            "//+------------------------------------------------------------------+\n"
            "//| OnTick",
            process_start,
        )
        process = self.strategy[process_start:process_end]
        self.assertIn("referenceCandidate=oneAfter", process)
        self.assertIn("referenceOneAfter=newest", process)
        self.assertIn("internalCandidate=oneAfter", process)
        self.assertIn("internalOneAfter=newest", process)

        pairs = (
            ("SBL_LONG", "referenceHighPivot", "internalHighPivot"),
            ("SBL_SHORT", "referenceLowPivot", "internalLowPivot"),
        )
        for direction, reference_output, internal_output in pairs:
            with self.subTest(direction=direction, role="reference"):
                self.assertRegex(
                    process,
                    rf"SblDetectInternalPivot\(\s*{direction}\s*,\s*"
                    r"InpExternalPivotStrength\s*,\s*"
                    r"referenceTwoBefore\s*,\s*referenceOneBefore\s*,\s*"
                    r"referenceCandidate\s*,\s*referenceOneAfter\s*,\s*"
                    r"referenceTwoAfter\s*,\s*"
                    rf"{reference_output}\s*\)",
                    "external references must use their independent strength",
                )
            with self.subTest(direction=direction, role="internal"):
                self.assertRegex(
                    process,
                    rf"SblDetectInternalPivot\(\s*{direction}\s*,\s*"
                    r"InpInternalPivotStrength\s*,\s*internalTwoBefore\s*,\s*"
                    r"internalOneBefore\s*,\s*internalCandidate\s*,\s*"
                    r"internalOneAfter\s*,\s*internalTwoAfter\s*,\s*"
                    rf"{internal_output}\s*\)",
                    "only setup pivots may use the configurable strength",
                )

        self.assertEqual(process.count("SblRejectAmbiguousDualPivot("), 2)
        self.assertIn("setupPivot=internalHighPivot", process)
        self.assertIn("setupPivot=internalLowPivot", process)
        self.assertIn(
            "UpdateReferenceSwings(referenceHighPivot,referenceLowPivot)",
            process,
        )
        self.assertNotIn("UpdateReferenceSwings(internal", process)
        self.assertIn(
            "config.allowMssBeforeTarget=InpAllowMssBeforeTarget",
            self.strategy,
        )
        self.assertIn(
            "config.allowTargetBeforeInternalPivot="
            "InpAllowTargetBeforeInternalPivot",
            self.strategy,
        )
        self.assertIn(
            "config.requireDirectionalRejection="
            "InpRequireDirectionalRejection",
            self.strategy,
        )
        self.assertIn(
            "config.maxFvgCandidates=InpMaxFvgCandidates",
            self.strategy,
        )

        tester_start = self.strategy.index("double OnTester()")
        tester = self.strategy[tester_start:]
        self.assertIn(
            "SBopt_v2_%s_P%d_EP%d_MBT%d_TBI%d_DR%d_FVC%d_ET%d_", tester
        )
        self.assertRegex(
            tester,
            r"FileWrite\(file,_Symbol,InpInternalPivotStrength,\s*"
            r"InpExternalPivotStrength,\s*"
            r"\(int\)InpAllowMssBeforeTarget,\s*"
            r"\(int\)InpAllowTargetBeforeInternalPivot,\s*"
            r"\(int\)InpRequireDirectionalRejection,\s*"
            r"InpMaxFvgCandidates,\s*InpEntryEqToleranceTicks,",
        )

    def test_strategy_entry_eq_tolerance_is_execution_only(self) -> None:
        bounds_start = self.strategy.index("int BoundEntryEqToleranceTicks(")
        bounds_end = self.strategy.index(
            "void ObserveEntryValueAreaGap(", bounds_start
        )
        bounds = self.strategy[bounds_start:bounds_end]
        self.assertIn("if(requested<0) return 0", bounds)
        self.assertIn("if(requested>50) return 50", bounds)
        self.assertRegex(
            bounds,
            r"tolerance\s*=\s*BoundEntryEqToleranceTicks\(\s*"
            r"InpEntryEqToleranceTicks\s*\)\s*\*\s*tickSize",
        )
        self.assertRegex(
            bounds,
            r"setup\.direction==SBL_LONG[\s\S]*?lower=setup\.fib0;\s*"
            r"upper=equilibrium\+tolerance;",
            "LONG may extend only beyond EQ; fib0 must remain a hard bound",
        )
        self.assertRegex(
            bounds,
            r"setup\.direction==SBL_SHORT[\s\S]*?"
            r"lower=equilibrium-tolerance;\s*upper=setup\.fib0;",
            "SHORT may extend only beyond EQ; fib0 must remain a hard bound",
        )

        enter_start = self.strategy.index("bool EnterSetup(")
        enter_end = self.strategy.index(
            "//====================== GESTION DES POSITIONS", enter_start
        )
        enter = self.strategy[enter_start:enter_end]
        self.assertIn(
            "ExecutableEntryInValueArea(setup.logic,entry)", enter
        )
        self.assertIn(
            "ExecutableEntryInValueArea(setup.logic,fill)", enter
        )
        self.assertNotIn("SblPriceInValueArea(", enter)

        process_start = self.strategy.index("bool ProcessClosedBar(")
        process_end = self.strategy.index(
            "//+------------------------------------------------------------------+\n"
            "//| OnTick",
            process_start,
        )
        self.assertNotIn(
            "InpEntryEqToleranceTicks",
            self.strategy[process_start:process_end],
            "closed-bar Core decisions must remain strict",
        )

    def test_windows_are_mandatory_in_both_adapters(self) -> None:
        for source in (self.strategy, self.signals):
            self.assertIn("!InpUseSbWindows", source)
            self.assertRegex(source, r"requireWindow\s*=\s*true")
            self.assertRegex(source, r"SblEntryWindowKey\s*\(")

    def test_strategy_catches_up_without_trading_stale_signals(self) -> None:
        loop = self.strategy.index(
            "for(int shift=firstClosedShift;shift>=1;shift--)"
        )
        freshness = self.strategy.index("bool fresh=shift==1", loop)
        dispatch = self.strategy.index(
            "ProcessClosedBar(shift,decisionTime,nextBarIndex,fresh,", freshness
        )
        stale_guard = self.strategy.index("if(!allowExecution)")
        entry = self.strategy.index("EnterSetup(i,decision)", stale_guard)
        self.assertLess(loop, freshness)
        self.assertLess(freshness, dispatch)
        self.assertLess(stale_guard, entry)
        self.assertIn("serverNow-tclose<=periodSeconds", self.signals)
        self.assertIn(
            "bool currentTradingDay=NewYorkDayKey(decisionTime)==g_currentNyDayKey",
            self.strategy,
        )
        self.assertIn("bool created=allowSetupCreation", self.strategy)

    def test_swing_must_be_confirmed_on_an_earlier_bar_in_both_adapters(self) -> None:
        self.assertIn("g_lastSwingHighConfirmBar", self.strategy)
        self.assertIn("g_lastSwingLowConfirmBar", self.strategy)
        self.assertIn("nextBarIndex>g_lastSwingHighConfirmBar", self.strategy)
        self.assertIn("nextBarIndex>g_lastSwingLowConfirmBar", self.strategy)
        self.assertIn("g_lastSwingHiConfirmBar", self.signals)
        self.assertIn("g_lastSwingLoConfirmBar", self.signals)
        self.assertIn("g_barIndex>g_lastSwingHiConfirmBar", self.signals)
        self.assertIn("g_barIndex>g_lastSwingLoConfirmBar", self.signals)

    def test_new_external_pivots_do_not_rewrite_the_current_bar_history(self) -> None:
        strategy_events = self.strategy.index("bool rawHigh=highAvailable")
        strategy_update = self.strategy.index(
            "UpdateReferenceSwings(referenceHighPivot,referenceLowPivot)",
            strategy_events,
        )
        self.assertLess(strategy_events, strategy_update)

        signal_events = self.signals.index("bool rawHigh=highConfirmedEarlier")
        signal_update = self.signals.index(
            "g_lastSwingHi=externalHighPivot.price", signal_events
        )
        self.assertLess(signal_events, signal_update)

    def test_consumed_origin_and_target_are_both_enforced(self) -> None:
        for source in (self.strategy, self.signals):
            self.assertRegex(source, r"\bHasSetupForLiquidity\s*\(")
            self.assertNotRegex(source, r"\bSetupTargetSwept\s*\(")
            self.assertRegex(source, r"startDecision\.consumeTarget")
            self.assertRegex(source, r"decision\.consumeTarget")

        strategy_decision = self.strategy.index("if(decision.consumeTarget")
        strategy_remove = self.strategy.index(
            "if(g_setups[i].logic.phase==SBL_PHASE_INVALID", strategy_decision
        )
        self.assertLess(strategy_decision, strategy_remove)

        signal_decision = self.signals.index("if(decision.consumeTarget")
        signal_remove = self.signals.index(
            "if(g_setups[i].phase==SBL_PHASE_INVALID", signal_decision
        )
        self.assertLess(signal_decision, signal_remove)

        self.assertIn("if(rawLow) ConsumeLiquidity(SBL_LONG,lowKey)", self.strategy)
        self.assertIn("if(rawHigh) ConsumeLiquidity(SBL_SHORT,highKey)", self.strategy)
        self.assertRegex(
            self.signals,
            r"if\(rawLow\)\s+SblRegistryConsume\(g_consumed,SBL_LONG,lowKey\)",
        )
        self.assertRegex(
            self.signals,
            r"if\(rawHigh\)\s+SblRegistryConsume\(g_consumed,SBL_SHORT,highKey\)",
        )

    def test_market_entry_reconciles_the_real_fill(self) -> None:
        self.assertIn("trade.Result(openResult)", self.strategy)
        self.assertIn("double fill=openResult.price", self.strategy)
        self.assertIn("DEAL_PRICE", self.strategy)
        self.assertIn("POSITION_PRICE_OPEN", self.strategy)
        self.assertNotRegex(self.strategy, r"\bfill\s*=\s*decision\.expectedEntry")

    def test_uncertain_broker_result_cannot_rearm_the_same_entry(self) -> None:
        request = self.strategy.index("bool requestCompleted=sent")
        result_order = self.strategy.index(
            "setup.entryOrder=openResult.order", request
        )
        result_deal = self.strategy.index(
            "setup.entryDeal=openResult.deal", result_order
        )
        reconciliation = self.strategy.index("bool executionFound=", result_deal)
        uncertain = self.strategy.index("if(mustReconcile)", reconciliation)
        pending = self.strategy.index("setup.entryPending=true", uncertain)
        stored = self.strategy.index("g_setups[index]=setup", pending)
        accepted_locally = self.strategy.index("return true", stored)
        pending_manager = self.strategy.index(
            "if(g_setups[i].entryPending)", accepted_locally
        )
        historical_rejection = self.strategy.index(
            "HistoricalOrderRejected(g_setups[i].entryOrder)", pending_manager
        )
        self.assertLess(request, result_order)
        self.assertLess(result_order, result_deal)
        self.assertLess(result_deal, reconciliation)
        self.assertLess(reconciliation, uncertain)
        self.assertLess(uncertain, pending)
        self.assertLess(pending, stored)
        self.assertLess(stored, accepted_locally)
        self.assertLess(accepted_locally, pending_manager)
        self.assertLess(pending_manager, historical_rejection)
        self.assertIn("PendingEntryRequestCount()", self.strategy)
        self.assertIn("FindEntryDealByIdentity(g_setups[i])", self.strategy)
        self.assertIn("BrokerReconcileExpired(", self.strategy)

    def test_entry_deal_fallback_uses_strict_request_identity(self) -> None:
        enter = self.strategy.index("bool EnterSetup(")
        send = self.strategy.index("trade.Buy(", enter)
        request_snapshot = self.strategy[enter:send]
        self.assertIn(
            "setup.entryRequestTimeMsc",
            request_snapshot,
            "the request timestamp must be captured before the market order is sent",
        )
        self.assertRegex(
            request_snapshot,
            r"setup\.requestedLots\s*=\s*lots",
            "the requested volume must be captured before the market order is sent",
        )

        identity_start = self.strategy.index("bool FindEntryDealByIdentity(")
        identity_end = self.strategy.index("bool FindPositionByIdentifier(", identity_start)
        identity = self.strategy[identity_start:identity_end]
        adoption = identity.index("setup.entryDeal=deal")
        required_identity_fields = (
            "DEAL_TIME_MSC",
            "setup.entryRequestTimeMsc",
            "DEAL_TYPE",
            "DEAL_TYPE_BUY",
            "DEAL_TYPE_SELL",
            "DEAL_VOLUME",
            "setup.requestedLots",
        )
        for field in required_identity_fields:
            with self.subTest(field=field):
                self.assertIn(field, identity)
                self.assertLess(
                    identity.index(field),
                    adoption,
                    f"{field} must be checked before adopting an historical deal",
                )
        self.assertIn("DEAL_ORDER", identity)
        self.assertIn("expectedComment", identity)

    def test_market_entry_revalidates_the_live_window_before_sending(self) -> None:
        enter = self.strategy.index("bool EnterSetup(")
        buy = self.strategy.index("trade.Buy(", enter)
        sell = self.strategy.index("trade.Sell(", buy)
        preflight = self.strategy[enter:buy]
        self.assertRegex(
            preflight,
            r"TimeTradeServer\s*\(",
            "entry preflight must read live server time, not reuse bar-close time",
        )
        self.assertRegex(
            preflight,
            r"EntryWindowKey\s*\(",
            "entry preflight must recompute the live New York window identity",
        )
        self.assertIn(
            "setup.logic.windowKey",
            preflight,
            "the live window must still be the setup's creation window",
        )
        self.assertLess(buy, sell)

    def test_entry_remainder_cancellation_is_serialized_and_reconciled(self) -> None:
        manager = self.strategy.index("void ManageOpenPositionsEveryTick(")
        self.assertIn(
            "trade.OrderDelete(",
            self.strategy[manager:],
            "an active remainder of a partially filled entry must be cancelled",
        )
        delete = self.strategy.index("trade.OrderDelete(", manager)
        cancellation_prefix = self.strategy[manager:delete]
        self.assertIn(
            "entryCancelPending",
            cancellation_prefix,
            "an entry remainder must not receive a second cancellation request",
        )
        self.assertIn("ActiveOrderExists(", cancellation_prefix)

        pending = self.strategy.index("entryCancelPending=true", delete)
        request_id = self.strategy.index("entryCancelRequestId=", pending)
        pending_since = self.strategy.index("entryCancelPendingSince=", request_id)
        close = self.strategy.index("trade.PositionClose(", pending_since)
        self.assertLess(delete, pending)
        self.assertLess(pending, request_id)
        self.assertLess(request_id, pending_since)
        self.assertLess(pending_since, close)

        transaction = self.strategy.index("void OnTradeTransaction(")
        transaction_body = self.strategy[transaction:]
        self.assertRegex(
            transaction_body,
            r"entryCancelPending[^;]+entryCancelRequestId[^;]+result\.request_id",
            "cancellation completion must be correlated with its own request",
        )
        self.assertIn("entryCancelRejected", transaction_body)

    def test_stop_modification_is_serialized_and_reconciled(self) -> None:
        modify_start = self.strategy.index("bool ModifyPositionChecked(")
        modify_end = self.strategy.index("bool EnterSetup(", modify_start)
        modify = self.strategy[modify_start:modify_end]
        send = modify.index("trade.PositionModify(")
        self.assertIn(
            "modifyPending",
            modify[:send],
            "a pending SL modification must block a duplicate request",
        )
        for field in (
            "modifyOrder",
            "modifyRequestId",
            "modifyPendingSince",
            "modifyStop",
            "modifyTakeProfit",
        ):
            with self.subTest(field=field):
                self.assertIn(field, modify[send:])

        manager = self.strategy.index("void ManageOpenPositionsEveryTick(")
        manager_end = self.strategy.index(
            "//====================== TRAITEMENT D'UNE BOUGIE FERMEE", manager
        )
        reconciliation = self.strategy[manager:manager_end]
        self.assertIn("POSITION_SL", reconciliation)
        self.assertIn("POSITION_TP", reconciliation)
        pending_resolution = reconciliation.index("modifyPending")
        be_done = reconciliation.index("beDone=true", pending_resolution)
        runner_stop = reconciliation.index("runnerStop=", pending_resolution)
        self.assertLess(pending_resolution, be_done)
        self.assertLess(pending_resolution, runner_stop)

        transaction = self.strategy.index("void OnTradeTransaction(")
        transaction_body = self.strategy[transaction:]
        self.assertRegex(
            transaction_body,
            r"modifyPending[^;]+modifyRequestId[^;]+result\.request_id",
            "SL transaction completion must be correlated with its own request",
        )
        self.assertIn("modifyRejected", transaction_body)

    def test_strategy_persists_consumed_registry_outside_tester(self) -> None:
        self.assertRegex(self.strategy, r"\bLoadConsumedRegistry\s*\(")
        self.assertRegex(self.strategy, r"\bSaveConsumedRegistry\s*\(")
        self.assertRegex(self.strategy, r"\bConsumeLiquidity\s*\(")
        self.assertIn("FILE_COMMON|FILE_REWRITE", self.strategy)
        self.assertIn("MQLInfoInteger(MQL_TESTER)", self.strategy)

    def test_strategy_persists_daily_risk_state_and_blocks_unsafe_recovery(self) -> None:
        self.assertIn("SB_STATE_SIGNATURE_V3", self.strategy)
        self.assertIn("FileWriteDouble(file,g_dayRealized)", self.strategy)
        self.assertIn("FileWriteLong(file,g_riskLevel)", self.strategy)
        self.assertIn("FileWriteLong(file,g_dayLocked ? 1 : 0)", self.strategy)
        self.assertRegex(self.strategy, r"\bUnmanagedSymbolPositionCount\s*\(")
        self.assertRegex(self.strategy, r"\bActiveMagicSymbolOrderCount\s*\(")
        self.assertRegex(self.strategy, r"\bUntrackedMagicSymbolOrderCount\s*\(")
        self.assertIn("g_recoveryBlocked", self.strategy)

    def test_strategy_reconciles_actual_risk_after_fill(self) -> None:
        self.assertRegex(
            self.strategy,
            r"OrderCalcProfit\(orderType,_Symbol,actualVolume,\s*fill,stop,actualStopPnl\)",
        )
        self.assertRegex(
            self.strategy,
            r"double\s+riskTolerance\s*=\s*"
            r"MathMax\(0\.05,riskBudget\*1e-4\)\s*;",
            "post-fill numeric tolerance must stay at exactly 5 cents or "
            "0.01% of the risk budget, whichever is larger",
        )
        self.assertIn("actualRisk<=riskBudget+riskTolerance", self.strategy)
        self.assertIn(
            "if(!fillValid || (!protectionValid && !protectionPending))",
            self.strategy,
        )

    def test_strategy_retries_history_before_finalizing(self) -> None:
        self.assertRegex(self.strategy, r"bool\s+FinalizeSetup\s*\(")
        self.assertIn("!HistorySelectByPosition(setup.positionIdentifier)", self.strategy)
        self.assertIn("exitedVolume+volumeTolerance<enteredVolume", self.strategy)
        self.assertIn("if(FinalizeSetup(i)) RemoveSetup(i)", self.strategy)

    def test_strategy_uses_real_fill_volume_and_tick_management(self) -> None:
        self.assertNotRegex(self.strategy, r"\bfill\s*=\s*entry\s*;")
        self.assertIn("POSITION_PRICE_OPEN", self.strategy)
        self.assertIn("POSITION_VOLUME", self.strategy)
        deal_fill = self.strategy.index("fill=HistoryDealGetDouble")
        position_fill = self.strategy.index("fill=PositionGetDouble(POSITION_PRICE_OPEN)")
        self.assertLess(deal_fill, position_fill)
        manage = self.strategy.index("ManageOpenPositionsEveryTick();")
        new_bar_guard = self.strategy.index("currentBar==g_lastBarOpen", manage)
        self.assertLess(manage, new_bar_guard)

    def test_tp1_partial_fill_is_reconciled_before_marking_core_taken(self) -> None:
        partial = self.strategy.index("trade.PositionClosePartial(")
        request_done = self.strategy.index("bool requestDone=closed", partial)
        done_retcode = self.strategy.index(
            "partialRetcode==TRADE_RETCODE_DONE", request_done
        )
        volume_confirmation = self.strategy.index(
            "bool volumeConfirmed=SelectSetupPosition", done_retcode
        )
        remaining = self.strategy.index("double remaining=volumeConfirmed", partial)
        pending_guard = self.strategy.index(
            "if(requestPending || (requestDone && !volumeChanged))", done_retcode
        )
        pending = self.strategy.index("g_setups[i].partialPending=true", pending_guard)
        reconciled = self.strategy.index(
            "else if(requestDone && volumeConfirmed &&", pending
        )
        taken = self.strategy.index("g_setups[i].coreTaken=true", reconciled)
        self.assertLess(partial, request_done)
        self.assertLess(request_done, done_retcode)
        self.assertLess(done_retcode, volume_confirmation)
        self.assertLess(volume_confirmation, remaining)
        self.assertLess(done_retcode, pending_guard)
        self.assertLess(pending_guard, pending)
        self.assertLess(pending, reconciled)
        self.assertLess(remaining, reconciled)
        self.assertLess(reconciled, taken)
        self.assertIn("HistoricalOrderExecutionFinished(", self.strategy)

    def test_pending_partial_is_reconciled_after_price_leaves_tp1(self) -> None:
        manager = self.strategy.index("void ManageOpenPositionsEveryTick(")
        manager_end = self.strategy.index(
            "//====================== TRAITEMENT D'UNE BOUGIE FERMEE", manager
        )
        management = self.strategy[manager:manager_end]
        partial_reconciliation = management.index(
            "if(g_setups[i].partialPending)"
        )
        tp1_gate = management.index("if(tp1Reached")
        self.assertLess(
            partial_reconciliation,
            tp1_gate,
            "a pending partial close must resolve even after price retreats from TP1",
        )
        self.assertNotRegex(
            management,
            r"if\s*\(\s*tp1Reached\s*&&\s*g_setups\[i\]\.coreTaken\s*&&\s*"
            r"!g_setups\[i\]\.beDone",
        )

        # coreTaken describes the runner volume. It can already be true at
        # entry when the position is too small to split, so BE also needs an
        # explicit proof that TP1 was reached. An implementation that instead
        # initializes coreTaken false is accepted as an equivalent invariant.
        if "tp1Confirmed" in self.strategy:
            enter = self.strategy.index("bool EnterSetup(")
            entered_state = self.strategy[enter:manager]
            self.assertIn("setup.tp1Confirmed=false", entered_state)

            partial_section = management[partial_reconciliation:tp1_gate]
            self.assertIn("if(targetConfirmed)", partial_section)
            self.assertIn("tp1Confirmed=true", partial_section)

            be_guard = (
                r"if\s*\(\s*g_setups\[i\]\.tp1Confirmed\s*&&\s*"
                r"g_setups\[i\]\.coreTaken\s*&&\s*"
                r"!g_setups\[i\]\.beDone"
            )
            self.assertRegex(
                management,
                be_guard,
                "BE must require independently confirmed TP1 and runner volume",
            )
        else:
            enter = self.strategy.index("bool EnterSetup(")
            entered_state = self.strategy[enter:manager]
            self.assertIn(
                "setup.coreTaken=false",
                entered_state,
                "without a TP1 flag, coreTaken must remain false until TP1",
            )
            self.assertRegex(
                management,
                r"if\s*\(\s*g_setups\[i\]\.coreTaken\s*&&\s*"
                r"!g_setups\[i\]\.beDone",
            )

    def test_force_close_request_is_not_resent_while_pending(self) -> None:
        force_close = self.strategy.index("if(g_setups[i].forceClose)")
        pending_guard = self.strategy.index(
            "if(g_setups[i].closePending)", force_close
        )
        close_request = self.strategy.index("trade.PositionClose(", pending_guard)
        pending_state = self.strategy.index(
            "g_setups[i].closePending=true", close_request
        )
        self.assertLess(force_close, pending_guard)
        self.assertLess(pending_guard, close_request)
        self.assertLess(close_request, pending_state)

    def test_strategy_funnel_telemetry_is_observational_and_stable(self) -> None:
        enabled_start = self.strategy.index("bool FunnelTelemetryEnabled(")
        enabled_end = self.strategy.index(
            "void ResetFunnelTelemetry(", enabled_start
        )
        enabled = self.strategy[enabled_start:enabled_end]
        self.assertIn("InpVerbose", enabled)
        self.assertIn("MQLInfoInteger(MQL_TESTER)", enabled)

        process = self.strategy.index("bool ProcessClosedBar(")
        advance = self.strategy.index("SblAdvanceSetup(", process)
        observation = self.strategy.index("ObserveFunnelAdvance(", advance)
        self.assertLess(
            advance,
            observation,
            "telemetry must observe the completed core decision",
        )

        observer_start = self.strategy.index("void ObserveFunnelAdvance(")
        observer_end = self.strategy.index("bool InputsAreValid(", observer_start)
        observer = self.strategy[observer_start:observer_end]
        for transition in (
            "hasInternalPivot",
            "targetTaken",
            "hasPendingMss",
            "mssBar",
            "confirmationBar",
            "hasContextFvg",
            "trigger",
            "decision.signal",
        ):
            with self.subTest(transition=transition):
                self.assertIn(transition, observer)
        self.assertIn("if(!FunnelTelemetryEnabled()) return", observer)

        creation = self.strategy.index("g_setups[count]=candidate")
        created_counter = self.strategy.index(
            "g_funnel.setupsCreated++", creation
        )
        self.assertLess(creation, created_counter)

        tester_start = self.strategy.index("double OnTester()")
        tester = self.strategy[tester_start:]
        self.assertIn("ICT_SB_FUNNEL,setups_created=", tester)
        self.assertIn("pending_mss=", tester)
        self.assertIn("early_target=", tester)
        self.assertRegex(
            observer,
            r"phaseBefore==SBL_PHASE_WAIT_INTERNAL_PIVOT\s*&&\s*"
            r"!hadTarget\s*&&\s*setup\.targetTaken\s*&&\s*"
            r"setup\.phase!=SBL_PHASE_INVALID",
        )
        for field in (
            "invalid_wait_internal",
            "invalid_wait_target",
            "invalid_wait_mss",
            "invalid_wait_confirmation",
            "invalid_wait_retracement",
            "invalid_triggered",
            "invalid_other",
        ):
            with self.subTest(field=field):
                self.assertIn(field, tester)

    def test_strategy_entry_funnel_observes_existing_rejection_paths(self) -> None:
        enter_start = self.strategy.index("bool EnterSetup(")
        enter_end = self.strategy.index(
            "//====================== GESTION DES POSITIONS", enter_start
        )
        enter = self.strategy[enter_start:enter_end]
        self.assertIn("bool observeEntry=FunnelTelemetryEnabled()", enter)
        self.assertLess(
            enter.index("g_funnel.entryAttempts++"),
            enter.index("SymbolInfoTick("),
        )

        for counter in (
            "entryRejectQuote",
            "entryRejectValueArea",
            "entryRejectRisk",
            "entryRejectStopLevel",
            "entryRejectLots",
            "entryRejectWindow",
            "entryBrokerReject",
            "entryPending",
            "entryConfirmed",
        ):
            with self.subTest(counter=counter):
                self.assertIn(f"g_funnel.{counter}++", enter)
        self.assertIn("ObserveEntryValueAreaGap(setup.logic,entry)", enter)

        helper_start = self.strategy.index("void ObserveEntryValueAreaGap(")
        helper_end = self.strategy.index("bool InputsAreValid(", helper_start)
        helper = self.strategy[helper_start:helper_end]
        self.assertIn(
            "ExecutableEntryValueAreaGapTicks(setup,entry)", helper
        )
        self.assertIn("entryRejectValueAreaMaxGapTicks", helper)

        distance_start = self.strategy.index(
            "double ExecutableEntryValueAreaGapTicks("
        )
        distance_end = self.strategy.index(
            "void ObserveEntryValueAreaGap(", distance_start
        )
        distance = self.strategy[distance_start:distance_end]
        self.assertIn("ExecutableEntryBounds(setup,lower,upper)", distance)
        self.assertIn("gap/tickSize", distance)

        tester_start = self.strategy.index("double OnTester()")
        tester = self.strategy[tester_start:]
        for field in (
            "entry_attempt=",
            "reject_quote=",
            "reject_value_area=",
            "reject_value_area_max_gap_ticks=",
            "reject_risk=",
            "reject_stop_level=",
            "reject_lots=",
            "reject_window=",
            "broker_reject=",
            "pending=",
            "confirmed=",
        ):
            with self.subTest(field=field):
                self.assertIn(field, tester)

    def test_core_retains_fvg_candidate_until_confirmation(self) -> None:
        self.assertIn("hasCandidateFvg", self.core)
        self.assertRegex(self.core, r"\bSblCacheCandidateFvg\s*\(")
        self.assertRegex(self.core, r"\bSblPromoteCandidateFvg\s*\(")


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(SharedCoreContractTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
