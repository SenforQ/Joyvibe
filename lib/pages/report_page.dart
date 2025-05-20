import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ReportPage extends StatefulWidget {
  final Map<String, dynamic> rec;
  const ReportPage({Key? key, required this.rec}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final List<String> _reasons = [
    'Pornographic or vulgar content',
    'Politically sensitive content',
    'Deception and Fraud',
    'Harassment and Threats',
    'Insults and Obscenity',
    'Incorrect Information',
    'Privacy Violation',
    'Plagiarism or Copyright Infringement',
    'Other',
  ];
  int _selectedReason = 0;
  final TextEditingController _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _onSave() async {
    await showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text('Report Submitted'),
            content: const Text(
              'Thank you for your report. Our team will review it within 24 hours.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Report'),
        previousPageTitle: '',
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Reason for Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: List.generate(_reasons.length, (i) {
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _selectedReason = i;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedReason == i
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle,
                            color:
                                _selectedReason == i
                                    ? Color(0xFFDB64A5)
                                    : Color(0xFFB0B0B0),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _reasons[i],
                              style: TextStyle(
                                fontSize: 16,
                                color:
                                    _selectedReason == i
                                        ? Color(0xFFDB64A5)
                                        : Color(0xFF555555),
                                fontWeight:
                                    _selectedReason == i
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Other Issue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: CupertinoTextField(
                controller: _otherController,
                placeholder: 'Describe the issue',
                maxLines: 3,
                style: const TextStyle(fontSize: 16),
                decoration: null,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: CupertinoButton(
                color: const Color(0xFFDB64A5),
                borderRadius: BorderRadius.circular(28),
                child: const Text(
                  'Submit',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                onPressed: _onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
