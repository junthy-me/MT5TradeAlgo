#property strict
#property version   "1.00"
#property description "MT5 P4 pattern strategy"

#include <Trade/Trade.mqh>

#define PATTERN_POINT_COUNT 7
#define PATTERN_SEGMENT_COUNT 6
#define HISTORY_CANDIDATE_GROWTH_STEP 512

input string InpSymbols = "XAUUSD";
input ENUM_TIMEFRAMES InpTF = PERIOD_M10;
input int InpTimerMillSec = 100;
input long InpMagic = 9527001;
input string InpComment = "P4PatternStrategy";

input double InpFixedLots = 0.05;
input int InpMaxPositionsPerSymbol = 1;
input int InpSlippagePoints = 20;
input int InpProfitObservationBars = 10;
input int InpStopObservationBars = 10;
input int InpLookbackBars = 300;
input int InpAdjustPointMinSpanKNumber = 3;
input int InpAdjustPointMaxSpanKNumber = 35;

input double InpCondAXMin = 0.75;
input double InpCondAXMax = 1.25;
input double InpP3P4DropMinRatioOfStructure = 0.44;
input double InpCondCZ = 1.0;
input double InpP1P2AValueSpaceMinPriceLimit = 0.0;
input int InpP1P2AValueTimeMinKNumberLimit = 1;
input double InpBSumValueMinRatioOfAValue = 2.0;
input double InpBSumValueMaxRatioOfAValue = 10.0;
input bool InpPreCondEnable = false;
input int InpPreCondPriorDeclineLookbackBars = 30;
input double InpPreCondPriorDeclineMinDropRatioOfStructure = 0.45;
input int InpPreCondPriorDeclineMinBarsBetweenPre0AndP0 = 0;

input double InpP5P6ReboundMinRatioOfP3P5Drop = 0.55;
input double InpSoftLossC = 1.0;
input double InpP5AnchoredProfitC = 1.0;
input bool InpEnableExactSearchCompare = false;

struct PatternSnapshot
  {
   bool              valid;
   string            symbol;
   int               pointIndexes[PATTERN_POINT_COUNT];
   datetime          p4BarTime;
   datetime          pointTimes[PATTERN_POINT_COUNT];
   long              pointTimesMsc[PATTERN_POINT_COUNT];
   double            pointPrices[PATTERN_POINT_COUNT];
   int               pointSpans[PATTERN_SEGMENT_COUNT];
   double            spanValues[PATTERN_SEGMENT_COUNT];
   double            a;
   double            b1;
   double            b2;
   double            c;
   double            d;
   double            e;
   double            r1;
   double            r2;
   double            sspanmin;
   double            t[PATTERN_SEGMENT_COUNT];
   double            triggerPatternTotalTimeMinute;
   bool              preCondPriorDecline;
   int               pre0Index;
   datetime          pre0Time;
   double            pre0Price;
   double            pre0Drop;
   double            pre0MinRequiredDrop;
   int               pre0BarsBetweenP0;
   bool              condA;
   bool              condB;
   bool              condC;
   bool              condD;
   bool              condF;
   bool              profitTargetActive;
   double            referenceEntryPrice;
   double            hardLossPrice;
   double            softLossPrice;
   double            profitPrice;
  };

struct BackboneSuccessState
  {
   datetime          pointTimes[4];
   datetime          successfulP4BarTime;
  };

struct SymbolRuntimeState
  {
   string            symbol;
   datetime          lastClosedBarTime;
   long              lastProcessedTickTimeMsc;
   double            lastProcessedTickBid;
   double            lastProcessedTickAsk;
   bool              historyCacheReady;
   int               historyCandidateCount;
   int               historyCandidateCapacity;
   PatternSnapshot   historyCandidates[];
   datetime          lastEvaluatedP4Time;
   double            lastEvaluatedP4Price;
   datetime          lastSuccessfulEntryBarTime;
   datetime          lastProfitTargetExitBarTime;
   datetime          lastStopExitBarTime;
   int               backboneSuccessCount;
   BackboneSuccessState backboneSuccesses[];
  };

struct P5ActivationCandidate
  {
   bool              valid;
   int               p5Index;
   int               p6Index;
   datetime          p5Time;
   datetime          p6Time;
   long              p5TimeMsc;
   long              p6TimeMsc;
   double            p5Price;
   double            p6Price;
   int               p5Span;
   int               p6Span;
   double            d;
   double            e;
   double            t5;
   double            t6;
   double            barHighAtP5Confirmation;
   double            softLossPrice;
   double            profitPrice;
  };

struct ManagedPositionState
  {
   bool              active;
   ulong             ticket;
   string            symbol;
   datetime          openedAt;
   PatternSnapshot   snapshot;
   bool              softStopActive;
   bool              p5ActivationFrozen;
   bool              intrabarTrackingInitialized;
   double            intrabarLastBid;
   double            entryBarLowAtP4;
   double            intrabarCurrentLowPrice;
   datetime          intrabarCurrentLowTime;
   long              intrabarCurrentLowTimeMsc;
   bool              intrabarCurrentLowConfirmed;
   int               observedP5CandidateCount;
   int               observedP5CandidateCapacity;
   P5ActivationCandidate observedP5Candidates[];
  };

CTrade trade;
string g_symbols[];
SymbolRuntimeState g_symbolStates[];
ManagedPositionState g_positionStates[];

int OnInit()
  {
   if(!ValidateInputs())
      return(INIT_PARAMETERS_INCORRECT);

   if(!ParseSymbols())
      return(INIT_PARAMETERS_INCORRECT);

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);

   if(!EventSetMillisecondTimer(InpTimerMillSec))
     {
      Print("Failed to register millisecond timer.");
      return(INIT_FAILED);
     }

   PrintFormat("Initialized P4PatternStrategy. symbols=%s timeframe=%s timer_ms=%d",
               InpSymbols,
               EnumToString(InpTF),
               InpTimerMillSec);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   PrintFormat("Deinitialized P4PatternStrategy. reason=%d", reason);
  }

void OnTick()
  {
  }

void OnTimer()
  {
   const int symbolCount = ArraySize(g_symbols);
   for(int i = 0; i < symbolCount; ++i)
      ProcessSymbol(g_symbols[i]);
  }

bool ValidateInputs()
  {
   if(InpTimerMillSec <= 0 || InpFixedLots <= 0.0 || InpMaxPositionsPerSymbol <= 0)
     {
      Print("Invalid runtime risk settings.");
      return(false);
     }

   if(InpAdjustPointMinSpanKNumber < 0 || InpAdjustPointMaxSpanKNumber < 0 || InpAdjustPointMinSpanKNumber > InpAdjustPointMaxSpanKNumber)
     {
      Print("Invalid min/max point span settings.");
      return(false);
     }

   if(InpLookbackBars < ((InpAdjustPointMaxSpanKNumber + 1) * 4))
     {
      Print("Lookback bars are too small for the configured max point span.");
      return(false);
     }

   if(InpProfitObservationBars < 0)
     {
      Print("InpProfitObservationBars must be greater than or equal to 0.");
      return(false);
     }

   if(InpStopObservationBars < 0)
     {
      Print("InpStopObservationBars must be greater than or equal to 0.");
      return(false);
     }

   if(InpCondAXMin <= 0.0 || InpCondAXMax <= 0.0 || InpCondAXMin > InpCondAXMax)
     {
      Print("Invalid CondA range.");
      return(false);
     }

   if(InpP3P4DropMinRatioOfStructure < 0.0)
     {
      Print("Invalid P3-P4 drop ratio threshold.");
      return(false);
     }

   if(InpP1P2AValueSpaceMinPriceLimit < 0.0)
     {
      Print("Invalid P1-P2 a-value minimum price threshold.");
      return(false);
     }

   if(InpP1P2AValueTimeMinKNumberLimit < 1)
     {
      Print("Invalid P1-P2 a-value minimum bar count.");
      return(false);
     }

   if(InpBSumValueMinRatioOfAValue < 0.0)
     {
      Print("Invalid b-sum to a-value minimum ratio threshold.");
      return(false);
     }

   if(InpBSumValueMaxRatioOfAValue < 0.0)
     {
      Print("Invalid b-sum to a-value maximum ratio threshold.");
      return(false);
     }

   if(InpBSumValueMaxRatioOfAValue < InpBSumValueMinRatioOfAValue)
     {
      Print("Invalid b-sum ratio range: max must be greater than or equal to min.");
      return(false);
     }

   if(InpPreCondPriorDeclineLookbackBars < 1)
     {
      Print("Invalid prior decline precondition lookback bars.");
      return(false);
     }

   if(InpPreCondPriorDeclineMinDropRatioOfStructure < 0.0)
     {
      Print("Invalid prior decline precondition minimum drop ratio.");
      return(false);
     }

   if(InpPreCondPriorDeclineMinBarsBetweenPre0AndP0 < 0)
     {
      Print("Invalid prior decline precondition minimum bars between Pre0 and P0.");
      return(false);
     }

   if(InpP5AnchoredProfitC < 0.0)
     {
      Print("InpP5AnchoredProfitC must be greater than or equal to 0.");
      return(false);
     }

   return(true);
  }

bool ParseSymbols()
  {
   string rawSymbols[];
   const int parts = StringSplit(InpSymbols, ';', rawSymbols);
   if(parts <= 0)
     {
      Print("InpSymbols does not contain any symbol.");
      return(false);
     }

   ArrayResize(g_symbols, 0);
   ArrayResize(g_symbolStates, 0);

   for(int i = 0; i < parts; ++i)
     {
      string symbol = rawSymbols[i];
      StringTrimLeft(symbol);
      StringTrimRight(symbol);
      if(symbol == "")
         continue;

      if(!SymbolSelect(symbol, true))
        {
         PrintFormat("Failed to select symbol %s", symbol);
         continue;
        }

      const int nextIndex = ArraySize(g_symbols);
      ArrayResize(g_symbols, nextIndex + 1);
      ArrayResize(g_symbolStates, nextIndex + 1);
      g_symbols[nextIndex] = symbol;
      ResetSymbolState(g_symbolStates[nextIndex], symbol);
     }

   if(ArraySize(g_symbols) == 0)
     {
      Print("No valid symbols were parsed from InpSymbols.");
      return(false);
     }

   return(true);
  }

