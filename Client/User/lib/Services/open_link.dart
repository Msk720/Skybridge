import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openLink(
  BuildContext context,
  String? url,
) async {
  if (url == null || url.isEmpty) return;

  final uri = Uri.tryParse(url);

  if (uri == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid URL')),
    );
    return;
  }

  try {
    bool success;

    if (kIsWeb) {
      success = await launchUrl(uri, webOnlyWindowName: '_blank');
    } else {
      success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }

    if (!success) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
