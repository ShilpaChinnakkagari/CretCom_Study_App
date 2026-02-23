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

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DriveService _driveService = DriveService();
  UserProfile? _userProfile;
  List<Map<String, dynamic>> _allSubjects = [];
  List<Map<String, dynamic>> _currentYearSubjects = [];
  bool _isLoading = true;
  
  String? _navigateYear;
  String? _navigateSemester;
  Map<String, dynamic>? _navigateSubject;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadAllSubjects();
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
                  
                  // Get notes count
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
                  
                  // Get notes count
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
                  
                  // Try multiple key patterns
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
                  
                  // Get notes count
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
          setState(() {}); // Force UI rebuild
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
          
          // FORCE IMMEDIATE REFRESH
          await _loadAllSubjects();
          if (mounted) {
            setState(() {}); // Force UI rebuild
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final themeService = Provider.of<ThemeService>(context);

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
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? _buildNoProfileView()
              : _currentYearSubjects.isEmpty
                  ? _buildEmptySubjectsView()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadAllSubjects();
                        setState(() {});
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Year ${_userProfile!.currentYear} • Semester ${_userProfile!.currentSemester}',
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userProfile!.branch.isEmpty
                                        ? '${_userProfile!.academicStart}-${_userProfile!.academicEnd}'
                                        : '${_userProfile!.branch} • ${_userProfile!.academicStart}-${_userProfile!.academicEnd}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            const Text(
                              'Your Subjects',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            
                            ..._currentYearSubjects.map((subject) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade700,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.white,
                                            child: Text(
                                              subject['name'][0].toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  subject['name'],
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
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
                                    
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      child: Column(
                                        children: subject['units'].map<Widget>((unit) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      unit['name'].replaceAll('Unit ', ''),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blue.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        unit['name'],
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: unit['notesCount'] > 0
                                                              ? Colors.green.shade50
                                                              : Colors.grey.shade100,
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          '${unit['notesCount']} notes',
                                                          style: TextStyle(
                                                            color: unit['notesCount'] > 0
                                                                ? Colors.green.shade700
                                                                : Colors.grey.shade600,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.arrow_forward,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                  onPressed: () => _navigateToNotes(subject, unit),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildDrawer(BuildContext context, User? user, ThemeService themeService) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? 'Student'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            decoration: const BoxDecoration(color: Colors.blue),
          ),
          
          ListTile(
            leading: const Icon(Icons.cloud_upload, color: Colors.green),
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
            leading: const Icon(Icons.person, color: Colors.blue),
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
            leading: const Icon(Icons.palette, color: Colors.purple),
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
            leading: const Icon(Icons.upload_file, color: Colors.orange),
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
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.calendar_today),
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
              leading: const Icon(Icons.school),
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
              leading: const Icon(Icons.book),
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
            leading: Icon(Icons.looks_one, color: Colors.blue),
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

  Widget _buildNoProfileView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          const Text(
            'Complete Your Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Set up your academic details to see your dashboard',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 30),
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
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySubjectsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          const Text(
            'No Subjects Yet',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create your first subject to see it here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 30),
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
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}