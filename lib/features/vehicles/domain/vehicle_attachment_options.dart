import '../../../core/database/database_enums.dart';

abstract final class VehicleAttachmentOptions {
  static const categories = VehicleAttachmentCategory.values;

  static String categoryLabel(VehicleAttachmentCategory category) =>
      switch (category) {
        VehicleAttachmentCategory.vehiclePhoto => '车辆照片',
        VehicleAttachmentCategory.repair => '故障/维修照片',
        VehicleAttachmentCategory.maintenance => '保养资料',
        VehicleAttachmentCategory.certificate => '车辆证照',
        VehicleAttachmentCategory.other => '其他资料',
      };

  static bool isImage(String extension) =>
      const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension.toLowerCase());
}
