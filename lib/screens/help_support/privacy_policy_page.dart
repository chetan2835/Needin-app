import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          "Privacy Policy",
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
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            """PRIVACY POLICY – NEEDIN APP 
Operated by Viec Carry India Pvt Ltd 

This Privacy Policy describes how Viec Carry India Pvt Ltd (“Company”, “we”, “our”, or “us”) collects, uses, processes, stores, and protects personal information when you access or use the Needin mobile application (“App”). 

By downloading, registering, accessing, or using the Needin App, you agree to the collection and use of information in accordance with this Privacy Policy. 

This Privacy Policy applies to all services offered through the Needin App, including: 
• Needin Services 
• Needin Express (travel-based same-day delivery services) 

1. Information We Collect 
a) Personal Information 
We may collect the following personal information: 
• Full name 
• Mobile number 
• Email address 
• Pickup and delivery addresses 
• Profile details provided by the user 

b) Identity Verification & KYC Information 
For safety, trust, fraud prevention, and legal compliance, we may collect: 
• Mobile number verification 
• Email verification 
• Aadhaar verification through DigiLocker or other authorized government platforms (only when legally required) 
• Face video recording, selfie, or image capture for identity verification and security checks 

Important: 
Aadhaar details are not stored by the Company unless legally required and are processed securely through authorized verification service providers. 

c) Location Information 
We may collect: 
• Real-time location data for pickup, delivery, navigation, and service facilitation 
• Background location data only during active service execution, tracking, safety, and delivery completion 
Location data is collected strictly for service-related purposes and is disabled once the service is completed. 

d) Transaction Information 
We may collect: 
• Order and service request details 
• Pickup and delivery information 
• Payment status and transaction reference IDs 
We do not store card details, bank account information, or UPI credentials. 

e) Device & Technical Information 
We may automatically collect: 
• Device type, model, and identifiers 
• Operating system and app version 
• IP address 
• Log files, usage statistics, and crash reports 

2. How We Use Your Information 
We use collected information to: 
• Provide, operate, and manage Needin services 
• Connect users with vendors and delivery partners 
• Verify identity and prevent fraud, fake accounts, or misuse 
• Enable secure onboarding and KYC verification 
• Process orders, deliveries, and payments 
• Improve app performance, safety, and user experience 
• Send OTPs, alerts, service updates, and notifications 
• Comply with legal, regulatory, and law-enforcement requirements 

3. User Consent & Lawful Processing 
By using the Needin App, users provide explicit consent for the collection, processing, and usage of their personal data. 
Users may withdraw consent at any time by: 
• Disabling app permissions, or 
• Requesting account deletion 
Withdrawal of consent may limit or disable certain app features, subject to legal and regulatory obligations. 

4. App Permissions  
The Needin App may request certain permissions to ensure that services are provided in a safe, reliable, and seamless manner. These permissions include: 
1. Location Permission (Foreground & Background) 
• For pickup, delivery, navigation, and real-time tracking 
• Background location access is used only while a service is actively in progress 
2. Camera & Microphone Permission 
• For identity verification (selfie / face video) 
• For uploading profile images and required documents 
• For customer support and security-related purposes 
3. Storage Permission 
• For uploading profile photos, documents, and other necessary files 
4. Phone Call Permission 
• To enable call connectivity between users, vendors, and delivery partners 
• Call functionality is limited strictly to service-related communication 
• The App does not record any phone calls 
5. SMS Permission 
• For sending and verifying OTPs 
• For service-related alerts and security notifications 
• The App does not read or store users’ personal SMS messages 
All of the above permissions are requested only when necessary and for limited, specific purposes. 
Users may control or revoke these permissions at any time through their device settings. 

5. Sharing of Information 
We may share personal information only when necessary, including with: 
• Vendors to fulfill service requests 
• Delivery partners for pickup and delivery 
• Payment gateway providers for transaction processing 
• Identity verification providers (e.g., DigiLocker, KYC services) 
• Government or legal authorities when required by law 
We do not sell, rent, or trade personal data to third parties. 

6. Vendor & Delivery Partner Data Visibility 
Only the minimum necessary user information is shared with vendors and delivery partners strictly for service fulfillment purposes. 

7. Location Data Usage 
Location data is used solely to: 
• Enable pickup and delivery services 
• Improve route accuracy and service efficiency 
• Provide real-time tracking and safety features 
Location data is never used for advertising purposes and is never sold. 

8. Cookies & Tracking Technologies 
The Needin App and website may use cookies, SDKs, pixels, and similar tracking technologies to enhance user experience, improve performance, analyze usage patterns, and ensure security. 
Cookies and tracking technologies may be used to: 
• Remember user preferences and login sessions 
• Analyze app and website traffic 
• Monitor performance, crashes, and errors 
• Improve service efficiency and reliability 
Users can control or disable cookies through their device or browser settings. However, disabling cookies may affect certain features or functionality of the App or website. 
We do not use cookies for unauthorized advertising purposes and do not sell cookie-based data to third parties. 

9. Analytics & Performance Monitoring 
We may use analytics and crash reporting tools to understand how users interact with the App and to improve service quality. These tools collect aggregated and anonymized data and do not allow us to personally identify users. 

10. Data Security 
We implement reasonable technical, administrative, and organizational safeguards to protect personal data from unauthorized access, loss, misuse, or alteration. 
However, no digital system is completely secure, and absolute security cannot be guaranteed. 

11. Data Retention 
User data is retained only for as long as necessary to: 
• Provide and improve services 
• Complete verification and compliance requirements 
• Meet legal, accounting, or regulatory obligations 
Data may be deleted or anonymized when no longer required or upon valid user request, subject to legal requirements. 

12. User Rights 
Users have the right to: 
• Access their personal information 
• Request correction of inaccurate or incomplete data 
• Request account and data deletion (subject to legal obligations) 
Deletion requests are processed within a reasonable time unless retention is required by law. 

13. Automated Decision-Making & Profiling 
The Company does not use personal data for automated decision-making or profiling that produces legal or similarly significant effects on users. 

14. Third-Party Services 
The Needin App may integrate with third-party services such as payment gateways, analytics tools, and identity verification providers. 
The Company is not responsible for the privacy practices of third-party platforms. Users are encouraged to review their respective privacy policies. 

15. International Data Processing 
Some data may be processed or stored on secure servers located outside India, subject to appropriate safeguards and in compliance with applicable data protection laws. 

16. Children’s Privacy 
The Needin App is intended only for users who are 18 years of age or older. 
We do not knowingly collect personal data from minors. 

17. Marketing & Promotional Communication 
Users may receive service-related and promotional communications from the Company. 
Users may opt out of non-essential promotional communications at any time. 

18. Legal Compliance 
The Company complies with applicable Indian laws, including: 
• Digital Personal Data Protection Act, 2023 
• Information Technology Act and applicable rules 

19. Grievance Officer 
In accordance with Indian IT Rules: 
Grievance Officer 
Designation: Grievance Officer 
Email: needinexpress06@gmail.com 
Response Time: Within 7 working days 

20. Changes to This Privacy Policy 
The Company may update this Privacy Policy from time to time. 
Any changes will be effective immediately upon publication on the App or website. 
Continued use of the App constitutes acceptance of the updated policy. 

21. Contact Information 
For any questions or concerns regarding this Privacy Policy, please contact: 
Viec Carry India Pvt Ltd 
Email: needinexpress06@gmail.com 
Website: www.vieccarryindia.com""",
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
