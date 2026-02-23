import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:shilpa_study_app/services/auth_service.dart';
import 'package:shilpa_study_app/services/theme_service.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'package:shilpa_study_app/screens/year_screen.dart';
import 'package:shilpa_study_app/screens/profile_screen.dart';
import 'package:shilpa_study_app/screens/unit_screen.dart';
import 'package:shilpa_study_app/screens/notes_screen.dart';
import 'package:shilpa_study_app/models/user_profile.dart';
import 'package:shilpa_study_app/models/academic_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DriveService _driveService = DriveService();
  UserProfile? _userProfile;
  List<Map<String, dynamic>> _allSubjects = [];
  List<Map<String, dynamic>> _currentYearSubjects = [];
  bool _isLoading = true;
  
  String? _navigateYear;
  String? _navigateSemester;
  Map<String, dynamic>? _navigateSubject;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    
    _loadUserProfile();
    _loadAllSubjects();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profileJson = prefs.getString('user_profile');
    
    if (profileJson != null) {
      try {
        Map<String, dynamic> json = jsonDecode(profileJson);
        setState(() {
          _userProfile = UserProfile.fromJson(json);
        });
        print("✅ Profile loaded: Year ${_userProfile?.currentYear}, Sem ${_userProfile?.currentSemester}");
      } catch (e) {
        print("❌ Error parsing profile: $e");
        _createDefaultProfile();
      }
    } else {
      _createDefaultProfile();
    }
  }

  void _createDefaultProfile() {
    setState(() {
      _userProfile = UserProfile(
        name: _authService.currentUser?.displayName ?? 'Student',
        email: _authService.currentUser?.email ?? '',
        program: 'UG',
        currentYear: 'I',
        currentSemester: 'I',
        academicStart: DateTime.now().year.toString(),
        academicEnd: (DateTime.now().year + 4).toString(),
        branch: '',
      );
    });
  }

  Future<void> _loadAllSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    List<Map<String, dynamic>> subjects = [];
    
    // Known unit folder IDs for Open CV (from logs)
    Map<String, Map<String, String>> knownUnitFolders = {
      '1rvDs5buDI1CYVq9I2u3qsYXhY6hdmSKa': { // Open CV subject folder
        'I': '1e0KvzJC7clNM54WTD78q5aVh_W6A8IKb',
        'II': '1Es7UYLb8CEjIDxLOVcrBh6MHrW_SjHtL',
        'III': '1RcE-uCLFATota0sxY2uoqdh8tOdgRca-',
        'IV': '1l42M52crMGnbzdMA9r4Upk9_-KaqXR0G',
        'V': '1cyNg0INdY3Xce7X2IdRF15qCOtHuODNv',
      }
    };
    
    // CORRECT unit folder IDs for RS (from your logs)
    Map<String, String> rsUnitFolders = {
      'I': '1FwBH7iwBKvZQ4BRXiZAkJ_IKOyJ3Vb6M',
      'II': '1SaaJxDQwNTRqTFBHsAYSMVIHn1nQFdff',
      'III': '1THxPyW7ssYDeNYqthrEiVsaw5ZK-ah1H',
      'IV': '1voQFo7IYHCuN5-LSCepMaCZSaIcfiNqx',
      'V': '1GLu9XplupRJ37zP9UnujMYXlktS-HJZz',
    };
    
    for (String key in keys) {
      if (key.startsWith('subjects_')) {
        String? subjectsJson = prefs.getString(key);
        if (subjectsJson != null && subjectsJson.isNotEmpty) {
          try {
            List<dynamic> subjectList = jsonDecode(subjectsJson);
            for (var subject in subjectList) {
              String subjectId = subject['id'] ?? '';
              String subjectFolderId = subject['folderId'] ?? '';
              String subjectName = subject['name'] ?? 'Unknown';
              String subjectCode = subject['courseCode'] ?? '000';
              
              print("📚 Processing subject: $subjectName ($subjectCode)");
              print("   Subject Folder ID: $subjectFolderId");
              print("   Subject ID: $subjectId");
              
              List<Map<String, dynamic>> units = [];
              List<String> unitLetters = ['I', 'II', 'III', 'IV', 'V'];
              
              // SPECIAL HANDLING FOR RS - Use exact folder IDs from logs
              if (subjectName == 'RS') {
                print("  🔧 Using exact RS unit folders");
                for (int i = 0; i < unitLetters.length; i++) {
                  String unit = unitLetters[i];
                  String unitFolderId = rsUnitFolders[unit]!;
                  int notesCount = 0;
                  
                  String notesKey = 'notes_$unitFolderId';
                  String? notesJson = prefs.getString(notesKey);
                  if (notesJson != null && notesJson.isNotEmpty) {
                    try {
                      List<dynamic> notesList = jsonDecode(notesJson);
                      notesCount = notesList.length;
                      print("  📝 RS Unit $unit has $notesCount notes");
                    } catch (e) {}
                  }
                  
                  units.add({
                    'name': 'Unit $unit',
                    'notesCount': notesCount,
                    'folderId': unitFolderId,
                  });
                }
              } 
              // SPECIAL HANDLING FOR OPEN CV - Use known folders
              else if (subjectName == 'Open CV') {
                print("  🔧 Using Open CV unit folders");
                for (int i = 0; i < unitLetters.length; i++) {
                  String unit = unitLetters[i];
                  String unitFolderId = knownUnitFolders[subjectFolderId]![unit]!;
                  int notesCount = 0;
                  
                  String notesKey = 'notes_$unitFolderId';
                  String? notesJson = prefs.getString(notesKey);
                  if (notesJson != null && notesJson.isNotEmpty) {
                    try {
                      List<dynamic> notesList = jsonDecode(notesJson);
                      notesCount = notesList.length;
                      print("  📝 Open CV Unit $unit has $notesCount notes");
                    } catch (e) {}
                  }
                  
                  units.add({
                    'name': 'Unit $unit',
                    'notesCount': notesCount,
                    'folderId': unitFolderId,
                  });
                }
              }
              // DYNAMIC LOOKUP FOR OTHER SUBJECTS
              else {
                for (String unit in unitLetters) {
                  String? unitFolderId;
                  int notesCount = 0;
                  
                  List<String> possibleKeys = [
                    'unit_${subjectFolderId}_$unit',
                    'units_${subjectFolderId}_$unit',
                    '${subjectFolderId}_$unit',
                    'unit_${subjectId}_$unit',
                  ];
                  
                  for (String possibleKey in possibleKeys) {
                    if (prefs.containsKey(possibleKey)) {
                      var value = prefs.get(possibleKey);
                      if (value is String) {
                        unitFolderId = value;
                        print("  ✅ Found unit $unit folder via key '$possibleKey': $unitFolderId");
                        break;
                      }
                    }
                  }
                  
                  if (unitFolderId != null && unitFolderId.isNotEmpty) {
                    String notesKey = 'notes_$unitFolderId';
                    String? notesJson = prefs.getString(notesKey);
                    if (notesJson != null && notesJson.isNotEmpty) {
                      try {
                        List<dynamic> notesList = jsonDecode(notesJson);
                        notesCount = notesList.length;
                        print("  📝 Unit $unit has $notesCount notes");
                      } catch (e) {}
                    }
                  }
                  
                  units.add({
                    'name': 'Unit $unit',
                    'notesCount': notesCount,
                    'folderId': unitFolderId,
                  });
                }
              }
              
              subjects.add({
                'name': subjectName,
                'code': subjectCode,
                'folderId': subjectFolderId,
                'id': subjectId,
                'year': 'III',
                'semester': 'II',
                'units': units,
              });
              
              print("✅ Added subject: $subjectName with ${units.length} units");
            }
          } catch (e) {
            print("❌ Error parsing subjects JSON: $e");
          }
        }
      }
    }
    
    setState(() {
      _allSubjects = subjects;
      _currentYearSubjects = List.from(_allSubjects);
      _isLoading = false;
    });
    
    print("✅ Loaded ${subjects.length} total subjects");
  }

  void _navigateToSubject(Map<String, dynamic> subject, {bool fromDashboard = true}) {
    final year = AcademicYear(
      id: fromDashboard ? (_userProfile?.currentYear ?? 'I') : (_navigateYear ?? 'I'),
      name: fromDashboard ? (_userProfile?.currentYear ?? 'I') : (_navigateYear ?? 'I'),
      type: _userProfile?.program ?? 'UG'
    );
    
    final semester = Semester(
      id: fromDashboard ? (_userProfile?.currentSemester ?? 'I') : (_navigateSemester ?? 'I'),
      name: 'Semester ${fromDashboard ? (_userProfile?.currentSemester ?? 'I') : (_navigateSemester ?? 'I')}'
    );
    
    final subjectObj = Subject(
      id: subject['id'],
      name: subject['name'],
      courseCode: subject['code'],
      folderId: subject['folderId'],
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnitScreen(
          academicType: _userProfile?.program ?? 'UG',
          year: year,
          semester: semester,
          subject: subjectObj,
        ),
      ),
    ).then((_) => _loadAllSubjects());
  }

  void _navigateToNotes(Map<String, dynamic> subject, Map<String, dynamic> unit) {
    final year = AcademicYear(
      id: _userProfile?.currentYear ?? 'I',
      name: _userProfile?.currentYear ?? 'I',
      type: _userProfile?.program ?? 'UG'
    );
    
    final semester = Semester(
      id: _userProfile?.currentSemester ?? 'I',
      name: 'Semester ${_userProfile?.currentSemester ?? 'I'}'
    );
    
    final subjectObj = Subject(
      id: subject['id'],
      name: subject['name'],
      courseCode: subject['code'],
      folderId: subject['folderId'],
    );
    
    final unitObj = Unit(
      id: unit['name'],
      name: unit['name'],
      folderId: unit['folderId'],
    );
    
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => NotesScreen(
          year: year,
          semester: semester,
          subject: subjectObj,
          unit: unitObj,
        ),
      ),
    ).then((changed) async {
      if (changed == true) {
        print("🔄 Changes detected, reloading subjects...");
        await _loadAllSubjects();
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  Future<void> _quickUpload() async {
    if (_currentYearSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subjects available'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_currentYearSubjects.length == 1) {
      await _uploadToSubject(_currentYearSubjects.first);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Subject'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _currentYearSubjects.length,
            itemBuilder: (context, index) {
              final subject = _currentYearSubjects[index];
              return ListTile(
                title: Text(subject['name']),
                subtitle: Text(subject['code']),
                onTap: () async {
                  Navigator.pop(context);
                  await _uploadToSubject(subject);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _uploadToSubject(Map<String, dynamic> subject) async {
    String? selectedUnit = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: subject['units'].map<Widget>((unit) {
            return ListTile(
              title: Text(unit['name']),
              onTap: () => Navigator.pop(context, unit['name']),
            );
          }).toList(),
        ),
      ),
    );

    if (selectedUnit != null) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        bool success = await _driveService.uploadFile(
          result.files.single.path!,
          result.files.single.name,
          subject['folderId'],
        );

        if (mounted) Navigator.pop(context);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Uploaded to ${subject['name']} - $selectedUnit')),
          );
          
          await _loadAllSubjects();
          if (mounted) {
            setState(() {});
          }
        }
      }
    }
  }

  // Helper method to get different colors for each unit
  Color _getUnitColor(String unitName, {required bool isDark}) {
    switch (unitName) {
      case 'Unit I':
        return isDark ? const Color(0xFF9C27B0) : Colors.purple.shade500; // Purple
      case 'Unit II':
        return isDark ? const Color(0xFF2196F3) : Colors.blue.shade500; // Blue
      case 'Unit III':
        return isDark ? const Color(0xFF4CAF50) : Colors.green.shade500; // Green
      case 'Unit IV':
        return isDark ? const Color(0xFFFF9800) : Colors.orange.shade500; // Orange
      case 'Unit V':
        return isDark ? const Color(0xFFF44336) : Colors.red.shade500; // Red
      default:
        return isDark ? const Color(0xFF9C27B0) : Colors.purple.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final themeService = Provider.of<ThemeService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shilpa Study App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, user, themeService),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.purple.shade300 : Colors.blue.shade300,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading your dashboard...',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : _userProfile == null
              ? _buildNoProfileView(isDark)
              : _currentYearSubjects.isEmpty
                  ? _buildEmptySubjectsView(isDark)
                  : _buildDashboard(isDark),
    );
  }

  Widget _buildDashboard(bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        _animationController.reset();
        _animationController.forward();
        await _loadAllSubjects();
        setState(() {});
      },
      color: isDark ? Colors.purple.shade300 : Colors.blue.shade300,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SHORTER GREETING CARD - Replace the existing one
