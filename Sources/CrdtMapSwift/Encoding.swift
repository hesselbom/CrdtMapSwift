//
//  Encoding.swift
//
//  Encodes numbers in little-endian order (least to most significant byte order)  
//
//  Created by Viktor Hesselbom on 2022-01-10.
//

import Foundation

public struct Encoding {
    public static func writeUint8(_ bytes: inout [UInt8], _ byte: UInt8) {
        bytes.append(byte)
    }
    
    public static func writeVarUint(_ bytes: inout [UInt8], _ num: UInt64) {
        var _num = num
        while _num > Binary.BITS7 {
            writeUint8(&bytes, UInt8(Binary.BIT8 | (Binary.BITS7 & _num)))
            
            // From https://stackoverflow.com/a/41202172/511949
            //_num = _num >>> 7
            _num = _num >> 7
        }
        writeUint8(&bytes, UInt8(Binary.BITS7 & _num))
    }
    
    public static func writeVarInt(_ bytes: inout [UInt8], _ num: Int32) {
        var _num = num
        
        let isNegative = num != 0 ? num < 0 : 1 / num < 0
        if isNegative {
            _num = -_num
        }
        
        //             |- whether to continue reading         |- whether is negative     |- number
        writeUint8(&bytes, UInt8((_num > Binary.BITS6 ? Binary.BIT8 : 0) | (isNegative ? Binary.BIT7 : 0) | (Binary.BITS6 & UInt64(_num))))
        _num = _num >> 6
        // We don't need to consider the case of num === 0 so we can use a different
        // pattern here than above.
        while _num > 0 {
            writeUint8(&bytes, UInt8((_num > Binary.BITS7 ? Binary.BIT8 : 0) | (Binary.BITS7 & UInt64(_num))))
            _num = _num >> 7
        }
    }
    
    public static func writeVarString(_ bytes: inout [UInt8], _ string: String) {
        //const encodedString = unescape(encodeURIComponent(str))
        let strBytes: [UInt8] = .init(string.utf8)
        writeVarUint(&bytes, UInt64(strBytes.count))
        bytes.append(contentsOf: strBytes)
    }
    
    //export const writeUint8Array = (encoder, uint8Array) => {
    public static func writeUint8Array(_ bytes: inout [UInt8], _ uint8Array: [UInt8]) {
        bytes.append(contentsOf: uint8Array)
    }
    
    public static func writeVarUint8Array(_ bytes: inout [UInt8], _ uint8Array: [UInt8]) {
        writeVarUint(&bytes, UInt64(uint8Array.count))
        writeUint8Array(&bytes, uint8Array)
      }
    
    public static func writeFloat32(_ bytes: inout [UInt8], _ num: Float32) {
        let data: [UInt8] = withUnsafeBytes(of: num.bitPattern.littleEndian, Array.init)
        bytes.append(contentsOf: data)
    }
    
    public static func writeFloat64(_ bytes: inout [UInt8], _ num: Float64) {
        // From https://stackoverflow.com/a/56955969/511949, https://stackoverflow.com/a/38024025/511949
        //num.bitPattern.littleEndian.data
        let data: [UInt8] = withUnsafeBytes(of: num.bitPattern.littleEndian, Array.init)
        bytes.append(contentsOf: data)
    }
    
    public static func writeUint32(_ bytes: inout [UInt8], _ num: UInt32) {
        var _num: UInt64 = UInt64(num)
        for _ in 0..<4 {
            writeUint8(&bytes, UInt8(_num & Binary.BITS8))
            _num = _num >> 8
        }
    }
    
    public static func writeAny(_ bytes: inout [UInt8], _ data: Any) {
        if let data = data as? Int32 {
            // TYPE 125: INTEGER
            writeVarUint(&bytes, 125)
            writeVarInt(&bytes, data)
        } else if let data = data as? Float32 {
            // TYPE 124: FLOAT32
            writeVarUint(&bytes, 124)
            writeFloat32(&bytes, data)
        } else if let data = data as? Float64 {
            // TYPE 123: FLOAT64
            writeVarUint(&bytes, 123)
            writeFloat64(&bytes, data)
        } else if let data = data as? String {
            // TYPE 119: STRING
            writeVarUint(&bytes, 119)
            writeVarString(&bytes, data)
        } else if let data = data as? Bool {
            // TYPE 120/121: boolean (true/false)
            writeVarUint(&bytes, data ? 120 : 121)
        } else {
            // TYPE 127: undefined
            writeVarUint(&bytes, 127)
        }
    }
}
