import 'package:flutter/material.dart';
import 'package:shilpa_study_app/models/academic_models.dart';
import 'package:shilpa_study_app/services/drive_service.dart';
import 'semester_screen.dart';


class YearScreen extends StatefulWidget {
  final String academicType; // "UG" or "PG"
  
  const YearScreen({super.key, required this.academicType});

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  final DriveService _driveService = DriveService();
  List<AcademicYear> _years = [];
  bool _isLoading = true;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeDriveAndLoadYears();
  }

  Future<void> _initializeDriveAndLoadYears() async {
    setState(() {
      _isLoading = true;
      _isInitializing = true;
    });
    
    try {
      // Initialize the root Drive folder first
      print("📁 Initializing root Drive folder...");
      final initialized = await _driveService.initializeAppFolder();
      
      if (initialized) {
        print("✅ Root folder initialized successfully");
        // Load saved folder IDs from DriveService
        _loadYears();
      } else {
        print("❌ Failed to initialize root folder");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to Google Drive'),
            backgroundColor: Colors.orange,
          ),
        );
        // Still load years even if Drive fails
        _loadYears();
      }
    } catch (e) {
      print("❌ Error initializing Drive: $e");
      _loadYears();
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _loadYears() {
    // Create years based on academic type
    List<AcademicYear> years = [];
    if (widget.academicType == "UG") {
      years = [
        AcademicYear(id: '1', name: 'I', type: 'UG'),
        AcademicYear(id: '2', name: 'II', type: 'UG'),
        AcademicYear(id: '3', name: 'III', type: 'UG'),
        AcademicYear(id: '4', name: 'IV', type: 'UG'),
      ];
    } else {
      years = [
        AcademicYear(id: '1', name: 'I', type: 'PG'),
        AcademicYear(id: '2', name: 'II', type: 'PG'),
      ];
    }
    
    // Try to load saved folder IDs from SharedPreferences
    _loadSavedFolderIds(years);
  }

  Future<void> _loadSavedFolderIds(List<AcademicYear> years) async {
    // In a real app, you'd load from SharedPreferences
    // For now, we'll just set the years
    setState(() {
      _years = years;
      _isLoading = false;
    });
  }

  Future<void> _createYearFolder(AcademicYear year) async {
    setState(() => _isLoading = true);
    try {
      print("📁 Creating folder for Year ${year.name}");
      
      // Ensure root folder exists
      final rootInitialized = await _driveService.initializeAppFolder();
      if (!rootInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize Google Drive folder'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Get root folder ID
      final rootId = _driveService.getRootFolderId();
      if (rootId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Root folder not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Create year folder
      final folderId = await _driveService.createYearFolder('Year ${year.name}');
      
      if (folderId != null) {
        setState(() {
          year.folderId = folderId;
        });
        
        print("✅ Year folder created: $folderId");
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Year ${year.name} folder created in Drive'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to create folder'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating folder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.academicType} - Select Year',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: widget.academicType == 'UG' ? Colors.blue : Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Loading years...'),
                ],
              ),
            )
          : _isInitializing
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('Connecting to Google Drive...'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _years.length,
                  itemBuilder: (context, index) {
                    final year = _years[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: widget.academicType == 'UG' 
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          radius: 25,
                          child: Text(
                            year.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: widget.academicType == 'UG' 
                                  ? Colors.blue 
                                  : Colors.green,
                            ),
                          ),
                        ),
                        title: Text(
                          'Year ${year.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          year.folderId == null 
                              ? '⏳ Not synced to Drive' 
                              : '✅ Synced to Drive',
                          style: TextStyle(
                            color: year.folderId == null 
                                ? Colors.orange 
                                : Colors.green,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (year.folderId == null)
                              IconButton(
                                icon: const Icon(Icons.cloud_upload, color: Colors.blue),
                                onPressed: _isLoading ? null : () => _createYearFolder(year),
                                tooltip: 'Sync to Google Drive',
                              ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward, color: Colors.grey),
                              onPressed: year.folderId == null
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SemesterScreen(
                                            academicType: widget.academicType,
                                            year: year,
                                          ),
                                        ),
                                      );
                                    },
                              tooltip: year.folderId == null 
                                  ? 'Sync first to continue' 
                                  : 'Enter Year',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}