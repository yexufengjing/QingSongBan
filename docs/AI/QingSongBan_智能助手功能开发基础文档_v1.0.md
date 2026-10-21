# QingSongBan 智能助手功能开发基础文档 v1.0

> 文档定位：智能助手功能的第一阶段基础设计文档  
> 适用项目：QingSongBan  
> 版本：v1.0  
> 日期：2026-10-17

---

## 1. 文档目的

本文件用于确定 QingSongBan App 内智能助手功能的基础产品方向、总体架构、关键设计原则和能力边界，为后续 UI 设计、模型接入、Tool 设计、数据接口、权限控制和功能开发提供统一依据。

本阶段不追求一次性实现完整 Agent，也不以“通用聊天机器人”为目标。第一阶段首先解决以下问题：

1. 智能助手在 App 中承担什么角色。
2. DeepSeek、Gemini 等大模型如何统一接入。
3. AI 如何安全地读取和操作 App 内业务数据。
4. 哪些能力由大模型完成，哪些能力必须由 App 本身完成。
5. 后续功能如何在不破坏现有业务模块的情况下逐步扩展。

---

# 2. 产品定位

QingSongBan 智能助手定位为：

> **App 内的自然语言操作入口、数据查询助手和工作分析助手。**

智能助手不是独立于现有功能之外的聊天工具，而是连接人员、考勤、工资、采购、库存、车辆、维修、提醒等业务模块的统一自然语言入口。

其核心价值不是“能聊天”，而是让用户可以直接表达工作意图，例如：

- “查一下 9 月份王某的考勤。”
- “哪些库存快没了？”
- “今年哪辆车维修费用最高？”
- “帮我整理本月临时工工资。”
- “今天特钢张三维修割草机，更换刀片 80 元。”
- “提醒我下周一检查 3 号洒水车轮胎。”

系统负责将自然语言转换为明确的业务查询或业务操作。

---

# 3. 核心设计原则

## 3.1 AI 不作为业务数据源

数据库和现有业务模块始终是唯一真实数据源。

大模型不得凭空生成：

- 人员信息；
- 考勤数据；
- 工资数据；
- 库存数量；
- 采购记录；
- 车辆状态；
- 维修费用；
- 油耗数据；
- 其他实际业务数据。

涉及真实数据时，必须先调用 App 内部业务接口获取结果，再由模型进行解释、归纳或展示。

设计原则：

```text
用户问题
    ↓
AI 理解意图
    ↓
调用 App Tool
    ↓
业务代码查询 / 计算
    ↓
返回结构化数据
    ↓
AI 组织结果
```

---

## 3.2 AI 不直接访问数据库

禁止大模型直接生成 SQL 或直接对数据库执行写操作。

统一采用：

```text
AI
↓
Tool / Function Calling
↓
Service
↓
Repository
↓
Local Database
```

这样可以保证：

- 数据权限可控；
- 参数可以校验；
- 错误可以追踪；
- 业务规则不会被绕过；
- 后续更换模型不会影响数据库结构。

---

## 3.3 确定性业务逻辑继续由 App 负责

以下逻辑不得交给大模型直接计算：

- 临时工工资；
- 出勤天数；
- 加班统计；
- 请假统计；
- 库存结余；
- 油耗汇总；
- 维修费用合计；
- 月度、年度统计；
- 重复领取判断；
- 采购状态流转；
- 其他有固定公式和规则的计算。

例如临时工工资：

```text
工资 = 出勤天数 × 日薪 + 补助 − 保险费用扣除
```

仍由 PayrollService 等确定性业务代码计算。

AI 只负责：

1. 理解用户要计算哪个月份；
2. 调用计算接口；
3. 解释计算结果；
4. 根据结果提供下一步操作入口。

---

# 4. 总体架构

建议采用五层架构。

```text
┌──────────────────────────┐
│          用户             │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│      智能助手 UI          │
│ 对话 / 快捷任务 / 结果卡片 │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│ Assistant Orchestrator   │
│ 意图识别                  │
│ 上下文管理                │
│ 权限判断                  │
│ Tool 调度                 │
│ 模型路由                  │
└───────┬──────────┬───────┘
        ↓          ↓
┌──────────────┐ ┌──────────────┐
│ App Tools    │ │ Model Gateway│
│ 数据查询      │ │ DeepSeek     │
│ 业务计算      │ │ Gemini       │
│ 创建草稿      │ │ 其他模型      │
│ 页面跳转      │ └──────────────┘
└───────┬──────┘
        ↓
┌──────────────────────────┐
│   App Service / Database │
└──────────────────────────┘
```

