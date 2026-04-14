//
//  StashModels.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

struct GitStashEntry: Identifiable, Sendable {
    let id: String      // e.g. "stash@{0}"
    let index: Int
    let message: String
    let relativeDate: String

    nonisolated init(id: String, index: Int, message: String, relativeDate: String) {
        self.id = id
        self.index = index
        self.message = message
        self.relativeDate = relativeDate
    }
}
