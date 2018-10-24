import Model

/// Object reference.
public struct OID: Hashable, CustomStringConvertible {
    // Prevent doing integer operations with the type and prevent custom creation
    // of the object.
    let id: Int

    init(id: Int) {
        self.id = id
    }

    public var description: String { return String(id) }
}


public class Object: CustomStringConvertible {
    public internal(set) var tags: Set<Symbol>
    public internal(set) var references: [Symbol:OID]

    public init(tags: Set<Symbol>, references: [Symbol:OID]) {
        self.tags = tags
        self.references = references
    }

    public var slots: Set<Symbol> {
        return Set(references.keys)
    }

    public var description: String {
        let tagsStr = tags.joined(separator: ", ")
        let slotsStr = references.map {
            "\($0.key)->\($0.value)"
        }.joined(separator: ", ")

        return "(\(tagsStr)|\(slotsStr))"
    }

}
