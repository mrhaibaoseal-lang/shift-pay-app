import SwiftUI
import UIKit

@MainActor
public final class KeyboardDismissManager: NSObject, UIGestureRecognizerDelegate {
    public static let shared = KeyboardDismissManager()

    private let recognizerName = "com.mrhaibaoseal.shiftpay.keyboardDismissTap"
    private var isStarted = false
    private var isKeyboardVisible = false

    private override init() { super.init() }

    public static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for window in ws.windows where !window.isHidden {
                window.endEditing(true)
            }
        }
    }

    public func start() {
        guard !isStarted else {
            installOnAllWindows()
            return
        }
        isStarted = true
        installOnAllWindows()

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(onWindowKey(_:)), name: UIWindow.didBecomeKeyNotification, object: nil)
        nc.addObserver(self, selector: #selector(onKBShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(onKBHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        nc.addObserver(self, selector: #selector(onTFBegin(_:)), name: UITextField.textDidBeginEditingNotification, object: nil)
        nc.addObserver(self, selector: #selector(onTVBegin(_:)), name: UITextView.textDidBeginEditingNotification, object: nil)
    }

    public func installOnAllWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for window in ws.windows { installTapGesture(on: window) }
        }
    }

    private func installTapGesture(on window: UIWindow) {
        let cls = NSStringFromClass(type(of: window))
        if cls.contains("Keyboard") || cls.contains("TextEffects") { return }
        if window.gestureRecognizers?.contains(where: { $0.name == recognizerName }) == true { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleWindowTap(_:)))
        tap.name = recognizerName
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
    }

    @objc private func onKBShow() { isKeyboardVisible = true; installOnAllWindows() }
    @objc private func onKBHide() { isKeyboardVisible = false }
    @objc private func onWindowKey(_ note: Notification) {
        if let w = note.object as? UIWindow { installTapGesture(on: w) }
        installOnAllWindows()
    }

    @objc private func onTFBegin(_ note: Notification) {
        isKeyboardVisible = true
        installOnAllWindows()
        guard let tf = note.object as? UITextField else { return }
        if tf.inputAccessoryView == nil {
            tf.inputAccessoryView = makeToolbar()
            tf.reloadInputViews()
        }
        if let w = tf.window { installTapGesture(on: w) }
    }

    @objc private func onTVBegin(_ note: Notification) {
        isKeyboardVisible = true
        installOnAllWindows()
        guard let tv = note.object as? UITextView else { return }
        if tv.inputAccessoryView == nil {
            tv.inputAccessoryView = makeToolbar()
            tv.reloadInputViews()
        }
        if let w = tv.window { installTapGesture(on: w) }
    }

    private func makeToolbar() -> UIToolbar {
        let tb = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        tb.barStyle = .black
        tb.isTranslucent = true

        let hint = UILabel()
        hint.text = "點空白處或按右側完成即可收起鍵盤"
        hint.font = .systemFont(ofSize: 12, weight: .medium)
        hint.textColor = UIColor.white.withAlphaComponent(0.6)
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let btn = UIButton(type: .system)
        var cfg = UIButton.Configuration.filled()
        cfg.title = "完成 ✓"
        cfg.baseBackgroundColor = UIColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 1.0)
        cfg.baseForegroundColor = .white
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14)
        btn.configuration = cfg
        btn.addTarget(self, action: #selector(onDoneTap), for: .touchUpInside)

        tb.items = [UIBarButtonItem(customView: hint), flex, UIBarButtonItem(customView: btn)]
        tb.sizeToFit()
        return tb
    }

    @objc private func onDoneTap() { HapticsManager.shared.lightTap(); Self.dismiss() }
    @objc private func handleWindowTap(_ g: UITapGestureRecognizer) {
        if g.state == .ended { Self.dismiss() }
    }

    public func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    public func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard isKeyboardVisible else { return false }
        var v: UIView? = touch.view
        while let cur = v {
            if cur is UITextField || cur is UITextView { return false }
            let t = NSStringFromClass(type(of: cur))
            if t.contains("Keyboard") || t.contains("InputSet") || t.contains("UIToolbar") || t.contains("ButtonBar") {
                return false
            }
            v = cur.superview
        }
        return true
    }
}

public extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onAppear { KeyboardDismissManager.shared.start() }
    }
}
