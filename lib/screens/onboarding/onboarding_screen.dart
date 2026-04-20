import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/login_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

  final PageController controller = PageController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  int pageIndex = 0;

  List<Map<String, String>> data = [
    {
      "image":
          "https://lh3.googleusercontent.com/aida-public/AB6AXuBoQd6VfjZkWp5Ylf-7UZj-Zaj9wgU925X4vGjbnSMiJal1D1VFPBXb2WiillehGMAlMkceqZS1BsKz1dGb3wibblDF2ZgMPArCenBFVpMotTdRi1cU1PnifIqNCVBTJUS3b86mzl8DltUISk9QtweLPM9yN8kIzIaPTyUnRdxz7FHwT2fvJpoNngXgE9hxaamaYYSqcNMiwE8HK5OXkKSXWhH5LGrSci-E8SPOpV1TIorx_kz6QCUzu72UNoS1JeIUq29dbJ0U7w",
      "title": "Travel and Earn",
      "desc":
          "Turn your journeys into earnings by delivering parcels along your route."
    },
    {
      "image":
          "https://lh3.googleusercontent.com/aida-public/AB6AXuCCKr1EYMnMt2qGL7HQcbJM2HkG07KTD31OLCjLCjvoxn1_5zjlpmNiXq6K5ndgt8C0UDMg9MokZdH0WJRtpukaxR920uhwnOMF-kLv2ewbaA2QJQJh7H25P74peuM5y2oi_hCJHp1Nnkb8-qkmFNP4Im6VMEtveGyM-YjWpDae6QsyQ8tFruFgfxhG53dhBrK4amhpqBj1sWb8_q-yrdU1_sqUEcr4lR7_bJncwKH_rLCbu0nTOSR1EQQhoqoRQMy5FqmnyVWelg",
      "title": "Reliable Parcel Delivery",
      "desc":
          "Find verified travelers to carry your packages safely and quickly."
    },
    {
      "image":
          "https://lh3.googleusercontent.com/aida-public/AB6AXuDTpWikkQygLVt-YZUtZMTptcKpGmLDjkKxxLb7nyG4G3eVlDSmPj2PqIr7BExIp5XFolLryzaEcIN5skKaZj3ss6aa13koBOOF7su-iJdol8gh4yIfplpQgBk_q-op8NDvt53UxPxJMdVhcwd3pTTibYE8RCrw5P-ETgrw8Q_1qrcgGT-d53vGbwUM6Sy9yUvqxAJjjsuCBPrfaVcT9CYL67DPjN_UMrMaO8E2j9Xd52emcJ_sZZ99SQSl1v-egLe_CkYsYAX3UQ",
      "title": "Secure & Verified",
      "desc":
          "Every traveler and sender is verified to ensure a safe community."
    },
  ];

  void finishOnboarding() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("seenOnboarding", true);

    if (!mounted) return;

    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            /// SKIP BUTTON
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: finishOnboarding,
                child: const Text("Skip",
                    style: TextStyle(color: Color(0xfff27f0d))),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: controller,
                itemCount: data.length,
                onPageChanged: (index) {
                  setState(() => pageIndex = index);
                },
                itemBuilder: (_, index) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        Image.network(data[index]["image"]!, height: 280),

                        const SizedBox(height: 30),

                        Text(
                          data[index]["title"]!,
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          data[index]["desc"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            /// DOTS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  data.length,
                  (index) => Container(
                        margin: const EdgeInsets.all(4),
                        height: 8,
                        width: pageIndex == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: pageIndex == index
                              ? const Color(0xfff27f0d)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                      )),
            ),

            const SizedBox(height: 20),

            /// NEXT BUTTON
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff27f0d),
                  ),
                  onPressed: () {

                    if (pageIndex == data.length - 1) {
                      finishOnboarding();
                    } else {
                      controller.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.ease);
                    }
                  },
                  child: Text(
                    pageIndex == data.length - 1 ? "Get Started" : "Next",
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}