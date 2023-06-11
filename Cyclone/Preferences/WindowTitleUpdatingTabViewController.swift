import Cocoa

class WindowTitleUpdatingTabViewController: NSTabViewController {
  override func viewDidAppear() {
    super.viewDidAppear()
    view.window?.title = tabViewItems[selectedTabViewItemIndex].label
  }

  override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
    guard let title = tabViewItem?.label else {
      return
    }
    tabView.window?.title = title
  }
}
