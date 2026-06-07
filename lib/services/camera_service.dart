import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CameraService {
  CameraService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Opens the camera, saves the photo to the app's private directory,
  /// and returns the absolute path. Returns null if the user cancels.
  Future<String?> capturePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) {
      return null;
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = _formatTimestamp(DateTime.now());
    final fileName = 'leitura_$timestamp.jpg';
    final targetPath = p.join(directory.path, fileName);

    final savedFile = await File(image.path).copy(targetPath);
    return savedFile.path;
  }

  /// Deletes a photo file from private storage.
  Future<void> deletePhoto(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _formatTimestamp(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}'
        '_${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}
