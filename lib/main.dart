import 'package:flutter/material.dart';

void main() {
  runApp(const MyUniApp());
}

class MyUniApp extends StatelessWidget {
  const MyUniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyUni',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MyUniHomePage(),
    );
  }
}

class MyUniHomePage extends StatelessWidget {
  const MyUniHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyUni Community'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_rounded, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text(
              'Welcome to MyUni!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Connecting students within your campus.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Future navigation logic
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}