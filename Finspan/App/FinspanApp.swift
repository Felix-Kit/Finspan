//
//  FinspanApp.swift
//  Finspan
//
//  Created by work on 2026/6/2.
//

import SwiftUI

@main
struct FinspanApp: App {
    private let environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView(environment: environment)
        }
    }
}
