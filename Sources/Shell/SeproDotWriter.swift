import DotWriter

// Iterative Simulator
import Simulator

// SeproSimulation for typealias
import Simulation
// DataItem
import Model

// FIXME: Remove this
typealias _SeproSimulator = IterativeSimulator<SeproSimulation>

// TODO: Include node and arrow styles
public class SeproDotWriter {
    func write(to outputPath: String, simulator: _SeproSimulator) {
        let writer = DotWriter(path: outputPath,
                               name: "g",
                               type: .directed)
        let graph = simulator.simulation.state.graph

        for object in graph.objects {
            // Get raw dot attribute string for every tag of the object
            // FIXME: This is _very_ unsafe, but helps us style our output for
            // the time being
            let tags = object.state.tags
            var attributeData: [String:[DataItem]] = [:]
            attributeData["color"] = tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_color", $0]))
            }
            attributeData["shape"] = tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_shape", $0]))
            }
            attributeData["style"] = tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_style", $0]))
            }
            attributeData["fillcolor"] = tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_fillcolor", $0]))
            }
            writeObject(oid: object.reference, object: object.state, attributeData: attributeData, into: writer)

            // Edges
            // ----------------

            for (slot, target) in object.references {
                var edgeAttrs: [String: String] = [:]

                // TODO: Default attributes
                edgeAttrs["label"] = slot
                edgeAttrs["fontname"] = "Helvetica"
                edgeAttrs["fontsize"] = "9"

                writer.writeEdge(from: object.reference.description,
                                 to: target.description,
                                 attributes: edgeAttrs)
            }
        }

        writer.close()
    }

	/// Write object node and it's relationships from slots. Nodes
	/// are labelled with object ids.
	func writeObject(oid: OID, object: SimulationState.ObjectState,
                  attributeData: [String:[DataItem]], into writer: DotWriter) {
		var attrs: [String:String] = [:]
		let tagsString = object.tags.sorted().joined(separator:",")
		let label = "\(oid):\(tagsString)"

        let color = attributeData["color"]?.first {
            !$0.tags.isDisjoint(with:object.tags)
        }?.text

        let shape = attributeData["shape"]?.first {
            !$0.tags.isDisjoint(with:object.tags)
        }?.text

        let style = attributeData["style"]?.first {
            !$0.tags.isDisjoint(with:object.tags)
        }?.text
        let fillcolor = attributeData["fillcolor"]?.first {
            !$0.tags.isDisjoint(with:object.tags)
        }?.text

        // Node
        // ----------------

		attrs["fontname"] = "Helvetica"
        attrs["color"] = color ?? "black"
        attrs["fillcolor"] = fillcolor ?? "white"
		attrs["shape"] = shape ?? "box"
		attrs["style"] = style ?? "rounded"
        attrs["label"] = label
		attrs["fontsize"] = "11"
        writer.writeNode(oid.description, attributes: attrs)

	}

}
