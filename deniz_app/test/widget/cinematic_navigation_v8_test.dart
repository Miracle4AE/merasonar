import 'package:deniz_app/map/utils/map_camera_animator.dart';
import 'package:deniz_app/navigation/premium_hero_tags.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_dialog.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_toast.dart';
import 'package:deniz_app/widgets/premium/navigation/captain_atlas_cinematic_opening.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_ambient_shell.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_bottom_sheet.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('PremiumHeroGoScore render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PremiumHeroGoScore(score: 82)),
      ),
    );
    expect(find.text('82'), findsOneWidget);
  });

  testWidgets('PremiumHeroCaptainAvatar render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PremiumHeroCaptainAvatar()),
      ),
    );
    expect(find.byType(PremiumHeroCaptainAvatar), findsOneWidget);
  });

  testWidgets('PremiumAmbientShell wraps child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PremiumAmbientShell(child: Text('İçerik')),
      ),
    );
    expect(find.text('İçerik'), findsOneWidget);
    expect(find.byType(PremiumAmbientShell), findsOneWidget);
  });

  testWidgets('CinematicSlidePanel slide render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CinematicSlidePanel(
            width: 300,
            onDismiss: () {},
            child: const Text('Panel'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Panel'), findsOneWidget);
  });

  testWidgets('CaptainAtlasCinematicOpening completes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CaptainAtlasCinematicOpening(
            child: Text('İçerik hazır'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('İçerik hazır'), findsOneWidget);
  });

  testWidgets('PremiumToast show', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => PremiumToast.show(ctx, 'Test mesajı'),
                child: const Text('Toast'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    expect(find.text('Test mesajı'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('PremiumDialog showAlert', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => PremiumDialog.showAlert(
                  ctx,
                  title: 'Başlık',
                  message: 'Mesaj',
                ),
                child: const Text('Dialog'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Başlık'), findsOneWidget);
    expect(find.text('Mesaj'), findsOneWidget);
  });

  test('PremiumHeroTags stable', () {
    expect(PremiumHeroTags.hotspot(7), 'hero_hotspot_7');
    expect(PremiumHeroTags.savedSpot('abc'), 'hero_saved_spot_abc');
    expect(PremiumHeroTags.goScore, 'hero_go_score');
  });

  testWidgets('MapCameraAnimator attaches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _MapCameraTestHost(),
      ),
    );
    expect(find.byType(FlutterMap), findsOneWidget);
  });
}

class _MapCameraTestHost extends StatefulWidget {
  @override
  State<_MapCameraTestHost> createState() => _MapCameraTestHostState();
}

class _MapCameraTestHostState extends State<_MapCameraTestHost>
    with TickerProviderStateMixin {
  final _controller = MapController();
  late final MapCameraAnimator _animator;

  @override
  void initState() {
    super.initState();
    _animator = MapCameraAnimator(controller: _controller, vsync: this);
  }

  @override
  void dispose() {
    _animator.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _controller,
        options: const MapOptions(
          initialCenter: LatLng(41, 29),
          initialZoom: 10,
        ),
        children: const [],
      ),
    );
  }
}
