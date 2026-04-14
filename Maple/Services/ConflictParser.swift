//
//  ConflictParser.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

enum ConflictSide: Sendable {
    case normal
    case ours
    case theirs
    case base
    case markerOurs
    case markerTheirs
    case markerBase
    case markerDivider
}

struct ConflictLine: Sendable {
    let content: String
    let side: ConflictSide
}

enum ConflictParser {
    static func parse(_ source: String) -> [ConflictLine] {
        var result: [ConflictLine] = []
        var side: ConflictSide = .normal

        for raw in source.components(separatedBy: "\n") {
            if raw.hasPrefix("<<<<<<<") {
                result.append(ConflictLine(content: raw, side: .markerOurs))
                side = .ours
            } else if raw.hasPrefix("|||||||") {
                result.append(ConflictLine(content: raw, side: .markerBase))
                side = .base
            } else if raw.hasPrefix("=======") && side != .normal {
                result.append(ConflictLine(content: raw, side: .markerDivider))
                side = .theirs
            } else if raw.hasPrefix(">>>>>>>") {
                result.append(ConflictLine(content: raw, side: .markerTheirs))
                side = .normal
            } else {
                result.append(ConflictLine(content: raw, side: side))
            }
        }

        return result
    }
}
