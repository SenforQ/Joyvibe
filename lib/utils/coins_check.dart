import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/wallet_page.dart';

class CoinsCheck {
  static const int COMMENT_COST = 5;

  /// 返回 true 表示用户选择去钱包，false 表示取消或余额足够
  static Future<bool> checkCoinsForComment(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getInt('wallet_balance') ?? 0;

    if (balance < COMMENT_COST) {
      final bool? shouldGoToWallet = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text(
            'Insufficient Coins',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B2B3A),
            ),
          ),
          content: const Text(
            'You need 5 coins to leave a comment. Your current balance is insufficient. Would you like to purchase more coins?',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Go to Wallet',
                style: TextStyle(
                  color: Color(0xFFDB64A5),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      // 返回用户选择
      return shouldGoToWallet == true;
    }
    return false;
  }

  static Future<void> deductCoinsForComment() async {
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getInt('wallet_balance') ?? 0;
    await prefs.setInt('wallet_balance', balance - COMMENT_COST);
  }
}
