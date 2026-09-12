# 轻松办当前数据库结构

当前 `schemaVersion` 为 **7**。本阶段继续复用现有 Drift 表结构，未新增迁移。

## 业务表

- `employees`：人员档案、在岗/离职状态及默认考勤组。
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
- `reminders`：本地提醒、来源业务及完成状态。

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

数据库备份使用 `.qsbak` 压缩包，包含 `database.sqlite`、`config.json` 和
`manifest.json`。当前应用未建立独立附件表，因此没有附件数据需要随库备份。
