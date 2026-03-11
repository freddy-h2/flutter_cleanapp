import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/announcement.dart';
import 'package:flutter_cleanapp/models/feedback_model.dart';

/// Admin screen for viewing user feedback and managing announcements.
///
/// Has two tabs:
/// - **Comentarios**: Shows all anonymous app feedback with delete option.
/// - **Comunicados**: Shows all announcements with create/deactivate options.
class FeedbackScreen extends StatefulWidget {
  /// Creates a [FeedbackScreen].
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  List<FeedbackModel> _feedback = [];
  List<Announcement> _announcements = [];
  bool _isLoading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.instance.getAllFeedback(),
        SupabaseService.instance.getAllAnnouncements(),
      ]);
      if (mounted) {
        setState(() {
          _feedback = results[0] as List<FeedbackModel>;
          _announcements = results[1] as List<Announcement>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteFeedback(String feedbackId) async {
    try {
      await SupabaseService.instance.deleteFeedback(feedbackId);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  Future<void> _deactivateAnnouncement(String announcementId) async {
    try {
      await SupabaseService.instance.deactivateAnnouncement(announcementId);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al desactivar: $e')));
      }
    }
  }

  Future<void> _activateAnnouncement(String announcementId) async {
    try {
      await SupabaseService.instance.activateAnnouncement(announcementId);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al activar comunicado: $e')),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(String announcementId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar comunicado'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este comunicado? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.deleteAnnouncement(announcementId);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  Future<void> _showCreateAnnouncementDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final linkController = TextEditingController();
    AnnouncementType selectedType = AnnouncementType.aviso;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo Comunicado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Tipo:'),
                const SizedBox(height: 8),
                SegmentedButton<AnnouncementType>(
                  segments: const [
                    ButtonSegment(
                      value: AnnouncementType.aviso,
                      label: Text('Aviso'),
                      icon: Icon(Icons.campaign_outlined),
                    ),
                    ButtonSegment(
                      value: AnnouncementType.recordatorio,
                      label: Text('Recordatorio'),
                      icon: Icon(Icons.notifications_active_outlined),
                    ),
                    ButtonSegment(
                      value: AnnouncementType.update,
                      label: Text('Actualización'),
                      icon: Icon(Icons.system_update_outlined),
                    ),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (selection) {
                    setDialogState(() {
                      selectedType = selection.first;
                    });
                  },
                ),
                if (selectedType == AnnouncementType.update) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkController,
                    decoration: const InputDecoration(
                      labelText: 'Enlace de descarga',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true &&
        titleController.text.trim().isNotEmpty &&
        messageController.text.trim().isNotEmpty) {
      try {
        final userId = await SupabaseService.instance.getCurrentUser();
        if (userId == null) return;
        await SupabaseService.instance.createAnnouncement(
          senderId: userId.id,
          title: titleController.text.trim(),
          message: messageController.text.trim(),
          type: selectedType,
          link:
              selectedType == AnnouncementType.update &&
                  linkController.text.trim().isNotEmpty
              ? linkController.text.trim()
              : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comunicado publicado.')),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
        }
      }
    }

    titleController.dispose();
    messageController.dispose();
    linkController.dispose();
  }

  Future<void> _showEditAnnouncementDialog(Announcement announcement) async {
    final titleController = TextEditingController(text: announcement.title);
    final messageController = TextEditingController(text: announcement.message);
    final linkController = TextEditingController(text: announcement.link ?? '');
    AnnouncementType selectedType = announcement.type;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar Comunicado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Tipo:'),
                const SizedBox(height: 8),
                SegmentedButton<AnnouncementType>(
                  segments: const [
                    ButtonSegment(
                      value: AnnouncementType.aviso,
                      label: Text('Aviso'),
                      icon: Icon(Icons.campaign_outlined),
                    ),
                    ButtonSegment(
                      value: AnnouncementType.recordatorio,
                      label: Text('Recordatorio'),
                      icon: Icon(Icons.notifications_active_outlined),
                    ),
                    ButtonSegment(
                      value: AnnouncementType.update,
                      label: Text('Actualización'),
                      icon: Icon(Icons.system_update_outlined),
                    ),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (selection) {
                    setDialogState(() {
                      selectedType = selection.first;
                    });
                  },
                ),
                if (selectedType == AnnouncementType.update) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkController,
                    decoration: const InputDecoration(
                      labelText: 'Enlace de descarga',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true &&
        titleController.text.trim().isNotEmpty &&
        messageController.text.trim().isNotEmpty) {
      try {
        await SupabaseService.instance.updateAnnouncement(
          announcementId: announcement.id,
          title: titleController.text.trim(),
          message: messageController.text.trim(),
          type: selectedType,
          link:
              selectedType == AnnouncementType.update &&
                  linkController.text.trim().isNotEmpty
              ? linkController.text.trim()
              : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comunicado actualizado.')),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
        }
      }
    }

    titleController.dispose();
    messageController.dispose();
    linkController.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  Widget _buildFeedbackTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feedback.isEmpty) {
      return const Center(
        child: Text(
          'No hay comentarios sobre la app',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _feedback.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _feedback[index];
        return Card(
          child: ListTile(
            title: Text(item.message),
            subtitle: Text(_formatDate(item.createdAt)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: () => _deleteFeedback(item.id),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        _announcements.isEmpty
            ? const Center(
                child: Text(
                  'No hay comunicados',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _announcements.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _announcements[index];
                  final IconData typeIcon = switch (item.type) {
                    AnnouncementType.aviso => Icons.campaign,
                    AnnouncementType.recordatorio => Icons.notifications_active,
                    AnnouncementType.update => Icons.system_update,
                  };
                  final String typeLabel = switch (item.type) {
                    AnnouncementType.aviso => 'Aviso',
                    AnnouncementType.recordatorio => 'Recordatorio',
                    AnnouncementType.update => 'Actualización',
                  };
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(typeIcon, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Editar',
                                    onPressed: () =>
                                        _showEditAnnouncementDialog(item),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    tooltip: 'Eliminar',
                                    onPressed: () =>
                                        _deleteAnnouncement(item.id),
                                  ),
                                  if (item.isActive)
                                    TextButton(
                                      onPressed: () =>
                                          _deactivateAnnouncement(item.id),
                                      child: const Text('Desactivar'),
                                    )
                                  else
                                    TextButton(
                                      onPressed: () =>
                                          _activateAnnouncement(item.id),
                                      child: const Text('Activar'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(item.message),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Chip(
                                label: Text(typeLabel),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(item.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          if (item.type == AnnouncementType.update &&
                              item.link != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.link!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: _showCreateAnnouncementDialog,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo comunicado'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Comunicados'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : null,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.feedback_outlined), text: 'Comentarios'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Comunicados'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFeedbackTab(), _buildAnnouncementsTab()],
      ),
    );
  }
}
