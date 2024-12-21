using Tar
using TOML
using PeriodicTable
using Inflate
using SHA

BASEURL = "https://github.com/JuliaMolSim/PseudoLibrary/raw/main/artifacts/"
KNOWN_FUNCTIONALS = ["pbe", "lda", "pbesol"]
KNOWN_EXTENSIONS  = ["xml", "upf", "hgh", "psp8"]

function check_valid_meta(folder, meta::AbstractDict)
    if !(meta["type"] in ("nc", "paw", "us"))
        error("Invalid type: $(meta["type"]) (in $folder)")
    end
    if !(meta["relativistic"] in ("sr", "fr"))
        error("Invalid relativistic: $(meta["relativistic"]) (in $folder)")
    end
    if !(meta["functional"] in KNOWN_FUNCTIONALS)
        error("Unusual functional: $(meta["functional"]) (in $folder)")
    end
    if !(meta["extension"] in KNOWN_EXTENSIONS)
        error("Unusual extension: $(meta["extension"]) (in $folder)")
    end
end

function artifact_name(meta::AbstractDict)
    join((meta["family"], meta["type"], meta["relativistic"],
          meta["functional"], replace(meta["version"], "." => "_"),
          meta["program"], join(meta["extra"], "."), meta["extension"]), ".")
end

function collect_meta(folder)
    meta = open(TOML.parse, joinpath(folder, "meta.toml"), "r")
    element_meta = Dict{String,Any}()
    elements = String[]

    for element in getproperty.(PeriodicTable.elements, :symbol)
        if isfile(joinpath(folder, element * "." * meta["extension"]))
            push!(elements, element)
        end
        if isfile(joinpath(folder, element * ".toml"))
            data = open(TOML.parse, joinpath(folder, element * ".toml"), "r")
            for (key, value) in pairs(data)
                get!(element_meta, key, Dict{String,Any}())[element] = value
            end
        end
    end
    meta["elements"] = elements

    for (key, value) in element_meta
        if key in keys(meta)
            @warn "Element-specific key \"$key\" overwriting pseudofamily meta"
        end
        meta[key] = value
    end

    check_valid_meta(folder, meta)

    meta
end

function pseudo_folders(path)
    [root for (root, dirs, files) in walkdir(path) if "meta.toml" in files]
end

function main(pseudopath, output)
    @assert isdir(pseudopath)
    @assert !isdir(output)
    mkpath(output)

    folders = pseudo_folders(pseudopath)
    @info "Found pseudo folders:" folders

    artifacts = Dict{String,Any}()
    for folder in folders
        meta = collect_meta(folder)
        name = artifact_name(meta)

        targetfile = joinpath(output, "$(name).tar.gz")
        @info "Generating $targetfile"
        folder = abspath(folder)
        targetfile = abspath(targetfile)
        cd(folder) do
            files = [e * "." * meta["extension"] for e in meta["elements"]]
            @assert all(isfile, files)
            withenv("GZIP" => -9) do # Increase compression level
                run(`tar --use-compress-program="pigz -k" -cf $targetfile $(files)`)
            end
        end

        meta["git-tree-sha1"] = Tar.tree_hash(IOBuffer(inflate_gzip(targetfile)))
        meta["lazy"] = true
        meta["download"] = [Dict(
            "url" => "$BASEURL/$name.tar.gz",
            "sha256" => bytes2hex(open(sha256, targetfile))
        )]

        artifacts[name] = meta
    end

    @info "Generating $(joinpath(output, "Artifacts.toml"))"
    open(joinpath(output, "Artifacts.toml"), "w") do io
        TOML.print(io, artifacts)
    end
end

(abspath(PROGRAM_FILE) == @__FILE__) && main(ARGS[1], ARGS[2])
