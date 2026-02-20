// ChannelsView.swift
// Tab 2 – list of all channels; tap one to see its daily programme schedule.

import SwiftUI

struct ChannelsView: View {
    @State private var channels: [Channel] = []
    @State private var searchText = ""

    private var filtered: [Channel] {
        guard !searchText.isEmpty else { return channels }
        return channels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if channels.isEmpty {
                    EmptyStateView(
                        iconName: "tv.slash",
                        title: "Geen zenders",
                        description: "Voeg een feed-URL toe in Instellingen en tik op \"Bijwerken\"."
                    )
                } else {
                    List(filtered) { channel in
                        NavigationLink(destination: ChannelDetailView(channel: channel)) {
                            HStack(spacing: 12) {
                                ChannelIconView(url: channel.icon)
                                Text(channel.name)
                                    .font(.body)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Zenders")
            .searchable(text: $searchText, prompt: "Zoek zender")
            .task { await loadChannels() }
            .refreshable { await loadChannels() }
        }
    }

    private func loadChannels() async {
        channels = (try? DatabaseManager.shared.fetchChannels()) ?? []
    }
}
