import Carbon.HIToolbox

/// Global hotkey via Carbon RegisterEventHotKey — needs no Accessibility
/// permission, unlike CGEventTap. Failable: returns nil if the combo is
/// already registered by another app.
///
/// Default is ⌃⇧V, NOT ⌘⇧V: ⌘⇧V is "Paste and Match Style" in many apps
/// (Notes, Slack, ...) and a global registration would steal it from all of
/// them silently. ⌃⇧V has no standard macOS meaning.
final class HotKey {
    static let defaultKeyCode = UInt32(kVK_ANSI_V)
    static let defaultModifiers = UInt32(controlKey | shiftKey)

    fileprivate static let signature = OSType(0x434C5053) // 'CLPS'
    private static var nextID: UInt32 = 0

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    fileprivate let hotKeyID: UInt32
    fileprivate let callback: () -> Void

    init?(keyCode: UInt32 = HotKey.defaultKeyCode,
          modifiers: UInt32 = HotKey.defaultModifiers,
          callback: @escaping () -> Void) {
        self.callback = callback
        Self.nextID += 1
        self.hotKeyID = Self.nextID

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler,
                                  1, &eventType, selfPointer, &eventHandler) == noErr else {
            return nil
        }

        let eventHotKeyID = EventHotKeyID(signature: Self.signature, id: hotKeyID)
        guard RegisterEventHotKey(keyCode, modifiers, eventHotKeyID,
                                  GetApplicationEventTarget(), 0, &hotKeyRef) == noErr,
              hotKeyRef != nil else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            // deinit still runs after `return nil` (all stored properties are
            // initialized by now), so nil the ref or it gets removed twice.
            eventHandler = nil
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
    guard let userData, let event else { return noErr }
    // Verify which hotkey fired instead of assuming ours: a second HotKey
    // instance would otherwise trigger every instance's callback.
    var firedID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID), nil,
                                   MemoryLayout<EventHotKeyID>.size, nil, &firedID)
    let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
    guard status == noErr,
          firedID.signature == HotKey.signature,
          firedID.id == hotKey.hotKeyID else { return noErr }
    hotKey.callback()
    return noErr
}
