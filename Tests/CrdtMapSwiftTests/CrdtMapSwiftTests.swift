import XCTest
@testable import CrdtMapSwift

final class CrdtMapSwiftTests: XCTestCase {
    func testSetKeys() throws {
        let doc = CrdtMapSwift()

        doc.set("key1", "data", timestamp: 1000)
        doc.set("key2", "data", timestamp: 1000)
        
        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["key1"] as? String, "data")
        XCTAssertEqual(dict["key2"] as? String, "data")
    }
    
    func testVerifyThatClientIdIsAUint() throws {
        XCTAssertGreaterThanOrEqual(CrdtMapSwift().clientId, 0)
        XCTAssertEqual(CrdtMapSwift(clientId: 10).clientId, 10)
    }
    
    func testUsesLatestTimestampedKeys() throws {
        let doc = CrdtMapSwift()

        doc.set("key3", "later-data-before", timestamp: 2000)

        doc.set("key1", "data", timestamp: 1000)
        doc.set("key2", "data", timestamp: 1000)
        doc.set("key3", "data", timestamp: 1000)
        doc.set("key4", nil, timestamp: 1000)

        doc.set("key1", "later-data", timestamp: 2000)
        doc.set("key2", "older-data", timestamp: 0)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 3)
        XCTAssertEqual(dict["key1"] as? String, "later-data")
        XCTAssertEqual(dict["key2"] as? String, "data")
        XCTAssertEqual(dict["key3"] as? String, "later-data-before")
    }

    func testRemoveKey() throws {
        let doc = CrdtMapSwift()

        doc.set("key", "data", timestamp: 1000)
        doc.remove("key", timestamp: 1001)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 0)
    }

    func testGetKeyValue() throws {
        let doc = CrdtMapSwift()
        
        XCTAssertNil(doc.get("key"))

        doc.set("key", "data", timestamp: 1000)
        XCTAssertEqual(doc.get("key") as? String, "data")
        doc.remove("key", timestamp: 1001)
        XCTAssertNil(doc.get("key"))

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 0)
    }

    func testTestIfKeyIsAvailable() throws {
        let doc = CrdtMapSwift()
        
        XCTAssertFalse(doc.has("key"))
        doc.set("key", "data", timestamp: 1000)
        XCTAssertTrue(doc.has("key"))
        doc.remove("key", timestamp: 1001)
        XCTAssertFalse(doc.has("key"))
    }

    func testSettingNullIsTheSameAsRemoving() throws {
        let doc = CrdtMapSwift()
        doc.set("key", "data", timestamp: 1000)
        doc.set("key", nil, timestamp: 1001)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 0)
    }

    func testKeepItemInsteadOfRemovingIfSameTimestamp() throws {
        let doc = CrdtMapSwift()
        doc.set("key", "data", timestamp: 1000)
        doc.remove("key", timestamp: 1000)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict["key"] as? String, "data")
    }

    func testIfSameTimestampAndSameClientIdJustUsesLatestEdgeCase() throws {
        let doc = CrdtMapSwift()
        doc.set("key", "data", timestamp: 1000)
        doc.set("key", "data2", timestamp: 1000)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict["key"] as? String, "data2")
    }

    func testIfSameTimestampAndDifferentClientIdsSortOnClientId() throws {
        let doc = CrdtMapSwift()
        doc.set("key", "data", timestamp: 1000, clientId: 1)
        doc.set("key", "data2", timestamp: 1000, clientId: 3)
        doc.set("key", "data3", timestamp: 1000, clientId: 2)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict["key"] as? String, "data2")
    }

    func testUsesLatestTimestampedKeysEvenWhenRemoved() throws {
        let doc = CrdtMapSwift()

        doc.set("key", "data", timestamp: 2000)
        doc.remove("key", timestamp: 1000)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict["key"] as? String, "data")
    }

    func testRemoveIfRemovedTimestampIsLaterEvenIfReceivedBefore() throws {
        let doc = CrdtMapSwift()

        doc.remove("key", timestamp: 2000)
        doc.set("key", "data", timestamp: 1000)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 0)
    }

    func testIfTimestampIsMissingUseDateNow() throws {
        let doc = CrdtMapSwift(clientId: 1)
        let then = Date().timeIntervalSince1970 * 1000

        doc.set("key", "data")

        // Test if timestamp is later than the first Date.now() we got
        XCTAssertGreaterThanOrEqual(doc.getSnapshotFrom(timestamp: 0)["key"]!.timestamp, then)
    }

    func testGetDiffSnapshotAfterSpecificTimestamp() throws {
        let doc = CrdtMapSwift(clientId: 1)

        doc.set("key", "data", timestamp: 1000)
        doc.set("key2", "data", timestamp: 1500)
        doc.remove("key", timestamp: 2000)
        
        let snapshot = doc.getSnapshotFrom(timestamp: 1500)
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot["key2"]!.timestamp, 1500)
        XCTAssertEqual(snapshot["key2"]!.clientId, 1)
        XCTAssertEqual(snapshot["key2"]!.data as? String, "data")
        XCTAssertEqual(snapshot["key"]!.timestamp, 2000)
        XCTAssertEqual(snapshot["key"]!.clientId, 1)
        XCTAssertNil(snapshot["key"]!.data)
    }

    func testGetDiffSnapshotAfterSpecificTimestampMakingSureDeletesAreNotIncludedIfOld() throws {
        let doc = CrdtMapSwift(clientId: 1)

        doc.set("key", "data", timestamp: 1000)
        doc.set("key2", "data", timestamp: 1500)
        doc.remove("key", timestamp: 1400)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict["key2"] as? String, "data")
        
        let snapshot = doc.getSnapshotFrom(timestamp: 1500)
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(snapshot["key2"]!.timestamp, 1500)
        XCTAssertEqual(snapshot["key2"]!.clientId, 1)
        XCTAssertEqual(snapshot["key2"]!.data as? String, "data")
    }

    func testGetDiffSnapshotEncodedAsUint8AfterSpecificTimestampAndDecode() throws {
        let doc = CrdtMapSwift(clientId: 1)

        doc.set("key", "data", timestamp: 1000)
        doc.set("key2", "data", timestamp: 1635257645564)
        doc.remove("key", timestamp: 2000)

        let resultSnapshot = doc.getSnapshotFrom(timestamp: 1500)
        let byteArray = CrdtMapSwift.encode(snapshot: doc.getSnapshotFrom(timestamp: 1500))
        let decodedSnapshot = CrdtMapSwift.decodeSnapshot(byteArray)

        // Verify that both snapshot and decoded snapshot are the same
        XCTAssertEqual(resultSnapshot.count, 2)
        XCTAssertEqual(resultSnapshot["key2"]!.timestamp, 1635257645564)
        XCTAssertEqual(resultSnapshot["key2"]!.clientId, 1)
        XCTAssertEqual(resultSnapshot["key2"]!.data as? String, "data")
        XCTAssertEqual(resultSnapshot["key"]!.timestamp, 2000)
        XCTAssertEqual(resultSnapshot["key"]!.clientId, 1)
        XCTAssertNil(resultSnapshot["key"]!.data)
        
        XCTAssertEqual(decodedSnapshot.count, 2)
        XCTAssertEqual(decodedSnapshot["key2"]!.timestamp, 1635257645564)
        XCTAssertEqual(decodedSnapshot["key2"]!.clientId, 1)
        XCTAssertEqual(decodedSnapshot["key2"]!.data as? String, "data")
        XCTAssertEqual(decodedSnapshot["key"]!.timestamp, 2000)
        XCTAssertEqual(decodedSnapshot["key"]!.clientId, 1)
        XCTAssertNil(decodedSnapshot["key"]!.data)
    }

    func testHandleEncodeDecodeOfVariousTypes() throws {
        let doc = CrdtMapSwift(clientId: 1)

        doc.set("string", "data", timestamp: 1000)
        doc.set("double", Double(10), timestamp: 1000)
        doc.set("float32", Float32(10), timestamp: 1000)
        doc.set("integer", Int32(10), timestamp: 1000)
        /*doc.set("uint64", UInt64(10), timestamp: 1000)
        doc.set("int64", Int64(10), timestamp: 1000)*/
        doc.set("boolean", true, timestamp: 1000)
        //doc.set("object", { foo: "bar" }, timestamp: 1000)

        let resultSnapshot = doc.getSnapshotFrom(timestamp: 0)
        let byteArray = CrdtMapSwift.encode(snapshot: doc.getSnapshotFrom(timestamp: 0))
        let decodedSnapshot = CrdtMapSwift.decodeSnapshot(byteArray)

        // Verify that both snapshot and decoded snapshot are the same
        XCTAssertEqual(resultSnapshot.count, 5)
        XCTAssertEqual(resultSnapshot["string"]!.timestamp, 1000)
        XCTAssertEqual(resultSnapshot["string"]!.clientId, 1)
        XCTAssertEqual(resultSnapshot["string"]!.data as? String, "data")
        XCTAssertEqual(resultSnapshot["double"]!.data as? Double, 10)
        XCTAssertEqual(resultSnapshot["float32"]!.data as? Float32, 10)
        XCTAssertEqual(resultSnapshot["integer"]!.data as? Int32, 10)
        /*XCTAssertEqual(resultSnapshot["float32"]!.data as? Float32, 10)
        XCTAssertEqual(resultSnapshot["uint64"]!.data as? UInt64, 10)
        XCTAssertEqual(resultSnapshot["int64"]!.data as? Int64, 10)*/
        XCTAssertEqual(resultSnapshot["boolean"]!.data as? Bool, true)
        
        XCTAssertEqual(decodedSnapshot.count, 5)
        XCTAssertEqual(decodedSnapshot["string"]!.timestamp, 1000)
        XCTAssertEqual(decodedSnapshot["string"]!.clientId, 1)
        XCTAssertEqual(decodedSnapshot["string"]!.data as? String, "data")
        XCTAssertEqual(decodedSnapshot["double"]!.data as? Double, 10)
        XCTAssertEqual(decodedSnapshot["float32"]!.data as? Float32, 10)
        XCTAssertEqual(decodedSnapshot["integer"]!.data as? Int32, 10)
        /*XCTAssertEqual(decodedSnapshot["float32"]!.data as? Float32, 10)
        XCTAssertEqual(decodedSnapshot["uint64"]!.data as? UInt64, 10)
        XCTAssertEqual(decodedSnapshot["int64"]!.data as? Int64, 10)*/
        XCTAssertEqual(decodedSnapshot["boolean"]!.data as? Bool, true)
        //object: { timestamp: 1000, data: { foo: "bar" }, clientId: 1 }
    }

    func testClearAllTombstonesFromTimestampToCleanUp() throws {
        let doc = CrdtMapSwift(clientId: 1)

        doc.set("key1", "data", timestamp: 1000) // will stay even if older, because it contains data
        doc.set("keyToBeRemoved", "data", timestamp: 1000) // will stay
        doc.set("key2", "data", timestamp: 1500) // will stay
        doc.remove("keyToBeRemoved", timestamp: 1400) // will be deleted
        
        var snapshot = doc.getSnapshotFrom(timestamp: 0)
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot["key1"]!.timestamp, 1000)
        XCTAssertEqual(snapshot["key1"]!.clientId, 1)
        XCTAssertEqual(snapshot["key1"]!.data as? String, "data")
        
        XCTAssertEqual(snapshot["key2"]!.timestamp, 1500)
        XCTAssertEqual(snapshot["key2"]!.clientId, 1)
        XCTAssertEqual(snapshot["key2"]!.data as? String, "data")
        
        XCTAssertEqual(snapshot["keyToBeRemoved"]!.timestamp, 1400)
        XCTAssertEqual(snapshot["keyToBeRemoved"]!.clientId, 1)
        XCTAssertNil(snapshot["keyToBeRemoved"]!.data)

        doc.clearTo(timestamp: 1499) // everything deleted before this is removed

        // Both will be added even if after cleared timestamp due to clear only affecting removed keys
        doc.set("key3", "data", timestamp: 1000)
        doc.set("key4", "data", timestamp: 1499)

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 4)
        XCTAssertEqual(dict["key1"] as? String, "data")
        XCTAssertEqual(dict["key2"] as? String, "data")
        XCTAssertEqual(dict["key3"] as? String, "data")
        XCTAssertEqual(dict["key4"] as? String, "data")
        
        snapshot = doc.getSnapshotFrom(timestamp: 0)
        XCTAssertEqual(snapshot.count, 4)
        XCTAssertEqual(snapshot["key1"]!.timestamp, 1000)
        XCTAssertEqual(snapshot["key1"]!.clientId, 1)
        XCTAssertEqual(snapshot["key1"]!.data as? String, "data")
        
        XCTAssertEqual(snapshot["key2"]!.timestamp, 1500)
        XCTAssertEqual(snapshot["key2"]!.clientId, 1)
        XCTAssertEqual(snapshot["key2"]!.data as? String, "data")
        
        XCTAssertEqual(snapshot["key3"]!.timestamp, 1000)
        XCTAssertEqual(snapshot["key3"]!.clientId, 1)
        XCTAssertEqual(snapshot["key3"]!.data as? String, "data")
        
        XCTAssertEqual(snapshot["key4"]!.timestamp, 1499)
        XCTAssertEqual(snapshot["key4"]!.clientId, 1)
        XCTAssertEqual(snapshot["key4"]!.data as? String, "data")
    }

    func testMergeSnapshotToDocument() throws {
        let docA = CrdtMapSwift()
        docA.set("key1", "dataA", timestamp: 1000)
        docA.set("key2", "dataA", timestamp: 1500)

        let docB = CrdtMapSwift()
        docB.set("key1", "dataB", timestamp: 1001)
        docB.set("key2", "dataB", timestamp: 1499)

        docA.apply(snapshot: docB.getSnapshotFrom(timestamp: 0))

        let dict = docA.toDict()
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["key1"] as? String, "dataB")
        XCTAssertEqual(dict["key2"] as? String, "dataA")
    }

    func testMergeSnapshotToDocumentWithClearedToTimestamp() throws {
        let docA = CrdtMapSwift(clientId: 1)
        docA.set("key1", "dataA", timestamp: 1000)
        docA.set("key2", "dataA", timestamp: 1500)
        docA.remove("key3", timestamp: 1400)
        docA.remove("key4", timestamp: 1500)
        docA.clearTo(timestamp: 1498)

        let docB = CrdtMapSwift(clientId: 2)
        docB.set("key1", "dataB", timestamp: 1001)
        docB.set("key2", "dataB", timestamp: 1499)

        docA.apply(snapshot: docB.getSnapshotFrom(timestamp: 0))

        let dict = docA.toDict()
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["key1"] as? String, "dataB")
        XCTAssertEqual(dict["key2"] as? String, "dataA")
        
        let snapshot = docA.getSnapshotFrom(timestamp: 0)
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot["key1"]!.timestamp, 1001)
        XCTAssertEqual(snapshot["key1"]!.clientId, 2)
        XCTAssertEqual(snapshot["key1"]!.data as? String, "dataB")
        
        XCTAssertEqual(snapshot["key2"]!.timestamp, 1500)
        XCTAssertEqual(snapshot["key2"]!.clientId, 1)
        XCTAssertEqual(snapshot["key2"]!.data as? String, "dataA")
        
        XCTAssertEqual(snapshot["key4"]!.timestamp, 1500)
        XCTAssertEqual(snapshot["key4"]!.clientId, 1)
        XCTAssertNil(snapshot["key4"]!.data)
    }

    // State vectors are latest stored timestamp from each clientId
    func testStateVectorsGetStateVectors() throws {
        let doc = CrdtMapSwift()

        // Empty before any data
        var stateVectors = doc.getStateVectors()
        XCTAssertEqual(stateVectors.count, 0)

        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.set("key2", "dataA", timestamp: 1500, clientId: 1)

        // Same key but earlier timestamp, should still be remembered
        doc.set("key2", "dataB", timestamp: 1400, clientId: 2)

        // Verify snapshot is only client 1
        let snapshot = doc.getSnapshotFrom(timestamp: 0)
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot["key1"]!.timestamp, 1000)
        XCTAssertEqual(snapshot["key1"]!.clientId, 1)
        XCTAssertEqual(snapshot["key1"]!.data as? String, "dataA")
        
        XCTAssertEqual(snapshot["key2"]!.timestamp, 1500)
        XCTAssertEqual(snapshot["key2"]!.clientId, 1)
        XCTAssertEqual(snapshot["key2"]!.data as? String, "dataA")

        // Get state vectors
        stateVectors = doc.getStateVectors()
        XCTAssertEqual(stateVectors.count, 2)
        XCTAssertEqual(stateVectors[1], 1500)
        XCTAssertEqual(stateVectors[2], 1400)
    }

    func testStateVectorsRemoveOldStateVectorsWithClearToTimestamp() throws {
        let doc = CrdtMapSwift()

        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.set("key1", "dataB", timestamp: 1400, clientId: 2)

        // Get state vectors
        var stateVectors = doc.getStateVectors()
        XCTAssertEqual(stateVectors.count, 2)
        XCTAssertEqual(stateVectors[1], 1000)
        XCTAssertEqual(stateVectors[2], 1400)

        // Clear
        doc.clearTo(timestamp: 1300)

        // Get state vectors with cleared
        stateVectors = doc.getStateVectors()
        XCTAssertEqual(stateVectors.count, 1)
        XCTAssertEqual(stateVectors[2], 1400)

        // When adding new key with old timestamp, will be added to state vectors even if previously cleared
        // Clear is just a one time action to clean up
        doc.set("key1", "dataA", timestamp: 1100, clientId: 1)
        stateVectors = doc.getStateVectors()
        XCTAssertEqual(stateVectors.count, 2)
        XCTAssertEqual(stateVectors[1], 1100)
        XCTAssertEqual(stateVectors[2], 1400)
    }

    func testStateVectorsEncodeDecodeStateVectors() throws {
        let doc = CrdtMapSwift()

        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.set("key1", "dataB", timestamp: 1400, clientId: 2)

        let resultStateVectors = doc.getStateVectors()
        let byteArray = CrdtMapSwift.encode(stateVectors: doc.getStateVectors())
        let decodedStateVectors = CrdtMapSwift.decodeStateVectors(byteArray)

        // Verify that both state vectors and decoded state vectors are the same
        XCTAssertEqual(resultStateVectors.count, 2)
        XCTAssertEqual(resultStateVectors[1], 1000)
        XCTAssertEqual(resultStateVectors[2], 1400)
        
        XCTAssertEqual(decodedStateVectors.count, 2)
        XCTAssertEqual(decodedStateVectors[1], 1000)
        XCTAssertEqual(decodedStateVectors[2], 1400)
    }

    func testStateVectorsGetSnapshotFromStateVectors() throws {
        let doc = CrdtMapSwift()

        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.set("key1", "dataB", timestamp: 1400, clientId: 2)
        doc.set("key1", "dataA", timestamp: 1300, clientId: 1)
        doc.set("key2", "dataA", timestamp: 1300, clientId: 1)
        doc.set("key3", "dataA", timestamp: 1200, clientId: 1)

        // Get from both client 1 and client 2
        var snapshot = doc.getSnapshotFrom(stateVectors: [1: 0, 2: 0])
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot["key1"]!.timestamp, 1400)
        XCTAssertEqual(snapshot["key1"]!.clientId, 2)
        XCTAssertEqual(snapshot["key1"]!.data as? String, "dataB")
        
        XCTAssertEqual(snapshot["key2"]!.timestamp, 1300)
        XCTAssertEqual(snapshot["key2"]!.clientId, 1)
        XCTAssertEqual(snapshot["key2"]!.data as? String, "dataA")
        
        XCTAssertEqual(snapshot["key3"]!.timestamp, 1200)
        XCTAssertEqual(snapshot["key3"]!.clientId, 1)
        XCTAssertEqual(snapshot["key3"]!.data as? String, "dataA")

        // Get only from client 2 because we have latest from client 1
        snapshot = doc.getSnapshotFrom(stateVectors: [1: 1500, 2: 0])
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(snapshot["key1"]!.timestamp, 1400)
        XCTAssertEqual(snapshot["key1"]!.clientId, 2)
        XCTAssertEqual(snapshot["key1"]!.data as? String, "dataB")

        // Get missing from client 1 (those after our latest vector, i.e. 1200)
        snapshot = doc.getSnapshotFrom(stateVectors: [1: 1200, 2: 1500])
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(snapshot["key2"]!.timestamp, 1300)
        XCTAssertEqual(snapshot["key2"]!.clientId, 1)
        XCTAssertEqual(snapshot["key2"]!.data as? String, "dataA")

        // Get all because we're missing all state vectors
        snapshot = doc.getSnapshotFrom(stateVectors: [:])
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot["key1"]!.timestamp, 1400)
        XCTAssertEqual(snapshot["key1"]!.clientId, 2)
        XCTAssertEqual(snapshot["key1"]!.data as? String, "dataB")
        
        XCTAssertEqual(snapshot["key2"]!.timestamp, 1300)
        XCTAssertEqual(snapshot["key2"]!.clientId, 1)
        XCTAssertEqual(snapshot["key2"]!.data as? String, "dataA")
        
        XCTAssertEqual(snapshot["key3"]!.timestamp, 1200)
        XCTAssertEqual(snapshot["key3"]!.clientId, 1)
        XCTAssertEqual(snapshot["key3"]!.data as? String, "dataA")
    }

    func testEventsWorks() throws {
        let doc = CrdtMapSwift()
        var onUpdateCallbacks: [[Any]] = []
        var onSnapshotCallbacks: [[Any]] = []
        var onDestroyCallbacks: [[Any]] = []
        let onUpdate: (([Any]) -> Void) = { args in onUpdateCallbacks.append(args) }
        let onSnapshot: (([Any]) -> Void) = { args in onSnapshotCallbacks.append(args) }
        let onDestroy: (([Any]) -> Void) = { args in onDestroyCallbacks.append(args) }

        // Events after .on()
        let onUpdateId = doc.on("update", onUpdate)
        let onSnapshotId = doc.on("snapshot", onSnapshot)
        doc.on("destroy", onDestroy)

        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.remove("key1", timestamp: 1100, clientId: 2)
        doc.clearTo(timestamp: 0)
        doc.apply(snapshot: [
            "key2": CrdtMapItem(timestamp: 1500, clientId: 2, data: "dataB")
        ])

        // No events after .off()
        doc.off("update", onUpdateId)
        doc.off("snapshot", onSnapshotId)

        // No events emitted for these
        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.remove("key1", timestamp: 1100, clientId: 2)
        doc.clearTo(timestamp: 0)
        doc.apply(snapshot: [
            "key2": CrdtMapItem(timestamp: 1500, clientId: 2, data: "dataB")
        ])

        // Event listener should"ve been called 2 times
        /*expect(onUpdate.mock.calls).toEqual([
            [{ key1: { timestamp: 1000, data: "dataA", clientId: 1 } }],
            [{ key1: { timestamp: 1100, data: nil, clientId: 2 } }]
        ])*/
        XCTAssertEqual(onUpdateCallbacks.count, 2)
        XCTAssertEqual((onUpdateCallbacks[0][0] as? [String: CrdtMapItem])?["key1"]?.timestamp, 1000)
        XCTAssertEqual((onUpdateCallbacks[0][0] as? [String: CrdtMapItem])?["key1"]?.clientId, 1)
        XCTAssertEqual((onUpdateCallbacks[0][0] as? [String: CrdtMapItem])?["key1"]?.data as? String, "dataA")
        XCTAssertEqual((onUpdateCallbacks[1][0] as? [String: CrdtMapItem])?["key1"]?.timestamp, 1100)
        XCTAssertEqual((onUpdateCallbacks[1][0] as? [String: CrdtMapItem])?["key1"]?.clientId, 2)
        XCTAssertTrue((onUpdateCallbacks[1][0] as? [String: CrdtMapItem])?["key1"]?.data == nil)

        // Snapshot should only call snapshot event, not multiple "set"s
        /*expect(onSnapshot.mock.calls).toEqual([
            [
                { key2: { timestamp: 1500, data: "dataB", clientId: 2 } },
                { key2: { timestamp: 1500, data: "dataB", clientId: 2 } }
            ]
        ])*/
        XCTAssertEqual(onSnapshotCallbacks.count, 1)
        // Snapshot
        XCTAssertEqual((onSnapshotCallbacks[0][0] as? [String: CrdtMapItem])?["key2"]?.timestamp, 1500)
        XCTAssertEqual((onSnapshotCallbacks[0][0] as? [String: CrdtMapItem])?["key2"]?.clientId, 2)
        XCTAssertEqual((onSnapshotCallbacks[0][0] as? [String: CrdtMapItem])?["key2"]?.data as? String, "dataB")
        // Applied snaphot
        XCTAssertEqual((onSnapshotCallbacks[0][1] as? [String: CrdtMapItem])?["key2"]?.timestamp, 1500)
        XCTAssertEqual((onSnapshotCallbacks[0][1] as? [String: CrdtMapItem])?["key2"]?.clientId, 2)
        XCTAssertEqual((onSnapshotCallbacks[0][1] as? [String: CrdtMapItem])?["key2"]?.data as? String, "dataB")

        //expect(onDestroy.mock.calls).toEqual([])
        XCTAssertEqual(onDestroyCallbacks.count, 0)
        doc.destroy()
        //expect(onDestroy.mock.calls).toEqual([[]])
        XCTAssertEqual(onDestroyCallbacks.count, 1)
        XCTAssertEqual(onDestroyCallbacks[0].count, 0)
    }

    func testEventsSnapshotsShouldIncludeBothFullSnapshotAndUpdatedValues() throws {
        let doc = CrdtMapSwift()
        var onSnapshotCallbacks: [[Any]] = []
        let onSnapshot: (([Any]) -> Void) = { args in onSnapshotCallbacks.append(args) }

        // Events after .on()
        let onSnapshotId = doc.on("snapshot", onSnapshot)

        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.set("key2", "dataA", timestamp: 1500, clientId: 1)
        doc.apply(snapshot: [
            "key1": CrdtMapItem(timestamp: 1500, clientId: 2, data: "dataB"),
            "key2": CrdtMapItem(timestamp: 1400, clientId: 2, data: "dataB")
        ])

        // No events after .off()
        doc.off("snapshot", onSnapshotId)
        
        XCTAssertEqual(onSnapshotCallbacks.count, 1)
        
        // First parameter includes full snapshot
        XCTAssertEqual((onSnapshotCallbacks[0][0] as? [String: CrdtMapItem])?["key1"]?.timestamp, 1500)
        XCTAssertEqual((onSnapshotCallbacks[0][0] as? [String: CrdtMapItem])?["key1"]?.clientId, 2)
        XCTAssertEqual((onSnapshotCallbacks[0][0] as? [String: CrdtMapItem])?["key1"]?.data as? String, "dataB")
        XCTAssertEqual((onSnapshotCallbacks[0][0] as? [String: CrdtMapItem])?["key2"]?.timestamp, 1400)
        XCTAssertEqual((onSnapshotCallbacks[0][0] as? [String: CrdtMapItem])?["key2"]?.clientId, 2)
        XCTAssertEqual((onSnapshotCallbacks[0][0] as? [String: CrdtMapItem])?["key2"]?.data as? String, "dataB")
        
        // Second parameter includes applied snapshot
        XCTAssertEqual((onSnapshotCallbacks[0][1] as? [String: CrdtMapItem])?["key1"]?.timestamp, 1500)
        XCTAssertEqual((onSnapshotCallbacks[0][1] as? [String: CrdtMapItem])?["key1"]?.clientId, 2)
        XCTAssertEqual((onSnapshotCallbacks[0][1] as? [String: CrdtMapItem])?["key1"]?.data as? String, "dataB")
        // key2 is not applied due to it having earlier timestamp to existing key2 (1400 < 1500)
    }

    func testEventsOnceShouldOnlyBeTriggeredOnce() throws {
        let doc = CrdtMapSwift()
        var onUpdateCallbacks: [[Any]] = []
        var onUpdateMultipleCallbacks: [[Any]] = []
        let onUpdate: (([Any]) -> Void) = { args in onUpdateCallbacks.append(args) }
        let onUpdateMultiple: (([Any]) -> Void) = { args in onUpdateMultipleCallbacks.append(args) }

        // Events after .on()
        doc.once("update", onUpdate)
        doc.on("update", onUpdateMultiple)

        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        doc.set("key1", "dataA", timestamp: 1000, clientId: 1)
        
        XCTAssertEqual(onUpdateCallbacks.count, 1)
        // Verify that regular onUpdate is called for each one
        XCTAssertEqual(onUpdateMultipleCallbacks.count, 4)
    }

    func testSubDocsStoresSubdocKeysWithPrefix() throws {
        let doc = CrdtMapSwift()
        let subMap1 = doc.getMap("sub1")
        let subMap2 = doc.getMap("sub2")

        XCTAssertFalse(subMap1.has("key2"))

        doc.set("key1", "data1")
        subMap1.set("key2", "data2")
        subMap2.set("key3", "data3")

        let dict = doc.toDict()
        XCTAssertEqual(dict.count, 3)
        XCTAssertEqual(dict["key1"] as? String, "data1")
        XCTAssertEqual(dict["sub1:key2"] as? String, "data2")
        XCTAssertEqual(dict["sub2:key3"] as? String, "data3")

        XCTAssertEqual(subMap1.get("key2") as? String, "data2")
        XCTAssertTrue(subMap1.has("key2"))
    }

    func testSubDocsDeleteKey() throws {
        let doc = CrdtMapSwift()
        let subMap1 = doc.getMap("sub1")
        let subMap2 = doc.getMap("sub2")

        doc.set("key1", "data1", timestamp: 1000)
        subMap1.set("key2", "data2", timestamp: 1000)
        subMap2.set("key3", "data3", timestamp: 1000)

        var dict = doc.toDict()
        XCTAssertEqual(dict.count, 3)
        XCTAssertEqual(dict["key1"] as? String, "data1")
        XCTAssertEqual(dict["sub1:key2"] as? String, "data2")
        XCTAssertEqual(dict["sub2:key3"] as? String, "data3")

        XCTAssertEqual(subMap1.get("key2") as? String, "data2")
        subMap1.delete("key2", timestamp: 1001)
        XCTAssertNil(subMap1.get("key2"))

        dict = doc.toDict()
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["key1"] as? String, "data1")
        XCTAssertEqual(dict["sub2:key3"] as? String, "data3")
    }

    func testSubDocsLoopSubdocKeysWithForEach() throws {
        let doc = CrdtMapSwift()
        let subMap1 = doc.getMap("sub1")
        let subMap2 = doc.getMap("sub2")

        doc.set("key1", "data1")
        subMap1.set("key2", "data2")
        subMap2.set("key3", "data3")
        subMap1.set("key2-2", "data2-2")
        subMap1.set("removed-key", "data", timestamp: 1000)
        subMap1.delete("removed-key", timestamp: 1001)
        
        var loopSub1Callbacks: [(Any, String)] = []
        var loopSub2Callbacks: [(Any, String)] = []
        let loopSub1: ((Any, String) -> Void) = { data, key in loopSub1Callbacks.append((data, key)) }
        let loopSub2: ((Any, String) -> Void) = { data, key in loopSub2Callbacks.append((data, key)) }

        subMap1.forEach(loopSub1)
        subMap2.forEach(loopSub2)
        
        // Sort callbacks to pass test because order of forEach is random
        loopSub1Callbacks.sort { a, b in b.1 > a.1 }
        
        XCTAssertEqual(loopSub1Callbacks.count, 2)
        XCTAssertEqual(loopSub1Callbacks[0].0 as? String, "data2")
        XCTAssertEqual(loopSub1Callbacks[0].1, "key2")
        XCTAssertEqual(loopSub1Callbacks[1].0 as? String, "data2-2")
        XCTAssertEqual(loopSub1Callbacks[1].1, "key2-2")
        
        XCTAssertEqual(loopSub2Callbacks.count, 1)
        XCTAssertEqual(loopSub2Callbacks[0].0 as? String, "data3")
        XCTAssertEqual(loopSub2Callbacks[0].1, "key3")
    }

    func testSubDocsGetSubdocKeysAsEntriesArray() throws {
        let doc = CrdtMapSwift()
        let subMap1 = doc.getMap("sub1")
        let subMap2 = doc.getMap("sub2")

        doc.set("key1", "data1")
        subMap1.set("key2", "data2")
        subMap2.set("key3", "data3")
        subMap1.set("key2-2", "data2-2")
        subMap1.set("removed-key", "data", timestamp: 1000)
        subMap1.delete("removed-key", timestamp: 1001)
        
        var entries = subMap1.entries()
        
        // Sort entries to pass test because order of entries is random
        entries.sort { a, b in b.0 > a.0 }
        
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].0, "key2")
        XCTAssertEqual(entries[0].1 as? String, "data2")
        XCTAssertEqual(entries[1].0, "key2-2")
        XCTAssertEqual(entries[1].1 as? String, "data2-2")
        
        entries = subMap2.entries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].0, "key3")
        XCTAssertEqual(entries[0].1 as? String, "data3")
    }

    func testSubDocsSubdocToDict() throws {
        let doc = CrdtMapSwift()
        let subMap1 = doc.getMap("sub1")
        let subMap2 = doc.getMap("sub2")

        doc.set("key1", "data1")
        subMap1.set("key2", "data2")
        subMap2.set("key3", "data3")
        subMap1.set("key2-2", "data2-2")
        subMap1.set("removed-key", "data", timestamp: 1000)
        subMap1.delete("removed-key", timestamp: 1001)

        var dict = subMap1.toDict()
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["key2"] as? String, "data2")
        XCTAssertEqual(dict["key2-2"] as? String, "data2-2")

        dict = subMap2.toDict()
        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict["key3"] as? String, "data3")
    }

    func testSubDocsGettingSameSubdocMultipleTimesShouldResultInSameSubdocObject() throws {
        let doc = CrdtMapSwift()
        let subMap1 = doc.getMap("sub1")
        let subMap2 = doc.getMap("sub1")
        
        XCTAssert(subMap1 === subMap2)
    }
    
    func testIndexOutOfBoundsIssueWhenClientIdIsHigh() throws {
        let doc = CrdtMapSwift()
        doc.set("postsync", "postsync", timestamp: 1642170325184.023, clientId: 2869881342)
        
        let encoded = CrdtMapSwift.encode(snapshot: doc.getSnapshotFrom(timestamp: 0))
        let decoded = CrdtMapSwift.decodeSnapshot(encoded)
        
        XCTAssertEqual(decoded.count, 1)
    }
}
