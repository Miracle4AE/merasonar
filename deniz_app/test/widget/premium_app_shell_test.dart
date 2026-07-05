import 'package:deniz_app/layout/premium_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PremiumAppShell smoke render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PremiumAppShell(
          selectedSectionId: 'overview',
          onSectionSelected: (_) {},
          serverIp: '127.0.0.1',
          child: const Text('İçerik alanı'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('İçerik alanı'), findsOneWidget);
    expect(find.byType(PremiumAppShell), findsOneWidget);
  });

  testWidgets('PremiumAppShell mobile drawer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PremiumAppShell(
          selectedSectionId: 'overview',
          onSectionSelected: (_) {},
          serverIp: '127.0.0.1',
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PremiumAppShell), findsOneWidget);
  });
}
