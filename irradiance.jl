using PortAudio, SampledSignals, DSP

include("./ParseConfig.jl")
include("./UpdateMethods.jl")

mode = "0"
function main()
    audio = PortAudioStream()
    udpsock = UDPSocket()
    numLED = 600
    leddata = [zeros(3) for i in 1:numLED]
    @async begin
        while true
            temp = readline(STDIN)
            if temp[1] in "0123456789"
                mode = temp[1]
            end
        end
    end
    while true
        parseAndUpdate(read(audio,(1/30)s),leddata,udpsock)
    end

end
function parseAndUpdate(audioSamp, leddata, socket)
    spec = fft(audioSamp[:,1])

    if mode == "0"
        leddata = getBarsFrame(leddata, audioSamp[:,1], spec)
    end
    push(leddata, socket)
end
function toHexString(num)
    num <= 255 || error("Input Error")
    magic = "0123456789ABCDEF"
    num1 = floor(Int, num / 16)
    num2 = convert(Int, num % 16)
    return "$(magic[num1+1])$(magic[num2+1])"
end
function push(rawdata, socket)
    data = zeros(UInt8, size(rawdata)[1]*3)
    for i in eachindex(rawdata)
        data[(3*i-2)] = convert(UInt8, rawdata[i][1])
        data[(3*i-2)+1] = convert(UInt8, rawdata[i][2])
        data[(3*i-2)+2] = convert(UInt8, rawdata[i][3])
    end
    #println(data)
    send(socket, ip"127.0.0.1", 8080, data)
end
