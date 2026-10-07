# 基础与人员 UI 差异排查

日期：2026-10-01  
负责范围：基础、人员、考勤、工资、提醒、保险、附件、设置、导出、报表、备份、日志、物品领取、请假、加班、离职等 40 个页面。库存、车辆与园林器械维修由其他工作流负责。

## 视觉基准与默认处理

可读参考为 `UI设计与美术资源/01_界面设计/01` 至 `06`，依次用于首页、人员名单、人员档案、每日考勤、月考勤表、月度汇总；`02_UI规范与美术资源/01_UI设计规范展板.png` 用作字体、色彩、圆角和卡片层级基准。07–14 原始 PNG 文件均保留，但图像流无法完整解码；可恢复的顶部片段之外像素不可作设计依据。依据 01–06 及规范板推导这些页面及无专图页面，不声明像素一致，不抄参考图内样例姓名、日期或数值。

公共 theme 已与规范板的 primary、tech blue、ink、body、helper、background、lightGreen、lightBlue 及 H1/H2/H3/body/辅助/说明字号一致，保留共享主题。产品数据缺失时显示空值、加载或错误状态；不填充参考截图示例数据。照片字段不存在时使用中性头像占位。保险单位没有数据库字段，不虚构单位、不加 schema。

## 可读参考逐页差异与修改

