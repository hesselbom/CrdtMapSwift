//
//  Decoding.swift
//  
//
//  Created by Viktor Hesselbom on 2022-01-10.
//

import Foundation

struct Decoding {
    public static func readUint8(_ bytes: [UInt8], _ pos: inout Int) -> UInt8 {
        pos += 1
        return bytes[pos - 1]
    }
    
    public static func readUint32(_ bytes: [UInt8], _ pos: inout Int) -> UInt32 {
        let a = UInt32(bytes[pos])
        let b = UInt32(bytes[pos + 1] << 8)
        let c = UInt32(bytes[pos + 2] << 16)
        let d = UInt32(bytes[pos + 3] << 24)
        let uint = (a + b + c + d) >> 0
        pos += 4
        return uint
    }
    
    public static func readVarUint(_ bytes: [UInt8], _ pos: inout Int) -> UInt64 {
        var num: UInt64 = 0
        var len: UInt64 = 0
        
        while true {
            pos += 1
            
            let r = UInt64(bytes[pos - 1])
            num = num | ((r & Binary.BITS7) << len)
            len += 7
            
            if r < Binary.BIT8 {
                return num >> 0
            }
            
            if len > 35 {
                print("Integer out of range!")
                return 0
            }
        }
    }
    
    public static func readVarInt(_ bytes: [UInt8], _ pos: inout Int) -> Int32 {
        pos += 1
        var r = UInt64(bytes[pos - 1])
        var num = r & Binary.BITS6
        var len = 6
        let sign: Int32 = (r & Binary.BIT7) > 0 ? -1 : 1
        
        if (r & Binary.BIT8) == 0 {
            // don't continue reading
            return sign * Int32(num)
        }
        
        while true {
            pos += 1
            r = UInt64(bytes[pos - 1])
            num = num | ((r & Binary.BITS7) << len)
            len += 7
            if r < Binary.BIT8 {
                return sign * Int32(num >> 0)
            }
            /* istanbul ignore if */
            if len > 41 {
                print("Integer out of range!")
                return 0
            }
        }
    }
    
    public static func readFloat32(_ bytes: [UInt8], _ pos: inout Int) -> Float32 {
        pos += 4
        
        if let roundtrip = UInt32(data: Data(bytes[(pos - 4)..<pos])) {
            return Float32(bitPattern: UInt32(littleEndian: roundtrip))
        }
        
        return 0
    }
    
    public static func readFloat64(_ bytes: [UInt8], _ pos: inout Int) -> Float64 {
        pos += 8
        
        if let roundtrip = UInt64(data: Data(bytes[(pos - 8)..<pos])) {
            return Float64(bitPattern: UInt64(littleEndian: roundtrip))
        }
        
        return 0
    }
    
    public static func readVarString(_ bytes: [UInt8], _ pos: inout Int) -> String {
        let length = Int(readVarUint(bytes, &pos))
        if length == 0 {
            return ""
        } else {
            pos += length
            return String(decoding: bytes[(pos - length)..<pos], as: UTF8.self)
        }
    }
    
    public static func readAny(_ bytes: [UInt8], _ pos: inout Int) -> Any? {
        let index = readUint8(bytes, &pos)
        
        switch index {
        case 119: return readVarString(bytes, &pos)
        case 120: return true
        case 121: return false
        case 123: return readFloat64(bytes, &pos)
        case 124: return readFloat32(bytes, &pos)
        case 125: return readVarInt(bytes, &pos)
        default: return nil
        }
    }
}
