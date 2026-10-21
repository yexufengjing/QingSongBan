# 中文真实模型验收问题

每轮按顺序提交问题；先等待页面回答，再运行 Snapshot。Snapshot 只返回域、月份、数量、来源和“预期事实是否命中”的布尔结果。只使用种子生成的演示数据。每条金额/数量检查传 `-ExpectedFactContains`，原文不会写入结果。

| 域 | 中文问题 | Snapshot 预期 |
|---|---|---|
| 人员档案 | 演示员工林晓禾的人员档案和入职信息 | `personnel`；来源 `/personnel/:id`；事实包含演示员工姓名 |
| 工资 | 查2026年10月演示员工林晓禾工资异常和实发金额 | `payroll`、`2026-10`；工资明细 `/reports/payroll/item/:id`；事实包含 `4500.00` |
| 库存 | 演示绿篱刀片现在有多少片，低于下限多少 | `inventory`；物资来源 `/inventory/materials/:id`；事实包含 `现存 6 片` 和 `下限 8` |
| 采购 | DEMO-ASSISTANT-PUR-001 采购了多少片、已入库多少片 | `purchase`；来源 `/purchase/detail/:id`；事实包含 `4/10` |
| 福利 | 查2026年10月演示员工林晓禾福利领取情况，哪些已领、哪些未领 | `distribution`、`2026-10`；福利来源 `/items?year=2026&month=10`；事实同时包含已领取与未领取 |
| 车辆维修 | 北区巡检车刹车异响维修到哪一步，实际花了多少钱 | `vehicleMaintenance`；来源 `/vehicles/repairs/:id`；事实包含 `125.00` |
| 车辆提醒 | 北区巡检车有哪些未处理提醒 | `vehicleReminders`；车辆页 `/vehicles/:id?tab=reminder`，提醒事实 `/settings/reminders/:id/edit`；事实包含“保养提醒” |
| 园林月费用 | 查2026年10月演示北区绿篱养护登记金额合计 | `gardenRepair`、`2026-10`；来源 `/garden-tool-repairs/analysis?year=2026&month=10`；事实同时包含 `24.00` 和 `1 条`，摘要包含 `24.00` |
| 园林跨月价格 | 对比2026年10月和9月演示北区绿篱养护40厘米按片的维修单价 | `gardenRepair`、`2026-10`；事实包含 `10.00` 和 `12.00`；过滤其他规格和单位 |
| 车辆费用旧能力 | 查北区巡检车2026年10月费用，按维修类别分析 | 旧车辆费用 Agent 的既有 Snapshot；要求金额为正、费用类别为维修；不以普通助手回答替代 |

工资、福利、维修、园林月份随种子适配设备当月/上月；若验收日期变化，只更新问题年份月份和 Snapshot 预期，不改写种子。工资样本实发 `4500.00` 元。库存样本采购入库后为6片、下限8片。涉及其他记录的回答只保留脚本生成的脱敏 Snapshot，不复制原始回答。

## 核对命令

单实体金额示例：

```powershell
powershell -ExecutionPolicy Bypass -File docs/acceptance/assistant-business-domains/scripts/assistant-business-vm-eval.ps1 -Action Submit -Serial emulator-5554 -FlutterLog docs/acceptance/assistant-business-domains/flutter-run-live.log -Text '查2026年10月演示员工林晓禾工资异常和实发金额'
powershell -ExecutionPolicy Bypass -File docs/acceptance/assistant-business-domains/scripts/assistant-business-vm-eval.ps1 -Action Snapshot -Serial emulator-5554 -FlutterLog docs/acceptance/assistant-business-domains/flutter-run-live.log -ExpectedDomain payroll -ExpectedYearMonth 2026-10 -ExpectedSourcePath '/reports/payroll/item/:id' -ExpectedFactContains '4500.00'
```

园林月费用要求摘要与两条本地事实都命中，避免把“记录数为零”的答复当作有效金额。演示数量为2片、单价12元，金额应为24元：

```powershell
powershell -ExecutionPolicy Bypass -File docs/acceptance/assistant-business-domains/scripts/assistant-business-vm-eval.ps1 -Action Snapshot -Serial emulator-5554 -ExpectedDomain gardenRepair -ExpectedYearMonth 2026-10 -ExpectedSourcePath '/garden-tool-repairs/analysis?year=2026&month=10' -ExpectedFactContains '24.00','1 条' -ExpectedSummaryContains '24.00'
```

车辆提醒需分别核对父级导航和提醒对象入口：第一次 Snapshot 用 `-ExpectedSourcePath '/vehicles/:id?tab=reminder'`；同一 Snapshot 再运行一次 `-ExpectedSourcePath '/settings/reminders/:id/edit'`。

上下文回归场景先提交 `查演示员工林晓禾2025年9月工资`，再提交 `那位员工呢` 与 `那上个月呢`；预期第二问仍为 `2025-09`，第三问为 `2025-08`，对象保持一致。该场景由 controller 集成测试固定验证；真机只检查助手显示的月份和对象，不需输出姓名或回答文本证据。
