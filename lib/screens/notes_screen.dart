import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';

class NotesScreen extends StatefulWidget {
  final AcademicYear year;
  final Semester semester;
  final Subject subject;
  final Unit unit;

  const NotesScreen({
    super.key,
    required this.year,
    required this.semester,
    required this.subject,
    required this.unit,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final DriveService _driveService = DriveService();
  final List<Note> _notes = [];
  bool _isLoading = false;
  final TextEditingController _textNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    // TODO: Load notes from SharedPreferences or Drive
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null) {
        setState(() => _isLoading = true);
        
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        
        if (widget.unit.folderId != null) {
          bool success = await _driveService.uploadFile(
            file.path,
            fileName,
            widget.unit.folderId!,
          );
          
          if (success && mounted) {
            setState(() {
              _notes.add(Note(
                id: DateTime.now().toString(),
                title: fileName,
                fileId: widget.unit.folderId,
                createdAt: DateTime.now(),
              ));
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✅ $fileName uploaded')),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _captureImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        setState(() => _isLoading = true);
        
        File file = File(image.path);
        String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        if (widget.unit.folderId != null) {
          bool success = await _driveService.uploadFile(
            file.path,
            fileName,
            widget.unit.folderId!,
          );
          
          if (success && mounted) {
            setState(() {
              _notes.add(Note(
                id: DateTime.now().toString(),
                title: fileName,
                fileId: widget.unit.folderId,
                createdAt: DateTime.now(),
              ));
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✅ Image captured and uploaded')),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTextNote() async {
    if (_textNoteController.text.isEmpty) return;

    try {
      setState(() => _isLoading = true);
      
      String fileName = 'note_${DateTime.now().millisecondsSinceEpoch}.txt';
      String tempPath = '${Directory.systemTemp.path}/$fileName';
      File tempFile = File(tempPath);
      await tempFile.writeAsString(_textNoteController.text);
      
      if (widget.unit.folderId != null) {
        bool success = await _driveService.uploadFile(
          tempPath,
          fileName,
          widget.unit.folderId!,
        );
        
        if (success && mounted) {
          setState(() {
            _notes.add(Note(
              id: DateTime.now().toString(),
              title: 'Text Note',
              content: _textNoteController.text,
              fileId: widget.unit.folderId,
              createdAt: DateTime.now(),
            ));
          });
          
          _textNoteController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Text note saved')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.unit.name} - Notes'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          // Input Section
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Notes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Text note input
                  TextField(
                    controller: _textNoteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Write your note...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveTextNote,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Text'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Upload File'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _captureImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Notes List
          Expanded(
            child: _notes.isEmpty
                ? const Center(
                    child: Text(
                      'No notes yet.\nAdd your first note above!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.shade100,
                            child: Icon(
                              note.content != null ? Icons.note : Icons.insert_drive_file,
                              color: Colors.purple,
                            ),
                          ),
                          title: Text(note.title),
                          subtitle: Text(
                            'Added: ${note.createdAt.toString().split('.').first}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.cloud_done, color: Colors.green),
                            onPressed: () {},
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