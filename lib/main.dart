import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/heat_theme.dart';

void main() {
  runApp(const HeatApp());
}

class HeatApp extends StatelessWidget {
  const HeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heat: Pedal to the Metal',
      debugShowCheckedModeBanner: false,
      theme: buildHeatTheme(),
      home: const HomeScreen(),
    );
  }
}
