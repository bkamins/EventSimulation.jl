@testset "SimQueue FIFO/LIFO, Resource FIFO/LIFO" begin
    function qfifo(fq, fr)
        tmp = []
        q = SimQueue{Int}(max_queue = 5, max_requests = 3,
                          fifo_queue = fq, fifo_requests = fr)
        s = Scheduler()

        @test request!(s, q, (x, y) -> push!(tmp, (1, y)))
        @test request!(s, q, (x, y) -> push!(tmp, (2, y)))
        @test request!(s, q, (x, y) -> push!(tmp, (3, y)))
        @test !request!(s, q, (x, y) -> push!(tmp, (4, y)))
        @test length(q.requests) == 3
        @test provide!(s, q, 1)
        s.now = 1.0
        @test provide!(s, q, 2)
        s.now = 2.0
        @test provide!(s, q, 3)
        @test length(q.queue) == 0
        @test length(s.event_queue) == 3
        @test length(q.requests) == 0
        @test provide!(s, q, 4)
        @test provide!(s, q, 5)
        @test provide!(s, q, 6)
        @test provide!(s, q, 7)
        @test provide!(s, q, 8)
        @test !provide!(s, q, 9)
        @test length(q.queue) == 5
        s.now = 3.0
        @test request!(s, q, (x, y) -> push!(tmp, (4, y)))
        s.now = 4.0
        @test request!(s, q, (x, y) -> push!(tmp, (5, y)))
        s.now = 5.0
        @test request!(s, q, (x, y) -> push!(tmp, (6, y)))
        @test length(q.queue) == 2

        go!(s, 6.0)
        tmp
    end

    @test qfifo(true, true) == [(1,1), (2,2), (3,3), (4,4), (5,5), (6,6)]
    @test qfifo(true, false) == [(3,1), (2,2), (1,3), (4,4), (5,5), (6,6)]
    @test qfifo(false, true) == [(1,1), (2,2), (3,3), (4,8), (5,7), (6,6)]
    @test qfifo(false, false) == [(3,1), (2,2), (1,3), (4,8), (5,7), (6,6)]
end

@testset "SimQueue waive! test" begin
    s = Scheduler()
    q = SimQueue{Int}()
    @test !waive!(q, identity)

    f1 = x -> println(1)
    f2 = x -> println(2)
    f3 = x -> println(3)
    request!(s, q, f1)
    request!(s, q, f2)
    request!(s, q, f3)

    @test length(q.requests) == 3
    @test waive!(q, f2)
    @test length(q.requests) == 2
    @test !waive!(q, f2)
    @test waive!(q, f1)
    @test waive!(q, f3)
    @test isempty(q.requests)
end

@testset "SimQueue withdraw! test" begin
    s = Scheduler()
    q = SimQueue{Int}()
    @test !withdraw!(q, 1)

    provide!(s, q, 1)
    provide!(s, q, 2)
    provide!(s, q, 3)

    @test length(q.queue) == 3
    @test withdraw!(q, 2)
    @test length(q.queue) == 2
    @test !withdraw!(q, 2)
    @test withdraw!(q, 1)
    @test withdraw!(q, 3)
    @test isempty(q.queue)
end

