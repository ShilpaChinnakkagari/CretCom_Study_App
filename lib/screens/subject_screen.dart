import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'unit_screen.dart';

class SubjectScreen extends StatefulWidget {
  final String academicType;
  final AcademicYear year;
  final Semester semester;
  
  const SubjectScreen({
    super.key, 
    required this.academicType, 
    required this.year, 
    required this.semester
  });

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  final DriveService _driveService = DriveService();
  final List<Subject> _subjects = [];
  bool _isLoading = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  late final String _storageKey;

  @override
  void initState() {
    super.initState();
    // IMPROVED: Include year and semester in storage key to filter by profile
    _storageKey = 'subjects_${widget.year.name}_${widget.semester.name}_${widget.semester.folderId ?? widget.semester.id}';
    print("🔑 Subjects storage key: $_storageKey");
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final String? subjectsJson = prefs.getString(_storageKey);
    
    if (subjectsJson != null && subjectsJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(subjectsJson);
        setState(() {
          _subjects.clear();
          _subjects.addAll(jsonList.map((json) => Subject(
            id: json['id'],
            name: json['name'],
            courseCode: json['courseCode'],
            folderId: json['folderId'],
          )).toList());
        });
        print("✅ Loaded ${_subjects.length} subjects from storage");
      } catch (e) {
        print("Error loading subjects: $e");
      }
    } else {
      print("📝 No saved subjects found");
    }
  }

  Future<void> _saveSubjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> subjectsJson = _subjects.map((s) => {
        'id': s.id,
        'name': s.name,
        'courseCode': s.courseCode,
        'folderId': s.folderId,
      }).toList();
      
      await prefs.setString(_storageKey, jsonEncode(subjectsJson));
      print("✅ Saved ${_subjects.length} subjects to storage");
    } catch (e) {
      print("Error saving subjects: $e");
    }
  }

  Future<void> _createSubject() async {
    if (_nameController.text.isEmpty || _codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter subject name and code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.semester.folderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please create semester folder first')),
        );
        return;
      }

      // Check if subject already exists
      bool alreadyExists = _subjects.any((s) => 
        s.name.toLowerCase() == _nameController.text.toLowerCase() &&
        s.courseCode.toLowerCase() == _codeController.text.toLowerCase()
      );

      if (alreadyExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Subject already exists'), backgroundColor: Colors.orange),
        );
        return;
      }

      final folderId = await _driveService.createSubjectFolder(
        _nameController.text, 
        _codeController.text, 
        widget.semester.folderId!
      );

      if (folderId != null) {
        // Create consistent ID
        String subjectId = '${_nameController.text}_${_codeController.text}'
            .replaceAll(' ', '_')
            .replaceAll('(', '')
            .replaceAll(')', '')
            .toLowerCase();
        
        Subject newSubject = Subject(
          id: subjectId,
          name: _nameController.text,
          courseCode: _codeController.text,
          folderId: folderId,
        );
        
        setState(() {
          _subjects.add(newSubject);
        });
        
        // Save subjects list
        await _saveSubjects();
        
        // Save individual subject folder ID
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('subject_${subjectId}_folder', folderId);
        
        _nameController.clear();
        _codeController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Subject created and saved permanently')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.year.name} - ${widget.semester.name} - Subjects'),
        backgroundColor: widget.academicType == 'UG' ? Colors.blue : Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Add Subject Card
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Subject',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.book),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Course Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.code),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createSubject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.academicType == 'UG' ? Colors.blue : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Subject'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Subjects List
          Expanded(
            child: _subjects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No subjects yet for ${widget.year.name}, ${widget.semester.name}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first subject above!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _subjects.length,
                    itemBuilder: (context, index) {
                      final subject = _subjects[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: widget.academicType == 'UG' 
                                ? Colors.blue.shade100 
                                : Colors.green.shade100,
                            radius: 25,
                            child: Text(
                              subject.name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.academicType == 'UG' 
                                    ? Colors.blue 
                                    : Colors.green,
                              ),
                            ),
                          ),
                          title: Text(
                            subject.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            subject.courseCode,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UnitScreen(
                                    academicType: widget.academicType,
                                    year: widget.year,
                                    semester: widget.semester,
                                    subject: subject,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}