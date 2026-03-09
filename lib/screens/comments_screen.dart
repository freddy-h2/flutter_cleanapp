import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/realtime_service.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/comment.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/comment_chat_screen.dart';

/// Screen that shows a single role-based view for comments.
///
/// Non-responsible users see a send form plus their own sent comments with
/// any replies from the responsible user.
/// The responsible user sees an inbox with all anonymous comments and can
/// reply to each one.
class CommentsScreen extends StatefulWidget {
  /// The currently authenticated user.
  final UserModel currentUser;

  /// Creates a [CommentsScreen].
  const CommentsScreen({super.key, required this.currentUser});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _senderScrollController = ScrollController();

  bool _isLoading = true;
  CleaningSchedule? _currentWeekSchedule;
  UserModel? _responsible;
  bool _isResponsible = false;

  /// For sender view: the user's own sent comments with replies.
  Map<Comment, List<Comment>> _myCommentsWithReplies = {};

  /// For inbox view: all top-level comments with their replies.
  Map<Comment, List<Comment>> _commentsWithReplies = {};

  late final StreamSubscription<void> _commentsRealtimeSub;
  late final StreamSubscription<void> _schedulesRealtimeSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _commentsRealtimeSub = RealtimeService.instance.onCommentsChanged.listen((
      _,
    ) {
      if (mounted) {
        _loadData();
      }
    });
    _schedulesRealtimeSub = RealtimeService.instance.onSchedulesChanged.listen((
      _,
    ) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _commentsRealtimeSub.cancel();
    _schedulesRealtimeSub.cancel();
    _messageController.dispose();
    _senderScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final schedule = await SupabaseService.instance.getCurrentWeekSchedule();
      UserModel? responsible;

      if (schedule != null) {
        final users = await SupabaseService.instance.getUsers();
        responsible = users.firstWhere(
          (u) => u.id == schedule.userId,
          orElse: () => const UserModel(id: '', name: '?', room: ''),
        );
      }

      final isResponsible =
          schedule != null && schedule.userId == widget.currentUser.id;

      Map<Comment, List<Comment>> commentsWithReplies = {};
      Map<Comment, List<Comment>> myComments = {};

      if (schedule != null) {
        if (isResponsible) {
          commentsWithReplies = await SupabaseService.instance
              .getCommentsWithReplies(schedule.id);
        } else {
          myComments = await SupabaseService.instance.getCommentsBySender(
            schedule.id,
            widget.currentUser.id,
          );
        }
      }

      if (mounted) {
        setState(() {
          _currentWeekSchedule = schedule;
          _responsible = responsible;
          _isResponsible = isResponsible;
          _commentsWithReplies = commentsWithReplies;
          _myCommentsWithReplies = myComments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar comentarios: $e')),
        );
      }
    }
  }

  /// Sends the comment typed in [_messageController].
  Future<void> _sendComment() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un comentario antes de enviar')),
      );
      return;
    }
    if (_currentWeekSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay responsable asignado esta semana'),
        ),
      );
      return;
    }
    try {
      await SupabaseService.instance.sendComment(
        _currentWeekSchedule!.id,
        text,
        senderId: widget.currentUser.id,
      );
      if (mounted) {
        _messageController.clear();
        // Scroll to bottom (index 0 since list is reversed).
        if (_senderScrollController.hasClients) {
          _senderScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Comentario enviado de forma anónima!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar comentario: $e')),
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
  /// [isMe] = false → left-aligned with [secondaryContainer] (sender view)
  /// or [surfaceContainerHighest] (inbox view, controlled by [bgColor]).
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
        (isMe
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest);
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

  /// Builds the sender view for non-responsible users (WhatsApp-style).
  Widget _buildSenderView() {
    return Column(
      children: [
        _buildSenderHeader(),
        Expanded(child: _buildSenderMessages()),
        _buildSenderInputBar(),
      ],
    );
  }

  /// Compact header showing the responsible user info.
  Widget _buildSenderHeader() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _responsible != null
              ? Row(
                  children: [
                    const CircleAvatar(child: Icon(CupertinoIcons.person_fill)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Responsable: ${_responsible!.name}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _responsible!.room,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Text(
                  'No hay responsable asignado esta semana',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  /// Scrollable message area showing all conversations chronologically.
  Widget _buildSenderMessages() {
    if (_myCommentsWithReplies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.bubble_left,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Envía un comentario anónimo',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Build a flat list of all bubbles in chronological order, then reverse
    // for the reversed ListView (newest at bottom).
    final entries = _myCommentsWithReplies.entries.toList()
      ..sort((a, b) => a.key.createdAt.compareTo(b.key.createdAt));

    final List<Widget> items = [];
    for (final entry in entries) {
      final comment = entry.key;
      final replies = [...entry.value]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      items.add(
        _buildChatBubble(
          message: comment.message,
          time: _formatTime(comment.createdAt),
          isMe: true,
        ),
      );
      for (final reply in replies) {
        items.add(
          _buildChatBubble(
            message: reply.message,
            time: _formatTime(reply.createdAt),
            isMe: false,
            senderLabel: _responsible?.name ?? 'Responsable',
          ),
        );
      }
      items.add(const SizedBox(height: 16));
    }

    // Reverse so that ListView(reverse: true) shows newest at bottom.
    final reversedItems = items.reversed.toList();

    return ListView.builder(
      controller: _senderScrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: reversedItems.length,
      itemBuilder: (_, index) => reversedItems[index],
    );
  }

  /// Input bar pinned at the bottom of the sender view.
  Widget _buildSenderInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: 1,
                maxLength: 280,
                decoration: InputDecoration(
                  hintText: 'Escribe un comentario...',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(CupertinoIcons.paperplane_fill),
              tooltip: 'Enviar comentario',
              onPressed: _sendComment,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the inbox view for the responsible user (WhatsApp-style
  /// conversation list).
  Widget _buildInboxView() {
    return Column(
      children: [
        _buildInboxHeader(),
        Expanded(child: _buildConversationList()),
      ],
    );
  }

  /// Compact header showing the inbox title and conversation count.
  Widget _buildInboxHeader() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final count = _commentsWithReplies.length;
    final subtitle = count == 0
        ? 'No tienes comentarios aún'
        : '$count conversaciones';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.tray, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Buzón de Comentarios',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  /// Builds the scrollable conversation list for the inbox.
  Widget _buildConversationList() {
    if (_commentsWithReplies.isEmpty) {
      return const Center(child: Text('No tienes comentarios aún'));
    }

    final entries = _commentsWithReplies.entries.toList()
      ..sort((a, b) => b.key.createdAt.compareTo(a.key.createdAt));

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final comment = entries[index].key;
        final replies = entries[index].value;
        final replyCount = replies.length;
        final preview = comment.message.length > 50
            ? '${comment.message.substring(0, 50)}…'
            : comment.message;
        final replyLabel = replyCount == 0
            ? 'Sin respuesta aún'
            : '💬 $replyCount respuestas';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              child: const Icon(CupertinoIcons.person_crop_circle_badge_xmark),
            ),
            title: const Text('Comentario anónimo'),
            subtitle: Text(
              '$preview\n$replyLabel',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatTime(comment.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            isThreeLine: true,
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => CommentChatScreen(
                    parentComment: comment,
                    initialReplies: replies,
                    schedule: _currentWeekSchedule!,
                    currentUser: widget.currentUser,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return _isResponsible ? _buildInboxView() : _buildSenderView();
  }
}
