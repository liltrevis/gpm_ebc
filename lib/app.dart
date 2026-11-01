import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

class GpmApp extends StatelessWidget {
  const GpmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPM-2EBC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return auth.connecte ? const HomeShell() : const LoginScreen();
        },
      ),
    );
  }
}
