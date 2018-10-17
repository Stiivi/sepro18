import Model

/// Sepro compiler - complies ASTModelObjects into model
///
public final class Compiler {
    public var model: Model
    // Counter for the anonymous structres to assign special naming
    public var anonStructCounter: Int = 1

    public init() {
        model = Model()
    }

    /// Compile `string` into model objects.
    ///
    /// - Pass 1: collect definitions or infer symbol types
    /// - Pass 2: create model objects
    ///
    public func compile(source: String) {
        let items: [ASTModelObject] = parse(source: source)

        // PHASE I. Determine symbols
        //
        // The symbol types are required for the selector - we need to know
        // whether the symbols represent tags (to check for existence) or slots
        // (to check for bindings)
        //
        let symbols = items.map { $0.symbols }.joined()
        var undefinedCandidates: Set<Symbol> = []

        symbols.forEach {
            typedSymbol in
            if let type = typedSymbol.type {
                if !model.define(symbol: typedSymbol.symbol, type: type) {
                    let previousType = model.typeOf(symbol: typedSymbol.symbol)
                    fatalError("Multiple types for symbol '\(typedSymbol.symbol)': used as \(type) previously defined as \(previousType!)")
                }
            }
            else {
                undefinedCandidates.insert(typedSymbol.symbol)
            }

            // TODO: What to do with unknown symbols?
        }

        let undefined: Set<Symbol> = undefinedCandidates.subtracting(Set(model.symbols.keys))
        
        if !undefined.isEmpty {
            print("WARNING: Undefined symbols: \(undefined)")
        }

        debugPrint("# Symbol Table")
        model.symbols.keys.sorted().forEach {
            let type = model.symbols[$0]!
            debugPrint(" - \($0): \(type.rawValue)") 
        }


        // PHASE II. Read model objects
        //

        // At this point we assume all symbols are known. If they are not, then
        // it is a fatal error and we sohuld not proceed.
        //
        items.forEach {
            compile(modelObject: $0)
        }
    }

    /// Complie a model object.
    ///
    func compile(modelObject item: ASTModelObject) {
        switch item {
        case let .define(typeName, symbol):
            compileDefine(typeName:typeName, symbol:symbol)

        case let .unaryActuator(name, selector, transitions):
            compileUnaryActuator(name: name,
                            selector: selector,
                            transitions: transitions)
        case let .binaryActuator(name, lselector, rselector, transitions):
            compileBinaryActuator(name: name,
                            leftSelector: lselector,
                            rightSelector: rselector,
                            transitions: transitions)

        case let .structure(name, items):
            compileStruct(name: name, items: items)
        case let .world(name, items):
            compileWorld(name: name, items: items)
        case let .data(tags, text):
            compileData(tags: tags, text: text)
        }
    }

    func compileDefine(typeName: String, symbol: String) {
        // FIXME: Looks like we can skip this one, as we did this in the
        // TODO: Process documentation here
        // Phase I.
    }

    func compileUnaryActuator(name: String, selector: ASTSelector,
                              transitions: [ASTTransition]) {
        let actuator: UnaryActuator
        let compiledSelector: Selector = compileSelector(selector)

        let transList: [(SubjectMode, UnaryTransition)]

        transList = transitions.map {
            trans in
            let mode: SubjectMode
            mode = trans.subject.slot.map { .indirect($0) } ?? .direct
            return (mode, compileUnaryTransition(trans))
        }

        let transDict = Dictionary(transList, uniquingKeysWith: { (_, last) in last })

        // TODO: notifications, traps and halts
        actuator = UnaryActuator(
            selector: compiledSelector,
            transitions: transDict,
            notifications: Set(),
            traps: Set(),
            halts: false
        )                               

        model.insertActuator(unary: actuator, name: name)
    }

    // Extracts SymbolMask from modifiers
    func tagMaskFromModifies(_ modifiers: [ASTModifier]) -> SymbolMask {
        let maskList: [(String, Presence)] = modifiers.compactMap {
            switch $0 {
            case let .set(sym): return (sym, .present)
            case let .unset(sym): return (sym, .absent)
            default: return nil
            }
        }

        // FIXME: check for dupes
        // Current implementation: take the latest in the list
        let mask = Dictionary(maskList, uniquingKeysWith: { (_, last) in last })
   
        return SymbolMask(mask: mask)
    }

