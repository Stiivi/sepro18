// Structure and world related structures
//

public struct Prototype {
    public let tags: Set<Symbol>

    public init(tags: Set<Symbol>) {
        self.tags = tags
    }
}

public struct QuantifiedStruct {
    public let count: Int
    public let structName: Symbol

    public init(count: Int, name: String) {
        self.count = count
        self.structName = name
    }
}

public struct World {
    // FIMXE: Rename to structures
    public let structures: [QuantifiedStruct]

    public init(structures: [QuantifiedStruct]) {
        self.structures = structures
    }
}

public struct StructBinding {
    public let fromName: String
    public let slot: String
    public let toName: String

    public init(from origin: String, slot: String, to target: String) {
        self.fromName = origin
        self.toName = target
        self.slot = slot
    }
}

public struct Structure {
    public let objects: [Symbol:Prototype]
    public let bindings: [StructBinding]

    public init(objects: [Symbol:Prototype], bindings: [StructBinding]) {
        self.objects = objects
        self.bindings = bindings
    }
}