void ProcessSymbol(const string symbol)
  {
   const int stateIndex = FindSymbolState(symbol);
   if(stateIndex < 0)
      return;

   if(!EnsureSymbolReady(symbol))
      return;

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick) || tick.ask <= 0.0)
      return;

   if(!HasNewProcessableTick(g_symbolStates[stateIndex], tick))
      return;

   CleanupPositionStates();
   ManageOpenPositions(symbol);

   PatternSnapshot match;
   if(!RefreshHistoricalCache(g_symbolStates[stateIndex]))
      return;

   const datetime currentBarTime = GetCurrentBarOpenTime(symbol);
   if(currentBarTime <= 0)
      return;

   const bool hasCachedMatch = EvaluateCachedRealtimePattern(g_symbolStates[stateIndex], tick, currentBarTime, match);
   if(InpEnableExactSearchCompare)
      CompareCachedAndLegacySearch(g_symbolStates[stateIndex], tick, currentBarTime, hasCachedMatch, match);

   if(!hasCachedMatch)
      return;

   if(match.pointTimes[4] <= g_symbolStates[stateIndex].lastEvaluatedP4Time &&
      match.pointPrices[4] == g_symbolStates[stateIndex].lastEvaluatedP4Price)
      return;

   g_symbolStates[stateIndex].lastEvaluatedP4Time = match.pointTimes[4];
   g_symbolStates[stateIndex].lastEvaluatedP4Price = match.pointPrices[4];

   datetime lastProfitTargetExitBarTime = 0;
   datetime lastStopExitBarTime = 0;
   int profitBlockedBarsRemaining = 0;
   int stopBlockedBarsRemaining = 0;
   const bool profitObservationLocked = IsProfitObservationLocked(g_symbolStates[stateIndex],
                                                                  symbol,
                                                                  currentBarTime,
                                                                  lastProfitTargetExitBarTime,
                                                                  profitBlockedBarsRemaining);
   const bool stopObservationLocked = IsStopObservationLocked(g_symbolStates[stateIndex],
                                                              symbol,
                                                              currentBarTime,
                                                              lastStopExitBarTime,
                                                              stopBlockedBarsRemaining);
   if(profitObservationLocked && stopObservationLocked)
      return;

   if(profitObservationLocked)
      return;

   if(stopObservationLocked)
      return;

   if(IsP4BarLocked(g_symbolStates[stateIndex], currentBarTime))
      return;

   datetime successfulBackboneP4BarTime = 0;
   string matchedBackbonePoint = "";
   if(IsBackboneSuccessLocked(g_symbolStates[stateIndex], match, successfulBackboneP4BarTime, matchedBackbonePoint))
      return;

   if(CountManagedPositions(symbol) >= InpMaxPositionsPerSymbol)
      return;

   ExecuteEntry(g_symbolStates[stateIndex], match);
  }

bool EnsureSymbolReady(const string symbol)
  {
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
     {
      if(!SymbolSelect(symbol, true))
         return(false);
     }

   long synchronized = 0;
   if(!SeriesInfoInteger(symbol, InpTF, SERIES_SYNCHRONIZED, synchronized))
      return(false);

   if(synchronized == 0)
      return(false);

   return(true);
  }

int FindSymbolState(const string symbol)
  {
   for(int i = 0; i < ArraySize(g_symbolStates); ++i)
     {
      if(g_symbolStates[i].symbol == symbol)
         return(i);
     }
   return(-1);
  }

double NormalizePrice(const string symbol, const double price)
  {
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return(NormalizeDouble(price, digits));
  }

datetime GetCurrentBarOpenTime(const string symbol)
  {
   return(iTime(symbol, InpTF, 0));
  }

bool IsP4BarLocked(const SymbolRuntimeState &state, const datetime currentBarTime)
  {
   return(currentBarTime > 0 && state.lastSuccessfulEntryBarTime == currentBarTime);
  }

bool IsObservationLocked(const datetime lastExitBarTime,
                         const string symbol,
                         const datetime currentBarTime,
                         const int configuredBars,
                         datetime &resolvedExitBarTime,
                         int &blockedBarsRemaining)
  {
   resolvedExitBarTime = lastExitBarTime;
   blockedBarsRemaining = 0;

   if(configuredBars <= 0 || currentBarTime <= 0 || resolvedExitBarTime <= 0)
      return(false);

   const int exitBarShift = iBarShift(symbol, InpTF, resolvedExitBarTime, false);
   if(exitBarShift < 0 || exitBarShift > configuredBars)
      return(false);

   blockedBarsRemaining = configuredBars - exitBarShift;
   return(true);
  }

bool IsProfitObservationLocked(const SymbolRuntimeState &state,
                               const string symbol,
                               const datetime currentBarTime,
                               datetime &lastProfitTargetExitBarTime,
                               int &blockedBarsRemaining)
  {
   return(IsObservationLocked(state.lastProfitTargetExitBarTime,
                              symbol,
                              currentBarTime,
                              InpProfitObservationBars,
                              lastProfitTargetExitBarTime,
                              blockedBarsRemaining));
  }

bool IsStopObservationLocked(const SymbolRuntimeState &state,
                             const string symbol,
                             const datetime currentBarTime,
                             datetime &lastStopExitBarTime,
                             int &blockedBarsRemaining)
  {
   return(IsObservationLocked(state.lastStopExitBarTime,
                              symbol,
                              currentBarTime,
                              InpStopObservationBars,
                              lastStopExitBarTime,
                              blockedBarsRemaining));
  }

string GetBackbonePointLabel(const int pointIndex)
  {
   switch(pointIndex)
     {
      case 0:
         return("P0");
      case 1:
         return("P1");
      case 2:
         return("P2");
      case 3:
         return("P3");
      default:
         return("unknown");
     }
  }

void LogEntryBlockedByP4Bar(const string symbol, const datetime currentBarTime)
  {
   PrintFormat("Entry blocked by P4 bar lock. symbol=%s timeframe=%s p4_bar=%s",
               symbol,
               EnumToString(InpTF),
               FormatTime(currentBarTime));
  }

void LogEntryBlockedByProfitObservation(const string symbol,
                                        const datetime currentBarTime,
                                        const datetime lastProfitTargetExitBarTime,
                                        const int blockedBarsRemaining)
  {
   PrintFormat("Entry blocked by post-profit observation window. symbol=%s timeframe=%s current_bar=%s profit_exit_bar=%s bars_remaining=%d configured_bars=%d",
               symbol,
               EnumToString(InpTF),
               FormatTime(currentBarTime),
               FormatTime(lastProfitTargetExitBarTime),
               blockedBarsRemaining,
               InpProfitObservationBars);
  }

void LogEntryBlockedByStopObservation(const string symbol,
                                      const datetime currentBarTime,
                                      const datetime lastStopExitBarTime,
                                      const int blockedBarsRemaining)
  {
   PrintFormat("Entry blocked by post-stop observation window. symbol=%s timeframe=%s current_bar=%s stop_exit_bar=%s bars_remaining=%d configured_bars=%d",
               symbol,
               EnumToString(InpTF),
               FormatTime(currentBarTime),
               FormatTime(lastStopExitBarTime),
               blockedBarsRemaining,
               InpStopObservationBars);
  }

void LogEntryBlockedByObservationWindows(const string symbol,
                                         const datetime currentBarTime,
                                         const datetime lastProfitTargetExitBarTime,
                                         const int profitBlockedBarsRemaining,
                                         const datetime lastStopExitBarTime,
                                         const int stopBlockedBarsRemaining)
  {
   PrintFormat("Entry blocked by overlapping observation windows. symbol=%s timeframe=%s current_bar=%s "
               "profit_exit_bar=%s profit_bars_remaining=%d profit_configured_bars=%d "
               "stop_exit_bar=%s stop_bars_remaining=%d stop_configured_bars=%d",
               symbol,
               EnumToString(InpTF),
               FormatTime(currentBarTime),
               FormatTime(lastProfitTargetExitBarTime),
               profitBlockedBarsRemaining,
               InpProfitObservationBars,
               FormatTime(lastStopExitBarTime),
               stopBlockedBarsRemaining,
               InpStopObservationBars);
  }

void ResetBackboneSuccesses(SymbolRuntimeState &state)
  {
   state.backboneSuccessCount = 0;
   ArrayResize(state.backboneSuccesses, 0);
  }

void RemoveBackboneSuccess(SymbolRuntimeState &state, const int index)
  {
   const int last = state.backboneSuccessCount - 1;
   if(index < 0 || index > last)
      return;

   for(int i = index; i < last; ++i)
      state.backboneSuccesses[i] = state.backboneSuccesses[i + 1];

   state.backboneSuccessCount--;
   ArrayResize(state.backboneSuccesses, state.backboneSuccessCount);
  }

void PruneBackboneSuccesses(SymbolRuntimeState &state, const datetime oldestRetainedBarTime)
  {
   if(oldestRetainedBarTime <= 0)
      return;

   for(int i = state.backboneSuccessCount - 1; i >= 0; --i)
     {
      if(state.backboneSuccesses[i].pointTimes[3] < oldestRetainedBarTime)
         RemoveBackboneSuccess(state, i);
     }
  }

int FindBackboneSuccess(const SymbolRuntimeState &state,
                        const PatternSnapshot &pattern,
                        int &matchedPointIndex)
  {
   matchedPointIndex = -1;
   for(int i = 0; i < state.backboneSuccessCount; ++i)
     {
      for(int pointIndex = 0; pointIndex < 4; ++pointIndex)
        {
         if(state.backboneSuccesses[i].pointTimes[pointIndex] <= 0 ||
            pattern.pointTimes[pointIndex] <= 0)
            continue;

         if(state.backboneSuccesses[i].pointTimes[pointIndex] == pattern.pointTimes[pointIndex])
           {
            matchedPointIndex = pointIndex;
            return(i);
           }
        }
     }
   return(-1);
  }

void MarkBackboneSuccess(SymbolRuntimeState &state,
                         const PatternSnapshot &pattern,
                         const datetime successfulP4BarTime)
  {
   int matchedPointIndex = -1;
   const int existing = FindBackboneSuccess(state, pattern, matchedPointIndex);
   if(existing >= 0)
     {
      state.backboneSuccesses[existing].successfulP4BarTime = successfulP4BarTime;
      return;
     }

   const int index = state.backboneSuccessCount;
   if(ArrayResize(state.backboneSuccesses, index + 1) < index + 1)
      return;

   for(int i = 0; i < 4; ++i)
      state.backboneSuccesses[index].pointTimes[i] = pattern.pointTimes[i];
   state.backboneSuccesses[index].successfulP4BarTime = successfulP4BarTime;
   state.backboneSuccessCount++;
  }

bool IsBackboneSuccessLocked(const SymbolRuntimeState &state,
                             const PatternSnapshot &pattern,
                             datetime &successfulBackboneP4BarTime,
                             string &matchedPointLabel)
  {
   int matchedPointIndex = -1;
   const int existing = FindBackboneSuccess(state, pattern, matchedPointIndex);
   if(existing < 0)
     {
      successfulBackboneP4BarTime = 0;
      matchedPointLabel = "";
      return(false);
     }

   successfulBackboneP4BarTime = state.backboneSuccesses[existing].successfulP4BarTime;
   matchedPointLabel = GetBackbonePointLabel(matchedPointIndex);
   return(successfulBackboneP4BarTime > 0);
  }

void LogEntryBlockedByBackboneSuccess(const PatternSnapshot &pattern,
                                      const datetime successfulBackboneP4BarTime,
                                      const string matchedPointLabel)
  {
   PrintFormat("Entry blocked by shared backbone successful P4 bar rule. symbol=%s timeframe=%s current_p4_bar=%s successful_p4_bar=%s "
               "matched_point=%s P0=%s P1=%s P2=%s P3=%s",
               pattern.symbol,
               EnumToString(InpTF),
               FormatTime(pattern.p4BarTime),
               FormatTime(successfulBackboneP4BarTime),
               matchedPointLabel,
               FormatTime(pattern.pointTimes[0]),
               FormatTime(pattern.pointTimes[1]),
               FormatTime(pattern.pointTimes[2]),
               FormatTime(pattern.pointTimes[3]));
  }

