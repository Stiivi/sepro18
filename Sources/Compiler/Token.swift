// Token.swift
//

/// Line and column text location. Starts at line 1 and column 1.
public struct SourceLocation: CustomStringConvertible {
    public internal(set) var line: Int = 1
    public internal(set) var column: Int = 1

	/// Advances the text location. If the character is a new line character,
	/// then line location is increasd and column location is reset to 1. 
    mutating func advanceColumn() {
        column += 1
    }

    mutating func advanceLine() {
        column = 1
        line += 1
    }

    public var description: String {
        return "\(line):\(column)"
    }

    public var longDescription: String {
        return "line \(line) column \(column)"
    }
}

public enum LexerError: Equatable {
    case newLineInString
    case unexpectedEndOfString
    case invalidCharacterInInt
    case unexpectedCharacter(UnicodeScalar)
    case unexpectedEnd

    public var description: String {
        switch self {
        case .newLineInString:
            return "New line in a single-line string"
        case .unexpectedEndOfString:
            return "Unexpected end of string"
        case .invalidCharacterInInt:
            return "Invalid character in integer literal"
        case .unexpectedCharacter(let char):
            return "Unexpected character '\(char)'"
        case .unexpectedEnd:
            return "Unexpected end"
        }
    }
}

public enum TokenType: Equatable, CustomStringConvertible {
    case error(LexerError)

    /// Identifier: first character + rest of identifier characters
    case symbol

    /// Integer
    case intLiteral

    /// Multi-line string containing a piece of documentation
    case stringLiteral

    /// From a list of operators
    case `operator`

    public var description: String {
        switch self {
        case .error(let message): return "error(\(message))"
        case .symbol: return "symbol"
        case .intLiteral: return "int"
        case .stringLiteral: return "string"
        case .operator: return "operator"
        }
    }
}


public struct Token: CustomStringConvertible, CustomDebugStringConvertible {
    public let location: SourceLocation
    public let type: TokenType
    public let text: String

    public init(_ type: TokenType, text: String, location: SourceLocation) {
        self.type = type
        self.text = text
        self.location = location
    }

    public var description: String {
        let str: String
        switch type {
        case .stringLiteral: str = "'\(text)'"
        case .error(let message): str = "\(message) around '\(self.text)'"
        default:
            str = self.text
        }
        return "\(str) (\(type)) at \(location)"
    }

    public var debugDescription: String {
        return description
    }
}


