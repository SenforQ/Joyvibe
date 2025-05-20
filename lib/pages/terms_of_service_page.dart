import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            'Terms of Service\n\n'
            '1. Acceptance of Terms\n'
            'By accessing or using JoyVibe, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.\n\n'
            '2. Use of the Service\n'
            'You must be at least 18 years old to use this app. You agree to use the service only for lawful purposes and in accordance with these terms.\n\n'
            '3. User Responsibilities\n'
            'You are responsible for maintaining the confidentiality of your account and for all activities that occur under your account.\n\n'
            '4. Content Policy\n'
            'You may not upload, post, or share any content that is illegal, offensive, or infringes on the rights of others. JoyVibe reserves the right to remove any content that violates these terms.\n\n'
            '5. Disclaimer\n'
            'JoyVibe is provided on an "as is" and "as available" basis. We do not guarantee the accuracy, completeness, or usefulness of any information on the app.\n\n'
            '6. Limitation of Liability\n'
            'JoyVibe shall not be liable for any damages arising from your use of the app.\n\n'
            '7. Changes to Terms\n'
            'We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of the new terms.\n\n'
            '8. Contact Us\n'
            'If you have any questions about these Terms, please contact us at joyvibe@gmail.com.\n',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
