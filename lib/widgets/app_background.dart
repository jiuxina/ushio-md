import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'particle_effect_widget.dart';

class AppBackground extends StatefulWidget {
  final Widget child;
  
  /// 是否在编辑器区域（用于判断是否显示粒子效果）
  final bool isEditor;

  /// 是否用 SafeArea 包裹子控件。当子控件是 Scaffold 时应设为 false，
  /// 避免与 Scaffold 的内建安全区域处理产生双重内边距。
  final bool wrapWithSafeArea;

  const AppBackground({
    super.key,
    required this.child,
    this.isEditor = false,
    this.wrapWithSafeArea = true,
  });

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  File? _cachedBgFile;
  ImageProvider? _cachedImageProvider;
  String? _cachedBgPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCachedImageIfNeeded();
  }

  @override
  void didUpdateWidget(AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateCachedImageIfNeeded();
  }

  void _updateCachedImageIfNeeded() {
    final settings = context.watch<SettingsProvider>();
    final bgPath = settings.backgroundImagePath;
    
    // If path changed or cache is invalid, update the cache
    if (bgPath != _cachedBgPath || _cachedImageProvider == null) {
      _cachedBgPath = bgPath;
      
      if (bgPath != null) {
        final bgFile = File(bgPath);
        if (bgFile.existsSync()) {
          _cachedBgFile = bgFile;
          _cachedImageProvider = FileImage(bgFile);
        } else {
          _cachedBgFile = null;
          _cachedImageProvider = null;
        }
      } else {
        _cachedBgFile = null;
        _cachedImageProvider = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    
    // 判断是否显示粒子效果
    final showParticles =
        settings.particleEnabled && !settings.particleGlobal && !widget.isEditor;
    
    // 粒子效果 Widget
    Widget? particleLayer;
    if (showParticles) {
      particleLayer = Positioned.fill(
        child: IgnorePointer(
          // TickerMode(enabled:true) overrides the route system's ticker-pause
          // so particles keep animating smoothly during route push/pop transitions.
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
          widget.wrapWithSafeArea ? SafeArea(child: widget.child) : widget.child,
          if (particleLayer != null) particleLayer,
        ],
      ),
    );
    
    // Apply background image if set (use cached image provider)
    if (_cachedImageProvider != null) {
      Widget bgImage = Image(
        image: _cachedImageProvider!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );

      final brightness = settings.backgroundBrightness;
      // Skip ColorFiltered when brightness is effectively neutral (1.0),
      // avoiding unnecessary compositing overhead at the default value.
      if ((brightness - 1.0).abs() > 0.001) {
        bgImage = ColorFiltered(
          colorFilter: ColorFilter.matrix([
            brightness, 0, 0, 0, 0,
            0, brightness, 0, 0, 0,
            0, 0, brightness, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: bgImage,
        );
      }
      
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
          widget.wrapWithSafeArea ? SafeArea(child: widget.child) : widget.child,
          // 粒子效果层
          if (particleLayer != null) particleLayer,
        ],
      );
    }
    
    return content;
  }
}
