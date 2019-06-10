import Compiler

public final class CommandCompiler {
    func compile(command ast: ASTCommand) throws -> Command? {
        switch ast {
        case .nothing: return DoNothingCommand()
        case .exit: return ExitCommand()
        case .help: return HelpCommand()
        case .status: return StatusCommand()
        case .halt: return SetHaltFlagCommand(halt: true)
        case .unhalt: return SetHaltFlagCommand(halt: false)
        case .step: return StepCommand()
        case .reset: return ResetCommand()
        case .run(let value): return RunCommand(steps: value)
        }
    }

}
