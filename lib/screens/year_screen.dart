import 'package:flutter/material.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'semester_screen.dart';

class YearScreen extends StatefulWidget {
  final String academicType; // "UG" or "PG"
  
  const YearScreen({super.key, required this.academicType});

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  final DriveService _driveService = DriveService();
  List<AcademicYear> _years = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  void _loadYears() {
    // Create years based on academic type
    List<AcademicYear> years = [];
    if (widget.academicType == "UG") {
      years = [
        AcademicYear(id: '1', name: 'I', type: 'UG'),
        AcademicYear(id: '2', name: 'II', type: 'UG'),
        AcademicYear(id: '3', name: 'III', type: 'UG'),
        AcademicYear(id: '4', name: 'IV', type: 'UG'),
      ];
    } else {
      years = [
        AcademicYear(id: '1', name: 'I', type: 'PG'),
        AcademicYear(id: '2', name: 'II', type: 'PG'),
      ];
    }
    setState(() {
      _years = years;
      _isLoading = false;
    });
  }

  Future<void> _createYearFolder(AcademicYear year) async {
    setState(() => _isLoading = true);
    try {
      final folderId = await _driveService.createYearFolder('Year ${year.name}');
      if (folderId != null) {
        year.folderId = folderId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${year.name} year folder created in Drive')),
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
        title: Text('${widget.academicType} - Select Year'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _years.length,
              itemBuilder: (context, index) {
                final year = _years[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        year.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('Year ${year.name}'),
                    subtitle: Text(year.folderId == null ? 'Not synced to Drive' : 'Synced to Drive'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (year.folderId == null)
                          IconButton(
                            icon: const Icon(Icons.cloud_upload, color: Colors.blue),
                            onPressed: () => _createYearFolder(year),
                          ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.grey),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SemesterScreen(
                                  academicType: widget.academicType,
                                  year: year,
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