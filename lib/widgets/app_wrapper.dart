import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pi_task_watch/widgets/custom_header.dart';

class AppWrapper extends StatelessWidget {
  final Widget child;

  const AppWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      return Scaffold(
        body: SafeArea(
          child: child,
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          const CustomHeader(
            title: 'PI Task Watch',
            backgroundColor: Colors.white,
            logoPath: "assets/logo-transparent.png",
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
