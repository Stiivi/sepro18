import Simulator
import Simulation
import Foundation

// TODO: Add sessions
// TODO: See AVCaptureOutput for some API inspiration

public typealias SeproSimulator = IterativeSimulator<SeproSimulation>

public protocol CaptureOutput {
    // FIXME: This shold be URL or something more generic
    init(path: String, simulator: SeproSimulator)

    func willBeginCapture()
    func captureScene()
    func finalizeCapture()
}

