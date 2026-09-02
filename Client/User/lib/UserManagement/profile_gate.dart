import 'package:skybridge02/Services/app_imports.dart';
import 'package:http/http.dart' as http;
import 'package:skybridge02/Home/home_screen.dart';
import 'profile_screen.dart';
import 'package:skybridge02/Services/app_config.dart';
import 'login_screen.dart';
import 'package:skybridge02/UserManagement/verification.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool _profileChecked = false;
  bool loading = true;
  bool profileComplete = false;

  @override
  void initState() {
    super.initState();

    if (!_profileChecked) {
      _profileChecked = true;
      _checkProfile();
    }
  }

  Future<void> _checkProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() => loading = false);
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('${getFunctionsBase()}/getProfile'),
        headers: {
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
      );

      if (res.statusCode == 403) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Your account is restricted. Please contact support."),
          ),
        );

        setState(() {
          loading = false;
          profileComplete = false;
        });

        return;
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        profileComplete = data['isComplete'] == true;
      }
    } catch (_) {
      profileComplete = false;
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!user.emailVerified) {
      return const VerifyEmailScreen();
    }
    if (!profileComplete) {
      return const ProfileScreen();
    }

    return const HomeScreen();
  }
}
