#property strict
#property version   "1.00"
#property description "MT5 P4 pattern strategy"

#include <Trade/Trade.mqh>

#define PATTERN_POINT_COUNT 7
#define PATTERN_SEGMENT_COUNT 6
#define HISTORY_CANDIDATE_GROWTH_STEP 512

input string InpSymbols = "AAPL;MSFT;NVDA";
input ENUM_TIMEFRAMES InpTF = PERIOD_M5;
input int InpTimerMillSec = 100;
input long InpMagic = 9527001;
input string InpComment = "P4PatternStrategy";

input double InpFixedLots = 0.05;
input int InpMaxPositionsPerSymbol = 1;
input int InpSlippagePoints = 20;
input int InpProfitObservationBars = 30;
input int InpStopObservationBars = 30;
input int InpLookbackBars = 300;
input int InpAdjustPointMaxSpanKNumber = 10;

input double InpCondAXMin = 0.75;
input double InpCondAXMax = 1.25;
input double InpP3P4DropMinRatioOfStructure = 0.4;
input double InpCondCZ = 1.0;
input double InpP1P2AValueSpaceMinPriceLimit = 5.0;
input int InpP1P2AValueTimeMinKNumberLimit = 3;
input double InpBSumValueMinRatioOfAValue = 2.0;
input double InpBSumValueMaxRatioOfAValue = 5.0;
input int InpPreCondPriorDeclineLookbackBars = 20;
input double InpPreCondPriorDeclineMinDropRatioOfStructure = 0.7;
input int InpPreCondPriorDeclineMinBarsBetweenPre0AndP0 = 0;

input double InpP5P6ReboundMinRatioOfP3P5Drop = 0.65;
input double InpSoftLossC = 1.0;
input double InpProfitC = 0.6;
input double InpP5AnchoredProfitC = 0.7;
input bool InpEnableExactSearchCompare = false;

