/// Interpreter commands
///
public protocol Command {
    func apply(interpreter: CommandInterpreter)
}

public class ExitCommand: Command {
    public func apply(interpreter: CommandInterpreter) {
        interpreter.stop()
    }
}

public class HelpCommand: Command {
    public func apply(interpreter: CommandInterpreter) {
        interpreter.help()
    }
}

public class StepCommand: Command {
    public func apply(interpreter: CommandInterpreter) {
        interpreter.step()
    }
}

public class ResetCommand: Command {
    public func apply(interpreter: CommandInterpreter) {
        interpreter.reset()
    }
}

// FIXME: Should be simulation command
public class RunCommand: Command {
    let steps: Int

    public init(steps: Int) {
        self.steps = steps
    }

    public func apply(interpreter: CommandInterpreter) {
        interpreter.run(steps: steps)
    }
}
