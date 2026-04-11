import SwiftUI

extension View {
    @ViewBuilder
    func trackpadGesture(isEnabled: Bool, trackpadAction: ((Int)->Void)?, isDragging: Binding<Bool>, dragStartOffset: Binding<CGFloat>) -> some View {
        if isEnabled {
            self.highPriorityGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if !isDragging.wrappedValue {
                            isDragging.wrappedValue = true
                            dragStartOffset.wrappedValue = value.translation.width
                            HapticFeedback.playMedium() // Trackpad initiate haptic
                        }
                        
                        let translation = value.translation.width
                        
                        // Dynamic threshold: shrinks as finger moves further from origin.
                        // value.translation is always relative to gesture start, so abs() = natural displacement.
                        let absDisplacement = abs(value.translation.width)
                        let threshold: Double
                        switch absDisplacement {
                        case ..<50:   threshold = 14.0  // Precise: 1 char per 14px
                        case ..<120:  threshold = 8.0   // Medium:  1 char per 8px
                        default:      threshold = 4.0   // Fast:    1 char per 4px
                        }
                        
                        let steps = Int((translation - dragStartOffset.wrappedValue) / threshold)
                        
                        if steps != 0 {
                            trackpadAction?(steps)
                            dragStartOffset.wrappedValue += CGFloat(steps) * threshold
                        }
                    }
                    .onEnded { _ in
                        isDragging.wrappedValue = false
                        dragStartOffset.wrappedValue = 0
                    }
            )
        } else {
            self
        }
    }
}
