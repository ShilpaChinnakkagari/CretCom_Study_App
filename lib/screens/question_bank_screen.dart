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
import 'package:open_file/open_file.dart';

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

class _QuestionBankScreenState extends State<QuestionBankScreen> with TickerProviderStateMixin {
  final DriveService _driveService = DriveService();
  final List<QuestionBank> _questionBanks = [];
  bool _isLoading = false;
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _bankTitleController = TextEditingController();
  final TextEditingController _marksController = TextEditingController();
  late final String _questionBankStorageKey;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  List<File> _selectedImages = [];

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
    _questionBankStorageKey = 'question_banks_${widget.unit.folderId ?? widget.unit.id}';
    
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
    
    _loadQuestionBanks();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
              '${widget.unit.name} - Question Bank',
              style: const TextStyle(
                fontSize: 16,
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
            // Add Question Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _showAddQuestionDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Question'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: unitColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            // Question Banks List
            Expanded(
              child: _questionBanks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.quiz,
                            size: 80,
                            color: unitColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No questions yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: unitColor.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first question above!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _questionBanks.length,
                      itemBuilder: (context, index) {
                        final bank = _questionBanks[index];
                        return _buildQuestionBankCard(bank, unitColor, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionBankCard(QuestionBank bank, Color unitColor, int index) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          (0.2 + (index * 0.1)).clamp(0.0, 0.8),
          (0.6 + (index * 0.1)).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      )),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: unitColor,
            child: Text(
              bank.questions.length.toString(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(
            bank.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Text('${bank.questions.length} questions'),
          children: [
            ...bank.questions.asMap().entries.map((entry) {
              int qIndex = entry.key;
              Question q = entry.value;
              return _buildQuestionItem(q, qIndex, bank, unitColor);
            }),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _showAddQuestionToBankDialog(bank),
                icon: const Icon(Icons.add),
                label: const Text('Add Question to this Bank'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: unitColor.withOpacity(0.1),
                  foregroundColor: unitColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionItem(Question q, int index, QuestionBank bank, Color unitColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: unitColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${q.marks} marks',
                  style: TextStyle(
                    color: unitColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete, size: 18),
                onPressed: () => _deleteQuestion(q, bank),
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Q${index + 1}: ${q.question}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (q.answer != null && q.answer!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIXED: Changed Icons.answer to Icons.question_answer
                  Icon(Icons.question_answer, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      q.answer!,
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (q.imageFileIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: q.imageFileIds.map((id) {
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text('Image', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddQuestionDialog() async {
    _bankTitleController.clear();
    _questionController.clear();
    _answerController.clear();
    _marksController.clear();
    _selectedImages.clear();

    String? bankTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Question Bank'),
        content: TextField(
          controller: _bankTitleController,
          decoration: const InputDecoration(
            labelText: 'Bank Title',
            hintText: 'e.g., Unit Test 1, Model Paper',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _bankTitleController.text),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (bankTitle == null || bankTitle.isEmpty) return;

    await _showAddQuestionForm(bankTitle);
  }

  Future<void> _showAddQuestionToBankDialog(QuestionBank bank) async {
    _questionController.clear();
    _answerController.clear();
    _marksController.clear();
    _selectedImages.clear();

    await _showAddQuestionForm(bank.title, existingBank: bank);
  }

  Future<void> _showAddQuestionForm(String bankTitle, {QuestionBank? existingBank}) async {
    bool isEditing = existingBank != null;
    
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEditing ? 'Add Question to ${existingBank!.title}' : 'Add Question to $bankTitle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _questionController,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _marksController,
                    decoration: const InputDecoration(
                      labelText: 'Marks',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _answerController,
                    decoration: const InputDecoration(
                      labelText: 'Answer (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final XFile? image = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image != null) {
                              setState(() {
                                _selectedImages.add(File(image.path));
                              });
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Add Image'),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(_selectedImages[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_questionController.text.isEmpty || _marksController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Question and marks are required')),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _saveQuestion(bankTitle, existingBank);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveQuestion(String bankTitle, QuestionBank? existingBank) async {
    try {
      setState(() => _isLoading = true);

      List<String> imageFileIds = [];

      // Upload images if any
      for (File image in _selectedImages) {
        if (widget.unit.folderId != null) {
          String fileName = 'question_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          // FIXED: Now receives String? instead of bool
          String? fileId = await _driveService.uploadFile(
            image.path,
            fileName,
            widget.unit.folderId!,
          );
          
          if (fileId != null) {
            imageFileIds.add(fileId);
          }
        }
      }

      Question newQuestion = Question(
        id: DateTime.now().toString(),
        question: _questionController.text,
        answer: _answerController.text.isNotEmpty ? _answerController.text : null,
        imageFileIds: imageFileIds,
        marks: int.parse(_marksController.text),
      );

      if (existingBank != null) {
        // Add to existing bank
        setState(() {
          existingBank.questions.add(newQuestion);
        });
      } else {
        // Create new bank
        QuestionBank newBank = QuestionBank(
          id: DateTime.now().toString(),
          title: bankTitle,
          questions: [newQuestion],
          folderId: widget.unit.folderId,
        );
        
        setState(() {
          _questionBanks.add(newBank);
        });
      }

      await _saveQuestionBanks();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Question saved'), backgroundColor: Colors.green),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteQuestion(Question question, QuestionBank bank) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text('Delete this question?'),
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

    if (confirm == true) {
      setState(() {
        bank.questions.remove(question);
        if (bank.questions.isEmpty) {
          _questionBanks.remove(bank);
        }
      });
      await _saveQuestionBanks();
    }
  }

  Future<void> _loadQuestionBanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? banksJson = prefs.getString(_questionBankStorageKey);
      
      if (banksJson != null && banksJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(banksJson);
        setState(() {
          _questionBanks.clear();
          _questionBanks.addAll(jsonList.map((json) => QuestionBank.fromJson(json)).toList());
        });
      }
    } catch (e) {
      print("Error loading question banks: $e");
    }
  }

  Future<void> _saveQuestionBanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String banksJson = jsonEncode(_questionBanks.map((bank) => bank.toJson()).toList());
      await prefs.setString(_questionBankStorageKey, banksJson);
    } catch (e) {
      print("Error saving question banks: $e");
    }
  }

  Color _getUnitColor() {
    String unitNum = widget.unit.name.replaceAll('Unit ', '');
    return _unitColors[unitNum] ?? Colors.purple;
  }
}