// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — BRAND PROTECTED SPLASH SCREEN
//
//  Animation Flow (Strict adherence to Logo constraints):
//  Phase 1 (0–1s):    Logo entry (fade 0→1, scale 0.85→1.0, easeOutCubic)
//  Phase 2 (1–3s):    Float + Breathing (±4px vertical, 1.0→1.03 scale)
//  Phase 3 (Continuous): Rotating energy ring behind logo
//  Phase 4 (Continuous): Star micro-animation pulse
//  Phase 5 (3–4s):    Final scale impact (1.0→1.05, hold 300ms)
//  Phase 6 (4–4.8s):  Crossfade out to destination
//
//  Performance: Native AnimationControllers, 60 FPS, no distortion
// ══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/motion/needin_motion.dart';

class SplashScreen extends StatefulWidget {
  final Widget destination;

  const SplashScreen({super.key, required this.destination});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _entryController;
  late Animation<double> _entryFade;
  late Animation<double> _entryScale;

  late AnimationController _floatController;
  late Animation<double> _floatY;
  late Animation<double> _floatScale;

  late AnimationController _ringController;
  late AnimationController _starController;

  late AnimationController _finaleController;
  late Animation<double> _finaleScale;

  late AnimationController _exitController;
  late Animation<double> _exitFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Phase 1: Entry (0-1s)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    // Phase 2: Float & Life (1-3s)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), 
    );
    _floatY = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
    _floatScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // Phase 3: Energy ring (Continuous)
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Phase 4: Star micro-animation (Continuous)
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Phase 5: Finale Impact (3-4s)
    _finaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _finaleScale = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _finaleController, curve: Curves.easeOutCubic),
    );

    // Phase 6: Exit (4s-)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // 0s: Start Entry
    await Future.delayed(const Duration(milliseconds: 100));
    _entryController.forward();
    
    // 1s: Start Float loop
    await Future.delayed(const Duration(milliseconds: 1000));
    _floatController.repeat(reverse: true);
    
    // 3s: Start Finale
    await Future.delayed(const Duration(milliseconds: 2000));
    _finaleController.forward();
    
    // Hold for 300ms after 700ms animation completion
    await Future.delayed(const Duration(milliseconds: 1000));

    // 4s: Exit crossfade
    _exitController.forward();
    
    await Future.delayed(const Duration(milliseconds: 600));
    _navigateToDestination();
  }

  void _navigateToDestination() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.destination,
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _floatController.dispose();
    _ringController.dispose();
    _starController.dispose();
    _finaleController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white minimum layout
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _entryController,
            _floatController,
            _ringController,
            _starController,
            _finaleController,
            _exitController,
          ]),
          builder: (context, child) {
            
            // Calculate composed scale and translations
            double finaleT = _finaleScale.value / 0.05; // 0.0 -> 1.0
            if (finaleT.isNaN) finaleT = 0.0;
            
            // Starts with entering scale
            double currentScale = _entryScale.value;
            double currentY = 0.0;
            
            // Float is interpolated out linearly as finale kicks in
            double floatScaleContrib = _floatScale.value - 1.0;
            double floatYContrib = _floatY.value;
            
            currentScale += floatScaleContrib * (1.0 - finaleT);
            currentY += floatYContrib * (1.0 - finaleT);
            
            // Add final impact scale
            currentScale += _finaleScale.value;

            return Opacity(
              opacity: _entryFade.value * _exitFade.value,
              child: Transform.translate(
                offset: Offset(0, currentY),
                child: Transform.scale(
                  scale: currentScale,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // ── Phase 3: Energy glow ring behind logo
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Transform.rotate(
                          angle: _ringController.value * 2 * math.pi,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  NeedinColors.coral.withValues(alpha: 0.0),
                                  NeedinColors.coral.withValues(alpha: 0.2),
                                  NeedinColors.gold.withValues(alpha: 0.1),
                                  NeedinColors.coral.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.4, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // ── Phase 1/2/5: Exact Logo Asset (Unmodified)
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: Image.asset(
                          'assets/images/needin logo.jpeg',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      
                      // ── Phase 4: Star Micro-animation
                      // Correctly positioned over the star inside the 180x180 logo
                      // The star is approx at top 25%, centered horizontally.
                      Positioned(
                        top: 38,
                        child: Opacity(
                          opacity: 0.4 + (_starController.value * 0.4),
                          child: Container(
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: NeedinColors.gold.withValues(alpha: 0.15),
                              boxShadow: [
                                BoxShadow(
                                  color: NeedinColors.gold.withValues(alpha: 0.6),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
