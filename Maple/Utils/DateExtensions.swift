//
//  DateExtensions.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
