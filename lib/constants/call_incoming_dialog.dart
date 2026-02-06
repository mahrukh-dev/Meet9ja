// import 'package:flutter/material.dart';
// import '../constants/app_colors.dart';
//
// class IncomingCallDialog extends StatelessWidget {
//   final String callId;
//   final String callType;
//   final String callerId;
//   final String callerName;
//   final String conversationId;
//   final VoidCallback onAccept;
//   final VoidCallback onReject;
//
//   const IncomingCallDialog({
//     super.key,
//     required this.callId,
//     required this.callType,
//     required this.callerId,
//     required this.callerName,
//     required this.conversationId,
//     required this.onAccept,
//     required this.onReject,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       backgroundColor: Colors.white,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//       ),
//       content: SizedBox(
//         height: 350,
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // Caller Avatar
//             CircleAvatar(
//               radius: 60,
//               backgroundImage: const NetworkImage(
//                 'https://via.placeholder.com/150', // Replace with actual caller avatar
//               ),
//               child: callType == 'video'
//                   ? const Icon(Icons.videocam, size: 40, color: Colors.white)
//                   : const Icon(Icons.call, size: 40, color: Colors.white),
//             ),
//             const SizedBox(height: 20),
//
//             // Caller Name
//             Text(
//               callerName,
//               style: const TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 10),
//
//             // Call Type
//             Text(
//               'Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey[600],
//               ),
//             ),
//             const SizedBox(height: 30),
//
//             // Call Duration Animation
//             Container(
//               width: 200,
//               height: 2,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     AppColors.primary,
//                     Colors.blueAccent,
//                     AppColors.primary,
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 30),
//
//             // Action Buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 // Accept Button
//                 GestureDetector(
//                   onTap: onAccept,
//                   child: Container(
//                     width: 70,
//                     height: 70,
//                     decoration: const BoxDecoration(
//                       color: Colors.green,
//                       shape: BoxShape.circle,
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.green,
//                           blurRadius: 20,
//                           spreadRadius: 5,
//                         ),
//                       ],
//                     ),
//                     child: const Icon(
//                       Icons.call,
//                       color: Colors.white,
//                       size: 30,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 40),
//
//                 // Reject Button
//                 GestureDetector(
//                   onTap: onReject,
//                   child: Container(
//                     width: 70,
//                     height: 70,
//                     decoration: BoxDecoration(
//                       color: Colors.red,
//                       shape: BoxShape.circle,
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.red,
//                           blurRadius: 20,
//                           spreadRadius: 5,
//                         ),
//                       ],
//                     ),
//                     child: const Icon(
//                       Icons.call_end,
//                       color: Colors.white,
//                       size: 30,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }