import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'blocked_account_page.dart';
import 'deleting_account_page.dart';

class UserStatusGate extends StatelessWidget {
  const UserStatusGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Guest hoặc chưa login thì cho qua
    if (user == null) return child;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return child;
        }

        final data = snapshot.data?.data();
        final status = data?['status'] ?? 'active';
        final reason = data?['banReason'] ?? '';

        if (status == 'suspended') {
          return BlockedAccountPage(reason: reason, status: status);
        }

        if (status == 'deleting') {
          final scheduledDeleteAt = data?['scheduledDeleteAt'];
          DateTime? deleteTime;
          if (scheduledDeleteAt is Timestamp) {
            deleteTime = scheduledDeleteAt.toDate();
          }
          return DeletingAccountPage(scheduledDeleteAt: deleteTime);
        }

        return child;
      },
    );
  }
}
