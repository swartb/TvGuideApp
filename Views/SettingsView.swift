// SettingsView.swift
// Settings screen: feed URL, manual update button, and status info.

import SwiftUI

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section("Feed") {
                    TextField("https://…/guide.xml.gz", text: $vm.feedURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: vm.feedURL) { vm.saveFeedURL() }

                    Button {
                        vm.updateFeed()
                    } label: {
                        HStack {
                            if vm.isUpdating {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(vm.isUpdating ? "Bezig…" : "Test / Nu bijwerken")
                        }
                    }
                    .disabled(vm.isUpdating || vm.feedURL.isEmpty)
                }

                if !vm.statusMessage.isEmpty {
                    Section("Status") {
                        Text(vm.statusMessage)
                            .foregroundStyle(vm.isError ? .red : .secondary)
                            .font(.footnote)
                    }
                }

                Section("Statistieken") {
                    LabeledContent("Laatste update", value: vm.lastUpdateLabel)
                    LabeledContent("Zenders", value: "\(vm.channelCount)")
                    LabeledContent("Programma's", value: "\(vm.programmeCount)")
                }
            }
            .navigationTitle("Instellingen")
            .task { vm.loadStats() }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var feedURL: String = ""
    @Published var isUpdating = false
    @Published var statusMessage = ""
    @Published var isError = false
    @Published var lastUpdateLabel = "Nooit"
    @Published var channelCount = 0
    @Published var programmeCount = 0

    init() {
        feedURL = FeedService.shared.feedURL
    }

    func saveFeedURL() {
        FeedService.shared.feedURL = feedURL
    }

    func updateFeed() {
        isUpdating = true
        statusMessage = ""
        isError = false

        Task {
            do {
                try await FeedService.shared.update()
                loadStats()
                statusMessage = "Feed succesvol bijgewerkt."
            } catch {
                isError = true
                statusMessage = error.localizedDescription
            }
            isUpdating = false
        }
    }

    func loadStats() {
        if let stats = try? DatabaseManager.shared.getStats() {
            channelCount   = stats.channelCount
            programmeCount = stats.programmeCount
        }

        if let date = FeedService.shared.lastUpdate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastUpdateLabel = formatter.string(from: date)
        } else {
            lastUpdateLabel = "Nooit"
        }
    }
}
