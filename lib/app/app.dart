import 'package:flutter/material.dart';

class FlowruStaffApp extends StatelessWidget {
  const FlowruStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flowru Staff',
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Flowru Staff test',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}