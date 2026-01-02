import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mama/models/patient.dart';

class PatientFormResult {
  const PatientFormResult(this.patient);
  final Patient patient;
}

class PatientFormDialog extends StatefulWidget {
  const PatientFormDialog({super.key, this.existing, required this.defaultPatientNumber});
  final Patient? existing;
  final int? defaultPatientNumber;

  @override
  State<PatientFormDialog> createState() => _PatientFormDialogState();
}

class _PatientFormDialogState extends State<PatientFormDialog> {
  late final _numberCtrl = TextEditingController(
    text: (widget.existing?.patientNumber ?? widget.defaultPatientNumber)?.toString() ?? '',
  );
  late final _firstCtrl = TextEditingController(text: widget.existing?.firstName ?? '');
  late final _fatherCtrl = TextEditingController(text: widget.existing?.fatherName ?? '');
  late final _lastCtrl = TextEditingController(text: widget.existing?.lastName ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
  late final _yearCtrl = TextEditingController(text: widget.existing?.birthYear?.toString() ?? '');
  late final _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');

  DateTime? _lastVisited;
  String? _numberError;

  @override
  void initState() {
    super.initState();
    final iso = widget.existing?.lastVisitedIso;
    _lastVisited = iso == null ? null : DateTime.tryParse(iso);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _firstCtrl.dispose();
    _fatherCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _yearCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  int? _parseYear(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  int? _parsePatientNumber(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  String? _iso(DateTime? d) {
    if (d == null) return null;
    return DateFormat('yyyy-MM-dd').format(d);
  }

  Future<void> _pickLastVisited() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 1),
      initialDate: _lastVisited ?? now,
    );
    if (picked == null) return;
    setState(() => _lastVisited = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit patient' : 'Add patient'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _numberCtrl,
                      'Patient number (ID)',
                      keyboard: TextInputType.number,
                      errorText: _numberError,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(_firstCtrl, 'First name')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_fatherCtrl, "Father's name")),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_lastCtrl, 'Last name')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(_phoneCtrl, 'Phone', keyboard: TextInputType.phone)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_yearCtrl, 'Birth year', keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _lastVisitedField(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Patient number is optional; all other fields are optional.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final number = _parsePatientNumber(_numberCtrl.text);
            if (number != null && number < 0) {
              setState(() => _numberError = 'Enter an integer ≥ 0, or leave blank');
              return;
            }
            setState(() => _numberError = null);
            final p = Patient(
              id: widget.existing?.id ?? 0,
              patientNumber: number,
              firstName: _nullIfEmpty(_firstCtrl.text),
              fatherName: _nullIfEmpty(_fatherCtrl.text),
              lastName: _nullIfEmpty(_lastCtrl.text),
              phone: _nullIfEmpty(_phoneCtrl.text),
              birthYear: _parseYear(_yearCtrl.text),
              lastVisitedIso: _iso(_lastVisited),
              notes: _nullIfEmpty(_notesCtrl.text),
            );
            Navigator.pop(context, PatientFormResult(p));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    String? errorText,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
    );
  }

  Widget _lastVisitedField(BuildContext context) {
    final text = _lastVisited == null ? '—' : DateFormat('yyyy-MM-dd').format(_lastVisited!);
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Last visited',
        border: OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          IconButton(
            tooltip: 'Pick date',
            onPressed: _pickLastVisited,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: () => setState(() => _lastVisited = null),
            icon: const Icon(Icons.clear_rounded),
          ),
        ],
      ),
    );
  }
}
