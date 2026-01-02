import 'package:mama/db/app_db.dart';
import 'package:mama/models/patient.dart';

enum SortField { id, firstName, fatherName, lastName, birthYear, lastVisited }
enum SortDir { asc, desc }

class PatientFilters {
  const PatientFilters({
    this.searchText,
    this.birthYearMin,
    this.birthYearMax,
    this.lastVisitedFromIso,
    this.lastVisitedToIso,
    this.phoneMode = PhoneFilterMode.any,
  });

  final String? searchText;

  final int? birthYearMin;
  final int? birthYearMax;

  final String? lastVisitedFromIso; // inclusive
  final String? lastVisitedToIso;   // inclusive

  final PhoneFilterMode phoneMode;

  PatientFilters copyWith({
    String? searchText,
    int? birthYearMin,
    int? birthYearMax,
    String? lastVisitedFromIso,
    String? lastVisitedToIso,
    PhoneFilterMode? phoneMode,
  }) {
    return PatientFilters(
      searchText: searchText ?? this.searchText,
      birthYearMin: birthYearMin ?? this.birthYearMin,
      birthYearMax: birthYearMax ?? this.birthYearMax,
      lastVisitedFromIso: lastVisitedFromIso ?? this.lastVisitedFromIso,
      lastVisitedToIso: lastVisitedToIso ?? this.lastVisitedToIso,
      phoneMode: phoneMode ?? this.phoneMode,
    );
  }
}

enum PhoneFilterMode { any, hasPhone, missingPhone }

class PatientRepo {
  PatientRepo._();
  static final PatientRepo instance = PatientRepo._();

  Future<List<Patient>> list({
    required PatientFilters filters,
    required SortField sortField,
    required SortDir sortDir,
  }) async {
    final db = await AppDb.instance.db;

    final whereParts = <String>[];
    final args = <Object?>[];

    final q = (filters.searchText ?? '').trim();
    if (q.isNotEmpty) {
      // Search across names, phone, patient number (as text)
      whereParts.add('('
          'CAST(patient_number AS TEXT) LIKE ? OR '
          'COALESCE(first_name,\'\') LIKE ? OR '
          'COALESCE(father_name,\'\') LIKE ? OR '
          'COALESCE(last_name,\'\') LIKE ? OR '
          'COALESCE(phone,\'\') LIKE ? OR '
          'TRIM(REPLACE(REPLACE('
          'COALESCE(first_name,\'\') || \' \' || '
          'COALESCE(father_name,\'\') || \' \' || '
          'COALESCE(last_name,\'\')'
          ', \'  \', \' \'), \'  \', \' \')) LIKE ? OR '
          'TRIM(REPLACE(REPLACE('
          'COALESCE(first_name,\'\') || \' \' || '
          'COALESCE(last_name,\'\')'
          ', \'  \', \' \'), \'  \', \' \')) LIKE ?'
          ')');
      final like = '%$q%';
      args.addAll([like, like, like, like, like, like, like]);
    }

    if (filters.birthYearMin != null) {
      whereParts.add('(birth_year IS NOT NULL AND birth_year >= ?)');
      args.add(filters.birthYearMin);
    }
    if (filters.birthYearMax != null) {
      whereParts.add('(birth_year IS NOT NULL AND birth_year <= ?)');
      args.add(filters.birthYearMax);
    }

    if (filters.lastVisitedFromIso != null) {
      whereParts.add('(last_visited IS NOT NULL AND last_visited >= ?)');
      args.add(filters.lastVisitedFromIso);
    }
    if (filters.lastVisitedToIso != null) {
      whereParts.add('(last_visited IS NOT NULL AND last_visited <= ?)');
      args.add(filters.lastVisitedToIso);
    }

    if (filters.phoneMode == PhoneFilterMode.hasPhone) {
      whereParts.add('(phone IS NOT NULL AND TRIM(phone) <> \'\')');
    } else if (filters.phoneMode == PhoneFilterMode.missingPhone) {
      whereParts.add('(phone IS NULL OR TRIM(phone) = \'\')');
    }

    final where = whereParts.isEmpty ? null : whereParts.join(' AND ');

    final orderBy = _orderBy(sortField, sortDir);

    final rows = await db.query(
      'patients',
      where: where,
      whereArgs: args,
      orderBy: orderBy,
    );

    return rows.map(Patient.fromMap).toList();
  }

  String _orderBy(SortField field, SortDir dir) {
    final d = (dir == SortDir.asc) ? 'ASC' : 'DESC';

    switch (field) {
      case SortField.id:
        if (dir == SortDir.asc) {
          return 'patient_number IS NULL, patient_number ASC, id ASC';
        } else {
          return 'patient_number IS NOT NULL, patient_number DESC, id DESC';
        }

      case SortField.firstName:
        return _textOrder('first_name', dir);

      case SortField.fatherName:
        return _textOrder('father_name', dir);

      case SortField.lastName:
        return _textOrder('last_name', dir);

      case SortField.birthYear:
        if (dir == SortDir.asc) {
          // NULLs last
          return 'birth_year IS NULL, birth_year ASC, id ASC';
        } else {
          // NULLs first
          return 'birth_year IS NOT NULL, birth_year DESC, id DESC';
        }

      case SortField.lastVisited:
        if (dir == SortDir.asc) {
          // NULLs last
          return 'last_visited IS NULL, last_visited ASC, id ASC';
        } else {
          // NULLs first
          return 'last_visited IS NOT NULL, last_visited DESC, id DESC';
        }
    }
  }

  String _textOrder(String column, SortDir dir) {
    // Consistent, null-safe ordering for text:
    // - ASC: empty / NULL last
    // - DESC: empty / NULL first
    if (dir == SortDir.asc) {
      return '($column IS NULL OR TRIM($column) = \'\'), COALESCE($column, \'\') ASC, id ASC';
    } else {
      return 'NOT ($column IS NULL OR TRIM($column) = \'\'), COALESCE($column, \'\') DESC, id DESC';
    }
  }

  Future<int> create(Patient p) async {
    final db = await AppDb.instance.db;
    return db.insert('patients', p.toMap(includeId: false));
  }

  Future<void> update(Patient p) async {
    final db = await AppDb.instance.db;
    await db.update('patients', p.toMap(includeId: false), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> delete(int id) async {
    final db = await AppDb.instance.db;
    await db.transaction((txn) async {
      await txn.delete('patients', where: 'id = ?', whereArgs: [id]);
      await txn.execute('UPDATE patients SET id = id - 1 WHERE id > ?', [id]);
      await txn.execute(
        "UPDATE sqlite_sequence "
        "SET seq = (SELECT IFNULL(MAX(id), 0) FROM patients) "
        "WHERE name = 'patients'",
      );
    });
  }

  Future<int> nextPatientNumber() async {
    final db = await AppDb.instance.db;
    final rows = await db.rawQuery('SELECT MAX(patient_number) AS m FROM patients');
    final maxVal = rows.first['m'] as int?;
    return (maxVal ?? -1) + 1;
  }

  Future<bool> isPatientNumberAvailable(int? number, {int? excludeId}) async {
    if (number == null) return true;
    final db = await AppDb.instance.db;
    final rows = await db.query(
      'patients',
      columns: ['id'],
      where: excludeId == null
          ? 'patient_number = ?'
          : 'patient_number = ? AND id <> ?',
      whereArgs: excludeId == null ? [number] : [number, excludeId],
      limit: 1,
    );
    return rows.isEmpty;
  }

  Future<Patient?> getById(int id) async {
    final db = await AppDb.instance.db;
    final rows = await db.query('patients', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }
}
