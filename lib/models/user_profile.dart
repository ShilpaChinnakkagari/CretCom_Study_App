class UserProfile {
  String name;
  String email;
  String program;
  String currentYear;
  String currentSemester;
  String academicStart;
  String academicEnd;
  String branch;

  UserProfile({
    required this.name,
    required this.email,
    required this.program,
    required this.currentYear,
    required this.currentSemester,
    required this.academicStart,
    required this.academicEnd,
    required this.branch,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'program': program,
    'currentYear': currentYear,
    'currentSemester': currentSemester,
    'academicStart': academicStart,
    'academicEnd': academicEnd,
    'branch': branch,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    program: json['program'] ?? 'UG',
    currentYear: json['currentYear'] ?? 'I',
    currentSemester: json['currentSemester'] ?? 'I',
    academicStart: json['academicStart'] ?? DateTime.now().year.toString(),
    academicEnd: json['academicEnd'] ?? (DateTime.now().year + 4).toString(),
    branch: json['branch'] ?? '',
  );
}