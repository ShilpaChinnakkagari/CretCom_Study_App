class AcademicYear {
  String id;
  String name;
  String type;
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
  String name;
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
  String name;
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
  String? fileId;
  String? content;
  DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    this.fileId,
    this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'fileId': fileId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

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
  String title;
  List<Question> questions;
  String? folderId;

  QuestionBank({
    required this.id,
    required this.title,
    this.questions = const [],
    this.folderId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'folderId': folderId,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

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
  List<String> imageFileIds;
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