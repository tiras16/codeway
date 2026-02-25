import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';

class ImageProcessor {
  Future<Directory> _imagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'processed', 'images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _pdfDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'processed', 'pdfs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<ProcessResult> process({
    required String imagePath,
    required ValueChanged<String> onStep,
  }) async {
    onStep('Detecting faces...');
    final faceCount = await _detectFacesCount(imagePath);

    if (faceCount > 0) {
      onStep('Applying face pipeline...');
      final out = await _processFaceImage(imagePath);
      return ProcessResult(
        type: ProcessingType.face,
        originalPath: imagePath,
        resultImagePath: out,
      );
    }

    onStep('Checking document text...');
    final textBlocks = await _detectTextBlockCount(imagePath);
    if (textBlocks == 0) {
      onStep('No text found, using face flow...');
      final out = await _processFaceImage(imagePath);
      return ProcessResult(
        type: ProcessingType.face,
        originalPath: imagePath,
        resultImagePath: out,
      );
    }

    onStep('Applying document pipeline...');
    final doc = await processDocumentPage(imagePath);
    onStep('Creating PDF...');
    final pdfPath = await buildPdfFromPages([doc]);
    return ProcessResult(
      type: ProcessingType.document,
      originalPath: imagePath,
      resultImagePath: doc,
      pdfPath: pdfPath,
      pageCount: 1,
    );
  }

  Future<int> _detectFacesCount(String path) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.08,
      ),
    );
    final input = InputImage.fromFilePath(path);
    final faces = await detector.processImage(input);
    await detector.close();
    return faces.length;
  }

  Future<int> _detectTextBlockCount(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final text = await recognizer.processImage(InputImage.fromFilePath(path));
    await recognizer.close();
    return text.blocks.length;
  }

  Future<String> _processFaceImage(String imagePath) async {
    final originalBytes = await File(imagePath).readAsBytes();
    final sourceImage = img.decodeImage(originalBytes);
    if (sourceImage == null) throw Exception('Cannot decode image');

    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.08,
      ),
    );
    final faces = await detector.processImage(
      InputImage.fromFilePath(imagePath),
    );
    await detector.close();

    for (final face in faces) {
      final r = face.boundingBox;
      final x = r.left.floor().clamp(0, sourceImage.width - 1);
      final y = r.top.floor().clamp(0, sourceImage.height - 1);
      final w = r.width.floor().clamp(1, sourceImage.width - x);
      final h = r.height.floor().clamp(1, sourceImage.height - y);

      final crop = img.copyCrop(sourceImage, x: x, y: y, width: w, height: h);
      final gray = img.grayscale(crop);
      img.compositeImage(sourceImage, gray, dstX: x, dstY: y);
    }

    final dir = await _imagesDir();
    final filePath = p.join(
      dir.path,
      'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(filePath).writeAsBytes(img.encodeJpg(sourceImage, quality: 90));
    return filePath;
  }

  Future<String> processDocumentPage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final sourceImage = img.decodeImage(bytes);
    if (sourceImage == null) throw Exception('Cannot decode image');

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final input = InputImage.fromFilePath(imagePath);
    final text = await recognizer.processImage(input);
    await recognizer.close();

    img.Image target = sourceImage;
    if (text.blocks.isNotEmpty) {
      var minX = sourceImage.width.toDouble();
      var minY = sourceImage.height.toDouble();
      var maxX = 0.0;
      var maxY = 0.0;

      for (final block in text.blocks) {
        minX = math.min(minX, block.boundingBox.left);
        minY = math.min(minY, block.boundingBox.top);
        maxX = math.max(maxX, block.boundingBox.right);
        maxY = math.max(maxY, block.boundingBox.bottom);
      }

      const pad = 24;
      final x = (minX.floor() - pad).clamp(0, sourceImage.width - 1);
      final y = (minY.floor() - pad).clamp(0, sourceImage.height - 1);
      final w = (maxX.floor() - x + pad).clamp(1, sourceImage.width - x);
      final h = (maxY.floor() - y + pad).clamp(1, sourceImage.height - y);
      final areaRatio = (w * h) / (sourceImage.width * sourceImage.height);
      if (areaRatio > 0.18) {
        target = img.copyCrop(sourceImage, x: x, y: y, width: w, height: h);
      }
    }

    if (_looksTooDark(target)) {
      final dir = await _imagesDir();
      final fallbackPath = p.join(
        dir.path,
        'doc_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(fallbackPath).writeAsBytes(bytes);
      return fallbackPath;
    }

    final dir = await _imagesDir();
    final filePath = p.join(
      dir.path,
      'doc_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(filePath).writeAsBytes(img.encodeJpg(target, quality: 92));
    return filePath;
  }

  bool _looksTooDark(img.Image image) {
    final sampleX = math.max(1, image.width ~/ 32);
    final sampleY = math.max(1, image.height ~/ 32);
    var total = 0;
    var count = 0;
    for (var y = 0; y < image.height; y += sampleY) {
      for (var x = 0; x < image.width; x += sampleX) {
        final pixel = image.getPixel(x, y);
        total += (pixel.r + pixel.g + pixel.b) ~/ 3;
        count++;
      }
    }
    if (count == 0) return false;
    final avg = total / count;
    return avg < 18;
  }

  Future<String> buildPdfFromPages(List<String> pageImagePaths) async {
    final pdf = pw.Document();
    for (final path in pageImagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }

    final dir = await _pdfDir();
    final pdfPath = p.join(
      dir.path,
      'scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await File(pdfPath).writeAsBytes(await pdf.save());
    return pdfPath;
  }
}
