import Compiler
import Logging
import Simulator
import Simulation
import Model

public final class Shell {
    let logger = Logger(label: "sepro.main")

    // Interpreter context
    let model: Model
    let simulator: IterativeSimulator<SeproSimulation>

    public internal(set) var shouldStop: Bool

    /// Create an empty shell with an empty model, empty simulation and a
    /// simulator.
    ///
    public convenience init() {
        let simulation = SeproSimulation(model: Model())
        let simulator = IterativeSimulator(simulation: simulation)
        self.init(simulator: simulator)
    }

    public init(simulator: IterativeSimulator<SeproSimulation>) {
        shouldStop = false
        self.simulator = simulator
        self.model = self.simulator.simulation.model
    }

    public func printError(_ message: String) {
        print("ERROR: \(message)")
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
        command.run(shell: self)
    }

    public func runSimulation(steps: Int) {
        guard !simulator.isHalted else {
            logger.error("Can not run halted simulator")
            return
        }
        guard steps > 0 else {
            logger.error("Number of steps to run must be grater than 0")
            return
        }

        let stepsRun: Int

        stepsRun = simulator.run(steps: steps) { (_, signal) in
            if !signal.traps.isEmpty {
                print("Traps: \(signal.traps)")
            }
            if !signal.notifications.isEmpty {
                print("Notifications: \(signal.notifications)")
            }
        }

        print("Simulation run for \(stepsRun) steps")
    }

    /// Signalst that the interpreter should stop.
    ///
    public func exit() {
        self.shouldStop = true
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

    public func displayStatus() {
        let haltFlag: String

        if simulator.isHalted {
            haltFlag = "halted"
        }
        else {
            haltFlag = "ready"
        }
        print("""
        Status: \(haltFlag)
        """)
        // TODO: Display last notifications and traps
    }

    public func resetSimulation() {
        print("(NOT YET) RESET")
    }

    /// Imports model from path.
    ///
    public func importModel(path: String){
        let compiler = ModelCompiler(model: model)
        let source: String

        logger.info("Loading model from \(path)...")

        do {
            source = try String(contentsOfFile: path, encoding:String.Encoding.utf8)
        } catch {
            logger.error("Unable to read model '\(path)'")
            return
            // FIXME: throw exception. this is remnant from Tool
        }

        logger.info("Compiling model...")
        compiler.compile(source: source)
    }

    /// Prints symbol table of the current model
    ///
    public func printSymbolTable() {
        let symbols = model.symbols
        print("Symbol Table:")
        symbols.sorted { rhs, lhs in
            lhs.key.lowercased() > rhs.key.lowercased()
        }
        .forEach {
            print("    \($0.key) \($0.value.rawValue)")
        }
    }

    /// Create objects from worls.
    ///
    func createWorld(_ name: String) {
        guard model.worlds[name] != nil else {
            logger.error("No world with name '\(name)' found")
            // FIXME: Better exit
            fatalError("No world \(name)")
        }
        simulator.simulation.createWorld(name)
    }


}
