import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:googleapis/drive/v3.dart' as drive;

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
    // TODO: Load notes from SharedPreferences
    setState(() {});
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
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
              SnackBar(content: Text('✅ $fileName uploaded'), backgroundColor: Colors.green),
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
              SnackBar(content: Text('✅ Image captured and uploaded'), backgroundColor: Colors.green),
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
              title: 'Text Note - ${DateTime.now().toString().split(' ')[0]}',
              content: _textNoteController.text,
              fileId: widget.unit.folderId,
              createdAt: DateTime.now(),
            ));
          });
          
          _textNoteController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Text note saved'), backgroundColor: Colors.green),
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

  // Download file from Drive
  Future<File?> _downloadFromDrive(String fileName) async {
    try {
      // Show loading
      if (!mounted) return null;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get Drive API
      final driveApi = await _driveService.getDriveApi();
      if (driveApi == null) {
        if (mounted) Navigator.pop(context);
        throw Exception('Not authenticated');
      }

      // Search for the file in the current unit folder
      final searchResult = await driveApi.files.list(
        q: "name='$fileName' and '${widget.unit.folderId}' in parents and trashed=false",
        spaces: 'drive',
      );

      if (searchResult.files == null || searchResult.files!.isEmpty) {
        if (mounted) Navigator.pop(context);
        throw Exception('File not found in Drive');
      }

      final fileMetadata = searchResult.files!.first;
      
      // Download the file
      final downloadDir = await getApplicationDocumentsDirectory();
      final downloadPath = '${downloadDir.path}/$fileName';
      final downloadFile = File(downloadPath);

      // Download file content
      final response = await driveApi.files.get(
        fileMetadata.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      // Check if response is Media type
      if (response is drive.Media) {
        // Write to local file
        final sink = downloadFile.openWrite();
        await response.stream.pipe(sink);
        await sink.close();
        
        if (mounted) Navigator.pop(context); // Close loading dialog
        return downloadFile;
      } else {
        if (mounted) Navigator.pop(context);
        throw Exception('Unexpected response type from Drive API');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  // View downloaded file
  Future<void> _viewDownloadedFile(File file, String fileName) async {
    if (fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png')) {
      // View image
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
    } else if (fileName.toLowerCase().endsWith('.txt')) {
      // View text file
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
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Share.shareXFiles([XFile(file.path)]);
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } else {
      // For PDFs and other files, open externally
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(fileName),
          content: const Text('How would you like to open this file?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Share.shareXFiles([XFile(file.path)]);
              },
              child: const Text('Share'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await launchUrl(
                  Uri.file(file.path),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Open'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _viewNote(Note note) async {
    try {
      // For text notes created in-app
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

      // For uploaded files, download from Drive
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
                          onPressed: _isLoading ? null : _pickFile,
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _captureImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_alt,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notes yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first note above!',
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
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: note.content != null 
                                ? Colors.blue.shade100 
                                : Colors.green.shade100,
                            child: Icon(
                              note.content != null ? Icons.note : Icons.insert_drive_file,
                              color: note.content != null ? Colors.blue : Colors.green,
                            ),
                          ),
                          title: Text(
                            note.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Added: ${note.createdAt.toString().split('.').first}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.blue),
                                onPressed: () => _viewNote(note),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, color: Colors.green),
                                onPressed: () async {
                                  final file = await _downloadFromDrive(note.title);
                                  if (file != null) {
                                    await Share.shareXFiles([XFile(file.path)]);
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () => _viewNote(note),
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