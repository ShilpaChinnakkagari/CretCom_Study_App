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
  List<Map<String, dynamic>> _realSubjects = [];
  bool _isLoading = true;
  
  String? _selectedYear;
  String? _selectedSemester;
  Map<String, dynamic>? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadRealSubjects();
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
        print("✅ Profile loaded: ${_userProfile?.academicStart}-${_userProfile?.academicEnd}");
      } catch (e) {
        print("❌ Error parsing profile: $e");
        _createDefaultProfile();
      }
    } else {
      _createDefaultProfile();
    }
    setState(() => _isLoading = false);
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

  Future<void> _loadRealSubjects() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();
  
  List<Map<String, dynamic>> subjects = [];
  
  // Known unit folder IDs from your logs (for Open CV)
  Map<String, String> knownUnitFolders = {
    'I': '1e0KvzJC7clNM54WTD78q5aVh_W6A8IKb',
    'II': '1Es7UYLb8CEjIDxLOVcrBh6MHrW_SjHtL',
    'III': '1RcE-uCLFATota0sxY2uoqdh8tOdgRca-',
    'IV': '1l42M52crMGnbzdMA9r4Upk9_-KaqXR0G',
    'V': '1cyNg0INdY3Xce7X2IdRF15qCOtHuODNv',
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
            
            // Get unit folder IDs and notes counts
            List<Map<String, dynamic>> units = [];
            
            for (String unit in ['I', 'II', 'III', 'IV', 'V']) {
              String? unitFolderId;
              int notesCount = 0;
              
              // Method 1: Use known folder IDs for Open CV
              if (subjectFolderId == '1rvDs5buDI1CYVq9I2u3qsYXhY6hdmSKa') {
                unitFolderId = knownUnitFolders[unit];
                print("  ✅ Using known folder ID for Unit $unit: $unitFolderId");
              }
              
              // Method 2: Look for unit_SubjectId_Unit key
              if (unitFolderId == null) {
                String key1 = 'unit_${subjectId}_$unit';
                if (prefs.containsKey(key1)) {
                  var value = prefs.get(key1);
                  if (value is String) {
                    unitFolderId = value;
                    print("  ✅ Found unit $unit folder via key1: $unitFolderId");
                  }
                }
              }
              
              // Method 3: Look for unit_SubjectFolderId_Unit key
              if (unitFolderId == null && subjectFolderId.isNotEmpty) {
                String key2 = 'unit_${subjectFolderId}_$unit';
                if (prefs.containsKey(key2)) {
                  var value = prefs.get(key2);
                  if (value is String) {
                    unitFolderId = value;
                    print("  ✅ Found unit $unit folder via key2: $unitFolderId");
                  }
                }
              }
              
              // Method 4: Look for any key containing this unit and subject
              if (unitFolderId == null) {
                for (String k in keys) {
                  if (k.contains('unit_') && k.contains(unit) && 
                      (k.contains(subjectId) || k.contains(subjectFolderId))) {
                    var val = prefs.get(k);
                    if (val is String && val.length > 10) {
                      unitFolderId = val;
                      print("  ✅ Found unit $unit folder via search: $unitFolderId");
                      break;
                    }
                  }
                }
              }
              
              // Get notes count using the folder ID
              if (unitFolderId != null && unitFolderId.isNotEmpty) {
                String notesKey = 'notes_$unitFolderId';
                String? notesJson = prefs.getString(notesKey);
                if (notesJson != null && notesJson.isNotEmpty) {
                  try {
                    List<dynamic> notesList = jsonDecode(notesJson);
                    notesCount = notesList.length;
                    print("  📝 Unit $unit has $notesCount notes");
                  } catch (e) {
                    notesCount = 0;
                  }
                }
              }
              
              units.add({
                'name': 'Unit $unit',
                'notesCount': notesCount,
                'folderId': unitFolderId,
              });
            }
            
            subjects.add({
              'name': subjectName,
              'code': subjectCode,
              'folderId': subjectFolderId,
              'id': subjectId,
              'units': units,
            });
            
            print("✅ Added subject: $subjectName");
          }
        } catch (e) {
          print("❌ Error parsing subjects JSON: $e");
        }
      }
    }
  }
  
  setState(() {
    _realSubjects = subjects;
    _isLoading = false;
  });
  
  print("✅ Loaded ${subjects.length} subjects with real notes counts");
}

  void _navigateToUnit(String subjectName, String courseCode, String subjectId, String folderId) {
    final year = AcademicYear(
      id: _userProfile?.currentYear ?? 'I', 
      name: _userProfile?.currentYear ?? 'I', 
      type: _userProfile?.program ?? 'UG'
    );
    final semester = Semester(
      id: _userProfile?.currentSemester ?? 'I', 
      name: 'Semester ${_userProfile?.currentSemester ?? 'I'}'
    );
    final subject = Subject(
      id: subjectId,
      name: subjectName,
      courseCode: courseCode,
      folderId: folderId,
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnitScreen(
          academicType: _userProfile?.program ?? 'UG',
          year: year,
          semester: semester,
          subject: subject,
        ),
      ),
    ).then((_) => _loadRealSubjects());
  }

  void _navigateToNotes(String subjectName, String courseCode, String subjectId, String unitName, String? unitFolderId) {
    final year = AcademicYear(
      id: _userProfile?.currentYear ?? 'I', 
      name: _userProfile?.currentYear ?? 'I', 
      type: _userProfile?.program ?? 'UG'
    );
    final semester = Semester(
      id: _userProfile?.currentSemester ?? 'I', 
      name: 'Semester ${_userProfile?.currentSemester ?? 'I'}'
    );
    final subject = Subject(
      id: subjectId,
      name: subjectName,
      courseCode: courseCode,
      folderId: subjectId,
    );
    final unit = Unit(
      id: unitName,
      name: unitName,
      folderId: unitFolderId,
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotesScreen(
          year: year,
          semester: semester,
          subject: subject,
          unit: unit,
        ),
      ),
    ).then((_) => _loadRealSubjects());
  }

  Future<void> _quickUpload() async {
    if (_realSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subjects available'), backgroundColor: Colors.orange),
      );
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
            itemCount: _realSubjects.length,
            itemBuilder: (context, index) {
              final subject = _realSubjects[index];
              return ListTile(
                title: Text(subject['name']),
                subtitle: Text(subject['code']),
                onTap: () async {
                  Navigator.pop(context);
                  
                  String? selectedUnit = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Select Unit'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: ['I', 'II', 'III', 'IV', 'V'].map((unit) {
                          return ListTile(
                            title: Text('Unit $unit'),
                            onTap: () => Navigator.pop(context, unit),
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
                          SnackBar(content: Text('✅ Uploaded to ${subject['name']} - Unit $selectedUnit')),
                        );
                        _loadRealSubjects();
                      }
                    }
                  }
                },
              );
            },
          ),
        ),
      ),
    );
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
              : _realSubjects.isEmpty
                  ? _buildEmptySubjectsView()
                  : _buildDashboard(),
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
            onTap: () {
              Navigator.pop(context);
              _quickUpload();
            },
          ),
          
          const Divider(),
          
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'NAVIGATE TO',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Select Year'),
            trailing: DropdownButton<String>(
              hint: const Text('Year'),
              value: _selectedYear,
              items: ['I', 'II', 'III', 'IV'].map((year) {
                return DropdownMenuItem(value: year, child: Text('Year $year'));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedYear = value;
                  _selectedSemester = null;
                  _selectedSubject = null;
                });
              },
            ),
          ),
          
          if (_selectedYear != null)
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Select Semester'),
              trailing: DropdownButton<String>(
                hint: const Text('Semester'),
                value: _selectedSemester,
                items: ['I', 'II'].map((sem) {
                  return DropdownMenuItem(value: sem, child: Text('Semester $sem'));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSemester = value;
                    _selectedSubject = null;
                  });
                },
              ),
            ),
          
          if (_selectedYear != null && _selectedSemester != null)
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Select Subject'),
              trailing: DropdownButton<Map<String, dynamic>>(
                hint: const Text('Subject'),
                value: _selectedSubject,
                items: _realSubjects.map((subject) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: subject,
                    child: Text('${subject['name']} (${subject['code']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSubject = value;
                  });
                  if (value != null) {
                    Navigator.pop(context);
                    _navigateToUnit(
                      value['name'],
                      value['code'],
                      value['id'],
                      value['folderId'],
                    );
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
              ).then((_) => _loadRealSubjects());
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

  Widget _buildDashboard() {
    return SingleChildScrollView(
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userProfile!.branch.isEmpty
                      ? '${_userProfile!.academicStart}-${_userProfile!.academicEnd}'
                      : '${_userProfile!.branch} • ${_userProfile!.academicStart}-${_userProfile!.academicEnd}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
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
          
          ..._realSubjects.map((subject) => Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  subject['name'][0],
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
              title: Text(
                subject['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(subject['code']),
              children: [
                const Divider(),
                ...subject['units'].map<Widget>((unit) {
                  return ListTile(
                    leading: Container(
                      width: 30,
                      height: 30,
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
                    title: Text(
                      unit['name'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: unit['notesCount'] > 0 
                            ? Colors.green.shade50 
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${unit['notesCount']} notes',
                        style: TextStyle(
                          color: unit['notesCount'] > 0 
                              ? Colors.green.shade700 
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () {
                      _navigateToNotes(
                        subject['name'],
                        subject['code'],
                        subject['id'],
                        unit['name'],
                        unit['folderId'],
                      );
                    },
                  );
                }).toList(),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}