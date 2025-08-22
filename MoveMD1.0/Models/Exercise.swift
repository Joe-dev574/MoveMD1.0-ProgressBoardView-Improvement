

//
//  Exercise.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//

import SwiftData

@Model
class Exercise {
    var name: String
    var order: Int
    var splitTimes: [SplitTime] = []  // No @Relationship macro needed
    
    init(name: String, order: Int = 0) {
        self.name = name
        self.order = order
    }
}
