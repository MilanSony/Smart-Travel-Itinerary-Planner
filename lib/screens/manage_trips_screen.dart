import 'package:flutter/material.dart';

class ManageTripsScreen extends StatelessWidget {
  const ManageTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Trips'),
      ),
      body: const Center(
        child: Text(
          'Manage Trips Page - Content coming soon!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}