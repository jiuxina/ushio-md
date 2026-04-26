// ============================================================================
// 粒子效果组件
// 
// 实现多种粒子动画效果，包括：
// - 🌸 樱花（sakura）- 粉色花瓣飘落，带旋转和摇摆
// - 🌧️ 下雨（rain）- 斜向下落的雨滴
// - ✨ 萤火虫（firefly）- 黄绿色光点，缓慢飘动带闪烁
// - ❄️ 雪花（snow）- 白色雪花缓慢飘落
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';

/// 粒子数据类
class Particle {
  double x;           // X 位置 (0-1 相对位置)
  double y;           // Y 位置 (0-1 相对位置)
  double size;        // 粒子大小
  double speed;       // 下落速度
  double angle;       // 旋转角度
  double wobble;      // 摇摆偏移
  double opacity;     // 透明度
  double phase;       // 相位（用于周期动画）
  Color color;        // 粒子颜色

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    this.angle = 0,
    this.wobble = 0,
    this.opacity = 1,
    this.phase = 0,
    this.color = Colors.white,
  });
}

/// 粒子效果组件
/// 
/// 使用 CustomPainter 和 Ticker 驱动粒子动画
class ParticleEffectWidget extends StatefulWidget {
  /// 粒子类型：sakura/rain/firefly/snow
  final String particleType;
  
  /// 粒子速率 (0.1-3.0)
  final double speed;
  
  /// 是否启用
  final bool enabled;
  
  /// 粒子数量倍数 (0.25-2.0)
  final double count;
  
  /// 粒子大小倍数 (0.5-2.0)
  final double size;
  
  /// 粒子透明度 (0.1-1.0)
  final double opacity;
  
  /// 风向 (-1.0 到 1.0)
  final double wind;

  const ParticleEffectWidget({
    super.key,
    required this.particleType,
    this.speed = 1.0,
    this.enabled = true,
    this.count = 1.0,
    this.size = 1.0,
    this.opacity = 1.0,
    this.wind = 0.0,
  });

  @override
  State<ParticleEffectWidget> createState() => _ParticleEffectWidgetState();
}

