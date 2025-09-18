import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:trip_genie/screens/auth_gate.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  // --- UPDATED: Edit Profile Dialog Logic ---
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _user?.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_user != null && nameController.text.trim().isNotEmpty) {
                // 1. Update the name in Firebase Authentication (for login state)
                await _user?.updateDisplayName(nameController.text.trim());

                // 2. Update the name in your Firestore 'users' collection (for display in lists)
                await _firestoreService.updateUserProfile(_user!.uid, nameController.text.trim());

                if (mounted) {
                  // Rebuild the UI to show the new name immediately
                  setState(() {});
                  Navigator.pop(context); // Close the dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- UPDATED: Change Password Dialog Logic ---
  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: newPasswordController,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text.trim().isNotEmpty) {
                // Now this correctly calls the method from your AuthService
                final result = await _authService.changePassword(newPasswordController.text.trim());

                if (mounted) {
                  Navigator.pop(context); // Close the dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result == "Success" ? 'Password changed successfully!' : result),
                      backgroundColor: result == "Success" ? Colors.green : Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Info Header
            if (_user != null)
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _user?.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
                      child: _user?.photoURL == null ? const Icon(Icons.person, size: 50) : null,
                    ),
                    const SizedBox(height: 16),
                    Text(_user!.displayName ?? 'Traveller', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_user!.email ?? '', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            const SizedBox(height: 30),

            // Settings Tiles
            _buildSettingsTile(
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              onTap: _showEditProfileDialog,
            ),
            _buildSettingsTile(
              icon: Icons.lock_reset_outlined,
              title: 'Change Password',
              onTap: _showChangePasswordDialog,
            ),
            _buildSettingsTile(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () async {
                await _authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthGate()),
                        (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the setting tiles
  Widget _buildSettingsTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
