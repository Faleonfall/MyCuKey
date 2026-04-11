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
                        let threshold = 12.0 // Pixels per character slice
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
