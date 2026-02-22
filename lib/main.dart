import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Listen to auth state changes
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user == null) {
      print('🔥 Auth State: User is currently signed out!');
    } else {
      print('🔥 Auth State: User is signed in as ${user.email}');
    }
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shilpa Study App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            print("✅ USER IS SIGNED IN: ${snapshot.data!.email}");
            return const HomeScreen();
          }
          
          print("❌ USER NOT SIGNED IN");
          return const LoginScreen();
        },
      ),
    );
  }
}