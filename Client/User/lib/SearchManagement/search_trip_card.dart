import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';
import 'base_card.dart';
import 'package:skybridge02/Services/Chat/chat_service.dart';

class TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;

  const TripCard({
    super.key,
    required this.trip,
  });

  String _safe(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  void _messageTraveler(BuildContext context) {
    final travelerId = _safe(trip['userId']);

    if (travelerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Traveler profile is not available')),
      );
      return;
    }

    ChatService.openChat(
      context: context,
      otherUserId: travelerId,
      otherUserName: _safe(trip['ownerName'], 'Traveler'),
      otherUserImage: _safe(trip['ownerImage']),
      source: 'peer',
      senderRole: 'buyer',
      receiverRole: 'traveler',
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromCity = (trip['fromCity'] ?? '').toString();
    final toCity = (trip['toCity'] ?? '').toString();
    final date = trip['departureDate'] ?? trip['date'] ?? trip['deliveryDate'];
    final rawTime = (trip['departureTime'] ?? '').toString().trim();
    final time = rawTime.isEmpty ? null : rawTime;
    final available = (trip['availableWeight'] ?? '—').toString();
    final ownerName = (trip['ownerName'] ?? 'Traveler').toString();
    final ownerImage = (trip['ownerImage'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BaseCard(
        fromCity: fromCity,
        toCity: toCity,
        dateText: date,
        timeText: time,
        weightText: '$available KG',
        weightSubText: 'Available weight',
        ownerName: ownerName,
        ownerImage: ownerImage,
        actionLabel: 'Message',
        actionIcon: Icons.chat_bubble_outline_rounded,
        onPressed: () => _messageTraveler(context),
      ),
    );
  }
}
