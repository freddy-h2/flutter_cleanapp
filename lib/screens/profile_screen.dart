import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Screen that allows the current user to edit their name and room.
class ProfileScreen extends StatefulWidget {
  /// The current user whose profile is being edited.
  final UserModel currentUser;

  /// Creates a [ProfileScreen].
  const ProfileScreen({super.key, required this.currentUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _roomController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _hasChanges = false;

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
    super.dispose();
  }
}
