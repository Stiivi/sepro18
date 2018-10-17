# Sepro18

Sepro - Method for modeling and simulation. Inspired by biochemistry.

See [Introduction slides](https://www.slideshare.net/Stiivi/sepro-introduction)


# Requirements

- [Swift](https://swift.org/download/) 4.2

Uses the following packages (no need to download, included in the Package
manifest):

- [ParserCombinator](https://github.com/stiivi/ParserCombinator) - for model
    language parsing.
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


# Author

Stefan Urbanek [stefan.urbanek@gmail.com](mailto:stefan.urbanek@gmail.com)

# Thanks

Thanks to Ľubomir Sepro Lanátor.

