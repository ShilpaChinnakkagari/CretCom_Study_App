import 'dart:io' as io;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class DriveService {
  final AuthService _authService = AuthService();
  static const String _appFolderName = 'ShilpaStudyApp';

  // Store folder IDs locally
  final Map<String, String> _folderIds = {};

  // Get Drive API
  Future<drive.DriveApi?> getDriveApi() async {
    return await _authService.getDriveApi();
  }

  // Initialize app folder structure
  Future<bool> initializeAppFolder() async {
    try {
      final driveApi = await _authService.getDriveApi();
      if (driveApi == null) {
        print("❌ Failed to get Drive API - user not authenticated");
        return false;
      }

      // Load saved folder IDs safely
      await _loadFolderIds();

      // Check if main app folder exists
      String? appFolderId = _folderIds['root'];
      
      if (appFolderId == null) {
        print("📁 Creating main app folder: $_appFolderName");
        
        // Search for existing folder first
        final searchResult = await driveApi.files.list(
          q: "name='$_appFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
          spaces: 'drive',
        );
        
        if (searchResult.files != null && searchResult.files!.isNotEmpty) {
          appFolderId = searchResult.files!.first.id;
          print("✅ Found existing folder: $appFolderId");
        } else {
          // Create new folder
          final folder = drive.File()
            ..name = _appFolderName
            ..mimeType = 'application/vnd.google-apps.folder';
          
          final created = await driveApi.files.create(folder);
          appFolderId = created.id;
          print("✅ Created new folder: $appFolderId");
        }
        
        _folderIds['root'] = appFolderId!;
        await _saveFolderIds();
      }

      return true;
    } catch (e) {
      print('❌ Error initializing Drive: $e');
      return false;
    }
  }

  // Create academic year folder
  Future<String?> createYearFolder(String year) async {
    return await _createFolder(year, _folderIds['root']);
  }

  // Create semester folder
  Future<String?> createSemesterFolder(String semester, String parentId) async {
    return await _createFolder(semester, parentId);
  }

  // Create subject folder
  Future<String?> createSubjectFolder(String subjectName, String courseCode, String parentId) async {
    return await _createFolder('$subjectName ($courseCode)', parentId);
  }

  // Create unit folder
  Future<String?> createUnitFolder(String unit, String parentId) async {
    return await _createFolder('Unit $unit', parentId);
  }

  // Generic folder creator
  Future<String?> _createFolder(String name, String? parentId) async {
    try {
      final driveApi = await _authService.getDriveApi();
      if (driveApi == null) {
        print("❌ Cannot create folder - Drive API not available");
        print("   🔄 Trying to refresh Google Sign-In...");
        
        // Try to refresh Google Sign-In
        final googleUser = await _authService.getCurrentGoogleUser();
        if (googleUser == null) {
          print("❌ Still not authenticated - user needs to sign in again");
          return null;
        }
        
        print("✅ Got Google user: ${googleUser.email}");
        
        // Try one more time
        final newDriveApi = await _authService.getDriveApi();
        if (newDriveApi == null) {
          print("❌ Still cannot get Drive API");
          return null;
        }
        
        // Use the new API to create folder
        return await _createFolderWithApi(newDriveApi, name, parentId);
      }

      return await _createFolderWithApi(driveApi, name, parentId);
    } catch (e) {
      print('❌ Error creating folder $name: $e');
      return null;
    }
  }

  // Helper method to actually create folder with API
  Future<String?> _createFolderWithApi(drive.DriveApi driveApi, String name, String? parentId) async {
    try {
      if (parentId == null) {
        print("❌ Cannot create folder - no parent ID");
        return null;
      }

      print("📁 Creating folder: $name in parent: $parentId");

      // Check if folder already exists
      final searchResult = await driveApi.files.list(
        q: "name='$name' and '$parentId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
      );
      
      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        print("✅ Folder already exists: ${searchResult.files!.first.id}");
        return searchResult.files!.first.id;
      }

      // Create new folder
      final folder = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentId];

      final created = await driveApi.files.create(folder);
      print("✅ Folder created successfully: ${created.id}");
      return created.id;
    } catch (e) {
      print('❌ Error in folder creation: $e');
      return null;
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

  // Load folder IDs safely
  Future<void> _loadFolderIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      _folderIds.clear();
      
      for (String key in keys) {
        // Only load string values that look like folder IDs
        if (key.startsWith('year_') || 
            key.startsWith('semester_') || 
            key.startsWith('subject_') || 
            key.startsWith('unit_') || 
            key == 'root') {
          
          var value = prefs.get(key);
          if (value is String) {
            _folderIds[key] = value;
          } else {
            // Remove corrupted data
            prefs.remove(key);
            print("🧹 Removed corrupted data for key: $key");
          }
        }
      }
      
      print("✅ Loaded ${_folderIds.length} folder IDs");
    } catch (e) {
      print('❌ Error loading folder IDs: $e');
    }
  }

  // Upload file to specific folder
  Future<bool> uploadFile(
    String filePath, 
    String fileName, 
    String folderId, {
    String? mimeType,
  }) async {
    try {
      final driveApi = await _authService.getDriveApi();
      if (driveApi == null) {
        print("❌ Cannot upload file - not authenticated");
        return false;
      }

      final file = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final bytes = io.File(filePath);
      final media = drive.Media(bytes.openRead(), bytes.lengthSync());
      
      await driveApi.files.create(
        file,
        uploadMedia: media,
      );
      
      print("✅ File uploaded successfully: $fileName");
      return true;
    } catch (e) {
      print('❌ Error uploading: $e');
      return false;
    }
  }

  // Get folder ID for root
  String? getRootFolderId() {
    return _folderIds['root'];
  }
}