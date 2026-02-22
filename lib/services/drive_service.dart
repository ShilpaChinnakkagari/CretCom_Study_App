import 'dart:io' as io;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class DriveService {
  final AuthService _authService = AuthService();
  static const String _appFolderName = 'ShilpaStudyApp';

  // Store folder IDs locally (NO actual files stored)
  final Map<String, String> _folderIds = {};

  // Initialize app folder structure
  Future<bool> initializeAppFolder() async {
    try {
      final driveApi = await _authService.getDriveApi();
      if (driveApi == null) return false;

      // Load saved folder IDs
      await _loadFolderIds();

      // Check if main app folder exists
      String? appFolderId = _folderIds['root'];
      
      if (appFolderId == null) {
        // Create main folder
        final folder = drive.File()
          ..name = _appFolderName
          ..mimeType = 'application/vnd.google-apps.folder';
        
        final created = await driveApi.files.create(folder);
        appFolderId = created.id;
        _folderIds['root'] = appFolderId!;
        await _saveFolderIds();
      }

      return true;
    } catch (e) {
      print('Error initializing: $e');
      return false;
    }
  }

  // Create academic year folder (I, II, III, IV)
  Future<String?> createYearFolder(String year, {String? parentId}) async {
    return await _createFolder(year, parentId ?? _folderIds['root']);
  }

  // Create semester folder (Semester I, Semester II)
  Future<String?> createSemesterFolder(String semester, String parentId) async {
    return await _createFolder('Semester $semester', parentId);
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
      if (driveApi == null) return null;

      final folder = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = parentId != null ? [parentId] : null;

      final created = await driveApi.files.create(folder);
      return created.id;
    } catch (e) {
      print('Error creating folder: $e');
      return null;
    }
  }

  // Save folder IDs locally (only IDs, no files)
  Future<void> _saveFolderIds() async {
    final prefs = await SharedPreferences.getInstance();
    _folderIds.forEach((key, value) {
      prefs.setString(key, value);
    });
  }

  // Load folder IDs
  Future<void> _loadFolderIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (String key in keys) {
      _folderIds[key] = prefs.getString(key)!;
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
      if (driveApi == null) return false;

      final file = drive.File()
        ..name = fileName
        ..parents = [folderId];

      // Read file bytes
      final bytes = await _readFileBytes(filePath);
      
      final media = drive.Media(bytes.openRead(), bytes.lengthSync());
      
      await driveApi.files.create(
        file,
        uploadMedia: media,
      );
      
      return true;
    } catch (e) {
      print('Error uploading: $e');
      return false;
    }
  }

  // Helper to read file
  Future<io.File> _readFileBytes(String path) async {
    return io.File(path);
  }
}