import 'package:flutter/material.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';

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
    // For now, we'll just show empty list
    // Later we can load from Drive/SharedPreferences
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
          SnackBar(content: Text('Unit ${_unitController.text} created')),
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
        title: Text('${widget.subject.name} - Units'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Add Unit Card
          Card(
            margin: const EdgeInsets.all(16),
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
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Unit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Units List
          Expanded(
            child: _units.isEmpty
                ? const Center(
                    child: Text(
                      'No units yet.\nAdd your first unit above!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _units.length,
                    itemBuilder: (context, index) {
                      final unit = _units[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple,
                            child: Text(
                              unit.name.replaceAll('Unit ', ''),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(unit.name),
                          subtitle: Text(unit.folderId == null ? 'Not synced' : 'Synced to Drive'),
                          trailing: PopupMenuButton(
                            icon: const Icon(Icons.more_vert),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'notes',
                                child: Row(
                                  children: [
                                    Icon(Icons.note, size: 20),
                                    SizedBox(width: 8),
                                    Text('Add Notes'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'questions',
                                child: Row(
                                  children: [
                                    Icon(Icons.question_answer, size: 20),
                                    SizedBox(width: 8),
                                    Text('Question Bank'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'images',
                                child: Row(
                                  children: [
                                    Icon(Icons.image, size: 20),
                                    SizedBox(width: 8),
                                    Text('Add Images'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$value coming soon!')),
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