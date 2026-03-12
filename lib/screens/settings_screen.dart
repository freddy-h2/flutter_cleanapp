import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/admin/feedback_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Settings screen that combines profile editing with app configuration.
class SettingsScreen extends StatefulWidget {
  /// The currently authenticated user.
  final UserModel currentUser;

  /// Called after a successful profile save so the parent can refresh data.
  final VoidCallback? onProfileChanged;

  /// The current theme mode icon to display.
  final IconData themeModeIcon;

  /// Called when the user taps the theme toggle.
  final VoidCallback onToggleTheme;

  /// Called when the user taps the feedback option.
  final VoidCallback onSendFeedback;

  /// Called when the user taps logout.
  final VoidCallback onLogout;

  /// Creates a [SettingsScreen].
  const SettingsScreen({
    super.key,
    required this.currentUser,
    this.onProfileChanged,
    required this.themeModeIcon,
    required this.onToggleTheme,
    required this.onSendFeedback,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Profile fields
  late final TextEditingController _nameController;
  late final TextEditingController _roomController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _hasChanges = false;

  // Password fields
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _showPasswordSection = false;

  // Email fields
  final _newEmailController = TextEditingController();
  bool _isChangingEmail = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser.name);
    _roomController = TextEditingController(text: widget.currentUser.room);
    _nameController.addListener(_onChanged);
    _roomController.addListener(_onChanged);
  }

  void _onChanged() {
    final changed =
        _nameController.text.trim() != widget.currentUser.name ||
        _roomController.text.trim() != widget.currentUser.room;
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.updateProfile(
        name: _nameController.text.trim(),
        room: _roomController.text.trim(),
      );
      if (mounted) {
        widget.onProfileChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La nueva contraseña debe tener al menos 6 caracteres'),
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      final currentEmail = SupabaseConfig.client.auth.currentUser?.email ?? '';

      // Verify current password
      await SupabaseConfig.client.auth.signInWithPassword(
        email: currentEmail,
        password: currentPassword,
      );

      // Update to new password
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada exitosamente')),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _showPasswordSection = false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        final message = e.message.toLowerCase().contains('invalid')
            ? 'Contraseña actual incorrecta'
            : 'Error: ${e.message}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _forgotPassword() async {
    final currentEmail = SupabaseConfig.client.auth.currentUser?.email ?? '';
    if (currentEmail.isEmpty) return;
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(
        currentEmail,
        redirectTo: 'limpy://reset-callback',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se ha enviado un correo para restablecer tu contraseña',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _changeEmail() async {
    final newEmail = _newEmailController.text.trim();
    if (newEmail.isEmpty) return;

    setState(() => _isChangingEmail = true);
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(email: newEmail),
        emailRedirectTo: 'limpy://reset-callback',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se ha enviado un correo de verificación a tu correo actual',
            ),
          ),
        );
        _newEmailController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isChangingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar/icon
            Center(
              child: CircleAvatar(
                radius: 48,
                child: Text(
                  widget.currentUser.name.isNotEmpty
                      ? widget.currentUser.name[0].toUpperCase()
                      : '?',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Email (read-only)
            TextFormField(
              initialValue: SupabaseConfig.client.auth.currentUser?.email ?? '',
              decoration: const InputDecoration(
                labelText: 'Correo electronico',
                prefixIcon: Icon(CupertinoIcons.mail),
              ),
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 16),
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(CupertinoIcons.person),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
            ),
            const SizedBox(height: 16),
            // Room
            TextFormField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Cuarto',
                prefixIcon: Icon(CupertinoIcons.house),
                hintText: 'Ej: Cuarto 3A',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa tu cuarto' : null,
            ),
            const SizedBox(height: 32),
            // Save button
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: (_hasChanges && !_isSaving) ? _save : null,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Guardar cambios'),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // ── Change Password section ──────────────────────────────
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(CupertinoIcons.lock),
                    title: const Text('Cambiar Contraseña'),
                    trailing: Icon(
                      _showPasswordSection
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                    ),
                    onTap: () => setState(
                      () => _showPasswordSection = !_showPasswordSection,
                    ),
                  ),
                  if (_showPasswordSection) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Current password
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _obscureCurrentPassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña actual',
                              prefixIcon: const Icon(CupertinoIcons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureCurrentPassword
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                ),
                                onPressed: () => setState(
                                  () => _obscureCurrentPassword =
                                      !_obscureCurrentPassword,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // New password
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            decoration: InputDecoration(
                              labelText: 'Nueva contraseña',
                              prefixIcon: const Icon(CupertinoIcons.lock_fill),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPassword
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                ),
                                onPressed: () => setState(
                                  () => _obscureNewPassword =
                                      !_obscureNewPassword,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Confirm new password
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirmar nueva contraseña',
                              prefixIcon: const Icon(CupertinoIcons.lock_fill),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _isChangingPassword
                                  ? null
                                  : _changePassword,
                              child: _isChangingPassword
                                  ? const CircularProgressIndicator()
                                  : const Text('Cambiar Contraseña'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _forgotPassword,
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // ── Change Email section ─────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cambiar Correo Electrónico',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Nuevo correo electrónico',
                        prefixIcon: Icon(CupertinoIcons.mail),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isChangingEmail ? null : _changeEmail,
                        child: _isChangingEmail
                            ? const CircularProgressIndicator()
                            : const Text('Solicitar cambio'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // ── App Settings section ─────────────────────────────────
            Text(
              'Configuración de la App',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Theme toggle
            Card(
              child: ListTile(
                leading: Icon(widget.themeModeIcon),
                title: const Text('Cambiar tema'),
                subtitle: const Text(
                  'Alterna entre claro, oscuro y automático',
                ),
                onTap: widget.onToggleTheme,
              ),
            ),
            const SizedBox(height: 8),

            // Feedback
            Card(
              child: ListTile(
                leading: const Icon(CupertinoIcons.chat_bubble),
                title: const Text('Comentario sobre la App'),
                subtitle: const Text('Envía un comentario anónimo'),
                onTap: widget.onSendFeedback,
              ),
            ),
            const SizedBox(height: 8),

            // Admin: Gestionar Comunicados (only if admin)
            if (widget.currentUser.isAdmin) ...[
              Card(
                child: ListTile(
                  leading: const Icon(CupertinoIcons.speaker),
                  title: const Text('Gestionar Comunicados'),
                  subtitle: const Text('Administrar avisos y actualizaciones'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 16),

            // Logout button
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                icon: Icon(
                  CupertinoIcons.square_arrow_right,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: Text(
                  'Cerrar sesión',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onPressed: widget.onLogout,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }
}
