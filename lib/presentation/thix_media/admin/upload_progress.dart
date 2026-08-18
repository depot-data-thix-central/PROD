import 'package:flutter/material.dart';
const kNavyDeep = Color(0xFF0A1F44);
const kAccent = Color(0xFF2D6CDF);

class UploadProgress extends StatelessWidget {
  final double progress; // 0.0 à 1.0
  final String fileName;
  final String status;
  final String? secondaryStatus;
  const UploadProgress({
    super.key,
    this.progress = 0,
    this.fileName = '',
    required this.status,
    this.secondaryStatus,
  });

  // compat ancien appel : UploadProgress(progress: 0.5, status: '...')
  factory UploadProgress.simple({required double progress, required String status}) {
    return UploadProgress(progress: progress, fileName: '', status: status);
  }

  @override Widget build(BuildContext context){
    final pct = (progress.clamp(0.0,1.0)*100).toInt();
    final isDone = progress>=0.99;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDone? Colors.green.withOpacity(0.3) : const Color(0xFFE7EEFC)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0,4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: isDone? Colors.green.withOpacity(0.15) : kAccent.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(isDone? Icons.check_rounded : Icons.cloud_upload_rounded, size: 16, color: isDone? Colors.green : kAccent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if(fileName.isNotEmpty) Text(fileName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kNavyDeep), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(status, style: TextStyle(fontSize: fileName.isNotEmpty? 10 : 12, fontWeight: FontWeight.w600, color: fileName.isNotEmpty? const Color(0xFF7386A8) : kNavyDeep)),
          ])),
          const SizedBox(width: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 400),
            builder: (c,v,_ )=> Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDone? Colors.green : kAccent)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (c,v,_ )=> LinearProgressIndicator(
              value: v==0? null : v,
              backgroundColor: const Color(0xFFE7EEFC),
              valueColor: AlwaysStoppedAnimation(isDone? Colors.green : kAccent),
              minHeight: 6,
            ),
          ),
        ),
        if(secondaryStatus!=null)...[
          const SizedBox(height: 6),
          Text(secondaryStatus!, style: const TextStyle(fontSize: 10, color: Color(0xFF7386A8))),
        ],
      ]),
    );
  }
}
