# 背景

目前依据经验已经总结出一套股票走势模式匹配，想将该模式通过策略算法的方式在 MetaTrader5 客户端上自动运行起来。

# 模式定义

## K线模式走势图：

![K线模式走势图](/Users/junthy/Library/Application Support/typora-user-images/image-20260227143906148.png)

## 模式变量定义

### 空间变量定义

- $S_{P0P2}=b1$
- $S_{P1P2}=a$
- $S_{P1P3}=b2$
- $S_{P2P3}=a+b2$
- $S_{P3P4}=c$
- $S_{P4P5}=d$
- $S_{P5P6}=e$
- $r1=c/(a+b1+b2)$
- $r2=a/(a+b1)$
- $min(S_{P0P2},S_{P1P2},S_{P1P3},S_{P2P3},S_{P3P4},S_{P4P5},S_{P5P6}) = sspanmin$

### 时间变量定义

- $T_{P0P1}=t1$
- $T_{P1P2}=t2$
- $T_{P2P3}=t3$
- $T_{P3P4}=t4$
- $T_{P4P5}=t5$
- $T_{P5P6}=t6$
- $trigger_pattern_total_time_minute = t1 + t2 + t3 + t4$ // k线走出趋势所花的时间（单位分钟）
- $min(t1, t2, t3, t4) = tspanmin$ // 趋势各个阶段中的最小时间（单位分钟）

### 模式匹配条件定义

1. 模式中的相邻点位之间可能横跨多根 k 线（比如 P0-P1 之间可能有 3 根 k 线），相邻点位之间最多包含的 k 线数由参数 **AdjustPointMaxSpanKNumber**（默认为 5）
2. 点位的值应取 k 线柱的最高点/最低点/均值点（默认为最高点），可由参数 **PointValueTypeEnum** 控制，可取枚举值为：
   1. KMax（K线柱最高价）
   2. KMin（K线柱最低价）
   3. KAvg（K线柱均价）

## 模式匹配条件定义

- **CondA** $b1=x*b2$（x为系数范围，可作为参数进行配置，默认为 [0.75, 1.25]）
- **CondB** $r1=y*r2$（y为系数范围，可作为参数进行配置，默认为 [0.75, 1.25]）
- **CondC** $t4<z*(t1+t2+t3)$（z为常量系数，可作为参数进行配置，默认为 1）
- **CondD** $c<m*a$（m为常量，可作为参数进行配置，默认为 2）
- **CondE** $tspanmin>=tspanmin_conf$（tspanmin_conf 为配置参数，默认为 5）
- **CondF** 相邻点位之间最多包含的 k 线数 <= AdjustPointMaxSpanKNumber

**当前只有满足 CondA & CondB & CondC & CondD & CondE && CondF 才认为模式完全匹配上！！！**

# 匹配后交易

匹配后下买单，买入的价位为 P4 点位，并设置相应的止损止盈位。

## 设置止损位

### 强止损位（HardLossLimit）

**当前价位下跌到止损位 `hard_loss_price` 时触发卖出，其中 `hard_loss_price` 为** $买入价位 - hardlossC * a$**。其中 hardlossC 可配置，默认为 1。**

### 弱止损位（SoftLossLimit）

只有在满足一定条件时才会设置弱止损位，当设置弱止损位后，如果触发了弱止损位或强止损位中的任意一个，都会在当前实时价位进行卖出。

**弱止损位设置条件**

1. **SetSoftLossCondA** 模式匹配后，后续走势能匹配上 $S_{P4P5}$ & $S_{P5P6}$
2. **SetSoftLossCondB** $(e-d)>=n*c$（其中 n 为常量系数，可作为参数进行配置，默认为 0.5）

当同时满足 **SetSoftLossCondA & SetSoftLossCondB 时增加弱止损位，**弱止损位设置如下：

`soft_loss_price` 为 softLossC \* Price_P5（P5点对应的价位）。其中 softLossC 为参数可动态配置，默认为 1。

## 设置止盈位

**当前价位达到止盈位 `profit_price`时触发卖出，其中 `profit_price` 为** $买入价位 + profitC * a$，其中 profitC 可配置，默认为2。

# 策略要求

## 参数设置

除了上述的模式匹配和交易信息参数设置，还应该提供如下等参数：

**交易对象与运行方式**

input string InpSymbols = "AAPL;MSFT;NVDA"；（要扫描的品种列表，用分号分隔）

input ENUM_TIMEFRAMES InpTF = PERIOD_M5;（周期识别形态范围，PERRIOD_M5 表示用 5min K线走势图）

input int InpTimerMillSec = 100;（每 100 毫秒并发轮询品种列表）

input long InpMagic = 9527001;（“魔术号”：EA 下的订单/持仓会带这个编号，用来与手动订单或其他 EA 区分）

input string InpComment = "xxx";（订单备注，用于识别）

**下单与风控（简化版）**

InpFixedLots：每次下单的固定手数（默认 0.05）

InpMaxPositionsPerSymbol：同品种最多同时 x 笔并行买单持仓（默认为 10）

InpSlippagePoints：允许滑点（点数）

## 代码要求

- 要求代码为 `.mq5` 格式，可在 metatrader5 上正确运行；
- 代码变量命名遵循规范，结构清晰，组织合理，正确且易扩展；
- 代码编写后进行仔细检查，因为涉及到真实交易，所以一定不能出现任何错误；
- 当成交时将成交时的各个点位信息（时间点、价位）、时间变量信息和空间变量信息都以日志形式打印出来；