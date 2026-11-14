/// Stub web : jamais appelé (garde kIsWeb dans ThixMediaOptimizer).
class VideoCompressor {
  VideoCompressor._();

  static Future<String?> process(
    String path, {
    required int maxMB,
    required bool needsCompress,
    int? trimStartMs,
    int? trimEndMs,
    void Function(double percent)? onProgress,
  }) async => null;
}
