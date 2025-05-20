import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            'Privacy Policy\n\n'
            '1. Introduction\n'
            'This Privacy Policy explains how JoyVibe collects, uses, and protects your information.\n\n'
            '2. Information We Collect\n'
            'We may collect personal information such as your name, email address, and usage data when you use our app.\n\n'
            '3. How We Use Your Information\n'
            'We use your information to provide, maintain, and improve our services, and to communicate with you.\n\n'
            '4. Information Sharing\n'
            'We do not sell or rent your personal information to third parties. We may share information as required by law or to protect our rights.\n\n'
            '5. Data Security\n'
            'We implement reasonable security measures to protect your information. However, no method of transmission over the Internet is 100% secure.\n\n'
            '6. Your Rights\n'
            'You may access, update, or delete your personal information by contacting us.\n\n'
            '7. Changes to This Policy\n'
            'We may update this Privacy Policy from time to time. Continued use of the app constitutes acceptance of the new policy.\n\n'
            '8. Contact Us\n'
            'If you have any questions about this Privacy Policy, please contact us at joyvibe@gmail.com.\n',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
