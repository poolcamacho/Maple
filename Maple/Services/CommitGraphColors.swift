//
//  CommitGraphColors.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

enum CommitGraphColors {
    private static let palette: [Color] = [
        .blue, .green, .orange, .purple,
        .pink, .teal, .yellow, .red,
        .cyan, .mint, .indigo, .brown
    ]

    static func color(forLane lane: Int) -> Color {
        palette[abs(lane) % palette.count]
    }
}
