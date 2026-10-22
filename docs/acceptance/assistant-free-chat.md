# 智能助手第二批：自由对话与设置

## 使用入口

智能助手顶部切换“业务查询 / 自由对话”。业务查询保留原有本地查询、快捷条件、收藏、结构化结果与来源跳转；自由对话使用独立历史和草稿，只发送用户聊天内容及该模式完整的历史轮次，不自动附带本地业务记录。

自由对话顶部提供历史、新对话、导出。历史支持标题/正文搜索、打开、单条删除、清空全部和 Markdown 导出。消息提供复制、编辑后重发、最后回复重新生成；生成期间可停止，失败/中断消息保留并标明未完成，后续上下文跳过未完成轮次。

## 设置

右上角更多 → AI 设置。API Key 继续使用安全存储；业务查询的模型适配保持现有配置。新增“自由对话 · 模型连接”单独设置 HTTPS API 地址和模型、测试已保存配置。自定义服务会收到所用 Key 和聊天文本，界面在地址字段说明。保存前不发请求。

对话偏好折叠分组：默认模式、简洁回答、字号。高级参数：历史上下文轮数、输出 Token 上限。收藏管理可删除已存快捷查询，历史管理入口位于自由对话顶部。Token 和耗时在回复下方展示，为当前请求数据，不表示账户余额或费用。

设置和历史写入现有 AppSettings，按 settingKey upsert，无数据库 schema 迁移。Key 不写入历史、普通设置或导出。

## 验证

测试设备限定 Android API 35 模拟器 emulator-5554，没有使用物理手机。可复现命令：

```powershell
flutter test integration_test -d emulator-5554 --reporter expanded
```

第二批端到端测试启动模拟器内部 HTTP SSE fixture，走实际 dart:io 传输，验证 UTF-8 流、表格、usage、停止、模式/草稿、历史搜索恢复、缺少 Key 和设置界面；fixture Key 仅在测试内存中。此证据不等同于真实 DeepSeek 账户连通性。真实服务需要在设置中安全保存有效 Key 后由用户点击连接测试。

参考：DeepSeek [Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion)，Markdown 使用 [flutter_markdown_plus](https://pub.dev/packages/flutter_markdown_plus)。初版请求关闭 thinking；后续已补充深度思考、联网搜索和峰谷提醒，见 [增强功能验收](assistant-thinking-search-pricing.md)。

## 模拟器回归中修复的问题

- 自由对话草稿跨模式和浮窗/全屏切换保留。停止与切换会话隔离旧响应，未完成轮次不进入后续上下文。
- 新回复为候选人员时，滚动定位到候选区；业务结果仍定位卡片开头。
- 浮窗只由外层扣除键盘高度，内层 Scaffold 不重复缩高；键盘显示时临时收起模式栏和快捷入口。
- 从助手跳转月考勤表时，小屏的无考勤组空态允许滚动，避免键盘仍显示期间布局溢出。
- 旧测试按 API Key 标签定位输入框，等待滚动完成后点击；模拟后台后按合法生命周期顺序恢复前台。

## 最终结果（2026-10-22）

- API 35 模拟器完整运行 `flutter test integration_test -d emulator-5554 --reporter expanded`：65 项通过。
- 本批源码、相关月考勤表页面及新增测试共 13 个检查目标 analyze 无问题。普通 debug APK 构建、安装成功。
- 普通安装版手动验证：对话默认模式设置保存后重启仍生效；Android 文件选择器导出得到 68 字节 Markdown，核对用户/助手分节有效；测试会话与测试下载文件已清理，默认模式恢复业务查询。
- 验证证据位于本机 `build/assistant-batch-two/acceptance.log`、`analyze.log`、`build.log`、`manual-checks.json` 和界面截图。真实 DeepSeek 请求未在本次使用有效账户 Key 联调。
