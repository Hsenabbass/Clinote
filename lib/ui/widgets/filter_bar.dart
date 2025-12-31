import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mama/repo/patient_repo.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.filters, required this.onChanged});
  final PatientFilters filters;
  final ValueChanged<PatientFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _BirthYearRange(
            min: filters.birthYearMin,
            max: filters.birthYearMax,
            onChanged: (min, max) => onChanged(filters.copyWith(birthYearMin: min, birthYearMax: max)),
          ),
          _LastVisitedFilter(
            fromIso: filters.lastVisitedFromIso,
            toIso: filters.lastVisitedToIso,
            onChanged: (from, to) => onChanged(filters.copyWith(lastVisitedFromIso: from, lastVisitedToIso: to)),
          ),
          _PhoneFilter(
            mode: filters.phoneMode,
            onChanged: (m) => onChanged(filters.copyWith(phoneMode: m)),
          ),
          if (_hasAny(filters))
            TextButton.icon(
              onPressed: () => onChanged(const PatientFilters(searchText: null)),
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  bool _hasAny(PatientFilters f) {
    return f.birthYearMin != null ||
        f.birthYearMax != null ||
        f.lastVisitedFromIso != null ||
        f.lastVisitedToIso != null ||
        f.phoneMode != PhoneFilterMode.any;
  }
}

class _BirthYearRange extends StatefulWidget {
  const _BirthYearRange({required this.min, required this.max, required this.onChanged});
  final int? min;
  final int? max;
  final void Function(int? min, int? max) onChanged;

  @override
  State<_BirthYearRange> createState() => _BirthYearRangeState();
}

class _BirthYearRangeState extends State<_BirthYearRange> {
  late final _minCtrl = TextEditingController(text: widget.min?.toString() ?? '');
  late final _maxCtrl = TextEditingController(text: widget.max?.toString() ?? '');

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  int? _parseYear(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cake_outlined),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _minCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Year min',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => widget.onChanged(_parseYear(_minCtrl.text), _parseYear(_maxCtrl.text)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _maxCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Year max',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => widget.onChanged(_parseYear(_minCtrl.text), _parseYear(_maxCtrl.text)),
          ),
        ),
      ],
    );
  }
}

class _LastVisitedFilter extends StatelessWidget {
  const _LastVisitedFilter({
    required this.fromIso,
    required this.toIso,
    required this.onChanged,
  });

  final String? fromIso;
  final String? toIso;
  final void Function(String? fromIso, String? toIso) onChanged;

  DateTime? _parse(String? iso) => iso == null ? null : DateTime.tryParse(iso);
  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final initial = DateTimeRange(
      start: _parse(fromIso) ?? DateTime(now.year, now.month, 1),
      end: _parse(toIso) ?? now,
    );
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (range == null) return;
    onChanged(_iso(range.start), _iso(range.end));
  }

  @override
  Widget build(BuildContext context) {
    final from = fromIso ?? '—';
    final to = toIso ?? '—';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.event_rounded),
        const SizedBox(width: 8),
        MenuAnchor(
          builder: (context, controller, _) {
            return OutlinedButton(
              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
              child: Text('Visited: $from → $to'),
            );
          },
          menuChildren: [
            MenuItemButton(
              onPressed: () {
                final today = DateTime.now();
                final iso = _iso(today);
                onChanged(iso, iso);
              },
              child: const Text('Today'),
            ),
            MenuItemButton(
              onPressed: () {
                final now = DateTime.now();
                final start = now.subtract(const Duration(days: 7));
                onChanged(_iso(start), _iso(now));
              },
              child: const Text('Last 7 days'),
            ),
            MenuItemButton(
              onPressed: () {
                final now = DateTime.now();
                final start = DateTime(now.year, now.month, 1);
                onChanged(_iso(start), _iso(now));
              },
              child: const Text('This month'),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: () => _pickRange(context),
              child: const Text('Custom range…'),
            ),
            MenuItemButton(
              onPressed: () => onChanged(null, null),
              child: const Text('Clear visited'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhoneFilter extends StatelessWidget {
  const _PhoneFilter({required this.mode, required this.onChanged});
  final PhoneFilterMode mode;
  final ValueChanged<PhoneFilterMode> onChanged;

  String _label(PhoneFilterMode m) => switch (m) {
        PhoneFilterMode.any => 'Any',
        PhoneFilterMode.hasPhone => 'Has phone',
        PhoneFilterMode.missingPhone => 'Missing phone',
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.phone_rounded),
        const SizedBox(width: 8),
        MenuAnchor(
          builder: (context, controller, _) {
            return OutlinedButton(
              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
              child: Text('Phone: ${_label(mode)}'),
            );
          },
          menuChildren: [
            for (final m in PhoneFilterMode.values)
              MenuItemButton(
                onPressed: () => onChanged(m),
                child: Text(_label(m)),
              ),
          ],
        ),
      ],
    );
  }
}