SlideTransition(
  position: _slideAnimation,
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16), // Reduced from 24 to 16
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: isDark
            ? [const Color(0xFF6A1B9A), const Color(0xFF4A148C)]
            : [Colors.blue.shade400, Colors.blue.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16), // Reduced from 20 to 16
      boxShadow: [
        BoxShadow(
          color: (isDark ? Colors.purple.shade900 : Colors.blue.shade200)
              .withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${_userProfile?.name.split(' ').first ?? 'Student'}! 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20, // Reduced from 28 to 20
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Year ${_userProfile!.currentYear} • Semester ${_userProfile!.currentSemester}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _userProfile!.branch.isEmpty
                    ? '${_userProfile!.academicStart}-${_userProfile!.academicEnd}'
                    : '${_userProfile!.branch}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Text(
            '👋',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ],
    ),
  ),
),
              
              const SizedBox(height: 24),
              
              // Section Title
              SlideTransition(
                position: _slideAnimation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Subjects',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.purple.shade900.withOpacity(0.3)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentYearSubjects.length} subjects',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.purple.shade200 : Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subjects with ENHANCED COLORFUL UNITS
              ..._currentYearSubjects.asMap().entries.map((entry) {
                int index = entry.key;
                var subject = entry.value;
                
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: SlideTransition(
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
                    child: _buildSubjectCard(subject, isDark),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject Header - Beautiful gradient
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF7B1FA2), const Color(0xFF512DA8)]
                  : [Colors.blue.shade400, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.purple.shade900 : Colors.blue.shade200)
                    .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Subject icon with letter
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  subject['name'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject['code'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // ENHANCED COLORFUL UNITS - Beautiful cards
        Container(
          margin: const EdgeInsets.only(left: 16),
          child: Column(
            children: subject['units'].map<Widget>((unit) {
              bool isSynced = unit['folderId'] != null;
              Color unitColor = _getUnitColor(unit['name'], isDark: isDark);
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isSynced ? () => _navigateToNotes(subject, unit) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSynced
                              ? unitColor.withOpacity(0.3)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                        ),
                        boxShadow: isSynced
                            ? [
                                BoxShadow(
                                  color: unitColor.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Unit Circle - COLORFUL!
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: isSynced
                                  ? LinearGradient(
                                      colors: [
                                        unitColor,
                                        unitColor.withOpacity(0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: [
                                        isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                        isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                if (isSynced)
                                  BoxShadow(
                                    color: unitColor.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                unit['name'].replaceAll('Unit ', ''),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Unit info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  unit['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: isSynced
                                        ? (isDark ? Colors.white : Colors.grey.shade800)
                                        : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Notes count badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: unit['notesCount'] > 0
                                        ? unitColor.withOpacity(0.1)
                                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${unit['notesCount']} notes',
                                    style: TextStyle(
                                      color: unit['notesCount'] > 0
                                          ? unitColor
                                          : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Arrow button
                          if (isSynced)
                            Container(
                              decoration: BoxDecoration(
                                color: unitColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_forward,
                                  color: unitColor,
                                ),
                                onPressed: () => _navigateToNotes(subject, unit),
                                tooltip: 'Open notes',
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_outline,
                                size: 20,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, User? user, ThemeService themeService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // User Header with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF6A1B9A), const Color(0xFF4A148C)]
                    : [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: UserAccountsDrawerHeader(
              accountName: Text(
                user?.displayName ?? 'Student',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, size: 40, color: Colors.blue)
                    : null,
              ),
              decoration: const BoxDecoration(color: Colors.transparent),
            ),
          ),
          
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_upload, color: isDark ? Colors.green.shade300 : Colors.green.shade700),
            ),
            title: const Text('Sync to Google Drive'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing...')),
              );
            },
          ),
          
          const Divider(),
          
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
            ),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              ).then((_) => _loadUserProfile());
            },
          ),
          
          const Divider(),
          
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.palette, color: isDark ? Colors.purple.shade300 : Colors.purple.shade700),
            ),
            title: const Text('Theme'),
            trailing: DropdownButton<AppTheme>(
              value: themeService.currentTheme,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: AppTheme.light, child: Text('Light')),
                DropdownMenuItem(value: AppTheme.dark, child: Text('Dark')),
                DropdownMenuItem(value: AppTheme.system, child: Text('System')),
              ],
              onChanged: (value) {
                if (value != null) themeService.setTheme(value);
              },
            ),
          ),
          
          const Divider(),
          
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.upload_file, color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
            ),
            title: const Text('Quick Upload'),
            onTap: () async {
              Navigator.pop(context);
              await _quickUpload();
            },
          ),
          
          const Divider(),
          
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'NAVIGATE TO OTHER YEARS',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.blue),
            title: const Text('Select Year'),
            trailing: DropdownButton<String>(
              hint: const Text('Year'),
              value: _navigateYear,
              items: ['I', 'II', 'III', 'IV'].map((year) {
                return DropdownMenuItem(value: year, child: Text('Year $year'));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _navigateYear = value;
                  _navigateSemester = null;
                  _navigateSubject = null;
                });
              },
            ),
          ),
          
          if (_navigateYear != null)
            ListTile(
              leading: const Icon(Icons.school, color: Colors.green),
              title: const Text('Select Semester'),
              trailing: DropdownButton<String>(
                hint: const Text('Semester'),
                value: _navigateSemester,
                items: ['I', 'II'].map((sem) {
                  return DropdownMenuItem(value: sem, child: Text('Semester $sem'));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _navigateSemester = value;
                    _navigateSubject = null;
                  });
                },
              ),
            ),
          
          if (_navigateYear != null && _navigateSemester != null)
            ListTile(
              leading: const Icon(Icons.book, color: Colors.orange),
              title: const Text('Select Subject'),
              trailing: DropdownButton<Map<String, dynamic>>(
                hint: const Text('Subject'),
                value: _navigateSubject,
                items: _allSubjects.map((subject) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: subject,
                    child: Text('${subject['name']} (${subject['code']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _navigateSubject = value;
                  });
                  if (value != null) {
                    Navigator.pop(context);
                    _navigateToSubject(value, fromDashboard: false);
                  }
                },
              ),
            ),
          
          const Divider(),
          
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'QUICK ACCESS',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          
          ...['I', 'II', 'III', 'IV'].map((year) => ListTile(
            leading: CircleAvatar(
              radius: 15,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              child: Text(
                year,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
            title: Text('Year $year'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const YearScreen(academicType: 'UG'),
                ),
              );
            },
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildNoProfileView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 100,
              color: isDark ? Colors.purple.shade300 : Colors.blue.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'Complete Your Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Set up your academic details\nto see your personalized dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                ).then((_) => _loadUserProfile());
              },
              icon: const Icon(Icons.edit),
              label: const Text('Go to Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.purple.shade300 : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySubjectsView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 100,
              color: isDark ? Colors.purple.shade300 : Colors.blue.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'No Subjects Yet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first subject to see it here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YearScreen(academicType: 'UG'),
                  ),
                ).then((_) => _loadAllSubjects());
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Subject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.purple.shade300 : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}