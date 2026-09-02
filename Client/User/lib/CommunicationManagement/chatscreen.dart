import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/app_config.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'package:skybridge02/Theme/app_color.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;
  final String source;
  final String senderRole;
  final String receiverRole;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    this.source = 'support',
    this.senderRole = '',
    this.receiverRole = '',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool loading = true;
  bool sending = false;

  List<Map<String, dynamic>> messages = [];

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> loadMessages() async {
    try {
      setState(() => loading = true);

      final response = await ApiService.get("/api/messages/my");
      final List<dynamic> data = response is List ? response : [];
      final List<Map<String, dynamic>> loadedMessages = [];

      for (final item in data) {
        final msg = Map<String, dynamic>.from(item);
        if (!_belongsToThisChat(msg, _currentUid)) continue;

        loadedMessages.add(msg);

        if (msg['replies'] is List) {
          for (final reply in msg['replies']) {
            loadedMessages.add({
              'message': reply['message'] ?? '',
              'imageUrl': reply['imageUrl'] ?? '',
              'messageType': reply['messageType'] ?? 'text',
              'sender': reply['sender'] ?? 'admin',
              'senderId': reply['senderId'] ?? 'admin',
              'createdAt': reply['createdAt'] ?? msg['createdAt'],
            });
          }
        }
      }

      loadedMessages.sort(
        (a, b) =>
            _safeDate(a["createdAt"]).compareTo(_safeDate(b["createdAt"])),
      );

      setState(() {
        messages = loadedMessages;
        loading = false;
      });
    } catch (e) {
      debugPrint("Load messages error: $e");
      setState(() => loading = false);
    }
  }

  DateTime _safeDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _belongsToThisChat(Map<String, dynamic> msg, String currentUid) {
    final source = (msg['source'] ?? '').toString().toLowerCase();
    final senderId = (msg['senderId'] ?? msg['userId'] ?? '').toString();
    final receiverId = (msg['receiverId'] ?? '').toString();

    if (widget.source == 'peer') {
      if (source != 'peer') return false;
      return (senderId == currentUid && receiverId == widget.otherUserId) ||
          (senderId == widget.otherUserId && receiverId == currentUid);
    }

    if (widget.source == 'dispute') {
      return source == 'dispute' &&
          (receiverId == currentUid ||
              senderId == currentUid ||
              receiverId == 'admin');
    }

    // Support chat must also show chats that admin opened first from the
    // dashboard or from a dispute. Those messages have senderId="admin" and
    // receiverId=current user, so do not require receiverId="admin" only.
    final bool userToAdmin = receiverId == 'admin' && senderId == currentUid;
    final bool adminToUser = senderId == 'admin' && receiverId == currentUid;
    return source == 'support' || userToAdmin || adminToUser;
  }

  Future<String> _uploadImage(Uint8List bytes) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudinarycloudname/auto/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = cloudinaryuploadpreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'chat_image.jpg'),
      );

    final response = await http.Response.fromStream(await request.send());
    final decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Image upload failed: $decoded');
    }

    return decoded['secure_url']?.toString() ?? '';
  }

  Future<void> sendImage() async {
    if (sending) return;

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => sending = true);
      final imageUrl = await _uploadImage(await image.readAsBytes());

      if (imageUrl.isEmpty) {
        throw Exception('Image URL is empty');
      }

      final saved = await _sendPayload(
        message: 'Image',
        imageUrl: imageUrl,
        messageType: 'image',
      );
      _addLocalMessage(saved,
          fallbackMessage: 'Image',
          fallbackImageUrl: imageUrl,
          fallbackType: 'image');

      await loadMessages();
    } catch (e) {
      debugPrint("Send image error: $e");
      _showError('Failed to send image');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;

    try {
      setState(() => sending = true);
      final saved = await _sendPayload(message: text);
      controller.clear();
      _addLocalMessage(saved, fallbackMessage: text);
      await loadMessages();
    } catch (e) {
      debugPrint("Send message error: $e");
      _showError('Failed to send message');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<Map<String, dynamic>> _sendPayload({
    required String message,
    String imageUrl = '',
    String messageType = 'text',
  }) async {
    final response = await ApiService.post("/api/messages", {
      "message": message,
      "imageUrl": imageUrl,
      "messageType": messageType,
      "subject": widget.source == "peer"
          ? "Messages"
          : widget.source == "dispute"
              ? "Dispute Messages"
              : "Support Messages",
      "source": widget.source,
      "receiverId": widget.source == "peer" ? widget.otherUserId : "admin",
      "receiverName": widget.otherUserName,
      "receiverImage": widget.otherUserImage,
      "senderRole": widget.senderRole,
      "receiverRole": widget.receiverRole,
    });

    return Map<String, dynamic>.from(response);
  }

  void _addLocalMessage(
    Map<String, dynamic> saved, {
    required String fallbackMessage,
    String fallbackImageUrl = '',
    String fallbackType = 'text',
  }) {
    final local = <String, dynamic>{
      ...saved,
      'message': (saved['message'] ?? fallbackMessage).toString(),
      'imageUrl': (saved['imageUrl'] ?? fallbackImageUrl).toString(),
      'messageType': (saved['messageType'] ?? fallbackType).toString(),
      'senderId': (saved['senderId'] ?? _currentUid).toString(),
      'receiverId': (saved['receiverId'] ??
              (widget.source == 'peer' ? widget.otherUserId : 'admin'))
          .toString(),
      'sender': (saved['sender'] ?? 'user').toString(),
      'source': (saved['source'] ?? widget.source).toString(),
      'createdAt':
          (saved['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
    };

    if (!mounted) return;
    setState(() {
      final localId = local['_id']?.toString() ?? '';
      if (localId.isNotEmpty) {
        messages.removeWhere((item) => item['_id']?.toString() == localId);
      }
      messages.add(local);
      messages.sort((a, b) =>
          _safeDate(a['createdAt']).compareTo(_safeDate(b['createdAt'])));
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isMyMessage(Map<String, dynamic> message) {
    final senderId =
        (message['senderId'] ?? message['userId'] ?? '').toString();
    final receiverId = (message['receiverId'] ?? '').toString();
    final sender = (message['sender'] ?? '').toString().toLowerCase();

    if (senderId.isNotEmpty) return senderId == _currentUid;
    if (sender == 'admin') return false;
    if (receiverId == _currentUid) return false;
    return true;
  }

  String _formatTime(dynamic value) {
    final dt = _safeDate(value).toLocal();
    if (dt.millisecondsSinceEpoch == 0) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget buildMessageBubble(Map<String, dynamic> message) {
    final bool isMe = _isMyMessage(message);
    final imageUrl = (message['imageUrl'] ?? '').toString();
    final text = (message['message'] ?? '').toString();
    final time = _formatTime(message['createdAt']);
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.74;
    final imageWidth = MediaQuery.of(context).size.width * 0.56;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    imageUrl,
                    width: imageWidth,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 145,
                        width: imageWidth,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isMe ? Colors.white : AppColors.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => SizedBox(
                      height: 120,
                      width: imageWidth,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: isMe ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              if (text.isNotEmpty && (imageUrl.isEmpty || text != 'Image')) ...[
                if (imageUrl.isNotEmpty) const SizedBox(height: 8),
                Text(
                  text,
                  softWrap: true,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
              if (time.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: 'Send image',
                onPressed: sending ? null : sendImage,
                icon:
                    const Icon(Icons.image_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: sending ? null : sendMessage,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 21),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 62,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              backgroundImage: widget.otherUserImage.isNotEmpty
                  ? NetworkImage(widget.otherUserImage)
                  : null,
              child: widget.otherUserImage.isEmpty
                  ? const Icon(Icons.person_outline, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUserName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.source == 'peer'
                        ? 'Buyer and traveler messages'
                        : 'Support messages',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: loadMessages,
                    child: messages.isEmpty
                        ? emptyState(
                            icon: Icons.chat_bubble_outline,
                            title: 'No Messages Yet',
                            subtitle: 'Start the conversation below.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            itemCount: messages.length,
                            itemBuilder: (context, index) =>
                                buildMessageBubble(messages[index]),
                          ),
                  ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}
