import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private let pdfEngine = IosPdfTextEngine()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let pdfChannel = FlutterMethodChannel(name: "com.translator/pdf_text_engine", binaryMessenger: controller.binaryMessenger)

    pdfChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }

      if call.method == "extractTextElements" {
        guard let args = call.arguments as? [String: Any],
              let pdfPath = args["pdfPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "pdfPath required", details: nil))
          return
        }
        let pageIndex = (args["pageIndex"] as? Int) ?? 0
        let elements = self.pdfEngine.extractTextElements(pdfPath: pdfPath, pageIndex: pageIndex)
        result(elements)
      } else if call.method == "saveModifiedPdf" {
        guard let args = call.arguments as? [String: Any],
              let sourcePath = args["sourcePath"] as? String,
              let outPath = args["outPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "sourcePath and outPath required", details: nil))
          return
        }
        let modifications = (args["modifications"] as? [[String: Any]]) ?? []
        let success = self.pdfEngine.saveModifiedPdf(sourcePath: sourcePath, outPath: outPath, modifications: modifications)
        result(success)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
