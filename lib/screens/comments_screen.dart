import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/comment.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Screen with two tabs: Enviar (send anonymous comments) and Recibir (inbox).
class CommentsScreen extends StatefulWidget {
  /// The currently authenticated user.
  final UserModel currentUser;

  /// Creates a [CommentsScreen].
  const CommentsScreen({super.key, required this.currentUser});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = true;
  CleaningSchedule? _currentWeekSchedule;
  UserModel? _responsible;
  List<Comment> _receivedComments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final schedule = await SupabaseService.instance.getCurrentWeekSchedule();
      UserModel? responsible;
      List<Comment> comments = [];

      if (schedule != null) {
        final users = await SupabaseService.instance.getUsers();
        responsible = users.firstWhere(
          (u) => u.id == schedule.userId,
          orElse: () => const UserModel(id: '', name: '?', apartment: ''),
        );

        // Load comments if current user is the responsible one
        if (schedule.userId == widget.currentUser.id) {
          comments = await SupabaseService.instance.getCommentsForSchedule(
            schedule.id,
          );
        }
      }

      if (mounted) {
        setState(() {
          _currentWeekSchedule = schedule;
          _responsible = responsible;
          _receivedComments = comments;
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

  /// Builds the Enviar (send) tab content.
  Widget _buildSendTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 48, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Enviar Comentario Anónimo',
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
                      '${_responsible!.name} — ${_responsible!.apartment}',
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
        ],
      ),
    );
  }

  /// Builds the Recibir (receive) tab content.
  Widget _buildReceiveTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isResponsible =
        _currentWeekSchedule != null &&
        _currentWeekSchedule!.userId == widget.currentUser.id;

    if (isResponsible) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Buzón de Comentarios',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
            if (_receivedComments.isEmpty)
              const Center(child: Text('No tienes comentarios aún'))
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final comment in _receivedComments)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.secondaryContainer,
                            child: Icon(
                              Icons.person_off,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          title: Text(comment.message),
                          subtitle: Text(_formatTime(comment.createdAt)),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    // Not the responsible user — show locked empty state.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Buzón no disponible',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 280,
              child: Text(
                'Solo puedes ver comentarios cuando eres el responsable del aseo',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.send_outlined), text: 'Enviar'),
            Tab(icon: Icon(Icons.inbox_outlined), text: 'Recibir'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildSendTab(), _buildReceiveTab()],
          ),
        ),
      ],
    );
  }
}
