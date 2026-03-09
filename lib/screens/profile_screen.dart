import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen that allows the current user to edit their name, room,
/// password, and email address.
class ProfileScreen extends StatefulWidget {
  /// The current user whose profile is being edited.
  final UserModel currentUser;

  /// Creates a [ProfileScreen].
  const ProfileScreen({super.key, required this.currentUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
        Navigator.pop(context, true); // Return true to signal changes
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Perfil'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                initialValue:
                    SupabaseConfig.client.auth.currentUser?.email ?? '',
                decoration: const InputDecoration(
                  labelText: 'Correo electronico',
                  prefixIcon: Icon(Icons.email),
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
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa tu nombre'
                    : null,
              ),
              const SizedBox(height: 16),
              // Room
              TextFormField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Cuarto',
                  prefixIcon: Icon(Icons.meeting_room),
                  hintText: 'Ej: Cuarto 3A',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa tu cuarto'
                    : null,
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cambiar Contraseña',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Current password
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrentPassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña actual',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrentPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
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
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureNewPassword = !_obscureNewPassword,
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
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Nuevo correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
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

              const SizedBox(height: 24),
            ],
          ),
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
