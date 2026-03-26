import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/widgets/app_background.dart';
import 'package:mdreader/widgets/particle_effect_widget.dart';
import 'package:provider/provider.dart';

class _TestSettingsProvider extends ChangeNotifier implements SettingsProvider {
  _TestSettingsProvider({
    required this.particleEnabledValue,
    required this.particleGlobalValue,
    this.particleTypeValue = 'sakura',
    this.particleSpeedValue = 1.0,
  });

  final bool particleEnabledValue;
  final bool particleGlobalValue;
  final String particleTypeValue;
  final double particleSpeedValue;

  @override
  bool get particleEnabled => particleEnabledValue;

  @override
  bool get particleGlobal => particleGlobalValue;

  @override
  String get particleType => particleTypeValue;

  @override
  double get particleSpeed => particleSpeedValue;

  @override
  String? get backgroundImagePath => null;

  @override
  double get backgroundBrightness => 1.0;

  @override
  String get backgroundEffect => 'none';

  @override
  double get backgroundBlur => 10.0;

  @override
  double get backgroundOverlayOpacity => 0.5;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> _pumpAppBackground(
    WidgetTester tester, {
    required SettingsProvider settings,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(
          home: AppBackground(
            wrapWithSafeArea: false,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('wraps particle layer in RepaintBoundary when enabled',
      (tester) async {
    await _pumpAppBackground(
      tester,
      settings: _TestSettingsProvider(
        particleEnabledValue: true,
        particleGlobalValue: true,
      ),
    );

    expect(find.byType(ParticleEffectWidget), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RepaintBoundary),
        matching: find.byType(ParticleEffectWidget),
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not build particle layer when disabled', (tester) async {
    await _pumpAppBackground(
      tester,
      settings: _TestSettingsProvider(
        particleEnabledValue: false,
        particleGlobalValue: true,
      ),
    );

    expect(find.byType(ParticleEffectWidget), findsNothing);
  });

  test('ParticlePainter shouldRepaint only for non-ticker changes', () {
    final particles = <Particle>[
      Particle(x: 0.2, y: 0.3, size: 2.0, speed: 0.5),
    ];

    final oldPainter = ParticlePainter(
      particles: particles,
      particleType: 'sakura',
    );
    final samePainter = ParticlePainter(
      particles: particles,
      particleType: 'sakura',
    );
    final changedTypePainter = ParticlePainter(
      particles: particles,
      particleType: 'rain',
    );
    final changedListPainter = ParticlePainter(
      particles: <Particle>[
        Particle(x: 0.2, y: 0.3, size: 2.0, speed: 0.5),
      ],
      particleType: 'sakura',
    );

    expect(samePainter.shouldRepaint(oldPainter), isFalse);
    expect(changedTypePainter.shouldRepaint(oldPainter), isTrue);
    expect(changedListPainter.shouldRepaint(oldPainter), isTrue);
  });
}
