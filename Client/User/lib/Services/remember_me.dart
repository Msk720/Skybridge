import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RememberMe {
  static const _emailsKey = 'remembered_emails';

  static Future<bool?> askSavePassword(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Save password?'),
        content: const Text(
          'Do you want this app to remember your password on this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  /// Save email always
  static Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final emails = prefs.getStringList(_emailsKey) ?? [];

    if (!emails.contains(email)) {
      emails.add(email);
      await prefs.setStringList(_emailsKey, emails);
    }
  }

  /// Save password per email
  static Future<void> savePassword(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pwd_$email', password);
  }

  /// Remove password if user says no
  static Future<void> removePassword(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pwd_$email');
  }

  /// Load password for specific email
  static Future<String?> loadPassword(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pwd_$email');
  }

  /// Load last used email
  static Future<String?> loadLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final emails = prefs.getStringList(_emailsKey);
    return (emails != null && emails.isNotEmpty) ? emails.last : null;
  }
}
