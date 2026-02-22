import 'package:flutter/material.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'subject_screen.dart';

class SemesterScreen extends StatefulWidget {
  final String academicType;
  final AcademicYear year;
  
  const SemesterScreen({super.key, required this.academicType, required this.year});

  @override
  State<SemesterScreen> createState() => _SemesterScreenState();
}

class _SemesterScreenState extends State<SemesterScreen> {
  final DriveService _driveService = DriveService();
  List<Semester> _semesters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSemesters();
  }

  void _loadSemesters() {
    setState(() {
      _semesters = [
        Semester(id: '1', name: 'I'),
        Semester(id: '2', name: 'II'),
      ];
      _isLoading = false;
    });
  }

  Future<void> _createSemesterFolder(Semester semester) async {
    setState(() => _isLoading = true);
    try {
      if (widget.year.folderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please create year folder first'), backgroundColor: Colors.orange),
        );
        return;
      }
      final folderId = await _driveService.createSemesterFolder(semester.name, widget.year.folderId!);
      if (folderId != null) {
        semester.folderId = folderId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${semester.name} folder created in Drive')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating folder: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Year ${widget.year.name} - Semesters'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _semesters.length,
              itemBuilder: (context, index) {
                final semester = _semesters[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text(
                        semester.name.replaceAll('Semester ', ''),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(semester.name),
                    subtitle: Text(semester.folderId == null ? 'Not synced to Drive' : 'Synced to Drive'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (semester.folderId == null)
                          IconButton(
                            icon: const Icon(Icons.cloud_upload, color: Colors.green),
                            onPressed: () => _createSemesterFolder(semester),
                          ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.grey),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SubjectScreen(
                                  academicType: widget.academicType,
                                  year: widget.year,
                                  semester: semester,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}