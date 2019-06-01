/// Interpreter commands
///
public protocol Command {
    static var commandName: String { get }

    /// Short description of the command
    static var synopsis: String { get }

    /// run the command to the `interpreter`
    func run(shell: Shell)
}

public let allCommands: [Command.Type] = [
    ExitCommand.self,
    HelpCommand.self,
    StatusCommand.self,
    StepCommand.self,
    ResetCommand.self,
    RunCommand.self
]

public class DoNothingCommand: Command {
    public static let synopsis = "Do nothing"
    public static let commandName = "nothing"

    public func run(shell: Shell) {
        // do nothing
    }
}

public class ExitCommand: Command {
    public static let synopsis = "Exit the interpreter"
    public static let commandName = "exit"

    public func run(shell: Shell) {
        shell.exit()
    }
}

public class HelpCommand: Command {
    public static let synopsis = "Print command help"
    public static let commandName = "help"

    public func run(shell: Shell) {
        shell.displayHelp()
    }
}

public class StatusCommand: Command {
    public static let synopsis = "Print simulator status"
    public static let commandName = "status"

    public func run(shell: Shell) {
        shell.displayStatus()
    }
}

public class SetHaltFlagCommand: Command {
    public static let synopsis = "Print simulator status"
    public static let commandName = "status"

    public let haltFlag: Bool

    public init(halt: Bool) {
        haltFlag = halt
    }

    public func run(shell: Shell) {
        // do nothing
    }
}


public class StepCommand: Command {
    public static let synopsis = "Run one step of the simulation"
    public static let commandName = "step"

    public func run(shell: Shell) {
        shell.runSimulation(steps: 1)
    }
}

public class ResetCommand: Command {
    public static let synopsis = "Reset the simulation"
    public static let commandName = "reset"

    public func run(shell: Shell) {
        // FIXME: do something
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

    public func run(shell: Shell) {
        shell.runSimulation(steps: steps)
    }
}
