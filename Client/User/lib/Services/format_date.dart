String formatDate(dynamic dateField) {
  if (dateField == null) return "--";

  final dt = DateTime.tryParse(dateField.toString());
  if (dt == null) return "--";

  const mo = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  return "${mo[dt.month - 1]} ${dt.day} ${dt.year}";
}
