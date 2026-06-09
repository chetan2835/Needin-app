import 'package:flutter/material.dart';

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key});

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  String? _selectedCategory;
  final TextEditingController _descriptionController = TextEditingController();

  final List<String> _categories = [
    "Journey Tracking Issue",
    "Payment/Earnings Issue",
    "Account Verification",
    "App Bug / Crash",
    "Other",
  ];

  void _submitIssue() {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an issue category')));
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a description of the issue')));
      return;
    }

    // In a real app this would send to backend
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Issue Reported", style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold)),
        content: const Text("Thank you for reporting this issue. Our team will look into it shortly.", style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close page
            },
            child: const Text("OK", style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFFF05A4F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          "Report an Issue",
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "How can we help you?",
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Please provide details about the issue you're facing. Our support team will investigate and get back to you.",
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Issue Category",
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCategory,
                  hint: const Text("Select a category", style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFF94A3B8))),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFF0F172A))),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Description",
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: "Describe the issue in detail...",
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF05A4F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitIssue,
                child: const Text("Submit Issue", style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
