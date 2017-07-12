using PortAudio, SampledSignals, DSP

include("./ParseConfig.jl")
include("./UpdateMethods.jl")

function main()
    signal_channel = Channel{String}(1)
    audio = PortAudioStream()
    udpsock = UDPSocket()
    numLED = 600
    leddata = [zeros(3) for i in 1:numLED]
    valid_modes = r"\d{1,2}"
    @async begin
        while true
            temp = readline(STDIN)
            if ismatch(temp[1], valid_modes)
                if length(signal_channel < 1)
                    take!(signal_channel)
                end
                put!(signal_channel, temp[1])
            elseif ismatch(temp[1], "\x02")
                if length(signal_channel < 1)
                    take!(signal_channel)
                end
                put!(signal_channel, "shutdown")
            end
        end
    end
    main_loop(audio, leddata, udpsock, signal_channel)
end
function main_loop(audio, leddata, udpsock, signal_channel)
    shutdown = false
    while !shutdown
        mode = fetch(signal_channel)
        if mode == "shutdown"
            shutdown = true
        end
        audioSamp = read(audio, (1/30)s)
        parseAndUpdate(audioSamp, leddata, udpsock, mode)
    end
end
function parseAndUpdate(audioSamp, leddata, socket, mode)
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
