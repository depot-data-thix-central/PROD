import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 🔑 GOOGLE MAPS SDK (google_maps_flutter)
    // Créez cette clé dans Google Cloud Console > Identifiants >
    // "Créer des identifiants" > Clé API > Restreindre à iOS (votre Bundle ID)
    GMSServices.provideAPIKey("COLLEZ_VOTRE_CLE_API_IOS_ICI")

    // 📞 CallKit/VoIP, 🔔 Firebase Messaging et 🔗 Universal Links
    // sont gérés automatiquement par FlutterAppDelegate + les plugins.
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
