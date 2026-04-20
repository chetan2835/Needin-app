// ══════════════════════════════════════════════════════════════
//  NEEDIN MOTION IDENTITY SYSTEM
//  Reusable brand animations used across:
//  - Splash screen
//  - Button loading states
//  - Page transitions
//  - Shimmer effects
//
//  This creates consistent "brand feel" like Uber/Airbnb
// ══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';

/// Brand color constants for the motion system
class NeedinColors {
  NeedinColors._();

  static const Color primary = Color(0xFFF27F0D);
  static const Color coral = Color(0xFFF27462);
  static const Color deepCoral = Color(0xFFE85D4A);
  static const Color gold = Color(0xFFD4A641);
  static const Color cream = Color(0xFFFFF8F0);
  static const Color darkText = Color(0xFF0F172A);
  static const Color subtleGrey = Color(0xFF64748B);
  static const Color background = Color(0xFFF8F7F5);
}

/// ──────────────────────────────────────────────────────────
///  1. BRAND PULSE — Subtle glow animation for logo/icons
///  Used on: Splash logo, loading indicators
/// ──────────────────────────────────────────────────────────
class NeedinPulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final bool enabled;

  const NeedinPulse({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1800),
    this.minScale = 0.97,
    this.maxScale = 1.03,
    this.enabled = true,
  });

  @override
  State<NeedinPulse> createState() => _NeedinPulseState();
}

class _NeedinPulseState extends State<NeedinPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// ──────────────────────────────────────────────────────────
///  2. SHIMMER SWEEP — Premium shimmer effect across any widget
///  Used on: Logo loading, skeleton screens, text highlights
/// ──────────────────────────────────────────────────────────
class NeedinShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool enabled;

  const NeedinShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
    this.enabled = true,
  });

  @override
  State<NeedinShimmer> createState() => _NeedinShimmerState();
}

class _NeedinShimmerState extends State<NeedinShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Colors.white,
                Color(0x33FFFFFF),
                Colors.white,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// ──────────────────────────────────────────────────────────
///  3. BRAND GLOW — Animated glow/shadow animation
///  Used on: Logo presence, featured cards, CTA buttons
/// ──────────────────────────────────────────────────────────
class NeedinGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final Duration duration;
  final double minBlur;
  final double maxBlur;

  const NeedinGlow({
    super.key,
    required this.child,
    this.color = const Color(0xFFF27F0D),
    this.duration = const Duration(milliseconds: 2200),
    this.minBlur = 20,
    this.maxBlur = 50,
  });

  @override
  State<NeedinGlow> createState() => _NeedinGlowState();
}

class _NeedinGlowState extends State<NeedinGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _blurAnimation = Tween<double>(
      begin: widget.minBlur,
      end: widget.maxBlur,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacityAnimation = Tween<double>(
      begin: 0.15,
      end: 0.35,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _opacityAnimation.value),
                blurRadius: _blurAnimation.value,
                spreadRadius: _blurAnimation.value * 0.3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// ──────────────────────────────────────────────────────────
///  4. FLOATING PARTICLES — Decorative ambient animation
///  Used on: Splash screen background, celebration screens
/// ──────────────────────────────────────────────────────────
class NeedinParticles extends StatefulWidget {
  final int count;
  final Color color;
  final double maxSize;

  const NeedinParticles({
    super.key,
    this.count = 20,
    this.color = const Color(0xFFF27F0D),
    this.maxSize = 6,
  });

  @override
  State<NeedinParticles> createState() => _NeedinParticlesState();
}

class _NeedinParticlesState extends State<NeedinParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _particles = List.generate(widget.count, (_) => _generateParticle());
  }

  _Particle _generateParticle() {
    return _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: _random.nextDouble() * widget.maxSize + 1,
      speed: _random.nextDouble() * 0.15 + 0.05,
      opacity: _random.nextDouble() * 0.4 + 0.1,
      phase: _random.nextDouble() * 2 * pi,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(
            particles: _particles,
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _Particle {
  final double x, y, size, speed, opacity, phase;
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final animY = (p.y - progress * p.speed) % 1.0;
      final wobbleX = sin(progress * 2 * pi + p.phase) * 0.02;
      final x = (p.x + wobbleX) * size.width;
      final y = animY * size.height;

      canvas.drawCircle(
        Offset(x, y),
        p.size,
        Paint()..color = color.withValues(alpha: p.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

/// ──────────────────────────────────────────────────────────
///  5. BRAND PAGE TRANSITION — Smooth fade+slide for Navigator
///  Used on: All page navigations for consistent brand feel
/// ──────────────────────────────────────────────────────────
class NeedinPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  NeedinPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            );
            final slideUp = Tween<Offset>(
              begin: const Offset(0.0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            return FadeTransition(
              opacity: fadeIn,
              child: SlideTransition(position: slideUp, child: child),
            );
          },
        );
}

/// ──────────────────────────────────────────────────────────
///  6. NEEDIN LOADING INDICATOR — Brand-consistent spinner
///  Used on: Buttons, loading states, data fetching
/// ──────────────────────────────────────────────────────────
class NeedinLoader extends StatefulWidget {
  final double size;
  final Color color;

  const NeedinLoader({
    super.key,
    this.size = 24,
    this.color = const Color(0xFFF27F0D),
  });

  @override
  State<NeedinLoader> createState() => _NeedinLoaderState();
}

class _NeedinLoaderState extends State<NeedinLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _NeedinLoaderPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _NeedinLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;

  _NeedinLoaderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Animated arc
    final startAngle = -pi / 2 + progress * 2 * pi;
    final sweepAngle = pi * 0.8 + sin(progress * 2 * pi) * pi * 0.3;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NeedinLoaderPainter old) =>
      old.progress != progress;
}
