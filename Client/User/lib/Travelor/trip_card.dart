import 'package:skybridge02/Services/action_buttons.dart';
import 'package:skybridge02/Services/app_imports.dart';

class TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String status;

  const TripCard(
      {super.key,
      required this.trip,
      this.onEdit,
      this.onDelete,
      required this.status});

  String _safe(dynamic v) => (v == null) ? '' : v.toString();

  String _formatDate(dynamic v) {
    if (v == null) return '--';
    try {
      final dt = DateTime.tryParse(v.toString());
      if (dt != null) {
        return "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}";
      }
    } catch (_) {}
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final fromCountry = _safe(trip['fromCountry'] ?? trip['fromCountry']);
    final fromCity = _safe(trip['fromCity'] ?? trip['fromCity']);
    final toCountry = _safe(trip['toCountry'] ?? trip['toCountry']);
    final toCity = _safe(trip['toCity'] ?? trip['toCity']);
    final date = _formatDate(trip['departureDate'] ?? trip['date'] ?? trip['deliveryDate']);
    final weightVal = _safe(trip['availableWeight'] ?? trip['weight']);
    final weight = weightVal.isEmpty ? '--' : '$weightVal KG';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
          // FROM
          Row(
            children: [
              Icon(Icons.flight_takeoff, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fromCountry.isEmpty || fromCity.isEmpty
                      ? '—'
                      : '$fromCountry $fromCity',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // TO
          Row(
            children: [
              Icon(Icons.flight_land, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  toCountry.isEmpty || toCity.isEmpty
                      ? '—'
                      : '$toCountry $toCity',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // DATE
          Row(
            children: [
              Icon(Icons.schedule, color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Text("Departs On: $date", style: const TextStyle(fontSize: 14)),
            ],
          ),

          const SizedBox(height: 12),

          // WEIGHT UNDER DATE
          Row(
            children: [
              Icon(Icons.monitor_weight, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                weight,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (status == "Active") ...[
            const SizedBox(height: 20),
            ActionButtonsRow(
              leftText: 'Edit',
              rightText: 'Delete',
              onLeftPressed: onEdit,
              onRightPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
