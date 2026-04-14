//
//  GitCommit+Hashable.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

// MARK: - Equatable/Hashable for selection

extension GitCommit: Hashable {
    static func == (lhs: GitCommit, rhs: GitCommit) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
