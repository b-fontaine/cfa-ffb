import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeDocumentsFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Prénoms et résultats d'élèves mineurs : la base SQLite (dossier Documents)
  /// ne doit pas partir dans les sauvegardes iCloud ; l'export JSON reste le
  /// seul moyen de sortir les données, à l'initiative de l'animateur.
  private func excludeDocumentsFromBackup() {
    guard
      var documents = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
      ).first
    else { return }
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try documents.setResourceValues(values)
    } catch {
      NSLog("Exclusion des sauvegardes iCloud impossible : \(error)")
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
