import Foundation

public struct CrdtMapItem {
    var timestamp: Double
    var clientId: UInt32
    var data: Any?
}

public class CrdtMapSubMap {
    var parent: CrdtMapSwift
    var prefix: String
    
    init(parent: CrdtMapSwift, prefix: String) {
        self.parent = parent
        self.prefix = prefix
    }

    @discardableResult public func set(_ key: String, _ data: Any?, timestamp: Double? = nil, clientId: UInt32? = nil, emitEvents: Bool = true) -> Bool {
        return parent.set(prefix + key, data, timestamp: timestamp, clientId: clientId)
    }

    public func remove(_ key: String, timestamp: Double? = nil, clientId: UInt32? = nil) {
        parent.remove(prefix + key, timestamp: timestamp, clientId: clientId)
    }

    public func delete(_ key: String, timestamp: Double? = nil, clientId: UInt32? = nil) {
        parent.remove(prefix + key, timestamp: timestamp, clientId: clientId)
    }

    public func has(_ key: String) -> Bool {
        return parent.has(prefix + key)
    }

    public func get(_ key: String) -> Any? {
        return parent.get(prefix + key)
    }

    public func forEach(_ callback: ((Any, String) -> Void)?) {
        parent.forEach { [weak self] data, key in
            if let prefix = self?.prefix, key.starts(with: prefix) {
                callback?(data, String(key.dropFirst(prefix.count)))
            }
        }
    }

    public func entries() -> [(String, Any?)] {
        var results: [(String, Any?)] = []
        
        forEach { data, key in
            results.append((key, data))
        }

        return results
    }

    public func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        forEach { data, key in
            dict[key] = data
        }

        return dict
    }
}

public class CrdtMapSwift {
    public private(set) var clientId: UInt32 = 0
    private var map: [String: CrdtMapItem] = [:]
    private var stateVectors: [UInt32: Double] = [:] // clientId: timestamp ms
    private var observers: [String: [UUID: ([Any]) -> Void]] = [:]
    private var subMaps: [String: CrdtMapSubMap] = [:]

    public init(clientId: UInt32? = nil) {
        self.clientId = clientId ?? UInt32.random(in: 0..<UInt32.max)
    }
    
    // Return id of observer
    @discardableResult public func on(_ name: String, _ callback: (([Any]) -> Void)?, id: UUID) -> UUID {
        if observers[name] == nil {
            observers[name] = [:]
        }
        
        observers[name]?[id] = callback
        
        return id
    }
    @discardableResult public func on(_ name: String, _ callback: (([Any]) -> Void)?) -> UUID {
        return on(name, callback, id: UUID())
    }
    
    // Return id of observer
    @discardableResult public func once(_ name: String, _ callback: (([Any]) -> Void)?) -> UUID {
        let id = UUID()
        on(name, { [weak self] args in
            self?.off(name, id)
            callback?(args)
        }, id: id)
        return id
    }
    
    public func off(_ name: String, _ callbackId: UUID) {
        observers[name]?.removeValue(forKey: callbackId)
        
        if observers[name]?.count == 0 {
            observers.removeValue(forKey: name)
        }
    }
    
    public func emit(_ name: String, _ args: [Any]) {
        if let callbacks = observers[name] {
            for (_, callback) in callbacks {
                callback(args)
            }
        }
    }
    
    public func destroy() {
        emit("destroy", [])
    }
    
    // timestamp = milliseconds
    @discardableResult public func set(_ key: String, _ data: Any?, timestamp: Double? = nil, clientId: UInt32? = nil, emitEvents: Bool = true) -> Bool {
        let existing = map[key]
        let _clientId = clientId ?? self.clientId
        let _timestamp = timestamp ?? Date().timeIntervalSince1970 * 1000

        // Update client state vector
        stateVectors[_clientId] = max(stateVectors[_clientId] ?? 0, _timestamp)

        if existing == nil {
            map[key] = CrdtMapItem(timestamp: _timestamp, clientId: _clientId, data: data)
            if emitEvents {
                //emit("update", [{ [key]: { data, timestamp, clientId } }])
                emit("update", [[key: map[key]]])
            }
            return true
        }

        // Conflict resolution when removing with same timestamp
        if data == nil && _timestamp == existing!.timestamp {
            return false
        }

        // Conflict resolution when adding with same timestamp but different clients
        if _timestamp == existing!.timestamp && _clientId != existing!.clientId {
            if _clientId > existing!.clientId {
                map[key] = CrdtMapItem(timestamp: _timestamp, clientId: _clientId, data: data)
                if emitEvents {
                    emit("update", [[key: map[key]]])
                }
                return true
            }
            return false
        }

        if _timestamp >= existing!.timestamp {
            map[key] = CrdtMapItem(timestamp: _timestamp, clientId: _clientId, data: data)
            if emitEvents {
                emit("update", [[key: map[key]]])
            }
            return true
        }

        return false
    }
    
