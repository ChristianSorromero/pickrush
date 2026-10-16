import 'package:flutter/material.dart';
import 'package:rider_app/app_theme.dart';
import 'package:rider_app/riderpages/login.dart';

void main() => runApp(const RiderApp());

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pickrush Rider',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
