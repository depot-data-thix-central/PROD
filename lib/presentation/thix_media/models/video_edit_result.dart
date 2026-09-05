class VideoEditResult {
  final String videoPath;
  final double trimStart;      // secondes
  final double trimEnd;        // secondes
  final String filterKey;      // 'filter_normal', 'filter_soft_beauty', ...
  final bool muteOriginalAudio;
  final String? musicPath;     // musique choisie
  final String? voicePath;     // voice-over (nouveau)

  const VideoEditResult({
    required this.videoPath,
    required this.trimStart,
    required this.trimEnd,
    required this.filterKey,
    this.muteOriginalAudio = false,
    this.musicPath,
    this.voicePath,
  });

  /// Mapping vers le label affiché sur la page Publier
  String get filterDisplayName {
    switch (filterKey) {
      case 'filter_cinematic': return 'Cinématique';
      case 'filter_bright':    return 'Éclat';
      case 'filter_vintage':   return 'Vintage';
      case 'filter_cyberpunk': return 'Cyberpunk';
      case 'filter_soft_beauty': return 'Beauty';
      default:                 return 'Normal';
    }
  }
}
