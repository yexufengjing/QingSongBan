import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const purchaseTestChineseFontFamily = 'PurchaseAcceptanceChinese';
const purchaseTestMaterialIconsFamily = 'MaterialIcons';

ThemeData purchaseAcceptanceTheme(ThemeData base, String? family) {
  TextStyle? withFamily(TextStyle? style) =>
      style?.copyWith(fontFamily: family);

  ButtonStyle? buttonStyle(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) => withFamily(
        style.textStyle?.resolve(states) ?? base.textTheme.labelLarge,
      ),
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: family),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: withFamily(base.appBarTheme.titleTextStyle),
      toolbarTextStyle: withFamily(base.appBarTheme.toolbarTextStyle),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: withFamily(base.inputDecorationTheme.labelStyle),
      floatingLabelStyle: withFamily(
        base.inputDecorationTheme.floatingLabelStyle,
      ),
      hintStyle: withFamily(base.inputDecorationTheme.hintStyle),
      helperStyle: withFamily(base.inputDecorationTheme.helperStyle),
      errorStyle: withFamily(base.inputDecorationTheme.errorStyle),
      counterStyle: withFamily(base.inputDecorationTheme.counterStyle),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: buttonStyle(base.filledButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buttonStyle(base.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonStyle(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: buttonStyle(base.textButtonTheme.style),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: withFamily(base.chipTheme.labelStyle),
      secondaryLabelStyle: withFamily(base.chipTheme.secondaryLabelStyle),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      titleTextStyle: withFamily(base.dialogTheme.titleTextStyle),
      contentTextStyle: withFamily(base.dialogTheme.contentTextStyle),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      textStyle: withFamily(base.popupMenuTheme.textStyle),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) =>
            withFamily(base.navigationBarTheme.labelTextStyle?.resolve(states)),
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelStyle: withFamily(base.tabBarTheme.labelStyle),
      unselectedLabelStyle: withFamily(base.tabBarTheme.unselectedLabelStyle),
    ),
  );
}

Future<String?> loadPurchaseTestFonts({
  required bool requiredForCapture,
}) async {
  final chineseFont = File(r'C:\Windows\Fonts\simhei.ttf');
  if (chineseFont.existsSync()) {
    final loader = FontLoader(purchaseTestChineseFontFamily)
      ..addFont(
        Future.value(ByteData.sublistView(await chineseFont.readAsBytes())),
      );
    await loader.load();
  } else if (requiredForCapture) {
    throw StateError(
      'Purchase UI capture requires the test-only Chinese font '
      '${chineseFont.path}; refusing to capture fallback glyphs.',
    );
  }

  final iconsFont = await _materialIconsFont();
  if (iconsFont == null) {
    if (requiredForCapture) {
      throw StateError(
        'Purchase UI capture requires MaterialIcons-Regular.otf from the '
        'active Flutter SDK; refusing to capture missing icon glyphs.',
      );
    }
    return chineseFont.existsSync() ? purchaseTestChineseFontFamily : null;
  }

  final loader = FontLoader(
    purchaseTestMaterialIconsFamily,
  )..addFont(Future.value(ByteData.sublistView(await iconsFont.readAsBytes())));
  await loader.load();
  return chineseFont.existsSync() ? purchaseTestChineseFontFamily : null;
}

Future<File?> _materialIconsFont() async {
  var current = File(Platform.resolvedExecutable).parent;
  while (true) {
    final fontsDirectory = Directory(
      '${current.path}${Platform.pathSeparator}bin${Platform.pathSeparator}'
      'cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}'
      'material_fonts',
    );
    if (fontsDirectory.existsSync()) {
      for (final font in fontsDirectory.listSync().whereType<File>()) {
        if (font.uri.pathSegments.last.toLowerCase() ==
            'materialicons-regular.otf') {
          return font;
        }
      }
    }
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}
