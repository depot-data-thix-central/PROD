// lib/presentation/thix_info/thix_downloads_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../providers/downloads_provider.dart';
import '../../services/thix_downloader.dart';
import 'thix_info_home.dart';

class ThixDownloadsPage extends ConsumerWidget {
  const ThixDownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.inkDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Mes téléchargements',
            style: ThixPolicy.h3Style.copyWith(color: Colors.white)),
      ),
      body: state.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_done_rounded,
                      size: 64, color: Colors.white24),
                  const SizedBox(height: ThixPolicy.s16),
                  Text('Aucun téléchargement',
                      style:
                          ThixPolicy.titleStyle.copyWith(color: Colors.white70)),
                  const SizedBox(height: ThixPolicy.s8),
                  Text('Téléchargez des podcasts ou vidéos pour les écouter hors ligne',
                      textAlign: TextAlign.center,
                      style: ThixPolicy.bodySmallStyle
                          .copyWith(color: Colors.white38)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(ThixPolicy.s16),
              children: [
                if (state.active.isNotEmpty) ...[
                  _header('En cours (${state.active.length})'),
                  ...state.active.map((i) => _tile(context, ref, i, active: true)),
                  const SizedBox(height: ThixPolicy.s24),
                ],
                if (state.completed.isNotEmpty) ...[
                  _header('Terminés (${state.completed.length})'),
                  ...state.completed
                      .map((i) => _tile(context, ref, i, active: false)),
                ],
                if (state.failed.isNotEmpty) ...[
                  const SizedBox(height: ThixPolicy.s24),
                  _header('Échoués (${state.failed.length})'),
                  ...state.failed
                      .map((i) => _tile(context, ref, i, active: false)),
                ],
              ],
            ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.only(bottom: ThixPolicy.s12),
        child: Text(t,
            style: ThixPolicy.labelStyle.copyWith(
                color: Colors.white54, letterSpacing: 1.2, fontWeight: ThixPolicy.bold)),
      );

  Widget _tile(BuildContext ctx, WidgetRef ref, DownloadItem item,
      {required bool active}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s12),
      child: GlassBox(
        padding: const EdgeInsets.all(ThixPolicy.s12),
        borderRadius: ThixPolicy.rMd,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              child: SizedBox(
                width: 64,
                height: 64,
                child: item.imageUrl != null
                    ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.white.withOpacity(0.08),
                        child: Icon(
                          item.mediaType == 'video'
                              ? Icons.movie_filter_rounded
                              : Icons.headphones_rounded,
                          color: Colors.white24,
                        )),
              ),
            ),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.bodyStyle
                          .copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                  const SizedBox(height: ThixPolicy.s4),
                  Row(
                    children: [
                      Icon(item.mediaType == 'video'
                              ? Icons.videocam_rounded
                              : Icons.graphic_eq_rounded,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: ThixPolicy.s4),
                      Text(item.mediaType == 'video' ? 'Vidéo' : 'Audio',
                          style: ThixPolicy.microStyle
                              .copyWith(color: Colors.white38)),
                      if (item.sizeLabel.isNotEmpty) ...[
                        const SizedBox(width: ThixPolicy.s8),
                        Text(item.sizeLabel,
                            style: ThixPolicy.microStyle
                                .copyWith(color: Colors.white38)),
                      ],
                    ],
                  ),
                  if (active && item.status == DownloadStatus.downloading) ...[
                    const SizedBox(height: ThixPolicy.s8),
                    LinearProgressIndicator(
                      value: item.progress,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: ThixPolicy.s4),
                    Text(item.progressLabel,
                        style: ThixPolicy.microStyle
                            .copyWith(color: Colors.white54)),
                  ],
                  if (item.status == DownloadStatus.failed)
                    Padding(
                      padding: const EdgeInsets.only(top: ThixPolicy.s6),
                      child: Text('Échec : ${item.error}',
                          style: ThixPolicy.microStyle
                              .copyWith(color: ThixPolicy.danger)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: ThixPolicy.s8),
            _tileAction(ref, item),
          ],
        ),
      ),
    );
  }

  Widget _tileAction(WidgetRef ref, DownloadItem item) {
    switch (item.status) {
      case DownloadStatus.downloading:
        return SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white54),
        );
      case DownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
          onPressed: () => ref.read(downloadsProvider).deleteDownload(item.id),
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.danger),
          onPressed: () => ref.read(downloadsProvider).retry(item.id),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
