import 'package:flutter/material.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';

Future<void> handleDelete({
  required BuildContext context,
  required Map<String, dynamic> item,
  required String collection,
  required Function(String id) onSuccessRemove,
  required Function(bool loading) setLoading,
  String title = "Delete",
  String message = "This cannot be undone.",
}) async {
  final id = item['id']?.toString();

  if (id == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Missing id')),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ) ??
      false;

  if (!confirmed) return;

  setLoading(true);

  bool ok = false;

  try {
    final result = await ApiService.post(
      "/deleteData",
      {
        "collection": collection,
        "id": id,
      },
    );

    ok = result["success"] == true;
  } catch (e) {
    debugPrint("Delete error: $e");
  }

  setLoading(false);
  if (!context.mounted) return;

  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to delete')),
    );
    return;
  }

  onSuccessRemove(id);

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Deleted Sucscessfully')),
  );
}
