class Patient {
  Patient({
    required this.id,
    this.firstName,
    this.fatherName,
    this.lastName,
    this.phone,
    this.birthYear,
    this.lastVisitedIso,
    this.notes,
  });

  final int id;
  final String? firstName;
  final String? fatherName;
  final String? lastName;
  final String? phone;
  final int? birthYear; // year only
  final String? lastVisitedIso; // YYYY-MM-DD
  final String? notes;

  String get fullName {
    final parts = [firstName, fatherName, lastName]
        .where((p) => p != null && p!.trim().isNotEmpty)
        .map((p) => p!.trim())
        .toList();
    return parts.isEmpty ? '—' : parts.join(' ');
  }

  Patient copyWith({
    int? id,
    String? firstName,
    String? fatherName,
    String? lastName,
    String? phone,
    int? birthYear,
    String? lastVisitedIso,
    String? notes,
  }) {
    return Patient(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      fatherName: fatherName ?? this.fatherName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      birthYear: birthYear ?? this.birthYear,
      lastVisitedIso: lastVisitedIso ?? this.lastVisitedIso,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'first_name': firstName,
      'father_name': fatherName,
      'last_name': lastName,
      'phone': phone,
      'birth_year': birthYear,
      'last_visited': lastVisitedIso,
      'notes': notes,
    };
    if (includeId) map['id'] = id;
    return map;
  }

  static Patient fromMap(Map<String, Object?> m) {
    return Patient(
      id: (m['id'] as int),
      firstName: m['first_name'] as String?,
      fatherName: m['father_name'] as String?,
      lastName: m['last_name'] as String?,
      phone: m['phone'] as String?,
      birthYear: m['birth_year'] as int?,
      lastVisitedIso: m['last_visited'] as String?,
      notes: m['notes'] as String?,
    );
  }
}
