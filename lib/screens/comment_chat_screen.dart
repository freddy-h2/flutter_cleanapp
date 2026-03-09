import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/realtime_service.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/comment.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// A WhatsApp-style individual chat screen for the responsible user to view
/// and reply to an anonymous comment conversation.
///
/// The [parentComment] is always shown as the first message (left-aligned).
/// Replies from the responsible user are right-aligned; all other replies
/// are left-aligned as anonymous messages.
class CommentChatScreen extends StatefulWidget {
  /// The top-level anonymous comment that started this conversation.
  final Comment parentComment;

  /// The initial list of replies to display.
  final List<Comment> initialReplies;

  /// The cleaning schedule this conversation belongs to.
  final CleaningSchedule schedule;

  /// The currently authenticated responsible user.
  final UserModel currentUser;

  /// Creates a [CommentChatScreen].
  const CommentChatScreen({
    super.key,
    required this.parentComment,
    required this.initialReplies,
    required this.schedule,
    required this.currentUser,
  });

  @override
  State<CommentChatScreen> createState() => _CommentChatScreenState();
}

class _CommentChatScreenState extends State<CommentChatScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late List<Comment> _replies;
  late final StreamSubscription<void> _commentsRealtimeSub;

  @override
  void initState() {
    super.initState();
    _replies = List<Comment>.from(widget.initialReplies);
    _commentsRealtimeSub = RealtimeService.instance.onCommentsChanged.listen((
      _,
    ) {
      if (mounted) {
        _reloadReplies();
      }
    });
  }

  @override
  void dispose() {
    _commentsRealtimeSub.cancel();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reloadReplies() async {
    try {
      final fresh = await SupabaseService.instance.getRepliesForComment(
        widget.parentComment.id,
      );
      if (mounted) {
        setState(() {
          _replies = fresh;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al recargar respuestas: $e')),
        );
      }
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    try {
      await SupabaseService.instance.sendComment(
        widget.schedule.id,
        text,
        senderId: widget.currentUser.id,
        parentId: widget.parentComment.id,
      );
      if (mounted) {
        _replyController.clear();
        // Scroll to bottom (index 0 because ListView is reversed).
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar respuesta: $e')),
        );
      }
    }
  }

  /// Returns a relative-time string in Spanish for [dateTime].
  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'Justo ahora';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} minutos';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} horas';
    } else {
      return 'Hace ${diff.inDays} días';
    }
  }

  /// Builds a chat bubble widget.
  ///
  /// [isMe] = true → right-aligned with [ColorScheme.primaryContainer].
  /// [isMe] = false → left-aligned with [ColorScheme.surfaceContainerHighest].
  Widget _buildChatBubble({
    required String message,
    required String time,
    required bool isMe,
    String? senderLabel,
    Color? bgColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    final backgroundColor =
        bgColor ??
        (isMe ? colorScheme.primaryContainer : colorScheme.secondaryContainer);
    final onColor = isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSecondaryContainer;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (senderLabel != null) ...[
                Text(
                  senderLabel,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onColor,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(color: onColor),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: textTheme.bodySmall?.copyWith(
                  color: onColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the quick-reply suggestion chips row.
  Widget _buildQuickReplyChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _buildSuggestionChip('Ok, enterado 👍'),
          _buildSuggestionChip('Entendido ✅'),
          _buildSuggestionChip('Trabajo en eso 🔧'),
          _buildSuggestionChip('¡Gracias por avisar! 😊'),
          _buildSuggestionChip('Lo reviso pronto 🔍'),
        ],
      ),
    );
  }

  /// Builds a single [ActionChip] that fills the reply [TextField] with [text].
  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        _replyController.text = text;
      },
    );
  }

  /// Builds the pinned input bar at the bottom of the screen.
  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                decoration: InputDecoration(
                  hintText: 'Escribe una respuesta...',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.paperplane_fill),
              tooltip: 'Enviar respuesta',
              onPressed: _sendReply,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Build the ordered list of messages: parentComment first, then replies
    // sorted chronologically.
    final sortedReplies = [..._replies]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // All messages in display order (oldest first).
    final allMessages = [widget.parentComment, ...sortedReplies];

    // Reversed for ListView(reverse: true) — last message at bottom.
    final reversedMessages = allMessages.reversed.toList();

    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: const Text('Comentario anónimo'),
        backgroundColor: colorScheme.surface.withValues(
          alpha: isDark ? 1.0 : 0.85,
        ),
        border: null,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: reversedMessages.length,
              itemBuilder: (context, index) {
                final msg = reversedMessages[index];
                final isMe = msg.senderId == widget.currentUser.id;
                return _buildChatBubble(
                  message: msg.message,
                  time: _formatTime(msg.createdAt),
                  isMe: isMe,
                  senderLabel: isMe ? 'Tú' : 'Anónimo',
                  bgColor: isMe ? null : colorScheme.surfaceContainerHighest,
                );
              },
            ),
          ),
          const Divider(height: 1),
          _buildQuickReplyChips(),
          _buildInputBar(),
        ],
      ),
    );
  }
}