| 页面/区域 | 修改前 | 参考预期 | 实际调整 | 状态与默认处理 |
|---|---|---|---|---|
| 首页：品牌头部 | 短渐变标题条，信息密度低 | 01 为清洁工与车辆照片横幅、产品名/人员管理/标语/离线标记 | 从原参考01的清洁工与车辆区域裁切为本地 `assets/ui/home_header.png`；用 `Image.asset` 配动态UI层和语义描述，不让位图文字成为唯一无障碍名称 | 已调整。没有独立原始横幅资产；直接复用参考裁片，不重新生成素材。离线标记由真实UI显示 |
| 首页：今日概览 | 六项合在大统计卡中，留白偏大；此前“今日已登记”把登记记录数当出勤数，“异常记录”卡数的是有异常的月汇总数 | 01 六张独立白卡：在岗、本月新增、本月离职、今日出勤、今日请假、即将到期 | 保持紧凑三列卡片；今日出勤按当天至少一个半日为 `present` 的去重人员数，今日请假按覆盖当天的未删除请假记录去重人员数，即将到期按未来30天启用且未完成提醒的 pending occurrence 去重提醒项；加载/错误状态仍由 dashboard provider 提供 | 源码已修正。当前数据模型没有合同/保险到期事实表，最后一项只称“即将到期”，不声称对应合同/保险人数 |
| 首页：快捷入口与待办 | 2列大横卡，首页首屏只露少量入口 | 01 六个核心入口为三列图标卡，另有提醒 | 改为三列六入口；其他已有入口保留在“更多功能”区；增加真实待处理提醒数入口 | 已调整。其余旧路由保持可达 |
| 人员名单：标题、筛选 | 筛选占据大表单卡，缺少搜索旁筛选入口、状态计数，已离职标签在实机窄屏被挤出 | 02 标题居中、搜索旁筛选按钮、绿色状态切换、四种状态同时可读 | 居中标题；搜索旁打开高级筛选底部面板；四个等宽紧凑状态chips，标签与真实人数分两行；保留用工类型筛选；圆形FAB内显示图标和两行“新增人员” | 已调整。计数使用全量人员真实数据 |
| 人员名单：档案卡 | 只显示编号/岗位/班组/用工类型、入职日；无工作区域与参保，卡高约115dp只显示约3.8条 | 02 姓名和性别标识、编号、岗位、班组、工作区域、是否参保，紧凑约85dp卡片 | 按参考层级重排；缩小内距/字号/头像和分隔，头像改为中性圆角矩形；性别仅明确男/女显示对应图标，未填写用中性标识；暂停状态用橙色；保险加载/失败/无档案/未参保分别显示 | 已调整。参保标签只读取保险 provider，卡片目标提升到约6条可见 |
| 人员档案：顶部身份卡 | 标题为“人员详情”，无参考结构 | 03 标题“人员档案”；白色身份卡、头像/姓名/状态/岗位/单位/工号，右侧编辑与更多 | 改为“人员档案”；加入白卡头像占位、姓名状态、岗位/考勤组/工号及编辑/更多 | 已调整。考勤组是现有组织关联；数据库无单位字段，默认不编造单位 |
| 人员档案：基本、工作、保险 | 标签和值上下堆叠使基本信息卡约285dp，首屏未露工作信息 | 03 彩色图标紧凑可折叠分组；标签和值同行、左右双列，基本卡约130dp | 各字段改为固定宽标签+可换行值同行；标签12、值14、行距6；出生/年龄压缩标签，备注/性别作为补充字段；标题左对齐；附件仍位于保险后 | 已调整。电话和证件仍按隐私规则脱敏；长地址可换行，保留全部原字段 |
| 人员档案：保险和附件 | 空值可能显示为未设置/0张 | 03 参保状态、参保时间、险种、保险单位、最近变更；附件按类别列数 | 参保状态已参保显示绿色；加入真实最近变更的生效月份/变更类型；四类附件和动态计数；加载和错误不显示成0 | 已调整。保险单位无字段，报告中注明未显示；不新增数据库字段 |
| 人员档案：操作与历史 | 现有工资、库存记录入口 | 03 有请假、加班、离职快捷操作；业务记录仍需可达 | 添加三类快捷操作，保留库存领取历史与工资入口 | 已调整。快捷登记沿用已有表单路由和真实校验 |
| 每日考勤：日期/组/入口 | 大 hero、日期卡、三统计卡、2x2 操作卡，首屏仅显示一名人员；实机日期中文格式折行 | 04 紧凑单行日期、考勤组横向 chips、1x4 彩色入口 | 已移除占高 hero/统计；日期改为单行年月日和星期，压缩日期按钮内距；班组展示实际人数；四入口横向单行；顶部状态称“自动保存”而不是无条件已保存 | 已调整。无固定参考日期；沿用本地自动保存语义 |
| 每日考勤：人员编辑 | 以大卡编辑，字段不像参考行式表 | 04 姓名/上午/下午/加班时长/备注表格行 | 改为对应列的紧凑可编辑行；加班时长由真实加班记录汇总；备注打开现有编辑控件；保留锁定日期与自动保存 | 已调整。参考底部“保存考勤”与即时自动保存语义不同，保留真实自动保存，不增加无效按钮或重复写日志 |
| 月考勤表：月份/班组/操作 | 月份、组选择分行，缺少参考导出入口；实机分段仅半宽，表格区域留下约90dp空白 | 05 月份和组并排；全宽绿色分段导航；“考勤明细”标题、绿色竖线和左右滑动提示 | 月份/班组并排，顶部导出薄荷底绿字且复用已有 Excel 路由；日登记/月表全宽分段选中态绿底白字；增加标题和横滑提示；表格高度按行数收缩并设最大滚动高度 | 已调整。只复用已有 Excel 页面，不发明导出路径 |
| 月考勤表：单元格和图例 | 单元格较大，锁定/未登记符号易与出勤符号混淆，状态色铺满整个格子 | 05 绿力/蓝半/红缺/灰休/橙停，小圆角符号徽标、薄荷色合计行、底部独立说明 | 状态色改为格内圆角符号底；合计行薄荷底；图例区补“未登记”“离职”及点击编辑说明，保留锁定逻辑 | 已调整。未登记“未”与锁定状态不冒充参考出勤符号，图例明确解释 |
| 月度汇总：首屏概览 | “汇总”大副标题、独立月份行、状态卡、chips、人员卡列表 | 06 “月度汇总”、月份/导出、3+2统计、三种汇总 tabs | 改为紧凑标题和月份选择；保留现有导出动作；五张白色统计卡按3+2排列，带彩色图标和较大数字；前三项为实际出勤/请假/缺勤人数，后两项为加班小时/数据完整率；加入考勤、人员变动、保险变更三类切换表 | 已调整。完整率基于真实 `isComplete`，无上月数据不显示环比 |
| 月度汇总：人员数据与异常 | 卡片列表不具备参考列结构 | 06 姓名、实际出勤、请假、缺勤、加班、月末状态、数据完整；异常汇总和底部导出 | 用可横向滚动数据表展示真实字段；人员变动表按真实月初/月末状态、入职/离职标记；保险表读取所选月变更记录；异常数据保留 | 已调整。空值显示未知/待补充；Excel 复用现有导出；确认/锁定操作收进展开操作区 |

