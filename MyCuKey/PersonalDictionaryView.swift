import SwiftUI
import Combine

// MARK: - Personal Dictionary View Model

@MainActor
final class PersonalDictionaryViewModel: ObservableObject {
    @Published var learnedWords: [LearnedWordEntry] = []
    @Published var newWord: String = ""
    @Published var searchText: String = ""

    private let service: PersonalDictionaryService

    // MARK: - Initialization

    init(service: PersonalDictionaryService) {
        self.service = service
        reload()
    }

    convenience init() {
        self.init(service: .shared)
    }

    // MARK: - Derived State

    var filteredWords: [LearnedWordEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return learnedWords }
        return learnedWords.filter { $0.normalizedWord.contains(query) }
    }

    var canAddWord: Bool {
        PersonalDictionaryService.normalizeLearnableWord(newWord) != nil
    }

    // MARK: - Actions

    func reload() {
        service.refreshFromStorage()
        learnedWords = service.allWords()
    }

    func addWord() {
        guard service.addWord(newWord) != nil else { return }
        newWord = ""
        reload()
    }

    func removeWords(at offsets: IndexSet) {
        let items = filteredWords
        for index in offsets {
            service.removeWord(items[index].normalizedWord)
        }
        reload()
    }

    func removeWord(_ word: String) {
        service.removeWord(word)
        reload()
    }

    func clearAll() {
        service.clearAll()
        reload()
    }
}

// MARK: - Personal Dictionary View

struct PersonalDictionaryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = PersonalDictionaryViewModel()
    @State private var showClearAllConfirmation = false

    // MARK: - Layout

    var body: some View {
        List {
            Section("Add Word") {
                HStack(spacing: 12) {
                    TextField("Custom word", text: $viewModel.newWord)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Add") {
                        viewModel.addWord()
                    }
                    .disabled(!viewModel.canAddWord)
                }

                Text("Learned words are stored in the shared keyboard dictionary and will suppress future autocorrections.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                if viewModel.filteredWords.isEmpty {
                    Text(viewModel.searchText.isEmpty ? "No learned words yet." : "No matching words.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.filteredWords) { entry in
                        Text(entry.normalizedWord)
                    }
                    .onDelete(perform: viewModel.removeWords)
                }
            } header: {
                HStack {
                    Text("Learned Words")
                    Spacer()
                    Text("\(viewModel.learnedWords.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Personal Dictionary")
        .searchable(text: $viewModel.searchText, prompt: "Search learned words")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.learnedWords.isEmpty {
                    Button("Clear All", role: .destructive) {
                        showClearAllConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog("Remove all learned words?", isPresented: $showClearAllConfirmation, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                viewModel.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            viewModel.reload()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            viewModel.reload()
        }
    }
}
