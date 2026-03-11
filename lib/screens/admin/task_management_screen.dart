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
    final messenger = ScaffoldMessenger.of(context);
    final taskCount = _tasks.length;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: CloseButton(onPressed: () => Navigator.pop(context)),
            title: const Text('Agregar actividad'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();
                    Navigator.pop(context);
                    SupabaseService.instance
                        .createTask(
                          title,
                          taskCount + 1,
                          description: description.isEmpty ? null : description,
                        )
                        .then((_) => _loadTasks())
                        .catchError((Object e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error al agregar actividad: $e'),
                            ),
                          );
                        });
                  },
                  child: const Text('Agregar'),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la actividad',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'El nombre no puede estar vacío'
                        : null,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 5,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Descripción de la actividad',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(CleaningTask task) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    final messenger = ScaffoldMessenger.of(context);

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: CloseButton(onPressed: () => Navigator.pop(context)),
            title: const Text('Editar actividad'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final newTitle = titleController.text.trim();
                    final newDescription = descriptionController.text.trim();
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
                            SnackBar(
                              content: Text('Error al editar actividad: $e'),
                            ),
                          );
                        });
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la actividad',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'El nombre no puede estar vacío'
                        : null,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 5,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Descripción de la actividad',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTask(CleaningTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${task.title}"?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.instance.deleteTask(task.id);
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Actividad eliminada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar actividad: $e')),
        );
      }
    }
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : null,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : null,
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
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => _deleteTask(task),
                            tooltip: 'Eliminar',
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
