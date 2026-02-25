import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'image_processor.dart';
import 'models.dart';
import 'screens.dart';

class AppController extends GetxController {
  final history = <ProcessItem>[].obs;
  final isBatchRunning = false.obs;
  final batchLabel = ''.obs;
  final isPickingImage = false.obs;

  final Box _box = Hive.box('history');
  final ImageProcessor _processor = ImageProcessor();
  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    _loadHistory();
  }

  void _loadHistory() {
    final items =
        _box.values
            .map(
              (value) => ProcessItem.fromMap(Map<dynamic, dynamic>.from(value)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    history.assignAll(items);
  }

  Future<void> saveToHistory(ProcessResult result) async {
    final filePath = result.type == ProcessingType.face
        ? result.resultImagePath
        : (result.pdfPath ?? result.resultImagePath);
    final size = await File(filePath).length();
    final item = ProcessItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: result.type,
      originalPath: result.originalPath,
      resultImagePath: result.resultImagePath,
      pdfPath: result.pdfPath,
      createdAt: DateTime.now(),
      fileSizeBytes: size,
      pageCount: result.pageCount,
    );
    await _box.put(item.id, item.toMap());
    _loadHistory();
  }

  Future<void> deleteItem(ProcessItem item) async {
    await _box.delete(item.id);
    await _safeDelete(item.resultImagePath);
    await _safeDelete(item.pdfPath);
    _loadHistory();
  }

  Future<void> _safeDelete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> startSingleFlow(ImageSource source) async {
    if (isPickingImage.value) return;
    isPickingImage.value = true;
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 92);
      if (picked == null) return;
      Get.to(() => ProcessingScreen(imagePath: picked.path));
    } on PlatformException catch (_) {
      Get.snackbar('Cancelled', 'Image request was interrupted. Try again.');
    } finally {
      isPickingImage.value = false;
    }
  }

  Future<void> startBatchFlow() async {
    if (isPickingImage.value) return;
    isPickingImage.value = true;
    List<XFile> picked = [];
    try {
      picked = await _picker.pickMultiImage(imageQuality: 88);
    } on PlatformException catch (_) {
      Get.snackbar('Cancelled', 'Batch request was interrupted. Try again.');
    } finally {
      isPickingImage.value = false;
    }
    if (picked.isEmpty) return;

    isBatchRunning.value = true;
    var success = 0;
    var failed = 0;
    final batchResults = <ProcessResult>[];
    for (var i = 0; i < picked.length; i++) {
      batchLabel.value = 'Processing ${i + 1}/${picked.length}';
      try {
        final result = await _processor.process(
          imagePath: picked[i].path,
          onStep: (_) {},
        );
        await saveToHistory(result);
        batchResults.add(result);
        success++;
      } catch (_) {
        failed++;
      }
    }
    batchLabel.value = '';
    isBatchRunning.value = false;
    Get.snackbar(
      'Batch Complete',
      'Total: ${picked.length}  Success: $success  Failed: $failed',
    );
    if (batchResults.isNotEmpty) {
      Get.to(() => BatchSummaryScreen(results: batchResults));
    }
  }
}
