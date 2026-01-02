import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:orbit_shield/parent/auth_wrapper.dart'; 

class ParentOnboardingScreen extends StatefulWidget {
  const ParentOnboardingScreen({super.key});

  @override
  State<ParentOnboardingScreen> createState() => _ParentOnboardingScreenState();
}

class _ParentOnboardingScreenState extends State<ParentOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isAccepted = false; 

  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Real-Time Monitoring",
      "body":
          "Keep track of your child's digital activities and ensure they are safe online.",
      "icon": Icons.remove_red_eye_rounded,
      "color": const Color(0xFF1E3A8A),
    },
    {
      "title": "Location Tracking",
      "body":
          "Know exactly where your child is at any moment with precise GPS updates.",
      "icon": Icons.location_on_rounded,
      "color": const Color(0xFF2563EB),
    },
    {
      "title": "App & Web Control",
      "body":
          "Block harmful content and limit screen time to build healthy habits.",
      "icon": Icons.block_rounded,
      "color": const Color(0xFF3B82F6),
    },
    {
      "title": "Legal Acknowledgement", 
      "body":
          "Strict privacy rules apply. You must confirm your authority to use this tool.",
      "icon": Icons.verified_user_rounded,
      "color": const Color(0xFF1E40AF),
    },
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _finishOnboarding() async {
    if (_isAccepted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('parent_onboarding_seen', true);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please accept the terms to proceed.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final data = _pages[index];
                  if (index == _pages.length - 1) {
                    return _buildConsentPage(data);
                  }
                  return _buildInfoPage(data);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 5),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _pages[_currentPage]['color']
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  if (_currentPage == _pages.length - 1)
                    ElevatedButton(
                      onPressed: _isAccepted
                          ? _finishOnboarding
                          : null, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages.last['color'],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text("Get Started"),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text("Next"),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPage(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 80,
            backgroundColor: data['color'].withOpacity(0.1),
            child: Icon(data['icon'], size: 80, color: data['color']),
          ),
          const SizedBox(height: 40),
          Text(
            data['title'],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: data['color'],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data['body'],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentPage(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gavel_rounded, size: 60, color: data['color']),
          const SizedBox(height: 20),
          Text(
            "Legal Acknowledgement",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: data['color'],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "To use Orbit Shield, you must confirm that:",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBullet(
                  "I am the legal guardian of the child using the target device.",
                ),
                _buildBullet(
                  "I have the legal right to monitor the target device.",
                ),
                _buildBullet(
                  "I understand unauthorized surveillance is a violation of privacy laws.",
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            title: const Text(
              "I acknowledge and agree to the Terms of Service and Privacy Policy.",
              style: TextStyle(fontSize: 13),
            ),
            value: _isAccepted,
            onChanged: (val) {
              setState(() {
                _isAccepted = val ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: data['color'],
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
