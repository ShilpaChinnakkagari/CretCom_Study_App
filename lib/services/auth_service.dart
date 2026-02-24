import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Store the GoogleSignIn instance to maintain state
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      'email',
      'profile',
    ],
  );

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      print("Starting Google Sign-In...");
      
      // First, ensure any existing sign-in is cleared
      await _googleSignIn.signOut();
      
      // Trigger Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print("Sign in cancelled by user");
        return null;
      }
      
      print("Google user selected: ${googleUser.email}");
      
      // Get authentication details
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      print("Got authentication tokens");
      
      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      print("Signing in to Firebase...");
      
      // Sign in to Firebase
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      print("Firebase sign in successful: ${userCredential.user?.email}");
      
      return userCredential.user;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      print("Signed out successfully");
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Get authenticated Drive API client
  Future<drive.DriveApi?> getDriveApi() async {
    try {
      // Check if user is signed in to Google
      final GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
      
      if (googleUser == null) {
        print("No Google user signed in - attempting to get current user");
        // Try to get the current user silently
        final currentUser = await _googleSignIn.signInSilently();
        if (currentUser == null) {
          print("Still no Google user - please sign in again");
          return null;
        }
        print("✅ Got Google user silently: ${currentUser.email}");
        
        final authHeaders = await currentUser.authHeaders;
        final client = GoogleAuthClient(authHeaders);
        return drive.DriveApi(client);
      }
      
      print("Getting Drive API for: ${googleUser.email}");
      final authHeaders = await googleUser.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      return drive.DriveApi(client);
    } catch (e) {
      print('Error getting Drive API: $e');
      return null;
    }
  }

  // Check if user is signed in
  User? get currentUser => _auth.currentUser;
  
  // Get the current Google user
  Future<GoogleSignInAccount?> getCurrentGoogleUser() async {
    // If there's a current user, return it
    if (_googleSignIn.currentUser != null) {
      return _googleSignIn.currentUser;
    }
    
    // Try to sign in silently
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      print('Error signing in silently: $e');
      return null;
    }
  }
  
  // Force sign in (use this when API calls fail)
  Future<User?> forceSignIn() async {
    try {
      print("Forcing sign in...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return null;
      }
      
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
          
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
          
      return userCredential.user;
    } catch (e) {
      print('Error forcing sign in: $e');
      return null;
    }
  }
}

// Helper class for authenticated HTTP requests
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}