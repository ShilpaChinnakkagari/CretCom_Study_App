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

class _NotesScreenState extends State<NotesScreen> with SingleTickerProviderStateMixin {
  final DriveService _driveService = DriveService();
  final List<Note> _notes = [];
  bool _isLoading = false;
  final TextEditingController _textNoteController = TextEditingController();
  final TextEditingController _noteTitleController = TextEditingController();
  late final String _notesStorageKey;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final ImagePicker _imagePicker = ImagePicker();

  // Colors for different elements
  final Map<String, Color> _unitColors = {
    'I': Colors.purple,
    'II': Colors.blue,
    'III': Colors.green,
    'IV': Colors.orange,
    'V': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _notesStorageKey = 'notes_${widget.unit.folderId ?? widget.unit.id}';
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    _loadNotes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
      }
    } catch (e) {
      print("Error loading notes: $e");
    }
  }

  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String notesJson = jsonEncode(_notes.map((note) => note.toJson()).toList());
      await prefs.setString(_notesStorageKey, notesJson);
    } catch (e) {
      print("Error saving notes: $e");
    }
  }

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

  Future<void> _saveTextNote() async {
    if (_textNoteController.text.isEmpty) return;

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
            SnackBar(
              content: Text('✅ "$title" created'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
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
            SnackBar(
              content: Text('✅ Image "$title" uploaded'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
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
            SnackBar(
              content: Text('✅ Image "$title" captured'),
              backgroundColor: Colors.purple,
              behavior: SnackBarBehavior.floating,
            ),
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
            SnackBar(
              content: Text('✅ File "$title" uploaded'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
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
        throw Exception('File not found');
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

  Future<void> _viewPDFInApp(File file, String fileName) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(fileName, style: const TextStyle(fontSize: 16)),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            body: PDFView(
              filePath: file.path,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: true,
            ),
          ),
        ),
      );
    } catch (e) {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

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
              child: SingleChildScrollView(child: Text(content)),
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
      await _viewPDFInApp(file, fileName);
    } else {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

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
              child: SingleChildScrollView(child: Text(note.content!)),
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

  Future<void> _deleteNote(Note note) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _notes.remove(note));
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

  Color _getUnitColor() {
    String unitNum = widget.unit.name.replaceAll('Unit ', '');
    return _unitColors[unitNum] ?? Colors.purple;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unitColor = _getUnitColor();
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: Colors.white70,
              ),
            ),
            Text(
              widget.unit.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: unitColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Animated Input Section
            SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      unitColor.withOpacity(0.1),
                      unitColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: unitColor.withOpacity(0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: unitColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.note_add,
                              color: unitColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Add Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: unitColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _textNoteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Write your note...',
                          labelStyle: TextStyle(color: unitColor.withOpacity(0.7)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: unitColor, width: 2),
                          ),
                          prefixIcon: Icon(Icons.edit, color: unitColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Button Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.save,
                              label: 'Save Text',
                              color: Colors.blue,
                              onPressed: _saveTextNote,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.attach_file,
                              label: 'Upload File',
                              color: Colors.green,
                              onPressed: _uploadFile,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.photo_library,
                              label: 'Upload Image',
                              color: Colors.orange,
                              onPressed: _uploadImage,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.camera_alt,
                              label: 'Capture',
                              color: unitColor,
                              onPressed: _captureImage,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Notes List with Animations
            Expanded(
              child: _notes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.note_alt,
                            size: 80,
                            color: unitColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notes yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: unitColor.withOpacity(0.7),
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
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              0.2 + (index * 0.1),
                              0.6 + (index * 0.1),
                              curve: Curves.easeOut,
                            ),
                          )),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  unitColor.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: unitColor.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: unitColor.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Dismissible(
                              key: Key(note.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(Icons.delete, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                  ],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete'),
                                    content: Text('Delete "${note.title}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (direction) async {
                                setState(() => _notes.removeAt(index));
                                await _saveNotes();
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        note.content != null ? Colors.blue : Colors.green,
                                        note.content != null ? Colors.blue.shade300 : Colors.green.shade300,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (note.content != null ? Colors.blue : Colors.green).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    note.content != null ? Icons.note : Icons.image,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  note.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  'Added: ${note.createdAt.toString().split('.').first}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.visibility, color: unitColor),
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
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}