import 'package:shared_preferences/shared_preferences.dart';
import 'package:skybridge02/Services/app_imports.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  void _onTapGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("first_time", false);

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  void _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool("first_time") ?? true;

    if (!isFirstTime && mounted) {
      Navigator.pushReplacementNamed(context, '/gate');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;

    const double pXl = 24.0;
    const double p_4xs = 8.0;
    const double br_25xl = 44.0;

    const double size_5xl = 26.0;
    const double size_9xl = 48.0;
    const double size_31xl = 64.0;
    const double sizeLg = 16.0;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: pXl),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                'WELCOME TO',
                                style: TextStyle(
                                  fontSize: size_5xl,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gray,
                                ),
                              ),
                              SizedBox(height: height * 0.01),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'S',
                                      style: TextStyle(
                                        fontSize: size_31xl,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'KY',
                                      style: TextStyle(
                                        fontSize: size_9xl,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'B',
                                      style: TextStyle(
                                        fontSize: size_31xl,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.black,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'RIDGE',
                                      style: TextStyle(
                                        fontSize: size_9xl,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: height * 0.02),
                              SizedBox(
                                width: size.width * 0.8,
                                child: Text(
                                  'Smart Seamless Shopping Platform,\nPowered By Travelers',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: sizeLg,
                                    color: AppColors.gray,
                                  ),
                                ),
                              ),
                              SizedBox(height: height * 0.03),
                              SizedBox(
                                width: size.width * 0.5,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: pXl,
                                      vertical: p_4xs,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        br_25xl,
                                      ),
                                    ),
                                  ),
                                  onPressed: () => _onTapGetStarted(),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text(
                                        'Get Started',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -123,
              left: -9,
              child: SizedBox(
                width: 180,
                height: 185,
                child: Image.asset(
                  'assets/images/Bottom.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -45,
              child: SizedBox(
                width: 180,
                height: 185,
                child: Image.asset(
                  'assets/images/Top.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
