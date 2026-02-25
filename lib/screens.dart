import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import 'app_controller.dart';
import 'image_processor.dart';
import 'models.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('ImageFlow')),
      body: Column(
        children: [
          Obx(() {
            if (!controller.isBatchRunning.value) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(controller.batchLabel.value),
                ],
              ),
            );
          }),
          Expanded(
            child: Obx(() {
              if (controller.history.isEmpty) {
                return const Center(
                  child: Text('No history yet.\nTap + to start'),
                );
              }

              return ListView.builder(
                itemCount: controller.history.length,
                itemBuilder: (_, index) {
                  final item = controller.history[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(item.resultImagePath),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) =>
                            const Icon(Icons.image),
                      ),
                    ),
                    title: Text(
                      item.type == ProcessingType.face
                          ? 'Face Processed'
                          : 'Document Scan',
                    ),
                    subtitle: Text(
                      '${item.createdAt.toLocal()}'
                      '${item.pageCount > 1 ? ' • ${item.pageCount} pages' : ''}',
                    ),
                    onTap: () => Get.to(() => HistoryDetailScreen(item: item)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => controller.deleteItem(item),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const CaptureScreen()),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }
}

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Source')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ActionCard(
              title: 'Camera',
              icon: Icons.photo_camera_outlined,
              onTap: () => controller.startSingleFlow(ImageSource.camera),
            ),
            _ActionCard(
              title: 'Gallery',
              icon: Icons.photo_library_outlined,
              onTap: () => controller.startSingleFlow(ImageSource.gallery),
            ),
            _ActionCard(
              title: 'Batch (Bonus)',
              icon: Icons.collections_outlined,
              onTap: controller.startBatchFlow,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.imagePath});
  final String imagePath;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final step = 'Preparing...'.obs;
  final processor = ImageProcessor();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 150), _run);
  }

  Future<void> _run() async {
    try {
      final result = await processor.process(
        imagePath: widget.imagePath,
        onStep: (text) => step.value = text,
      );
      if (!mounted) return;
      Get.off(() => ResultScreen(result: result));
    } catch (_) {
      if (!mounted) return;
      Get.snackbar('Processing failed', 'Please try with another image');
      Get.offAll(() => const HomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Obx(() => Text(step.value)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  ResultScreen({super.key, required this.result});
  final ProcessResult result;
  final AppController appController = Get.find<AppController>();
  final ImageProcessor processor = ImageProcessor();

  final pages = <String>[].obs;
  final pdfPath = RxnString();
  final busy = false.obs;

  Future<void> _addDocPage() async {
    if (busy.value) return;
    busy.value = true;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null) {
      final page = await processor.processDocumentPage(picked.path);
      pages.add(page);
      final path = await processor.buildPdfFromPages(pages);
      pdfPath.value = path;
    }
    busy.value = false;
  }

  void _removePage(int index) {
    if (index < 0 || index >= pages.length) return;
    if (pages.length == 1) return;
    pages.removeAt(index);
  }

  void _reorderPages(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final item = pages.removeAt(oldIndex);
    pages.insert(newIndex, item);
  }

  Future<void> _done() async {
    final finalResult = ProcessResult(
      type: result.type,
      originalPath: result.originalPath,
      resultImagePath: result.resultImagePath,
      pdfPath: result.type == ProcessingType.document
          ? (pdfPath.value ?? result.pdfPath)
          : null,
      pageCount: result.type == ProcessingType.document ? pages.length : 1,
    );
    await appController.saveToHistory(finalResult);
    Get.offAll(() => const HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      pages.add(result.resultImagePath);
      pdfPath.value = result.pdfPath;
    }

    final isFace = result.type == ProcessingType.face;
    return Scaffold(
      appBar: AppBar(title: Text(isFace ? 'Face Result' : 'Document Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: isFace
                  ? Row(
                      children: [
                        Expanded(
                          child: _PreviewCard(
                            label: 'Before',
                            filePath: result.originalPath,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PreviewCard(
                            label: 'After',
                            filePath: result.resultImagePath,
                          ),
                        ),
                      ],
                    )
                  : Obx(
                      () => Column(
                        children: [
                          Expanded(
                            child: _PreviewCard(
                              label: 'Scanned Preview',
                              filePath: pages.last,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 140,
                            child: ReorderableListView.builder(
                              scrollDirection: Axis.horizontal,
                              buildDefaultDragHandles: true,
                              itemCount: pages.length,
                              onReorder: _reorderPages,
                              itemBuilder: (_, index) {
                                final page = pages[index];
                                return Container(
                                  key: ValueKey('$page-$index'),
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(page),
                                          width: 100,
                                          height: 140,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          onTap: () => _removePage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          color: Colors.black54,
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Pages: ${pages.length}'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: busy.value ? null : _addDocPage,
                                  child: const Text('Add Page'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      (busy.value || pdfPath.value == null)
                                      ? null
                                      : () => OpenFilex.open(pdfPath.value!),
                                  child: const Text('Open PDF'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _done, child: const Text('Done')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.label, required this.filePath});
  final String label;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(filePath),
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => const SizedBox(
                  height: 170,
                  child: Center(child: Text('Cannot load image')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.item});
  final ProcessItem item;

  String _bytesLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDoc = item.type == ProcessingType.document;
    return Scaffold(
      appBar: AppBar(title: const Text('History Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Image.file(
                  File(item.resultImagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stackTrace) =>
                      const Text('Preview unavailable'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Type: ${isDoc ? 'Document' : 'Face'}'),
            Text('Date: ${item.createdAt.toLocal()}'),
            Text('File size: ${_bytesLabel(item.fileSizeBytes)}'),
            if (isDoc) Text('Pages: ${item.pageCount}'),
            const SizedBox(height: 12),
            if (isDoc && item.pdfPath != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => OpenFilex.open(item.pdfPath!),
                  child: const Text('Open in PDF Viewer'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BatchSummaryScreen extends StatelessWidget {
  const BatchSummaryScreen({super.key, required this.results});
  final List<ProcessResult> results;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Summary')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, index) {
                final item = results[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _PreviewThumb(
                                  label: 'Before',
                                  filePath: item.originalPath,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PreviewThumb(
                                  label: 'After',
                                  filePath: item.resultImagePath,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.type == ProcessingType.face
                                ? 'Face'
                                : 'Document',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Get.offAll(() => const HomeScreen()),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewThumb extends StatelessWidget {
  const _PreviewThumb({required this.label, required this.filePath});
  final String label;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(filePath),
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.image)),
            ),
          ),
        ),
      ],
    );
  }
}
