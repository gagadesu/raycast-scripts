import AppKit
import CoreGraphics
import Foundation
import RaycastSwiftMacros

private enum KeyCode: CGKeyCode {
  case u = 0x20
}

private let internalStopMarker: Int64 = 0x434C45414E

private final class CleaningOverlayWindow: NSWindow {
  convenience init(screen: NSScreen) {
    self.init(
      // The screen-specific initializer expects an origin relative to the
      // supplied screen. Passing screen.frame here adds the screen origin a
      // second time and places secondary-display windows offscreen.
      contentRect: NSRect(origin: .zero, size: screen.frame.size),
      styleMask: [.borderless, .fullSizeContentView],
      backing: .buffered,
      defer: false,
      screen: screen
    )
    // Swift ARC owns the window; close() must not release it again.
    isReleasedWhenClosed = false
    level = .screenSaver
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    isOpaque = true
    backgroundColor = .black
    hasShadow = false
    isMovable = false
    hidesOnDeactivate = false
    ignoresMouseEvents = false
    title = "Clean Mode"
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

final class CleaningModeController: NSObject {
  private var windows: [CleaningOverlayWindow] = []
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var screenObserver: NSObjectProtocol?
  private var focusTimer: Timer?
  private var isStopping = false
  private let locksKeyboard: Bool
  private let activationPolicy: NSApplication.ActivationPolicy

  init(
    locksKeyboard: Bool = true,
    activationPolicy: NSApplication.ActivationPolicy = .accessory
  ) {
    self.locksKeyboard = locksKeyboard
    self.activationPolicy = activationPolicy
  }

  func run() {
    let application = NSApplication.shared
    application.setActivationPolicy(activationPolicy)
    application.finishLaunching()

    guard !locksKeyboard || startKeyboardLock() else {
      fatalError("Failed to create keyboard event tap. Check Raycast Accessibility permission.")
    }

    createOverlayWindows()
    observeScreenChanges()
    startFocusEnforcer()
    application.activate(ignoringOtherApps: true)
    windows.first?.makeKeyAndOrderFront(nil)
    application.run()
    tearDown()
  }

  private func createOverlayWindows() {
    closeOverlayWindows()
    for screen in NSScreen.screens {
      let window = CleaningOverlayWindow(screen: screen)
      window.contentView = makeContentView()
      window.orderFrontRegardless()
      windows.append(window)
    }
  }

  private func makeContentView() -> NSView {
    let rootView = NSView()
    rootView.wantsLayer = true
    rootView.layer?.backgroundColor = NSColor.black.cgColor

    let iconView = NSImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.image = NSImage(systemSymbolName: "paintbrush.pointed.fill", accessibilityDescription: "Cleaning")
      ?? NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Cleaning")
    iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 54, weight: .light)
    iconView.contentTintColor = NSColor(white: 0.86, alpha: 1)
    iconView.imageScaling = .scaleProportionallyUpOrDown

    let titleLabel = label("Screen Cleaning Mode", size: 24, weight: .semibold, color: .white)
    let subtitleLabel = label(
      "Clean the screen and keyboard safely",
      size: 13,
      weight: .regular,
      color: NSColor(white: 0.58, alpha: 1)
    )

    let exitButton = NSButton(title: "Click to Exit", target: self, action: #selector(exitClicked))
    exitButton.translatesAutoresizingMaskIntoConstraints = false
    exitButton.isBordered = false
    exitButton.font = NSFont.systemFont(ofSize: 15, weight: .medium)
    exitButton.contentTintColor = .white
    exitButton.refusesFirstResponder = true
    exitButton.focusRingType = .none
    exitButton.cell?.focusRingType = .none
    exitButton.wantsLayer = true
    exitButton.layer?.backgroundColor = NSColor(white: 0.20, alpha: 1).cgColor
    exitButton.layer?.cornerRadius = 9
    exitButton.toolTip = "Exit Clean Mode"

    let centerStack = NSStackView(views: [iconView, titleLabel, subtitleLabel, exitButton])
    centerStack.translatesAutoresizingMaskIntoConstraints = false
    centerStack.orientation = .vertical
    centerStack.alignment = .centerX
    centerStack.spacing = 14
    centerStack.setCustomSpacing(22, after: subtitleLabel)

    let keyboardLabel = label(
      "Your keyboard is also locked",
      size: 13,
      weight: .regular,
      color: NSColor(white: 0.46, alpha: 1)
    )

    rootView.addSubview(centerStack)
    rootView.addSubview(keyboardLabel)
    NSLayoutConstraint.activate([
      centerStack.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
      centerStack.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 72),
      iconView.heightAnchor.constraint(equalToConstant: 72),
      exitButton.widthAnchor.constraint(equalToConstant: 156),
      exitButton.heightAnchor.constraint(equalToConstant: 44),
      keyboardLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
      keyboardLabel.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -38),
    ])
    return rootView
  }

