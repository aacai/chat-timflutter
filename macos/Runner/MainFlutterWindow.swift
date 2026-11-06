import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    let bg = NSColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.0)
    self.backgroundColor = bg
    self.isOpaque = true
    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = bg.cgColor

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 子窗口是独立的 FlutterViewController，不会走主窗口的注册流程。
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      // GeneratedPluginRegistrant 会把 FlutterMultiWindowPlugin 再注册一遍，
      // 它会把 windowId=0 的原生通道错挂到子窗口。用主窗口 registrar 重新
      // 注册一次，保证子窗口发往主窗口的消息能送达。
      FlutterMultiWindowPlugin.register(
        with: flutterViewController.registrar(forPlugin: "FlutterMultiWindowPlugin"))
    }

    super.awakeFromNib()
  }
}
