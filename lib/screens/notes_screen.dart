import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';

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

class _NotesScreenState extends State<NotesScreen> with TickerProviderStateMixin {
  final DriveService _driveService = DriveService();
  final List<Note> _notes = [];
  bool _isLoading = false;
  final TextEditingController _textNoteController = TextEditingController();
  final TextEditingController _noteTitleController = TextEditingController();
  late final String _notesStorageKey;
  
  late AnimationController _animationController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;
  late Animation<Offset> _slideAnimation;
  
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

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
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
    
    _loadNotes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _glowController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: unitColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Icon(
                        Icons.swipe_left,
                        color: unitColor.withOpacity(_glowAnimation.value),
                        size: 20,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Swipe left to delete',
                    style: TextStyle(color: unitColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [unitColor.withOpacity(0.1), unitColor.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextField(
                        controller: _textNoteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Write your note...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildActionButton(Icons.save, 'Save Text', Colors.blue, _saveTextNote)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildActionButton(Icons.attach_file, 'Upload File', Colors.green, _uploadFile)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildActionButton(Icons.photo_library, 'Upload Image', Colors.orange, _uploadImage)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildActionButton(Icons.camera_alt, 'Capture', unitColor, _captureImage)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
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
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        bool isPdf = note.title.toLowerCase().endsWith('.pdf');
                        bool isDoc = note.title.toLowerCase().endsWith('.doc') || 
                                    note.title.toLowerCase().endsWith('.docx');
                        bool isPpt = note.title.toLowerCase().endsWith('.ppt') || 
                                    note.title.toLowerCase().endsWith('.pptx');
                        
                        return Dismissible(
                          key: Key(note.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) async {
                            setState(() => _notes.removeAt(index));
                            await _saveNotes();
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPdf ? Colors.red : (isDoc || isPpt ? Colors.blue : Colors.purple),
                                child: Icon(
                                  isPdf ? Icons.picture_as_pdf : 
                                  isDoc ? Icons.description : 
                                  isPpt ? Icons.slideshow :
                                  Icons.note,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(note.title),
                              subtitle: Text('Added: ${note.createdAt.toString().split('.').first}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () => _viewNote(note),
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
      ),
    );
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

  Future<String?> _showTitleDialog(String action) {
    _noteTitleController.clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Note'),
        content: TextField(
          controller: _noteTitleController,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, _noteTitleController.text),
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
        String? fileId = await _driveService.uploadFile(
          tempPath,
          fileName,
          widget.unit.folderId!,
        );
        
        if (fileId != null && mounted) {
          setState(() {
            _notes.add(Note(
              id: DateTime.now().toString(),
              title: title,
              content: _textNoteController.text,
              fileId: fileId,
              createdAt: DateTime.now(),
            ));
          });
          
          _textNoteController.clear();
          await _saveNotes();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ "$title" created'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    String? title = await _showTitleDialog('Upload Image');
    if (title == null) return;

    try {
      setState(() => _isLoading = true);
      
      String fileName = '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      if (widget.unit.folderId != null) {
        String? fileId = await _driveService.uploadFile(
          image.path,
          fileName,
          widget.unit.folderId!,
        );
        
        if (fileId != null) {
          setState(() {
            _notes.add(Note(
              id: DateTime.now().toString(),
              title: title,
              fileId: fileId,
              createdAt: DateTime.now(),
            ));
          });
          await _saveNotes();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Image "$title" uploaded'), backgroundColor: Colors.orange),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _captureImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    String? title = await _showTitleDialog('Capture Image');
    if (title == null) return;

    try {
      setState(() => _isLoading = true);
      
      String fileName = '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      if (widget.unit.folderId != null) {
        String? fileId = await _driveService.uploadFile(
          image.path,
          fileName,
          widget.unit.folderId!,
        );
        
        if (fileId != null) {
          setState(() {
            _notes.add(Note(
              id: DateTime.now().toString(),
              title: title,
              fileId: fileId,
              createdAt: DateTime.now(),
            ));
          });
          await _saveNotes();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Image "$title" captured'), backgroundColor: Colors.purple),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    String? title = await _showTitleDialog('Upload File');
    if (title == null) return;

    try {
      setState(() => _isLoading = true);
      
      File file = File(result.files.single.path!);
      String extension = result.files.single.name.split('.').last;
      String fileName = '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      if (widget.unit.folderId != null) {
        String? fileId = await _driveService.uploadFile(
          file.path,
          fileName,
          widget.unit.folderId!,
        );
        
        if (fileId != null) {
          setState(() {
            _notes.add(Note(
              id: DateTime.now().toString(),
              title: title,
              fileId: fileId,
              createdAt: DateTime.now(),
            ));
          });
          await _saveNotes();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ File "$title" uploaded'), backgroundColor: Colors.green),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<File?> _downloadFromDrive(String fileName) async {
    try {
      if (!mounted) return null;
      
      final driveApi = await _driveService.getDriveApi();
      if (driveApi == null) {
        throw Exception('Not authenticated');
      }

      final searchResult = await driveApi.files.list(
        q: "name contains '$fileName' and '${widget.unit.folderId}' in parents and trashed=false",
        spaces: 'drive',
      );

      if (searchResult.files == null || searchResult.files!.isEmpty) {
        throw Exception('File not found');
      }

      final driveFile = searchResult.files!.first;
      
      final downloadDir = await getApplicationDocumentsDirectory();
      final downloadPath = '${downloadDir.path}/${driveFile.name}';
      final downloadFile = File(downloadPath);

      final response = await driveApi.files.get(
        driveFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is drive.Media) {
        final sink = downloadFile.openWrite();
        await response.stream.pipe(sink);
        await sink.close();
        
        return downloadFile;
      }
      
      return null;
    } catch (e) {
      print("Download failed: $e");
      return null;
    }
  }

  Future<void> _viewNote(Note note) async {
    try {
      if (note.content != null && note.content!.isNotEmpty) {
        _showTextNoteDialog(note);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final file = await _downloadFromDrive(note.title);
      
      if (!mounted) return;
      Navigator.pop(context);

      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download file')),
        );
        return;
      }

      String fileName = note.title.toLowerCase();
      
      if (fileName.endsWith('.pdf')) {
        // Open PDF in-app with vertical scrolling
        await _viewPDFInApp(file, note.title);
      } 
      else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png')) {
        // Open images in-app
        await _viewImageFile(file, note.title);
      } 
      else if (fileName.endsWith('.txt')) {
        // Open text files in-app
        String content = await file.readAsString();
        _showTextNoteDialog(Note(
          id: note.id,
          title: note.title,
          content: content,
          createdAt: note.createdAt,
        ));
      } 
      else if (fileName.endsWith('.doc') || fileName.endsWith('.docx') || 
                fileName.endsWith('.ppt') || fileName.endsWith('.pptx')) {
        // Try multiple methods to open DOCX/PPT
        await _openDocument(file, note.title);
      } 
      else {
        // For other files, try external app
        await OpenFile.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showTextNoteDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note.title),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(note.content!),
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
  }

  // FIXED: Try multiple methods to open documents
  Future<void> _openDocument(File file, String fileName) async {
    // Method 1: Try with OpenFile (uses external apps)
    try {
      final result = await OpenFile.open(file.path);
      if (result.type == ResultType.done) {
        return; // Successfully opened
      }
      print("OpenFile failed: ${result.message}");
    } catch (e) {
      print("OpenFile error: $e");
    }

    // Method 2: Try sharing as fallback
    bool? share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open File'),
        content: Text('No app found to open "$fileName". Would you like to share it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Share'),
          ),
        ],
      ),
    );
    
    if (share == true) {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

  // PDF in-app viewer with vertical scrolling
  Future<void> _viewPDFInApp(File file, String fileName) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(fileName),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            body: PDFView(
              filePath: file.path,
              enableSwipe: true,
              swipeHorizontal: false,
              pageSnap: false,
              autoSpacing: true,
              pageFling: false,
            ),
          ),
        ),
      );
    } catch (e) {
      print("PDF Error: $e");
      // Fallback to open document method
      await _openDocument(file, fileName);
    }
  }

  Future<void> _viewImageFile(File file, String fileName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(fileName), backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }

  Color _getUnitColor() {
    String unitNum = widget.unit.name.replaceAll('Unit ', '');
    return _unitColors[unitNum] ?? Colors.purple;
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}