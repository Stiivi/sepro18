import Compiler

public final class CommandCompiler {
    public func compile(command ast: ASTCommand) throws -> Command? {
        switch ast {
        case .exit: return ExitCommand()
        case .help: return HelpCommand()
        case .step: return StepCommand()
        case .reset: return ResetCommand()
        case .run(let value): return RunCommand(steps: value)
        }
        return nil
    }

}
