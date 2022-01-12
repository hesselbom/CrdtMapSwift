//
//  DataConvertible.swift
//
//  From https://stackoverflow.com/a/38024025/511949
//
//  Created by Viktor Hesselbom on 2022-01-10.
//

import Foundation

protocol DataConvertible {
    init?(data: Data)
    var data: Data { get }
}

extension DataConvertible where Self: ExpressibleByIntegerLiteral{
    init?(data: Data) {
        var value: Self = 0
        guard data.count == MemoryLayout.size(ofValue: value) else { return nil }
        _ = withUnsafeMutableBytes(of: &value, { data.copyBytes(to: $0)} )
        self = value
    }

    var data: Data {
        return withUnsafeBytes(of: self) { Data($0) }
    }
}

extension UInt32 : DataConvertible { }
extension UInt64 : DataConvertible { }
extension Double : DataConvertible { }
