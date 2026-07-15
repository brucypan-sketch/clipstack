import Carbon.HIToolbox

/// Global hotkey via Carbon RegisterEventHotKey — needs no Accessibility
/// permission, unlike CGEventTap. Failable: returns nil if the combo is
/// already registered by another app.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    fileprivate let callback: () -> Void

    init?(keyCode: Int = kVK_ANSI_V,
          modifiers: Int = cmdKey | shiftKey,
          callback: @escaping () -> Void) {
        self.callback = callback

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler,
                                  1, &eventType, selfPointer, &eventHandler) == noErr else {
            return nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5053), id: 1) // 'CLPS'
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                  GetApplicationEventTarget(), 0, &hotKeyRef) == noErr,
              hotKeyRef != nil else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}

private func hotKeyEventHandler(_ nextHandler: EventHandlerCallRef?,
                                _ event: EventRef?,
                                _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().callback()
    return noErr
}
