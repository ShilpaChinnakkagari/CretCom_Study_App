import 'package:flutter/material.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'notes_screen.dart';

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
  bool _isLoading = false;
  
  final TextEditingController _unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  void _loadUnits() {
    // TODO: Load units from SharedPreferences
    setState(() {});
  }

  Future<void> _createUnit() async {
    if (_unitController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter unit number (I, II, III, etc.)')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.subject.folderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject folder not created yet')),
        );
        return;
      }

      print("📁 Creating unit: ${_unitController.text}");
      final folderId = await _driveService.createUnitFolder(
        _unitController.text, 
        widget.subject.folderId!
      );

      if (folderId != null) {
        setState(() {
          _units.add(Unit(
            id: DateTime.now().toString(),
            name: 'Unit ${_unitController.text}',
            folderId: folderId,
          ));
        });
        _unitController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Unit ${_unitController.text} created'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'), 
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
      body: Column(
        children: [
          // Add Unit Card
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
                    'Add New Unit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit Number (I, II, III, IV, V)',
                      hintText: 'Enter I, II, III, etc.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createUnit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Unit', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Units List
          Expanded(
            child: _units.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No units yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first unit above!',
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
                    itemCount: _units.length,
                    itemBuilder: (context, index) {
                      final unit = _units[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
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
                                  ? '⏳ Not synced to Drive' 
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
                                    Text('Add Notes', style: TextStyle(fontSize: 14)),
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
                              const PopupMenuItem(
                                value: 'images',
                                child: Row(
                                  children: [
                                    Icon(Icons.image, size: 20, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Add Images', style: TextStyle(fontSize: 14)),
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
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✨ $value coming soon!'),
                                    backgroundColor: Colors.purple,
                                  ),
                                );
                              }
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