import 'package:flutter/material.dart';

class ViewAnalyticsScreen extends StatelessWidget {
  const ViewAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Analytics'),
      ),
      body: const Center(
        child: Text(
          'View Analytics Page - Content coming soon!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}