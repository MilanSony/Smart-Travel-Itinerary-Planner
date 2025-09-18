import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'role_dispatcher_screen.dart'; // Import the new screen
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If a user is logged in, show the dispatcher screen to check their role
        if (snapshot.hasData) {
          return const RoleDispatcherScreen();
        }

        // If no user is logged in, show the login screen
        return const LoginScreen();
      },
    );
  }
}