## 全页面覆盖矩阵

以下 40 个文件全部纳入本轮检查。标“直对”的仅指直接参考页；其他页面依照邻近参考的卡片、输入框、状态、空/错/加载模式推导，不能视作像素对齐验收。

| 页面文件 | 页面/对应参考 | 检查结果/默认处理 |
|---|---|---|
| `lib/features/home/presentation/home_page.dart` | 首页 / 01 直对 | 品牌横幅、6张真实指标卡、6个快捷入口与待办摘要；指标口径见下方复核记录 |
| `lib/features/personnel/presentation/personnel_page.dart` | 人员入口 / 02–03 推导 | 复用人员名单与档案入口，不新增截图外业务值 |
| `lib/features/personnel/presentation/personnel_list_page.dart` | 人员名单 / 02 直对 | 搜索、状态计数、类型筛选、FAB及字段布局已调 |
| `lib/features/personnel/presentation/personnel_detail_page.dart` | 人员档案 / 03 直对 | 身份卡、折叠分组、附件、历史入口已调 |
| `lib/features/personnel/presentation/personnel_form_page.dart` | 人员新增/编辑 / 02–03 推导 | 保留真实档案字段、日期选择、必填验证及保存反馈 |
| `lib/features/attendance/presentation/attendance_page.dart` | 考勤入口 / 04–06 推导 | 保留已有日考勤/月表/月汇总入口和导航状态 |
| `lib/features/attendance/presentation/daily_attendance_page.dart` | 每日考勤 / 04 直对 | 紧凑日期、班组 chips、四入口及行式编辑；自动保存 |
| `lib/features/attendance/presentation/monthly_attendance_table_page.dart` | 月考勤表 / 05 直对 | 控件并排、表格密度、图例、导出入口已调；页面内容使用可纵向滚动列表，避免固定 Column 被表格/停用组提示/窄屏高度撑溢 |
| `lib/features/attendance/presentation/monthly_roster_page.dart` | 月度人员名单 / 05–06 推导 | 保留月份/组、加入移除名单、参与状态和确认校验 |
| `lib/features/attendance/presentation/attendance_group_list_page.dart` | 考勤组列表 / 04 推导 | 保留组状态、成员数、编辑/详情入口，真实空状态 |
| `lib/features/attendance/presentation/attendance_group_detail_page.dart` | 考勤组详情 / 04 推导 | 保留成员列表及加人/移出确认流程 |
| `lib/features/attendance/presentation/attendance_group_form_page.dart` | 考勤组表单 / 04 推导 | 分区表单和字段校验按公共表单风格处理 |
| `lib/features/payroll/presentation/payroll_home_page.dart` | 工资首页 / 无专图，规范推导 | 保留真实工资批次、筛选与历史/造资入口，不放样例数 |
| `lib/features/payroll/presentation/payroll_editor_page.dart` | 工资名单/编辑 / 无专图，规范推导 | 保留真实名单、重算/确认/锁定等操作与异常反馈 |
| `lib/features/payroll/presentation/payroll_detail_page.dart` | 工资明细 / 无专图，规范推导 | 保留实际工资明细与考勤、历史入口 |
| `lib/features/payroll/presentation/payroll_history_page.dart` | 工资历史 / 无专图，规范推导 | 保留真实历史列表与空状态 |
| `lib/features/payroll/presentation/employee_payroll_page.dart` | 人员工资料 / 无专图，规范推导 | 保留参与核算、工种日薪与历史工资 |
| `lib/features/payroll/presentation/payroll_export_page.dart` | 工资 Excel / 无专图，规范推导 | 保留预览、月份及导出结果/失败反馈 |
| `lib/features/payroll/presentation/wage_job_settings_page.dart` | 工种与日薪 / 无专图，规范推导 | 保留工种状态、日薪生效月份与历史生效规则 |
| `lib/features/reminders/presentation/reminder_page.dart` | 提醒列表 / 无完整专图，07–14损坏后按规范推导 | 保留实际提醒状态、编辑/重复规则和删除确认 |
| `lib/features/reminders/presentation/reminder_form_page.dart` | 提醒表单 / 无专图，规范推导 | 保留真实提醒内容、对象、日程及校验 |
| `lib/features/reminders/presentation/reminder_alerts_page.dart` | 提醒通知 / 无专图，规范推导 | 保留真实到期项及延后/处理入口 |
| `lib/features/reminders/presentation/reminder_repeat_page.dart` | 重复规则 / 无专图，规范推导 | 保留周期/截止规则选择和日期校验 |
| `lib/features/reminders/presentation/reminder_schedule_page.dart` | 提醒日程 / 无专图，规范推导 | 保留日期时间选择与日程回显 |
| `lib/features/insurance/presentation/insurance_page.dart` | 保险管理 / 12仅顶部可读，其他推导 | 保留真实参保档案、变更列表、筛选及状态菜单 |
| `lib/features/insurance/presentation/insurance_profile_form_page.dart` | 保险档案 / 08、12残片+规范推导 | 保留参保状态/类型/月份/基数等真实字段和表单校验 |
| `lib/features/insurance/presentation/insurance_change_form_page.dart` | 保险变更 / 12残片+规范推导 | 保留变更类型、生效月、办理状态、真实历史和保存校验 |
| `lib/features/attachments/presentation/employee_attachments_page.dart` | 附件 / 09顶部残片+规范推导 | 保留附件类型、预览/隐私揭示/删除确认及真实计数 |
| `lib/features/leave/presentation/leave_page.dart` | 请假列表 / 无专图，规范推导 | 保留真实请假时段、人员状态及编辑/撤销操作 |
| `lib/features/leave/presentation/leave_form_page.dart` | 请假表单 / 无专图，规范推导 | 保留人员、日期、类型、原因与有效区间校验 |
| `lib/features/overtime/presentation/overtime_page.dart` | 加班列表 / 无专图，规范推导 | 保留月份、时段、真实加班时长及编辑/删除确认 |
| `lib/features/overtime/presentation/overtime_form_page.dart` | 加班表单 / 无专图，规范推导 | 保留人员/时段选择、重叠验证、自动时长计算 |
| `lib/features/termination/presentation/termination_page.dart` | 离职记录 / 11顶部残片+规范推导 | 保留真实离职记录和详情导航 |
| `lib/features/termination/presentation/termination_form_page.dart` | 离职表单 / 11顶部残片+规范推导 | 保留人员、离职日期、原因及保存验证 |
| `lib/features/settings/presentation/settings_page.dart` | 设置 / 14顶部残片+规范推导 | 保留现有主题、数据、备份/导出入口与实际配置项 |
| `lib/features/backup/presentation/backup_page.dart` | 备份与恢复 / 无专图，规范推导 | 保留选档、覆盖前确认、完成/失败结果和重启入口 |
| `lib/features/excel/presentation/excel_page.dart` | Excel导出 / 13顶部残片+规范推导 | 保留真实预览/导出；从月表路由带入实际年月 |
| `lib/features/reports/presentation/reports_page.dart` | 月度汇总 / 06 直对 | 已按指标、tabs、数据表、异常和导出重排 |
| `lib/features/operation_logs/presentation/operation_log_page.dart` | 操作日志 / 无专图，规范推导 | 保留真实操作时间、对象、结果及筛选，不伪造示例日志 |
| `lib/features/item_distribution/presentation/item_distribution_page.dart` | 物品领取/福利发放 / 无专图，规范推导 | 保留发放、领取、补领、重复提醒及真实库存/人员校验 |

