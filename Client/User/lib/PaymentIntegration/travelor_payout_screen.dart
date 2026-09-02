import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:url_launcher/url_launcher.dart';

class TravelerPayoutScreen extends StatefulWidget {
  const TravelerPayoutScreen({super.key});

  @override
  State<TravelerPayoutScreen> createState() => _TravelerPayoutScreenState();
}

class _TravelerPayoutScreenState extends State<TravelerPayoutScreen> {
  bool loading = false;
  Map<String, dynamic>? profile;
  Map<String, dynamic>? stripeBalance;

  bool get _stripeConnected =>
      profile?['stripeAccountId'] != null &&
      profile!['stripeAccountId'].toString().isNotEmpty;

  bool get _stripeReady =>
      profile?['stripeDetailsSubmitted'] == true &&
      profile?['stripePayoutsEnabled'] == true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadProfile() async {
    setState(() => loading = true);

    try {
      final data = await ApiService.get('/getProfile');
      if (!mounted) return;
      setState(() {
        profile = Map<String, dynamic>.from(data);
      });

      await _loadStripeBalance();
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    }

    if (mounted) setState(() => loading = false);
  }
  Future<void> _loadStripeBalance() async {
    if (!_stripeConnected) {
      if (!mounted) return;
      setState(() {
        stripeBalance = null;
      });
      return;
    }

    try {
      final data = await ApiService.get('/getTravelerStripeBalance');
      if (!mounted) return;
      setState(() {
        stripeBalance = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      debugPrint('Load Stripe balance error: $e');
    }
  }


  Future<void> _connectStripeAccount() async {
    setState(() => loading = true);

    try {
      final result = await ApiService.post(
        '/createTravelerStripeAccountLink',
        {},
      );

      final url = result['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('Stripe onboarding URL missing');
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open Stripe onboarding');
      }
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _refreshStripeAccountStatus() async {
    setState(() => loading = true);

    try {
      await ApiService.post('/getTravelerStripeAccountStatus', {});
      await _loadProfile();

      if (!mounted) return;
      _showMessage('Stripe payout status refreshed');
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _openStripeDashboard() async {
    setState(() => loading = true);

    try {
      final result = await ApiService.post(
        '/createTravelerStripeDashboardLoginLink',
        {},
      );

      final url = result['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('Stripe dashboard URL missing');
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open Stripe dashboard');
      }
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: 'Payout Account',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshStripeAccountStatus,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _payoutCard(),
                if (_stripeConnected) ...[
                  const SizedBox(height: 16),
                  _balanceCard(),
                ],
                const SizedBox(height: 16),
                _infoNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _payoutCard() {
    final accountId = profile?['stripeAccountId']?.toString();
    final detailsSubmitted = profile?['stripeDetailsSubmitted'] == true;
    final payoutsEnabled = profile?['stripePayoutsEnabled'] == true;
    final disabledReason = profile?['stripeDisabledReason']?.toString();

    final statusText = !_stripeConnected
        ? 'Not connected'
        : _stripeReady
            ? 'Ready for transfers and payouts'
            : 'Onboarding incomplete';

    final statusColor = !_stripeConnected
        ? const Color(0xFFB45309)
        : _stripeReady
            ? const Color(0xFF047857)
            : const Color(0xFFB91C1C);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Traveler payout account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Connect Stripe to receive delivery payments.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _stripeReady
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (accountId != null && accountId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Account: $accountId',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (_stripeConnected && !_stripeReady) ...[
            const SizedBox(height: 8),
            Text(
              'Details submitted: ${detailsSubmitted ? 'Yes' : 'No'} • Payouts enabled: ${payoutsEnabled ? 'Yes' : 'No'}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (disabledReason != null && disabledReason.isNotEmpty)
              Text(
                'Reason: $disabledReason',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loading ? null : _connectStripeAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    _stripeConnected ? 'Continue Stripe' : 'Connect Stripe',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: loading ? null : _refreshStripeAccountStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  loading || !_stripeConnected ? null : _openStripeDashboard,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                disabledForegroundColor: Colors.grey.shade400,
                side: BorderSide(
                  color: _stripeConnected
                      ? AppColors.primary
                      : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
              label: const Text('Open Stripe Dashboard'),
            ),
          ),
          if (loading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  String _firstBalanceAmount(String key) {
    final values = stripeBalance?[key];
    if (values is List && values.isNotEmpty) {
      final first = values.first;
      if (first is Map) {
        final amount = first['displayAmount']?.toString();
        final currency = first['currency']?.toString().toUpperCase() ?? 'USD';
        if (amount != null && amount.isNotEmpty) {
          return '\$$amount $currency';
        }
      }
    }

    return '\$0.00 USD';
  }

  String _bankSummary() {
    final banks = stripeBalance?['bankAccounts'];
    if (banks is List && banks.isNotEmpty) {
      final first = banks.first;
      if (first is Map) {
        final bankName = first['bankName']?.toString();
        final last4 = first['last4']?.toString();
        if (bankName != null && bankName.isNotEmpty && last4 != null && last4.isNotEmpty) {
          return '$bankName •••• $last4';
        }
        if (last4 != null && last4.isNotEmpty) {
          return 'Bank account •••• $last4';
        }
      }
    }

    return 'Not available in app';
  }

  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stripe Balance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'This is the traveler Express balance, not the real bank balance.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _balanceBox('Available', _firstBalanceAmount('available')),
              const SizedBox(width: 10),
              _balanceBox('Pending', _firstBalanceAmount('pending')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Payout bank: ${_bankSummary()}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _balanceBox(String label, String amount) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Travelers must connect Stripe before creating a trip. After delivery QR verification, the transfer is sent to this connected payout account.',
              style: TextStyle(
                color: Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
