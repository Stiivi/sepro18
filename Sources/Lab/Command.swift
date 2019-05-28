/// Interpreter commands
///
public protocol Command {
    static var commandName: String { get }

    /// Short description of the command
    static var synopsis: String { get }

    /// Apply the command to the `interpreter`
    func apply(interpreter: CommandInterpreter)
}

public let allCommands: [Command.Type] = [
    ExitCommand.self,
    HelpCommand.self,
    StepCommand.self,
    ResetCommand.self,
    RunCommand.self,
]


public class DoNothingCommand: Command {
    public static let synopsis = "Do nothing"
    public static let commandName = "nothing"

    public func apply(interpreter: CommandInterpreter) {
        // do nothing
    }
}

public class ExitCommand: Command {
    public static let synopsis = "Exit the interpreter"
    public static let commandName = "exit"

    public func apply(interpreter: CommandInterpreter) {
        interpreter.exit()
    }
}

public class HelpCommand: Command {
    public static let synopsis = "Print command help"
    public static let commandName = "help"

    public func apply(interpreter: CommandInterpreter) {
        interpreter.displayHelp()
    }
}

public class StepCommand: Command {
    public static let synopsis = "Run one step of the simulation"
    public static let commandName = "step"

    public func apply(interpreter: CommandInterpreter) {
        interpreter.stepSimulation()
    }
}

public class ResetCommand: Command {
    public static let synopsis = "Reset the simulation"
    public static let commandName = "reset"

    public func apply(interpreter: CommandInterpreter) {
        interpreter.resetSimulation()
    }
}

// FIXME: Should be simulation command
public class RunCommand: Command {
    public static let synopsis = "Run simulation for number of steps"
    public static let commandName = "run"

    let steps: Int

    public init(steps: Int) {
        self.steps = steps
    }

    public func apply(interpreter: CommandInterpreter) {
        interpreter.runSimulation(steps: steps)
    }
}