## 弹窗、菜单和确认流程覆盖

| 页面文件与入口 | 交互内容 | 参考/样式默认 |
|---|---|---|
| `personnel_list_page.dart` 搜索旁“筛选” | 高级筛选 bottom sheet：考勤组、入职月移除、已删除开关 | 对应02筛选入口；筛选区压缩并保留数据状态 |
| `personnel_detail_page.dart` 更多/删除 | 删除确认、已删除档案恢复菜单 | 对应03更多操作；保留软删除历史语义 |
| `personnel_form_page.dart` 出生/入职日期 | 日期选择器 | 日期使用设备真实日期与有效范围校验 |
| `employee_attachments_page.dart` 新增/查看/删除 | 附件类型选择 SimpleDialog、预览/隐私字段揭示/删除确认 | 09残片及附件业务规则推导；真实附件可查看 |
| `daily_attendance_page.dart` 日期/备注 | 日期选择器、备注编辑 AlertDialog | 对应04日期行/备注列；备注保存沿用真实流程 |
| `attendance_group_detail_page.dart` 成员操作 | 添加成员 bottom sheet、移出成员确认 | 按04班组chips及列表标准推导 |
| `monthly_roster_page.dart` 人员操作 | 加入名单 bottom sheet、移除/参与状态/离职相关确认、日期选择器 | 按05/06真实名单状态推导，保留操作保护 |
| `monthly_attendance_table_page.dart` 单元格 | 编辑出勤状态和日期对话框 | 对应05点击编辑提示；不可编辑原因保留真实锁定规则 |
| `reports_page.dart` 解锁操作 | 解锁原因 AlertDialog | 原有状态操作收进展开操作区；要求实际原因 |
| `reminder_page.dart` 列表更多 | 提醒删除确认及状态菜单 | Material 3确认控件，状态菜单只执行已有选项 |
| `reminder_alerts_page.dart` 提醒动作 | 延后时长 bottom sheet | 按真实提醒状态操作推导 |
| `reminder_form_page.dart` 对象选择 | 人员/对象 bottom sheet | 保留真实对象关联与校验 |
| `reminder_repeat_page.dart` 重复规则 | 间隔、结束方式及次数/日期 bottom sheets；截止日期选择器 | 保留现有重复规则业务字段 |
| `reminder_schedule_page.dart` 日期/时间 | 日期与时间 bottom sheets | 保留真实日期和时区/显示规则 |
| `insurance_page.dart` 变更记录更多 | 保险记录状态 PopupMenuButton | 真实办理状态和记录操作 |
| `insurance_profile_form_page.dart` 表单选择 | 参保档案状态、类型、有效月/基数选择 | 依08/12残片与规范推导，不添加“保险单位”假字段 |
| `insurance_change_form_page.dart` 表单选择 | 变更类型、状态、生效月份选择 | 12残片显示生效月/变更区域；继续用数据库字段 |
| `leave_form_page.dart` 表单选择 | 人员、请假类型、起止日期选择 | 业务日期校验和表单错误提示 |
| `overtime_page.dart` 更多 | 编辑/删除菜单，删除确认 | 真实时段记录保护 |
| `overtime_form_page.dart` 日期/时间/人员 | 日期时间选择器及人员选择 | 保留不重叠校验、计算时长 |
| `termination_form_page.dart` 表单 | 人员、日期、原因填写 | 11残片与规范推导，保留状态流转 |
| `payroll_editor_page.dart` 操作菜单 | 重生成、同步考勤、异常检查、确认/锁定/撤销、删草稿、导出；删批次/加人员/编辑明细确认或表单 | 保留既有工资业务操作及错误反馈，不压缩掉功能 |
| `wage_job_settings_page.dart` 工种操作 | 工种编辑/停用确认、添加生效日薪、月份选择对话框 | 真实工资生效规则，统一输入层级 |
| `backup_page.dart` 恢复 | 覆盖数据确认、恢复完成/重启选择、失败提示 | 操作前明确本地覆盖结果，保留真实备份流 |
| `item_distribution_page.dart` 物品操作 | 补领登记、福利设置、记录保存、重复领取提醒确认 | 真实领取库存和重复校验，不伪造示例数 |

