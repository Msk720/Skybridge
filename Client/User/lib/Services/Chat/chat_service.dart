import 'package:flutter/material.dart';
import 'package:skybridge02/CommunicationManagement/chatscreen.dart';

class ChatService {
  /// Open support chat
  static Future<void> openChat({
    required BuildContext context,
    required String otherUserId,
    String? otherUserName,
    String? otherUserImage,
    String source = "peer",
    String senderRole = "",
    String receiverRole = "",
  }) async {
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: getChatId(otherUserId, source),
          otherUserId: otherUserId,
          otherUserName: otherUserName ?? (source == "support" ? "Customer Support" : "User"),
          otherUserImage: otherUserImage ?? "",
          source: source,
          senderRole: senderRole,
          receiverRole: receiverRole,
        ),
      ),
    );
  }

  /// Helper method retained to avoid breaking existing code.
  static String getChatId(String otherUserId, [String source = "peer"]) {
    if (source == "dispute") return "dispute-chat";
    if (source == "support" || otherUserId == "admin") return "support-chat";
    return "peer-$otherUserId";
  }

  /// Helper retained for compatibility.
  static Future<String?> ensureChat(String otherUserId) async {
    return "admin";
  }
}
