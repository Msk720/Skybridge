import 'package:flutter/material.dart';
import 'package:skybridge02/Services/Chat/chat_service.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/format_date.dart';
import 'package:skybridge02/Services/open_link.dart';
import 'package:skybridge02/SearchManagement/details_hero_card.dart';
import 'package:skybridge02/Theme/app_color.dart';

class ShipmentDetailsScreen extends StatefulWidget {
  const ShipmentDetailsScreen({
    super.key,
  });

  @override
  State<ShipmentDetailsScreen> createState() => _ShipmentDetailsScreenState();
}

class _ShipmentDetailsScreenState extends State<ShipmentDetailsScreen> {
  bool _loading = false;

  int customReward = 0;
  int originalReward = 0;

  bool loading = true;

  void openWebsite(BuildContext context) {
    openLink(context, item['storeLink']);
  }

  Map<String, dynamic> item = {};
  bool _initialized = false;

  String _safe(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      item = args;
    } else if (args is Map) {
      item = Map<String, dynamic>.from(args);
    }

    customReward = (num.tryParse(_safe(item['travelerReward'], '0')) ?? 0).round();
    originalReward = customReward;
    _initialized = true;
  }

  void _messageBuyer(BuildContext context) {
    final buyerId = _safe(item['userId'] ?? item['buyerUid']);

    if (buyerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buyer profile is not available')),
      );
      return;
    }

    ChatService.openChat(
      context: context,
      otherUserId: buyerId,
      otherUserName: _safe(item['ownerName'], 'Buyer'),
      otherUserImage: _safe(item['ownerImage']),
      source: 'peer',
      senderRole: 'traveler',
      receiverRole: 'buyer',
    );
  }

  Future<void> _sendOfferFlow() async {
    try {
      final tripId = await fetchMatchingTripId();
      if (!mounted) return;
      if (tripId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No matching trip found")),
        );
        return;
      }

      final data = await ApiService.post("/sendOffer", {
        "itemId": item['id'],
        "tripId": tripId,
        "buyerUid": item['userId'],
        "originalReward": item['travelerReward'] ?? 0,
        "offeredReward": customReward,
        "departureDate": item['date'],
      });

      if (!mounted) return;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer sent successfully')),
        );

        if (!context.mounted) return;

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        throw Exception("Failed");
      }
    } catch (e) {
      debugPrint("❌ sendOffer error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send offer')),
      );
    }
  }

  Future<void> _handleSendOffer() async {
    setState(() => _loading = true);

    await _sendOfferFlow();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<String?> fetchMatchingTripId() async {
    try {
      final data = await ApiService.post("/getMyMatchingTripId", {
        "fromCountry": item['fromCountry'],
        "fromCity": item['fromCity'],
        "toCountry": item['toCountry'],
        "toCity": item['toCity'],
        "weight": item['weightTotal'],
        "date": item['date'],
      });

      return data['tripId'];
    } catch (e) {
      debugPrint("❌ trip match error: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(233, 233, 233, 233),
      appBar: dashboardAppBar(
        title: "Shipment Details",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DetailsHeroCard(
              imageUrl: item['image']?.toString(),
              fallbackIcon: Icons.inventory_2_outlined,
              title: item['name']?.toString() ?? 'Shipment',
              rows: [
                DetailsHeroRow(
                  'From',
                  '${item['fromCountry']}, ${item['fromCity']}',
                ),
                DetailsHeroRow(
                  'To',
                  '${item['toCountry']}, ${item['toCity']}',
                ),
                DetailsHeroRow('By', formatDate(item['date'])),
              ],
            ),
            infoCard([
              infoRow('Quantity', _safe(item['quantity'], '—')),
              infoRow('Category', _safe(item['category'], '—')),
              infoRow('Weight', '${_safe(item['weightTotal'], '—')} kg'),
              infoRow('Price', _safe(item['price'], '0')),
              infoRow(
                'Traveler Reward',
                _safe(item['travelerReward'], '0'),
              ),
              infoRow('Total Price', _safe(item['totalPrice'], '0')),
              GestureDetector(
                onTap: () => openWebsite(context),
                child: const Text(
                  'See this product here',
                  style: TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ]),
            if (item['note'] != null &&
                item['note'].toString().trim().isNotEmpty)
              infoCard([
                const Text(
                  "Shopper's Note:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(_safe(item['note'])),
              ]),
            infoCard([
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: _safe(item['ownerImage']).isNotEmpty
                        ? NetworkImage(_safe(item['ownerImage']))
                        : null,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                    radius: 24,
                    child: _safe(item['ownerImage']).isEmpty
                        ? const Icon(Icons.person, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Buyer',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _safe(item['ownerName'], 'Buyer'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  detailsMessageButton(
                    onPressed: () => _messageBuyer(context),
                  ),
                ],
              ),
            ]),
            infoCard([
              const Text(
                'Set  Offer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() {
                        if (originalReward <= 5) return;

                        if (customReward > 5) {
                          customReward -= 2;
                        }
                      });
                    },
                  ),
                  Text(
                    '\$ $customReward',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      setState(() {
                        customReward += 2;
                      });
                    },
                  ),
                ],
              ),
            ]),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: _handleSendOffer,
                  child: const Text(
                    'Send Offer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ================= HELPERS =================
}

Widget infoRow(String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.grey)),
      Text(value),
    ],
  );
}
