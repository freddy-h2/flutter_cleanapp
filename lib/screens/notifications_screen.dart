import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/announcement.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen showing the full history of announcements for all users.
class NotificationsScreen extends StatefulWidget {
  /// Whether the current user has admin privileges.
  final bool isAdmin;

  /// Creates a [NotificationsScreen].
  const NotificationsScreen({super.key, required this.isAdmin});

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
          .getActiveAnnouncements();
      // Sort: updates first, then recordatorios, then avisos. Within each
      // group, newest first.
      announcements.sort((a, b) {
        final order = {
          AnnouncementType.update: 0,
          AnnouncementType.recordatorio: 1,
          AnnouncementType.aviso: 2,
        };
        final typeCompare = order[a.type]!.compareTo(order[b.type]!);
        if (typeCompare != 0) return typeCompare;
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
    final (
      IconData icon,
      Color cardColor,
      Color contentColor,
    ) = switch (announcement.type) {
      AnnouncementType.update => (
        CupertinoIcons.arrow_down_circle_fill,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      AnnouncementType.recordatorio => (
        CupertinoIcons.bell_fill,
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      AnnouncementType.aviso => (
        CupertinoIcons.speaker_2_fill,
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
    };

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: contentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: contentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(switch (announcement.type) {
                    AnnouncementType.aviso => 'Aviso',
                    AnnouncementType.recordatorio => 'Recordatorio',
                    AnnouncementType.update => 'Actualización',
                  }),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              announcement.message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: contentColor),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(announcement.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (announcement.type == AnnouncementType.update &&
                announcement.link != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(CupertinoIcons.square_arrow_down),
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Notificaciones'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF000000)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        border: null,
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _announcements.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.bell_slash,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay notificaciones',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _announcements.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (_, index) =>
                    _buildAnnouncementCard(_announcements[index]),
              ),
      ),
    );
  }
}
