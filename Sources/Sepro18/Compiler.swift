/// Sepro compiler - complies ASTModelObjects into model
///
class Compiler {
    var model: Model

    init() {
        model = Model()
    }

    /// Compile `string` into model objects.
    ///
    /// - Pass 1: collect definitions or infer symbol types
    /// - Pass 2: create model objects
    ///
    func compile(_ string: String) {
        let items: [ASTModelObject] = parse(source: string)

        // Phase 1: Determine symbols
        //
        // The symbol types are required for the selector - we need to know
        // whether the symbols represent tags (to check for existence) or slots
        // (to check for bindings)
        //
        let symbols = items.map { $0.symbols }.joined()

        symbols.forEach {
            typedSymbol in
            if let type = typedSymbol.type {
                if !model.define(symbol: typedSymbol.symbol, type: type) {
                    let previousType = model.typeOf(symbol: typedSymbol.symbol)
                    fatalError("Multiple types for symbol \(typedSymbol.symbol). Trying to define as \(type) previously defined as \(previousType)")
                }
            }
            // TODO: What to do with unknown symbols?
        }

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

        case let .actuator(name, lselector, rselector, modifiers):
            compileActuator(name: name,
                            leftSelector: lselector,
                            rightSelector: rselector,
                            modifiers: modifiers)

        case let .structure:
            fatalError("not implemented")
        }
    }

    func compileDefine(typeName: String, symbol: String) {
        // FIXME: Looks like we can skip this one, as we did this in the
        // Phase I.
    }

    func compileActuator(name: String, leftSelector: ASTSelector,
            rightSelector: ASTSelector?, modifiers: [ASTModifier]) {
  
        // FIXME: Require ALL kind of actuator

        let leftCompiled: Selector
        let rightCompiled   : Selector?

        leftCompiled = compileSelector(leftSelector)
        rightCompiled = rightSelector.map { compileSelector($0) }
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
        }.reduce((Set<ModeSymbol>(), Set<ModeSymbol>())) {
            state, next in
            let (seen, dupes) = state
            if seen.contains(next) {
                return (seen: seen, dupes: dupes)
            }
            else {
                return (seen: seen, dupes: dupes)
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
}

