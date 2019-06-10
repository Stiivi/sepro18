import Simulator
import Simulation
import Foundation


/*
    $OUTPUT
        current.dot
        recording/
            step${STEP}.dot

*/

public final class DotGraphFileSequence: CaptureOutput {
    let outputPath: String
    let dotsPath: String
    let simulator: SeproSimulator
    let writer: SeproDotWriter

    // FIXME: See protocol Recorder note about init()
    required public init(path: String, simulator: SeproSimulator) {
        outputPath = path
        // FIXME: Use proper path construction here
        dotsPath = outputPath + "/dots"
        self.simulator = simulator
        self.writer = SeproDotWriter()
    }

	public func willBeginCapture() {
        // FIXME: Unite with view's equivalent of this

        // Create output directories
        // -----------------------------------------------------------------------
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: outputPath) else {
            // FIXME: Test for directory as well. We don't do that because the
            // file manager is using ObjCBool
            fatalError("Output directory '\(outputPath)' does not exist")
        }

        do {
            try fileManager.createDirectory(atPath:dotsPath,
                                            withIntermediateDirectories: true)
        }
        catch {
            fatalError("Unable to create dot files directory '\(dotsPath)'")
        }

		// writeDot(path: dotFileName(sequence: simulator.stepCount))
	}

    public func captureScene() {
		let name = String(format: "%06d.dot", simulator.stepCount)
        // FIXME: Use proper path construction method
		let fullPath = "\(dotsPath)/\(name)"
        writer.write(to: fullPath, simulator: simulator)
    }

    public func finalizeCapture() {
        // Do nothing
    }

}

public final class DotGraphFileSnapshot: CaptureOutput {
    let simulator: IterativeSimulator<SeproSimulation>
    let outputPath: String

    required public init(path: String, simulator: IterativeSimulator<SeproSimulation>) {
        self.simulator = simulator
        self.outputPath = path
    }

    public func captureScene() {
        let writer = SeproDotWriter()
        writer.write(to: outputPath, simulator: simulator)
    }

    public func willBeginCapture() {
        // Do nothing
    }

    public func finalizeCapture() {
        // Do nothing
    }

	func prepareOutput() {
        // FIXME: Unite with recorder's equivalent of this

        // Create output directories
        // -----------------------------------------------------------------------
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: outputPath) else {
            // FIXME: Test for directory as well. We don't do that because the
            // file manager is using ObjCBool
            fatalError("Output directory '\(outputPath)' does not exist")
        }

		// writeDot(path: dotFileName(sequence: simulator.stepCount))
	}


}
