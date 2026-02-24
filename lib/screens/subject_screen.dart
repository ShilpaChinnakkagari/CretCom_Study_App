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

class _SubjectScreenState extends State<SubjectScreen> with SingleTickerProviderStateMixin {
  final DriveService _driveService = DriveService();
  final List<Subject> _subjects = [];
  bool _isLoading = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  late final String _storageKey;

  @override
  void initState() {
    super.initState();
    _storageKey = 'subjects_${widget.year.name}_${widget.semester.name}_${widget.semester.folderId ?? widget.semester.id}';
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    _loadSubjects();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      } catch (e) {}
    }
  }

  Future<void> _saveSubjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> subjectsJson = _subjects.map((s) => ({
        'id': s.id,
        'name': s.name,
        'courseCode': s.courseCode,
        'folderId': s.folderId,
      })).toList();
      
      await prefs.setString(_storageKey, jsonEncode(subjectsJson));
    } catch (e) {}
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
        
        setState(() => _subjects.add(newSubject));
        await _saveSubjects();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('subject_${subjectId}_folder', folderId);
        
        _nameController.clear();
        _codeController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Subject created')),
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

  Future<void> _deleteSubject(Subject subject) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text('Permanently delete "${subject.name}" from app AND Google Drive?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              try {
                // 1. Delete from Google Drive
                if (subject.folderId != null) {
                  await _driveService.deleteFolder(subject.folderId!);
                }
                
                // 2. Remove from list
                setState(() => _subjects.remove(subject));
                await _saveSubjects();
                
                // 3. Remove all related SharedPreferences keys
                final prefs = await SharedPreferences.getInstance();
                List<String> keysToRemove = [];
                
                for (String key in prefs.getKeys()) {
                  if (key.startsWith('units_${subject.id}') || 
                      key.startsWith('subject_${subject.id}') ||
                      (subject.folderId != null && key.contains(subject.folderId!))) {
                    keysToRemove.add(key);
                    await _driveService.clearFolderId(key);
                  }
                }
                
                for (String key in keysToRemove) {
                  await prefs.remove(key);
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Subject permanently deleted'), backgroundColor: Colors.green),
                );
                
                Navigator.pop(context, true);
                
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.year.name} - ${widget.semester.name} - Subjects'),
        backgroundColor: widget.academicType == 'UG' ? Colors.blue : Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Add Subject Card
                  SlideTransition(
                    position: _slideAnimation,
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Subject Name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.book),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _codeController,
                              decoration: InputDecoration(
                                labelText: 'Course Code',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.code),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _createSubject,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.academicType == 'UG' ? Colors.blue : Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('Create Subject'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Subjects List
                  Expanded(
                    child: _subjects.isEmpty
                        ? Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.book, size: 80, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text('No subjects yet', style: TextStyle(fontSize: 20, color: Colors.grey.shade600)),
                            ],
                          ))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _subjects.length,
                            itemBuilder: (context, index) {
                              final subject = _subjects[index];
                              
                              return AnimatedContainer(
                                duration: Duration(milliseconds: 300 + (index * 100)),
                                curve: Curves.easeOut,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.2, 0),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: _animationController,
                                    curve: Interval(
                                      (0.2 + (index * 0.1)).clamp(0.0, 0.8),
                                      (0.6 + (index * 0.1)).clamp(0.0, 1.0),
                                      curve: Curves.easeOut,
                                    ),
                                  )),
                                  child: Dismissible(
                                    key: Key(subject.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Icon(Icons.delete, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Subject'),
                                          content: Text('Delete "${subject.name}" permanently?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onDismissed: (direction) => _deleteSubject(subject),
                                    child: Card(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(16),
                                        leading: CircleAvatar(
                                          radius: 28,
                                          backgroundColor: (widget.academicType == 'UG' ? Colors.blue : Colors.green).withOpacity(0.1),
                                          child: Text(
                                            subject.name[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: widget.academicType == 'UG' ? Colors.blue : Colors.green,
                                            ),
                                          ),
                                        ),
                                        title: Text(subject.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                        subtitle: Text(subject.courseCode),
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
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}