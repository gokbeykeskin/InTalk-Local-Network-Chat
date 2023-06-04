import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:photo_view/photo_view.dart';

class FullScreenImage extends StatefulWidget {
  final File imageFile;

  const FullScreenImage(this.imageFile, {super.key});

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InTalk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final imageBytes = await widget.imageFile.readAsBytes();
              final result = await ImageGallerySaver.saveImage(imageBytes);
              if (result != null && result.isNotEmpty && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image saved to gallery')),
                );
              }
            },
          ),
        ],
      ),
      body: PhotoView(
        imageProvider:
            FileImage(File(widget.imageFile.path)), //widget.imageFile,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        gaplessPlayback: false,
        customSize: MediaQuery.of(context).size,
        enableRotation: true,
        minScale: PhotoViewComputedScale.contained * 0.8,
        maxScale: PhotoViewComputedScale.covered * 1.8,
        initialScale: PhotoViewComputedScale.contained,
        basePosition: Alignment.center,
      ),
    );
  }
}
