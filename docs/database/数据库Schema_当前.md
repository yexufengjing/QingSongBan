# 轻松办当前数据库结构

当前 `schemaVersion` 为 **12**。提醒功能在现有 Drift 数据库上增加了重复执行实例、通知规则和通用关联表，并保持本地迁移与旧提醒兼容。

## 业务表

- `employees`：人员档案、在岗/离职状态及默认考勤组。
- `employee_attachments`：人员附件元数据、业务来源、相对存储路径和软删除状态。
- `attendance_groups`：考勤组配置。
- `attendance_group_members`：考勤组成员及默认组关系。
- `monthly_attendance_rosters`：按月份保存考勤名单，移除使用 `isActive = false`。
- `attendance_records`：每日上下半天考勤记录。
- `leave_records`：请假记录。
- `overtime_records`：加班记录及分钟数。
- `termination_records`：离职记录及停保办理状态。
- `monthly_attendance_summaries`：月度考勤汇总、状态和异常数。
- `insurance_profiles`：当前保险档案。
- `insurance_change_records`：保险变更记录。
- `social_security_base_history`：社保缴费基数历史。
- `wage_job_types`：工资工种、默认日薪和启停状态。
- `wage_rate_history`：工种按生效月份保存的日薪历史。
- `employee_wage_profiles`：人员参与工资核算、工种和个人特殊日薪。
- `payroll_batches`：按月份保存的工资批次、状态、汇总和软删除标记。
- `payroll_items`：工资人员快照、半天出勤、日薪、补助、保险扣除和最终工资。
- `payroll_adjustments`：工资明细的扩展调整项。
- `reminders`：本地提醒主项、来源业务、重复规则、优先级和归档状态。
- `reminder_occurrences`：每一期提醒的执行实例、逾期/完成/跳过/稍后提醒状态及完成时间。
- `reminder_alert_rules`：当天、提前提醒和未完成催办规则；同一主项可以有多条规则。
- `reminder_links`：提醒与人员、车辆、器械、物资等对象的通用关联，当前已接通人员。

## 支撑表

- `operation_logs`：关键业务操作日志。
- `dictionary_items`：可扩展字典项。
- `app_settings`：应用配置。

## 迁移记录

- 版本 1：初始人员、考勤组、月度名单、每日考勤及支撑表。
- 版本 2：请假记录。
- 版本 3：加班记录。
- 版本 4：离职记录。
- 版本 5：月度汇总。
- 版本 6：保险档案、保险变更及基数历史。
- 版本 7：本地提醒。
- 版本 8：人员附件元数据表。
- 版本 9：工种、日薪历史、人员工资资料、工资批次、工资明细和工资调整表。
- 版本 10：物资/物品发放模块相关表。
- 版本 11：物资/物品发放模块补充字段和索引。
- 版本 12：提醒主项扩展字段、执行实例、通知规则和通用关联表；旧提醒迁移为首个执行实例及提前提醒规则。

提醒字段约定：`scheduledAt` 和提醒的 `dueDate` 保存为用户设备时区下的墙上时间，`timezoneId` 保存创建时使用的 IANA 时区标识；调度时转换为 `timezone` 的 `TZDateTime`。重复规则使用 RFC 5545 RRULE，由 `rrule` 包计算，禁止在业务层手写日期递推。

数据库备份使用 `.qsbak` 压缩包，包含 `database.sqlite`、`config.json` 和
`manifest.json`，以及 `attachments/` 下的应用内附件文件。备份格式版本 2
兼容旧格式版本 1。
