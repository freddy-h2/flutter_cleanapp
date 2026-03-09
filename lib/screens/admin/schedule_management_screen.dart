import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/utils/cycle_generator.dart';

/// Admin screen for managing cleaning schedules.
///
/// Allows admins to view, add, edit, and delete schedule entries.
class ScheduleManagementScreen extends StatefulWidget {
  /// Creates a [ScheduleManagementScreen].
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  List<CleaningSchedule> _schedules = [];
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await SupabaseService.instance.getSchedules();
      final users = await SupabaseService.instance.getUsers();
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
    }
  }

  String _userName(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId).name;
    } catch (_) {
      return userId;
    }
  }

  String _userRoom(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId).room;
    } catch (_) {
      return '';
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  Future<void> _showAddDialog() async {
    UserModel? selectedUser = _users.isNotEmpty ? _users.first : null;
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Agregar fecha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<UserModel>(
                    initialValue: selectedUser,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                    items: _users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text('${u.name} — ${u.room}'),
                          ),
                        )
                        .toList(),
                    onChanged: (u) => setDialogState(() => selectedUser = u),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Fecha: ${_formatDate(selectedDate)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Se crearán 3 días consecutivos de aseo a partir de la '
                    'fecha seleccionada',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selectedUser == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            for (
                              var i = 0;
                              i < SupabaseService.cleaningPeriodDays;
                              i++
                            ) {
                              final date = selectedDate.add(Duration(days: i));
                              await SupabaseService.instance.createSchedule(
                                CleaningSchedule(
                                  id: '',
                                  userId: selectedUser!.id,
                                  date: date,
                                ),
                              );
                            }
                            await _loadData();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al agregar: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(CleaningSchedule schedule) async {
    UserModel? selectedUser;
    try {
      selectedUser = _users.firstWhere((u) => u.id == schedule.userId);
    } catch (_) {
      selectedUser = _users.isNotEmpty ? _users.first : null;
    }
    DateTime selectedDate = schedule.date;
    bool isCompleted = schedule.isCompleted;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Editar fecha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<UserModel>(
                    initialValue: selectedUser,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                    items: _users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text('${u.name} — ${u.room}'),
                          ),
                        )
                        .toList(),
                    onChanged: (u) => setDialogState(() => selectedUser = u),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Fecha: ${_formatDate(selectedDate)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Completado'),
                    value: isCompleted,
                    onChanged: (v) =>
                        setDialogState(() => isCompleted = v ?? false),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selectedUser == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await SupabaseService.instance.updateSchedule(
                              schedule.id,
                              date: selectedDate,
                              userId: selectedUser!.id,
                              isCompleted: isCompleted,
                            );
                            await _loadData();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al guardar: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeletePeriod(_SchedulePeriod period) async {
    final userName = _userName(period.userId);
    final firstDate = _formatDate(period.schedules.first.date);
    final lastDate = _formatDate(period.schedules.last.date);
    final dateText = period.schedules.length > 1
        ? 'del $firstDate al $lastDate'
        : 'del $firstDate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar periodo'),
        content: Text('¿Eliminar el periodo de $userName $dateText?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final schedule in period.schedules) {
          await SupabaseService.instance.deleteSchedule(schedule.id);
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  Future<void> _showCycleGeneratorDialog() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _CycleGeneratorPage(users: _users),
      ),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Calendario'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generar por ciclos',
            onPressed: _showCycleGeneratorDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Agregar fecha',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
          ? const Center(child: Text('No hay entradas en el calendario.'))
          : Builder(
              builder: (context) {
                // Group consecutive same-user schedules into periods.
                final periods = <_SchedulePeriod>[];
                for (final schedule in _schedules) {
                  if (periods.isNotEmpty &&
                      periods.last.userId == schedule.userId) {
                    periods.last.schedules.add(schedule);
                  } else {
                    periods.add(
                      _SchedulePeriod(
                        userId: schedule.userId,
                        schedules: [schedule],
                      ),
                    );
                  }
                }
                return ListView.builder(
                  itemCount: periods.length,
                  itemBuilder: (context, index) {
                    final period = periods[index];
                    final firstDate = period.schedules.first.date;
                    final lastDate = period.schedules.last.date;
                    final allCompleted = period.schedules.every(
                      (s) => s.isCompleted,
                    );

                    final dateText = period.schedules.length > 1
                        ? '${_formatDate(firstDate)} al '
                              '${_formatDate(lastDate)}'
                        : _formatDate(firstDate);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        title: Text(_userName(period.userId)),
                        subtitle: Text(
                          '${_userRoom(period.userId)} · $dateText',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              allCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: allCompleted ? Colors.green : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar',
                              onPressed: () =>
                                  _showEditDialog(period.schedules.first),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Eliminar',
                              onPressed: () => _confirmDeletePeriod(period),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Full-screen page for generating cleaning schedules by cycles.
class _CycleGeneratorPage extends StatefulWidget {
  const _CycleGeneratorPage({required this.users});

  /// All available users to select from.
  final List<UserModel> users;

  @override
  State<_CycleGeneratorPage> createState() => _CycleGeneratorPageState();
}

class _CycleGeneratorPageState extends State<_CycleGeneratorPage> {
  late final Map<String, bool> _selectedUsers;
  DateTime _startDate = DateTime.now();
  final _periodDaysController = TextEditingController(text: '3');
  final _numberOfCyclesController = TextEditingController(text: '1');
  List<CycleScheduleEntry> _previewEntries = [];
  bool _previewGenerated = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedUsers = {for (final u in widget.users) u.id: false};
  }

  @override
  void dispose() {
    _periodDaysController.dispose();
    _numberOfCyclesController.dispose();
    super.dispose();
  }

  bool get _anyUserSelected =>
      _selectedUsers.values.any((selected) => selected);

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  int _clampedInt(String text, int min, int max, int fallback) {
    final parsed = int.tryParse(text.trim());
    if (parsed == null) return fallback;
    return parsed.clamp(min, max);
  }

  void _generatePreview() {
    final periodDays = _clampedInt(_periodDaysController.text, 1, 7, 3);
    final numberOfCycles = _clampedInt(
      _numberOfCyclesController.text,
      1,
      12,
      1,
    );

    final selectedUsers = widget.users
        .where((u) => _selectedUsers[u.id] == true)
        .map((u) => (id: u.id, name: u.name))
        .toList();

    final entries = CycleGenerator.generate(
      users: selectedUsers,
      startDate: _startDate,
      periodDays: periodDays,
      numberOfCycles: numberOfCycles,
    );

    setState(() {
      _previewEntries = entries;
      _previewGenerated = true;
    });
  }

  Future<void> _confirmAndSave() async {
    setState(() => _isSaving = true);
    try {
      final schedules = _previewEntries
          .map((e) => CleaningSchedule(id: '', userId: e.userId, date: e.date))
          .toList();
      await SupabaseService.instance.createSchedulesBatch(schedules);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Calendario generado exitosamente!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildPreview() {
    if (!_previewGenerated) return const SizedBox.shrink();

    // Group entries by cycle number.
    final Map<int, List<CycleScheduleEntry>> byCycle = {};
    for (final entry in _previewEntries) {
      byCycle.putIfAbsent(entry.cycleNumber, () => []).add(entry);
    }

    final cycleNumbers = byCycle.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Total: ${_previewEntries.length} entradas',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final cycleNum in cycleNumbers) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Ciclo $cycleNum',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ..._buildCycleCards(byCycle[cycleNum]!),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving ? null : _confirmAndSave,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirmar y guardar'),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCycleCards(List<CycleScheduleEntry> entries) {
    // Group by userId to show date range per user.
    final Map<String, List<CycleScheduleEntry>> byUser = {};
    for (final entry in entries) {
      byUser.putIfAbsent(entry.userId, () => []).add(entry);
    }

    return byUser.entries.map((e) {
      final userEntries = e.value..sort((a, b) => a.date.compareTo(b.date));
      final firstName = _formatShortDate(userEntries.first.date);
      final lastName = _formatShortDate(userEntries.last.date);
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          title: Text(userEntries.first.userName),
          subtitle: Text('$firstName al $lastName'),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        widget.users.isNotEmpty &&
        widget.users.every((u) => _selectedUsers[u.id] == true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar por Ciclos'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- User selection ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Usuarios',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      final newValue = !allSelected;
                      for (final key in _selectedUsers.keys) {
                        _selectedUsers[key] = newValue;
                      }
                    });
                  },
                  child: Text(
                    allSelected ? 'Deseleccionar todos' : 'Seleccionar todos',
                  ),
                ),
              ],
            ),
            for (final user in widget.users)
              CheckboxListTile(
                title: Text('${user.name} — ${user.room}'),
                value: _selectedUsers[user.id] ?? false,
                onChanged: (v) {
                  setState(() => _selectedUsers[user.id] = v ?? false);
                },
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 16),

            // --- Start date ---
            Row(
              children: [
                Expanded(
                  child: Text('Fecha inicial: ${_formatDate(_startDate)}'),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 2),
                      ),
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                    }
                  },
                  child: const Text('Seleccionar'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Period days ---
            Row(
              children: [
                const Expanded(child: Text('Días de aseo por usuario:')),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _periodDaysController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Number of cycles ---
            Row(
              children: [
                const Expanded(child: Text('Número de ciclos:')),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _numberOfCyclesController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Preview button ---
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _anyUserSelected ? _generatePreview : null,
                child: const Text('Vista previa'),
              ),
            ),

            // --- Preview section ---
            _buildPreview(),
          ],
        ),
      ),
    );
  }
}

/// Groups consecutive same-user [CleaningSchedule] entries into a period.
class _SchedulePeriod {
  _SchedulePeriod({required this.userId, required this.schedules});

  /// The user ID shared by all schedules in this period.
  final String userId;

  /// The schedules belonging to this period (consecutive days).
  final List<CleaningSchedule> schedules;
}