struct PatternSnapshot
  {
   bool              valid;
   string            symbol;
   int               pointIndexes[PATTERN_POINT_COUNT];
   datetime          p4BarTime;
   datetime          pointTimes[PATTERN_POINT_COUNT];
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

struct ManagedPositionState
  {
   bool              active;
   ulong             ticket;
   string            symbol;
   datetime          openedAt;
   PatternSnapshot   snapshot;
   bool              softStopActive;
   bool              p5ActivationFrozen;
  };

struct P5ActivationCandidate
  {
   bool              valid;
   int               p5Index;
   int               p6Index;
   datetime          p5Time;
   datetime          p6Time;
   double            p5Price;
   double            p6Price;
   int               p5Span;
   int               p6Span;
   double            d;
   double            e;
   double            t5;
   double            t6;
   double            softLossPrice;
   double            profitPrice;
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

   if(InpAdjustPointMaxSpanKNumber < 1 || InpLookbackBars < 16)
     {
      Print("Lookback or point span settings are too small.");
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

   const bool hasCachedMatch = EvaluateCachedRealtimePattern(g_symbolStates[stateIndex], tick, match);
   if(InpEnableExactSearchCompare)
      CompareCachedAndLegacySearch(g_symbolStates[stateIndex], tick, hasCachedMatch, match);

   if(!hasCachedMatch)
      return;

   match.p4BarTime = currentBarTime;

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
     {
      LogEntryBlockedByObservationWindows(symbol,
                                          currentBarTime,
                                          lastProfitTargetExitBarTime,
                                          profitBlockedBarsRemaining,
                                          lastStopExitBarTime,
                                          stopBlockedBarsRemaining);
      return;
     }

   if(profitObservationLocked)
     {
      LogEntryBlockedByProfitObservation(symbol,
                                         currentBarTime,
                                         lastProfitTargetExitBarTime,
                                         profitBlockedBarsRemaining);
      return;
     }

   if(stopObservationLocked)
     {
      LogEntryBlockedByStopObservation(symbol,
                                       currentBarTime,
                                       lastStopExitBarTime,
                                       stopBlockedBarsRemaining);
      return;
     }

   if(IsP4BarLocked(g_symbolStates[stateIndex], currentBarTime))
     {
      LogEntryBlockedByP4Bar(symbol, currentBarTime);
      return;
     }

   datetime successfulBackboneP4BarTime = 0;
   string matchedBackbonePoint = "";
   if(IsBackboneSuccessLocked(g_symbolStates[stateIndex], match, successfulBackboneP4BarTime, matchedBackbonePoint))
     {
      LogEntryBlockedByBackboneSuccess(match, successfulBackboneP4BarTime, matchedBackbonePoint);
      return;
     }

   if(CountManagedPositions(symbol) >= InpMaxPositionsPerSymbol)
     {
      PrintFormat("Entry blocked by position limit. symbol=%s timeframe=%s p4_bar=%s limit=%d",
                  symbol,
                  EnumToString(InpTF),
                  FormatTime(currentBarTime),
                  InpMaxPositionsPerSymbol);
      return;
     }

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

double GetRoleLow(const MqlRates &rate)
  {
   return(rate.low);
  }

double GetRoleHigh(const MqlRates &rate)
  {
   return(rate.high);
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
  return(copied >= (InpAdjustPointMaxSpanKNumber * 4 + 1));
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

   const double structureValue = pattern.a + pattern.b1 + pattern.b2;
   const double minRequiredDrop = NormalizePrice(pattern.symbol,
                                                 InpPreCondPriorDeclineMinDropRatioOfStructure * structureValue);
   int bestIndex = -1;
   double bestPrice = 0.0;
   double bestDrop = 0.0;
   int bestBarsBetween = -1;

   pattern.preCondPriorDecline = false;
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

   pattern.pointPrices[0] = NormalizePrice(symbol, p0);
   pattern.pointPrices[1] = NormalizePrice(symbol, p1);
   pattern.pointPrices[2] = NormalizePrice(symbol, p2);
   pattern.pointPrices[3] = NormalizePrice(symbol, p3);

   pattern.pointSpans[0] = i1 - i0;
   pattern.pointSpans[1] = i2 - i1;
   pattern.pointSpans[2] = i3 - i2;
   pattern.pointSpans[3] = (latestClosedIndex - i3) + 1;

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

   const int p1p2BarCount = pattern.pointSpans[1] + 1;
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

   const int span = InpAdjustPointMaxSpanKNumber;
   int p0Candidates[];
   int p1Candidates[];
   int p2Candidates[];
   int p3Candidates[];

   CollectCandidateIndexes(latest - (span * 4) + 1, latest - 3, p0Candidates);
   CollectCandidateIndexes(latest - (span * 3) + 1, latest - 2, p1Candidates);
   CollectCandidateIndexes(latest - (span * 2) + 1, latest - 1, p2Candidates);
   CollectCandidateIndexes(latest - span + 1, latest, p3Candidates);

   for(int p3Cursor = 0; p3Cursor < ArraySize(p3Candidates); ++p3Cursor)
     {
      const int i3 = p3Candidates[p3Cursor];
      const double p3 = GetRoleHigh(rates[i3]);

      for(int p2Cursor = 0; p2Cursor < ArraySize(p2Candidates); ++p2Cursor)
        {
         const int i2 = p2Candidates[p2Cursor];
         if(i2 >= i3 || (i3 - i2) > span)
            continue;

         const double p2 = GetRoleLow(rates[i2]);
         if(p2 >= p3)
            continue;

         for(int p1Cursor = 0; p1Cursor < ArraySize(p1Candidates); ++p1Cursor)
           {
            const int i1 = p1Candidates[p1Cursor];
            if(i1 >= i2 || (i2 - i1) > span)
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
               if(i0 >= i1 || (i1 - i0) > span)
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

   if(!(pattern.condA && pattern.condB && pattern.condC && pattern.condF))
     {
      ResetPattern(pattern);
      return(false);
     }

   pattern.referenceEntryPrice = pattern.pointPrices[4];
   pattern.hardLossPrice = pattern.pointPrices[0];
   pattern.softLossPrice = 0.0;
   pattern.profitPrice = NormalizePrice(pattern.symbol,
                                        pattern.referenceEntryPrice + InpProfitC * (pattern.b1 + pattern.b2 + pattern.a));
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
                                   PatternSnapshot &match)
  {
   if(!state.historyCacheReady || state.historyCandidateCount <= 0)
      return(false);

   PatternSnapshot best;
   ResetPattern(best);
   for(int i = 0; i < state.historyCandidateCount; ++i)
     {
      PatternSnapshot candidate;
      if(EvaluateRealtimePatternFromBackbone(state.historyCandidates[i], tick, candidate))
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

   const int span = InpAdjustPointMaxSpanKNumber;
   for(int i3 = latest; i3 >= MathMax(0, latest - span + 1); --i3)
     {
      for(int i2 = i3 - 1; i2 >= MathMax(0, i3 - span); --i2)
        {
         for(int i1 = i2 - 1; i1 >= MathMax(0, i2 - span); --i1)
           {
            for(int i0 = i1 - 1; i0 >= MathMax(0, i1 - span); --i0)
              {
               PatternSnapshot backbone;
               if(!BuildHistoricalBackbone(symbol, rates, i0, i1, i2, i3, latest, backbone))
                  continue;

               PatternSnapshot candidate;
               if(!EvaluateRealtimePatternFromBackbone(backbone, tick, candidate))
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
                                  const bool cachedValid,
                                  const PatternSnapshot &cachedMatch)
  {
   PatternSnapshot legacyMatch;
   const bool legacyValid = FindLatestPatternLegacyExact(state.symbol, tick, legacyMatch);
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
               cachedValid ? (cachedMatch.pointSpans[1] + 1) : -1,
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
               legacyValid ? (legacyMatch.pointSpans[1] + 1) : -1,
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
   pattern.preCondPriorDecline = false;
   pattern.pre0Index = -1;
   pattern.pre0Time = 0;
   pattern.pre0Price = 0.0;
   pattern.pre0Drop = 0.0;
   pattern.pre0MinRequiredDrop = 0.0;
   pattern.pre0BarsBetweenP0 = -1;
   pattern.condA = false;
   pattern.condB = false;
   pattern.condC = false;
   pattern.condD = false;
   pattern.condF = false;
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

bool InRange(const double value, const double minValue, const double maxValue)
  {
   return(value >= minValue && value <= maxValue);
  }

bool MaxSpanWithinLimit(const PatternSnapshot &pattern)
  {
   for(int i = 0; i < 4; ++i)
     {
      if(pattern.pointSpans[i] > InpAdjustPointMaxSpanKNumber)
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
   candidate.p5Price = 0.0;
   candidate.p6Price = 0.0;
   candidate.p5Span = 0;
   candidate.p6Span = 0;
   candidate.d = 0.0;
   candidate.e = 0.0;
   candidate.t5 = 0.0;
   candidate.t6 = 0.0;
   candidate.softLossPrice = 0.0;
   candidate.profitPrice = 0.0;
  }

bool FindLowestQualifiedP5ActivationCandidate(const ManagedPositionState &state,
                                              MqlRates &rates[],
                                              P5ActivationCandidate &candidate)
  {
   ResetP5ActivationCandidate(candidate);

   const int total = ArraySize(rates);
   int searchStartIndex = -1;
   for(int i = 0; i < total; ++i)
     {
      if(rates[i].time > state.snapshot.pointTimes[4])
        {
         searchStartIndex = i;
         break;
        }
     }

   if(searchStartIndex < 0 || searchStartIndex >= total - 1)
      return(false);

   const double structureValue = state.snapshot.a + state.snapshot.b1 + state.snapshot.b2;
   const double p4Price = state.snapshot.pointPrices[4];
   for(int p5Index = searchStartIndex; p5Index < total - 1; ++p5Index)
     {
      const double p5Price = NormalizePrice(state.symbol, GetRoleLow(rates[p5Index]));
      if(p5Price >= p4Price)
         continue;

      int bestP6Index = -1;
      double bestP6Price = 0.0;
      for(int p6Index = p5Index + 1; p6Index < total; ++p6Index)
        {
         const double currentP6Price = NormalizePrice(state.symbol, GetRoleHigh(rates[p6Index]));
         if(bestP6Index < 0 || currentP6Price > bestP6Price)
           {
            bestP6Index = p6Index;
            bestP6Price = currentP6Price;
           }
        }

      if(bestP6Index < 0 || bestP6Price <= p5Price)
         continue;

      const double d = NormalizePrice(state.symbol, p4Price - p5Price);
      const double e = NormalizePrice(state.symbol, bestP6Price - p5Price);
      if(d <= 0.0 || e <= 0.0)
         continue;

      if(e < (InpP5P6ReboundMinRatioOfP3P5Drop * (state.snapshot.c + d)))
         continue;

      if(candidate.valid && p5Price >= candidate.p5Price)
         continue;

      candidate.valid = true;
      candidate.p5Index = p5Index;
      candidate.p6Index = bestP6Index;
      candidate.p5Time = rates[p5Index].time;
      candidate.p6Time = rates[bestP6Index].time;
      candidate.p5Price = p5Price;
      candidate.p6Price = bestP6Price;
      candidate.p5Span = p5Index - searchStartIndex + 1;
      candidate.p6Span = bestP6Index - p5Index;
      candidate.d = d;
      candidate.e = e;
      candidate.t5 = MinutesBetween(state.snapshot.pointTimes[4], candidate.p5Time);
      candidate.t6 = MinutesBetween(candidate.p5Time, candidate.p6Time);
      candidate.softLossPrice = NormalizePrice(state.symbol, InpSoftLossC * p5Price);
      candidate.profitPrice = NormalizePrice(state.symbol, p5Price + InpP5AnchoredProfitC * structureValue);
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
     {
      PrintFormat("Skipping pattern because current ask is already below hard loss. symbol=%s p4_bar=%s ask=%.5f hard_loss=%.5f",
                  pattern.symbol,
                  FormatTime(pattern.p4BarTime),
                  tick.ask,
                  pattern.hardLossPrice);
      return;
     }

   if(tick.ask >= pattern.profitPrice)
     {
      PrintFormat("Skipping stale pattern because current ask is already beyond target. symbol=%s p4_bar=%s ask=%.5f target=%.5f",
                  pattern.symbol,
                  FormatTime(pattern.p4BarTime),
                  tick.ask,
                  pattern.profitPrice);
      return;
     }

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
   LogEntry(pattern, trade.ResultPrice(), orderComment, ticket);
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

      UpdateSoftStopState(g_positionStates[i]);

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

      if(currentBid >= g_positionStates[i].snapshot.profitPrice)
        {
         CloseManagedPosition(i, "profit_target", currentBid);
         continue;
        }
     }
  }

void UpdateSoftStopState(ManagedPositionState &state)
  {
   if(state.p5ActivationFrozen)
      return;

   MqlRates rates[];
   if(!LoadClosedRates(state.symbol, rates))
      return;

   P5ActivationCandidate candidate;
   if(!FindLowestQualifiedP5ActivationCandidate(state, rates, candidate))
      return;

   state.snapshot.pointIndexes[5] = candidate.p5Index;
   state.snapshot.pointIndexes[6] = candidate.p6Index;
   state.snapshot.pointTimes[5] = candidate.p5Time;
   state.snapshot.pointTimes[6] = candidate.p6Time;
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
   state.softStopActive = true;
   state.p5ActivationFrozen = true;

   PrintFormat("Soft stop and P5-anchored profit activated. symbol=%s ticket=%I64u soft_loss=%.5f rewritten_profit=%.5f "
               "selected_p5=(%s,%.5f) p6=(%s,%.5f) d=%.5f e=%.5f c=%.5f structure=%.5f",
               state.symbol,
               state.ticket,
               state.snapshot.softLossPrice,
               state.snapshot.profitPrice,
               FormatTime(state.snapshot.pointTimes[5]),
               state.snapshot.pointPrices[5],
               FormatTime(state.snapshot.pointTimes[6]),
               state.snapshot.pointPrices[6],
               state.snapshot.d,
               state.snapshot.e,
               state.snapshot.c,
               state.snapshot.a + state.snapshot.b1 + state.snapshot.b2);
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

   LogExit(g_positionStates[stateIndex], reason, triggerPrice);
   RemovePositionState(stateIndex);
  }

void LogEntry(const PatternSnapshot &pattern, const double executedPrice, const string orderComment, const ulong ticket)
  {
   PrintFormat("ENTRY symbol=%s ticket=%I64u comment=%s p4_bar=%s executed=%.5f ref_p4=%.5f hard_loss=%.5f profit=%.5f "
               "condB=%s r1=%.5f p3p4_drop_min_ratio=%.5f "
               "a_min_price=%.5f p1p2_min_bars=%d bsum_min_ratio_of_a=%.5f bsum_max_ratio_of_a=%.5f "
               "prior_decline=%s pre0=(%s,%.5f) pre0_drop=%.5f pre0_min_drop=%.5f pre0_bars_between=%d "
               "spans=%d,%d,%d,%d p1p2_bars=%d bsum=%.5f bsum_min_allowed=%.5f bsum_max_allowed=%.5f bsum_ratio_of_a=%.5f "
               "source=P0:Low,P1:High,P2:Low,P3:High,P4:Realtime,P5:Low,P6:High "
               "P0=(%s,%.5f) P1=(%s,%.5f) P2=(%s,%.5f) P3=(%s,%.5f) P4=(%s,%.5f) "
               "a=%.5f b1=%.5f b2=%.5f c=%.5f r1=%.5f r2=%.5f t1=%.2f t2=%.2f t3=%.2f t4=%.2f total=%.2f",
               pattern.symbol,
               ticket,
               orderComment,
               FormatTime(pattern.p4BarTime),
               executedPrice,
               pattern.referenceEntryPrice,
               pattern.hardLossPrice,
               pattern.profitPrice,
               pattern.condB ? "true" : "false",
               pattern.r1,
               InpP3P4DropMinRatioOfStructure,
               InpP1P2AValueSpaceMinPriceLimit,
               InpP1P2AValueTimeMinKNumberLimit,
               InpBSumValueMinRatioOfAValue,
               InpBSumValueMaxRatioOfAValue,
               pattern.preCondPriorDecline ? "true" : "false",
               FormatTime(pattern.pre0Time),
               pattern.pre0Price,
               pattern.pre0Drop,
               pattern.pre0MinRequiredDrop,
               pattern.pre0BarsBetweenP0,
               pattern.pointSpans[0],
               pattern.pointSpans[1],
               pattern.pointSpans[2],
               pattern.pointSpans[3],
               pattern.pointSpans[1] + 1,
               pattern.b1 + pattern.b2,
               InpBSumValueMinRatioOfAValue * pattern.a,
               InpBSumValueMaxRatioOfAValue * pattern.a,
               (pattern.a > 0.0) ? ((pattern.b1 + pattern.b2) / pattern.a) : 0.0,
               FormatTime(pattern.pointTimes[0]),
               pattern.pointPrices[0],
               FormatTime(pattern.pointTimes[1]),
               pattern.pointPrices[1],
               FormatTime(pattern.pointTimes[2]),
               pattern.pointPrices[2],
               FormatTime(pattern.pointTimes[3]),
               pattern.pointPrices[3],
               FormatTime(pattern.pointTimes[4]),
               pattern.pointPrices[4],
               pattern.a,
               pattern.b1,
               pattern.b2,
               pattern.c,
               pattern.r1,
               pattern.r2,
               pattern.t[0],
               pattern.t[1],
               pattern.t[2],
               pattern.t[3],
               pattern.triggerPatternTotalTimeMinute);
  }

void LogExit(const ManagedPositionState &state, const string reason, const double executedPrice)
  {
   PrintFormat("EXIT symbol=%s ticket=%I64u reason=%s p4_bar=%s executed=%.5f hard_loss=%.5f soft_loss=%.5f profit=%.5f "
               "source=P4:Realtime,P5:Low,P6:High "
               "P4=(%s,%.5f) P5=(%s,%.5f) P6=(%s,%.5f) d=%.5f e=%.5f t5=%.2f t6=%.2f",
               state.symbol,
               state.ticket,
               reason,
               FormatTime(state.snapshot.p4BarTime),
               executedPrice,
               state.snapshot.hardLossPrice,
               state.snapshot.softLossPrice,
               state.snapshot.profitPrice,
               FormatTime(state.snapshot.pointTimes[4]),
               state.snapshot.pointPrices[4],
               FormatTime(state.snapshot.pointTimes[5]),
               state.snapshot.pointPrices[5],
               FormatTime(state.snapshot.pointTimes[6]),
               state.snapshot.pointPrices[6],
               state.snapshot.d,
               state.snapshot.e,
               state.snapshot.t[4],
               state.snapshot.t[5]);
  }

string FormatTime(const datetime value)
  {
   if(value == 0)
      return("n/a");
   return(TimeToString(value, TIME_DATE | TIME_MINUTES));
  }
