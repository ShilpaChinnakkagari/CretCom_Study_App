import 'package:flutter/material.dart';
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

      final folderId = await _driveService.createSubjectFolder(
        _nameController.text, 
        _codeController.text, 
        widget.semester.folderId!
      );

      if (folderId != null) {
        setState(() {
          _subjects.add(Subject(
            id: DateTime.now().toString(),
            name: _nameController.text,
            courseCode: _codeController.text,
            folderId: folderId,
          ));
        });
        _nameController.clear();
        _codeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subject ${_nameController.text} created')),
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
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Add Subject Card
          Card(
            margin: const EdgeInsets.all(16),
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
                        backgroundColor: Colors.blue,
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
                ? const Center(
                    child: Text(
                      'No subjects yet.\nAdd your first subject above!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _subjects.length,
                    itemBuilder: (context, index) {
                      final subject = _subjects[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Text(
                              subject.name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(subject.name),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}