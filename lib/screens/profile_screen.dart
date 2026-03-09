import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Profile screen — placeholder until full implementation in task cx3.11.
class ProfileScreen extends StatelessWidget {
  /// The current logged-in user.
  final UserModel currentUser;

  /// Creates a [ProfileScreen].
  const ProfileScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar Perfil')),
      body: const Center(child: Text('Próximamente')),
    );
  }
}
