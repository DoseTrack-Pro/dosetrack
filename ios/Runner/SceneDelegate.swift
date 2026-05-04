import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  var flutterEngine: FlutterEngine?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let engine = FlutterEngine(name: "main_engine")
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    self.flutterEngine = engine

    let viewController = FlutterViewController(
      engine: engine,
      nibName: nil,
      bundle: nil
    )

    let newWindow = UIWindow(windowScene: windowScene)
    newWindow.rootViewController = viewController
    self.window = newWindow
    newWindow.makeKeyAndVisible()

    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
