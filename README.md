# PseudoLibrary

Next generation version of https://github.com/JuliaMolSim/PseudoLibrary

## How to add a pseudo family
- Add a folder with the files `element.extension`
- Add a file `meta.toml` into the folder

## How to release a new version
- Update the `VERSION` variable in `scripts/make_artifacts.jl`
- Make a tag of the form `v0.0.0` and push the tag
