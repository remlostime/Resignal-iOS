//
//  TagChipsView.swift
//  Resignal
//
//  Chip-based tag display and input component.
//

import SwiftUI

/// Displays tags as chips with optional removal
struct TagChipsView: View {
    
    // MARK: - Properties
    
    let tags: [String]
    let onRemove: ((String) -> Void)?
    
    // MARK: - Initialization
    
    init(tags: [String], onRemove: ((String) -> Void)? = nil) {
        self.tags = tags
        self.onRemove = onRemove
    }
    
    // MARK: - Body
    
    var body: some View {
        FlowLayout(spacing: AppTheme.Spacing.xs) {
            ForEach(tags, id: \.self) { tag in
                TagChip(tag: tag, onRemove: onRemove)
            }
        }
    }
}

/// Single tag chip component
struct TagChip: View {
    
    let tag: String
    let onRemove: ((String) -> Void)?
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Text(tag)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            if let onRemove = onRemove {
                Button {
                    onRemove(tag)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xxs)
        .background(AppTheme.Colors.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

/// Flow layout for wrapping chips to next line
struct FlowLayout: Layout {
    
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }
        
        return (positions, CGSize(width: totalWidth, height: totalHeight))
    }
}

/// Tag input field that parses comma-separated values
struct TagInputField: View {
    
    @Binding var tags: [String]
    @State private var inputText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            if !tags.isEmpty {
                TagChipsView(tags: tags) { tag in
                    withAnimation(AppTheme.Animation.fast) {
                        tags.removeAll { $0 == tag }
                    }
                }
            }
            
            HStack {
                TextField("Add tags (comma separated)", text: $inputText)
                    .font(AppTheme.Typography.body)
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        addTags()
                    }
                
                if !inputText.isEmpty {
                    Button("Add") {
                        addTags()
                    }
                    .font(AppTheme.Typography.callout.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
    }
    
    private func addTags() {
        let newTags = inputText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !tags.contains($0) }
        
        withAnimation(AppTheme.Animation.fast) {
            tags.append(contentsOf: newTags)
        }
        inputText = ""
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TagChipsView(tags: ["iOS", "Swift", "SwiftUI", "Technical"])
        
        TagChipsView(tags: ["iOS", "Swift", "SwiftUI"]) { tag in
            print("Remove: \(tag)")
        }
        
        TagInputField(tags: .constant(["Sample", "Tags"]))
    }
    .padding()
}

