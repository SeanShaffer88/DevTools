// Root widget: owns the MaterialApp, theme, and top-level routing
// choice. Feature-first layout (see guides/14 in this resource pack):
// each feature lives under lib/features/<feature>/ and shared data
// code under lib/data/.
import 'package:flutter/material.dart';

import 'features/home/home_page.dart';

class AppSkeletonApp extends StatelessWidget {
  const AppSkeletonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Skeleton',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