    public func remove(_ key: String, timestamp: Double? = nil, clientId: UInt32? = nil) {
        set(key, nil, timestamp: timestamp, clientId: clientId)
    }
    
    public func delete(_ key: String, timestamp: Double? = nil, clientId: UInt32? = nil) {
        remove(key, timestamp: timestamp, clientId: clientId)
    }
    
    public func has(_ key: String) -> Bool {
        return get(key) != nil
    }
    
    public func get(_ key: String) -> Any? {
        return map[key]?.data
    }
    
    // Clear old tombstoned data up to timestamp
    // Will also clear old clientId vectors to make up space
    // Warning! This is potentially dangerous, make sure all data has been synced up to this timestamp
    public func clearTo(timestamp: Double) {
        // Clear old removed/tombstoned data
        for (key, item) in map {
            if item.data == nil && item.timestamp < timestamp {
                map.removeValue(forKey: key)
            }
        }

        // Clear old state vectors
        for (key, vector) in stateVectors {
            if vector < timestamp {
                stateVectors.removeValue(forKey: key)
            }
        }
    }
    
    public func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        for (key, item) in map {
            if let data = item.data {
                dict[key] = data
            }
        }

        return dict
    }
    
    public func apply(snapshot: [String: CrdtMapItem]) {
        var appliedSnapshot: [String: CrdtMapItem] = [:]
        for (key, item) in snapshot {
            if set(key, item.data, timestamp: item.timestamp, clientId: item.clientId, emitEvents: false) {
                appliedSnapshot[key] = item
            }
        }
        emit("snapshot", [snapshot, appliedSnapshot])
    }
    
    public func getSnapshotFrom(timestamp: Double) -> [String: CrdtMapItem] {
        var dict: [String: CrdtMapItem] = [:]
        
        for (key, item) in map {
            if item.timestamp >= timestamp {
                dict[key] = item
            }
        }

        return dict
    }
    
    public func getSnapshotFrom(stateVectors: [UInt32: Double]) -> [String: CrdtMapItem] {
        var dict: [String: CrdtMapItem] = [:]
        
        for (key, item) in map {
            let vector = stateVectors[item.clientId]
            if vector == nil || item.timestamp > vector! {
                dict[key] = item
            }
        }

        return dict
    }
    
    public func getStateVectors() -> [UInt32: Double] {
        return stateVectors
    }
    
    public func getMap(_ name: String) -> CrdtMapSubMap {
        if let subMap = subMaps[name] {
            return subMap
        }
        
        let prefix = "\(name):"
        let subMap = CrdtMapSubMap(parent: self, prefix: prefix)
        
        subMaps[name] = subMap

        return subMap
    }
    
    public func forEach(_ callback: ((Any, String) -> Void)?) {
        for (key, item) in map {
            if let data = item.data {
                callback?(data, key)
            }
        }
    }
    
    public static func encode(snapshot: [String: CrdtMapItem]) -> Data {
        var bytes: [UInt8] = []
        
        for (key, item) in snapshot {
            if let data = item.data {
                Encoding.writeUint8(&bytes, 1)
                Encoding.writeVarString(&bytes, key)
                Encoding.writeFloat64(&bytes, item.timestamp)
                Encoding.writeUint32(&bytes, item.clientId)
                Encoding.writeAny(&bytes, data)
            } else {
                Encoding.writeUint8(&bytes, 0)
                Encoding.writeVarString(&bytes, key)
                Encoding.writeFloat64(&bytes, item.timestamp)
                Encoding.writeUint32(&bytes, item.clientId)
            }
        }
        
        return Data(bytes)
    }
    
    public static func decodeSnapshot(_ data: Data) -> [String: CrdtMapItem] {
        var pos: Int = 0
        var snapshot: [String: CrdtMapItem] = [:]
        let bytes: [UInt8] = [UInt8](data)

        while pos < bytes.count {
            let hasData = Decoding.readUint8(bytes, &pos) == 1
            let key = Decoding.readVarString(bytes, &pos)

            let item = CrdtMapItem(
                timestamp: Decoding.readFloat64(bytes, &pos),
                clientId:  Decoding.readUint32(bytes, &pos),
                data: hasData ? Decoding.readAny(bytes, &pos) : nil
            )

            snapshot[key] = item
        }

        return snapshot
    }
    
    public static func encode(stateVectors: [UInt32: Double]) -> Data {
        var bytes: [UInt8] = []
        
        for (key, vector) in stateVectors {
            Encoding.writeUint32(&bytes, key)
            Encoding.writeFloat64(&bytes, vector)
        }

        return Data(bytes)
    }

    public static func decodeStateVectors(_ data: Data) -> [UInt32: Double] {
        var pos: Int = 0
        var stateVectors: [UInt32: Double] = [:]
        let bytes: [UInt8] = [UInt8](data)

        while pos < bytes.count {
            let key = Decoding.readUint32(bytes, &pos)
            let vector = Decoding.readFloat64(bytes, &pos)

            stateVectors[key] = vector
        }

        return stateVectors
    }
}
