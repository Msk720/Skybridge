import 'package:skybridge02/Services/Chat/chat_service.dart';
import 'package:skybridge02/Services/action_buttons.dart';
import 'package:skybridge02/Services/format_date.dart';
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Theme/text_styles.dart';

class Offercard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Function(String offerId)? onAccept;
  final Function(String offerId)? onReject;
  final bool isLoading;
  final bool showActions;
  final VoidCallback? onMessage;

  const Offercard({
    super.key,
    required this.offer,
    this.onAccept,
    this.onReject,
    this.isLoading = false,
    this.showActions = true,
    this.onMessage,
  });

  void _openOfferChat(BuildContext context) {
    final otherUserId = (showActions
            ? offer['travelerUid'] ?? offer['ownerId'] ?? offer['userId']
            : offer['buyerUid'] ?? offer['ownerId'] ?? offer['userId'])
        ?.toString();

    if (otherUserId == null || otherUserId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is not available for message')),
      );
      return;
    }

    ChatService.openChat(
      context: context,
      otherUserId: otherUserId,
      otherUserName: offer['ownerName']?.toString(),
      otherUserImage: offer['ownerImage']?.toString(),
      source: 'peer',
      senderRole: showActions ? 'buyer' : 'traveler',
      receiverRole: showActions ? 'traveler' : 'buyer',
    );
  }

  @override
  Widget build(BuildContext context) {
    final departureDate =
        formatDate(offer['departureDate'] ?? offer['deliveryDate']);
    final ownerImage = (offer['ownerImage'] ?? '').toString();
    final status = (offer['status'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ]),
      child: Column(
        children: [
          /// HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.local_offer_rounded,
                size: 30,
                color: AppColors.primary,
              ),
            ),
          ),

          /// ROUTE
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    /// FROM
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'From',
                            style: AppTextStyles.label,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            offer['fromCity'] ?? '',
                            style: AppTextStyles.city,
                          ),
                          Text(
                            offer['fromCountry'] ?? '',
                            style: AppTextStyles.country,
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.flight_takeoff,
                      size: 30,
                      color: AppColors.primary,
                    ),

                    /// TO
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('To', style: AppTextStyles.label),
                          const SizedBox(height: 3),
                          Text(
                            offer['toCity'] ?? '',
                            style: AppTextStyles.city,
                          ),
                          Text(
                            offer['toCountry'] ?? '',
                            style: AppTextStyles.country,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                /// DATE
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      size: 25,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Departs on:', style: AppTextStyles.label),
                    const SizedBox(width: 4),
                    Text(
                      departureDate,
                      style: AppTextStyles.value,
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// REWARD
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Icon(Icons.attach_money_rounded,
                    size: 23, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text('Offered Reward', style: AppTextStyles.label),
                const Spacer(),
                Text(
                  '\$${offer['originalReward']}',
                  style: AppTextStyles.rewardOld,
                ),
                const SizedBox(width: 4),
                Text(
                  '\$${offer['offeredReward']}',
                  style: AppTextStyles.reward,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          /// TRAVELER
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 25, 30),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage:
                      ownerImage.isNotEmpty ? NetworkImage(ownerImage) : null,
                  child: ownerImage.isEmpty
                      ? const Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer['ownerName'] ?? '',
                      style: AppTextStyles.name,
                    ),
                    Row(
                      children: const [
                        Icon(Icons.star, size: 17, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          '4.8',
                          style: AppTextStyles.rating,
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: onMessage ?? () => _openOfferChat(context),
                  icon: const Icon(
                    Icons.chat_bubble_outline_sharp,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          if (showActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              child: isLoading
                  ? const CircularProgressIndicator()
                  : ActionButtonsRow(
                      leftText: 'Accept',
                      rightText: 'Reject',
                      onLeftPressed: () => onAccept?.call(offer['id']),
                      onRightPressed: () => onReject?.call(offer['id']),
                    ),
            )
          else if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
