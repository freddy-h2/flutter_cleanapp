import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/realtime_service.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/comment.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

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

  bool _isLoading = true;
  CleaningSchedule? _currentWeekSchedule;
  UserModel? _responsible;
  bool _isResponsible = false;

  /// For sender view: the user's own sent comments with replies.
  Map<Comment, List<Comment>> _myCommentsWithReplies = {};

  /// For inbox view: all top-level comments with their replies.
  Map<Comment, List<Comment>> _commentsWithReplies = {};

  /// Reply controllers — one per comment being replied to.
  final Map<String, TextEditingController> _replyControllers = {};

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
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
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

  /// Sends a reply to [parentComment] from the responsible user.
  Future<void> _sendReply(Comment parentComment) async {
    final controller = _replyControllers[parentComment.id];
    if (controller == null || controller.text.trim().isEmpty) return;

    try {
      await SupabaseService.instance.sendComment(
        _currentWeekSchedule!.id,
        controller.text.trim(),
        senderId: widget.currentUser.id,
        parentId: parentComment.id,
      );
      if (mounted) {
        controller.clear();
        // Data will reload via Realtime subscription.
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

  /// Builds the sender view for non-responsible users.
  Widget _buildSenderView() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 48, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Comentarios Anónimos',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Tu mensaje será enviado de forma anónima',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            child: _responsible != null
                ? ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: const Text('Responsable actual'),
                    subtitle: Text(
                      '${_responsible!.name} — ${_responsible!.room}',
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay responsable asignado esta semana'),
                  ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 4,
            maxLength: 280,
            decoration: InputDecoration(
              hintText: 'Escribe tu comentario aquí...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _sendComment,
              icon: const Icon(Icons.send),
              label: const Text('Enviar Comentario'),
            ),
          ),
          if (_myCommentsWithReplies.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mis comentarios',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in _myCommentsWithReplies.entries)
              _buildSentCommentTile(entry.key, entry.value),
          ],
        ],
      ),
    );
  }

  /// Builds an [ExpansionTile] for a sent comment with its replies.
  Widget _buildSentCommentTile(Comment comment, List<Comment> replies) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(
          comment.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_formatTime(comment.createdAt)),
        children: [
          if (replies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Sin respuesta aún',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final reply in replies)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _responsible?.name ?? 'Responsable',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reply.message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(reply.createdAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Builds the inbox view for the responsible user.
  Widget _buildInboxView() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 48, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Buzón de Comentarios',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Comentarios anónimos de tus vecinos',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_commentsWithReplies.isEmpty)
            const Center(child: Text('No tienes comentarios aún'))
          else
            for (final entry in _commentsWithReplies.entries)
              _buildInboxCommentTile(entry.key, entry.value),
        ],
      ),
    );
  }

  /// Builds an expandable [Card] for an inbox comment with reply capability.
  Widget _buildInboxCommentTile(Comment comment, List<Comment> replies) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Ensure a reply controller exists for this comment.
    _replyControllers.putIfAbsent(comment.id, () => TextEditingController());
    final replyController = _replyControllers[comment.id]!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: Icon(
            Icons.person_off,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(comment.message),
        subtitle: Text(_formatTime(comment.createdAt)),
        children: [
          // Existing replies.
          for (final reply in replies)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tú',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reply.message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(reply.createdAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          // Quick reply suggestions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildSuggestionChip('Ok, enterado 👍', replyController),
                _buildSuggestionChip('Entendido ✅', replyController),
                _buildSuggestionChip('Trabajo en eso 🔧', replyController),
                _buildSuggestionChip(
                  '¡Gracias por avisar! 😊',
                  replyController,
                ),
                _buildSuggestionChip('Lo reviso pronto 🔍', replyController),
              ],
            ),
          ),
          // Reply input row.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: replyController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe una respuesta...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  tooltip: 'Enviar respuesta',
                  onPressed: () => _sendReply(comment),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a suggestion [ActionChip] that fills [controller] with [text].
  Widget _buildSuggestionChip(String text, TextEditingController controller) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        controller.text = text;
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