    func compileUnaryTransition(_ trans: ASTTransition) -> UnaryTransition {
        // We need to convert:
        //      modifiers -> tags
        //      modifiers -> bindings

        // 1. Compile tags
        //
        let modifiers = trans.modifiers

        let mask = tagMaskFromModifies(trans.modifiers)

        // 2. Compile bindings
        //

        // FIXME: This is not OK, we can't have qualified symbol here
        // we need to replace it with proper target
        let bindList: [(String, UnaryTarget)] = modifiers.compactMap {
            switch $0 {
            case let .bind(slot, target):
                // THIS -> .subject
                // slot -> direct(slot)
                // THIS.slot -> direct(slot)
                // slot.slot -> indirect (slot, slot)
                if let qual = target.qualifier {
                    if qual == "THIS" {
                        return (slot, .direct(target.symbol))            
                    }
                    else {
                        return (slot, .indirect(qual, target.symbol))            
                    }
                }
                else {
                    if target.symbol == "THIS" {
                        return (slot, .subject)
                    } 
                    else {
                        return (slot, .direct(target.symbol))
                    }
                }
            case let .unbind(slot):
                return (slot, .none)
            case .set, .unset:
                return nil
            }
        }

        let bindings = Dictionary(bindList,
                                  uniquingKeysWith: { (_, last) in last })

        return UnaryTransition(tags: mask, bindings: bindings)

    }

    func compileBinaryTransition(_ trans: ASTTransition) -> BinaryTransition {
        // We need to convert:
        //      modifiers -> tags
        //      modifiers -> bindings

        // 1. Compile tags
        //
        let modifiers = trans.modifiers
        let mask = tagMaskFromModifies(trans.modifiers)

        // 2. Compile bindings
        //

        // FIXME: This is not OK, we can't have qualified symbol here
        // we need to replace it with proper target
        let bindList: [(String, BinaryTarget)] = modifiers.compactMap {
            switch $0 {
            case let .bind(slot, target):
                // THIS -> .subject
                // slot -> direct(slot)
                // THIS.slot -> direct(slot)
                // slot.slot -> indirect (slot, slot)
                if let qual = target.qualifier {
                    if qual.uppercased() == "OTHER" {
                        return (slot, .inOther(target.symbol))            
                    }
                    else {
                        fatalError("Indirection in biary actuator: \(qual).\(slot)")
                    }
                }
                else {
                    if target.symbol.uppercased() == "OTHER" {
                        return (slot, .other)
                    } 
                    else {
                        // TODO: Should we allow that?
                        // This can be done through tags as non-atomic
                        fatalError("Invalid binding target in binary actuator: \(target.symbol)")
                    }
                }
            case let .unbind(slot):
                return (slot, .none)
            case .set, .unset:
                return nil
            }
        }
        let bindings = Dictionary(bindList,
                                  uniquingKeysWith: { (_, last) in last })

        return BinaryTransition(tags: mask, bindings: bindings)

    }

    func compileBinaryActuator(name: String, leftSelector: ASTSelector,
            rightSelector: ASTSelector, transitions: [ASTTransition]) {
        let leftCompiled: Selector = compileSelector(leftSelector)
        let rightCompiled: Selector = compileSelector(rightSelector)

        let leftTransList = transitions.filter {
            $0.subject.side == "LEFT"
        }.map {
            trans in
            (trans.subject.slot.map { SubjectMode.indirect($0) } ??  SubjectMode.direct,
             compileBinaryTransition(trans))
        }
        let leftTrans = Dictionary(leftTransList,
                                   uniquingKeysWith: { (_, last) in last })

        let rightTransList = transitions.filter {
            $0.subject.side == "RIGHT"
        }.map {
            trans in
            (trans.subject.slot.map { SubjectMode.indirect($0) } ??  SubjectMode.direct,
             compileBinaryTransition(trans))
        }
        let rightTrans = Dictionary(rightTransList,
                                   uniquingKeysWith: { (_, last) in last })

        // TODO: Add control signals
        let actuator = BinaryActuator(
            leftSelector: leftCompiled,
            rightSelector: rightCompiled,
            leftTransitions: leftTrans,
            rightTransitions: rightTrans,
            notifications: Set(),
            traps: Set(),
            halts: false
        )

        model.insertActuator(binary: actuator, name: name)


    }

    func compileSelector(_ selector: ASTSelector) -> Selector {
        // mode -> pattern (tags, slots)
        let result: Selector

        switch selector {
        case .all:
            result = .all
        case .match(let matches):
            let matches = compileSelectorMatches(matches)
            result = .match(matches)
        }

        return result
    }

