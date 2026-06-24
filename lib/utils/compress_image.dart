import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

String compressBase64Image(String base64String, {int quality = 50}) {
  // Calculate original size
  int originalSize = base64String.length;
  double originalSizeMB = originalSize / (1024 * 1024);
  print('Original image size: ${originalSizeMB.toStringAsFixed(2)} MB');

  // Decode Base64 to bytes
  Uint8List imageBytes = base64Decode(base64String);
  img.Image? image = img.decodeImage(imageBytes);

  if (image == null) {
    throw Exception("Invalid image data");
  }

  // Compress the image (JPEG format)
  List<int> compressedBytes = img.encodeJpg(image, quality: quality);

  // Convert back to Base64
  String compressedBase64 = base64Encode(Uint8List.fromList(compressedBytes));

  // Calculate compressed size
  int compressedSize = compressedBase64.length;
  double compressedSizeMB = compressedSize / (1024 * 1024);
  print('Compressed image size: ${compressedSizeMB.toStringAsFixed(2)} MB');
  print(
    'Compression ratio: ${(compressedSize / originalSize * 100).toStringAsFixed(2)}%',
  );

  return compressedBase64;
}
