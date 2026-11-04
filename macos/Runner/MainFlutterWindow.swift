import Cocoa
import FlutterMacOS

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

    super.awakeFromNib()
  }
}
