// ChannelDetailView.swift
// Shows the programme schedule for a single channel on a chosen day.

import SwiftUI

struct ChannelDetailView: View {
    let channel: Channel

    @State private var selectedDate = Date()
    @State private var programmes: [Programme] = []
    @State private var isLoading = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Day navigation
            HStack {
                Button {
                    if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                        selectedDate = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(.horizontal)
                }

                Spacer()

                Text(Self.dayFormatter.string(from: selectedDate))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                        selectedDate = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if programmes.isEmpty {
                EmptyStateView(
                    iconName: "calendar.badge.exclamationmark",
                    title: "Geen programma's",
                    description: "Er zijn geen programma's beschikbaar voor deze dag."
                )
            } else {
                List(programmes) { programme in
                    ProgrammeRow(programme: programme)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedDate) { await loadProgrammes() }
    }

    private func loadProgrammes() async {
        isLoading = true
        programmes = (try? DatabaseManager.shared.fetchProgrammes(for: channel.id, on: selectedDate)) ?? []
        isLoading = false
    }
}

// MARK: - Programme Row

private struct ProgrammeRow: View {
    let programme: Programme

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Self.timeFormatter.string(from: programme.startDate))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                Text(programme.title)
                    .font(.body)
            }

            if let desc = programme.desc, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 52)
            }
        }
        .padding(.vertical, 2)
    }
}
