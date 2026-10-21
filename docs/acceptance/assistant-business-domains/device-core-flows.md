# 模拟器核心业务和系统交互

目标设备：`emulator-5554`。只使用本轮带“演示”标记的记录。禁止卸载 App、清空数据库、读取 `shared_prefs`、读取或导出模型 Key；改动前后的业务数据用 `device-db-baseline.py` 聚合摘要核对。

## 考勤、工资和导出

1. 从演示员工进入当月考勤，打开月考勤表，选择员工所属考勤组。核对至少有出勤、请假/休息和加班记录，汇总数与表格行及右侧合计一致。
2. 进入该员工当月工资批次，确认工资来源月份一致；如有工资异常解释，打开对应工资明细与考勤依据，核对出勤快照、基本工资、补贴、扣款和实发金额。
3. 执行工资 Excel 导出，等待应用完成导出，打开 Android「文件」或 Downloads 查看 `yyyy年MM月临时工工资表.xlsx` 确实存在且可打开。工资导出沿用 `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` 默认 MIME。

## 采购、分批入库和撤销

1. 打开本轮演示采购单，完成 OA 申报字段更新并查看流程链接；从待领取页登记到货通知。
2. 分两次入库，分别输入不同数量。每次确认后核对采购单已入库数量、剩余数量及库存流水；数量与所选单位逐项匹配。
3. 撤销第二次入库，核对对应库存减少、采购单状态和剩余数恢复，已确认的第一次入库仍保留。对比撤销前后的设备库聚合摘要，确认仅演示行变更。

## 园林维修、附件和分析

1. 新建一条带演示编号的园林维修记录，输入项目、规格、计量单位、数量和单价；保存后重新打开编辑并调整单价，确认金额按现有业务规则重算。
2. 通过附件入口分别尝试文件选择、相册选择和相机拍摄。确认取消选择不丢失表单草稿；成功添加后附件可在详情查看和删除。
3. 打开园林分析，选择该记录月份，核对项目+规格+单位的单价和金额；切到上月，确保只比较对应月份的记录。

## 通知、文件选择和备份恢复

1. 新建带演示标题的提醒，启用系统通知并保存；确认提醒页显示该记录，打开 Android 通知栏检查应用通知。点击应用内测试通知后确认出现通知。
2. 在 Excel、附件或备份页面打开系统文件选择器，选择文件后返回 App；取消选择时保持原表单和数据库不变。
3. 使用本轮演示密码创建加密备份。创建后页面会把同一 `.qsbak` 加密包写入 Android Downloads，备份 MIME 为 `application/octet-stream`；确认下载目录可见后，点“选择备份并恢复”，在系统文件选择器的 Downloads 中选同一个 `.qsbak`，确认后用同一密码恢复。
4. 恢复后核对本轮演示考勤、工资、采购和园林行仍可打开，车辆及既有提醒仍存在；重新采集 `device-db-baseline.py` 摘要并与恢复前 row hash 对比。只在相同备份恢复结果满足该项时记录通过。

自动化已覆盖：工资计算器与 Excel 服务 `test/payroll/payroll_calculator_test.dart`、`test/payroll/payroll_excel_service_test.dart`；采购 OA、通知字段、入库与撤销 `test/purchase/purchase_ui_audit_test.dart`、`test/purchase/purchase_repository_test.dart`；园林金额与分析 `test/garden_tool_repairs/garden_tool_repair_pages_test.dart`、`test/garden_tool_repairs/garden_tool_repair_analysis_service_test.dart`；文件选择和备份恢复状态 `test/system_tools_reference_states_test.dart`、`test/backup/backup_service_test.dart`。这些测试不代替上面的 Android 文件选择器、相机/相册和系统通知交互。

## Android 控件辅助脚本

脚本每次只在内存读取当前 `uiautomator` 树，自动删除设备临时 XML，只报告预置控件是否可见或“Tap action sent”；不会保存或打印完整界面层级。需要人工输入的密码只在 App 对话框中输入，不传给命令行。

```powershell
$script = 'docs/acceptance/assistant-business-domains/scripts/device-ui-boundary.ps1'
powershell -ExecutionPolicy Bypass -File $script -Action inspect -Serial emulator-5554
powershell -ExecutionPolicy Bypass -File $script -Action tap -Serial emulator-5554 -Text '创建备份'
# 在密码对话框中人工输入并确认；读取提示中的本轮备份文件名。
powershell -ExecutionPolicy Bypass -File $script -Action verify-download-mime -Serial emulator-5554 -Text 'qingsongban_本轮时间戳.qsbak' -ExpectedMimeType application/octet-stream
powershell -ExecutionPolicy Bypass -File $script -Action tap -Serial emulator-5554 -Text '选择备份并恢复'
# 在系统文件选择器打开 Downloads 后，按本轮唯一备份名后缀选同一个文件。
powershell -ExecutionPolicy Bypass -File $script -Action tap-qsbak -Serial emulator-5554 -Text 'qingsongban_本轮时间戳.qsbak'
# 工资导出后可用同一元数据检查核旧Excel默认MIME，只输出布尔结论。
powershell -ExecutionPolicy Bypass -File $script -Action verify-download-mime -Serial emulator-5554 -Text '2026年10月临时工工资表.xlsx' -ExpectedMimeType application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
```

## 可运行验收命令

整组真实问答使用下面的 runner。它先查询10月工资，再用“那上个月呢”核对上下文；每个案例只提交一次，轮询阶段只看安全状态，等消息数增长且助手回到 idle 后再检查业务域、月份、事实、来源和预期金额。每条 JSONL 只保存脱敏汇总；遇到首个失败会停止并保留失败行。

```powershell
powershell -ExecutionPolicy Bypass -File docs/acceptance/assistant-business-domains/scripts/run-business-dialogues.ps1 -Serial emulator-5554 -FlutterLog docs/acceptance/assistant-business-domains/flutter-run-seed-repair.log
```

若要单独复核当前已回答的问题，可用下面两步。`Submit` 只在当前可见助手页面填入并提交中文问题；回答完成后用 `Snapshot` 检查域、月份、事实数和本地来源。Snapshot 仅输出枚举、计数和经数字 ID 脱敏的路由，不输出问题、姓名、金额、原始模型响应、Key 或数据库行。

```powershell
powershell -ExecutionPolicy Bypass -File docs/acceptance/assistant-business-domains/scripts/assistant-business-vm-eval.ps1 -Action Submit -Serial emulator-5554 -Text '查2026年9月【演示员工编号】工资异常和实发金额'
powershell -ExecutionPolicy Bypass -File docs/acceptance/assistant-business-domains/scripts/assistant-business-vm-eval.ps1 -Action Snapshot -Serial emulator-5554 -ExpectedDomain payroll -ExpectedYearMonth 2026-09 -ExpectedSourcePath '/reports/payroll/item/:id' -ExpectedFactCount 1
```

将问题中的占位项替换为本轮种子清单里明确标记的演示记录；每个业务域至少执行一个正金额/有记录问题。问题及期望月份、金额、来源路径见 `real-model-cases.md`。真实模型响应不得复制进日志或证据文件；只保留 Snapshot 聚合结果和人工核对结论。设备库读前、种子后和幂等复启可使用 `device-db-baseline.py` 的内存快照模式核对旧行 hash、外键和演示行数。
