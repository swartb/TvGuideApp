// ContentView.swift
// Root view: a TabView with "Nu/Straks", "Zenders", and "Instellingen" tabs.

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NowNextView()
                .tabItem {
                    Label("Nu/Straks", systemImage: "clock.fill")
                }

            ChannelsView()
                .tabItem {
                    Label("Zenders", systemImage: "tv.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Instellingen", systemImage: "gearshape.fill")
                }
        }
    }
}
