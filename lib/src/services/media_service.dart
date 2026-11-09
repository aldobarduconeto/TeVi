import 'platform_support.dart';

import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../models/api_exception.dart';

Future<String?> pickPhoto({bool camera = false}) async {
  if (!PlatformSupport.current.supported ||
      (camera && !PlatformSupport.current.cameraCapture)) {
    throw ApiException(
      'Captura pela câmera indisponível. Escolha uma imagem do dispositivo.',
    );
  }
  final photo = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1000,
    imageQuality: 80,
  );
  if (photo == null) return null;
  if (await photo.length() > 3 * 1024 * 1024)
    throw ApiException('Escolha uma foto de até 3 MB.');
  final bytes = await photo.readAsBytes();
  if (bytes.length > 3 * 1024 * 1024) {
    throw ApiException('Escolha uma foto de até 3 MB.');
  }
  return encodePhoto(bytes);
}

/// Detect content rather than trusting a browser filename or extension.
String encodePhoto(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024)
    throw ApiException('Escolha uma foto de até 3 MB.');
  bool starts(List<int> signature, [int offset = 0]) =>
      bytes.length >= offset + signature.length &&
      List.generate(
        signature.length,
        (i) => bytes[offset + i] == signature[i],
      ).every((v) => v);
  final type = starts([255, 216, 255])
      ? 'image/jpeg'
      : starts([137, 80, 78, 71, 13, 10, 26, 10])
      ? 'image/png'
      : starts(ascii.encode('RIFF')) && starts(ascii.encode('WEBP'), 8)
      ? 'image/webp'
      : null;
  if (type == null) throw ApiException('Escolha uma imagem JPEG, PNG ou WebP.');
  return 'data:$type;base64,${base64Encode(bytes)}';
}
