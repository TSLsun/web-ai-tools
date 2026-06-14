// ios/NewsSummarizer/NewsSummarizerApp.swift
import SwiftUI

@main
struct NewsSummarizerApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("摘要", systemImage: "newspaper") }
                SettingsView()
                    .tabItem { Label("設定", systemImage: "gearshape") }
            }
        }
    }
}