---

# 5. 核心模块划分

## 5.1 Assistant UI

负责用户交互，不直接承担业务逻辑。

主要包括：

- 智能助手主页；
- 消息列表；
- 输入框；
- 快捷任务入口；
- 结果卡片；
- Tool 执行状态；
- 操作确认窗口；
- 会话历史；
- 模型状态显示。

---

## 5.2 Assistant Orchestrator

作为整个智能助手的核心调度层。

主要职责：

### 意图识别

识别用户当前需求属于：

- 普通问答；
- 查询数据；
- 数据分析；
- 新增记录；
- 修改记录；
- 页面跳转；
- 创建提醒；
- 多步骤任务。

### 上下文管理

保存并管理：

- 当前会话；
- 当前页面；
- 当前业务对象；
- 最近一次查询；
- 最近 Tool 调用结果；
- 用户继续追问所需的上下文。

例如：

用户首先询问：

> 查看 9 月份王某考勤。

随后继续问：

> 那李某呢？

助手需要继承：

```text
月份 = 2026-09
查询类型 = 月度考勤
```

只替换人员。

---

## 5.3 Model Gateway

所有大模型统一通过 Model Gateway 调用。

禁止在不同业务模块中直接调用 DeepSeek API 或 Gemini API。

统一抽象：

```text
AIProvider
├── DeepSeekProvider
├── GeminiProvider
└── FutureProvider
```

基础能力接口建议统一为：

```text
chat()
streamChat()
toolCall()
structuredOutput()
vision()
```

业务层只依赖统一 AIProvider，不依赖具体厂商。

这样未来可以：

- 更换默认模型；
- 增加其他模型；
- 删除某个模型；
- 自动切换模型；
- 针对不同任务分配不同模型。

---

# 6. 模型选择策略

第一阶段支持：

- DeepSeek；
- Gemini。

用户设置中允许选择：

```text
默认模型

● 自动选择
○ DeepSeek
○ Gemini
```

推荐默认采用：

**自动选择。**

普通用户无需判断不同模型的具体能力。

后续 ModelRouter 可以按照任务类型自动路由。

示意：

```text
普通文本问答
→ 低成本模型

结构化信息提取
→ 低成本模型

复杂数据分析
→ 强推理模型

图片识别
→ 多模态模型

当前模型异常
→ 备用模型
```

第一阶段不需要设计复杂的智能路由算法，只需保留扩展接口。

---

# 7. Tool Calling 设计原则

Tool 是连接 AI 和 QingSongBan 业务系统的核心。

每个 Tool 都对应一个明确、可验证的 App 能力。

例如：

```text
getEmployees()
getEmployeeAttendance()
getMonthlyAttendance()
getPayroll()
getInventory()
getLowStockItems()
getPurchaseRecords()
getVehicles()
getVehicleRepairs()
getFuelSummary()
getRepairRecords()
```

模型只能：

1. 判断需要调用哪个 Tool；
2. 提供 Tool 参数；
3. 接收 Tool 返回结果。

模型不能绕过 Tool 自行访问数据库。

---

# 8. Tool 分类

建议将 Tool 划分为四类。

## 8.1 查询类 Tool

只读取数据。

例如：

```text
getEmployees
getEmployeeAttendance
getMonthlyAttendance
getInventory
getVehicles
getVehicleRepairs
```

特点：

- 风险低；
- 默认可以直接执行；
- 第一阶段优先开发。

---

## 8.2 计算类 Tool

调用现有确定性业务逻辑。

例如：

```text
calculatePayroll
calculateAttendanceSummary
calculateFuelSummary
calculateRepairCost
```

AI 不参与具体数值运算规则。

---

## 8.3 草稿类 Tool

根据用户自然语言生成待确认的数据。

例如：

```text
createPurchaseDraft
createRepairDraft
createReminderDraft
```

