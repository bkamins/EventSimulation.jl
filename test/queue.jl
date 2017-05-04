function qfifo(fq, fr)
    println("Queue FIFO: $fq\tResource FIFO: $fr")
    q = Queue{Int}(max_queue = 5, max_requests = 3,
                   fifo_queue = fq, fifo_requests = fr)
    s = Scheduler()

    @test request!(s, q, (x, y) -> println((1, y)))
    @test request!(s, q, (x, y) -> println((2, y)))
    @test request!(s, q, (x, y) -> println((3, y)))
    @test !request!(s, q, (x, y) -> println((4, y)))
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
    @test request!(s, q, (x, y) -> println((4, y)))
    s.now = 4.0
    @test request!(s, q, (x, y) -> println((5, y)))
    s.now = 5.0
    @test request!(s, q, (x, y) -> println((6, y)))
    @test length(q.queue) == 2

    # visual inspection needed - order of tuple dimensions should be the same
    go!(s, 6.0)
end

qfifo(true, true)
qfifo(true, false)
qfifo(false, true)
qfifo(false, false)

