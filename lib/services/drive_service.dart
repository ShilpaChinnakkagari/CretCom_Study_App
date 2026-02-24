import 'dart:io' as io;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class DriveService {
  final AuthService _authService = AuthService();
  static const String _appFolderName = 'ShilpaCretcom';

  // Store folder IDs locally
  final Map<String, String> _folderIds = {};

  bool isUserSignedIn() {
    return _authService.currentUser != null;
  }

  // Get Drive API with better error handling
  Future<drive.DriveApi?> getDriveApi() async {
    try {
      final api = await _authService.getDriveApi();
      if (api == null) {
        print("⚠️ Drive API is null - trying to refresh sign in");
        
        final googleUser = await _authService.getCurrentGoogleUser();
        if (googleUser != null) {
          print("✅ Got Google user: ${googleUser.email}");
          return await _authService.getDriveApi();
        } else {
          print("⚠️ No Google user - forcing sign in");
          await _authService.forceSignIn();
          return await _authService.getDriveApi();
        }
      }
      return api;
    } catch (e) {
      print('❌ Error getting Drive API: $e');
      return null;
    }
  }

  // Check if folder is synced
  bool isFolderSynced(String key) {
    return _folderIds.containsKey(key);
  }

  // Initialize app root folder
  Future<bool> initializeAppFolder() async {
    try {
      final driveApi = await getDriveApi();
      if (driveApi == null) {
        print("❌ Failed to get Drive API");
        return false;
      }

      await _loadFolderIds();

      String? rootFolderId = _folderIds['root'];
      
      if (rootFolderId == null) {
        print("📁 Creating root folder: $_appFolderName");
        
        final searchResult = await driveApi.files.list(
          q: "name='$_appFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
          spaces: 'drive',
        );
        
        if (searchResult.files != null && searchResult.files!.isNotEmpty) {
          rootFolderId = searchResult.files!.first.id;
          print("✅ Found existing root folder: $rootFolderId");
        } else {
          final folder = drive.File()
            ..name = _appFolderName
            ..mimeType = 'application/vnd.google-apps.folder';
          
          final created = await driveApi.files.create(folder);
          rootFolderId = created.id;
          print("✅ Created new root folder: $rootFolderId");
        }
        
        _folderIds['root'] = rootFolderId!;
        await _saveFolderIds();
      }

      return true;
    } catch (e) {
      print('❌ Error initializing Drive: $e');
      return false;
    }
  }

  // Get root folder ID
  String? getRootFolderId() {
    return _folderIds['root'];
  }

  // Create academic year folder
  Future<String?> createYearFolder(String year, String program) async {
    String folderName = 'Year $year';
    
    try {
      final driveApi = await getDriveApi();
      if (driveApi == null) return null;
      
      String? parentId = _folderIds['root'];
      
      if (parentId == null) {
        bool initialized = await initializeAppFolder();
        if (!initialized) return null;
        parentId = _folderIds['root'];
      }
      
      String programKey = 'program_$program';
      String? programFolderId = _folderIds[programKey];
      
      if (programFolderId == null) {
        programFolderId = await _createFolder(program, parentId!);
        if (programFolderId != null) {
          _folderIds[programKey] = programFolderId;
          await _saveFolderIds();
        }
      }
      
      if (programFolderId == null) return null;
      
      return await _createFolder(folderName, programFolderId);
    } catch (e) {
      print('❌ Error creating year folder: $e');
      return null;
    }
  }

  // Create semester folder
  Future<String?> createSemesterFolder(String semester, String parentId) async {
    return await _createFolder('Semester $semester', parentId);
  }

  // Create subject folder with unique name
  Future<String?> createSubjectFolder(String subjectName, String courseCode, String parentId) async {
    String folderName = '$subjectName ($courseCode)';
    return await _createFolder(folderName, parentId);
  }

  // Create unit folder
  Future<String?> createUnitFolder(String unit, String parentId) async {
    return await _createFolder('Unit $unit', parentId);
  }

  // Generic folder creator with duplicate check
  Future<String?> _createFolder(String name, String parentId) async {
    try {
      final driveApi = await getDriveApi();
      if (driveApi == null) {
        print("❌ Cannot create folder - Drive API not available");
        return null;
      }

      print("📁 Creating folder: $name in parent: $parentId");

      final searchResult = await driveApi.files.list(
        q: "name='$name' and '$parentId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
      );
      
      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        print("✅ Folder already exists: ${searchResult.files!.first.id}");
        return searchResult.files!.first.id;
      }

      final folder = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentId];

      final created = await driveApi.files.create(folder);
      print("✅ Folder created: ${created.id}");
      return created.id;
    } catch (e) {
      print('❌ Error creating folder: $e');
      return null;
    }
  }

  // FIXED: Returns String? instead of bool
  Future<String?> uploadFile(String filePath, String fileName, String folderId) async {
    try {
      final driveApi = await getDriveApi();
      if (driveApi == null) {
        print("❌ Cannot upload file - not authenticated");
        return null;
      }

      final file = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final bytes = io.File(filePath);
      final media = drive.Media(bytes.openRead(), bytes.lengthSync());
      
      final uploadedFile = await driveApi.files.create(
        file,
        uploadMedia: media,
      );
      
      print("✅ File uploaded: $fileName with ID: ${uploadedFile.id}");
      return uploadedFile.id;
    } catch (e) {
      print('❌ Error uploading: $e');
      return null;
    }
  }

  // Delete folder and all contents from Drive
  Future<bool> deleteFolder(String folderId) async {
    try {
      final driveApi = await getDriveApi();
      if (driveApi == null) {
        print("❌ Cannot delete folder - not authenticated");
        return false;
      }

      await driveApi.files.delete(folderId);
      print("✅ Folder deleted from Drive: $folderId");
      return true;
    } catch (e) {
      print('❌ Error deleting folder: $e');
      return false;
    }
  }

  // Save folder IDs locally
  Future<void> _saveFolderIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _folderIds.forEach((key, value) {
        prefs.setString(key, value);
      });
    } catch (e) {
      print('❌ Error saving folder IDs: $e');
    }
  }

  // Load folder IDs
  Future<void> _loadFolderIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      _folderIds.clear();
      
      for (String key in keys) {
        if (key.startsWith('year_') || 
            key.startsWith('semester_') || 
            key.startsWith('subject_') || 
            key.startsWith('unit_') || 
            key.startsWith('program_') ||
            key == 'root') {
          
          var value = prefs.get(key);
          if (value is String) {
            _folderIds[key] = value;
          }
        }
      }
      
      print("✅ Loaded ${_folderIds.length} folder IDs");
    } catch (e) {
      print('❌ Error loading folder IDs: $e');
    }
  }

  // Clear folder ID from storage
  Future<void> clearFolderId(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      _folderIds.remove(key);
      print("🗑️ Removed folder ID: $key");
    } catch (e) {
      print('❌ Error removing folder ID: $e');
    }
  }
}