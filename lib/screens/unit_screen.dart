import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'notes_screen.dart';
import 'question_bank_screen.dart';

class UnitScreen extends StatefulWidget {
  final String academicType;
  final AcademicYear year;
  final Semester semester;
  final Subject subject;
  
  const UnitScreen({
    super.key, 
    required this.academicType, 
    required this.year, 
    required this.semester, 
    required this.subject
  });

  @override
  State<UnitScreen> createState() => _UnitScreenState();
}

class _UnitScreenState extends State<UnitScreen> {
  final DriveService _driveService = DriveService();
  final List<Unit> _units = [];
  bool _isLoading = true;
  
  // Default units (user doesn't need to create them)
  final List<String> _defaultUnits = ['I', 'II', 'III', 'IV', 'V'];

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if units were already created
      bool unitsCreated = prefs.getBool('units_created_${widget.subject.id}') ?? false;
      
      if (!unitsCreated) {
        // Auto-create all default units
        await _createAllDefaultUnits();
        await prefs.setBool('units_created_${widget.subject.id}', true);
      } else {
        // Load existing unit folder IDs
        for (int i = 0; i < _defaultUnits.length; i++) {
          String unitNum = _defaultUnits[i];
          String? folderId = prefs.getString('unit_${widget.subject.id}_$unitNum');
          
          _units.add(Unit(
            id: '${i + 1}',
            name: 'Unit $unitNum',
            folderId: folderId,
          ));
        }
      }
    } catch (e) {
      print("Error loading units: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createAllDefaultUnits() async {
    if (widget.subject.folderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sync subject first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      for (int i = 0; i < _defaultUnits.length; i++) {
        String unitNum = _defaultUnits[i];
        
        // Create folder in Drive
        final folderId = await _driveService.createUnitFolder(
          unitNum, 
          widget.subject.folderId!
        );

        if (folderId != null) {
          // Save to SharedPreferences
          await prefs.setString('unit_${widget.subject.id}_$unitNum', folderId);
          
          _units.add(Unit(
            id: '${i + 1}',
            name: 'Unit $unitNum',
            folderId: folderId,
          ));
          
          print("✅ Auto-created Unit $unitNum");
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ All units auto-created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error creating units: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating units: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.subject.name} - Units',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Auto-creating units...'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _units.length,
              itemBuilder: (context, index) {
                final unit = _units[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade100,
                          radius: 25,
                          child: Text(
                            unit.name.replaceAll('Unit ', ''),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                        title: Text(
                          unit.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            unit.folderId == null 
                                ? '⏳ Not synced' 
                                : '✅ Synced to Drive',
                            style: TextStyle(
                              color: unit.folderId == null 
                                  ? Colors.orange 
                                  : Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        trailing: PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Colors.purple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'notes',
                              child: Row(
                                children: [
                                  Icon(Icons.note, size: 20, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Notes', style: TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'questions',
                              child: Row(
                                children: [
                                  Icon(Icons.question_answer, size: 20, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Question Bank', style: TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'notes') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotesScreen(
                                    year: widget.year,
                                    semester: widget.semester,
                                    subject: widget.subject,
                                    unit: unit,
                                  ),
                                ),
                              );
                            } else if (value == 'questions') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QuestionBankScreen(
                                    year: widget.year,
                                    semester: widget.semester,
                                    subject: widget.subject,
                                    unit: unit,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}