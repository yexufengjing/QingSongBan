# 首批库存与首页设备检查（2026-10-09）

设备：`emulator-5554` / `qingsongban_api35`，API 35，1080×2400，density 420。安装包：`build/app/outputs/flutter-apk/app-debug.apk`，SHA256 `0DD71DFE7987E02A7512D7C218A74AC09D2E56C872453057014AF21A7BABF14E`。

检查路径：

- 首页“库存出库”进入008领用登记；首页“库存管理”进入库存首页，底部“领用出库”进入007领用记录。
- 007固定“新增领取登记”进入008；表单返回后回到007。
- 008点领取人打开Bottom Sheet并弹出系统键盘；键盘上方搜索框与可滚动名单仍可见。系统返回收起键盘/关闭选择器，未选中名单项。

本次只检查路由、返回和键盘触达，没有选择人员或物资、保存表单或改变库存。设备保留原有数据库。`inventory-issues-final.png`展示原库已有领用记录；`issue_form_items_390_1.0.png`的两项物资仅来自Widget测试fixture，不能视为设备数据。

截图：

- [首页处理](home_processing-final.png)
- [库存首页](inventory-home-final.png)
- [007领用记录](inventory-issues-final.png)
- [008空表单入口](inventory-entry-final.png)
- [领取人选择与键盘](inventory-picker-keyboard-final.png)

复核边界：模拟器没有2026-10月度名单，首页今日考勤登记进度显示名单0人、上午0、下午0；本次未用假数据填补。多物资提交、扣减与撤销语义由库存事务回归覆盖，未在保留原库的模拟器上写入新记录。
