#property strict
#property version   "1.00"
#property description "MT5 P4 pattern strategy"

#include <Trade/Trade.mqh>

#define PATTERN_POINT_COUNT 7
#define PATTERN_SEGMENT_COUNT 6
#define HISTORY_CANDIDATE_GROWTH_STEP 512

enum PointValueTypeEnum
  {
   KMax = 0,
   KMin = 1,
   KAvg = 2
  };

input string InpSymbols = "AAPL;MSFT;NVDA";
input ENUM_TIMEFRAMES InpTF = PERIOD_M5;
input int InpTimerMillSec = 100;
input long InpMagic = 9527001;
input string InpComment = "P4PatternStrategy";

input double InpFixedLots = 0.05;
input int InpMaxPositionsPerSymbol = 10;
input int InpSlippagePoints = 20;

input int InpLookbackBars = 120;
input int InpAdjustPointMaxSpanKNumber = 5;
input PointValueTypeEnum InpPointValueType = KMax;

input double InpCondAXMin = 0.75;
input double InpCondAXMax = 1.25;
input double InpRatioC = 0.4;
input double InpCondCZ = 1.0;
input int InpTSpanMinConf = 5;

input double InpSoftLossN = 0.5;
input double InpSoftLossC = 1.0;
input double InpProfitC = 1.8;
input double NoiseFilter_bSumValueCompBuyPricePercent = 0.5;
input bool InpEnableExactSearchCompare = false;

struct PatternSnapshot
  {
   bool              valid;
   string            symbol;
   int               pointIndexes[PATTERN_POINT_COUNT];
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
   double            tspanmin;
   bool              condA;
   bool              condB;
   bool              condC;
   bool              condD;
   bool              condE;
   bool              condF;
   bool              condG;
   bool              condH;
   double            referenceEntryPrice;
   double            hardLossPrice;
   double            softLossPrice;
   double            profitPrice;
   double            noiseFilterBuyPrice;
   double            noiseFilterBSumPercent;
   double            noiseFilterBSumValue;
  };

struct SymbolRuntimeState
  {
   string            symbol;
   datetime          lastClosedBarTime;
   bool              historyCacheReady;
   int               historyCandidateCount;
   int               historyCandidateCapacity;
   PatternSnapshot   historyCandidates[];
   datetime          lastEvaluatedP4Time;
   double            lastEvaluatedP4Price;
  };

