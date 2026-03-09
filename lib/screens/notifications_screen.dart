import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/announcement.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen showing the full history of announcements for all users.
class NotificationsScreen extends StatefulWidget {
  /// Creates a [NotificationsScreen].
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Announcement> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final announcements = await SupabaseService.instance
          .getAllAnnouncements();
      // Sort: update-type first, then avisos. Within each group, newest first.
      announcements.sort((a, b) {
        final aIsUpdate = a.type == AnnouncementType.update;
        final bIsUpdate = b.type == AnnouncementType.update;
        if (aIsUpdate && !bIsUpdate) return -1;
        if (!aIsUpdate && bIsUpdate) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      if (mounted) {
        setState(() {
          _announcements = announcements;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Opens [url] in an external browser or app.
  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Formats a [DateTime] as 'dd/MM/yyyy'.
  String _formatDate(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return '$dd/$mm/$yyyy';
  }

  /// Builds a card for the given [announcement].
  Widget _buildAnnouncementCard(Announcement announcement) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUpdate = announcement.type == AnnouncementType.update;

    return Card(
      color: isUpdate
          ? colorScheme.primaryContainer
          : colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUpdate ? Icons.system_update : Icons.campaign,
                  color: isUpdate
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isUpdate
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(isUpdate ? 'Actualización' : 'Aviso'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              announcement.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isUpdate
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(announcement.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!announcement.isActive) ...[
              const SizedBox(height: 4),
              Chip(
                label: const Text('Inactivo'),
                visualDensity: VisualDensity.compact,
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                labelStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
            if (isUpdate && announcement.link != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Descargar actualización'),
                onPressed: () => _openLink(announcement.link!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
          ? const Center(child: Text('No hay notificaciones'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _announcements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) =>
                  _buildAnnouncementCard(_announcements[index]),
            ),
    );
  }
}
