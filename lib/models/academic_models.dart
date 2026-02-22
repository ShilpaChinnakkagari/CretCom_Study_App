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

  // Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'folderId': folderId,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  // Create from JSON
  factory QuestionBank.fromJson(Map<String, dynamic> json) => QuestionBank(
    id: json['id'],
    title: json['title'],
    folderId: json['folderId'],
    questions: (json['questions'] as List)
        .map((q) => Question.fromJson(q))
        .toList(),
  );
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
    'imageFileIds': imageFileIds,
    'marks': marks,
  };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'],
    question: json['question'],
    answer: json['answer'],
    imageFileIds: List<String>.from(json['imageFileIds']),
    marks: json['marks'],
  );
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