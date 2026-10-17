// ignore: uri_does_not_exist
import 'call_foreground_service_stub.dart'
    if (dart.library.io) 'call_foreground_service_impl.dart';

class CallForegroundService {
  CallForegroundService._();

  static Future<void> start({required bool video}) =>
      CallForegroundServiceImpl.start(video: video);

  static Future<void> stop() => 
      CallForegroundServiceImpl.stop();
}
