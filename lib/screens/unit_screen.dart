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
  final List<String> _defaultUnits = ['I', 'II', 'III', 'IV', 'V'];
  
  late final String _baseKey;

  @override
  void initState() {
    super.initState();
    // Use subject folder ID as base key - this NEVER changes!
    _baseKey = 'units_${widget.subject.folderId ?? widget.subject.id}';
    print("🔑 Unit base key: $_baseKey");
    print("📁 Subject folder ID: ${widget.subject.folderId}");
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear existing list
      _units.clear();
      
      // Check if units were already created for this subject
      bool unitsCreated = prefs.getBool('${_baseKey}_created') ?? false;
      print("📊 Units already created: $unitsCreated");
      
      for (String unitNum in _defaultUnits) {
        String key = '${_baseKey}_$unitNum';
        String? folderId = prefs.getString(key);
        
        if (folderId != null && folderId.isNotEmpty) {
          // Unit exists - add to list
          _units.add(Unit(
            id: unitNum,
            name: 'Unit $unitNum',
            folderId: folderId,
          ));
          print("✅ Loaded Unit $unitNum with folder: $folderId");
        } else {
          // Unit doesn't exist yet
          _units.add(Unit(
            id: unitNum,
            name: 'Unit $unitNum',
            folderId: null,
          ));
        }
      }
      
      // Only auto-create if NO units have folder IDs AND subject has folder
      bool hasAnySynced = _units.any((u) => u.folderId != null);
      
      if (!hasAnySynced && widget.subject.folderId != null && !unitsCreated) {
        print("📁 Auto-creating all units for subject: ${widget.subject.name}");
        await _createAllUnits(prefs);
        await prefs.setBool('${_baseKey}_created', true);
      } else {
        print("✅ Using existing units - no auto-creation needed");
      }
      
    } catch (e) {
      print("❌ Error loading units: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createAllUnits(SharedPreferences prefs) async {
    int createdCount = 0;
    
    for (String unitNum in _defaultUnits) {
      try {
        print("📁 Creating Unit $unitNum...");
        final folderId = await _driveService.createUnitFolder(
          unitNum, 
          widget.subject.folderId!
        );
        
        if (folderId != null) {
          String key = '${_baseKey}_$unitNum';
          await prefs.setString(key, folderId);
          
          // Update the unit in the list
          int index = _units.indexWhere((u) => u.id == unitNum);
          if (index != -1) {
            _units[index] = Unit(
              id: unitNum,
              name: 'Unit $unitNum',
              folderId: folderId,
            );
          }
          
          createdCount++;
          print("✅ Created Unit $unitNum with folder: $folderId");
        }
      } catch (e) {
        print("❌ Failed to create Unit $unitNum: $e");
      }
    }
    
    if (createdCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $createdCount units ready'),
          backgroundColor: Colors.green,
        ),
      );
    }
    
    setState(() {}); // Refresh UI
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
                  Text('Loading units...'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _units.length,
              itemBuilder: (context, index) {
                final unit = _units[index];
                bool isSynced = unit.folderId != null && unit.folderId!.isNotEmpty;
                
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
                          backgroundColor: isSynced 
                              ? Colors.purple.shade100 
                              : Colors.grey.shade200,
                          radius: 25,
                          child: Text(
                            unit.name.replaceAll('Unit ', ''),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSynced 
                                  ? Colors.purple.shade700 
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        title: Text(
                          unit.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSynced ? Colors.black : Colors.grey.shade600,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isSynced 
                                ? '✅ Permanently synced' 
                                : '⏳ Not synced',
                            style: TextStyle(
                              color: isSynced ? Colors.green : Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        trailing: isSynced
                            ? PopupMenuButton(
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
                              )
                            : const SizedBox(width: 40), // Empty space when not synced
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}