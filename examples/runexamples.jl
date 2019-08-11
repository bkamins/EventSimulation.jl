d = readdir()

for f in d
    if isfile(f) && occursin(r"\.jl$", f) && f != "runexamples.jl"
        println("\n\n*** Running: $f ***")
        run(`julia $f`)
    end
end
