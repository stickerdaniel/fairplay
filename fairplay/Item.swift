//
//  Item.swift
//  fairplay
//
//  Created by Daniel Sticker on 05.01.26.
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
