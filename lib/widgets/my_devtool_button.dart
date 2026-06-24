// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:logarte/logarte.dart';

// final Logarte logarte = Logarte(
//   // Protect with password
//   password: '1234',

//   // Skip password in debug mode
//   ignorePassword: kDebugMode,

//   // Share network request
//   onShare: (String content) {
//     // Share.share(content);
//   },

//   // Add shortcut actions (optional)
//   onRocketLongPressed: (context) {
//     // e.g: toggle theme mode
//   },
//   // onRocketDoubleTapped: (context) {
//   //   // e.g: change language
//   // }
// );

// class MyDevtoolButton extends StatelessWidget {
//   const MyDevtoolButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return LogarteMagicalTap(logarte: logarte, child: Text('App Version 1.0'));
//   }
// }

// void launchDevTool(BuildContext context) async {
//   Future.delayed(const Duration(milliseconds: 1000), () {
//     logarte.attach(context: context, visible: kDebugMode);
//   });
// }
