import 'package:flutter/material.dart';
import 'dart:math';
import 'post_journey_page.dart';
import 'my_journeys_page.dart';

class JourneyPostedSuccessPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const JourneyPostedSuccessPage({
    super.key,
    required this.journeyData,
  });

  @override
  State<JourneyPostedSuccessPage> createState() => _JourneyPostedSuccessPageState();
}

class _JourneyPostedSuccessPageState extends State<JourneyPostedSuccessPage>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;

  late AnimationController _textController;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;

  late AnimationController _confettiController;

  late AnimationController _buttonController;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    // Check icon animation
    _checkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _checkScale = CurvedAnimation(parent: _checkController, curve: Curves.elasticOut);

    // Text stagger
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _titleFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _textController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)));
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _textController, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)));

    // Confetti
    _confettiController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

    // Buttons
    _buttonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _buttonFade = CurvedAnimation(parent: _buttonController, curve: Curves.easeOut);

    // Sequence
    _checkController.forward();
    Future.delayed(const Duration(milliseconds: 400), () => _textController.forward());
    Future.delayed(const Duration(milliseconds: 900), () => _buttonController.forward());
  }

  @override
  void dispose() {
    _checkController.dispose();
    _textController.dispose();
    _confettiController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final origin = widget.journeyData['origin'] ?? 'Origin';
    final destination = widget.journeyData['destination'] ?? 'Destination';
    final travelMode = widget.journeyData['travel_mode'] ?? 'Road';
    final departureTime = widget.journeyData['departure_time'];

    String formattedTime = '';
    if (departureTime != null) {
      try {
        final dt = DateTime.parse(departureTime.toString());
        final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        formattedTime = "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
      } catch (_) {
        formattedTime = departureTime.toString();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Stack(
          children: [
            // Animated confetti particles
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _AnimatedConfettiPainter(progress: _confettiController.value),
                );
              },
            ),

            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated check icon
                        ScaleTransition(
                          scale: _checkScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF27F0D).withValues(alpha: 0.1))),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4))],
                                  border: Border.all(color: const Color(0xFFFAFAFA), width: 4),
                                ),
                                child: const Center(child: Icon(Icons.check_circle, color: Color(0xFFF27F0D), size: 60)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Animated title
                        FadeTransition(
                          opacity: _titleFade,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: const Text(
                              "Journey Posted\nSuccessfully!",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Animated subtitle with REAL data
                        FadeTransition(
                          opacity: _subtitleFade,
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, color: Color(0xFF64748B), height: 1.5),
                              children: [
                                const TextSpan(text: "Your journey from "),
                                TextSpan(text: origin, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                const TextSpan(text: " to "),
                                TextSpan(text: destination, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                const TextSpan(text: " is now live and visible to senders."),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Journey summary chips (real data)
                        FadeTransition(
                          opacity: _subtitleFade,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildInfoChip(Icons.directions_car, travelMode),
                              if (formattedTime.isNotEmpty) _buildInfoChip(Icons.calendar_today, formattedTime),
                              if (widget.journeyData['distance_km'] != null)
                                _buildInfoChip(Icons.straighten, "${(widget.journeyData['distance_km'] as num).toStringAsFixed(0)} km"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Animated buttons
                FadeTransition(
                  opacity: _buttonFade,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF27F0D),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 6,
                            shadowColor: const Color(0xFFF27F0D).withValues(alpha: 0.4),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const MyJourneysPage()),
                              (route) => route.isFirst,
                            );
                          },
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                            Text("View My Journeys", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            minimumSize: const Size(double.infinity, 56),
                            side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const PostJourneyPage()),
                              (route) => route.isFirst,
                            );
                          },
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                            Icon(Icons.add),
                            SizedBox(width: 8),
                            Text("Post Another Journey", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: const Color(0xFFF27F0D)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      ]),
    );
  }
}

class _AnimatedConfettiPainter extends CustomPainter {
  final double progress;
  _AnimatedConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(42);
    final colors = [
      const Color(0xFFF27F0D),
      const Color(0xFFFCD34D),
      const Color(0xFFF27F0D).withValues(alpha: 0.6),
      const Color(0xFFFFB347),
    ];

    for (int i = 0; i < 50; i++) {
      final baseX = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * (size.height * 0.7);
      final sizeFactor = rand.nextDouble();
      final color = colors[rand.nextInt(colors.length)];
      final speed = 0.5 + rand.nextDouble() * 1.5;
      final phase = rand.nextDouble() * pi * 2;

      final x = baseX + sin(progress * 2 * pi * speed + phase) * 15;
      final y = (baseY + progress * size.height * 0.3 * speed) % (size.height * 0.7);

      final paint = Paint()..color = color.withValues(alpha: 0.12 + sizeFactor * 0.08);

      if (rand.nextBool()) {
        canvas.drawCircle(Offset(x, y), 3 + 4 * sizeFactor, paint);
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * pi * 2 + phase);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 6 + 5 * sizeFactor, height: 6 + 5 * sizeFactor), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedConfettiPainter old) => old.progress != progress;
}
