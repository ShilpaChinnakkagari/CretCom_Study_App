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

class _UnitScreenState extends State<UnitScreen> with SingleTickerProviderStateMixin {
  final DriveService _driveService = DriveService();
  final List<Unit> _units = [];
  bool _isLoading = true;
  final List<String> _defaultUnits = ['I', 'II', 'III', 'IV', 'V'];
  
  late final String _baseKey;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _baseKey = 'units_${widget.subject.name}_${widget.subject.courseCode}'
        .replaceAll(' ', '_')
        .replaceAll('(', '')
        .replaceAll(')', '');
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    
    print("🔑 Unit base key: $_baseKey");
    print("📁 Subject folder ID: ${widget.subject.folderId}");
    _loadUnits();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _units.clear();
      
      bool hasAnySynced = false;
      
      for (String unitNum in _defaultUnits) {
        String key = '${_baseKey}_$unitNum';
        String? folderId = prefs.getString(key);
        
        if (folderId != null && folderId.isNotEmpty) {
          hasAnySynced = true;
          _units.add(Unit(
            id: unitNum,
            name: 'Unit $unitNum',
            folderId: folderId,
          ));
          print("✅ Loaded Unit $unitNum with folder: $folderId");
        } else {
          _units.add(Unit(
            id: unitNum,
            name: 'Unit $unitNum',
            folderId: null,
          ));
        }
      }
      
      if (!hasAnySynced && widget.subject.folderId != null) {
        print("📁 Auto-creating all units for subject: ${widget.subject.name}");
        await _createAllUnits(prefs);
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
        final folderId = await _driveService.createUnitFolder(
          unitNum, 
          widget.subject.folderId!
        );
        
        if (folderId != null) {
          String key = '${_baseKey}_$unitNum';
          await prefs.setString(key, folderId);
          
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
    
    setState(() {});
  }

  Future<void> _createSingleUnit(Unit unit) async {
    if (widget.subject.folderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject not synced to Drive')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final folderId = await _driveService.createUnitFolder(
        unit.id, 
        widget.subject.folderId!
      );
      
      if (folderId != null) {
        final prefs = await SharedPreferences.getInstance();
        String key = '${_baseKey}_${unit.id}';
        await prefs.setString(key, folderId);
        
        int index = _units.indexWhere((u) => u.id == unit.id);
        if (index != -1) {
          _units[index] = Unit(
            id: unit.id,
            name: 'Unit ${unit.id}',
            folderId: folderId,
          );
        }
        
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Unit ${unit.id} synced'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("❌ Error creating unit: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              'Units',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
          : FadeTransition(
              opacity: _fadeAnimation,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _units.length,
                itemBuilder: (context, index) {
                  final unit = _units[index];
                  bool isSynced = unit.folderId != null && unit.folderId!.isNotEmpty;
                  
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: isSynced 
                              ? theme.colorScheme.secondary.withOpacity(0.2)
                              : theme.colorScheme.surface,
                          child: Text(
                            unit.name.replaceAll('Unit ', ''),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSynced 
                                  ? theme.colorScheme.secondary 
                                  : theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ),
                        title: Text(
                          unit.name,
                          style: TextStyle(
                            color: isSynced 
                                ? theme.colorScheme.onSurface 
                                : theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isSynced 
                                ? '✅ Permanently synced' 
                                : '⏳ Not synced',
                            style: TextStyle(
                              color: isSynced 
                                  ? theme.colorScheme.secondary 
                                  : theme.colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isSynced)
                              IconButton(
                                icon: Icon(
                                  Icons.cloud_upload,
                                  color: theme.colorScheme.primary,
                                ),
                                onPressed: _isLoading ? null : () => _createSingleUnit(unit),
                                tooltip: 'Create in Drive',
                              ),
                            PopupMenuButton(
                              icon: Icon(
                                Icons.more_vert,
                                color: isSynced 
                                    ? theme.colorScheme.onSurface 
                                    : theme.colorScheme.onSurface.withOpacity(0.3),
                              ),
                              enabled: isSynced,
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}