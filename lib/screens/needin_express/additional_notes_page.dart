import 'package:flutter/material.dart';
import 'confirm_post_journey_page.dart';

class AdditionalNotesPage extends StatefulWidget {
  final Map<String, dynamic> journeyData;

  const AdditionalNotesPage({super.key, required this.journeyData});

  @override
  State<AdditionalNotesPage> createState() => _AdditionalNotesPageState();
}

class _AdditionalNotesPageState extends State<AdditionalNotesPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  String? _privacyWarning;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Privacy Detection ──────────────────────────────────────
  void _checkPrivacy(String text) {
    String? warning;

    // Phone number detection (Indian & international patterns)
    final phonePattern = RegExp(r'(\+?\d[\d\s\-]{7,14}\d)');
    if (phonePattern.hasMatch(text)) {
      warning = "⚠️ Phone number detected! For your safety, do not share contact details here.";
    }

    // Email detection
    final emailPattern = RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}');
    if (emailPattern.hasMatch(text)) {
      warning = "⚠️ Email address detected! Please don't share personal email in notes.";
    }

    // Address detection (house/flat/apt numbers, street patterns)
    final addressPattern = RegExp(
      r'(house\s*no|flat\s*no|apt\s*#?|plot\s*no|street\s*no|sector\s*\d|block\s*[a-z]|\d+[a-z]?\s*(st|nd|rd|th)\s*floor)',
      caseSensitive: false,
    );
    if (addressPattern.hasMatch(text)) {
      warning = "⚠️ Specific address detected! Avoid sharing exact home addresses for safety.";
    }

    setState(() {
      _privacyWarning = warning;
    });
  }

  Future<void> _submitJourney() async {
    if (_privacyWarning != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.privacy_tip, color: Color(0xFFF27F0D)),
              SizedBox(width: 8),
              Text("Privacy Warning", style: TextStyle(fontFamily: "Plus Jakarta Sans")),
            ],
          ),
          content: Text(
            _privacyWarning!,
            style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Edit Notes", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF27F0D)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Continue Anyway", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isLoading = true);

    final finalJourneyData = Map<String, dynamic>.from(widget.journeyData);
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      finalJourneyData['additional_notes'] = notes;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ConfirmPostJourneyPage(journeyData: finalJourneyData),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            /// Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: const Color(0xFFFAFAFA).withValues(alpha: 0.95),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      color: Colors.transparent,
                      child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 40),
                      child: Text(
                        "Additional Information",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Plus Jakarta Sans",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// Progress Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Step 10 of 11", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF27F0D))),
                      Text("Almost there", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.90,
                      child: Container(decoration: BoxDecoration(color: const Color(0xFFF27F0D), borderRadius: BorderRadius.circular(3))),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Any notes for the sender?",
                          style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Add any specific details that might help the sender prepare their package.",
                          style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                        ),
                        const SizedBox(height: 24),

                        /// Input Area
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _privacyWarning != null ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                              width: 2,
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Stack(
                            children: [
                              TextField(
                                controller: _notesController,
                                maxLines: 10,
                                minLines: 8,
                                maxLength: 500,
                                style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, color: Color(0xFF0F172A)),
                                decoration: InputDecoration(
                                  hintText: "e.g. I can pick up from the airport, I have extra space for fragile items, or I will be arriving late at night...",
                                  hintStyle: TextStyle(color: const Color(0xFF64748B).withValues(alpha: 0.7)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                  counterText: "",
                                ),
                                onChanged: (text) {
                                  _checkPrivacy(text);
                                  setState(() {});
                                },
                              ),
                              Positioned(
                                bottom: 12,
                                right: 16,
                                child: Text(
                                  "${_notesController.text.length}/500",
                                  style: TextStyle(
                                    fontFamily: "Plus Jakarta Sans",
                                    fontSize: 12,
                                    color: _notesController.text.length > 450 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        /// Privacy Warning (dynamic)
                        if (_privacyWarning != null)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _privacyWarning!,
                                      style: const TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 13, color: Color(0xFFEF4444), height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_privacyWarning == null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF27F0D).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF27F0D).withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning, color: Color(0xFFF27F0D), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text("Privacy Check", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      SizedBox(height: 4),
                                      Text(
                                        "For your safety, do not share your phone number or specific home address in this note. You can exchange contact details after the offer is accepted.",
                                        style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 12, color: Color(0xFF64748B), height: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(color: const Color(0xFFFAFAFA).withValues(alpha: 0.95)),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF27F0D),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFFF27F0D).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
            onPressed: _isLoading ? null : _submitJourney,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Text("Continue", style: TextStyle(fontFamily: "Plus Jakarta Sans", fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ]),
          ),
        ),
      ),
    );
  }
}
