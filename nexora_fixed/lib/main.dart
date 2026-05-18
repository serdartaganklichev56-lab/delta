import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const DeltaApp());
}

class DeltaApp extends StatelessWidget {
  const DeltaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snap.hasData) {
            return FutureBuilder(
              future: AuthService().getUser(snap.data!.uid),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (userSnap.data == null) {
                  return const AuthScreen();
                }
                return HomeScreen(user: userSnap.data!);
              },
            );
          }
          return const AuthScreen();
        },
      ),
    );
  }
}
