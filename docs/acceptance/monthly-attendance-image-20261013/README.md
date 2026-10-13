# 月考勤表图片导出验收（2026-10-13）

本次功能：月考勤表的“导出”菜单保留 Excel，并增加图片导出。对当前月份、所选分组的已加载月表建立快照，生成一张 3 倍分辨率、白底无损 PNG。预览支持双指缩放和拖动，保存使用预览的完整原始 PNG 字节；保存失败保留预览供重试，成功后禁用重复保存。

图片包含月份、分组、人数、姓名和工号、整月日期及星期、现有每日考勤符号、个人出勤/请假统计、底部合计和图例。姓名列按完整姓名和工号宽度展开，不使用省略号。统计及符号复用当前月表口径，没有修改考勤数据或统计业务规则。

## 验证结果

- `flutter analyze --no-pub`：本次 5 个 Dart 实现文件与新增测试文件无问题。
- `flutter test --no-pub test/attendance/monthly_attendance_image_test.dart test/attendance/monthly_attendance_table_repository_test.dart`：10 项通过。覆盖 20 人、31 天、末位人员/末日绘制、快照不随原数据变化、实际月份天数、320px 预览布局、双指放大、缩放后保存完整原图、保存失败重试、成功后禁止重复保存、所选分组和旧月份禁止导出。
- `flutter test --no-pub test/widget_test.dart --plain-name 'renders month cells and opens the cell editor'`：1 项通过，原单元格编辑入口正常。
- `flutter build apk --debug --no-pub`：通过，最终 APK 已安装到 `emulator-5554`。
- `git diff --check`：通过。

## Android 15 模拟器实际验证

使用已有的“生产一组”2026-10 月表，5 人、31 天。经过“导出图片 → 预览 → 保存到相册”，系统相册成功打开，并检查放大后的日期、符号及数字。

MediaStore 记录：`content://media/external/images/media/1000000153`；`mime_type=image/png`，`width=4524`，`height=1482`，`relative_path=Pictures/轻松办/`，`is_pending=0`。图中个人与整体合计与月表一致，出勤合计 2.5，请假合计 2。

- `exported.png`：从系统相册拉取的实际完整原图（4524 × 1482）。
- `preview.png`：应用内完整图片预览。
- `saved.png`、`saved.xml`：保存成功后的界面与语义记录。
- `gallery-zoom.png`：系统相册放大查看的截图。

证据范围：20 人月表通过自动化验证；实际设备流程使用已有的 5 人演示月表。Android API 24–28 的权限申请、公共 Pictures 写入及媒体扫描兼容路径已实现并编译通过，本次没有旧系统设备实测。未进行全应用回归。

仓库中本次开始前已有的月表请假/公休汇总改动及相关测试已保留。
