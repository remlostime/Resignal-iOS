//
//  SelectableTextView.swift
//  Resignal
//
//  Non-editable, selectable text view with a restricted context menu
//  (Copy, Select All) and an onCopy callback for toast feedback.
//

import SwiftUI
import UIKit

struct SelectableTextView: UIViewRepresentable {

    let text: String
    var onCopy: (() -> Void)?

    func makeUIView(context: Context) -> CopyAwareTextView {
        let textView = CopyAwareTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = UIColor(AppTheme.Colors.textPrimary)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textView.onCopy = onCopy
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: CopyAwareTextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            uiView.invalidateIntrinsicContentSize()
        }
        uiView.onCopy = onCopy
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CopyAwareTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width < CGFloat.infinity else {
            return nil
        }
        let fittingSize = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: width, height: fittingSize.height)
    }
}

// MARK: - UITextView Subclass

final class CopyAwareTextView: UITextView {

    var onCopy: (() -> Void)?

    private static let allowedActions: Set<Selector> = [
        #selector(copy(_:)),
        #selector(selectAll(_:)),
    ]

    override var intrinsicContentSize: CGSize {
        let fixedWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let size = sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        Self.allowedActions.contains(action)
    }

    override func copy(_ sender: Any?) {
        super.copy(sender)
        onCopy?()
    }
}