    func compileSelectorMatches(_ matches: [ASTMatch]) -> [SubjectMode: SelectorPattern] {
        // Convert (isPresent, (qual, symbol)
        //          -> (mode, type, symbol, presence)


        // Internal structure for hashable purposes of the (mode, symbol) tuple
        struct ModeSymbol: Hashable {
            let mode: SubjectMode
            let symbol: String
        }

        // Expand the matches for easier downstream handling:
        // - convert presence flag into Presence type
        // - convert qualifier into indirection
        // - extract symbol
        //
        let expandedMatches: [(mode: SubjectMode, symbol: String, presence:Presence)] = matches.map {
            match in

            let presence: Presence = match.isPresent ? .present : .absent
            let mode: SubjectMode = match.symbol.qualifier.map { .indirect($0) } ?? .direct
            let symbol = match.symbol.symbol
           
            return (mode: mode, symbol: symbol, presence: presence)
        }
        
        // Check for uniqueness of symbols within a mode
        //
        let (_, dupes) = expandedMatches.map {
            ModeSymbol(mode: $0.mode, symbol: $0.symbol)  
        }.reduce(into: (Set<ModeSymbol>(), Set<ModeSymbol>())) {
            state, next in
            // Tuple items:
            // 0 - seen
            // 1 - dupes
            if state.0.contains(next) {
                // seen -> goes into dupes
                state.1.insert(next)
            }
            else {
                // not seen -> goes into seen
                state.0.insert(next)
            }
        }
    
        // Fail if we have duplicates
        //
        // TODO: we need to improve on error reporting here - we need to know
        // what actuator we are in.
        guard dupes.count == 0 else {
            fatalError("Duplicate use of selector symbols: \(dupes) ")

        }
      
        // Group matches by subject mode
        //
        var byMode: [SubjectMode:[(Symbol, Presence)]] = [:]
        byMode = expandedMatches.reduce(into: byMode) {
            state, next in

            let (mode, symbol, presence) = next

            if state[mode] == nil {
                state[mode] = [(symbol, presence)]
            }
            else {
                state[mode]!.append((symbol, presence))
            }
        }

        // Final conversion to selector patterns
        //
        let patterns: [(SubjectMode, SelectorPattern)] = byMode.map {
            item in
            let mode = item.key
            let presences = item.value

            var slots: [Symbol:Presence] = [:]
            var tags: [Symbol:Presence] = [:]

            presences.forEach {
                (symbol, presence) in
                guard let type: SymbolType = model.typeOf(symbol: symbol) else {
                    fatalError("Unknown type of symbol '\(symbol)'")
                }
                
                switch type {
                case .slot: slots[symbol] = presence
                case .tag: tags[symbol] = presence
                default:
                    fatalError("Only slot or tag symbol types are allowed in selector. Symbol '\(symbol)' is \(type).")
                }
            }

            return (mode, SelectorPattern(tags:SymbolMask(mask: tags),
                                         slots:SymbolMask(mask: slots)))
        }
        // Generate selector pattern
        let result: [SubjectMode:SelectorPattern]
        
        result = Dictionary(patterns, uniquingKeysWith: { (first, _) in first })

        return result
    }
    func compileWorld(name: String, items: [ASTWorldItem]) {
        let namedStructs: [QuantifiedStruct] = items.compactMap {
            switch $0 {
            case let .quantifiedStructure(count, name):
                return QuantifiedStruct(count: count, name: name)
            default:
                return nil
            }
        }

        let freeObjects: [(count: Int, tags: [String])] = items.compactMap {
            switch $0 {
            case let .quantifiedObject(count, tags):
                return (count: count, tags: tags)
            default:
                return nil
            }
        }

        // Create anonymous structures
        var constructedStructs: [QuantifiedStruct] = []

        freeObjects.enumerated().forEach {
            let (offset, element) = $0
            let proto = Prototype(tags: Set(element.tags))
            let structure = Structure(objects: ["_":proto], bindings: []) 
            let name = "__anonymous\(anonStructCounter + offset)__"

            let qStruct = QuantifiedStruct(count: element.count,
                                           name: name)
            constructedStructs.append(qStruct)
            model.insertStruct(structure, name: name)
        }
        anonStructCounter += freeObjects.count

        let world = World(structs: namedStructs + constructedStructs)
        model.insertWorld(world, name: name)
    }
    func compileStruct(name: String, items: [ASTStructItem]) {
        var objects: [String:Prototype]
        var bindings: [StructBinding]

        objects = Dictionary(uniqueKeysWithValues: items.compactMap {
            switch $0 {
                case let .object(name, tags):
                    return (name, Prototype(tags: Set(tags)))
            default: return nil
            } 
        })

        bindings = items.compactMap {
            switch $0 {
                case let .binding(origin, slot, target):
                    return StructBinding(from: origin, slot: slot, to: target)
            default: return nil
            } 
        }


        let structure = Structure(objects: objects, bindings: bindings)
        model.insertStruct(structure, name: name)
    }

    func compileData(tags: [String], text: String) {
        let item = DataItem(tags: Set(tags), text: text)
        model.appendData(item)
    }

}

