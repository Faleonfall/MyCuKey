import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("How to Enable")) {
                    InstructionRow(step: "1", text: "Open the Settings app on your iPhone or iPad.")
                    InstructionRow(step: "2", text: "Go to General > Keyboard > Keyboards.")
                    InstructionRow(step: "3", text: "Tap \"Add New Keyboard...\"")
                    InstructionRow(step: "4", text: "Locate and select MyCuKey from the list.")
                    InstructionRow(step: "5", text: "Tap on MyCuKey again and toggle \"Allow Full Access\" to enable all features.")
                }
                
                Section(header: Text("How to Use")) {
                    InstructionRow(step: "6", text: "Open any app with a text field (like Messages).")
                    InstructionRow(step: "7", text: "Tap and hold the 🌐 Globe button located at the bottom left of your standard Apple Keyboard.")
                    InstructionRow(step: "8", text: "Select MyCuKey from the menu to start typing!")
                }
            }
            .navigationTitle("Setup Guide")
        }
    }
}

struct InstructionRow: View {
    let step: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                Text(step)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.body)
                .padding(.top, 3)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
