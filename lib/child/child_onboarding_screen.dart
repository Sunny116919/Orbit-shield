

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:orbit_shield/child/child_auth_wrapper.dart';

class ChildOnboardingScreen extends StatefulWidget {
  const ChildOnboardingScreen({super.key});

  @override
  State<ChildOnboardingScreen> createState() => _ChildOnboardingScreenState();
}

class _ChildOnboardingScreenState extends State<ChildOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isAccepted = false;

  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Stay Connected",
      "body":
          "This app helps your parents keep you safe while you explore the internet.",
      "icon": Icons.sentiment_satisfied_alt_rounded,
      "color": const Color(0xFF0F766E),
    },
    {
      "title": "In Case of Emergency",
      "body":
          "Use the SOS button to instantly alert your parents if you feel unsafe.",
      "icon": Icons.sos_rounded,
      "color": const Color(0xFFEF4444), 
    },
    {
      "title": "Healthy Habits",
      "body": "Balance your screen time and focus on what matters most.",
      "icon": Icons.hourglass_bottom_rounded,
      "color": const Color(0xFF0F766E),
    },
    {
      "title": "Device Monitoring",
      "body": "Transparency is key. Please understand how this app works.",
      "icon": Icons.visibility_rounded,
      "color": const Color(0xFF0D9488),
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
      await prefs.setBool('child_onboarding_seen', true);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChildAuthWrapper()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Acknowledgement is required to proceed."),
        ),
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
                      onPressed: _isAccepted ? _finishOnboarding : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages.last['color'],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text("Allow & Continue"),
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
          Icon(Icons.info_outline_rounded, size: 60, color: data['color']),
          const SizedBox(height: 20),
          Text(
            "Transparency Notice",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: data['color'],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "This app is designed for parental supervision.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4), 
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Text(
                  "By continuing, you acknowledge that this device's location, app usage, and screen time will be visible to the linked Parent account.",
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            title: const Text(
              "I understand and consent to this monitoring.",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
}
