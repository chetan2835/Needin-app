import 'package:flutter/material.dart';

class RouteDetailsPage extends StatefulWidget {
  const RouteDetailsPage({super.key});

  @override
  State<RouteDetailsPage> createState() => _RouteDetailsPageState();
}

class _RouteDetailsPageState extends State<RouteDetailsPage> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destController = TextEditingController();

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF181410)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Route Details",
          style: TextStyle(
            fontFamily: "Inter",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF181410),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Where are you travelling?",
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF181410),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Tell us your origin and destination to find matching parcels on your route.",
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontSize: 14,
                        color: Color(0xFF6B5E52),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildInputLabel("Origin"),
                    const SizedBox(height: 8),
                    _buildTextField(_originController, "E.g., Mumbai, Maharashtra", Icons.my_location),
                    const SizedBox(height: 24),
                    _buildInputLabel("Destination"),
                    const SizedBox(height: 8),
                    _buildTextField(_destController, "E.g., Pune, Maharashtra", Icons.location_on),
                    const SizedBox(height: 24),
                    _buildInputLabel("Date of Travel"),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: const Text(
                          "Select Date",
                          style: TextStyle(fontFamily: "Inter", color: Color(0xFF6B5E52)),
                        ),
                        trailing: const Icon(Icons.calendar_today, color: Color(0xFFFF8000)),
                        onTap: () async {
                          await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8000),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Navigate to map preview or next step
                },
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: "Inter",
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF181410),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontFamily: "Inter", fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, color: const Color(0xFF6B5E52)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF8000), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
