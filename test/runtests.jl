using FastCGI
using Test
using Random

function test_types()
    @testset "utility methods" begin
        @test FastCGI.BYTE(0x0102, 1) === 0x02
        @test FastCGI.BYTE(0x0102, 2) === 0x01
        @test FastCGI.B16(0x02, 0x03) === 0x0203
        @test FastCGI.padding(7) == 1
        @test FastCGI.padding(8) == 0
        @test FastCGI.padding(17) == 7
    end

    @testset "read-write nv lengths" begin
        p = PipeBuffer()
        @test FastCGI._writenvlen(p, UInt8(5)) == 1
        @test FastCGI._readnvlen(p) === UInt32(5)
        @test FastCGI._writenvlen(p, UInt16(127)) == 1
        @test FastCGI._readnvlen(p) === UInt32(127)
        @test FastCGI._writenvlen(p, UInt16(128)) == 4
        @test FastCGI._readnvlen(p) === UInt32(128)
        @test FastCGI._writenvlen(p, UInt16(1024)) == 4
        @test FastCGI._readnvlen(p) === UInt32(1024)
    end

    @testset "read-write types" begin
        p = PipeBuffer()
        reqid = UInt16(1)

        # FCGIBeginRequest
        req = FastCGI.FCGIBeginRequest(FastCGI.FCGIRequestRole.RESPONDER, FastCGI.KEEP_CONN)
        rec = FastCGI.FCGIRecord(FastCGI.FCGIHeaderType.BEGIN_REQUEST, reqid, req)
        @test FastCGI.fcgiwrite(p, rec) == 16
        @test FastCGI.FCGIRecord(p) == rec
        reqid += UInt16(1)

        # FCGIEndRequest
        req = FastCGI.FCGIEndRequest(UInt32(10), FastCGI.FCGIEndRequestProtocolStatus.REQUEST_COMPLETE)
        rec = FastCGI.FCGIRecord(FastCGI.FCGIHeaderType.END_REQUEST, reqid, req)
        @test FastCGI.fcgiwrite(p, rec) == 16
        @test FastCGI.FCGIRecord(p) == rec
        reqid += UInt16(1)

        # FCGIUnknownType
        req = FastCGI.FCGIUnknownType(UInt8(20))
        rec = FastCGI.FCGIRecord(FastCGI.FCGIHeaderType.END_REQUEST, reqid, req)
        @test FastCGI.fcgiwrite(p, rec) == 16
        @test FastCGI.FCGIRecord(p) == rec
        reqid += UInt16(1)

        # FCGIParams
        req = FastCGI.FCGIParams()
        push!(req.nvpairs, FastCGI.FCGINameValuePair("name1", "value1"))
        push!(req.nvpairs, FastCGI.FCGINameValuePair("name2", ""))
        push!(req.nvpairs, FastCGI.FCGINameValuePair("name1", randstring(512)))
        push!(req.nvpairs, FastCGI.FCGINameValuePair(randstring(512), randstring(1024)))
        rec = FastCGI.FCGIRecord(FastCGI.FCGIHeaderType.GET_VALUES, reqid, req)
        @test FastCGI.fcgiwrite(p, rec) == 2096
        @test FastCGI.FCGIRecord(p) == rec
        reqid += UInt16(1)
    end
end

function test_bufferedpipe()
    @testset "buffered pipes" begin
        inpipe = Pipe()
        in = FastCGI.BufferedPipe(inpipe; delay=10.0, bytelimit=10)
        out = IOBuffer()
        proc = run(pipeline(`cat`, stdin=inpipe, stdout=out), wait=false)
        write(in, "hello")
        sleep(2)
        @test position(out) == 0
        write(in, "hello")
        sleep(1)
        @test position(out) == 10
        write(in, "hello")
        sleep(2)
        @test position(out) == 10
        sleep(11)
        @test position(out) == 15
        write(in, "hello")
        flush(in)
        sleep(1)
        @test position(out) == 20
        close(in)
        @test !isopen(inpipe)
    end
end

test_types()
test_bufferedpipe()