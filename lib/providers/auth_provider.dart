// ─────────────────────────────────────────────
//  Polyticks – Auth Provider (InheritedWidget)
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../models/models.dart';

class AuthProvider extends InheritedWidget {
  final AppUser? currentUser;
  final VoidCallback onLogout;

  const AuthProvider({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required super.child,
  });

  static AuthProvider? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthProvider>();

  @override
  bool updateShouldNotify(AuthProvider old) =>
      old.currentUser != currentUser;
}
