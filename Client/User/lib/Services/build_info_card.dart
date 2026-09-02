import 'package:flutter/material.dart';

// Widget buildCard({required Widget child}) {
//   return Container(
//     padding: const EdgeInsets.all(15),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(24),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withValues(alpha: 0.05),
//           blurRadius: 10,
//           offset: const Offset(0, 2),
//         ),
//       ],
//     ),
//     child: child,
//   );
// }

Widget infoCard(List<Widget> children) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 3),
    padding: const EdgeInsets.all(16),
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 10,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .map(
            (e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: e),
          )
          .toList(),
    ),
  );
}
