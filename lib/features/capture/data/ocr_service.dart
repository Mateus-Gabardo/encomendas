import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../../delivery_lists/domain/name_extractor.dart';

class OcrResult {
  const OcrResult({
    required this.rawText,
    required this.cropPath,
    required this.extraction,
  });

  final String rawText;
  final String cropPath;
  final NameExtraction extraction;
}

class OcrService {
  OcrService({NameExtractor? extractor})
    : _extractor = extractor ?? NameExtractor();

  final NameExtractor _extractor;
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<OcrResult> process(
    String imagePath, {
    Iterable<String> knownNames = const [],
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final croppedBytes = await Isolate.run(() => _cropGuide(bytes));
    final cropPath = imagePath.replaceFirst(
      RegExp(r'\.jpe?g$', caseSensitive: false),
      '_crop.jpg',
    );
    await File(cropPath).writeAsBytes(croppedBytes, flush: true);

    final cropText = await _recognizer.processImage(
      InputImage.fromFilePath(cropPath),
    );
    return OcrResult(
      rawText: cropText.text,
      cropPath: cropPath,
      extraction: _extractor.extract(cropText.text, knownNames: knownNames),
    );
  }

  Future<void> close() => _recognizer.close();

  static Uint8List _cropGuide(Uint8List bytes) {
    final source = img.decodeImage(bytes);
    if (source == null) return bytes;
    final x = (source.width * 0.08).round();
    final y = (source.height * 0.38).round();
    final width = (source.width * 0.84).round();
    final height = (source.height * 0.24).round();
    final crop = img.copyCrop(source, x: x, y: y, width: width, height: height);
    return Uint8List.fromList(img.encodeJpg(crop, quality: 90));
  }
}
