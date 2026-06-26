//
//  Item.swift
//  TheVeil
//
//  Created by Tilo Delau on 2026-06-26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
