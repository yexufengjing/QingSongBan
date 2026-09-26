# QingSongBan
自用软件

## 加载演示数据

需要在 Android 模拟器中快速验证中国姓名、考勤、请假、加班、离职和社保页面时，使用以下命令启动一次：

```powershell
flutter run --dart-define=QSB_SEED_DATA=true
```

演示数据只会在数据库中不存在 `DEMO-` 人员和种子标记时插入一次，包含虚构的中国姓名、手机号、身份证号和地址，不代表真实个人信息。普通启动不加载演示数据。

只加载车辆管理演示数据时，使用独立开关：

```powershell
flutter run --dart-define=QSB_SEED_VEHICLE_DATA=true
```

车辆演示数据包含虚构车辆、车况、油耗、保养、维修和费用记录；每个应用数据库只加载一次，不影响人员演示数据。

## 项目文档

文档已按产品方案、开发过程、验收记录和数据库说明分类，入口见 [文档目录](docs/README.md)。
