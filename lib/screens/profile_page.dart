import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_genie/screens/auth_gate.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // --- All your existing state variables and services are correct ---
  User? _user = FirebaseAuth.instance.currentUser;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  String _travelStyle = 'Not set';
  List<String> _interests = [];
  final List<String> _interestOptions = const [
    'Food',
    'Nature',
    'Culture',
    'Shopping',
    'Adventure',
    'History',
    'Nightlife',
    'Photography',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  // --- All your existing methods are correct ---
  Future<void> _loadUserPreferences() async {
    if (_user != null) {
      final prefs = await _firestoreService.getUserPreferences(_user!.uid);
      if (prefs != null && mounted) {
        setState(() {
          _travelStyle = prefs['travelStyle'] ?? 'Not set';
          _interests = List<String>.from(prefs['interests'] ?? []);
        });
      }
    }
  }

  Future<void> _updateUserPreferences() async {
    if (_user == null) return;
    try {
      await _firestoreService.setUserPreferences(_user!.uid, {
        'travelStyle': _travelStyle,
        'interests': _interests,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save preferences: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _user?.displayName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Username')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_user != null && nameController.text.trim().isNotEmpty) {
                await _user?.updateDisplayName(nameController.text.trim());
                await _firestoreService.updateUserProfile(_user!.uid, nameController.text.trim());
                await FirebaseAuth.instance.currentUser?.reload();
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      setState(() => _user = FirebaseAuth.instance.currentUser);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green));
    }
  }

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
              final result = await _authService.changePassword(newPasswordController.text);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result == "Success" ? 'Password changed successfully!' : result),
                  backgroundColor: result == "Success" ? Colors.green : Colors.redAccent,
                ));
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showTravelStyleDialog() async {
    final List<String> styles = const [
      'Relaxed', 'Adventure', 'Cultural', 'Nature', 'Luxury', 'Budget'
    ];
    String tempStyle = _travelStyle == 'Not set' ? styles.first : _travelStyle;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Travel Style'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: styles.map((style) => RadioListTile<String>(
                    title: Text(style),
                    value: style,
                    groupValue: tempStyle,
                    onChanged: (val) {
                      setDialogState(() {
                        tempStyle = val!;
                      });
                    },
                  )).toList(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      setState(() => _travelStyle = tempStyle);
      await _updateUserPreferences();
    }
  }

  void _showInterestsDialog() async {
    final Set<String> temp = _interests.toSet();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Interests'),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _interestOptions.map((interest) {
                    final bool selected = temp.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: selected,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            temp.add(interest);
                          } else {
                            temp.remove(interest);
                          }
                        });
                      },
                      selectedColor: Colors.deepPurple.withOpacity(0.15),
                      checkmarkColor: Colors.deepPurple,
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      setState(() => _interests = temp.toList());
      await _updateUserPreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get an instance of your ThemeProvider to control the theme
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).cardColor,
                    backgroundImage: _user?.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
                    child: _user?.photoURL == null
                        ? Icon(Icons.person, size: 50, color: Theme.of(context).primaryColor)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(_user?.displayName ?? 'Traveller', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_user?.email ?? 'No email provided', style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodySmall?.color)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Travel Preferences Section
            const Text('Travel Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildPreferenceCard(context, icon: Icons.style_outlined, title: 'Travel Style', value: _travelStyle, onTap: _showTravelStyleDialog),
            _buildPreferenceCard(context, icon: Icons.interests_outlined, title: 'Interests', value: _interests.isEmpty ? 'Not set' : _interests.join(', '), onTap: _showInterestsDialog),

            const SizedBox(height: 30),
            const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // --- UPDATED: Settings Section with Dark Mode Toggle ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      // This will toggle the theme and save the preference
                      themeProvider.toggleTheme();
                    },
                    secondary: Icon(
                      themeProvider.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildSettingsTile(icon: Icons.edit_outlined, title: 'Edit Profile', onTap: _showEditProfileDialog),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildSettingsTile(icon: Icons.lock_reset_outlined, title: 'Change Password', onTap: _showChangePasswordDialog),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Logout Button
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

  // --- Helper Widgets ---
  Widget _buildPreferenceCard(BuildContext context, {required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).textTheme.bodySmall?.color),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}