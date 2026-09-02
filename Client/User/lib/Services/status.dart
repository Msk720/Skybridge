import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:flutter/material.dart';

Future<void> updateEntityStatus({
  required String collection,
  required String id,
  required String status,
}) async {
  try {
    final res = await ApiService.post(
      "/updateEntityStatus",
      {
        "collection": collection,
        "id": id,
        "status": status,
      },
    );

    if (res['success'] != true) {
      throw Exception("Update failed");
    }
  } catch (e) {
    debugPrint("❌ updateEntityStatus error: $e");
    rethrow;
  }
}
