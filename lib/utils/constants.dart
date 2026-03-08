class AppConstants {
  // App name
  static const String appName = 'ShilpaCretcom';
  
  // Folder names
  static const String notesFolder = 'Notes';
  static const String questionBankFolder = 'Question Bank';
  static const String imagesFolder = 'Images';
  
  // MIME types
  static const String folderMimeType = 'application/vnd.google-apps.folder';
  static const String docMimeType = 'application/vnd.google-apps.document';
  static const String sheetMimeType = 'application/vnd.google-apps.spreadsheet';
  
  // SharedPreferences keys
  static const String mainFolderIdKey = 'main_folder_id';
  static const String userEmailKey = 'user_email';
  
  // Error messages
  static const String signInError = 'Failed to sign in. Please try again.';
  static const String driveError = 'Failed to connect to Google Drive.';
  static const String folderCreateError = 'Failed to create folder in Drive.';
  static const String uploadError = 'Failed to upload file.';
  
  // Success messages
  static const String signInSuccess = 'Signed in successfully!';
  static const String folderCreateSuccess = 'Folder created successfully!';
  static const String uploadSuccess = 'File uploaded successfully!';
}