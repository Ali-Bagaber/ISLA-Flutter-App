class UserProfile {
  final String name;
  final String studentId;
  final String faculty;
  final int year;
  final int semester;
  final String photoUrl;

  const UserProfile({
    required this.name,
    required this.studentId,
    required this.faculty,
    required this.year,
    required this.semester,
    this.photoUrl = '',
  });

  factory UserProfile.initial() {
    return const UserProfile(
      name: '',
      studentId: '',
      faculty: '',
      year: 0,
      semester: 0,
      photoUrl: '',
    );
  }

  UserProfile copyWith({
    String? name,
    String? studentId,
    String? faculty,
    int? year,
    int? semester,
    String? photoUrl,
  }) {
    return UserProfile(
      name: name ?? this.name,
      studentId: studentId ?? this.studentId,
      faculty: faculty ?? this.faculty,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'studentId': studentId,
      'faculty': faculty,
      'year': year,
      'semester': semester,
      if (photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: (map['name'] as String?) ?? '',
      studentId: (map['studentId'] as String?) ?? '',
      faculty: (map['faculty'] as String?) ?? '',
      year: (map['year'] as int?) ?? 0,
      semester: (map['semester'] as int?) ?? 0,
      photoUrl: (map['photoUrl'] as String?) ?? '',
    );
  }
}
