using Statistics

@testset "Testing core Scheduler creation" begin
    es = EmptyState()
    sReal = Scheduler{EmptyState, Real}(1.2, Vector{EventSimulation.Action{Real}}(),
                                        es, (a,b)->nothing)
    @test isa(sReal, Scheduler{EmptyState, Real})
    @test sReal.now == 1.2
    @test isempty(sReal.event_queue)
    @test isa(sReal.state, EmptyState)
    @test isa(sReal.monitor(0, sReal), Nothing)
end

@testset "Testing if register! and go! produce correct order" begin
    s = Scheduler()

    mlen = 100
    ts = (1.0:mlen)[randperm(mlen)]

    for x in ts
        register!(s, z -> push!(v, z.now), x)
    end

    v = Float64[]
    go!(s, mlen)
    @test v == [1.0:mlen;]
    @test length(s.event_queue) == 0
end

@testset "Testing register! and terminate! for correct number of elements" begin
    s = Scheduler()

    mlen = 100
    ts = (1.0:mlen)[randperm(mlen)]
    for x in ts
        register!(s, z -> push!(v, z.now), x)
    end

    @test length(s.event_queue) == mlen
    terminate!(s)
    @test length(s.event_queue) == 0
end

@testset "Testing repeat_register!" begin
    s = Scheduler()
    rrv = []
    f(x) = push!(rrv, x.now)
    ifun(x) = x.now + 1
    repeat_register!(s, f, ifun)
    go!(s, 50)
    @test rrv == [1,3,7,15,31]

    s = Scheduler()
    rrv = []
    f(x) = push!(rrv, x.now)
    ifun2(x) = length(rrv) < 5 ? x.now + 1 : NaN
    repeat_register!(s, f, ifun2)
    go!(s)
    @test length(rrv) == 5
end

@testset "Testing ordered bulk_register!" begin
    s = Scheduler()
    v2 = []
    who = [1:5;]
    for x in randperm(10)
        bulk_register!(s, who, (a,b) -> push!(v2, (s.now, b)), Float64(x), false)
    end
    go!(s, 11)
    v2t = []
    for i in 1.0:10.0, j in 1:5
        push!(v2t, (i, j))
    end

    @test v2 == v2t
end

@testset "Testing random bulk_register!" begin
    tmp_store = []
    s = Scheduler()
    v2 = []
    who = [1:100;]
    for x in randperm(10)
        bulk_register!(s, who, (a,b) -> push!(tmp_store, (s.now, b)), Float64(x), true)
    end
    go!(s, 11)
    v = getindex.(tmp_store, 1)
    @test v == sort(v)
    l = unique(v)
    for k in l
        r = [tmp_store[i][2] for i in 1:length(tmp_store) if tmp_store[i][1] == k]
        @test r != sort(r)
    end
end

@testset "Testing ordered repeat_bulk_register!" begin
    s = Scheduler()
    v2 = []
    who = [1:5;]
    repeat_bulk_register!(s, who, (a,b) -> push!(v2, (s.now, b)), x -> 1.0, false)
    go!(s, 10)
    v2t = []
    for i in 1.0:10.0, j in 1:5
        push!(v2t, (i, j))
    end

    @test v2 == v2t

    s = Scheduler()
    v2 = []
    who = [1:5;]
    repeat_bulk_register!(s, who, (a,b) -> push!(v2, (s.now, b)),
                          x -> length(v2) < length(v2t) ? 1.0 : nothing, false)
    go!(s)

    @test v2 == v2t
end

@testset "Testing random repeat_bulk_register!. Visual inspection required." begin
    tmp_store = []
    s = Scheduler()
    v2 = []
    who = [1:100;]
    repeat_bulk_register!(s, who, (a,b) -> push!(tmp_store, (s.now, b)), x -> 1.0, true)
    go!(s, 10)

    v = getindex.(tmp_store, 1)
    @test v == sort(v)
    l = unique(v)
    for k in l
        r = [tmp_store[i][2] for i in 1:length(tmp_store) if tmp_store[i][1] == k]
        @test r != sort(r)
    end
end

@testset "Testing interrupt." begin
    s = Scheduler()
    @test interrupt!(s, EventSimulation.Action(identity, 1.0)) == false
    for i in 1:10
        register!(s, identity, rand())
    end

    OK = []
    a = register!(s, x -> push!(OK, false), rand())

    for i in 1:10
        register!(s, identity, rand())
    end

    @test interrupt!(s, a) == true
    go!(s, 1.0)
    @test isempty(OK)
end

@testset "Testing monitor." begin
    s = Scheduler()
    deltas = Float64[]
    s.monitor = (s,Δ) -> push!(deltas, Δ)
    repeat_register!(s, x -> nothing, x -> rand())
    go!(s, 100_000)
    m = mean(deltas)
    v = var(deltas)
    @test max(abs(m-0.5), abs(v-1/12)) < 0.005
end

