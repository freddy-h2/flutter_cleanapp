import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Admin-only screen for managing building residents.
///
/// Allows viewing all users, changing their roles, and deleting accounts.
class UserManagementScreen extends StatefulWidget {
  /// Creates a [UserManagementScreen].
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await SupabaseService.instance.getUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar usuarios: $e')));
      }
    }
  }

  Future<void> _handleMenuAction(String action, UserModel user) async {
    if (action == 'toggle_role') {
      final newRole = user.isAdmin ? UserRole.user : UserRole.admin;
      final newRoleLabel = user.isAdmin ? 'Usuario' : 'Administrador';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar'),
          content: Text(
            '¿Estás seguro de cambiar el rol de ${user.name} a $newRoleLabel?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await SupabaseService.instance.updateUserRole(user.id, newRole);
        await _loadUsers();
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar'),
          content: Text('¿Estás seguro de eliminar a ${user.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await SupabaseService.instance.deleteUser(user.id);
        await _loadUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Administrar Usuarios'),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.85),
        border: null,
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: user.isAdmin
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        foregroundColor: user.isAdmin
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                        child: Icon(
                          user.isAdmin
                              ? Icons.admin_panel_settings
                              : Icons.person,
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text(
                        '${user.room} — ${user.isAdmin ? "Administrador" : "Usuario"}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => _handleMenuAction(value, user),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle_role',
                            child: Text(
                              user.isAdmin
                                  ? 'Cambiar a Usuario'
                                  : 'Cambiar a Administrador',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Eliminar usuario',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