示例：

用户：

> 今天特钢张三维修割草机，换刀片 80 元。

助手生成：

```text
维修记录草稿

日期：2026-10-17
维修单位：特钢
维修人：张三
设备：割草机
维修内容：更换刀片
金额：80 元
```

然后显示：

```text
[修改]
[确认保存]
```

---

## 8.4 写入类 Tool

真正修改业务数据。

例如：

```text
saveRepairRecord
savePurchaseRecord
updateVehicle
deleteRecord
```

写入类 Tool 必须经过用户确认。

---

# 9. AI 操作权限模型

建议划分四级权限。

| 等级 | 能力 | 是否需要确认 |
|---|---|---|
| L0 | 普通问答 | 否 |
| L1 | 数据查询 | 否 |
| L2 | 生成操作草稿 | 否 |
| L3 | 修改、新增、删除实际数据 | 是 |

其中高风险操作建议额外限制。

例如：

- 批量删除数据；
- 永久删除附件；
- 覆盖备份；
- 恢复数据库；
- 修改系统核心设置。

第一阶段建议不向 AI 开放这些操作。

---

# 10. 页面上下文

智能助手需要知道用户当前位于哪个页面。

例如用户位于：

```text
车辆详情
vehicleId = 12
```

此时用户直接询问：

> 今年修了几次？

系统自动补充：

```text
vehicleId = 12
year = 当前年份
```

无需用户重新说明车辆名称。

推荐统一页面上下文结构：

```text
AssistantPageContext
{
  module
  page
  entityType
  entityId
  additionalContext
}
```

例如：

```text
module = vehicle
page = vehicle_detail
entityType = vehicle
entityId = 12
```

---

# 11. 上下文最小化原则

不得因为 AI 需要分析数据就把整个本地数据库发送给模型。

遵循：

> **只发送完成当前任务所必需的数据。**

例如用户询问：

> 王某 9 月份考勤怎么样？

发送：

```text
王某
2026-09
王某对应考勤结果
```

不要发送：

- 全部员工；
- 全部工资；
- 身份证；
- 电话；
- 全部车辆；
- 全部采购；
- 全部库存。

---

# 12. 敏感数据处理

建议增加：

```text
ContextSanitizer
```

负责在发送模型前处理敏感字段。

默认不发送：

- 身份证号；
- 银行卡号；
- 手机号；
- 不相关工资信息；
- 保险敏感信息；
- 其他与当前任务无关的个人信息。

基本原则：

```text
业务数据库
↓
Tool 查询
↓
ContextSanitizer
↓
必要字段
↓
Model Gateway
```

---

# 13. 智能助手入口设计

不建议在当前五个底部导航之外增加第六个固定 Tab。

建议采用：

## 全局入口

使用全局悬浮按钮或导航栏智能助手入口：

```text
✦ 智能助手
```

可以从任意主要页面打开。

## 页面级入口

在支持 AI 分析的页面增加：

```text
✦ 问助手
```

例如：

- 人员详情；
- 月考勤；
- 工资；
- 库存；
- 车辆详情；
- 油耗；
- 维修；
- 采购。

页面级入口自动携带当前页面上下文。

---

# 14. 智能助手主页基础结构

建议第一版结构：

```text
┌─────────────────────────┐
│ 智能助手                 │
│                         │
│ 今天想处理什么？          │
│                         │
│ [查询考勤] [库存分析]     │
│ [车辆分析] [采购记录]     │
│                         │
│ 最近使用                 │
│ · 查看本月临时工工资      │
│ · 查看低库存物资          │
│                         │
│ ┌─────────────────────┐ │
│ │ 输入问题……        🎙 │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

第一版可以暂不实现语音，只保留 UI 扩展位置。

---

# 15. 快捷任务设计

相比单独一个空白聊天框，推荐提供高频快捷任务。

首批建议：

### 人员与考勤

- 查询员工；
- 查询个人考勤；
- 查询月度考勤；
- 查询请假；
- 查询加班。

### 临时工工资

- 查询某月工资；
- 查询某人工资；
- 生成月度工资汇总。

### 库存

- 查询库存；
- 查询低库存；
- 查询物资流水。

### 采购

- 查询采购状态；
- 查询采购历史；
- 创建采购记录草稿。

### 车辆

- 查询车辆状态；
- 查询维修记录；
- 查询油耗；
- 查询年度维修费用。

### 园林器械维修

- 查询维修记录；
- 创建维修记录草稿；
- 查询维修费用。

---

# 16. 首期推荐 Tool

第一阶段建议控制在约 10～15 个 Tool。

推荐：

```text
getEmployees
getEmployeeAttendance
getMonthlyAttendance
getLeaveRecords
getOvertimeRecords

