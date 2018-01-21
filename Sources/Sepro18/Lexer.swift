//
//  Lexer.swift
//  SeproLang
//
//===----------------------------------------------------------------------===//
//
// Lexer interface and simple lexer
//
//===----------------------------------------------------------------------===//

/// Parser Token

import Foundation

public enum TokenKind: Equatable, CustomStringConvertible {
    case empty

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
        case .empty: return "empty"
        case .symbol: return "symbol"
        case .intLiteral: return "int"
        case .stringLiteral: return "string"
		case .operator: return "operator"
        }
    }
}

/// Line and column text position. Starts at line 1 and column 1.
public struct TextPosition: CustomStringConvertible {
    var line: Int = 1
    var column: Int = 1

	/// Advances the text position. If the character is a new line character,
	/// then line position is increased and column position is reset to 1. 
    mutating func advance(with char: UnicodeScalar?) {
		if let char = char {
			if NewLineCharacterSet.contains(char) {
				self.column = 1
				self.line += 1
			}
            self.column += 1
		}
    }

    public var description: String {
        return "\(self.line):\(self.column)"
    }
}


public struct Token: CustomStringConvertible, CustomDebugStringConvertible {
    public let position: TextPosition
    public let kind: TokenKind
    public let text: String

    public init(_ kind: TokenKind, text: String, position: TextPosition) {
        self.kind = kind
        self.text = text
        self.position = position
    }

    public var description: String {
        let str: String
        switch self.kind {
        case .empty: str = "(empty)"
        case .stringLiteral: str = "'\(self.text)'"
        case .error(let message): str = "\(message) around '\(self.text)'"
        default:
            str = self.text
        }
        return "\(str) (\(self.kind)) at \(self.position)"
    }
    public var debugDescription: String {
        return description
    }

    /// Content of the string literal.
    public var stringLiteral: String? {
        guard kind == .stringLiteral else {
            return nil
        }

        let offset: Int

        if text.hasPrefix("\"\"\"") {
            offset = 3
        }
        else {
            offset = 1
        }
        let start = text.index(text.startIndex, offsetBy: offset)
        let end = text.index(text.endIndex, offsetBy: -offset)

        return String(text[start...end])
    }

}

public func ==(token: Token, kind: TokenKind) -> Bool {
    return token.kind == kind
}

public func ==(left: Token, right: String) -> Bool {
    return left.text == right
}

// Character sets
let WhitespaceCharacterSet = CharacterSet.whitespaces | CharacterSet.newlines
let NewLineCharacterSet = CharacterSet.newlines
let DecimalDigitCharacterSet = CharacterSet.decimalDigits

var IdentifierStart = CharacterSet.letters | "_"
var IdentifierCharacters = CharacterSet.alphanumerics | "_"
var OperatorCharacters =  CharacterSet(charactersIn: ".,*=():")

// Single quote: Symbol, Triple quote: Docstring
let CommentStart: UnicodeScalar = "#"

/// Simple lexer that produces symbols, keywords, integers, operators and
/// docstrings. Symbols can be quoted with a back-quote character.
///
public class Lexer {
	typealias Index = String.UnicodeScalarView.Index

    let source: String
    let characters: String.UnicodeScalarView
    var index: Index
    var currentChar: UnicodeScalar? = nil

    public var position: TextPosition
    public var currentToken: Token?

    /// Initialize the lexer with model source.
    ///
    /// - Parameter source: source string
    ///
    public init(_ source:String) {
        self.source = source

        characters = source.unicodeScalars
        index = characters.startIndex

        if source.isEmpty {
            currentChar = nil
        }
        else {
            currentChar = characters[index]
        }

        position = TextPosition()

        currentToken = nil
    }

    /// Latest error token message.
    ///
    public var error: String? {
        guard let kind = currentToken?.kind else {
            return nil
        }

        switch kind {
        case .error(let message): return message
        default: return nil
        }
    }

    /// true` if the parser is at end of input.
    ///
    public var atEnd: Bool {
        return index >= characters.endIndex
    }


