//
//  ContentView.swift
//  VibePomodoro
//
//  Created by Qi Wu on 15.03.26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PomodoroStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var isFocusTabBarVisuallyHidden = false

    var body: some View {
        TabView(selection: $store.selectedTab) {
            FocusScreen(tabBarChromeHidden: $isFocusTabBarVisuallyHidden)
                .tag(AppTab.focus)
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }

            ProductivityScreen()
                .tag(AppTab.productivity)
                .tabItem {
                    Label("Productivity", systemImage: "chart.bar")
                }

            SettingsScreen()
                .tag(AppTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(VibePalette.interfaceTint(for: colorScheme, contrast: colorSchemeContrast))
        .background {
            SystemTabBarVisibilityBridge(isHidden: isFocusTabBarVisuallyHidden)
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: store.selectedTab)
    }
}
