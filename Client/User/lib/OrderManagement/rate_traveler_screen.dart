import 'package:flutter/material.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Theme/app_color.dart';

class RateTravelerScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const RateTravelerScreen({super.key, required this.order});

  @override
  State<RateTravelerScreen> createState() => _RateTravelerScreenState();
}

class _RateTravelerScreenState extends State<RateTravelerScreen> {
  int rating = 5;
  bool loading = false;
  bool completed = false;

  String get orderId => widget.order['id']?.toString() ?? '';

  Future<void> _submit() async {
    if (orderId.isEmpty || loading || completed) return;

    setState(() => loading = true);

    try {
      await ApiService.post('/submitTravelerRating', {
        'orderId': orderId,
        'rating': rating,
      });

      completed = true;

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to submit rating')),
      );
    } finally {
      if (mounted && !completed) setState(() => loading = false);
    }
  }

  Future<void> _skip() async {
    if (orderId.isEmpty || loading || completed) return;

    setState(() => loading = true);

    try {
      await ApiService.post('/skipTravelerRating', {'orderId': orderId});

      completed = true;

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to skip rating')),
      );
    } finally {
      if (mounted && !completed) setState(() => loading = false);
    }
  }

  void _handleBackAttempt() {
    if (loading || completed) return;
    _skip();
  }

  @override
  Widget build(BuildContext context) {
    final travelerName = widget.order['ownerName']?.toString() ?? 'Traveler';

    return PopScope(
      canPop: completed,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAttempt();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: dashboardAppBar(
          title: 'Rate Traveler',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: loading ? null : _skip,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'How was your delivery?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textprimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rate $travelerName or skip this step.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textgray,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      final selected = value <= rating;

                      return GestureDetector(
                        onTap: loading ? null : () => setState(() => rating = value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Icon(
                            selected ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 38,
                            color: Colors.amber,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: appPrimaryButton(
                      text: 'Submit Rating',
                      loading: loading,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: loading ? null : _skip,
                    child: const Text('Skip Rating'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
