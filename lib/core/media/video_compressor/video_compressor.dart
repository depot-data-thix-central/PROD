// Aiguillage de plateforme : le web (dart2js ET dart2wasm) prend le stub,
// le natif (Android/iOS/macOS) prend le plugin. Le build web ne compile
// donc jamais light_compressor_v2.
export 'video_compressor_native.dart'
    if (dart.library.js_interop) 'video_compressor_web.dart';
