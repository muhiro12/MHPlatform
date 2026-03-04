//
//  Item.swift
//  MHKitExample
//
//  Created by Hiromu Nakano on 2026/03/04.
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
