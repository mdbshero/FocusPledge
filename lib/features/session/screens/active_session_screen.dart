import 'package:flutter/material.dart';

class ActiveSessionScreen extends StatelessWidget {
  final String sessionId;

  const ActiveSessionScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Session')),
      body: Center(child: Text('Active Session: $sessionId - TODO')),
    );
  }
}