getPayroll

getInventory
getLowStockItems

getPurchaseRecords

getVehicles
getVehicleRepairs
getFuelSummary

getRepairRecords

createReminderDraft
createPurchaseDraft
createRepairDraft
```

原则：

> 优先覆盖高频、确定性强、风险低的查询能力。

暂不追求“一次接入所有业务”。

---

# 17. 典型流程

## 17.1 查询考勤

用户：

> 查一下 9 月份王某的考勤。

执行：

```text
自然语言
↓
识别 Tool
↓
getEmployeeAttendance
↓
App 查询数据库
↓
返回结构化结果
↓
AI 生成自然语言总结
```

---

## 17.2 查询库存

用户：

> 哪些东西快没了？

执行：

```text
自然语言
↓
getLowStockItems
↓
库存 Service
↓
返回低库存数据
↓
结果卡片
```

结果卡片可以提供：

```text
查看库存
加入待采购
```

涉及实际新增待采购记录时，需要用户确认。

---

## 17.3 新增维修记录

用户：

> 今天特钢张三维修割草机，更换刀片 80 元。

执行：

```text
自然语言
↓
结构化解析
↓
createRepairDraft
↓
维修草稿卡片
↓
用户确认
↓
saveRepairRecord
```

不得从自然语言直接跳到数据库写入。

---

# 18. API Key 方案

项目目前以个人自用、本地化为主，因此第一阶段可以采用 BYOK：

> Bring Your Own Key

即用户自己配置 DeepSeek / Gemini API Key。

建议：

```text
AI 设置

DeepSeek
API Key：••••••••••••
状态：已连接

Gemini
API Key：••••••••••••
状态：已连接

