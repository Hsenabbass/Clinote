import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mama/db/app_db.dart';
import 'package:mama/models/patient.dart';
import 'package:mama/repo/patient_repo.dart';
import 'package:mama/state/app_settings.dart';
import 'package:mama/ui/widgets/filter_bar.dart';
import 'package:mama/ui/widgets/patient_form_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = PatientRepo.instance;

  final _searchCtrl = TextEditingController();
  PatientFilters _filters = const PatientFilters();

  SortField _sortField = SortField.id;
  SortDir _sortDir = SortDir.asc;

  List<Patient> _rows = const [];
  bool _loading = true;

  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filters = _filters.copyWith(searchText: _searchCtrl.text);
    });
    _refresh();
  }

  Patient? get _selectedPatient {
    final id = _selectedId;
    if (id == null) return null;
    try {
      return _rows.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final items = await _repo.list(filters: _filters, sortField: _sortField, sortDir: _sortDir);
      if (!mounted) return;
      setState(() {
        _rows = items;
        if (_selectedId != null && !_rows.any((p) => p.id == _selectedId)) {
          _selectedId = null;
        }
      });
    } catch (e, st) {
      debugPrint('Patient list failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search failed. Please try again.')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addOrEdit({Patient? existing}) async {
    final defaultNumber = existing == null ? await _repo.nextPatientNumber() : existing.patientNumber;
    if (!mounted) return;
    final result = await showDialog<PatientFormResult>(
      context: context,
      builder: (_) => PatientFormDialog(existing: existing, defaultPatientNumber: defaultNumber),
    );
    if (result == null) return;

    final p = result.patient;
    if (p.patientNumber != null && p.patientNumber! < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient number must be ≥ 0.')),
      );
      return;
    }
    if (p.patientNumber != null) {
      final available = await _repo.isPatientNumberAvailable(
        p.patientNumber,
        excludeId: existing?.id,
      );
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient number already exists.')),
        );
        return;
      }
    }

    try {
      if (existing == null) {
        await _repo.create(p);
      } else {
        await _repo.update(p.copyWith(id: existing.id));
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _deleteSelected() async {
    final id = _selectedId;
    if (id == null) return;

    final patientNumber = _selectedPatient?.patientNumber;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete patient?'),
        content: Text(
          patientNumber == null
              ? 'This will permanently remove this patient.'
              : 'This will permanently remove patient #$patientNumber.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    await _repo.delete(id);
    setState(() => _selectedId = null);
    await _refresh();
  }

  Future<void> _exportDb() async {
    final sourcePath = await AppDb.instance.dbPath();
    final fileName = 'mama_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.db';

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export/Backup Database',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['db'],
    );
    if (path == null) return;

    await File(sourcePath).copy(path);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup saved: ${_shorten(path)}')),
    );
  }

  Future<void> _importDb() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import/Restore Database',
        type: FileType.custom,
        allowedExtensions: const ['db'],
      );
      if (res == null || res.files.single.path == null) return;

      final picked = res.files.single.path!;
      if (!await File(picked).exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected file is not accessible.')),
        );
        return;
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore database?'),
          content: Text(
            'This will replace your current local database with:\n${_shorten(picked)}\n\n'
            'Make sure you have a backup first.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
          ],
        ),
      );
      if (ok != true) return;

      await AppDb.instance.replaceDbFile(picked);

      final db = await AppDb.instance.db;
      final hasPatients = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='patients'",
      );
      if (hasPatients.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import failed: missing patients table.')),
        );
        return;
      }
      final countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM patients');
      final count = (countRows.first['c'] as int?) ?? 0;

      setState(() => _selectedId = null);
      await _refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database restored. $count patients found.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  String _shorten(String path) {
    if (path.length <= 70) return path;
    return '${path.substring(0, 26)}…${path.substring(path.length - 40)}';
  }

  void _toggleTheme() {
    final current = widget.settings.themeMode.value;
    final next = switch (current) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    widget.settings.setThemeMode(next);
  }

  IconData _themeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
    };
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.settings.themeMode.value;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dr Nesrine'),
        centerTitle: false,
        actions: [
          Tooltip(
            message: 'Theme: ${_themeLabel(mode)}',
            child: IconButton(
              onPressed: _toggleTheme,
              icon: Icon(_themeIcon(mode)),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) async {
              if (v == 'export') await _exportDb();
              if (v == 'import') await _importDb();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'export', child: Text('Export/Backup DB')),
              PopupMenuItem(value: 'import', child: Text('Import/Restore DB')),
            ],
          )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface,
              cs.surfaceContainerHighest,
              cs.surface,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1050;

                final sidebar = SizedBox(
                  width: isWide ? 420 : double.infinity,
                  child: _Sidebar(
                    searchCtrl: _searchCtrl,
                    filters: _filters,
                    onFiltersChanged: (f) {
                      setState(() => _filters = f);
                      _refresh();
                    },
                    sortField: _sortField,
                    sortDir: _sortDir,
                    onSortChanged: (f, d) {
                      setState(() {
                        _sortField = f;
                        _sortDir = d;
                      });
                      _refresh();
                    },
                    onAdd: () => _addOrEdit(),
                    onEdit: _selectedPatient == null ? null : () => _addOrEdit(existing: _selectedPatient),
                    onDelete: _selectedPatient == null ? null : _deleteSelected,
                    statsRows: _rows,
                  ),
                );

                final main = Expanded(
                  child: Column(
                    children: [
                      _MainHeader(
                        count: _rows.length,
                        selected: _selectedPatient,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _PatientTable(
                                  rows: _rows,
                                  selectedId: _selectedId,
                                  onSelect: (id) => setState(() => _selectedId = id),
                                  sortField: _sortField,
                                  sortDir: _sortDir,
                                  onSortFromHeader: (f, d) {
                                    setState(() {
                                      _sortField = f;
                                      _sortDir = d;
                                    });
                                    _refresh();
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: _DetailsPanel(
                          patient: _selectedPatient,
                          onEdit: _selectedPatient == null ? null : () => _addOrEdit(existing: _selectedPatient),
                          onDelete: _selectedPatient == null ? null : _deleteSelected,
                        ),
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sidebar,
                      const SizedBox(width: 16),
                      main,
                    ],
                  );
                }

                // Narrow layout: stack with scrolling
                return ListView(
                  children: [
                    sidebar,
                    const SizedBox(height: 16),
                    SizedBox(height: 520, child: main),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.searchCtrl,
    required this.filters,
    required this.onFiltersChanged,
    required this.sortField,
    required this.sortDir,
    required this.onSortChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.statsRows,
  });

  final TextEditingController searchCtrl;

  final PatientFilters filters;
  final ValueChanged<PatientFilters> onFiltersChanged;

  final SortField sortField;
  final SortDir sortDir;
  final void Function(SortField, SortDir) onSortChanged;

  final VoidCallback onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final List<Patient> statsRows;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Patients', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(
            controller: searchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search by ID, name, or phone…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          _SortRow(field: sortField, dir: sortDir, onChanged: onSortChanged),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
              FilledButton.tonalIcon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Filters', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilterBar(
            filters: filters,
            onChanged: onFiltersChanged,
          ),
          const SizedBox(height: 16),
          Text('Overview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _QuickStats(rows: statsRows),
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.field, required this.dir, required this.onChanged});

  final SortField field;
  final SortDir dir;
  final void Function(SortField, SortDir) onChanged;

  String _fieldLabel(SortField f) => switch (f) {
        SortField.id => 'ID',
        SortField.firstName => 'First name',
        SortField.fatherName => "Father's name",
        SortField.lastName => 'Last name',
        SortField.birthYear => 'Birth year',
        SortField.lastVisited => 'Last visited',
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MenuAnchor(
            builder: (context, controller, child) {
              return OutlinedButton.icon(
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.sort_rounded),
                label: Text('${_fieldLabel(field)} • ${dir == SortDir.asc ? "Asc" : "Desc"}'),
              );
            },
            menuChildren: [
              for (final f in SortField.values)
                MenuItemButton(
                  onPressed: () => onChanged(f, dir),
                  child: Text('Sort by ${_fieldLabel(f)}'),
                ),
              const Divider(),
              MenuItemButton(
                onPressed: () => onChanged(field, dir == SortDir.asc ? SortDir.desc : SortDir.asc),
                child: Text(dir == SortDir.asc ? 'Direction: Desc' : 'Direction: Asc'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MainHeader extends StatelessWidget {
  const _MainHeader({required this.count, required this.selected});

  final int count;
  final Patient? selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.table_rows_rounded, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient table', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '$count record${count == 1 ? "" : "s"} • '
                  '${selected == null ? "No selection" : _selectedLabel(selected!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = cs.outlineVariant.withOpacity(0.5);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.72),
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.rows});
  final List<Patient> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.length;
    final withPhone = rows.where((p) => (p.phone ?? '').trim().isNotEmpty).length;
    final withLastVisited = rows.where((p) => (p.lastVisitedIso ?? '').trim().isNotEmpty).length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatPill(label: 'Total', value: '$total', icon: Icons.people_alt_rounded),
        _StatPill(label: 'With phone', value: '$withPhone', icon: Icons.phone_rounded),
        _StatPill(label: 'Visited set', value: '$withLastVisited', icon: Icons.event_rounded),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.patient, required this.onEdit, required this.onDelete});

  final Patient? patient;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    if (p == null) {
      return Row(
        children: [
          const Icon(Icons.touch_app_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Select a row to see details here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    Widget chip(IconData icon, String text) {
      return Chip(
        avatar: Icon(icon, size: 18),
        label: Text(text),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      );
    }

    final phone = (p.phone ?? '').trim();
    final first = (p.firstName ?? '').trim();
    final father = (p.fatherName ?? '').trim();
    final last = (p.lastName ?? '').trim();
    final name = ([first, father, last].where((e) => e.isNotEmpty).toList()..removeWhere((e) => e.isEmpty)).join(' ');
    final displayName = name.isEmpty ? '—' : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_patientLabel(p)} • $displayName',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            chip(Icons.call_rounded, phone.isEmpty ? 'Phone: —' : 'Phone: $phone'),
            chip(Icons.cake_rounded, 'Year: ${p.birthYear?.toString() ?? "—"}'),
            chip(Icons.event_rounded, 'Visited: ${p.lastVisitedIso ?? "—"}'),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          (p.notes == null || p.notes!.trim().isEmpty) ? 'Notes: —' : 'Notes: ${p.notes!.trim()}',
          style: Theme.of(context).textTheme.bodyMedium,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PatientTable extends StatelessWidget {
  const _PatientTable({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    required this.sortField,
    required this.sortDir,
    required this.onSortFromHeader,
  });

  final List<Patient> rows;
  final int? selectedId;
  final void Function(int id) onSelect;

  final SortField sortField;
  final SortDir sortDir;
  final void Function(SortField, SortDir) onSortFromHeader;

  bool _isSorted(SortField f) => sortField == f;

  void _toggleSort(SortField f) {
    if (sortField == f) {
      onSortFromHeader(f, sortDir == SortDir.asc ? SortDir.desc : SortDir.asc);
    } else {
      onSortFromHeader(f, SortDir.asc);
    }
  }

  String _cellText(String? s) => (s == null || s.trim().isEmpty) ? '—' : s.trim();

  @override
  Widget build(BuildContext context) {
    final vCtrl = ScrollController();
    final hCtrl = ScrollController();

    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 44, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 10),
            Text('No patients yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Add a patient from the left panel.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: vCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: vCtrl,
            child: Scrollbar(
              controller: hCtrl,
              thumbVisibility: true,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: hCtrl,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    columnSpacing: 22,
                    horizontalMargin: 18,
                    columns: [
                      DataColumn(
                        label: InkWell(
                          onTap: () => _toggleSort(SortField.id),
                          child: _Header(label: 'ID', sorted: _isSorted(SortField.id), dir: sortDir),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: InkWell(
                          onTap: () => _toggleSort(SortField.firstName),
                          child: _Header(label: 'First', sorted: _isSorted(SortField.firstName), dir: sortDir),
                        ),
                      ),
                      DataColumn(
                        label: InkWell(
                          onTap: () => _toggleSort(SortField.fatherName),
                          child: _Header(label: "Father's", sorted: _isSorted(SortField.fatherName), dir: sortDir),
                        ),
                      ),
                      DataColumn(
                        label: InkWell(
                          onTap: () => _toggleSort(SortField.lastName),
                          child: _Header(label: 'Last', sorted: _isSorted(SortField.lastName), dir: sortDir),
                        ),
                      ),
                      const DataColumn(label: Text('Phone')),
                      DataColumn(
                        label: InkWell(
                          onTap: () => _toggleSort(SortField.birthYear),
                          child: _Header(label: 'Birth year', sorted: _isSorted(SortField.birthYear), dir: sortDir),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: InkWell(
                          onTap: () => _toggleSort(SortField.lastVisited),
                          child: _Header(label: 'Last visited', sorted: _isSorted(SortField.lastVisited), dir: sortDir),
                        ),
                      ),
                    ],
                    rows: [
                      for (final p in rows)
                        DataRow(
                          selected: selectedId == p.id,
                          onSelectChanged: (_) => onSelect(p.id),
                          cells: [
                            DataCell(Text(_idText(p.patientNumber))),
                            DataCell(Text(_cellText(p.firstName))),
                            DataCell(Text(_cellText(p.fatherName))),
                            DataCell(Text(_cellText(p.lastName))),
                            DataCell(Text(_cellText(p.phone))),
                            DataCell(Text(p.birthYear?.toString() ?? '—')),
                            DataCell(Text(p.lastVisitedIso ?? '—')),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.label, required this.sorted, required this.dir});
  final String label;
  final bool sorted;
  final SortDir dir;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        if (sorted) ...[
          const SizedBox(width: 6),
          Icon(dir == SortDir.asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16),
        ]
      ],
    );
  }
}

String _idText(int? value) => value == null ? '—' : value.toString();

String _patientLabel(Patient p) {
  final n = p.patientNumber;
  return n == null ? 'Patient' : 'Patient #$n';
}

String _selectedLabel(Patient p) {
  final n = p.patientNumber;
  return n == null ? 'Selected' : 'Selected #$n';
}
