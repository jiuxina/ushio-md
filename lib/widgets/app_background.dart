import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'particle_effect_widget.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  
  /// 是否在编辑器区域（用于判断是否显示粒子效果）
  final bool isEditor;

  const AppBackground({
    super.key,
    required this.child,
    this.isEditor = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    
    // 判断是否显示粒子效果
    final showParticles = settings.particleEnabled && 
        (settings.particleGlobal || !isEditor);
    
    // 粒子效果 Widget
    Widget? particleLayer;
    if (showParticles) {
      particleLayer = Positioned.fill(
        child: IgnorePointer(
          child: ParticleEffectWidget(
            particleType: settings.particleType,
            speed: settings.particleSpeed,
            enabled: true,
          ),
        ),
      );
    }
    
    Widget content = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                  const Color(0xFF0f0f23),
                ]
              : [
                  const Color(0xFFf8f9ff),
                  const Color(0xFFf0f4ff),
                  const Color(0xFFe8eeff),
                ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(child: child),
          if (particleLayer != null) particleLayer,
        ],
      ),
    );
    
    // Apply background image if set
    if (settings.backgroundImagePath != null) {
      final bgFile = File(settings.backgroundImagePath!);
      if (bgFile.existsSync()) {
        Widget bgImage = Image.file(
          bgFile,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
        
        // Apply blur effect
        if (settings.backgroundEffect == 'blur') {
          bgImage = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: settings.backgroundBlur,
              sigmaY: settings.backgroundBlur,
            ),
            child: bgImage,
          );
        }
        
        content = Stack(
          fit: StackFit.expand,
          children: [
            bgImage,
            // Apply overlay effect
            if (settings.backgroundEffect == 'overlay')
              Container(
                color: isDark 
                    ? Colors.black.withValues(alpha: settings.backgroundOverlayOpacity)
                    : Colors.white.withValues(alpha: settings.backgroundOverlayOpacity),
              ),
            SafeArea(child: child),
            // 粒子效果层
            if (particleLayer != null) particleLayer,
          ],
        );
      }
    }
    
    return content;
  }
}
