import XCTest
@testable import Compiler

class ParserTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of
        // each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation
        // of each test method in the class.
        super.tearDown()
    }

    func testEmpty() {
        let parser = Parser(source: "")
        let token = parser.accept { _ in true } 

        XCTAssertNil(token)
        XCTAssertNil(token)
    }

    func testEmptyExpectEnd() {
        let parser = Parser(source: "")

        XCTAssertNoThrow(try parser.expectEnd())

        let parser2 = Parser(source: " ")

        XCTAssertNoThrow(try parser2.expectEnd())
    }

    func testExpectEnd() {
        let parser = Parser(source: "help")

        XCTAssertThrowsError(try parser.expectEnd())

        let parser2 = Parser(source: "help")

        // Accept one token unconditionally
        parser2.accept { _ in true }
        XCTAssertNoThrow(try parser2.expectEnd())
    }

}