  private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.translatesAutoresizingMaskIntoConstraints = false
    field.font = NSFont.systemFont(ofSize: size, weight: weight)
    field.textColor = color
    field.alignment = .center
    field.maximumNumberOfLines = 1
    return field
  }

  private func startKeyboardLock() -> Bool {
    let eventMask = CGEventMask(
      (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.keyUp.rawValue) |
        (1 << CGEventType.flagsChanged.rawValue) |
        (1 << 14)
    )
    guard let tap = CGEvent.tapCreate(
      tap: .cghidEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: eventMask,
      callback: keyboardEventCallback,
      userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    ) else {
      return false
    }

    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    if let runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
  }

  func handleKeyboardEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
      return Unmanaged.passUnretained(event)
    }

    if type == .keyDown && event.getIntegerValueField(.eventSourceUserData) == internalStopMarker {
      stop()
    }

    // Mouse and trackpad events are intentionally absent from the event mask,
    // while every physical keyboard event is swallowed here.
    return nil
  }

  private func observeScreenChanges() {
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.createOverlayWindows()
      self?.windows.first?.makeKeyAndOrderFront(nil)
    }
  }

  private func startFocusEnforcer() {
    focusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      guard let self, !self.isStopping else { return }
      for window in self.windows { window.orderFrontRegardless() }
      self.windows.first?.makeKey()
    }
  }

  @objc private func exitClicked() {
    stop()
  }

  private func stop() {
    guard !isStopping else { return }
    isStopping = true
    tearDown()
    NSApp.stop(nil)

    if let wakeEvent = NSEvent.otherEvent(
      with: .applicationDefined,
      location: .zero,
      modifierFlags: [],
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: 0,
      context: nil,
      subtype: 0,
      data1: 0,
      data2: 0
    ) {
      NSApp.postEvent(wakeEvent, atStart: true)
    }
  }

  private func tearDown() {
    if let screenObserver {
      NotificationCenter.default.removeObserver(screenObserver)
      self.screenObserver = nil
    }
    focusTimer?.invalidate()
    focusTimer = nil

    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      CFMachPortInvalidate(eventTap)
    }
    runLoopSource = nil
    eventTap = nil
    closeOverlayWindows()
  }

  private func closeOverlayWindows() {
    for window in windows {
      window.contentView = nil
      window.orderOut(nil)
      window.close()
    }
    windows.removeAll()
  }
}

private func keyboardEventCallback(
  proxy _: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let controller = Unmanaged<CleaningModeController>.fromOpaque(refcon).takeUnretainedValue()
  return controller.handleKeyboardEvent(type: type, event: event)
}

func postInternalStopEvent() {
  let stopEvent = CGEvent(keyboardEventSource: nil, virtualKey: KeyCode.u.rawValue, keyDown: true)
  stopEvent?.flags = .maskControl
  stopEvent?.setIntegerValueField(.eventSourceUserData, value: internalStopMarker)
  stopEvent?.post(tap: .cghidEventTap)
}

@raycast func handler() {
  CleaningModeController().run()
}

@raycast func stopHandler() {
  postInternalStopEvent()
}
