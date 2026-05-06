import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // ← Don't stretch full height
          children: [
            CircularProgressIndicator(
              color: Colors.black,
              backgroundColor: Colors.white,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Colors.black),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
