import 'package:flutter/material.dart';
import 'package:shilpa_study_app/services/auth_service.dart';
import 'package:shilpa_study_app/screens/year_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shilpa Study App',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? 'Student'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'UNDERGRADUATE (UG)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 14,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.looks_one, color: Colors.blue, size: 20),
              ),
              title: const Text(
                'Year I',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YearScreen(academicType: 'UG'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.looks_two, color: Colors.blue, size: 20),
              ),
              title: const Text(
                'Year II',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YearScreen(academicType: 'UG'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.looks_3, color: Colors.blue, size: 20),
              ),
              title: const Text(
                'Year III',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YearScreen(academicType: 'UG'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.looks_4, color: Colors.blue, size: 20),
              ),
              title: const Text(
                'Year IV',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YearScreen(academicType: 'UG'),
                  ),
                );
              },
            ),
            const Divider(height: 32, thickness: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'POSTGRADUATE (PG)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 14,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.looks_one, color: Colors.green, size: 20),
              ),
              title: const Text(
                'Year I',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YearScreen(academicType: 'PG'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.looks_two, color: Colors.green, size: 20),
              ),
              title: const Text(
                'Year II',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YearScreen(academicType: 'PG'),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school,
                size: 80,
                color: Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Welcome, ${user?.displayName ?? 'Student'}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              user?.email ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud, color: Colors.blue.shade700),
                      const SizedBox(width: 10),
                      Text(
                        'Google Drive Connected',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'All your study materials are stored in:\n"ShilpaStudyApp" folder',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              '👈 Open drawer to select your academic year',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}