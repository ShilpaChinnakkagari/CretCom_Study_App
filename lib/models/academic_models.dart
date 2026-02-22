class AcademicYear {
  String id;
  String name; // I, II, III, IV
  String type; // UG or PG
  String? folderId;
  List<Semester> semesters;

  AcademicYear({
    required this.id,
    required this.name,
    required this.type,
    this.folderId,
    this.semesters = const [],
  });
}

class Semester {
  String id;
  String name; // Semester I, Semester II
  String? folderId;
  List<Subject> subjects;

  Semester({
    required this.id,
    required this.name,
    this.folderId,
    this.subjects = const [],
  });
}

class Subject {
  String id;
  String name;
  String courseCode;
  String? folderId;
  List<Unit> units;

  Subject({
    required this.id,
    required this.name,
    required this.courseCode,
    this.folderId,
    this.units = const [],
  });
}

class Unit {
  String id;
  String name; // Unit I, Unit II
  String? folderId;
  List<Note> notes;
  List<QuestionBank> questionBanks;

  Unit({
    required this.id,
    required this.name,
    this.folderId,
    this.notes = const [],
    this.questionBanks = const [],
  });
}

class Note {
  String id;
  String title;
  String? fileId; // Google Drive file ID
  String? content; // For text notes
  DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    this.fileId,
    this.content,
    required this.createdAt,
  });

  // Convert Note to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'fileId': fileId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  // Create Note from JSON
  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    fileId: json['fileId'],
    content: json['content'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class QuestionBank {
  String id;
  String title; // "1 Mark Questions", "2 Mark Questions", etc.
  List<Question> questions;
  String? folderId;

  QuestionBank({
    required this.id,
    required this.title,
    this.questions = const [],
    this.folderId,
  });
}

class Question {
  String id;
  String question;
  String? answer;
  List<String> imageFileIds; // Google Drive image IDs
  int marks;

  Question({
    required this.id,
    required this.question,
    this.answer,
    this.imageFileIds = const [],
    required this.marks,
  });
}