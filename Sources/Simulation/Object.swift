import Model

/// Object reference.
public struct OID: Hashable, CustomStringConvertible {
    // Prevent doing integer operations with the type and prevent custom
    // creation of the object.
    let id: Int

    init(id: Int) {
        self.id = id
    }

    public var description: String { return String(id) }
}


/// Representation of an object from the object graph.
///
public struct Object: CustomStringConvertible {
    public typealias Slots = Dictionary<Symbol, OID>.Keys

    public let oid: OID
    public let tags: Set<Symbol>
    public let references: [Symbol:OID]

    public init(oid: OID, tags: Set<Symbol>, references: [Symbol:OID]) {
        self.oid = oid
        self.tags = tags
        self.references = references
    }

    public var slots: Slots {
        return references.keys
    }

    public var description: String {
        let tagsStr = tags.joined(separator: ",")
        let slotsStr = references.map {
            "\($0.key)->\($0.value)"
        }.joined(separator: ",")

        return "{\(oid): \(tagsStr) [\(slotsStr)]}"
    }

}
