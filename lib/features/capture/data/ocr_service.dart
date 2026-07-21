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
    final crops = await Isolate.run(() => _createGuideCrops(bytes));
    final cropPath = imagePath.replaceFirst(
      RegExp(r'\.jpe?g$', caseSensitive: false),
      '_crop.jpg',
    );
    await File(cropPath).writeAsBytes(crops.original, flush: true);

    final cropText = await _recognizer.processImage(
      InputImage.fromFilePath(cropPath),
    );
    var rawText = cropText.text;
    var extraction = _extractor.extract(rawText, knownNames: knownNames);

    // A versão com contraste reforçado recupera nomes em etiquetas pouco nítidas
    // sem ampliar a área examinada além do guia mostrado na câmera.
    if (extraction.confidence < .9) {
      final enhancedPath = imagePath.replaceFirst(
        RegExp(r'\.jpe?g$', caseSensitive: false),
        '_crop_enhanced.jpg',
      );
      try {
        await File(enhancedPath).writeAsBytes(crops.enhanced, flush: true);
        final enhancedText = await _recognizer.processImage(
          InputImage.fromFilePath(enhancedPath),
        );
        final enhancedExtraction = _extractor.extract(
          enhancedText.text,
          knownNames: knownNames,
        );
        if (enhancedExtraction.confidence > extraction.confidence) {
          rawText = enhancedText.text;
          extraction = enhancedExtraction;
        }
      } finally {
        final enhancedFile = File(enhancedPath);
        if (await enhancedFile.exists()) await enhancedFile.delete();
      }
    }
    return OcrResult(
      rawText: rawText,
      cropPath: cropPath,
      extraction: extraction,
    );
  }

  Future<void> close() => _recognizer.close();

  static _GuideCrops _createGuideCrops(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return _GuideCrops(bytes, bytes);
    final source = img.bakeOrientation(decoded);
    final x = (source.width * 0.08).round();
    final y = (source.height * 0.39).round();
    final width = (source.width * 0.84).round();
    final height = (source.height * 0.22).round();
    final crop = img.copyCrop(source, x: x, y: y, width: width, height: height);
    final original = Uint8List.fromList(img.encodeJpg(crop, quality: 94));
    final enhanced = img.adjustColor(crop, contrast: 1.35, brightness: 1.05);
    return _GuideCrops(
      original,
      Uint8List.fromList(img.encodeJpg(enhanced, quality: 94)),
    );
  }
}

class _GuideCrops {
  const _GuideCrops(this.original, this.enhanced);

  final Uint8List original;
  final Uint8List enhanced;
}
