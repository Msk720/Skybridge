// //   // Widget _buildTab(String tab) {
// //   //   final active = _selectedTab == tab;

// //   //   return Expanded(
// //   //     child: GestureDetector(
// //   //       onTap: () {
// //   //         if (_selectedTab == tab) return;
// //   //         setState(() => _selectedTab = tab);
// //   //         fetchOrders();
// //   //       },
// //   //       child: Container(
// //   //         padding: const EdgeInsets.symmetric(vertical: 10),
// //   //         decoration: BoxDecoration(
// //   //           borderRadius: BorderRadius.circular(12),
// //   //           gradient: active
// //   //               ? const LinearGradient(
// //   //                   colors: [
// //   //                     Color.fromARGB(255, 5, 35, 56),
// //   //                     Color.fromARGB(255, 108, 124, 146),
// //   //                   ],
// //   //                 )
// //   //               : null,
// //   //         ),
// //   //         child: Text(
// //   //           tab,
// //   //           textAlign: TextAlign.center,
// //   //           style: TextStyle(
// //   //             fontWeight: FontWeight.w600,
// //   //             fontSize: 14,
// //   //             color: active ? Colors.white : const Color(0xFF4B5563),
// //   //           ),
// //   //         ),
// //   //       ),
// //   //     ),
// //   //   );
// //   // }
// //  Padding(
// //                 padding: const EdgeInsets.all(12),
// //                 child: Row(
// //                   children: [
// //                     Container(
// //                       width: 4,
// //                       height: 32,
// //                       decoration: const BoxDecoration(
// //                         borderRadius: BorderRadius.all(Radius.circular(2)),
// //                         gradient: LinearGradient(
// //                           colors: [
// //                             Color(0xFF3B82F6),
// //                             Color.fromARGB(255, 108, 124, 146),
// //                           ],
// //                           begin: Alignment.topCenter,
// //                           end: Alignment.bottomCenter,
// //                         ),
// //                       ),
// //                     ),
// //                     const SizedBox(width: 8),
// //                     const Text(
// //                       "My Orders",
// //                       style: TextStyle(
// //                         fontSize: 28,
// //                         fontWeight: FontWeight.bold,
// //                         color: Color(0xFF111827),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
//  Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: Container(
//                     padding: const EdgeInsets.all(6),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(16),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.15),
//                           blurRadius: 20,
//                           spreadRadius: 2,
//                           offset: const Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                   )),
