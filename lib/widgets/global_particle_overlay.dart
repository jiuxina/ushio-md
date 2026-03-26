import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'particle_effect_widget.dart';

/// 应用级全局粒子覆盖层。
///
/// 通过挂在 MaterialApp.builder，确保路由切换期间复用同一粒子实例，
/// 避免每个页面分别创建导致的粒子位置跳变。
class GlobalParticleOverlay extends StatelessWidget {
  final Widget child;

  const GlobalParticleOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final showGlobalParticles =
        settings.particleEnabled && settings.particleGlobal;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showGlobalParticles)
          Positioned.fill(
            child: IgnorePointer(
              child: TickerMode(
                enabled: true,
                child: RepaintBoundary(
                  child: ParticleEffectWidget(
                    particleType: settings.particleType,
                    speed: settings.particleSpeed,
                    enabled: true,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
