import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class QuestionBankScreen extends StatefulWidget {
  final AcademicYear year;
  final Semester semester;
  final Subject subject;
  final Unit unit;

  const QuestionBankScreen({
    super.key,
    required this.year,
    required this.semester,
    required this.subject,
    required this.unit,
  });

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  final DriveService _driveService = DriveService();
  final List<QuestionBank> _questionBanks = [];
  bool _isLoading = false;
  late final String _storageKey;

  @override
  void initState() {
    super.initState();
    _storageKey = 'qb_${widget.unit.folderId ?? 'temp'}';
    _loadQuestionBanks();
  }

  Future<void> _loadQuestionBanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? qbJson = prefs.getString(_storageKey);
      
      if (qbJson != null) {
        final List<dynamic> jsonList = jsonDecode(qbJson);
        setState(() {
          _questionBanks.clear();
          _questionBanks.addAll(jsonList.map((json) => QuestionBank.fromJson(json)).toList());
        });
        print("✅ Loaded ${_questionBanks.length} question banks");
      }
    } catch (e) {
      print("Error loading question banks: $e");
    }
  }

  Future<void> _saveQuestionBanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String qbJson = jsonEncode(_questionBanks.map((qb) => qb.toJson()).toList());
      await prefs.setString(_storageKey, qbJson);
      print("✅ Saved ${_questionBanks.length} question banks");
    } catch (e) {
      print("Error saving question banks: $e");
    }
  }

  Future<void> _uploadQuestionBank() async {
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
              _questionBanks.add(QuestionBank(
                id: DateTime.now().toString(),
                title: fileName,
                folderId: widget.unit.folderId,
              ));
            });
            
            await _saveQuestionBanks();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✅ Question bank uploaded'), backgroundColor: Colors.green),
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

  Future<File?> _downloadFromDrive(String fileName) async {
    try {
      if (!mounted) return null;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
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
        throw Exception('Unexpected response type');
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

  void _viewQuestionBank(QuestionBank qb) async {
    final file = await _downloadFromDrive(qb.title);
    if (file != null && mounted) {
      String lowerName = qb.title.toLowerCase();
      
      if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg') || lowerName.endsWith('.png')) {
        // View image
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(qb.title),
                backgroundColor: Colors.black,
              ),
              body: Center(
                child: InteractiveViewer(
                  child: Image.file(file),
                ),
              ),
            ),
          ),
        );
      } else if (lowerName.endsWith('.pdf')) {
        // View PDF
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(qb.title),
                backgroundColor: Colors.red,
              ),
              body: PDFView(
                filePath: file.path,
              ),
            ),
          ),
        );
      } else {
        // Share other files
        await Share.shareXFiles([XFile(file.path)]);
      }
    }
  }

  Future<void> _deleteQuestionBank(QuestionBank qb) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${qb.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _questionBanks.remove(qb);
              });
              await _saveQuestionBanks();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ Deleted'), backgroundColor: Colors.orange),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.unit.name} - Question Bank'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuestionBanks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload Button Card
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Upload Question Paper',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _uploadQuestionBank,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_isLoading ? 'Uploading...' : 'Upload Question Bank'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // List of Question Banks
          Expanded(
            child: _questionBanks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.question_answer,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No question banks yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload your first question paper above!',
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
                    itemCount: _questionBanks.length,
                    itemBuilder: (context, index) {
                      final qb = _questionBanks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: const Icon(Icons.question_answer, color: Colors.green),
                          ),
                          title: Text(qb.title),
                          subtitle: const Text('Question Bank'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.blue),
                                onPressed: () => _viewQuestionBank(qb),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteQuestionBank(qb),
                              ),
                            ],
                          ),
                          onTap: () => _viewQuestionBank(qb),
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