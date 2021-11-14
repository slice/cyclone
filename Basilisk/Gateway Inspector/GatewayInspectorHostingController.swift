import Combine
import SwiftUI

private func globalGatewayLogStore() -> GatewayLogStore {
  let delegate = NSApp.delegate as! AppDelegate
  return delegate.gatewayLogStore
}

class GatewayInspectorHostingController: NSHostingController<GatewayInspector> {
  private var updateWindowTitleSink: AnyCancellable!

  required init?(coder: NSCoder) {
    super.init(
      coder: coder,
      rootView: GatewayInspector(state: globalGatewayLogStore())
    )
  }

  private func updateSubtitle() {
    let store = globalGatewayLogStore()
    let s = store.messages.count == 1 ? "" : "s"
    view.window?.subtitle = "\(store.messages.count) message\(s)"
  }

  override func viewDidAppear() {
    view.window?.title = "Gateway Inspector"
    updateSubtitle()

    updateWindowTitleSink = globalGatewayLogStore().objectWillChange
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.updateSubtitle()
      }
  }
}
