import 'package:shilpa_study_app/services/drive_service.dart';
import 'package:shilpa_study_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  static final DriveService _driveService = DriveService();
  static final AuthService _authService = AuthService();

  // Sync all folders
  static Future<bool> syncAll() async {
    try {
      print("🔄 Starting full sync...");
      
      // Check authentication
      final user = _authService.currentUser;
      if (user == null) {
        print("❌ User not authenticated");
        return false;
      }

      // Initialize root folder
      final initialized = await _driveService.initializeAppFolder();
      if (!initialized) {
        print("❌ Failed to initialize Drive");
        return false;
      }

      // Get root folder ID
      final rootId = _driveService.getRootFolderId();
      if (rootId == null) {
        print("❌ Root folder not found");
        return false;
      }

      print("✅ Sync completed successfully");
      return true;
    } catch (e) {
      print("❌ Sync failed: $e");
      return false;
    }
  }

  // Get last sync time
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString('last_sync_time');
    if (timestamp != null) {
      return DateTime.parse(timestamp);
    }
    return null;
  }

  // Update last sync time
  static Future<void> updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
  }
}