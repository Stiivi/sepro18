// Sepro 2018 - Model
//

public typealias Symbol = String

/// Type of a symbol within a model.
///
public enum SymbolType: String, CaseIterable {
    /// Symbol represents a slot
    case slot
    /// Symbol represents a tag
    case tag
    case structure
    case world
    case actuator
    case data

    public init?(name: String) {
        switch name {
        case "slot": self = .slot
        case "tag": self = .tag
        case "structure": self = .structure
        case "world": self = .world
        case "actuator": self = .actuator
        case "data": self = .data
        default: return nil
        }
    }
}

// Basic types
//

public struct DataItem {
    public let tags: Set<Symbol>
    public let text: String

    public init(tags: Set<Symbol>, text: String) {
        self.tags = tags
        self.text = text
    }
}

/// Sepro model description.
///
public class Model: CustomStringConvertible {
    // FIXME: Make all properties immutable (let)
    //        - they are made mutable for the compiler
    //
    public var symbols: [Symbol:SymbolType] = [:]
    public var unaryActuators: [String:UnaryActuator] = [:]
    public var binaryActuators: [String:BinaryActuator] = [:]
    public var structures: [String:Structure] = [:]
    public var worlds: [String:World] = [:]

    public var data: [DataItem] = []

    public init() {
    }

    /// - Returns: Type of a symbol `symbol`. If symbol is not defined, then
    /// returns `SymbolType.undefined`
    public func typeOf(symbol: Symbol) -> SymbolType? {
        return symbols[symbol]
    }

    // Mutation methods
    // ================

    /// Define a symbol `symbol` to be of `type` if it is not defined.
    /// - Returns: `true` if the symbol was successfully defined or if symbol
    /// existed and was of the same type. Returns `false` if the symbol was
    /// already defined but was of another type.

    @discardableResult
    public func define(symbol: Symbol, type: SymbolType) -> Bool {
        if let previous = symbols[symbol] {
            if previous == type {
                return true
            }
            else {
                return false
            }
        }

        symbols[symbol] = type
        return true
    }

    public func insertActuator(unary: UnaryActuator, name: String) {
        unaryActuators[name] = unary
    }

    public func insertActuator(binary: BinaryActuator, name: String) {
        binaryActuators[name] = binary
    }

    public var description: String {
        var items: [String] = []

        items += symbols.filter { (_, value) in
            value == .slot || value == .tag
        }.map { (key, value) in "DEF \(value) \(key)" }

        items += unaryActuators.map { (key, _) in
            "ACT \(key) ..."
        }

        items += binaryActuators.map { (key, value) in
            "REACT \(key) \(value)"
        }

        items += structures.map { (key, _) in
            "STRUCT \(key) ..."
        }

        items += worlds.map { (key, _) in
            "WORLD \(key) ..."
        }

        items += data.map {
            "DATA (\($0.tags)) ..."
        }

        return items.joined(separator: "\n")

    }

    public func insertWorld(_ world: World, name: String) {
        worlds[name] = world
    }
    public func insertStruct(_ structure: Structure, name: String) {
        structures[name] = structure
    }
    public func appendData(_ item: DataItem) {
        data.append(item)
    }

    /// Get data that match the `tags`. If `exact` is `true` then the data
    /// tags and `tags` must be equal sets, otherwise the `tags` is only subset
    /// of the data tags.
    public func getData(tags:Set<Symbol>, exact: Bool=true) -> [DataItem] {
        if exact {
            return self.data.filter { $0.tags == tags }
        }
        else {
            return self.data.filter { tags.isSubset(of:$0.tags) }
        }
    }
}
