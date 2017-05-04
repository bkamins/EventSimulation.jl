function rfifo(fr)
    println("Resource FIFO: $fr")
    r = Resource{Int}(quantity=5, lo=0, hi=5,
                      max_requests=3, fifo_requests=fr)
    s = Scheduler()
    @test_throws ErrorException Resource{Int}(quantity=0, lo=1, hi=5)
    @test_throws ErrorException Resource{Int}(quantity=3, lo=3, hi=2)

    @test request!(s, r, 2, x -> println(1))
    s.now = 1.0
    @test request!(s, r, 2, x -> println(2))
    @test request!(s, r, 2, x -> println(3))
    @test request!(s, r, 2, x -> println(4))
    @test request!(s, r, 2, x -> println(5))
    @test !request!(s, r, 2, x -> println(6))
    @test length(r.requests) == 3
    s.now = 2.0
    @test provide!(s, r, 1) == 1
    @test request!(s, r, 2, x -> println(7))
    s.now = 3.0
    @test provide!(s, r, 10) == 5

    # visual inspection needed - order of tuple dimensions should be the same
    go!(s, 6.0)
    @test length(r.requests) == 1
    print("Pending request number: ")
    r.requests[1].request(s)
end

println("\nExpected order: 1,2,3,4,5; pending: 7")
rfifo(true)
println("\nExpected order: 1,2,5,7,4; pending: 3")
rfifo(false)
