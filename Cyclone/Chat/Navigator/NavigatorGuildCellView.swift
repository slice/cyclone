import Cocoa

class NavigatorGuildCellView: NSTableCellView {
  @IBOutlet var roundingView: RoundingView!

  override func prepareForReuse() {
    super.prepareForReuse()
    imageView?.image = nil
    imageView?.kf.cancelDownloadTask()
    textField?.stringValue = ""
  }
}
