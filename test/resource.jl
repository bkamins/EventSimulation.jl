function rfifo(fr)
    println("SimResource FIFO: $fr")
    r = SimResource{Int}(quantity=5, lo=0, hi=5,
                         max_requests=3, fifo_requests=fr)
    s = Scheduler()
    @test_throws ErrorException SimResource{Int}(quantity=0, lo=1, hi=5)
    @test_throws ErrorException SimResource{Int}(quantity=3, lo=3, hi=2)

    @test request!(s, r, 2, x -> println(1))[1]
    s.now = 1.0
    @test request!(s, r, 2, x -> println(2))[1]
    @test request!(s, r, 2, x -> println(3))[1]
    @test request!(s, r, 2, x -> println(4))[1]
    @test request!(s, r, 2, x -> println(5))[1]
    @test !request!(s, r, 2, x -> println(6))[1]
    @test length(r.requests) == 3
    s.now = 2.0
    @test provide!(s, r, 1) == 1
    @test request!(s, r, 2, x -> println(7))[1]
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

println("SimResource waive! test")
s = Scheduler()
r = SimResource{Int}()
@test !waive!(r, ResourceRequest(1, identity))

rr1 = request!(s, r, 2, x -> println(2))[2]
rr2 = request!(s, r, 2, x -> println(3))[2]
rr3 = request!(s, r, 2, x -> println(4))[2]

@test length(r.requests) == 3
@test waive!(r, rr2)
@test length(r.requests) == 2
@test !waive!(r, rr2)
@test waive!(r, rr1)
@test waive!(r, rr3)
@test isempty(r.requests)

