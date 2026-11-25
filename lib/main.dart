import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/inventory_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/employee_equipment_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  runApp(const IctInventoryApp());
}

class IctInventoryApp extends StatelessWidget {
  const IctInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ICT Equipment Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;
        if (user == null) {
          return const AuthScreen();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userDocSnap) {
            if (userDocSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = userDocSnap.data?.data() as Map<String, dynamic>?;
            final isNewlyCreated =
                user.metadata.creationTime != null &&
                DateTime.now()
                        .difference(user.metadata.creationTime!)
                        .inSeconds <
                    15;

            if (data == null && isNewlyCreated) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = (data?['role'] ?? 'ictu')
                .toString()
                .trim()
                .toLowerCase();
            final storedName = (data?['fullName'] ?? '').toString().trim();
            final resolvedName = storedName.isNotEmpty
                ? storedName
                : user.displayName;

            if (role == 'employee') {
              return EmployeeEquipmentScreen(
                user: user,
                employeeFullName: resolvedName,
              );
            }

            return ChangeNotifierProvider(
              create: (_) => InventoryProvider(),
              child: const DashboardScreen(),
            );
          },
        );
      },
    );
  }
}
