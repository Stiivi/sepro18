import Compiler
import Logging
import Simulator
import Simulation
import Model


// TODO: handle errors
// TODO: Consolidate logging
// TODO: Consolidate printing output

public final class Shell {
    let logger = Logger(label: "sepro.main")
    let boo = 1234
    // Interpreter context
    let model: Model
    let simulator: IterativeSimulator<SeproSimulation>

    let outputURL: String?
    let outputs: [CaptureOutput]

    public internal(set) var shouldStop: Bool

    /// Create an empty shell with an empty model, empty simulation and a
    /// simulator.
    ///
    public convenience init(outputURL: String? = nil) {
        let simulation = SeproSimulation(model: Model())
        let simulator = IterativeSimulator(simulation: simulation)
        self.init(outputURL: outputURL, simulator: simulator)
    }

    public init(outputURL: String?, simulator: IterativeSimulator<SeproSimulation>) {
        shouldStop = false
        self.outputURL = outputURL
        self.simulator = simulator
        self.model = self.simulator.simulation.model

        if let outputURL = outputURL {
            // FIXME: Use proper path building functions
            let snapshotPath = outputURL + "/scene.dot"
            let sequencePath = outputURL // TODO: Let's check for dots/ here
            self.outputs = [
                DotGraphFileSnapshot(path:snapshotPath, simulator: simulator),
                DotGraphFileSequence(path:sequencePath, simulator: simulator)
            ]
        }
        else {
            self.outputs = []
        }
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

        outputs.forEach { $0.willBeginCapture() }

        // Write initial state
        self.outputs.forEach { $0.captureScene() }

        stepsRun = simulator.run(steps: steps) { (_, signal) in
            if !signal.traps.isEmpty {
                print("Traps: \(signal.traps)")
            }
            if !signal.notifications.isEmpty {
                print("Notifications: \(signal.notifications)")
            }

            // TODO: Capture notifications and traps as well.
            self.outputs.forEach { $0.captureScene() }
        }

        outputs.forEach { $0.finalizeCapture() }

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

        logger.info("Model compiled")
        logger.info("    Symbol count    : \(model.symbols.count)")
        logger.info("    Unary actuators : \(model.unaryActuators.count)")
        logger.info("    Binary actuators: \(model.unaryActuators.count)")

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
    public func createWorld(_ name: String) {
        guard model.worlds[name] != nil else {
            logger.error("No world with name '\(name)' found")
            // FIXME: Better exit
            fatalError("No world \(name)")
        }
        simulator.simulation.createWorld(name)
    }
}
