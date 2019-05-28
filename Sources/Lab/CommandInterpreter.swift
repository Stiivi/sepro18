import Compiler
import Logging

public final class CommandInterpreter {

    var shouldStop: Bool
    let logger = Logger(label: "sepro.main")

    public init() {
        shouldStop = false
    }

    /// Compile `string` into commands.
    ///
    public func interpret(source: String) {
        let parser = Parser(source: source)

        let commandAST: ASTCommand

        do {
            commandAST = try parser.commandLine()
        }
        catch {
            let context = parser.currentToken.map { "'\($0.text)'" }
                            ?? "end"

            // FIXME: Handle this error more gracefully.
            // TODO: ... or rather have a nice error handling for the compiler
            // #good-first
            print("Command parser error at \(parser.sourceLocation.longDescription) around \(context): \(error)")
            return
        }

        let maybeCommand: Command?

        do {
            let compiler = CommandCompiler()
            maybeCommand = try compiler.compile(command: commandAST)
        }
        catch {
            fatalError("Compiler error: \(error)")
        }

        guard let command = maybeCommand else {
            fatalError("Empty compiled command")
        }

        interpret(command: command)

    }

    public func interpret(command: Command) {
        // TODO: Handle errors.
        command.apply(interpreter: self)
    }

    /// Signalst that the interpreter should stop.
    ///
    public func exit() {
        self.shouldStop = true
    }
    public func runSimulation(steps: Int) {
        print("(NOT YET) RUN for \(steps) steps")
    }

    // displayHelp
    public func displayHelp() {
        print("""
        Commands

        """)

        for command in allCommands {
            print("\(command.commandName) - \(command.synopsis)")
        }
    }

    public func stepSimulation() {
        print("(NOT YET) STEP")
    }
    public func resetSimulation() {
        print("(NOT YET) RESET")
    }


}
