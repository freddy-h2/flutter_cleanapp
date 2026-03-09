import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_task.dart';

/// Admin screen for managing the cleaning task checklist items.
///
/// Allows adding, editing, reordering, and activating/deactivating tasks.
class TaskManagementScreen extends StatefulWidget {
  /// Creates a [TaskManagementScreen].
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  List<CleaningTask> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await SupabaseService.instance.getAllTasks();
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar actividades: $e')),
        );
      }
    }
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar actividad'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la actividad',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'El nombre no puede estar vacío'
                    : null,
                autofocus: true,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripcion de la actividad',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              final messenger = ScaffoldMessenger.of(this.context);
              Navigator.pop(context);
              SupabaseService.instance
                  .createTask(
                    title,
                    _tasks.length + 1,
                    description: description.isEmpty ? null : description,
                  )
                  .then((_) => _loadTasks())
                  .catchError((Object e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error al agregar actividad: $e')),
                    );
                  });
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(CleaningTask task) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar actividad'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la actividad',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'El nombre no puede estar vacío'
                    : null,
                autofocus: true,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripcion de la actividad',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final newTitle = titleController.text.trim();
              final newDescription = descriptionController.text.trim();
              final messenger = ScaffoldMessenger.of(this.context);
              Navigator.pop(context);
              SupabaseService.instance
                  .updateTask(
                    task.id,
                    title: newTitle,
                    description: newDescription,
                  )
                  .then((_) => _loadTasks())
                  .catchError((Object e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error al editar actividad: $e')),
                    );
                  });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(CleaningTask task, bool value) async {
    try {
      await SupabaseService.instance.updateTask(task.id, isActive: value);
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar actividad: $e')),
        );
      }
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final task = _tasks.removeAt(oldIndex);
    _tasks.insert(newIndex, task);
    setState(() {});
    try {
      for (var i = 0; i < _tasks.length; i++) {
        await SupabaseService.instance.updateTask(
          _tasks[i].id,
          sortOrder: i + 1,
        );
      }
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reordenar actividades: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Actividades'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Agregar actividad',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView(
              onReorder: _onReorder,
              children: [
                for (final task in _tasks)
                  Card(
                    key: ValueKey(task.id),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: _tasks.indexOf(task),
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(task.title),
                      subtitle: Text(
                        'Orden: ${task.sortOrder}'
                        '${task.isActive ? '' : ' — Inactiva'}'
                        '${task.description.isNotEmpty ? '\n${task.description}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditDialog(task),
                            tooltip: 'Editar',
                          ),
                          Switch(
                            value: task.isActive,
                            onChanged: (value) => _toggleActive(task, value),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
