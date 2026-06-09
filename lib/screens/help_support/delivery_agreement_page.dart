import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryAgreementPage extends StatefulWidget {
  const DeliveryAgreementPage({super.key});

  @override
  State<DeliveryAgreementPage> createState() => _DeliveryAgreementPageState();
}

class _DeliveryAgreementPageState extends State<DeliveryAgreementPage> {
  bool _isAccepted = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAcceptanceStatus();
  }

  Future<void> _loadAcceptanceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAccepted = prefs.getBool('delivery_agreement_accepted') ?? false;
    });
  }

  Future<void> _saveAcceptance() async {
    if (!_isAccepted) return;
    
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('delivery_agreement_accepted', true);
    
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Delivery Agreement accepted successfully."),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
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
          "Delivery Agreement",
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Text(
                  """NEEDIN EXPRESS – DELIVERY USER AGREEMENT 
This Delivery User Agreement (“Agreement”) is entered into between: 
Company 
AND 
User 
Any individual registering on and using the Needin mobile application to avail Needin Express delivery services 
(hereinafter referred to as the “User”). 

1. Purpose 
Needin Express is a technology-enabled delivery facilitation service that connects Users with independent delivery partners for travel-based, same-day or time-bound deliveries. 
The Company does not itself provide delivery services. 

2. Platform Role 
The Company acts solely as a facilitator and technology platform. Delivery services are performed by independent delivery partners. Nothing in this Agreement creates an employer-employee, agency, partnership, or joint-venture relationship between the Company and any delivery partner. 

3. Eligibility 
Users must be 18 years of age or older and legally capable of entering into a binding contract under Indian law to use Needin Express. 

4. User Responsibilities 
The User agrees to: 
• Provide accurate pickup and delivery details; 
• Ensure safe, secure, and proper packaging of parcels; 
• Be available (or ensure availability) at pickup and delivery locations at the scheduled time; 
• Comply with all applicable laws and regulations. 

4.A – Packaging Responsibility & Proof (Evidence of Packaging) 
Proof of Packaging Condition 
The User acknowledges and agrees that proper and secure packaging of the parcel is solely the responsibility of the User. To ensure transparency and avoid disputes, the Company reserves the right to capture photographic evidence of the parcel at the time of pickup through its delivery partner. 
Such photographs may include images of the outer packaging, seals, and visible condition of the parcel at the time of pickup. These photographs shall be treated as valid evidence of the parcel’s apparent external condition at the time of handover. 
In the event of any claim, complaint, or dispute regarding damage, leakage, or breakage of the contents, such photographic evidence shall be relied upon to determine whether the parcel was externally intact at the time of pickup. The Company shall not be held liable for damages arising from inadequate, improper, or defective packaging by the User. 

5. Permitted & Prohibited Items 
Permitted Items 
Only legal, safe, and non-restricted items may be sent. 
Prohibited Items 
The User shall not send: 
• Illegal, hazardous, flammable, explosive, or narcotic substances; 
• Cash, jewellery, precious metals/stones, or high-value items; 
• Restricted goods under applicable laws. 
The User bears full responsibility for parcel contents and declarations. 

6. No Inspection & Declaration 
The Company and delivery partners do not inspect parcel contents. The User warrants that all declarations are true and lawful and indemnifies the Company against violations. 

6.A – No Inspection & Right to Refuse Suspicious Parcels 
No Inspection of Contents & Right to Refuse Suspicious Parcels 
The Company and its delivery partners do not open, inspect, or verify the internal contents of any parcel. However, the delivery partner shall have the absolute right to refuse pickup of any parcel that appears suspicious, unsafe, illegal, or hazardous based on external observation. 
This includes, but is not limited to, parcels showing signs of leakage, unusual odor, abnormal sounds, improper sealing, damaged packaging, or any indication of prohibited, illegal, or dangerous items. 
Such refusal shall be deemed a preventive safety measure and shall not be considered a breach of service. The Company shall not be liable for any loss, delay, or inconvenience arising from refusal of such parcels, and the User shall bear full responsibility for ensuring that the parcel complies with applicable laws and safety standards.

7. Delivery Timelines 
Pickup and delivery timelines shown in the App are estimates only and not guaranteed. 
Delays may occur due to traffic, weather, technical issues, or other factors beyond control. 

8. Charges & Payments 
• Delivery charges are calculated based on distance, parcel characteristics, and applicable platform fees; 
• Payments must be completed successfully before a delivery request is processed; 
• Delivery charges are generally non-refundable, unless expressly stated or required by law. 

9. Cancellation 
• Once a parcel has been picked up, cancellation is not permitted; 
• If a User cancels prior to pickup, applicable charges may apply as displayed in the App. 

10. Recipient Unavailability 
If the recipient is unavailable: 
• Reattempt or return charges may apply; 
• The User shall bear any additional costs incurred. 

11. No Insurance 
Parcels sent via Needin Express are not insured by default. Users are advised not to send high-value or sensitive items. 

12. Limitation of Liability 
To the maximum extent permitted by law: 
• The Company shall not be liable for loss, damage, theft, delay, or non-delivery of parcels; 
• The Company shall not be liable for indirect, incidental, or consequential damages. 

13. Force Majeure 
The Company shall not be liable for failure or delay caused by events beyond reasonable control, including natural disasters, government actions, strikes, network failures, or technical issues. 

14. Data Privacy 
User data shall be collected and processed in accordance with the Company’s Privacy Policy. 

15. Account Actions 
The Company reserves the right to suspend or terminate User access for violations of this Agreement, misuse, or unlawful activity. 

16. Modifications 
The Company may modify this Agreement from time to time. Continued use of Needin Express constitutes acceptance of the updated Agreement. 

17. Governing Law & Jurisdiction 
This Agreement shall be governed by the laws of India. Courts at Meerut, Uttar Pradesh shall have exclusive jurisdiction. 

17.A Delivery Partner / Traveller Declaration  
The Delivery Partner / Traveller hereby clearly confirms that: 
• He/She is already travelling on the route displayed in the application; 
• Carrying the parcel will not require any additional travel, special route, or separate trip; 
• Needin Express only provides a travel-based parcel connection facility and does not require or compel any Delivery Partner to undertake an additional journey. 
This declaration shall be mandatorily made by accepting the checkbox provided in the application.  

18. Acceptance 
By creating a profile or continuing to use the Needin App, the User confirms that they have read, understood, and accepted this Agreement along with the Terms & Conditions and Privacy Policy of the Company.""",
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _isAccepted,
                      onChanged: (bool? value) {
                        setState(() {
                          _isAccepted = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFFF05A4F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    const Expanded(
                      child: Text(
                        "I have read and agree to the Delivery User Agreement.",
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF05A4F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                    ),
                    onPressed: _isAccepted ? _saveAcceptance : null,
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Accept & Continue", style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
