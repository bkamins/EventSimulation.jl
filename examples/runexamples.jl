d = readdir()

for f in d
    if isfile(f) && ismatch(r"\.jl$", f) && f != PROGRAM_FILE
        println("\n*** Running: $f ***")
        run(`julia $f`)
    end
end

