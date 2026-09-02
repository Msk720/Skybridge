import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/custom_inputfield.dart';
import 'package:skybridge02/Services/app_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool loading = false;

  Future<void> _sendResetLink() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Please enter your email');
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      _showMessage('Password reset link sent. Check your email.');
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Something went wrong');
    } finally {
      setState(() => loading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final double fieldWidth = MediaQuery.of(context).size.width * 0.90;
    const double fieldHeight = 64;
    final double buttonWidth = fieldWidth * 0.94;
    const double buttonHeight = 54;

    return Scaffold(
      appBar: dashboardAppBar(
        title: "Forgot Password",
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
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: fieldWidth,
                height: fieldHeight,
                child: CustomInputField(
                  controller: emailController,
                  hint: 'Enter your email',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: buttonWidth,
                height: buttonHeight,
                child: appPrimaryButton(
                  text: 'Send Reset Link',
                  loading: loading,
                  height: buttonHeight,
                  onPressed: _sendResetLink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
