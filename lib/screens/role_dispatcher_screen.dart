import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';

class RoleDispatcherScreen extends StatefulWidget {
  const RoleDispatcherScreen({super.key});

  @override
  State<RoleDispatcherScreen> createState() => _RoleDispatcherScreenState();
}

class _RoleDispatcherScreenState extends State<RoleDispatcherScreen> {
  @override
  void initState() {
    super.initState();
    _dispatchUser();
  }

  Future<void> _dispatchUser() async {
    // Wait for the isAdmin check to complete
    final bool isAdmin = await AuthService().isAdmin();

    // Ensure the widget is still mounted before navigating
    if (mounted) {
      // Use pushReplacement to prevent the user from going back to this loading screen
      if (isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a simple loading indicator while the check is in progress
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}