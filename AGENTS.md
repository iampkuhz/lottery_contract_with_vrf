# Agent Instructions

## Product decisions
- 抽奖不使用 drawTime，管理员随时可发起 `requestDraw()`。
- 一旦发起 VRF 请求，候选人列表视为封存，禁止再修改（若需变更，先结束本轮）。
- 事件与接口按分组组织，分组之间用空行分隔，分组开头使用 ASCII 多行注释框。
- 参与者录入时拒绝合约地址，仅允许 EOA（`code.length == 0`）。

## Code style
- 合约与接口注释全部为中文。
- 每个事件、函数接口必须提供单行注释。

## Docs and tests
- 任何测试流程变更，需要同步更新 `README.md` 的“测试流程说明”章节。
- 任何 `.env` 配置变更，需要同步更新 `.env.example`。
