import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class FullScreenImageScreen extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? imagePath;

  const FullScreenImageScreen({super.key, this.imageBytes, this.imagePath});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (imageBytes != null) {
      child = Image.memory(imageBytes!, fit: BoxFit.contain);
    } else if (imagePath != null) {
      if (kIsWeb) {
        child = Image.network(imagePath!, fit: BoxFit.contain);
      } else {
        child = Image.file(File(imagePath!), fit: BoxFit.contain);
      }
    } else {
      child = const Center(child: Text('ไม่มีภาพ'));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: child,
          ),
        ),
      ),
    );
  }
}
