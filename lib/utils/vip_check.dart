import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/vip_page.dart';

class VipCheck {
  static Future<bool> checkVipPermission(
      BuildContext context, String permission) async {
    final hasPermission = await VipPermissions.hasVipPermission(permission);
    if (!hasPermission) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('VIP Required'),
          content: const Text(
              'You need VIP to view character details. Would you like to become a VIP?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VipPage()),
                );
              },
              child: const Text('Get VIP'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }
}
