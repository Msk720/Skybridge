import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skybridge02/Services/custom_inputfield.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/app_imports.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool rememberMe = false;
  bool showPassword = false;
  bool _loading = false;
  bool isLogin = true;
  bool showConfirmPassword = false;

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final savedEmail = p.getString('email');
      _emailController.text = savedEmail ?? '';
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _authTab({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        width: MediaQuery.of(context).size.width * 0.90 / 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user!.sendEmailVerification();
      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        'uid': uid,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/gate', (_) => false);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Signup failed")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});

        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/gate', (_) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sign-In failed')),
      );
    }
  }

  Future<void> handleLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both email and password.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (rememberMe) {
        final p = await SharedPreferences.getInstance();
        await p.setString('email', email);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login successful"),
          backgroundColor: AppColors.secondary,
        ),
      );
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/gate', (_) => false);
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-credential':
          message = 'Wrong email or password.';
          break;

        case 'invalid-email':
          message = 'The email address is not valid.';
          break;

        case 'user-disabled':
          message = 'This user has been disabled.';
          break;

        default:
          message = 'Login failed. Please try again.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double fieldWidth = MediaQuery.of(context).size.width * 0.90;
    final double fieldHeight = 64;
    final double buttonWidth = fieldWidth * 0.94;
    final double buttonHeight = 54;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 0.7,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 240,
                ),
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'S',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  TextSpan(
                    text: 'KY',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  TextSpan(
                    text: 'B',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.background,
                    ),
                  ),
                  TextSpan(
                    text: 'RIDGE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.background,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            height: fieldHeight,
                            width: fieldWidth,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _authTab(
                                title: "Sign In",
                                selected: isLogin,
                                onTap: () => setState(() => isLogin = true),
                              ),
                              _authTab(
                                title: "Sign Up",
                                selected: !isLogin,
                                onTap: () => setState(() => isLogin = false),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: fieldWidth,
                        height: fieldHeight,
                        child: CustomInputField(
                          controller: _emailController,
                          hint: 'Enter your email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: fieldWidth,
                        height: fieldHeight,
                        child: CustomInputField(
                          controller: _passwordController,
                          hint: 'Enter your password',
                          icon: Icons.lock,
                          obscureText: !showPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => showPassword = !showPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (!isLogin)
                        SizedBox(
                          width: fieldWidth,
                          height: fieldHeight,
                          child: CustomInputField(
                            controller: _confirmPasswordController,
                            hint: 'Confirm your password',
                            icon: Icons.lock,
                            obscureText: !showConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                showConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() =>
                                  showConfirmPassword = !showConfirmPassword),
                            ),
                          ),
                        ),
                      if (!isLogin) const SizedBox(height: 15),
                      SizedBox(
                        width: fieldWidth,
                        height: 28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  rememberMe = !rememberMe;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    rememberMe
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: rememberMe
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    size: 21,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Remember me",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, '/forgotPassword'),
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: appPrimaryButton(
                          text: isLogin ? 'Sign In' : 'Sign Up',
                          loading: _loading,
                          height: buttonHeight,
                          onPressed: isLogin ? handleLogin : handleSignUp,
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: fieldWidth - 20,
                        child: Row(
                          children: [
                            const Expanded(
                                child: Divider(
                                    thickness: 1,
                                    color: AppColors.textSecondary)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                "Or continue with",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Expanded(
                                child: Divider(
                                    thickness: 1,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          onPressed: signInWithGoogle,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  'assets/images/google.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Continue with Google",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 35),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
