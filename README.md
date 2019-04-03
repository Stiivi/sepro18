# Sepro18

Sepro - Method for modeling and simulation. Inspired by biochemistry.

See [Introduction slides](https://www.slideshare.net/Stiivi/sepro-introduction)


# Requirements

- [Swift](https://swift.org/download/) 5.0

Uses the following packages (no need to download, included in the Package
manifest):

- [DotWriter](https://github.com/stiivi/DotWriter) - for generating
    [Graphviz](https://www.graphviz.org) output.


# Build

```
swift build
```

# Run examples

Command `sepro MODEL STEPS` runs the model for given number of steps and
generates output into `./out/dots`.

```
swift run Models/linker.sepro 10
```

Other options for the command-line tool:

```
  --help            List options
  --dump-symbols    Dump symbol table.
  -o DIR            Output directory. Default: ./out
  -w WORLD          World name to initialize simlation. Default: main
```

# Language Reference

Model is composed of model objects: actuators, structures and worlds. Each
element of the model is identified by a _symbol_. 

Symbol definition:

```
DEF TAG open
DEF TAG closed
DEF TAG hungry

DEF SLOT next
DEF SLOT site
DEF SLOT complement 
```

## Actuators

There are two kinds of actuators: unary `ACT`  and binary `REACT`. The unary
actuator operates on a selection of objects matching the `WHERE` selector
pattern. The symbols of type _tag_ are tested against object's tags and symbols
of type _slot_ are tested against object's bindings. `!` operator negates the
presence - denotes absence of given symbol.

The selector is followed by list of transitions which have form `IN subject
transitions`. In unary actuators the subject is `THIS`, in binary actuator the subject
can be `LEFT` or `RIGHT` representing left side of the selector or right side
of the selector respectively. The subject can be made indirect by adding
indirection slot such as `THIS.site` or `THIS.next`.

Transitions can be:

- `SET tag` to set a tag.
- `UNSET tag` to unset a tag. 
- `BIND slot TO target` to create a new binding.
- `UNBIND slot` to remove a binding.

In unary transition if the target for a binding is the same as the selected
object then it is referred to as `THIS`. In binary binding we can't refer to
the object of the same "hand" (by design), only to the object from the other
hand which we call `OTHER`.

Unary actuators:

```
ACT move
    WHERE (crawler node.next)
    IN THIS
        BIND node TO node.next

ACT detach
    WHERE (crawler !node.next)
    IN THIS
        UNBIND node
        SET free


ACT bind_complement
    WHERE (polymerase init t_site.nucleotide c_site.nucleotide)
    IN THIS
        UNSET init
        SET shift

    IN THIS.t_site
        BIND complement TO c_site
```

Binary actuators:

```
REACT close_box
    WHERE (box open) ON (lid free)
    IN LEFT
        SET closed
        UNSET open
        BIND top TO OTHER
    IN RIGHT
        UNSET free

REACT r_origin
    WHERE (polymerase !t_site !c_site)
        ON (nucleotide origin)
    IN LEFT
        BIND t_site TO OTHER
```

## Initial State

The initial state is described through structures and worlds. Structure is a
simple graph definition with list of objects and bindings (edges). The object
definition has form: `OBJ name (tags)`. The scope object's name is only
the structure the object is contained in. The binding has form `BIND object.slot
TO target_object`. Only objects defined within the same structure can be used
for the bindings.

Example structures:

```
STRUCT triangle
    OBJ a (node)
    OBJ b (node)
    OBJ c (node)
    BIND a.next TO b
    BIND b.next TO c
    BIND c.next TO a


STRUCT strand
    OBJ n1 (nucleotide G origin)
    OBJ n2 (nucleotide A)
    OBJ n3 (nucleotide T)
    OBJ n4 (nucleotide T)
    OBJ n5 (nucleotide A)
    OBJ n6 (nucleotide C)
    OBJ n7 (nucleotide A)
    BIND n1.next TO n2
    BIND n2.next TO n3
    BIND n3.next TO n4
    BIND n4.next TO n5
    BIND n5.next TO n6
    BIND n6.next TO n7
```

The initial state of a simulation is defined by _world_ which can be though as
"ingredients" of the simulated universe. The world items are specified as
`count (tags)` for copies of free-standing objects and `count structure_name`
for copies of a given structure.

Example world:


```
WORLD main
    3 (free nucleotide A)
    3 (free nucleotide C)
    3 (free nucleotide T)
    3 (free nucleotide G)
    1 strand
    1 (polymerase)
```


## Data

Model can have (meta) data associated with it. The data is not relevant to the
simulation itself, but might be used by the simulator or a visualisation
component. The data has form: `DATA (tags) "text"`. The tags are being used by
the tools as a key either by chosing all items that contain particuliar tag or
all items that match all the tags. One has to refer to the tool documentation
to learn how the key is used.

Example data:

```
DATA (dot_style nucleotide) "rounded"
DATA (dot_color A) "salmon"
DATA (dot_color C) "slateblue"
DATA (dot_color T) "sandybrown"
DATA (dot_color G) "skyblue"
DATA (dot_style polymerase) "filled"
DATA (dot_fillcolor polymerase) "gold"
```

# Author

Stefan Urbanek [stefan.urbanek@gmail.com](mailto:stefan.urbanek@gmail.com)

# Thanks

Thanks to Ľubomir Sepro Lanátor.