struct ManagedPositionState
  {
   bool              active;
   ulong             ticket;
   string            symbol;
   datetime          openedAt;
   PatternSnapshot   snapshot;
   bool              softStopActive;
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

   if(InpCondAXMin <= 0.0 || InpCondAXMax <= 0.0 || InpCondAXMin > InpCondAXMax)
     {
      Print("Invalid CondA range.");
      return(false);
     }

   if(InpRatioC < 0.0)
     {
      Print("Invalid CondB ratio threshold.");
      return(false);
     }

   if(NoiseFilter_bSumValueCompBuyPricePercent < 0.0)
     {
      Print("Invalid noise filter threshold.");
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

   CleanupPositionStates();
   ManageOpenPositions(symbol);

   PatternSnapshot match;
   if(!RefreshHistoricalCache(g_symbolStates[stateIndex]))
      return;

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick) || tick.ask <= 0.0)
      return;

   const bool hasCachedMatch = EvaluateCachedRealtimePattern(g_symbolStates[stateIndex], tick, match);
   if(InpEnableExactSearchCompare)
      CompareCachedAndLegacySearch(g_symbolStates[stateIndex], tick, hasCachedMatch, match);

   if(!hasCachedMatch)
      return;

   if(match.pointTimes[4] <= g_symbolStates[stateIndex].lastEvaluatedP4Time &&
      match.pointPrices[4] == g_symbolStates[stateIndex].lastEvaluatedP4Price)
      return;

   g_symbolStates[stateIndex].lastEvaluatedP4Time = match.pointTimes[4];
   g_symbolStates[stateIndex].lastEvaluatedP4Price = match.pointPrices[4];

   if(CountManagedPositions(symbol) >= InpMaxPositionsPerSymbol)
     {
      PrintFormat("Entry blocked by position limit. symbol=%s limit=%d", symbol, InpMaxPositionsPerSymbol);
      return;
     }

   ExecuteEntry(match);
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
   state.historyCandidateCapacity = 0;
   state.lastEvaluatedP4Time = 0;
   state.lastEvaluatedP4Price = 0.0;
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
   pattern.tspanmin = MinPositiveTime(pattern);

   pattern.condA = InRange(pattern.b1 / pattern.b2, InpCondAXMin, InpCondAXMax);
   pattern.condE = pattern.tspanmin >= (double)InpTSpanMinConf;
   pattern.condF = MaxSpanWithinLimit(pattern);
   return(pattern.condA && pattern.condE && pattern.condF);
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

   pattern.condB = pattern.r1 >= InpRatioC;
   pattern.condC = pattern.t[3] < (InpCondCZ * (pattern.t[0] + pattern.t[1] + pattern.t[2]));
   pattern.condD = true;

   if(!(pattern.condA && pattern.condB && pattern.condC && pattern.condE && pattern.condF))
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
          lhs.condE == rhs.condE &&
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
               "legacy_p3=%s legacy_p4=%s legacy_a=%.5f legacy_b1=%.5f legacy_b2=%.5f legacy_c=%.5f",
               state.symbol,
               cachedValid ? "true" : "false",
               legacyValid ? "true" : "false",
               cachedValid ? FormatTime(cachedMatch.pointTimes[3]) : "n/a",
               cachedValid ? FormatTime(cachedMatch.pointTimes[4]) : "n/a",
               cachedValid ? cachedMatch.a : 0.0,
               cachedValid ? cachedMatch.b1 : 0.0,
               cachedValid ? cachedMatch.b2 : 0.0,
               cachedValid ? cachedMatch.c : 0.0,
               legacyValid ? FormatTime(legacyMatch.pointTimes[3]) : "n/a",
               legacyValid ? FormatTime(legacyMatch.pointTimes[4]) : "n/a",
               legacyValid ? legacyMatch.a : 0.0,
               legacyValid ? legacyMatch.b1 : 0.0,
               legacyValid ? legacyMatch.b2 : 0.0,
               legacyValid ? legacyMatch.c : 0.0);
  }

