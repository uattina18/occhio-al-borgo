import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:occhio_al_borgo/services/chat_service.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUsername;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await ChatService.sendMessage(widget.chatId, text);
    _controller.clear();

    // 🔽 Scorrimento automatico in basso
    await Future.delayed(const Duration(milliseconds: 150));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color myBubble = isDark
        ? const Color(0xFF3a602a)
        : const Color(0xFF91be7e);
    final Color otherBubble = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 20),
            const SizedBox(width: 6),
            Text(
              widget.otherUsername,
              style: const TextStyle(fontFamily: 'Cinzel'),
            ),
          ],
        ),
        backgroundColor: isDark
            ? const Color(0xFF3a602a)
            : const Color(0xFF91be7e),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 💬 Lista messaggi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ChatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == uid;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? myBubble : otherBubble,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(10),
                            topRight: const Radius.circular(10),
                            bottomLeft: isMe
                                ? const Radius.circular(10)
                                : const Radius.circular(0),
                            bottomRight: isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(10),
                          ),
                        ),
                        child: Text(
                          data['text'] ?? '',
                          style: TextStyle(
                            fontFamily: 'Cormorant',
                            fontSize: 15,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✍️ Input messaggio
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Scrivi un messaggio...',
                        hintStyle: TextStyle(
                          fontFamily: 'Cormorant',
                          color: Colors.grey.shade500,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Cormorant'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF3a602a),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
