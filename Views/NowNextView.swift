// NowNextView.swift
// Tab 1 – shows the current and next programme for every channel.

import SwiftUI

struct NowNextView: View {
    @State private var items: [(channel: Channel, now: Programme?, next: Programme?)] = []
    @State private var isLoading = false
    @State private var searchText = ""

    private var filtered: [(channel: Channel, now: Programme?, next: Programme?)] {
        guard !searchText.isEmpty else { return items }
        return items.filter { item in
            item.channel.name.localizedCaseInsensitiveContains(searchText)
                || item.now?.title.localizedCaseInsensitiveContains(searchText) == true
                || item.next?.title.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView("Laden…")
                } else if items.isEmpty {
                    EmptyStateView(
                        iconName: "tv.slash",
                        title: "Geen gegevens",
                        description: "Voeg een feed-URL toe in Instellingen en tik op \"Bijwerken\"."
                    )
                } else {
                    List(filtered, id: \.channel.id) { item in
                        NowNextRow(item: item)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Nu / Straks")
            .searchable(text: $searchText, prompt: "Zoek zender of programma")
            .refreshable { await loadData() }
            .task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        items = (try? DatabaseManager.shared.fetchNowNext()) ?? []
        isLoading = false
    }
}

// MARK: - Row

private struct NowNextRow: View {
    let item: (channel: Channel, now: Programme?, next: Programme?)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Channel icon
            ChannelIconView(url: item.channel.icon)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.channel.name)
                    .font(.headline)

                if let now = item.now {
                    Label(now.title, systemImage: "play.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(now.formattedTimeRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Geen huidig programma")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let next = item.next {
                    Label(next.title, systemImage: "forward.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(next.formattedTimeRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Channel Icon Helper

struct ChannelIconView: View {
    let url: String?

    var body: some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 44, height: 44)
    }

    private var placeholder: some View {
        Image(systemName: "tv")
            .resizable()
            .scaledToFit()
            .padding(8)
            .foregroundStyle(.secondary)
    }
}
