import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late final String _baseKey;

  @override
  void initState() {
    super.initState();
    _baseKey = 'semester_${widget.year.id}';
    _loadSavedSemesters();
  }

  Future<void> _loadSavedSemesters() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _semesters = [
        Semester(id: '1', name: 'I'),
        Semester(id: '2', name: 'II'),
      ];
      
      for (var sem in _semesters) {
        String key = '${_baseKey}_${sem.id}';
        String? savedId = prefs.getString(key);
        if (savedId != null && savedId.isNotEmpty) {
          sem.folderId = savedId;
          print("✅ Loaded ${sem.name} from permanent storage: $savedId");
        }
      }
      
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
        // Save PERMANENTLY
        final prefs = await SharedPreferences.getInstance();
        String key = '${_baseKey}_${semester.id}';
        await prefs.setString(key, folderId);
        
        setState(() {
          semester.folderId = folderId;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${semester.name} permanently synced'), backgroundColor: Colors.green),
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
        title: Text('Year ${widget.year.name} - Semesters'),
        backgroundColor: widget.academicType == 'UG' ? Colors.blue : Colors.green,
        foregroundColor: Colors.white,
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
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: widget.academicType == 'UG' 
                          ? Colors.blue.shade100
                          : Colors.green.shade100,
                      radius: 25,
                      child: Text(
                        semester.name.replaceAll('Semester ', ''),
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
                      semester.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      semester.folderId == null 
                          ? '⏳ Not synced' 
                          : '✅ Permanently synced',
                      style: TextStyle(
                        color: semester.folderId == null 
                            ? Colors.orange 
                            : Colors.green,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (semester.folderId == null)
                          IconButton(
                            icon: const Icon(Icons.cloud_upload, color: Colors.blue),
                            onPressed: _isLoading ? null : () => _createSemesterFolder(semester),
                          ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.grey),
                          onPressed: semester.folderId == null
                              ? null
                              : () {
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