    /// Parse the input and return an array of parsed tokens
    public func parse() -> [Token] {
        var tokens = [Token]()

        loop: while(true) {
            let token = self.nextToken()

            tokens.append(token)

            switch token.kind {
            case .empty, .error:
                break loop
            default:
                break
            }
        }

        return tokens
    }

    /**
     Advance to the next character and set current character.
     */
    func advance() {
		index = characters.index(index, offsetBy: 1)

        // TODO: Fix this with atEnd
        if index < characters.endIndex {
			currentChar = characters[index]
			position.advance(with: currentChar)
		}
		else {
			currentChar = nil
		}
    }

    /** Accept characters that are equal to the `char` character */
    fileprivate func accept(character: UnicodeScalar) -> Bool {
        if self.currentChar == character {
            self.advance()
            return true
        }
        else {
            return false
        }
    }

    /// Accept characters from a character set `set`
    fileprivate func accept(from set: CharacterSet) -> Bool {
        if currentChar.map({ set.contains($0) }) ?? false {
            self.advance()
            return true
        }
        else {
            return false
        }
    }

    private func acceptWhile(from set: CharacterSet) {
        while(self.currentChar != nil) {
            if !(set.contains(self.currentChar!)) {
                break
            }
            self.advance()
        }
    }

	@discardableResult
    private func acceptUntil(from set: CharacterSet) -> Bool {
        while(self.currentChar != nil) {
            if set.contains(self.currentChar!) {
                return true
            }
            self.advance()
        }
        return false
    }

    /**
     Parse next token.

     - Returns: currently parsed SourceToken
     */
    public func nextToken() -> Token {
        let tokenKind: TokenKind

        // Skip whitespace
        while(true){
            if self.accept(character: CommentStart) {
                self.acceptUntil(from: NewLineCharacterSet)
            }
            else if !self.accept(from: WhitespaceCharacterSet) {
                break
            }
        }

        if self.atEnd {
            return Token(.empty, text: "", position: position)
        }

        let start = self.index
        let pos = self.position

        // Integer = [0-9]+
        //
        if accept(from: DecimalDigitCharacterSet) {
            self.acceptWhile(from: DecimalDigitCharacterSet)

            if accept(from: IdentifierStart) {
                let invalid = currentChar.map { String($0) } ?? "(nil)"
                let error = "Invalid character \(invalid) in integer literal."
                tokenKind = .error(error)
            }
            else {
                tokenKind = .intLiteral
            }
        }
        else if accept(from: IdentifierStart) {
            acceptWhile(from: IdentifierCharacters)

            tokenKind = .symbol
        }
        else if accept(character: "\"") {
            tokenKind = scanString()
        }
        else if accept(from: OperatorCharacters) {
            tokenKind = .operator
        }
        else{
            let error = self.currentChar.map {
                            "Unexpected character '\($0)'"
                        } ?? "Unexpected end"
            
            tokenKind = .error(error)
        }

        var text = String(self.source.unicodeScalars[start..<index])

        // Strip quotes from a string literal.
        // TODO: This is not quite nice
        //
        if tokenKind == .stringLiteral {
            let offset: Int

            if text.hasPrefix("\"\"\"") {
                offset = 3
            }
            else {
                offset = 1
            }
            let start = text.index(text.startIndex, offsetBy: offset)
            let end = text.index(text.endIndex, offsetBy: -offset)

            text = String(text[start..<end])
            
        }

        currentToken = Token(tokenKind, text: text, position: pos)

        return currentToken!
    }

    func scanString() -> TokenKind {
		// Second quote
        if accept(character: "\"") {
            if accept(character: "\"") {
                while !atEnd {
                    if accept(character: "\"")
                        && accept(character: "\"")
                        && accept(character: "\"") {
                        
                        return .stringLiteral
                    }
                    else if accept(character: "\\") && atEnd {
                        break
                    }
                    advance() 
                }
            }
            else {
				// If not third quote, then we have an empty string
                return .stringLiteral
            }
        }
        else {
            // Parse normal string here
            while !atEnd {
                // Escape character
                if accept(character: "\""){
                    return .stringLiteral
                }
                else if accept(character: "\\") && atEnd {
                    // Unexpected end of s tring
                    break
                }

                advance()
            }
        }
        return .error("Unexpected end of input in a string")
    }
}