## 代码检查记录

- 本次改动覆盖首页、人员名单/档案、每日/月考勤、Excel路由初始化月份、月度汇总及保险变更 provider；主题颜色无需改动。
- 对本次核心页面和路由运行定向 `dart analyze`：`No issues found!`。全量检查、测试、构建和模拟器截图由主 Agent 统一验收。
- 尚未完成 root 的最终实机验收。图07–14完整图像预览损坏，依据可读取的上部片段及01–06/规范板推导，不将黑色损坏区域当作设计内容。

## 2026-10-01 源码复核增补

逐项对照本报告列出的 40 个页面文件和弹窗/菜单入口后，确认上一版“已调整”只描述实施意图，不代表代码路径与数据口径都已通过复验。本次确认并修正以下实际差异：

| 页面/范围 | 源码复核发现 | 修正/结论 |
|---|---|---|
| 首页指标 | 参考图的第二行是今日出勤、今日请假、即将到期；旧实现显示非空考勤登记记录、异常月汇总条数和到今日为止的提醒数。字段名称和实际统计口径均不相同。 | 首页 provider 与卡片已对齐为真实 present 人数、当天请假人员数和未来30天提醒项数。模型未记录合同/保险到期日，故不显示参考图中的“合同/保险”说明，也未增加字段或业务。 |
| 人员名单入职月份 | 路由 query 在 `initState` 微任务初始化筛选；同一页面状态若被 GoRouter 以新 query 更新，原代码没有处理参数变化。 | 保留微任务以避开 build 生命周期写 provider；增加 `didUpdateWidget` 同步状态。新增跨两个月真实数据库记录的 widget 用例。 |
| 人员名单班组与新增按钮 | 班组下拉真实读取启用考勤组，筛选通过员工的 `defaultAttendanceGroupId` 作用于数据库查询；新增按钮源码为 64×64 `CircleBorder`，内部有图标和文字。 | 新增两组、两名真实数据库人员的筛选用例，并断言按钮形状。测试尚待主 Agent 串行执行。 |
| 每日考勤/月考勤表 | 每日页面标题实际为“每日考勤”；月表日期表头显示日数字及星期两行，不含“日”字。月表原来用固定 Column 排列日期选择、组、停用告警、表格及图例，在有限视口触发过 6px overflow。 | 测试改为匹配真实标题和日期单元；月表内容改为 ListView，表格继续保持自身横向/纵向滚动。测试尚待主 Agent 串行执行。 |
| 首页品牌图语义 | 首页品牌图已有 label，但 Semantics 未声明独立容器，现有 Semantics finder 未定位到目标节点。 | 加入 `container: true` 保留同一文案并明确语义边界；测试待主 Agent 串行执行。 |
| widget 测试收尾 | Drift `QueryStream` 在 ProviderScope 卸载时排入零延迟关闭 timer；放在 test teardown 的清理在测试框架 invariant 检查之后执行，仍报 pending timer。 | 所有 `widgetTest` 用例通过共享包装，在回调 `finally` 内卸载 widget、推进 fake clock、关闭内存 DB，再推进一次；不捕获断言异常。 |

