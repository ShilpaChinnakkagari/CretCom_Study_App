import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shilpa_study_app/models/user_profile.dart';
import 'package:shilpa_study_app/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _academicStartController;
  late TextEditingController _academicEndController;
  late TextEditingController _branchController;
  
  String _selectedProgram = 'UG';
  String _selectedYear = 'I';
  String _selectedSemester = 'I';
  
  final List<String> _ugYears = ['I', 'II', 'III', 'IV'];
  final List<String> _pgYears = ['I', 'II'];
  final List<String> _semesters = ['I', 'II'];

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _academicStartController = TextEditingController(text: DateTime.now().year.toString());
    _academicEndController = TextEditingController(text: (DateTime.now().year + 4).toString());
    _branchController = TextEditingController();
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      try {
        Map<String, dynamic> json = jsonDecode(profileJson);
        _nameController.text = json['name'] ?? _nameController.text;
        _branchController.text = json['branch'] ?? '';
        _selectedProgram = json['program'] ?? 'UG';
        _selectedYear = json['currentYear'] ?? 'I';
        _selectedSemester = json['currentSemester'] ?? 'I';
        _academicStartController.text = json['academicStart'] ?? _academicStartController.text;
        _academicEndController.text = json['academicEnd'] ?? _academicEndController.text;
        setState(() {});
      } catch (e) {
        print("Error loading profile: $e");
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = UserProfile(
      name: _nameController.text,
      email: _emailController.text,
      program: _selectedProgram,
      currentYear: _selectedYear,
      currentSemester: _selectedSemester,
      academicStart: _academicStartController.text,
      academicEnd: _academicEndController.text,
      branch: _branchController.text,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(profile.toJson()));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profile saved'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
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
                        'Personal Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Card(
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
                        'Academic Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _selectedProgram,
                        decoration: const InputDecoration(
                          labelText: 'Program',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'UG', child: Text('Undergraduate (UG)')),
                          DropdownMenuItem(value: 'PG', child: Text('Postgraduate (PG)')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedProgram = value!;
                            _selectedYear = _selectedProgram == 'UG' ? 'I' : 'I';
                          });
                        },
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedYear,
                              decoration: const InputDecoration(
                                labelText: 'Current Year',
                                border: OutlineInputBorder(),
                              ),
                              items: (_selectedProgram == 'UG' ? _ugYears : _pgYears)
                                  .map((year) => DropdownMenuItem(
                                        value: year,
                                        child: Text('Year $year'),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() => _selectedYear = value!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedSemester,
                              decoration: const InputDecoration(
                                labelText: 'Semester',
                                border: OutlineInputBorder(),
                              ),
                              items: _semesters
                                  .map((sem) => DropdownMenuItem(
                                        value: sem,
                                        child: Text('Semester $sem'),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() => _selectedSemester = value!),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: _branchController,
                        decoration: const InputDecoration(
                          labelText: 'Department/Branch',
                          hintText: 'e.g., Computer Science, ECE, Mechanical',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_tree),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _academicStartController,
                              decoration: const InputDecoration(
                                labelText: 'Start Year',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value!.isEmpty) return 'Required';
                                if (value.length != 4) return 'Enter 4-digit year';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _academicEndController,
                              decoration: const InputDecoration(
                                labelText: 'End Year',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value!.isEmpty) return 'Required';
                                if (value.length != 4) return 'Enter 4-digit year';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Profile', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}