//
//  Lexer.swift
//  SeproLang
//
//===----------------------------------------------------------------------===//
//
// Lexer interface and simple lexer
//
//===----------------------------------------------------------------------===//

// FIXME: use [lr]paren instead of operator for '(' ')'

/// Parser Token

import Foundation

public enum TokenType: Equatable, CustomStringConvertible {
    case error(String)

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


/// Line and column text location. Starts at line 1 and column 1.
public struct SourceLocation: CustomStringConvertible {
    var line: Int = 1
    var column: Int = 1

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


/// Simple lexer that produces symbols, keywords, integers, operators and
/// docstrings. Symbols can be quoted with a back-quote character.
///
public class Lexer {
	typealias Index = String.UnicodeScalarView.Index

    var iterator: String.UnicodeScalarView.Iterator
    var currentChar: UnicodeScalar?
    var text: String

    public internal (set) var location: SourceLocation
    public internal (set) var currentToken: Token?

    static let whitespaces = CharacterSet.whitespaces | CharacterSet.newlines
    static let decimalDigits = CharacterSet.decimalDigits
    static let symbolStart = CharacterSet.letters | "_"
    static let symbolCharacters = symbolStart | CharacterSet.decimalDigits | "_"
    static let operatorCharacters =  CharacterSet(charactersIn: ".()!")

    /// Initialize the lexer with model source. The current token is `nil` upon
    /// initialization and the caller is responsible to start parsing with
    /// the `next()` function.
    ///
    /// - Parameter source: source string
    ///
    public init(_ source:String) {
        iterator = source.unicodeScalars.makeIterator()

        currentChar = iterator.next()
        location = SourceLocation()

        text = ""
        currentToken = nil
    }
    /// Latest error token message.
    ///
    public var error: String? {
        guard let type = currentToken?.type else {
            return nil
        }

        switch type {
        case .error(let message): return message
        default: return nil
        }
    }

    /// true` if the parser is at end of input.
    ///
    public var atEnd: Bool {
        return currentChar == nil
    }


    /// Parse the input and return an array of parsed tokens
    public func parse() -> [Token] {
        var tokens = [Token]()

        loop: while true {
            guard let token = self.next() else {
                break
            }

            tokens.append(token)

            switch token.type {
            case .error:
                break loop
            default:
                break
            }
        }

        return tokens
    }

    /// Advance to the next character and set current character.
    ///
    /// - Parameter discard: If `true` then the current character is not
    ///                      appended to the result text.
    ///
    func advance(discard: Bool=false) {
        if !atEnd {
            if !discard {
                text.unicodeScalars.append(currentChar!)
            }
            currentChar = iterator.next()

            if let char = currentChar {
                if CharacterSet.newlines.contains(char) {
                    location.advanceLine()
                }
                else {
                    location.advanceColumn()
                }
            }
        }
    }

    /// Accept characters that are equal to the `char` character
    ///
    /// - Returns: `true` if character was accepted, otherwise `false`.
    ///
    fileprivate func accept(character: UnicodeScalar, discard: Bool=false) -> Bool {
        if self.currentChar == character {
            self.advance(discard: discard)
            return true
        }
        else {
            return false
        }
    }

    /// Accept characters from a character set and advance if the character was
    /// accepted..
    ///
    /// - Returns: `true` if character was accepted, otherwise `false`
    ///
    fileprivate func accept(from set: CharacterSet) -> Bool {
        if currentChar.map({ set.contains($0) }) ?? false {
            self.advance()
            return true
        }
        else {
            return false
        }
    }

    /// Accept characters while a character for a set is encountered.
    ///
    /// - Returns: `true` if at least one character was accepted, otherwise
    /// `false`
    ///
    @discardableResult
    private func acceptWhile(from set: CharacterSet) -> Bool {
        var advanced: Bool = false

        while accept(from: set) {
            advanced = true 
        }

        return advanced
    }

    /// Accept characters until a character for a set is encountered.
    ///
    /// - Returns: `true` if at least one character was accepted, otherwise
    /// `false`
    ///
	@discardableResult
    private func acceptUntil(from set: CharacterSet) -> Bool {
        var advanced: Bool = false

        while true {
            if currentChar.map({ set.contains($0) }) ?? true {
                break
            }
            else {
                self.advance()
                advanced = true
            }
        }

        return advanced
    }

    /// Read a single or tripple quoted string literal.
    ///
    func scanString() -> TokenType {
        if accept(character: "\"", discard: true) {
            if accept(character: "\"", discard: true) {
                while !atEnd {
                    if accept(character: "\"", discard: true)
                        && accept(character: "\"", discard: true)
                        && accept(character: "\"", discard: true) {

                        return .stringLiteral
                    }
                    else if accept(character: "\\") && atEnd {
                        // Unexpected end of string - expected escaped character
                        break
                    }
                    advance()
                }
            }
            else {
                // We got an empty string
                return .stringLiteral
            }

        }
        else {
            while !atEnd {
                // Escape character
                if accept(character: "\"", discard: true) {
                    return .stringLiteral
                }
                else if accept(character: "\\") && atEnd {
                    // Unexpected end of string - expected escaped character
                    break
                }
                else if accept(from: CharacterSet.newlines) {
                    return .error("New line in a single-line string.")
                }
                advance()
            }
        }

        return .error("Unexpected end of string")

    }

    /// Parse next token.
    ///
    /// - Returns: currently parsed SourceToken or nil if it is at the end of
    /// the source stream.
    ///
    @discardableResult
    func next() -> Token? {
        let type: TokenType

        // Skip whitespace
        while true {
            if accept(character: "#") {
                acceptUntil(from: CharacterSet.newlines)
            }
            else if !accept(from: Lexer.whitespaces) {
                break
            }
        }

        guard !self.atEnd else {
            return nil
        }

        // Reset the text buffer.
        text = ""

        // Integer = [0-9]+
        //
        if accept(from: Lexer.decimalDigits) {
            self.acceptWhile(from: Lexer.decimalDigits)

            if accept(from: Lexer.symbolStart) {
                let invalid = currentChar.map { String($0) } ?? "(nil)"
                let error = "Invalid character \(invalid) in integer literal."
                type = .error(error)
            }
            else {
                type = .intLiteral
            }
        }
        else if accept(from: Lexer.symbolStart) {
            acceptWhile(from: Lexer.symbolCharacters)

            type = .symbol
        }
        else if accept(character: "\"", discard: true) {
            type = scanString()
        }
        else if accept(from: Lexer.operatorCharacters) {
            type = .operator
        }
        else {
            let error = currentChar.map {
                            "Unexpected character '\($0)'"
                        } ?? "Unexpected end"

            type = .error(error)
        }

        currentToken = Token(type, text: text, location: location)

        return currentToken
    }
}
