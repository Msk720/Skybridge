import 'package:http/http.dart' as http;
import 'package:skybridge02/Services/app_config.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';

Future<List<Map<String, dynamic>>> listData({
  required String collection,
  String? category,
}) async {
  if (category == null || category.isEmpty) {
    try {
      http.get(Uri.parse('${getFunctionsBase()}/autoExpireEntities'));
    } catch (_) {}
  }

  final endpoint = (category != null && category.isNotEmpty)
      ? "/listData?collection=$collection&category=$category"
      : "/listData?collection=$collection";

  final res = await ApiService.get(endpoint);

  final List data = res["data"] ?? [];

  return data.map<Map<String, dynamic>>((e) {
    final m = Map<String, dynamic>.from(e);
    m['id'] ??= m['_id']?.toString();
    return m;
  }).toList();
}