class _ParticleEffectWidgetState extends State<ParticleEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();
  
  // 粒子数量配置（基础值）
  static const Map<String, int> _baseParticleCounts = {
    'sakura': 30,
    'rain': 100,
    'firefly': 25,
    'snow': 60,
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.addListener(_updateParticles);
    
    if (widget.enabled) {
      _initParticles();
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ParticleEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 效果类型、数量或启用状态变化时重新初始化
    if (oldWidget.particleType != widget.particleType ||
        oldWidget.count != widget.count ||
        oldWidget.enabled != widget.enabled) {
      _particles.clear();
      if (widget.enabled) {
        _initParticles();
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      } else {
        _controller.stop();
      }
    }
  }

  /// 初始化粒子
  void _initParticles() {
    final baseCount = _baseParticleCounts[widget.particleType] ?? 30;
    final count = (baseCount * widget.count).round();
    
    for (int i = 0; i < count; i++) {
      _particles.add(_createParticle(randomY: true));
    }
  }

  /// 创建单个粒子
  Particle _createParticle({bool randomY = false}) {
    switch (widget.particleType) {
      case 'sakura':
        return _createSakuraParticle(randomY: randomY);
      case 'rain':
        return _createRainParticle(randomY: randomY);
      case 'firefly':
        return _createFireflyParticle(randomY: randomY);
      case 'snow':
        return _createSnowParticle(randomY: randomY);
      default:
        return _createSakuraParticle(randomY: randomY);
    }
  }

  /// 创建樱花粒子
  Particle _createSakuraParticle({bool randomY = false}) {
    final baseOpacity = 0.6 + _random.nextDouble() * 0.4;
    return Particle(
      x: _random.nextDouble(),
      y: randomY ? _random.nextDouble() : -0.1,
      size: (8 + _random.nextDouble() * 8) * widget.size,
      speed: 0.3 + _random.nextDouble() * 0.3,
      angle: _random.nextDouble() * 2 * pi,
      wobble: _random.nextDouble() * 2 * pi,
      opacity: baseOpacity * widget.opacity,
      phase: _random.nextDouble() * 2 * pi,
      color: Color.lerp(
        const Color(0xFFFFB7C5),  // 淡粉
        const Color(0xFFFF69B4),  // 热粉
        _random.nextDouble(),
      )!,
    );
  }

  /// 创建雨滴粒子
  Particle _createRainParticle({bool randomY = false}) {
    final baseOpacity = 0.3 + _random.nextDouble() * 0.4;
    return Particle(
      x: _random.nextDouble(),
      y: randomY ? _random.nextDouble() : -0.1,
      size: (2 + _random.nextDouble() * 3) * widget.size,
      speed: 1.5 + _random.nextDouble() * 1.0,
      angle: 0.15, // 雨滴倾斜角度
      opacity: baseOpacity * widget.opacity,
      color: const Color(0xFF87CEEB).withValues(alpha: 0.6),
    );
  }

  /// 创建萤火虫粒子
  Particle _createFireflyParticle({bool randomY = false}) {
    final baseOpacity = 0.4 + _random.nextDouble() * 0.6;
    return Particle(
      x: _random.nextDouble(),
      y: randomY ? _random.nextDouble() : _random.nextDouble(),
      size: (3 + _random.nextDouble() * 4) * widget.size,
      speed: 0.1 + _random.nextDouble() * 0.15,
      angle: _random.nextDouble() * 2 * pi,
      phase: _random.nextDouble() * 2 * pi,
      opacity: baseOpacity * widget.opacity,
      color: Color.lerp(
        const Color(0xFF9ACD32),  // 黄绿
        const Color(0xFFADFF2F),  // 荧光绿
        _random.nextDouble(),
      )!,
    );
  }

  /// 创建雪花粒子
  Particle _createSnowParticle({bool randomY = false}) {
    final baseOpacity = 0.5 + _random.nextDouble() * 0.5;
    return Particle(
      x: _random.nextDouble(),
      y: randomY ? _random.nextDouble() : -0.1,
      size: (3 + _random.nextDouble() * 5) * widget.size,
      speed: 0.2 + _random.nextDouble() * 0.3,
      wobble: _random.nextDouble() * 2 * pi,
      phase: _random.nextDouble() * 2 * pi,
      opacity: baseOpacity * widget.opacity,
      color: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_updateParticles);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return CustomPaint(
      painter: ParticlePainter(
        particles: _particles,
        particleType: widget.particleType,
        repaint: _controller,
      ),
      size: Size.infinite,
    );
  }

  /// 更新粒子位置
  void _updateParticles() {
    final dt = 0.016 * widget.speed; // 约 60fps
    final windEffect = widget.wind * 0.003; // 风向影响

    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      
      switch (widget.particleType) {
        case 'sakura':
          _updateSakuraParticle(p, dt, windEffect);
          break;
        case 'rain':
          _updateRainParticle(p, dt, windEffect);
          break;
        case 'firefly':
          _updateFireflyParticle(p, dt, windEffect);
          break;
        case 'snow':
          _updateSnowParticle(p, dt, windEffect);
          break;
      }

      // 重置超出边界的粒子
      if (_shouldResetParticle(p)) {
        _particles[i] = _createParticle();
      }
    }
  }

  bool _shouldResetParticle(Particle p) {
    if (widget.particleType == 'firefly') {
      // 萤火虫在边界反弹，不重置
      return false;
    }
    return p.y > 1.1 || p.x < -0.1 || p.x > 1.1;
  }

  void _updateSakuraParticle(Particle p, double dt, double windEffect) {
    p.y += p.speed * dt;
    p.wobble += dt * 2;
    p.x += sin(p.wobble) * 0.002 + windEffect;
    p.angle += dt * 0.5;
  }

  void _updateRainParticle(Particle p, double dt, double windEffect) {
    p.y += p.speed * dt;
    p.x += p.angle * dt * 0.3 + windEffect; // 水平偏移 + 风向
  }

  void _updateFireflyParticle(Particle p, double dt, double windEffect) {
    p.phase += dt * 3;
    // 随机漂浮
    p.x += sin(p.phase) * 0.002 + windEffect * 0.3;
    p.y += cos(p.phase * 0.7) * 0.001;
    // 闪烁效果
    p.opacity = (0.3 + sin(p.phase * 2) * 0.35 + 0.35) * widget.opacity;
    
    // 边界反弹
    if (p.x < 0) p.x = 0;
    if (p.x > 1) p.x = 1;
    if (p.y < 0) p.y = 0;
    if (p.y > 1) p.y = 1;
  }

  void _updateSnowParticle(Particle p, double dt, double windEffect) {
    p.y += p.speed * dt;
    p.wobble += dt * 1.5;
    p.x += sin(p.wobble) * 0.001 + windEffect;
  }
}

/// 粒子绘制器
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final String particleType;

  ParticlePainter({
    required this.particles,
    required this.particleType,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = p.x * size.width;
      final y = p.y * size.height;

      switch (particleType) {
        case 'sakura':
          _drawSakura(canvas, x, y, p);
          break;
        case 'rain':
          _drawRain(canvas, x, y, p, size.height);
          break;
        case 'firefly':
          _drawFirefly(canvas, x, y, p);
          break;
        case 'snow':
          _drawSnow(canvas, x, y, p);
          break;
      }
    }
  }

  void _drawSakura(Canvas canvas, double x, double y, Particle p) {
    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(p.angle);

    // 绘制花瓣形状（椭圆组合）
    final path = Path();
    path.addOval(Rect.fromCenter(
      center: Offset.zero,
      width: p.size,
      height: p.size * 0.6,
    ));
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  void _drawRain(Canvas canvas, double x, double y, Particle p, double height) {
    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..strokeWidth = p.size * 0.5
      ..strokeCap = StrokeCap.round;

    final length = p.size * 8;
    final dx = sin(p.angle) * length;
    final dy = cos(p.angle) * length;

    canvas.drawLine(
      Offset(x, y),
      Offset(x + dx, y + dy),
      paint,
    );
  }

  void _drawFirefly(Canvas canvas, double x, double y, Particle p) {
    // 外发光
    final glowPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(x, y), p.size * 2, glowPaint);

    // 核心光点
    final corePaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), p.size, corePaint);
  }

  void _drawSnow(Canvas canvas, double x, double y, Particle p) {
    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;

    // 简单圆形雪花
    canvas.drawCircle(Offset(x, y), p.size, paint);

    // 添加十字装饰
    final linePaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.5)
      ..strokeWidth = 1;
    
    canvas.drawLine(
      Offset(x - p.size, y),
      Offset(x + p.size, y),
      linePaint,
    );
    canvas.drawLine(
      Offset(x, y - p.size),
      Offset(x, y + p.size),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return true;
  }
}
