import 'package:flutter/material.dart';
import 'main_tab_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _agreed = false;

  void _onEnterApp() {
    if (_agreed) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => MainTabPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Terms of Service and Privacy Policy first',
          ),
        ),
      );
    }
  }

  void _openTerms() {
    Navigator.pushNamed(context, '/terms');
  }

  void _openPrivacy() {
    Navigator.pushNamed(context, '/privacy');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/Image/welcome_bg_2025_5_15.png',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withOpacity(0.25)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/Image/applogo_2025_5_15.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'JoyVibe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: _onEnterApp,
                      child: const Text(
                        'Enter APP',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (v) {
                          setState(() {
                            _agreed = v ?? false;
                          });
                        },
                        activeColor: Colors.pinkAccent,
                      ),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'I have read and agree ',
                              style: TextStyle(color: Colors.white),
                            ),
                            GestureDetector(
                              onTap: _openTerms,
                              child: const Text(
                                'Terms of Service',
                                style: TextStyle(
                                  color: Colors.pinkAccent,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const Text(
                              ' and ',
                              style: TextStyle(color: Colors.white),
                            ),
                            GestureDetector(
                              onTap: _openPrivacy,
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: Colors.pinkAccent,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
