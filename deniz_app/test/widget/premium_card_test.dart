import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PremiumCard smoke render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PremiumCard(
            child: Text('Test kart'),
          ),
        ),
      ),
    );
    expect(find.text('Test kart'), findsOneWidget);
  });

  testWidgets('PremiumCard onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumCard(
            onTap: () => tapped = true,
            child: const Text('Tıkla'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tıkla'));
    expect(tapped, isTrue);
  });
}
