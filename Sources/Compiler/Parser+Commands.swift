// FIXME: Don't be public
public enum ASTCommand {
    case exit
    case help
    // case importModel(String)
    // case importGraph(String)
    // case exportModel(String)
    // case exportGraph(String)
    case run(Int)
    case step
    case reset
}

extension Parser {
    // FIXME: Don't be public
    public func _command() throws -> ASTCommand? {
        if keyword("EXIT") {
            return .exit
        }
        else if keyword("HELP") {
            return .help
        }
        else if keyword("STEP") {
            return .step
        }
        else if keyword("RESET") {
            return .reset
        }
        else {
            return try _run()
                    ?? _import()
        }
    }

    // IMPORT MODEL FROM path [REPLACE]
    // IMPORT GRAPH FROM path [REPLACE|APPEND]
    func _import() throws -> ASTCommand? {
        guard keyword("IMPORT") else { return nil }
       
        if keyword("MODEL") {
            throw CompilerError.keywordExpected("IMPORT MODEL not yet implemented")
            // return try _importModel()
        }
        else if keyword("GRAPH") {
            throw CompilerError.keywordExpected("IMPORT GRAPH not yet implemented")
            // return try _importGraph()
        }
        else {
            throw CompilerError.keywordExpected("Can import only MODEL or GRAPH")
        }
    }

    func _run() throws -> ASTCommand? {
        guard keyword("RUN") else { return nil }

        guard let steps = integer() else {
            throw CompilerError.unexpectedTokenType("number of steps expected")
        } 

        return .run(steps)
    
    }
}
