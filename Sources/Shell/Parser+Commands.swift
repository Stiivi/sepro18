import Compiler

// FIXME: Don't be public
enum ASTCommand {
    case nothing
    case exit
    case help
    case status
    // case importModel(String)
    // case importGraph(String)
    // case exportModel(String)
    // case exportGraph(String)
    case run(Int)
    case step
    case reset
    case halt
    case unhalt
}

extension Parser {
    // FIXME: Don't be public
    func commandLine() throws -> ASTCommand {
        let command = try _command()

        try expectEnd()

        if let command = command {
            return command
        }
        else {
            return .nothing
        }
    }

    func _command() throws -> ASTCommand? {
        if keyword("EXIT") {
            return .exit
        }
        else if keyword("HELP") {
            return .help
        }
        else if keyword("STATUS") {
            return .status
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
            throw ParserError.keywordExpected("IMPORT MODEL not yet implemented")
            // return try _importModel()
        }
        else if keyword("GRAPH") {
            throw ParserError.keywordExpected("IMPORT GRAPH not yet implemented")
            // return try _importGraph()
        }
        else {
            throw ParserError.keywordExpected("Can import only MODEL or GRAPH")
        }
    }

    func _run() throws -> ASTCommand? {
        guard keyword("RUN") else { return nil }

        guard let steps = integer() else {
            throw ParserError.unexpectedTokenType("number of steps expected")
        } 

        return .run(steps)
    
    }
}
