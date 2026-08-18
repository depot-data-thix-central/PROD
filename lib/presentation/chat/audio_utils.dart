import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Utilitaires pour les messages audio.
class AudioUtils {
  /// Formate une durée en secondes en chaîne mm:ss.
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  /// Formate une durée en secondes en chaîne lisible (ex: 1 min 30 s).
  static String formatDurationHuman(int seconds) {
    if (seconds < 60) return '$seconds s';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    if (remaining == 0) return '$minutes min';
    return '$minutes min $remaining s';
  }

  /// Formate la taille d'un fichier en octets en Ko ou Mo.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / 1048576).toStringAsFixed(1)} Mo';
  }

  /// Génère des données d'onde sonore synthétiques (pour démonstration).
  /// Retourne une liste de niveaux normalisés entre 0 et 1.
  static List<double> generateWaveformData(int barCount, double intensity) {
    final random = Random();
    final data = List.generate(barCount, (_) {
      return 0.2 + random.nextDouble() * 0.8 * intensity;
    });
    // Lisser un peu
    for (int i = 1; i < data.length - 1; i++) {
      data[i] = (data[i - 1] + data[i] + data[i + 1]) / 3;
    }
    return data;
  }

  /// Convertit une chaîne de données d'onde (base64 ou liste sérialisée) en List<double>.
  static List<double> decodeWaveform(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final parts = encoded.split(',');
      return parts.map((e) => double.parse(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Encode une liste de doubles en chaîne pour le stockage.
  static String encodeWaveform(List<double> data) {
    return data.map((e) => e.toStringAsFixed(3)).join(',');
  }

  /// Extrait un échantillon d'onde pour l'affichage (réduit ou agrandit).
  static List<double> resampleWaveform(List<double> data, int targetCount) {
    if (data.isEmpty) return List.filled(targetCount, 0.5);
    final step = data.length / targetCount;
    final result = <double>[];
    for (int i = 0; i < targetCount; i++) {
      final start = (i * step).floor();
      final end = ((i + 1) * step).ceil();
      double sum = 0;
      int count = 0;
      for (int j = start; j < end && j < data.length; j++) {
        sum += data[j];
        count++;
      }
      result.add(count > 0 ? sum / count : 0.5);
    }
    return result;
  }

  /// Retourne un widget de visualisation d'onde minimaliste (pour les messages).
  static Widget buildMiniWaveform({
    required List<double>? data,
    required double progress,
    required Color color,
    double height = 20,
    int barCount = 20,
    double barWidth = 3,
    double barSpacing = 2,
  }) {
    final waveformData = data ?? List.filled(barCount, 0.5);
    final resampled = resampleWaveform(waveformData, barCount);
    final progressIndex = (resampled.length * progress).floor();

    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(resampled.length, (index) {
          final value = resampled[index];
          final barHeight = (value * height * 0.8).clamp(2.0, height);
          final isProgress = index <= progressIndex;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: barSpacing / 2),
            child: Container(
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: isProgress ? color : color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(barWidth / 2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
