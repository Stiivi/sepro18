indirect enum AST {
    case error(String)
    case define(String, String)
    case actuator(String, [AST], [AST]?, [AST])
    case structure(String, [AST])

    // Actuator components
    case modifier(AST, [AST])
    case qualifiedSymbol(String?, String)
    case symbolPresence(Bool, AST)

    case bind(AST, AST)
    case unbind(AST)
    case set(String)
    case unset(String)

    // Structure
    case structureItem(Int, [String])
}