void ResetPattern(PatternSnapshot &pattern)
  {
   pattern.valid = false;
   pattern.symbol = "";
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
   pattern.tspanmin = 0.0;
   pattern.condA = false;
   pattern.condB = false;
   pattern.condC = false;
   pattern.condD = false;
   pattern.condE = false;
   pattern.condF = false;
   pattern.condG = false;
   pattern.condH = false;
   pattern.referenceEntryPrice = 0.0;
   pattern.hardLossPrice = 0.0;
   pattern.softLossPrice = 0.0;
   pattern.profitPrice = 0.0;
   pattern.noiseFilterBuyPrice = 0.0;
   pattern.noiseFilterBSumPercent = 0.0;
   pattern.noiseFilterBSumValue = 0.0;
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

double MinPositiveTime(const PatternSnapshot &pattern)
  {
   double value = DBL_MAX;
   for(int i = 0; i < 3; ++i)
     {
      if(pattern.t[i] > 0.0 && pattern.t[i] < value)
         value = pattern.t[i];
     }
   return(value == DBL_MAX ? 0.0 : value);
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

void ExecuteEntry(PatternSnapshot &pattern)
  {
   MqlTick tick;
   if(!SymbolInfoTick(pattern.symbol, tick))
      return;

   if(tick.ask <= 0.0)
      return;

   if(!EvaluateNoiseFilters(pattern, tick.ask))
     {
      LogNoiseFilterBlocked(pattern);
      return;
     }

   if(tick.ask <= pattern.hardLossPrice)
     {
      PrintFormat("Skipping pattern because current ask is already below hard loss. symbol=%s ask=%.5f hard_loss=%.5f",
                  pattern.symbol,
                  tick.ask,
                  pattern.hardLossPrice);
      return;
     }

   if(tick.ask >= pattern.profitPrice)
     {
      PrintFormat("Skipping stale pattern because current ask is already beyond target. symbol=%s ask=%.5f target=%.5f",
                  pattern.symbol,
                  tick.ask,
                  pattern.profitPrice);
      return;
     }

   const string orderComment = BuildOrderComment(pattern);
   const bool submitted = trade.Buy(InpFixedLots, pattern.symbol, 0.0, 0.0, 0.0, orderComment);
   if(!submitted)
     {
      PrintFormat("Buy failed. symbol=%s retcode=%d msg=%s",
                  pattern.symbol,
                  trade.ResultRetcode(),
                  trade.ResultRetcodeDescription());
      return;
     }

   const ulong ticket = FindNewestManagedPositionTicket(pattern.symbol);
   if(ticket == 0)
     {
      PrintFormat("Buy succeeded but no managed position ticket found. symbol=%s", pattern.symbol);
      return;
     }

   RegisterManagedPosition(ticket, pattern.symbol, pattern);
   LogEntry(pattern, trade.ResultPrice(), orderComment, ticket);
  }

bool EvaluateNoiseFilters(PatternSnapshot &pattern, const double buyPrice)
  {
   pattern.noiseFilterBuyPrice = NormalizePrice(pattern.symbol, buyPrice);
   pattern.noiseFilterBSumValue = pattern.b1 + pattern.b2;
   pattern.noiseFilterBSumPercent = (buyPrice > 0.0) ? (pattern.noiseFilterBSumValue / buyPrice) * 100.0 : 0.0;
   pattern.condG = true;
   pattern.condH = pattern.noiseFilterBSumPercent >= NoiseFilter_bSumValueCompBuyPricePercent;
   return(pattern.condH);
  }

void LogNoiseFilterBlocked(const PatternSnapshot &pattern)
  {
   string failedConditions = "";
   if(!pattern.condH)
      failedConditions = "CondH";

   PrintFormat("ENTRY_FILTER_BLOCKED symbol=%s failed=%s source=P0:Low,P1:High,P2:Low,P3:High,P4:Realtime "
               "buy_price=%.5f a=%.5f b_sum=%.5f b_sum_pct=%.5f threshold_pct=%.5f b1=%.5f b2=%.5f",
               pattern.symbol,
               failedConditions,
               pattern.noiseFilterBuyPrice,
               pattern.a,
               pattern.noiseFilterBSumValue,
               pattern.noiseFilterBSumPercent,
               NoiseFilter_bSumValueCompBuyPricePercent,
               pattern.b1,
               pattern.b2);
  }

string BuildOrderComment(const PatternSnapshot &pattern)
  {
   const string suffix = StringFormat("|P4|%I64d", (long)pattern.pointTimes[4]);
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
   if(state.softStopActive)
      return;

   MqlRates rates[];
   if(!LoadClosedRates(state.symbol, rates))
      return;

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
      return;

   int p5Index = -1;
   double p5Price = DBL_MAX;
   for(int i = searchStartIndex; i < total; ++i)
     {
      const double value = GetRoleLow(rates[i]);
      if(value < p5Price)
        {
         p5Price = value;
         p5Index = i;
        }
     }

   if(p5Index < 0 || p5Price >= state.snapshot.pointPrices[4])
      return;

   int p6Index = -1;
   double p6Price = -DBL_MAX;
   for(int i = p5Index + 1; i < total; ++i)
     {
      const double value = GetRoleHigh(rates[i]);
      if(value > p6Price)
        {
         p6Price = value;
         p6Index = i;
        }
     }

   if(p6Index < 0 || p6Price <= p5Price)
      return;

   state.snapshot.pointIndexes[5] = p5Index;
   state.snapshot.pointIndexes[6] = p6Index;
   state.snapshot.pointTimes[5] = rates[p5Index].time;
   state.snapshot.pointTimes[6] = rates[p6Index].time;
   state.snapshot.pointPrices[5] = NormalizePrice(state.symbol, p5Price);
   state.snapshot.pointPrices[6] = NormalizePrice(state.symbol, p6Price);
   state.snapshot.pointSpans[4] = p5Index - searchStartIndex + 1;
   state.snapshot.pointSpans[5] = p6Index - p5Index;

   state.snapshot.d = NormalizePrice(state.symbol, state.snapshot.pointPrices[4] - state.snapshot.pointPrices[5]);
   state.snapshot.e = NormalizePrice(state.symbol, state.snapshot.pointPrices[6] - state.snapshot.pointPrices[5]);
   state.snapshot.spanValues[4] = state.snapshot.c;
   state.snapshot.spanValues[5] = state.snapshot.d;
   state.snapshot.sspanmin = MinPositiveSpan(state.snapshot);
   state.snapshot.t[4] = MinutesBetween(state.snapshot.pointTimes[4], state.snapshot.pointTimes[5]);
   state.snapshot.t[5] = MinutesBetween(state.snapshot.pointTimes[5], state.snapshot.pointTimes[6]);

   if(state.snapshot.d <= 0.0 || state.snapshot.e <= 0.0)
      return;

   if((state.snapshot.e - state.snapshot.d) >= (InpSoftLossN * state.snapshot.c))
     {
      state.snapshot.softLossPrice = NormalizePrice(state.symbol, InpSoftLossC * state.snapshot.pointPrices[5]);
      state.softStopActive = true;
      PrintFormat("Soft stop activated. symbol=%s ticket=%I64u soft_loss=%.5f p5=%.5f p6=%.5f d=%.5f e=%.5f c=%.5f",
                  state.symbol,
                  state.ticket,
                  state.snapshot.softLossPrice,
                  state.snapshot.pointPrices[5],
                  state.snapshot.pointPrices[6],
                  state.snapshot.d,
                  state.snapshot.e,
                  state.snapshot.c);
     }
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

   LogExit(g_positionStates[stateIndex], reason, triggerPrice);
   RemovePositionState(stateIndex);
  }

void LogEntry(const PatternSnapshot &pattern, const double executedPrice, const string orderComment, const ulong ticket)
  {
   PrintFormat("ENTRY symbol=%s ticket=%I64u comment=%s executed=%.5f ref_p4=%.5f hard_loss=%.5f profit=%.5f "
               "noise_buy=%.5f condB=%s r1=%.5f threshold_r1=%.5f condH=%s b_sum=%.5f b_sum_pct=%.5f threshold_pct=%.5f "
               "source=P0:Low,P1:High,P2:Low,P3:High,P4:Realtime,P5:Low,P6:High "
               "P0=(%s,%.5f) P1=(%s,%.5f) P2=(%s,%.5f) P3=(%s,%.5f) P4=(%s,%.5f) "
               "a=%.5f b1=%.5f b2=%.5f c=%.5f r1=%.5f r2=%.5f t1=%.2f t2=%.2f t3=%.2f t4=%.2f total=%.2f",
               pattern.symbol,
               ticket,
               orderComment,
               executedPrice,
               pattern.referenceEntryPrice,
               pattern.hardLossPrice,
               pattern.profitPrice,
               pattern.noiseFilterBuyPrice,
               pattern.condB ? "true" : "false",
               pattern.r1,
               InpRatioC,
               pattern.condH ? "true" : "false",
               pattern.noiseFilterBSumValue,
               pattern.noiseFilterBSumPercent,
               NoiseFilter_bSumValueCompBuyPricePercent,
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
   PrintFormat("EXIT symbol=%s ticket=%I64u reason=%s executed=%.5f hard_loss=%.5f soft_loss=%.5f profit=%.5f "
               "source=P4:Realtime,P5:Low,P6:High "
               "P4=(%s,%.5f) P5=(%s,%.5f) P6=(%s,%.5f) d=%.5f e=%.5f t5=%.2f t6=%.2f",
               state.symbol,
               state.ticket,
               reason,
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
