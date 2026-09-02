import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skybridge02/Services/action_buttons.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Theme/app_color.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool loading = false;

  final user = FirebaseAuth.instance.currentUser;

  Future<void> checkVerified() async {
    setState(() => loading = true);

    await FirebaseAuth.instance.currentUser?.reload();

    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (!mounted) return;
    if (refreshedUser != null && refreshedUser.emailVerified) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/gate',
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email not verified yet. Please check your inbox."),
        ),
      );
    }

    setState(() => loading = false);
  }

  Future<void> resendEmail() async {
    try {
      await user?.sendEmailVerification();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verification email sent again"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send verification email"),
        ),
      );
    }
  }

  Future<void> backToLogin() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = MediaQuery.of(context).size.width * 0.88;
    const double buttonHeight = 54;

    return Scaffold(
      appBar: dashboardAppBar(
        title: "Verify Email",
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          child: IconButton(
            iconSize: 20,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => backToLogin(),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                "A verification email has been sent to:",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? "",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: buttonWidth,
                child: ActionButtonsRow(
                  leftText: 'Resend Email',
                  rightText: 'I Verified',
                  height: buttonHeight,
                  onLeftPressed: resendEmail,
                  onRightPressed: checkVerified,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
