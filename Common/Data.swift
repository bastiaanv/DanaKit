//
//  Data.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 10/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

extension Data {
    func uint16(at index: Int) -> UInt16 {
        var value: UInt16 = 0
        (self as NSData).getBytes(&value, range: NSRange(location: index, length: MemoryLayout<UInt16>.size))
        return UInt16(littleEndian: value)
    }
    
    mutating func addDate(at index: Int, date: Date, usingUTC: Bool) {
        let calendar: Calendar = usingUTC ? .current : .autoupdatingCurrent
        
        self[index] = UInt8(calendar.component(.year, from: date) & 0xff)
        self[index + 1] = UInt8((calendar.component(.month, from: date) + 1) & 0xff) // Months use zero-based index in Swift
        self[index + 2] = UInt8(calendar.component(.day, from: date) & 0xff)
        self[index + 3] = UInt8(calendar.component(.hour, from: date) & 0xff)
        self[index + 4] = UInt8(calendar.component(.minute, from: date) & 0xff)
        self[index + 5] = UInt8(calendar.component(.second, from: date) & 0xff)
    }
    
    func date(at index: Int) -> Date {
        let year = 2000 + Int(self[startIndex])
        let month = -1 + Int(self[startIndex + 1])
        let day = Int(self[startIndex + 2])
        let hour = Int(self[startIndex + 3])
        let min = Int(self[startIndex + 4])
        let sec = Int(self[startIndex + 5])

        return Calendar.current.date(bySetting: .year, value: year, of: Date()) ?? Date()
    }
}
