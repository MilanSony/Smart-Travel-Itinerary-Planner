import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

/// Shows previously saved packing lists for the current user for a
/// specific destination.
class SavedPackingListsScreen extends StatelessWidget {
  final String destination;

  const SavedPackingListsScreen({
    super.key,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          title: const Text('Saved Packing Lists'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Please sign in to view your saved packing lists.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final firestore = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Saved for $destination',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            firestore.getPackingTransactionsForUserDestination(uid, destination),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C5CE7),
              ),
            );
          }
          if (snapshot.hasError) {
            return _buildMessage(
              theme,
              icon: Icons.cloud_off,
              title: 'Could not load saved packing lists',
              subtitle:
                  'Please check your internet connection and try again.',
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildMessage(
              theme,
              icon: Icons.inventory_2_outlined,
              title: 'No saved packing lists yet',
              subtitle:
                  'Save a packing list from the Smart Packing List screen for $destination and it will appear here.',
            );
          }

          // We keep a single evolving list per destination; show the latest doc.
          final doc = docs.first;
          final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'] as Timestamp?;
              final startDate = data['startDate'] as Timestamp?;
              final endDate = data['endDate'] as Timestamp?;
              final items = (data['items'] as List?)?.cast<String>() ?? const [];

              String dateRange = '';
              if (startDate != null) {
                final start = startDate.toDate();
                final end = endDate?.toDate() ?? start;
                dateRange =
                    '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
              }

          final createdLabel = createdAt != null
              ? 'Saved on ${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
              : '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    dateRange.isNotEmpty
                        ? 'Trip: $dateRange'
                        : 'Saved packing list',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: createdLabel.isNotEmpty
                      ? Text(
                          createdLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        )
                      : null,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Items',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle,
                                size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Color(0xFF9CA3AF)),
                              tooltip: 'Remove from saved list',
                              onPressed: () async {
                                final updated = List<String>.from(items)
                                  ..remove(name);
                                await firestore.updatePackingTransactionItems(
                                  doc.id,
                                  updated,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessage(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF9FAFB),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF6C5CE7),
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

