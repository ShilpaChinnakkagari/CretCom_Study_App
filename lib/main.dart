import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shilpa_study_app/screens/login_screen.dart';
import 'package:shilpa_study_app/screens/home_screen.dart';
import 'package:shilpa_study_app/services/auth_service.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';  // ADD THIS LINE

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shilpa Study App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData) {
              return const HomeScreen();
            }
            return const LoginScreen();
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}