模块差异矩阵列出的 40 个页面文件均存在。逐页源码检索确认本报告登记的主要 bottom sheet、dialog、日期时间选择器、下拉菜单、PopupMenu、加载/错误/空态回退路径存在；报表中的月份、3+2 指标、横向数据表、人员变动/保险变更 tab、异常列表及解锁原因均由相应 provider/repository 字段驱动。此项只代表源码路径审阅，不表示 40 页及每个弹窗均已完成真机逐屏视觉验收；07–14 图片不可读的限制仍然适用。

新增 provider 用例覆盖“present 对 rest”、跨日请假范围及提醒启用/完成/30天边界。`widget_test.dart` 当前所有 widget 用例已放入回调内清理包装。此工作流没有运行 Flutter test/build；主 Agent 需串行执行：`D:\Flutter\bin\flutter.bat test --no-pub test/widget_test.dart`，并按最终运行日志判断通过情况。此前分析结果是改动前的历史记录，不作为本次变更的静态分析结论。




## 本轮最终主审增补（2026-10-01）

以上“待主 Agent 执行/尚未最终验收”属于续接前或子代理交付时状态，最终结论以 [主审报告](../acceptance/UI参考图对照验收.md) 为准。本轮人员 Semantics、真实入职月/班组、Drift timer 均已回归通过；首页按参考收紧白卡与三列快捷区、待办首屏可见，真实统计单位和在岗/月新增导航参数修正。人员状态计数为单行括号数值，真实班组 chips 在前，全部班组在后；圆形 FAB 保留并实机核对。已有 terminationInsurance 待办的首页漏计已按提醒页相同类型判定修复，无 schema 改动。

最终全量 +202 通过；分析只有原有9条 info、无 error/warning。已构建保留数据安装，源码/实机独立审查与截图对应见 [索引](../acceptance/ui-reference-audit/截图审查索引_20261001.md)。07–14 损坏限制继续保留；40页及全部弹窗的源码路径核对不等于每个弹窗都有最终实机画面。用户后续要求通过页无需继续采集其余路由，已停止批量采集；不再为了补照片制造业务记录。