long FindOpenChart(const string symbol, const ENUM_TIMEFRAMES timeframe)
  {
   for(long chartId = ChartFirst(); chartId >= 0; chartId = ChartNext(chartId))
     {
      if(ChartSymbol(chartId) == symbol && (ENUM_TIMEFRAMES)ChartPeriod(chartId) == timeframe)
         return(chartId);
     }
   return(-1);
  }

string BuildEntryAnnotationPrefix(const PatternSnapshot &pattern, const ulong ticket)
  {
   return(StringFormat("P4Pattern_%s_%s_%I64u_%I64d",
                       pattern.symbol,
                       EnumToString(InpTF),
                       ticket,
                       (long)pattern.p4BarTime));
  }

color GetAnnotationPointColor(const string pointLabel)
  {
   if(pointLabel == "Pre0")
      return(clrRed);
   if(pointLabel == "P0")
      return(clrYellow);
   if(pointLabel == "P1")
      return(clrOrangeRed);
   if(pointLabel == "P2")
      return(clrHotPink);
   if(pointLabel == "P3")
      return(clrMagenta);
   if(pointLabel == "P4")
      return(clrGold);
   if(pointLabel == "P5")
      return(clrWhite);
   if(pointLabel == "P6")
      return(clrKhaki);
   return(clrWhiteSmoke);
  }

ENUM_ANCHOR_POINT GetAnnotationPointAnchor(const string pointLabel)
  {
   if(pointLabel == "P5")
      return(ANCHOR_LEFT_UPPER);
   if(pointLabel == "P6")
      return(ANCHOR_RIGHT_LOWER);
   return(ANCHOR_LEFT_LOWER);
  }

datetime MidTime(const datetime lhs, const datetime rhs)
  {
   if(lhs <= 0)
      return(rhs);
   if(rhs <= 0)
      return(lhs);
   return((datetime)(((long)lhs + (long)rhs) / 2));
  }

double MidPrice(const double lhs, const double rhs)
  {
   return((lhs + rhs) / 2.0);
  }

string FormatPriceValue(const string symbol, const double value)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 5;
   return(DoubleToString(value, digits));
  }

string FormatValueLabel(const string symbol, const string label, const double value)
  {
   return(label + "=" + FormatPriceValue(symbol, value));
  }

void ConfigureAnnotationObject(const long chartId, const string objectName)
  {
   ObjectSetInteger(chartId, objectName, OBJPROP_BACK, false);
   ObjectSetInteger(chartId, objectName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartId, objectName, OBJPROP_SELECTED, false);
   ObjectSetInteger(chartId, objectName, OBJPROP_HIDDEN, false);
  }

