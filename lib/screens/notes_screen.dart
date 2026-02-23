import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

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
  final TextEditingController _noteTitleController = TextEditingController();
  late final String _notesStorageKey;

  // For tracking note being edited
  Note? _editingNote;
  bool _isEditing = false;

  // For image upload
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _notesStorageKey = 'notes_${widget.unit.folderId ?? widget.unit.id}';
    print("📝 Notes storage key: $_notesStorageKey");
    _loadNotes();
  }

  // ==================== CRUD OPERATIONS ====================

  // CREATE - Load notes
  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notesJson = prefs.getString(_notesStorageKey);
      
      if (notesJson != null && notesJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(notesJson);
        setState(() {
          _notes.clear();
          _notes.addAll(jsonList.map((json) => Note.fromJson(json)).toList());
        });
        print("✅ Loaded ${_notes.length} notes");
      }
    } catch (e) {
      print("Error loading notes: $e");
    }
  }

  // CREATE/UPDATE - Save notes
  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String notesJson = jsonEncode(_notes.map((note) => note.toJson()).toList());
      await prefs.setString(_notesStorageKey, notesJson);
      print("✅ Saved ${_notes.length} notes");
    } catch (e) {
      print("Error saving notes: $e");
    }
  }

  // CREATE - Show dialog for title
  Future<String?> _showTitleDialog(String action, {String? initialValue}) {
    _noteTitleController.text = initialValue ?? '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Note'),
        content: TextField(
          controller: _noteTitleController,
          decoration: const InputDecoration(
            labelText: 'Note Title',
            hintText: 'e.g., 1M, 2M, Important Formulas',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_noteTitleController.text.isNotEmpty) {
                Navigator.pop(context, _noteTitleController.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // CREATE - Save text note
  Future<void> _saveTextNote() async {
    if (_textNoteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter note content'), backgroundColor: Colors.orange),
      );
      return;
    }

    String? title = await _showTitleDialog('Save Text');
    if (title == null) return;

    try {
      setState(() => _isLoading = true);
      
      String fileName = '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.txt';
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
              title: title,
              content: _textNoteController.text,
              fileId: widget.unit.folderId,
              createdAt: DateTime.now(),
            ));
          });
          
          _textNoteController.clear();
          await _saveNotes();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ "$title" created'), backgroundColor: Colors.green),
          );
          
          Navigator.pop(context, true);
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

  // CREATE - Upload image from gallery
  Future<void> _uploadImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      String? title = await _showTitleDialog('Upload Image');
      if (title == null) return;

      setState(() => _isLoading = true);
      
      File file = File(image.path);
      String fileName = '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
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
              title: title,
              fileId: widget.unit.folderId,
              createdAt: DateTime.now(),
            ));
          });
          
          await _saveNotes();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Image "$title" uploaded'), backgroundColor: Colors.green),
          );
          
          Navigator.pop(context, true);
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

  // CREATE - Capture image from camera
  Future<void> _captureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);

      if (image == null) return;

      String? title = await _showTitleDialog('Capture Image');
      if (title == null) return;

      setState(() => _isLoading = true);
      
      File file = File(image.path);
      String fileName = '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
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
              title: title,
              fileId: widget.unit.folderId,
              createdAt: DateTime.now(),
            ));
          });
          
          await _saveNotes();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Image "$title" captured'), backgroundColor: Colors.green),
          );
          
          Navigator.pop(context, true);
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

  // CREATE - Upload file
  Future<void> _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
      );

      if (result == null) return;

      String? title = await _showTitleDialog('Upload File');
      if (title == null) return;

      setState(() => _isLoading = true);
      
      File file = File(result.files.single.path!);
      String originalFileName = result.files.single.name;
      String extension = originalFileName.split('.').last;
      String fileName = '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
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
              title: title,
              fileId: widget.unit.folderId,
              createdAt: DateTime.now(),
            ));
          });
          
          await _saveNotes();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ File "$title" uploaded'), backgroundColor: Colors.green),
          );
          
          Navigator.pop(context, true);
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

  // UPDATE - Edit note
  Future<void> _editNote(Note note) async {
    if (note.content != null) {
      // For text notes
      _textNoteController.text = note.content!;
      String? newTitle = await _showTitleDialog('Edit', initialValue: note.title);
      
      if (newTitle != null) {
        setState(() {
          note.title = newTitle;
          // Note: Content editing would require re-uploading to Drive
          // For simplicity, we'll just update the title
        });
        await _saveNotes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Note updated'), backgroundColor: Colors.green),
        );
      }
    } else {
      // For files/images, just edit the title
      String? newTitle = await _showTitleDialog('Edit', initialValue: note.title);
      if (newTitle != null) {
        setState(() {
          note.title = newTitle;
        });
        await _saveNotes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Note renamed'), backgroundColor: Colors.green),
        );
      }
    }
  }

  // DELETE - Delete note (already implemented via swipe)
  Future<void> _deleteNote(Note note) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _notes.remove(note);
              });
              await _saveNotes();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ Note deleted'), backgroundColor: Colors.orange),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // READ - View note
  Future<void> _viewNote(Note note) async {
    try {
      if (note.content != null && note.content!.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(note.title),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Text(note.content!),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      final downloadedFile = await _downloadFromDrive(note.title);
      if (downloadedFile != null && mounted) {
        await _viewDownloadedFile(downloadedFile, note.title);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening note: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Helper: Download file from Drive
  Future<File?> _downloadFromDrive(String fileName) async {
    try {
      if (!mounted) return null;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final driveApi = await _driveService.getDriveApi();
      if (driveApi == null) {
        if (mounted) Navigator.pop(context);
        throw Exception('Not authenticated');
      }

      final searchResult = await driveApi.files.list(
        q: "name='$fileName' and '${widget.unit.folderId}' in parents and trashed=false",
        spaces: 'drive',
      );

      if (searchResult.files == null || searchResult.files!.isEmpty) {
        if (mounted) Navigator.pop(context);
        throw Exception('File not found in Drive');
      }

      final fileMetadata = searchResult.files!.first;
      
      final downloadDir = await getApplicationDocumentsDirectory();
      final downloadPath = '${downloadDir.path}/$fileName';
      final downloadFile = File(downloadPath);

      final response = await driveApi.files.get(
        fileMetadata.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is drive.Media) {
        final sink = downloadFile.openWrite();
        await response.stream.pipe(sink);
        await sink.close();
        
        if (mounted) Navigator.pop(context);
        return downloadFile;
      } else {
        if (mounted) Navigator.pop(context);
        throw Exception('Unexpected response');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  // Helper: View downloaded file
  Future<void> _viewDownloadedFile(File file, String fileName) async {
    String lowerName = fileName.toLowerCase();
    
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg') || lowerName.endsWith('.png')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(fileName),
              backgroundColor: Colors.black,
            ),
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(file),
              ),
            ),
          ),
        ),
      );
    } else if (lowerName.endsWith('.txt')) {
      try {
        String content = await file.readAsString();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(fileName),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Text(content),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e'), backgroundColor: Colors.red),
        );
      }
    } else if (lowerName.endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(fileName),
              backgroundColor: Colors.red,
            ),
            body: PDFView(filePath: file.path),
          ),
        ),
      );
    } else {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.unit.name} - Notes',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotes,
          ),
        ],
      ),
      body: Column(
        children: [
          // Input Section
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
                      prefixIcon: Icon(Icons.edit),
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
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _uploadFile,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Upload File'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _uploadImage,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Upload Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _captureImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Notes List with CRUD options
          Expanded(
            child: _notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_alt, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No notes yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('Add your first note above!', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Dismissible(
                          key: Key(note.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete'),
                                content: Text('Delete "${note.title}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) async {
                            setState(() => _notes.removeAt(index));
                            await _saveNotes();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${note.title} deleted')),
                            );
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: note.content != null ? Colors.blue.shade100 : Colors.green.shade100,
                              child: Icon(note.content != null ? Icons.note : Icons.image, color: note.content != null ? Colors.blue : Colors.green),
                            ),
                            title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Added: ${note.createdAt.toString().split('.').first}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // View button
                                IconButton(icon: const Icon(Icons.visibility, color: Colors.blue), onPressed: () => _viewNote(note)),
                                // Edit button
                                IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editNote(note)),
                                // Share button
                                IconButton(icon: const Icon(Icons.share, color: Colors.green), onPressed: () async {
                                  final file = await _downloadFromDrive(note.title);
                                  if (file != null) await Share.shareXFiles([XFile(file.path)]);
                                }),
                              ],
                            ),
                            onTap: () => _viewNote(note),
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