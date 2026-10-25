import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/features/assistant/application/assistant_chat.dart';
import 'package:qingsongban/features/assistant/application/assistant_favorites.dart';
import 'package:qingsongban/features/assistant/domain/assistant_chat_models.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_chat_settings.dart';

void main() {
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'advanced parameter labels stay inside expanded clip at scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              assistantChatSettingsProvider.overrideWith(_Settings.new),
              assistantQueryFavoritesProvider.overrideWith(_Favorites.new),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: AssistantChatSettingsPanel(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final advanced = find.widgetWithText(ExpansionTile, '高级参数');
        await tester.ensureVisible(advanced);
        await tester.tap(find.text('高级参数'));
        await tester.pumpAndSettle();
        for (final text in ['携带最近对话轮数', '单次输出 Token 上限']) {
          final label = find.text(text);
          expect(label, findsOneWidget);
          final box = tester.renderObject<RenderBox>(label);
          final corners = [
            box.localToGlobal(Offset.zero),
            box.localToGlobal(box.size.bottomRight(Offset.zero)),
          ];
          final rect = Rect.fromPoints(corners[0], corners[1]);
          RenderObject? ancestor = box.parent;
          while (ancestor != null) {
            if (ancestor is RenderClipRect &&
                ancestor.clipBehavior != Clip.none &&
                ancestor.hasSize) {
              final localClip =
                  ancestor.clipper?.getClip(ancestor.size) ??
                  (Offset.zero & ancestor.size);
              final clip = localClip.shift(ancestor.localToGlobal(Offset.zero));
              // Viewport scroll clipping is independent of expansion-content clipping.
              if (ancestor.size.height < 600 * scale) {
                expect(
                  rect.top,
                  greaterThanOrEqualTo(clip.top - 0.5),
                  reason: '$text is clipped at the expanded content top',
                );
                expect(
                  rect.bottom,
                  lessThanOrEqualTo(clip.bottom + 0.5),
                  reason: '$text is clipped at the expanded content bottom',
                );
              }
            }
            ancestor = ancestor.parent;
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Settings extends AssistantChatSettingsNotifier {
  @override
  Future<AssistantChatSettings> build() async => const AssistantChatSettings();
}

class _Favorites extends AssistantQueryFavoritesNotifier {
  @override
  Future<List<AssistantQueryFavorite>> build() async => const [];
}
