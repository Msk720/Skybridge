import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/format_date.dart';
import 'package:skybridge02/Theme/text_styles.dart';

class DisputeCard extends StatelessWidget {
  final Map<String, dynamic> dispute;
  final VoidCallback? onCancel;

  const DisputeCard({
    super.key,
    required this.dispute,
    this.onCancel,
  });

  String _itemTitle() {
    return (dispute['itemDescription'] ??
            dispute['itemName'] ??
            dispute['productName'] ??
            dispute['name'] ??
            'Disputed Item')
        .toString();
  }

  String _orderText() {
    final orderNumber = dispute['orderNumber'];

    if (orderNumber != null && orderNumber.toString().trim().isNotEmpty) {
      return orderNumber.toString();
    }

    final order = dispute['orderId'];

    if (order is Map) {
      return (order['orderNumber'] ?? order['id'] ?? order['_id'] ?? 'N/A')
          .toString();
    }

    return order?.toString() ?? 'N/A';
  }

  String _shortOrderId(String value) {
    final clean = value.trim();

    if (clean.length <= 6) return clean;

    return clean.substring(clean.length - 6);
  }

  String _disputeId() {
    final id = (dispute['_id'] ?? dispute['id'] ?? '').toString();

    if (id.isEmpty) return '#DSP-000000';
    if (id.length <= 6) return '#DSP-${id.toUpperCase()}';

    return '#DSP-${id.substring(id.length - 6).toUpperCase()}';
  }

  String _natureText() {
    return (dispute['natureOfDispute'] ??
            dispute['nature'] ??
            dispute['type'] ??
            dispute['reason'] ??
            'General Issue')
        .toString();
  }

  String _detailsText() {
    return (dispute['extraDetails'] ??
            dispute['description'] ??
            dispute['details'] ??
            'No issue details added.')
        .toString();
  }

  String _statusValue() {
    return (dispute['status'] ?? 'pending')
        .toString()
        .toLowerCase()
        .replaceAll('-', '_')
        .trim();
  }

  bool _isOpenStatus(String status) {
    return status == 'pending' ||
        status == 'open' ||
        status == 'under_review' ||
        status == 'review';
  }

  String _openCloseText(String status) {
    return _isOpenStatus(status) ? 'Dispute Open' : 'Dispute Closed';
  }

  String _progressText(String status) {
    if (status == 'under_review' || status == 'review') return 'Under Review';
    if (status == 'resolved' || status == 'solved') return 'Solved';
    if (status == 'rejected' || status == 'reject') return 'Rejected';
    if (status == 'cancelled' || status == 'canceled') return 'Cancelled';
    if (status == 'closed') return 'Closed';

    return 'Pending';
  }

  Color _progressColor(String status) {
    if (status == 'resolved' || status == 'solved') {
      return AppColors.success;
    }

    if (status == 'rejected' || status == 'reject') {
      return AppColors.error;
    }

    if (status == 'cancelled' || status == 'canceled' || status == 'closed') {
      return AppColors.textgray;
    }

    if (status == 'under_review' || status == 'review') {
      return AppColors.secondary;
    }

    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final title = _itemTitle();
    final orderId = _orderText();
    final nature = _natureText();
    final details = _detailsText();
    final status = _statusValue();
    final progressColor = _progressColor(status);
    final canCancel = _isOpenStatus(status) && onCancel != null;
    final filedDate = formatDate(dispute['createdAt']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.activeline.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topSection(
            title: title,
            orderId: orderId,
            status: status,
            progressColor: progressColor,
          ),
          const SizedBox(height: 18),
          _typeSection(nature),
          const SizedBox(height: 16),
          Text(
            details,
            style: AppTextStyles.value.copyWith(
              color: AppColors.textgray,
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _openCloseLabel(status),
          const SizedBox(height: 18),
          _bottomSection(
            filedDate: filedDate,
            canCancel: canCancel,
          ),
        ],
      ),
    );
  }

  Widget _topSection({
    required String title,
    required String orderId,
    required String status,
    required Color progressColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textprimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Order# ${_shortOrderId(orderId)}',
                style: AppTextStyles.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textgray,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _progressChip(
          text: _progressText(status),
          color: progressColor,
        ),
      ],
    );
  }

  Widget _typeSection(String nature) {
    return Row(
      children: [
        Text(
          'TYPE',
          style: AppTextStyles.label.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: AppColors.textgray,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: _natureChip(nature),
        ),
      ],
    );
  }

  Widget _bottomSection({
    required String filedDate,
    required bool canCancel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dispute ID: ${_disputeId()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Filed $filedDate',
                  style: const TextStyle(
                    color: AppColors.textgray,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canCancel) ...[
            const SizedBox(width: 10),
            _cancelButton(),
          ],
        ],
      ),
    );
  }

  Widget _progressChip({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.activeline.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _natureChip(String nature) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.report_problem_outlined,
            size: 14,
            color: AppColors.error,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              nature,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _openCloseLabel(String status) {
    final isOpen = _isOpenStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: isOpen
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.textgray.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOpen
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.textgray.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        _openCloseText(status),
        style: TextStyle(
          color: isOpen ? AppColors.primary : AppColors.textgray,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _cancelButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCancel,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
