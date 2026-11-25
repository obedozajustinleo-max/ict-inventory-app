import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class IctuRequestsScreen extends StatelessWidget {
  const IctuRequestsScreen({super.key});

  String _typeLabel(String type) {
    return switch (type) {
      'unlisted_employee' => 'Unlisted Employee Registration',
      'password_reset' => 'Manual Password Reset Help',
      'mr_discrepancy' => 'MR Discrepancy Report',
      _ => 'Employee Request',
    };
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('ictu_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Employee Requests & Help')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No employee requests submitted yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = (doc.data() as Map<String, dynamic>?) ?? {};
              final type = (data['type'] ?? '').toString();
              final fullName = (data['fullName'] ?? 'Unknown').toString();
              final email = (data['email'] ?? '').toString();
              final notes = (data['notes'] ?? '').toString();
              final status = (data['status'] ?? 'pending').toString();
              final isPending = status == 'pending';

              return Card(
                child: ListTile(
                  title: Text(
                    '$fullName • ${_typeLabel(type)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${email.isNotEmpty ? "Email: $email\n" : ""}'
                    '${notes.isNotEmpty ? "Note: $notes" : "No additional notes"}',
                  ),
                  isThreeLine: true,
                  trailing: isPending
                      ? FilledButton.tonal(
                          onPressed: () =>
                              doc.reference.update({'status': 'resolved'}),
                          child: const Text('Mark Resolved'),
                        )
                      : const Chip(label: Text('Resolved')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
