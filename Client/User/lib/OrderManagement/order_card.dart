import 'package:flutter/material.dart';
import 'package:skybridge02/Services/Chat/chat_service.dart';
import 'package:skybridge02/Services/format_date.dart';
import 'package:skybridge02/Theme/text_styles.dart';

class Ordercard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String viewerRole;
  final ValueChanged<String>? onStatusChanged;
  final VoidCallback? onCancelOrder;
  final VoidCallback? onShowDeliveryQr;
  final VoidCallback? onScanDeliveryQr;
  final VoidCallback? onRateTraveler;

  const Ordercard({
    super.key,
    required this.order,
    this.viewerRole = 'buyer',
    this.onStatusChanged,
    this.onCancelOrder,
    this.onShowDeliveryQr,
    this.onScanDeliveryQr,
    this.onRateTraveler,
  });

  void openChat(BuildContext context) {
    final otherUserId = viewerRole == 'buyer'
        ? (order['otherUserId'] ?? order['ownerId'] ?? order['travelerUid'])
        : (order['otherUserId'] ?? order['ownerId'] ?? order['buyerUid']);

    if (otherUserId == null || otherUserId.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is not available for message')),
      );
      return;
    }

    ChatService.openChat(
      context: context,
      otherUserId: otherUserId.toString(),
      otherUserName: order['ownerName'],
      otherUserImage: order['ownerImage'],
      source: 'peer',
      senderRole: viewerRole,
      receiverRole: viewerRole == 'buyer' ? 'traveler' : 'buyer',
    );
  }

  @override
  Widget build(BuildContext context) {
    final arrivalDate = formatDate(order['departureDate'] ?? order['date'] ?? order['deliveryDate'] ?? order['orderDate']);
    final currentStatus = order['status']?.toString() ?? 'Placed';
    final travelerPaymentStatus =
        order['travelerPaymentStatus']?.toString().toUpperCase() ?? '';
    final paymentBoxLabel = viewerRole == 'traveler'
        ? (travelerPaymentStatus == 'RELEASED'
            ? 'RELEASED'
            : currentStatus == 'Received'
                ? 'HOLD 24H'
                : 'HOLD')
        : 'PAID';
    final canCancel = viewerRole == 'buyer' && currentStatus == 'Placed';
    final canShowQr = viewerRole == 'buyer' && currentStatus == 'InTransit';
    final canStartDelivery = viewerRole == 'traveler' &&
        currentStatus == 'Placed' &&
        onStatusChanged != null;
    final canScanQr = viewerRole == 'traveler' && currentStatus == 'InTransit';
    final ratingStatus = order['buyerRatingStatus']?.toString() ?? '';
    final canRateTraveler = viewerRole == 'buyer' &&
        currentStatus == 'Received' &&
        ratingStatus != 'rated' &&
        ratingStatus != 'noRating' &&
        order['buyerRatingSubmitted'] != true &&
        order['buyerRatingSkipped'] != true &&
        onRateTraveler != null;

    final hasCornerAction = canCancel ||
        canShowQr ||
        canStartDelivery ||
        canScanQr ||
        canRateTraveler;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
          decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 255, 255),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      order['itemImage'] ?? '',
                      width: 90,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            right: hasCornerAction ? 82 : 0,
                          ),
                          child: Text(
                            order['itemName'] ?? '',
                            style: AppTextStyles.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 22,
                              color: Color.fromARGB(255, 16, 63, 129),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'DESTINATION',
                              style: AppTextStyles.label,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                order['toCity'] ?? '',
                                style: AppTextStyles.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 22,
                              color: Color(0xFFF97316),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ARRIVAL',
                              style: AppTextStyles.label,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                arrivalDate,
                                style: AppTextStyles.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _infoBox(
                      icon: Icons.attach_money,
                      label: 'REWARD',
                      value: '\$${order['reward']}',
                      bgColor: const Color.fromARGB(255, 240, 175, 161),
                      iconColor: const Color.fromARGB(255, 185, 52, 28),
                      textColor: const Color.fromARGB(255, 185, 52, 28),
                    ),
                    Container(
                        width: 1, height: 50, color: Colors.grey.shade400),
                    _infoBox(
                      icon: Icons.credit_card,
                      label: paymentBoxLabel,
                      value: '\$${order['totalAmount']}',
                      bgColor: const Color.fromARGB(255, 167, 180, 222),
                      iconColor: const Color(0xFF103F81),
                      textColor: const Color(0xFF103F81),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage:
                            NetworkImage(order['ownerImage'] ?? ''),
                        backgroundColor: Colors.grey.shade200,
                        onBackgroundImageError: (_, __) {},
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['viewerRole'] == 'buyer'
                                ? 'Traveler'
                                : 'Buyer',
                            style: AppTextStyles.role,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order['ownerName'] ?? '',
                            style: AppTextStyles.name,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => openChat(context),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFF103F81),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        if (canCancel)
          Positioned(
            top: 10,
            right: 16,
            child: _cornerActionButton(
              label: 'Cancel',
              icon: Icons.close_rounded,
              primaryColor: const Color(0xFFB91C1C),
              onTap: onCancelOrder,
            ),
          ),
        if (canShowQr)
          Positioned(
            top: 10,
            right: 16,
            child: _cornerActionButton(
              label: 'QR',
              icon: Icons.qr_code_2_rounded,
              primaryColor: const Color(0xFF0F766E),
              onTap: onShowDeliveryQr,
            ),
          ),
        if (canStartDelivery)
          Positioned(
            top: 10,
            right: 16,
            child: _cornerActionButton(
              label: 'Pick',
              icon: Icons.local_shipping_outlined,
              primaryColor: const Color(0xFF103F81),
              onTap: () => onStatusChanged!('InTransit'),
            ),
          ),
        if (canScanQr)
          Positioned(
            top: 10,
            right: 16,
            child: _cornerActionButton(
              label: 'Scan',
              icon: Icons.qr_code_scanner_rounded,
              primaryColor: const Color(0xFF103F81),
              onTap: onScanDeliveryQr,
            ),
          ),
        if (canRateTraveler)
          Positioned(
            top: 10,
            right: 16,
            child: _cornerActionButton(
              label: 'Rate',
              icon: Icons.star_rounded,
              primaryColor: const Color(0xFFF59E0B),
              onTap: onRateTraveler,
            ),
          ),
      ],
    );
  }
}

Widget _cornerActionButton({
  required String label,
  required IconData icon,
  required Color primaryColor,
  required VoidCallback? onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(18),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.10),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(18),
          ),
          border: Border.all(color: primaryColor.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primaryColor, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: primaryColor,
              size: 12,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _infoBox({
  required IconData icon,
  required String label,
  required String value,
  required Color bgColor,
  required Color iconColor,
  required Color textColor,
}) {
  return Expanded(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.reward.copyWith(color: textColor),
        ),
      ],
    ),
  );
}
