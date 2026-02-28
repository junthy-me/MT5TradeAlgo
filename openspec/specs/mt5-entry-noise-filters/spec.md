# mt5-entry-noise-filters Specification

## Purpose
TBD - created by archiving change add-mt5-entry-noise-filters. Update Purpose after archive.
## Requirements
### Requirement: 入场前必须通过 a 值相对买价的噪声过滤
策略 SHALL 在准备提交买单时计算 `a / buy_price * 100`，其中 `buy_price` SHALL 为当前实际准备提交订单所依据的买入价格。仅当 `a / buy_price * 100 >= NoiseFilter_aValueCompBuyPricePercent` 时，该条件才视为通过。`NoiseFilter_aValueCompBuyPricePercent` SHALL 作为百分比参数暴露，默认值 SHALL 为 `1`，表示 `1%`。

#### Scenario: a 值相对买价达到阈值时通过过滤
- **WHEN** 某个候选入场信号已经满足原有 CondA 到 CondF，且 `a / buy_price * 100` 大于或等于 `NoiseFilter_aValueCompBuyPricePercent`
- **THEN** 策略将该噪声过滤条件判定为通过，并允许继续执行后续入场前校验

#### Scenario: a 值相对买价不足时阻止发单
- **WHEN** 某个候选入场信号已经满足原有 CondA 到 CondF，但 `a / buy_price * 100` 小于 `NoiseFilter_aValueCompBuyPricePercent`
- **THEN** 策略不得提交买单，并记录该条件失败的计算值与阈值

### Requirement: 入场前必须通过 b 值相对 a 值强度的噪声过滤
策略 SHALL 在准备提交买单时计算 `max(b1, b2)`，并仅当 `max(b1, b2) >= NoiseFilter_maxBValueCompAValueProd * a` 时才允许该条件通过。`NoiseFilter_maxBValueCompAValueProd` SHALL 作为参数暴露，默认值 SHALL 为 `1.5`。

#### Scenario: 最大 b 值达到 a 值乘积阈值时通过过滤
- **WHEN** 某个候选入场信号已经满足原有 CondA 到 CondF，且 `max(b1, b2)` 大于或等于 `NoiseFilter_maxBValueCompAValueProd * a`
- **THEN** 策略将该噪声过滤条件判定为通过，并允许继续执行后续入场前校验

#### Scenario: 最大 b 值不足时阻止发单
- **WHEN** 某个候选入场信号已经满足原有 CondA 到 CondF，但 `max(b1, b2)` 小于 `NoiseFilter_maxBValueCompAValueProd * a`
- **THEN** 策略不得提交买单，并记录该条件失败的计算值与阈值

### Requirement: 仅在 CondA 到 CondF 与新增噪声条件全部通过时允许买入
策略 SHALL 仅在原有 CondA 到 CondF 全部通过且新增两条噪声过滤条件也全部通过时，才允许提交买单。任意新增噪声过滤条件失败都 SHALL 阻止下单，但不 SHALL 否定原有模式匹配结果。

#### Scenario: 原有模式匹配成功但噪声过滤失败时不发单
- **WHEN** 某个形态已经被识别为满足原有 CondA 到 CondF，但 CondG 或 CondH 任意一项失败
- **THEN** 策略保留该模式已匹配的事实，但不会提交买单

#### Scenario: 全部条件通过时允许提交买单
- **WHEN** 某个形态满足原有 CondA 到 CondF，且两条新增噪声过滤条件也全部通过
- **THEN** 策略允许继续执行买单提交流程

### Requirement: 日志必须区分模式匹配成功与入场噪声过滤失败
策略 SHALL 在日志中输出新增噪声过滤条件的原始值、阈值和通过状态，以便区分“模式未匹配”和“模式已匹配但被噪声过滤阻止入场”两类情况。

#### Scenario: 噪声过滤失败时输出过滤原因
- **WHEN** 某个候选入场信号因新增噪声过滤条件失败而被阻止发单
- **THEN** 日志输出包含 `buy_price`、`a / buy_price * 100`、`max(b1, b2)`、对应阈值以及失败条件名称