默认模型：
● 自动
○ DeepSeek
○ Gemini
```

API Key 必须存储在：

- Android Keystore；
- iOS Keychain；
- 或 Flutter 对应安全存储方案。

禁止：

- 明文存储在 SQLite；
- 写入普通 SharedPreferences；
- 写死在代码；
- 提交到 GitHub。

---

# 19. 后续公开发布时的架构

如果未来 App 面向多人或公开发布，应改为：

```text
App
↓
AI Gateway
↓
DeepSeek / Gemini
```

Gateway 负责：

- API Key；
- 用户鉴权；
- 请求限流；
- Token 统计；
- 成本控制；
- 模型路由；
- 请求日志；
- Provider 降级；
- 敏感信息控制。

当前个人版本无需提前建设云端 Gateway，但代码架构必须预留替换能力。

---

# 20. 成本控制基础设计

所有模型调用建议记录：

```text
provider
model
inputTokens
outputTokens
cachedTokens
latency
cost
success
toolCalls
timestamp
```

第一阶段只需要实现基础统计，不需要复杂计费系统。

建议提供：

```text
今日调用次数
本月调用次数
本月 Token
预估费用
平均响应时间
```

---

# 21. 错误与降级策略

智能助手必须考虑模型不可用情况。

常见异常：

- API Key 无效；
- 网络错误；
- 请求超时；
- Provider 服务异常；
- 模型不存在；
- Token 超限；
- Tool 参数错误；
- JSON 输出格式错误。

基础策略：

```text
请求
↓
当前模型
↓
失败
↓
允许重试
↓
备用模型
↓
仍失败
↓
明确提示用户
```

不得因为模型异常导致 App 主业务不可用。

即：

> AI 是增强能力，不是现有业务模块的运行前提。

---

# 22. 会话历史

第一阶段建议保存：

```text
Conversation
Message
ToolCall
ToolResult
```

但不建议无限保存全部上下文并每次重新发送给模型。

采用：

```text
最近消息
+
必要历史摘要
+
当前页面上下文
+
当前任务数据
```

降低 Token 消耗。

---

# 23. 第一阶段明确不做

为了控制开发复杂度，v1.0 基础阶段暂不开发：

- 完全自主 Agent；
- 自动连续执行大量操作；
- 自动修改数据库；
- AI 自动批量删除；
- 长期自主运行；
- 云端知识库；
- 复杂 RAG；
- 实时语音助手；
- 多 Agent 协作；
- AI 自动决策采购；
- AI 自动决定工资；
- AI 自动改变库存；
- AI 自动恢复数据库。

---

# 24. MVP 目标

第一版核心目标可以概括为：

> **能问、能查、能生成操作草稿，但不能未经确认修改重要数据。**

MVP 基础能力：

```text
01 智能助手独立页面
02 DeepSeek Provider
03 Gemini Provider
04 API Key 配置
05 模型统一抽象
06 流式聊天
07 多轮上下文
08 页面上下文
09 Tool Calling
10 App 数据查询
11 结构化结果卡片
12 操作草稿
13 写操作确认
14 会话历史
15 Token / 调用统计
16 Provider 错误处理
```

---

# 25. 第一阶段开发优先顺序

建议按以下顺序开发。

### Step 1：基础架构

完成：

```text
AIProvider
ModelGateway
AssistantOrchestrator
ToolRegistry
AssistantContext
```

### Step 2：模型接入

完成：

```text
DeepSeekProvider
GeminiProvider
API Key 管理
基础连接测试
流式输出
```

### Step 3：智能助手 UI

完成：

```text
助手首页
聊天界面
快捷任务
结果卡片
Loading / Error
```

### Step 4：查询 Tool

优先接入：

```text
人员
考勤
工资
库存
采购
车辆
维修
```

### Step 5：页面上下文

实现：

```text
当前模块
当前页面
当前实体
```

### Step 6：草稿操作

实现：

```text
采购草稿
维修草稿
提醒草稿
```

### Step 7：安全确认

所有写操作：

```text
AI生成
↓
用户查看
↓
确认
↓
业务 Service
↓
数据库
```

---

# 26. 第一阶段验收标准

达到以下条件即可认为智能助手基础架构完成。

## 模型

- DeepSeek 可以正常调用；
- Gemini 可以正常调用；
- 模型之间可以切换；
- 业务模块不直接依赖具体模型。

## 对话

- 支持流式回答；
- 支持多轮对话；
- 支持基础会话历史。

## Tool

- AI 可以正确识别查询意图；
- 可以调用 App Tool；
- Tool 返回真实数据库数据；
- AI 可以解释 Tool 返回结果。

## 上下文

- 可以识别当前页面；
- 可以识别当前业务对象；
- 连续追问时可以继承必要上下文。

## 安全

- AI 无法直接访问数据库；
- AI 无法未经确认修改重要业务数据；
- API Key 不明文存储；
- 敏感字段默认不发送给模型。

## 稳定性

- AI 服务失败不会影响现有 App；
- Tool 调用失败具有明确错误提示；
- Provider 异常可以重试或切换。

---

# 27. 后续文档拆分建议

本基础文档确认后，建议继续形成以下专项开发文档：

```text
01 智能助手_UI与交互设计规范.md

02 智能助手_模型接入与Provider架构.md

03 智能助手_Tool Calling开发规范.md

04 智能助手_业务Tool清单与参数定义.md

05 智能助手_上下文与会话管理.md

06 智能助手_数据安全与权限规范.md

07 智能助手_MVP开发执行文档.md
```

其中下一步优先建议编写：

> **《智能助手_Tool Calling 与业务能力映射设计 v1.0》**

因为 Tool 层决定智能助手能够真正使用 QingSongBan 哪些功能，也是后续模型接入、UI 和业务开发之间的核心连接层。

---

# 28. 最终原则

QingSongBan 智能助手的基础设计应始终遵循以下原则：

```text
AI负责理解
业务代码负责执行

AI负责表达
数据库负责事实

AI负责建议
用户负责确认

AI增强现有功能
但不取代现有业务系统
```

最终目标不是把 QingSongBan 改造成一个聊天软件，而是让自然语言逐步成为现有 App 的第二套高效操作方式。