bool CreateAnnotationLine(const long chartId,
                          const string objectName,
                          const datetime fromTime,
                          const double fromPrice,
                          const datetime toTime,
                          const double toPrice,
                          const color lineColor)
  {
   if(ObjectFind(chartId, objectName) >= 0)
      ObjectDelete(chartId, objectName);

   if(!ObjectCreate(chartId, objectName, OBJ_TREND, 0, fromTime, fromPrice, toTime, toPrice))
      return(false);

   ConfigureAnnotationObject(chartId, objectName);
   ObjectSetInteger(chartId, objectName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(chartId, objectName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(chartId, objectName, OBJPROP_RAY_RIGHT, false);
   return(true);
  }

bool CreateAnnotationPoint(const long chartId,
                           const string objectPrefix,
                           const string pointLabel,
                           const datetime pointTime,
                           const double pointPrice,
                           const color pointColor)
  {
   const string markerName = objectPrefix + "_" + pointLabel + "_MARK";
   const string textName = objectPrefix + "_" + pointLabel + "_TEXT";

   if(ObjectFind(chartId, markerName) >= 0)
      ObjectDelete(chartId, markerName);
   if(!ObjectCreate(chartId, markerName, OBJ_ARROW, 0, pointTime, pointPrice))
      return(false);
   ConfigureAnnotationObject(chartId, markerName);
   ObjectSetInteger(chartId, markerName, OBJPROP_COLOR, pointColor);
   ObjectSetInteger(chartId, markerName, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(chartId, markerName, OBJPROP_WIDTH, 1);

   if(ObjectFind(chartId, textName) >= 0)
      ObjectDelete(chartId, textName);
   if(!ObjectCreate(chartId, textName, OBJ_TEXT, 0, pointTime, pointPrice))
      return(false);
   ConfigureAnnotationObject(chartId, textName);
   ObjectSetInteger(chartId, textName, OBJPROP_COLOR, pointColor);
   ObjectSetString(chartId, textName, OBJPROP_TEXT, pointLabel);
   ObjectSetInteger(chartId, textName, OBJPROP_ANCHOR, GetAnnotationPointAnchor(pointLabel));
   ObjectSetInteger(chartId, textName, OBJPROP_FONTSIZE, 10);
   return(true);
  }

bool CreateAnnotationValueLabel(const long chartId,
                                const string objectName,
                                const datetime pointTime,
                                const double pointPrice,
                                const string labelText,
                                const color labelColor)
  {
   if(ObjectFind(chartId, objectName) >= 0)
      ObjectDelete(chartId, objectName);

   if(!ObjectCreate(chartId, objectName, OBJ_TEXT, 0, pointTime, pointPrice))
      return(false);

   ConfigureAnnotationObject(chartId, objectName);
   ObjectSetInteger(chartId, objectName, OBJPROP_COLOR, labelColor);
   ObjectSetString(chartId, objectName, OBJPROP_TEXT, labelText);
   ObjectSetInteger(chartId, objectName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(chartId, objectName, OBJPROP_FONTSIZE, 10);
   return(true);
  }

bool CreateAnnotationLevel(const long chartId,
                           const string objectPrefix,
                           const string symbol,
                           const string levelLabel,
                           const datetime anchorTime,
                           const double levelPrice,
                           const color levelColor)
  {
   const string lineName = objectPrefix + "_" + levelLabel + "_LINE";
   const string textName = objectPrefix + "_" + levelLabel + "_TEXT";
   if(ObjectFind(chartId, lineName) >= 0)
      ObjectDelete(chartId, lineName);
   if(!ObjectCreate(chartId, lineName, OBJ_HLINE, 0, 0, levelPrice))
      return(false);

   ConfigureAnnotationObject(chartId, lineName);
   ObjectSetInteger(chartId, lineName, OBJPROP_COLOR, levelColor);
   ObjectSetInteger(chartId, lineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(chartId, lineName, OBJPROP_WIDTH, 1);

   return(CreateAnnotationValueLabel(chartId,
                                     textName,
                                     anchorTime,
                                     levelPrice,
                                     levelLabel + "=" + FormatPriceValue(symbol, levelPrice),
                                     levelColor));
  }

bool CreateP4BuyHighlight(const long chartId,
                          const string objectName,
                          const datetime pointTime,
                          const double pointPrice)
  {
   if(ObjectFind(chartId, objectName) >= 0)
      ObjectDelete(chartId, objectName);
   if(!ObjectCreate(chartId, objectName, OBJ_ARROW_BUY, 0, pointTime, pointPrice))
      return(false);

   ConfigureAnnotationObject(chartId, objectName);
   ObjectSetInteger(chartId, objectName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(chartId, objectName, OBJPROP_WIDTH, 2);
   return(true);
  }

bool DrawEntryPatternAnnotation(const PatternSnapshot &pattern,
                                const ulong ticket,
                                string &annotationStatus)
  {
   annotationStatus = "no_matching_chart";
   const long chartId = FindOpenChart(pattern.symbol, InpTF);
   if(chartId < 0)
      return(false);

   const string prefix = BuildEntryAnnotationPrefix(pattern, ticket);
   const color lineColor = clrSilver;
   const bool hasPre0 = pattern.preCondPriorDecline && pattern.pre0Time > 0;
   const bool hasP5 = pattern.pointTimes[5] > 0;
   const bool hasP6 = pattern.pointTimes[6] > 0;

   if((hasPre0 &&
       (!CreateAnnotationPoint(chartId, prefix, "Pre0", pattern.pre0Time, pattern.pre0Price, GetAnnotationPointColor("Pre0")) ||
        !CreateAnnotationLine(chartId, prefix + "_LPre0P0", pattern.pre0Time, pattern.pre0Price, pattern.pointTimes[0], pattern.pointPrices[0], lineColor))) ||
      !CreateAnnotationPoint(chartId, prefix, "P0", pattern.pointTimes[0], pattern.pointPrices[0], GetAnnotationPointColor("P0")) ||
      !CreateAnnotationPoint(chartId, prefix, "P1", pattern.pointTimes[1], pattern.pointPrices[1], GetAnnotationPointColor("P1")) ||
      !CreateAnnotationPoint(chartId, prefix, "P2", pattern.pointTimes[2], pattern.pointPrices[2], GetAnnotationPointColor("P2")) ||
      !CreateAnnotationPoint(chartId, prefix, "P3", pattern.pointTimes[3], pattern.pointPrices[3], GetAnnotationPointColor("P3")) ||
      !CreateAnnotationPoint(chartId, prefix, "P4", pattern.pointTimes[4], pattern.pointPrices[4], GetAnnotationPointColor("P4")) ||
      (hasP5 && !CreateAnnotationPoint(chartId, prefix, "P5", pattern.pointTimes[5], pattern.pointPrices[5], GetAnnotationPointColor("P5"))) ||
      (hasP6 && !CreateAnnotationPoint(chartId, prefix, "P6", pattern.pointTimes[6], pattern.pointPrices[6], GetAnnotationPointColor("P6"))) ||
      !CreateAnnotationLine(chartId, prefix + "_L01", pattern.pointTimes[0], pattern.pointPrices[0], pattern.pointTimes[1], pattern.pointPrices[1], lineColor) ||
      !CreateAnnotationLine(chartId, prefix + "_L12", pattern.pointTimes[1], pattern.pointPrices[1], pattern.pointTimes[2], pattern.pointPrices[2], lineColor) ||
      !CreateAnnotationLine(chartId, prefix + "_L23", pattern.pointTimes[2], pattern.pointPrices[2], pattern.pointTimes[3], pattern.pointPrices[3], lineColor) ||
      !CreateAnnotationLine(chartId, prefix + "_L34", pattern.pointTimes[3], pattern.pointPrices[3], pattern.pointTimes[4], pattern.pointPrices[4], lineColor) ||
      (hasP5 && !CreateAnnotationLine(chartId, prefix + "_L45", pattern.pointTimes[4], pattern.pointPrices[4], pattern.pointTimes[5], pattern.pointPrices[5], lineColor)) ||
      (hasP6 && !CreateAnnotationLine(chartId, prefix + "_L56", pattern.pointTimes[5], pattern.pointPrices[5], pattern.pointTimes[6], pattern.pointPrices[6], lineColor)) ||
      !CreateP4BuyHighlight(chartId, prefix + "_BUY", pattern.pointTimes[4], pattern.pointPrices[4]) ||
      !CreateAnnotationLevel(chartId, prefix, pattern.symbol, "hard_stop", pattern.pointTimes[4], pattern.hardLossPrice, clrRed) ||
      (pattern.softLossPrice > 0.0 &&
       !CreateAnnotationLevel(chartId, prefix, pattern.symbol, "soft_stop", hasP6 ? pattern.pointTimes[6] : pattern.pointTimes[4], pattern.softLossPrice, clrOrange)) ||
      (hasPre0 &&
       !CreateAnnotationValueLabel(chartId, prefix + "_V_PRE0_DROP", MidTime(pattern.pre0Time, pattern.pointTimes[0]), MidPrice(pattern.pre0Price, pattern.pointPrices[0]), FormatValueLabel(pattern.symbol, "pre0_drop", pattern.pre0Drop), GetAnnotationPointColor("Pre0"))) ||
      !CreateAnnotationValueLabel(chartId, prefix + "_V_B1", MidTime(pattern.pointTimes[0], pattern.pointTimes[2]), MidPrice(pattern.pointPrices[0], pattern.pointPrices[2]), FormatValueLabel(pattern.symbol, "b1", pattern.b1), GetAnnotationPointColor("P0")) ||
      !CreateAnnotationValueLabel(chartId, prefix + "_V_A", MidTime(pattern.pointTimes[1], pattern.pointTimes[2]), MidPrice(pattern.pointPrices[1], pattern.pointPrices[2]), FormatValueLabel(pattern.symbol, "a", pattern.a), GetAnnotationPointColor("P1")) ||
      !CreateAnnotationValueLabel(chartId, prefix + "_V_B2", MidTime(pattern.pointTimes[1], pattern.pointTimes[3]), MidPrice(pattern.pointPrices[1], pattern.pointPrices[3]), FormatValueLabel(pattern.symbol, "b2", pattern.b2), GetAnnotationPointColor("P3")) ||
      !CreateAnnotationValueLabel(chartId, prefix + "_V_C", MidTime(pattern.pointTimes[3], pattern.pointTimes[4]), MidPrice(pattern.pointPrices[3], pattern.pointPrices[4]), FormatValueLabel(pattern.symbol, "c", pattern.c), GetAnnotationPointColor("P4")))
     {
      annotationStatus = "draw_failed";
      return(false);
     }

   ChartRedraw(chartId);
   annotationStatus = "drawn";
   return(true);
  }

double GetRoleLow(const MqlRates &rate)
  {
   return(rate.low);
  }

double GetRoleHigh(const MqlRates &rate)
  {
   return(rate.high);
  }

bool SegmentEndpointsReachExtrema(const string symbol,
                                  MqlRates &rates[],
                                  const int startIndex,
                                  const int endIndex,
                                  const bool startUsesHigh,
                                  const bool endUsesHigh)
  {
   const int total = ArraySize(rates);
   if(startIndex < 0 || endIndex < startIndex || endIndex >= total)
      return(false);

   double segmentLow = NormalizePrice(symbol, GetRoleLow(rates[startIndex]));
   double segmentHigh = NormalizePrice(symbol, GetRoleHigh(rates[startIndex]));
   for(int i = startIndex + 1; i <= endIndex; ++i)
     {
      const double barLow = NormalizePrice(symbol, GetRoleLow(rates[i]));
      const double barHigh = NormalizePrice(symbol, GetRoleHigh(rates[i]));
      if(barLow < segmentLow)
         segmentLow = barLow;
      if(barHigh > segmentHigh)
         segmentHigh = barHigh;
     }

   const double startValue = NormalizePrice(symbol,
                                            startUsesHigh ? GetRoleHigh(rates[startIndex]) : GetRoleLow(rates[startIndex]));
   const double endValue = NormalizePrice(symbol,
                                          endUsesHigh ? GetRoleHigh(rates[endIndex]) : GetRoleLow(rates[endIndex]));

   if(startUsesHigh)
     {
      if(startValue < segmentHigh)
         return(false);
     }
   else
     {
      if(startValue > segmentLow)
         return(false);
     }

   if(endUsesHigh)
     {
      if(endValue < segmentHigh)
         return(false);
     }
   else
     {
      if(endValue > segmentLow)
         return(false);
     }

   return(true);
  }

bool SegmentHasAscendingEndpointExtrema(const string symbol,
                                        MqlRates &rates[],
                                        const int startIndex,
                                        const int endIndex)
  {
   return(SegmentEndpointsReachExtrema(symbol, rates, startIndex, endIndex, false, true));
  }

bool SegmentHasDescendingEndpointExtrema(const string symbol,
                                         MqlRates &rates[],
                                         const int startIndex,
                                         const int endIndex)
  {
   return(SegmentEndpointsReachExtrema(symbol, rates, startIndex, endIndex, true, false));
  }

void ResetPriorDeclineState(PatternSnapshot &pattern)
  {
   pattern.preCondPriorDecline = false;
   pattern.pre0Index = -1;
   pattern.pre0Time = 0;
   pattern.pre0Price = 0.0;
   pattern.pre0Drop = 0.0;
   pattern.pre0MinRequiredDrop = 0.0;
   pattern.pre0BarsBetweenP0 = -1;
  }

bool GetP3P4SegmentHighStats(const string symbol,
                             const datetime p3Time,
                             const double p3Price,
                             const datetime p4BarTime,
                             double &segmentHigh,
                             bool &hasAdditionalTieHigh)
  {
   const int p3Shift = iBarShift(symbol, InpTF, p3Time, false);
   const int p4Shift = iBarShift(symbol, InpTF, p4BarTime, false);
   if(p3Shift < 0 || p4Shift < 0 || p3Shift < p4Shift)
      return(false);

   const double normalizedP3Price = NormalizePrice(symbol, p3Price);
   segmentHigh = normalizedP3Price;
   hasAdditionalTieHigh = false;
   for(int shift = p4Shift; shift <= p3Shift; ++shift)
     {
      const double barHigh = NormalizePrice(symbol, iHigh(symbol, InpTF, shift));
      if(barHigh > segmentHigh)
         segmentHigh = barHigh;
      if(shift != p3Shift && barHigh == normalizedP3Price)
         hasAdditionalTieHigh = true;
     }

   return(true);
  }

void ResetHistoryCache(SymbolRuntimeState &state)
  {
   state.historyCacheReady = false;
   state.historyCandidateCount = 0;
   if(state.historyCandidateCapacity > 0)
     {
      for(int i = 0; i < state.historyCandidateCapacity; ++i)
         ResetPattern(state.historyCandidates[i]);
     }
  }

bool EnsureHistoryCandidateCapacity(SymbolRuntimeState &state, const int requiredCapacity)
  {
   if(requiredCapacity <= state.historyCandidateCapacity)
      return(true);

   int nextCapacity = state.historyCandidateCapacity;
   while(nextCapacity < requiredCapacity)
      nextCapacity += HISTORY_CANDIDATE_GROWTH_STEP;

   if(ArrayResize(state.historyCandidates, nextCapacity) < nextCapacity)
      return(false);

   for(int i = state.historyCandidateCapacity; i < nextCapacity; ++i)
      ResetPattern(state.historyCandidates[i]);

   state.historyCandidateCapacity = nextCapacity;
   return(true);
  }

void ResetSymbolState(SymbolRuntimeState &state, const string symbol)
  {
   state.symbol = symbol;
   state.lastClosedBarTime = 0;
   state.lastProcessedTickTimeMsc = 0;
   state.lastProcessedTickBid = 0.0;
   state.lastProcessedTickAsk = 0.0;
   state.historyCandidateCapacity = 0;
   state.lastEvaluatedP4Time = 0;
   state.lastEvaluatedP4Price = 0.0;
   state.lastSuccessfulEntryBarTime = 0;
   state.lastProfitTargetExitBarTime = 0;
   state.lastStopExitBarTime = 0;
   ResetBackboneSuccesses(state);
   ResetHistoryCache(state);
  }

datetime GetLatestClosedBarTime(const string symbol)
  {
   return(iTime(symbol, InpTF, 1));
  }

bool LoadClosedRates(const string symbol, MqlRates &rates[])
  {
   ArrayResize(rates, 0);
   const int copied = CopyRates(symbol, InpTF, 1, InpLookbackBars, rates);
   if(copied <= 0)
      return(false);

   ArrayResize(rates, copied);
   ArraySetAsSeries(rates, false);
   return(copied >= ((InpAdjustPointMaxSpanKNumber + 1) * 4));
  }

bool HasNewProcessableTick(SymbolRuntimeState &state, const MqlTick &tick)
  {
   if(state.lastProcessedTickTimeMsc == tick.time_msc &&
      state.lastProcessedTickBid == tick.bid &&
      state.lastProcessedTickAsk == tick.ask)
      return(false);

   state.lastProcessedTickTimeMsc = tick.time_msc;
   state.lastProcessedTickBid = tick.bid;
   state.lastProcessedTickAsk = tick.ask;
   return(true);
  }

void CollectCandidateIndexes(const int startIndex,
                             const int endIndex,
                             int &indexes[])
  {
   ArrayResize(indexes, 0);
   if(endIndex < startIndex || endIndex < 0)
      return;

   const int start = MathMax(0, startIndex);
   if(endIndex < start)
      return;

   const int count = endIndex - start + 1;
   ArrayResize(indexes, count);
   int cursor = 0;
   for(int i = endIndex; i >= start; --i)
      indexes[cursor++] = i;
  }

bool EvaluatePriorDeclinePrecondition(MqlRates &rates[], PatternSnapshot &pattern)
  {
   const int p0Index = pattern.pointIndexes[0];
   if(p0Index <= 0)
      return(false);

   const int endIndex = p0Index - 1;
   const int startIndex = MathMax(0, p0Index - InpPreCondPriorDeclineLookbackBars);
   if(endIndex < startIndex)
      return(false);

   const double structureValue = pattern.a + pattern.b1;
   const double minRequiredDrop = NormalizePrice(pattern.symbol,
                                                 InpPreCondPriorDeclineMinDropRatioOfStructure * structureValue);
   int bestIndex = -1;
   double bestPrice = 0.0;
   double bestDrop = 0.0;
   int bestBarsBetween = -1;

   ResetPriorDeclineState(pattern);
   pattern.pre0MinRequiredDrop = minRequiredDrop;

   for(int i = startIndex; i <= endIndex; ++i)
     {
      const int barsBetween = p0Index - i - 1;
      if(barsBetween < InpPreCondPriorDeclineMinBarsBetweenPre0AndP0)
         continue;

      const double pre0Price = NormalizePrice(pattern.symbol, GetRoleHigh(rates[i]));
      const double drop = NormalizePrice(pattern.symbol, pre0Price - pattern.pointPrices[0]);
      if(drop <= minRequiredDrop)
         continue;

      if(!SegmentHasDescendingEndpointExtrema(pattern.symbol, rates, i, p0Index))
         continue;

      if(bestIndex < 0 || pre0Price > bestPrice || (pre0Price == bestPrice && i > bestIndex))
        {
         bestIndex = i;
         bestPrice = pre0Price;
         bestDrop = drop;
         bestBarsBetween = barsBetween;
        }
     }

   if(bestIndex < 0)
      return(false);

   pattern.preCondPriorDecline = true;
   pattern.pre0Index = bestIndex;
   pattern.pre0Time = rates[bestIndex].time;
   pattern.pre0Price = bestPrice;
   pattern.pre0Drop = bestDrop;
   pattern.pre0BarsBetweenP0 = bestBarsBetween;
   return(true);
  }

// Keep precondition evaluation isolated so future rules can be added without
// growing the historical backbone filter into a single monolithic condition.
bool EvaluatePatternPreconditions(MqlRates &rates[], PatternSnapshot &pattern)
  {
   if(!InpPreCondEnable)
     {
      ResetPriorDeclineState(pattern);
      return(true);
     }

   return(EvaluatePriorDeclinePrecondition(rates, pattern));
  }

bool BuildHistoricalBackbone(const string symbol,
                             MqlRates &rates[],
                             const int i0,
                             const int i1,
                             const int i2,
                             const int i3,
                             const int latestClosedIndex,
                             PatternSnapshot &pattern)
  {
   const double p0 = GetRoleLow(rates[i0]);
   const double p1 = GetRoleHigh(rates[i1]);
   const double p2 = GetRoleLow(rates[i2]);
   const double p3 = GetRoleHigh(rates[i3]);

   const double b1 = p2 - p0;
   const double a = p1 - p2;
   const double b2 = p3 - p1;

   if(!(p1 > p0 && p2 > p0 && p2 < p1 && p3 > p1))
      return(false);

   if(b1 <= 0.0 || a <= 0.0 || b2 <= 0.0)
      return(false);

   if(!SegmentHasAscendingEndpointExtrema(symbol, rates, i0, i1) ||
      !SegmentHasDescendingEndpointExtrema(symbol, rates, i1, i2) ||
      !SegmentHasAscendingEndpointExtrema(symbol, rates, i2, i3))
      return(false);

   ResetPattern(pattern);
   pattern.valid = true;
   pattern.symbol = symbol;

   pattern.pointIndexes[0] = i0;
   pattern.pointIndexes[1] = i1;
   pattern.pointIndexes[2] = i2;
   pattern.pointIndexes[3] = i3;
   pattern.pointIndexes[4] = latestClosedIndex + 1;

   pattern.pointTimes[0] = rates[i0].time;
   pattern.pointTimes[1] = rates[i1].time;
   pattern.pointTimes[2] = rates[i2].time;
   pattern.pointTimes[3] = rates[i3].time;
   pattern.pointTimesMsc[0] = ((long)rates[i0].time) * 1000;
   pattern.pointTimesMsc[1] = ((long)rates[i1].time) * 1000;
   pattern.pointTimesMsc[2] = ((long)rates[i2].time) * 1000;
   pattern.pointTimesMsc[3] = ((long)rates[i3].time) * 1000;

   pattern.pointPrices[0] = NormalizePrice(symbol, p0);
   pattern.pointPrices[1] = NormalizePrice(symbol, p1);
   pattern.pointPrices[2] = NormalizePrice(symbol, p2);
   pattern.pointPrices[3] = NormalizePrice(symbol, p3);

   pattern.pointSpans[0] = MiddleBarCountBetweenIndexes(i0, i1);
   pattern.pointSpans[1] = MiddleBarCountBetweenIndexes(i1, i2);
   pattern.pointSpans[2] = MiddleBarCountBetweenIndexes(i2, i3);
   pattern.pointSpans[3] = MiddleBarCountBetweenIndexes(i3, latestClosedIndex + 1);

   pattern.a = NormalizePrice(symbol, a);
   pattern.b1 = NormalizePrice(symbol, b1);
   pattern.b2 = NormalizePrice(symbol, b2);
   pattern.r2 = (a + b1 > 0.0) ? a / (a + b1) : 0.0;
   pattern.spanValues[0] = pattern.b1;
   pattern.spanValues[1] = pattern.a;
   pattern.spanValues[2] = pattern.b2;
   pattern.spanValues[3] = pattern.a + pattern.b2;
   pattern.sspanmin = MinPositiveSpan(pattern);

   pattern.t[0] = MinutesBetween(pattern.pointTimes[0], pattern.pointTimes[1]);
   pattern.t[1] = MinutesBetween(pattern.pointTimes[1], pattern.pointTimes[2]);
   pattern.t[2] = MinutesBetween(pattern.pointTimes[2], pattern.pointTimes[3]);
   pattern.triggerPatternTotalTimeMinute = pattern.t[0] + pattern.t[1] + pattern.t[2];

   const int p1p2BarCount = SpanToInclusiveBarCount(pattern.pointSpans[1]);
   const double bSumValue = pattern.b1 + pattern.b2;
   const double bSumMinValue = InpBSumValueMinRatioOfAValue * pattern.a;
   const double bSumMaxValue = InpBSumValueMaxRatioOfAValue * pattern.a;
   pattern.condA = InRange(pattern.b1 / pattern.b2, InpCondAXMin, InpCondAXMax);
   pattern.condF = MaxSpanWithinLimit(pattern);
   const bool preconditionsPassed = EvaluatePatternPreconditions(rates, pattern);
   if(!(pattern.condA &&
        pattern.condF &&
        pattern.a >= InpP1P2AValueSpaceMinPriceLimit &&
        p1p2BarCount >= InpP1P2AValueTimeMinKNumberLimit &&
        preconditionsPassed))
      return(false);

   if(bSumValue < bSumMinValue)
      return(false);

   if(bSumValue > bSumMaxValue)
      return(false);

   return(true);
  }

bool AppendHistoricalCandidate(SymbolRuntimeState &state, const PatternSnapshot &pattern)
  {
   if(!EnsureHistoryCandidateCapacity(state, state.historyCandidateCount + 1))
      return(false);

   state.historyCandidates[state.historyCandidateCount] = pattern;
   state.historyCandidateCount++;
   return(true);
  }

void BuildHistoricalCandidateCache(SymbolRuntimeState &state, MqlRates &rates[])
  {
   ResetHistoryCache(state);

   const int latest = ArraySize(rates) - 1;
   if(latest < 3)
      return;

   const int maxIndexDistance = MaxPointIndexDistance();
   int p0Candidates[];
   int p1Candidates[];
   int p2Candidates[];
   int p3Candidates[];

   CollectCandidateIndexes(latest - (maxIndexDistance * 4) + 1, latest - 3, p0Candidates);
   CollectCandidateIndexes(latest - (maxIndexDistance * 3) + 1, latest - 2, p1Candidates);
   CollectCandidateIndexes(latest - (maxIndexDistance * 2) + 1, latest - 1, p2Candidates);
   CollectCandidateIndexes(latest - maxIndexDistance + 1, latest, p3Candidates);

   for(int p3Cursor = 0; p3Cursor < ArraySize(p3Candidates); ++p3Cursor)
     {
      const int i3 = p3Candidates[p3Cursor];
      const double p3 = GetRoleHigh(rates[i3]);

      for(int p2Cursor = 0; p2Cursor < ArraySize(p2Candidates); ++p2Cursor)
        {
         const int i2 = p2Candidates[p2Cursor];
         if(!IsPointSpanWithinConfiguredRange(i2, i3))
            continue;

         const double p2 = GetRoleLow(rates[i2]);
         if(p2 >= p3)
            continue;

         for(int p1Cursor = 0; p1Cursor < ArraySize(p1Candidates); ++p1Cursor)
           {
            const int i1 = p1Candidates[p1Cursor];
            if(!IsPointSpanWithinConfiguredRange(i1, i2))
               continue;

            const double p1 = GetRoleHigh(rates[i1]);
            if(p1 <= p2 || p3 <= p1)
               continue;

            const double b2 = p3 - p1;
            if(b2 <= 0.0)
               continue;

            const double p0MinAllowed = p2 - (InpCondAXMax * b2);
            const double p0MaxAllowed = p2 - (InpCondAXMin * b2);

            for(int p0Cursor = 0; p0Cursor < ArraySize(p0Candidates); ++p0Cursor)
              {
               const int i0 = p0Candidates[p0Cursor];
               if(!IsPointSpanWithinConfiguredRange(i0, i1))
                  continue;

               const double p0 = GetRoleLow(rates[i0]);
               if(p1 <= p0 || p2 <= p0)
                  continue;

               if(p0 < p0MinAllowed || p0 > p0MaxAllowed)
                  continue;

               PatternSnapshot candidate;
               if(!BuildHistoricalBackbone(state.symbol, rates, i0, i1, i2, i3, latest, candidate))
                  continue;

               if(!AppendHistoricalCandidate(state, candidate))
                 {
                  ResetHistoryCache(state);
                  return;
                 }
              }
           }
        }
     }

   state.historyCacheReady = true;
  }

bool RefreshHistoricalCache(SymbolRuntimeState &state)
  {
   const datetime latestClosedBarTime = GetLatestClosedBarTime(state.symbol);
   if(latestClosedBarTime <= 0)
      return(false);

   if(state.historyCacheReady && state.lastClosedBarTime == latestClosedBarTime)
      return(state.historyCandidateCount > 0);

   MqlRates rates[];
   if(!LoadClosedRates(state.symbol, rates))
     {
      state.lastClosedBarTime = latestClosedBarTime;
      ResetHistoryCache(state);
      return(false);
     }

   PruneBackboneSuccesses(state, rates[0].time);
   state.lastClosedBarTime = latestClosedBarTime;
   BuildHistoricalCandidateCache(state, rates);
   return(state.historyCandidateCount > 0);
  }

bool EvaluateRealtimePatternFromBackbone(const PatternSnapshot &backbone,
                                         const MqlTick &tick,
                                         const datetime currentBarTime,
                                         PatternSnapshot &pattern)
  {
   pattern = backbone;
   const double p4 = tick.ask;
   const double c = pattern.pointPrices[3] - p4;

   if(!(p4 < pattern.pointPrices[3]))
      return(false);

   if(c <= 0.0)
      return(false);

   pattern.pointTimes[4] = tick.time;
   pattern.pointTimesMsc[4] = tick.time_msc;
   pattern.p4BarTime = currentBarTime;
   pattern.pointPrices[4] = NormalizePrice(pattern.symbol, p4);
   pattern.c = NormalizePrice(pattern.symbol, c);
   pattern.r1 = (pattern.a + pattern.b1 + pattern.b2 > 0.0) ? pattern.c / (pattern.a + pattern.b1 + pattern.b2) : 0.0;
   pattern.spanValues[4] = pattern.c;
   pattern.sspanmin = MinPositiveSpan(pattern);
   pattern.t[3] = MinutesBetween(pattern.pointTimes[3], pattern.pointTimes[4]);
   pattern.triggerPatternTotalTimeMinute = pattern.t[0] + pattern.t[1] + pattern.t[2] + pattern.t[3];

   pattern.condB = pattern.r1 >= InpP3P4DropMinRatioOfStructure;
   pattern.condC = pattern.t[3] < (InpCondCZ * (pattern.t[0] + pattern.t[1] + pattern.t[2]));
   pattern.condD = true;

   double p34SegmentHigh = 0.0;
   bool p34HasAdditionalTieHigh = false;
   if(!GetP3P4SegmentHighStats(pattern.symbol, pattern.pointTimes[3], pattern.pointPrices[3], currentBarTime,
                               p34SegmentHigh, p34HasAdditionalTieHigh))
     {
      ResetPattern(pattern);
      return(false);
     }

   if(p34SegmentHigh > pattern.pointPrices[3])
     {
      if(InpEnableExactSearchCompare)
         PrintFormat("P34_EXTREMA_REJECT symbol=%s p3=(%s,%.5f) p4_bar=%s segment_high=%.5f",
                     pattern.symbol,
                     FormatTime(pattern.pointTimes[3]),
                     pattern.pointPrices[3],
                     FormatTime(currentBarTime),
                     p34SegmentHigh);
      ResetPattern(pattern);
      return(false);
     }

   if(InpEnableExactSearchCompare && p34HasAdditionalTieHigh)
      PrintFormat("P34_EXTREMA_TIE symbol=%s p3=(%s,%.5f) p4_bar=%s segment_high=%.5f",
                  pattern.symbol,
                  FormatTime(pattern.pointTimes[3]),
                  pattern.pointPrices[3],
                  FormatTime(currentBarTime),
                  p34SegmentHigh);

   if(!(pattern.condA && pattern.condB && pattern.condC && pattern.condF))
     {
      ResetPattern(pattern);
      return(false);
     }

   pattern.referenceEntryPrice = pattern.pointPrices[4];
   pattern.hardLossPrice = pattern.pointPrices[0];
   pattern.softLossPrice = 0.0;
   pattern.profitTargetActive = false;
   pattern.profitPrice = 0.0;
   return(true);
  }

bool IsPreferredMatch(const PatternSnapshot &candidate, const PatternSnapshot &best)
  {
   if(!best.valid)
      return(true);

   if(candidate.pointTimes[3] > best.pointTimes[3])
      return(true);

   if(candidate.pointTimes[3] == best.pointTimes[3] &&
      candidate.pointPrices[4] < best.pointPrices[4])
      return(true);

   return(false);
  }

bool EvaluateCachedRealtimePattern(SymbolRuntimeState &state,
                                   const MqlTick &tick,
                                   const datetime currentBarTime,
                                   PatternSnapshot &match)
  {
   if(!state.historyCacheReady || state.historyCandidateCount <= 0)
      return(false);

   PatternSnapshot best;
   ResetPattern(best);
   for(int i = 0; i < state.historyCandidateCount; ++i)
     {
      PatternSnapshot candidate;
      if(EvaluateRealtimePatternFromBackbone(state.historyCandidates[i], tick, currentBarTime, candidate))
         if(IsPreferredMatch(candidate, best))
            best = candidate;
     }

   if(!best.valid)
      return(false);

   match = best;
   return(true);
  }

bool FindLatestPatternLegacyExact(const string symbol,
                                  const MqlTick &tick,
                                  const datetime currentBarTime,
                                  PatternSnapshot &match)
  {
   MqlRates rates[];
   if(!LoadClosedRates(symbol, rates))
      return(false);

   const int latest = ArraySize(rates) - 1;
   if(latest < 3)
      return(false);

   PatternSnapshot best;
   ResetPattern(best);

   const int maxIndexDistance = MaxPointIndexDistance();
   for(int i3 = latest; i3 >= MathMax(0, latest - maxIndexDistance + 1); --i3)
     {
      for(int i2 = i3 - 1; i2 >= MathMax(0, i3 - maxIndexDistance); --i2)
        {
         if(!IsPointSpanWithinConfiguredRange(i2, i3))
            continue;

         for(int i1 = i2 - 1; i1 >= MathMax(0, i2 - maxIndexDistance); --i1)
           {
            if(!IsPointSpanWithinConfiguredRange(i1, i2))
               continue;

            for(int i0 = i1 - 1; i0 >= MathMax(0, i1 - maxIndexDistance); --i0)
              {
               if(!IsPointSpanWithinConfiguredRange(i0, i1))
                  continue;

               PatternSnapshot backbone;
               if(!BuildHistoricalBackbone(symbol, rates, i0, i1, i2, i3, latest, backbone))
                  continue;

               PatternSnapshot candidate;
               if(!EvaluateRealtimePatternFromBackbone(backbone, tick, currentBarTime, candidate))
                  continue;

               if(IsPreferredMatch(candidate, best))
                  best = candidate;
              }
           }
        }
     }

   if(!best.valid)
      return(false);

   match = best;
   return(true);
  }

bool ArePatternsEquivalent(const bool lhsValid,
                           const PatternSnapshot &lhs,
                           const bool rhsValid,
                           const PatternSnapshot &rhs)
  {
   if(lhsValid != rhsValid)
      return(false);

   if(!lhsValid)
      return(true);

   return(lhs.pointTimes[0] == rhs.pointTimes[0] &&
          lhs.pointTimes[1] == rhs.pointTimes[1] &&
          lhs.pointTimes[2] == rhs.pointTimes[2] &&
          lhs.pointTimes[3] == rhs.pointTimes[3] &&
          lhs.pointTimes[4] == rhs.pointTimes[4] &&
          lhs.pointPrices[0] == rhs.pointPrices[0] &&
          lhs.pointPrices[1] == rhs.pointPrices[1] &&
          lhs.pointPrices[2] == rhs.pointPrices[2] &&
          lhs.pointPrices[3] == rhs.pointPrices[3] &&
          lhs.pointPrices[4] == rhs.pointPrices[4] &&
          lhs.a == rhs.a &&
          lhs.b1 == rhs.b1 &&
          lhs.b2 == rhs.b2 &&
          lhs.c == rhs.c &&
          lhs.condA == rhs.condA &&
          lhs.condB == rhs.condB &&
          lhs.condC == rhs.condC &&
          lhs.condD == rhs.condD &&
          lhs.condF == rhs.condF);
  }

void CompareCachedAndLegacySearch(SymbolRuntimeState &state,
                                  const MqlTick &tick,
                                  const datetime currentBarTime,
                                  const bool cachedValid,
                                  const PatternSnapshot &cachedMatch)
  {
   PatternSnapshot legacyMatch;
   const bool legacyValid = FindLatestPatternLegacyExact(state.symbol, tick, currentBarTime, legacyMatch);
   if(ArePatternsEquivalent(cachedValid, cachedMatch, legacyValid, legacyMatch))
      return;

   PrintFormat("EXACT_COMPARE_MISMATCH symbol=%s cached_valid=%s legacy_valid=%s "
               "cached_p3=%s cached_p4=%s cached_a=%.5f cached_b1=%.5f cached_b2=%.5f cached_c=%.5f "
               "cached_p1p2_bars=%d cached_bsum_ratio_of_a=%.5f "
               "cached_precond=%s cached_pre0=%s cached_pre0_price=%.5f cached_pre0_drop=%.5f cached_pre0_min_drop=%.5f cached_pre0_bars_between=%d "
               "cached_spans=%d,%d,%d,%d "
               "legacy_p3=%s legacy_p4=%s legacy_a=%.5f legacy_b1=%.5f legacy_b2=%.5f legacy_c=%.5f "
               "legacy_p1p2_bars=%d legacy_bsum_ratio_of_a=%.5f "
               "legacy_precond=%s legacy_pre0=%s legacy_pre0_price=%.5f legacy_pre0_drop=%.5f legacy_pre0_min_drop=%.5f legacy_pre0_bars_between=%d "
               "legacy_spans=%d,%d,%d,%d",
               state.symbol,
               cachedValid ? "true" : "false",
               legacyValid ? "true" : "false",
               cachedValid ? FormatTime(cachedMatch.pointTimes[3]) : "n/a",
               cachedValid ? FormatTime(cachedMatch.pointTimes[4]) : "n/a",
               cachedValid ? cachedMatch.a : 0.0,
               cachedValid ? cachedMatch.b1 : 0.0,
               cachedValid ? cachedMatch.b2 : 0.0,
               cachedValid ? cachedMatch.c : 0.0,
               cachedValid ? SpanToInclusiveBarCount(cachedMatch.pointSpans[1]) : -1,
               (cachedValid && cachedMatch.a > 0.0) ? ((cachedMatch.b1 + cachedMatch.b2) / cachedMatch.a) : 0.0,
               cachedValid && cachedMatch.preCondPriorDecline ? "true" : "false",
               cachedValid ? FormatTime(cachedMatch.pre0Time) : "n/a",
               cachedValid ? cachedMatch.pre0Price : 0.0,
               cachedValid ? cachedMatch.pre0Drop : 0.0,
               cachedValid ? cachedMatch.pre0MinRequiredDrop : 0.0,
               cachedValid ? cachedMatch.pre0BarsBetweenP0 : -1,
               cachedValid ? cachedMatch.pointSpans[0] : -1,
               cachedValid ? cachedMatch.pointSpans[1] : -1,
               cachedValid ? cachedMatch.pointSpans[2] : -1,
               cachedValid ? cachedMatch.pointSpans[3] : -1,
               legacyValid ? FormatTime(legacyMatch.pointTimes[3]) : "n/a",
               legacyValid ? FormatTime(legacyMatch.pointTimes[4]) : "n/a",
               legacyValid ? legacyMatch.a : 0.0,
               legacyValid ? legacyMatch.b1 : 0.0,
               legacyValid ? legacyMatch.b2 : 0.0,
               legacyValid ? legacyMatch.c : 0.0,
               legacyValid ? SpanToInclusiveBarCount(legacyMatch.pointSpans[1]) : -1,
               (legacyValid && legacyMatch.a > 0.0) ? ((legacyMatch.b1 + legacyMatch.b2) / legacyMatch.a) : 0.0,
               legacyValid && legacyMatch.preCondPriorDecline ? "true" : "false",
               legacyValid ? FormatTime(legacyMatch.pre0Time) : "n/a",
               legacyValid ? legacyMatch.pre0Price : 0.0,
               legacyValid ? legacyMatch.pre0Drop : 0.0,
               legacyValid ? legacyMatch.pre0MinRequiredDrop : 0.0,
               legacyValid ? legacyMatch.pre0BarsBetweenP0 : -1,
               legacyValid ? legacyMatch.pointSpans[0] : -1,
               legacyValid ? legacyMatch.pointSpans[1] : -1,
               legacyValid ? legacyMatch.pointSpans[2] : -1,
               legacyValid ? legacyMatch.pointSpans[3] : -1);
  }

void ResetPattern(PatternSnapshot &pattern)
  {
   pattern.valid = false;
   pattern.symbol = "";
   pattern.p4BarTime = 0;
   for(int i = 0; i < PATTERN_POINT_COUNT; ++i)
     {
      pattern.pointIndexes[i] = -1;
      pattern.pointTimes[i] = 0;
      pattern.pointTimesMsc[i] = 0;
      pattern.pointPrices[i] = 0.0;
     }
   for(int i = 0; i < PATTERN_SEGMENT_COUNT; ++i)
     {
      pattern.pointSpans[i] = 0;
      pattern.spanValues[i] = 0.0;
      pattern.t[i] = 0.0;
     }
   pattern.a = 0.0;
   pattern.b1 = 0.0;
   pattern.b2 = 0.0;
   pattern.c = 0.0;
   pattern.d = 0.0;
   pattern.e = 0.0;
   pattern.r1 = 0.0;
   pattern.r2 = 0.0;
   pattern.sspanmin = 0.0;
   pattern.triggerPatternTotalTimeMinute = 0.0;
   ResetPriorDeclineState(pattern);
   pattern.condA = false;
   pattern.condB = false;
   pattern.condC = false;
   pattern.condD = false;
   pattern.condF = false;
   pattern.profitTargetActive = false;
   pattern.referenceEntryPrice = 0.0;
   pattern.hardLossPrice = 0.0;
   pattern.softLossPrice = 0.0;
   pattern.profitPrice = 0.0;
  }

double MinutesBetween(const datetime fromTime, const datetime toTime)
  {
   if(toTime <= fromTime)
      return(0.0);
   return((double)(toTime - fromTime) / 60.0);
  }

double MinutesBetweenMsc(const long fromTimeMsc, const long toTimeMsc)
  {
   if(toTimeMsc <= fromTimeMsc)
      return(0.0);
   return((double)(toTimeMsc - fromTimeMsc) / 60000.0);
  }

bool InRange(const double value, const double minValue, const double maxValue)
  {
   return(value >= minValue && value <= maxValue);
  }

int MiddleBarCountBetweenIndexes(const int startIndex, const int endIndex)
  {
   if(endIndex <= startIndex)
      return(-1);
   return(endIndex - startIndex - 1);
  }

int MaxPointIndexDistance()
  {
   return(InpAdjustPointMaxSpanKNumber + 1);
  }

int SpanToInclusiveBarCount(const int middleBarCount)
  {
   if(middleBarCount < 0)
      return(0);
   return(middleBarCount + 2);
  }

bool IsPointSpanWithinConfiguredRange(const int startIndex, const int endIndex)
  {
   const int span = MiddleBarCountBetweenIndexes(startIndex, endIndex);
   if(span < 0)
      return(false);
   return(span >= InpAdjustPointMinSpanKNumber && span <= InpAdjustPointMaxSpanKNumber);
  }

bool IsProfitTargetActive(const PatternSnapshot &pattern)
  {
   return(pattern.profitTargetActive);
  }

bool MaxSpanWithinLimit(const PatternSnapshot &pattern)
  {
   for(int i = 0; i < 4; ++i)
     {
      if(pattern.pointSpans[i] < InpAdjustPointMinSpanKNumber || pattern.pointSpans[i] > InpAdjustPointMaxSpanKNumber)
         return(false);
     }
   return(true);
  }

double MinPositiveSpan(const PatternSnapshot &pattern)
  {
   const double values[7] =
     {
      pattern.b1,
      pattern.a,
      pattern.b2,
      pattern.a + pattern.b2,
      pattern.c,
      pattern.d,
      pattern.e
     };
   double value = DBL_MAX;
   for(int i = 0; i < 7; ++i)
     {
      if(values[i] > 0.0 && values[i] < value)
         value = values[i];
     }
   return(value == DBL_MAX ? 0.0 : value);
  }

void ResetP5ActivationCandidate(P5ActivationCandidate &candidate)
  {
   candidate.valid = false;
   candidate.p5Index = -1;
   candidate.p6Index = -1;
   candidate.p5Time = 0;
   candidate.p6Time = 0;
   candidate.p5TimeMsc = 0;
   candidate.p6TimeMsc = 0;
   candidate.p5Price = 0.0;
   candidate.p6Price = 0.0;
   candidate.p5Span = 0;
   candidate.p6Span = 0;
   candidate.d = 0.0;
   candidate.e = 0.0;
   candidate.t5 = 0.0;
   candidate.t6 = 0.0;
   candidate.barHighAtP5Confirmation = 0.0;
   candidate.softLossPrice = 0.0;
   candidate.profitPrice = 0.0;
  }

void ResetIntrabarTrackingState(ManagedPositionState &state)
  {
   state.intrabarTrackingInitialized = false;
   state.intrabarLastBid = 0.0;
   state.entryBarLowAtP4 = 0.0;
   state.intrabarCurrentLowPrice = 0.0;
   state.intrabarCurrentLowTime = 0;
   state.intrabarCurrentLowTimeMsc = 0;
   state.intrabarCurrentLowConfirmed = false;
   state.observedP5CandidateCount = 0;
   state.observedP5CandidateCapacity = 0;
   ArrayResize(state.observedP5Candidates, 0);
  }

bool EnsureObservedP5CandidateCapacity(ManagedPositionState &state, const int required)
  {
   if(required <= state.observedP5CandidateCapacity)
      return(true);

   int capacity = state.observedP5CandidateCapacity;
   if(capacity <= 0)
      capacity = 8;
   while(capacity < required)
      capacity *= 2;

   if(ArrayResize(state.observedP5Candidates, capacity) != capacity)
      return(false);

   state.observedP5CandidateCapacity = capacity;
   return(true);
  }

bool AppendObservedP5Candidate(ManagedPositionState &state,
                               const datetime p5Time,
                               const long p5TimeMsc,
                               const double p5Price)
  {
   const int nextIndex = state.observedP5CandidateCount;
   if(!EnsureObservedP5CandidateCapacity(state, nextIndex + 1))
      return(false);

   ResetP5ActivationCandidate(state.observedP5Candidates[nextIndex]);
   state.observedP5Candidates[nextIndex].valid = true;
   state.observedP5Candidates[nextIndex].p5Time = p5Time;
   state.observedP5Candidates[nextIndex].p5TimeMsc = p5TimeMsc;
   state.observedP5Candidates[nextIndex].p5Price = p5Price;
   state.observedP5Candidates[nextIndex].barHighAtP5Confirmation =
      NormalizePrice(state.symbol, iHigh(state.symbol, InpTF, 0));
   state.observedP5CandidateCount++;
   return(true);
  }

void UpdateObservedP6Candidates(ManagedPositionState &state,
                                const datetime tickTime,
                                const long tickTimeMsc,
                                const double tickPrice)
  {
   for(int i = 0; i < state.observedP5CandidateCount; ++i)
     {
      if(!state.observedP5Candidates[i].valid)
         continue;
      if(tickTimeMsc <= state.observedP5Candidates[i].p5TimeMsc)
         continue;
      if(tickPrice <= state.observedP5Candidates[i].p5Price)
         continue;
      if(state.observedP5Candidates[i].p6TimeMsc > 0 &&
         tickPrice <= state.observedP5Candidates[i].p6Price)
         continue;

      state.observedP5Candidates[i].p6Time = tickTime;
      state.observedP5Candidates[i].p6TimeMsc = tickTimeMsc;
      state.observedP5Candidates[i].p6Price = tickPrice;
     }
  }

void TrackIntrabarP5P6State(ManagedPositionState &state, const MqlTick &tick)
  {
   const long p4TimeMsc = state.snapshot.pointTimesMsc[4];
   if(tick.time_msc <= p4TimeMsc)
      return;

   const double tickBid = NormalizePrice(state.symbol, tick.bid);
   UpdateObservedP6Candidates(state, tick.time, tick.time_msc, tickBid);

   if(!state.intrabarTrackingInitialized)
     {
      state.intrabarTrackingInitialized = true;
      state.intrabarLastBid = tickBid;
      state.intrabarCurrentLowPrice = tickBid;
      state.intrabarCurrentLowTime = tick.time;
      state.intrabarCurrentLowTimeMsc = tick.time_msc;
      state.intrabarCurrentLowConfirmed = false;
      return;
     }

   if(tickBid < state.intrabarCurrentLowPrice ||
      (state.intrabarCurrentLowConfirmed && tickBid < state.intrabarLastBid))
     {
      state.intrabarCurrentLowPrice = tickBid;
      state.intrabarCurrentLowTime = tick.time;
      state.intrabarCurrentLowTimeMsc = tick.time_msc;
      state.intrabarCurrentLowConfirmed = false;
     }
   else if(tickBid > state.intrabarCurrentLowPrice &&
           !state.intrabarCurrentLowConfirmed &&
           state.intrabarCurrentLowPrice < state.snapshot.pointPrices[4] &&
           state.intrabarCurrentLowTimeMsc > p4TimeMsc)
     {
      AppendObservedP5Candidate(state,
                                state.intrabarCurrentLowTime,
                                state.intrabarCurrentLowTimeMsc,
                                state.intrabarCurrentLowPrice);
      state.intrabarCurrentLowConfirmed = true;
      UpdateObservedP6Candidates(state, tick.time, tick.time_msc, tickBid);
     }

   state.intrabarLastBid = tickBid;
  }

bool FindLowestQualifiedP5ActivationCandidate(const ManagedPositionState &state,
                                              P5ActivationCandidate &candidate)
  {
   ResetP5ActivationCandidate(candidate);

   const double structureValue = state.snapshot.a + state.snapshot.b1 + state.snapshot.b2;
   const double p4Price = state.snapshot.pointPrices[4];
   for(int i = 0; i < state.observedP5CandidateCount; ++i)
     {
      P5ActivationCandidate observed = state.observedP5Candidates[i];
      if(!observed.valid)
         continue;
      if(observed.p5TimeMsc <= state.snapshot.pointTimesMsc[4] ||
         observed.p6TimeMsc <= observed.p5TimeMsc)
         continue;

      const double d = NormalizePrice(state.symbol, p4Price - observed.p5Price);
      const double e = NormalizePrice(state.symbol, observed.p6Price - observed.p5Price);
      if(d <= 0.0 || e <= 0.0)
         continue;
      if(e < (InpP5P6ReboundMinRatioOfP3P5Drop * (state.snapshot.c + d)))
         continue;
      if(candidate.valid && observed.p5Price >= candidate.p5Price)
         continue;

      candidate.valid = true;
      candidate.p5Index = -1;
      candidate.p6Index = -1;
      candidate.p5Time = observed.p5Time;
      candidate.p6Time = observed.p6Time;
      candidate.p5TimeMsc = observed.p5TimeMsc;
      candidate.p6TimeMsc = observed.p6TimeMsc;
      candidate.p5Price = observed.p5Price;
      candidate.p6Price = observed.p6Price;
      candidate.p5Span = 0;
      candidate.p6Span = 0;
      candidate.d = d;
      candidate.e = e;
      candidate.t5 = MinutesBetweenMsc(state.snapshot.pointTimesMsc[4], candidate.p5TimeMsc);
      candidate.t6 = MinutesBetweenMsc(candidate.p5TimeMsc, candidate.p6TimeMsc);
      candidate.barHighAtP5Confirmation = observed.barHighAtP5Confirmation;
      candidate.softLossPrice = NormalizePrice(state.symbol, InpSoftLossC * observed.p5Price);
      candidate.profitPrice = NormalizePrice(state.symbol, observed.p5Price + InpP5AnchoredProfitC * structureValue);
     }

   return(candidate.valid);
  }

int CountManagedPositions(const string symbol)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(IsManagedPosition(symbol))
         ++count;
     }
   return(count);
  }

bool IsManagedPosition(const string symbolFilter)
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   if(symbolFilter != "" && symbol != symbolFilter)
      return(false);

   if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
      return(false);

   const string comment = PositionGetString(POSITION_COMMENT);
   return(StringFind(comment, CommentPrefix()) == 0);
  }

void ExecuteEntry(SymbolRuntimeState &state, PatternSnapshot &pattern)
  {
   MqlTick tick;
   if(!SymbolInfoTick(pattern.symbol, tick))
      return;

   if(tick.ask <= 0.0)
      return;

   if(tick.ask <= pattern.hardLossPrice)
      return;

   if(IsProfitTargetActive(pattern) && tick.ask >= pattern.profitPrice)
      return;

   const string orderComment = BuildOrderComment(pattern);
   const bool submitted = trade.Buy(InpFixedLots, pattern.symbol, 0.0, 0.0, 0.0, orderComment);
   if(!submitted)
     {
      PrintFormat("Buy failed. symbol=%s p4_bar=%s retcode=%d msg=%s",
                  pattern.symbol,
                  FormatTime(pattern.p4BarTime),
                  trade.ResultRetcode(),
                  trade.ResultRetcodeDescription());
      return;
     }

   const ulong ticket = FindNewestManagedPositionTicket(pattern.symbol);
   if(ticket == 0)
     {
      PrintFormat("Buy succeeded but no managed position ticket found. symbol=%s p4_bar=%s",
                  pattern.symbol,
                  FormatTime(pattern.p4BarTime));
      return;
     }

   RegisterManagedPosition(ticket, pattern.symbol, pattern);
   state.lastSuccessfulEntryBarTime = pattern.p4BarTime;
   MarkBackboneSuccess(state, pattern, pattern.p4BarTime);
   string annotationStatus = "";
   DrawEntryPatternAnnotation(pattern, ticket, annotationStatus);
   LogEntry(pattern, trade.ResultPrice(), ticket, annotationStatus);
  }

string BuildOrderComment(const PatternSnapshot &pattern)
  {
   const string suffix = StringFormat("|P4|%I64d", (long)pattern.p4BarTime);
   return(CommentPrefix(StringLen(suffix)) + suffix);
  }

string CommentPrefix(const int reservedSuffixLength = 14)
  {
   string baseComment = InpComment;
   const int maxBaseLength = 31 - reservedSuffixLength;
   if(maxBaseLength <= 0)
      return("");
   if(StringLen(baseComment) > maxBaseLength)
      baseComment = StringSubstr(baseComment, 0, maxBaseLength);
   return(baseComment);
  }

ulong FindNewestManagedPositionTicket(const string symbol)
  {
   ulong bestTicket = 0;
   long bestTimeMsc = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(!IsManagedPosition(symbol))
         continue;

      const long openedMsc = PositionGetInteger(POSITION_TIME_MSC);
      if(openedMsc >= bestTimeMsc)
        {
         bestTimeMsc = openedMsc;
         bestTicket = ticket;
        }
     }

   return(bestTicket);
  }

void RegisterManagedPosition(const ulong ticket, const string symbol, const PatternSnapshot &pattern)
  {
   const int existing = FindManagedPositionState(ticket);
   const int index = (existing >= 0) ? existing : ArraySize(g_positionStates);
   if(existing < 0)
      ArrayResize(g_positionStates, index + 1);

   g_positionStates[index].active = true;
   g_positionStates[index].ticket = ticket;
   g_positionStates[index].symbol = symbol;
   g_positionStates[index].openedAt = TimeCurrent();
   g_positionStates[index].snapshot = pattern;
   g_positionStates[index].softStopActive = false;
   g_positionStates[index].p5ActivationFrozen = false;
   ResetIntrabarTrackingState(g_positionStates[index]);
   g_positionStates[index].entryBarLowAtP4 = NormalizePrice(symbol, iLow(symbol, InpTF, 0));
  }

int FindManagedPositionState(const ulong ticket)
  {
   for(int i = 0; i < ArraySize(g_positionStates); ++i)
     {
      if(g_positionStates[i].active && g_positionStates[i].ticket == ticket)
         return(i);
     }
   return(-1);
  }

void CleanupPositionStates()
  {
   for(int i = ArraySize(g_positionStates) - 1; i >= 0; --i)
     {
      if(!g_positionStates[i].active)
        {
         RemovePositionState(i);
         continue;
        }

      if(!PositionSelectByTicket(g_positionStates[i].ticket))
         RemovePositionState(i);
     }
  }

void RemovePositionState(const int index)
  {
   const int last = ArraySize(g_positionStates) - 1;
   if(index < 0 || index > last)
      return;

   for(int i = index; i < last; ++i)
      g_positionStates[i] = g_positionStates[i + 1];

   ArrayResize(g_positionStates, last);
  }

void ManageOpenPositions(const string symbol)
  {
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return;

   for(int i = ArraySize(g_positionStates) - 1; i >= 0; --i)
     {
      if(!g_positionStates[i].active || g_positionStates[i].symbol != symbol)
         continue;

      if(!PositionSelectByTicket(g_positionStates[i].ticket))
        {
         RemovePositionState(i);
         continue;
        }

      UpdateSoftStopState(g_positionStates[i], tick);

      const double currentBid = tick.bid;
      if(currentBid <= g_positionStates[i].snapshot.hardLossPrice)
        {
         CloseManagedPosition(i, "hard_stop", currentBid);
         continue;
        }

      if(g_positionStates[i].softStopActive &&
         currentBid <= g_positionStates[i].snapshot.softLossPrice)
        {
         CloseManagedPosition(i, "soft_stop", currentBid);
         continue;
        }

      if(IsProfitTargetActive(g_positionStates[i].snapshot) &&
         currentBid >= g_positionStates[i].snapshot.profitPrice)
        {
         CloseManagedPosition(i, "profit_target", currentBid);
         continue;
        }
     }
  }

void UpdateSoftStopState(ManagedPositionState &state, const MqlTick &tick)
  {
   if(state.p5ActivationFrozen)
      return;

   TrackIntrabarP5P6State(state, tick);

   P5ActivationCandidate candidate;
   if(!FindLowestQualifiedP5ActivationCandidate(state, candidate))
      return;

   state.snapshot.pointIndexes[5] = candidate.p5Index;
   state.snapshot.pointIndexes[6] = candidate.p6Index;
   state.snapshot.pointTimes[5] = candidate.p5Time;
   state.snapshot.pointTimes[6] = candidate.p6Time;
   state.snapshot.pointTimesMsc[5] = candidate.p5TimeMsc;
   state.snapshot.pointTimesMsc[6] = candidate.p6TimeMsc;
   state.snapshot.pointPrices[5] = candidate.p5Price;
   state.snapshot.pointPrices[6] = candidate.p6Price;
   state.snapshot.pointSpans[4] = candidate.p5Span;
   state.snapshot.pointSpans[5] = candidate.p6Span;
   state.snapshot.d = candidate.d;
   state.snapshot.e = candidate.e;
   state.snapshot.spanValues[4] = state.snapshot.c;
   state.snapshot.spanValues[5] = state.snapshot.d;
   state.snapshot.sspanmin = MinPositiveSpan(state.snapshot);
   state.snapshot.t[4] = candidate.t5;
   state.snapshot.t[5] = candidate.t6;
   state.snapshot.softLossPrice = candidate.softLossPrice;
   state.snapshot.profitPrice = candidate.profitPrice;
   state.snapshot.profitTargetActive = true;
   state.softStopActive = true;
   state.p5ActivationFrozen = true;

   string annotationStatus = "";
   DrawEntryPatternAnnotation(state.snapshot, state.ticket, annotationStatus);
   LogP5Activation(state.snapshot,
                   state.ticket,
                   annotationStatus,
                   state.entryBarLowAtP4,
                   candidate.barHighAtP5Confirmation);

  }

void CloseManagedPosition(const int stateIndex, const string reason, const double triggerPrice)
  {
   if(stateIndex < 0 || stateIndex >= ArraySize(g_positionStates))
      return;

   const ulong ticket = g_positionStates[stateIndex].ticket;
   const string symbol = g_positionStates[stateIndex].symbol;
   if(!PositionSelectByTicket(ticket))
     {
      RemovePositionState(stateIndex);
      return;
     }

   if(!trade.PositionClose(ticket, InpSlippagePoints))
     {
      PrintFormat("Position close failed. symbol=%s ticket=%I64u reason=%s retcode=%d msg=%s",
                  symbol,
                  ticket,
                  reason,
                  trade.ResultRetcode(),
                  trade.ResultRetcodeDescription());
      return;
     }

   if(reason == "profit_target" || reason == "hard_stop" || reason == "soft_stop")
     {
      const int symbolStateIndex = FindSymbolState(symbol);
      if(symbolStateIndex >= 0)
        {
         const datetime currentBarTime = GetCurrentBarOpenTime(symbol);
         if(reason == "profit_target")
            g_symbolStates[symbolStateIndex].lastProfitTargetExitBarTime = currentBarTime;
         else
            g_symbolStates[symbolStateIndex].lastStopExitBarTime = currentBarTime;
        }
     }

   RemovePositionState(stateIndex);
  }

void LogEntry(const PatternSnapshot &pattern,
              const double executedPrice,
              const ulong ticket,
              const string annotationStatus)
  {
   PrintFormat("ENTRY_P4 symbol=%s ticket=%I64u p4_bar=%s executed=%.5f hard_loss=%.5f annotation=%s "
               "P0=(%s,%.5f) P1=(%s,%.5f) P2=(%s,%.5f) P3=(%s,%.5f) P4=(%s,%.5f)",
               pattern.symbol,
               ticket,
               FormatTime(pattern.p4BarTime),
               executedPrice,
               pattern.hardLossPrice,
               annotationStatus,
               FormatTime(pattern.pointTimes[0]),
               pattern.pointPrices[0],
               FormatTime(pattern.pointTimes[1]),
               pattern.pointPrices[1],
               FormatTime(pattern.pointTimes[2]),
               pattern.pointPrices[2],
               FormatTime(pattern.pointTimes[3]),
               pattern.pointPrices[3],
               FormatTimeMsc(pattern.pointTimesMsc[4]),
               pattern.pointPrices[4]);

   if(InpEnableExactSearchCompare)
      PrintFormat("ENTRY_DIAG symbol=%s ticket=%I64u precond_enabled=%s precond_matched=%s "
                  "pre0=(%s,%.5f) pre0_drop=%.5f pre0_min_drop=%.5f",
                  pattern.symbol,
                  ticket,
                  InpPreCondEnable ? "true" : "false",
                  pattern.preCondPriorDecline ? "true" : "false",
                  pattern.preCondPriorDecline ? FormatTime(pattern.pre0Time) : "n/a",
                  pattern.preCondPriorDecline ? pattern.pre0Price : 0.0,
                  pattern.pre0Drop,
                  pattern.pre0MinRequiredDrop);
  }

void LogP5Activation(const PatternSnapshot &pattern,
                     const ulong ticket,
                     const string annotationStatus,
                     const double entryBarLowAtP4,
                     const double barHighAtP5Confirmation)
  {
   PrintFormat("ACTIVATE_P56 symbol=%s ticket=%I64u annotation=%s "
               "P4=(%s,%.5f) P5=(%s,%.5f) P6=(%s,%.5f) "
               "entry_bar_low_at_p4=%.5f bar_high_at_p5=%.5f soft_loss=%.5f profit=%.5f",
               pattern.symbol,
               ticket,
               annotationStatus,
               FormatTimeMsc(pattern.pointTimesMsc[4]),
               pattern.pointPrices[4],
               FormatTimeMsc(pattern.pointTimesMsc[5]),
               pattern.pointPrices[5],
               FormatTimeMsc(pattern.pointTimesMsc[6]),
               pattern.pointPrices[6],
               entryBarLowAtP4,
               barHighAtP5Confirmation,
               pattern.softLossPrice,
               pattern.profitPrice);
  }

string FormatTime(const datetime value)
  {
   if(value == 0)
      return("n/a");
   return(TimeToString(value, TIME_DATE | TIME_MINUTES));
  }

string FormatTimeMsc(const long value)
  {
   if(value <= 0)
      return("n/a");
   const datetime secondsPart = (datetime)(value / 1000);
   const int millisPart = (int)(value % 1000);
   return(StringFormat("%s.%03d",
                       TimeToString(secondsPart, TIME_DATE | TIME_SECONDS),
                       millisPart));
  }
