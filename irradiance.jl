using PortAudio, SampledSignals, DSP

include("./LEDTypes.jl")
include("./ParseConfig.jl")
include("./UpdateMethods.jl")

const old_data = Array{Any, 1}(0)

function main()
    led_data = parse_config("./lights.json")
    signal_channel = Channel{String}(1)
    push!(signal_channel, "0")
    audio = PortAudioStream("default")
    udpsock = UDPSocket()
    valid_modes = r"\d{1,2}"
    @async begin
        stopped = false
        while !stopped
            temp = readline(STDIN)
            if ismatch(valid_modes, temp)
                if length(signal_channel.data) > 0
                    take!(signal_channel)
                end
                put!(signal_channel, temp[1])
            elseif ismatch(r"shutdown|quit"six, temp)
                if length(signal_channel.data) > 0
                    take!(signal_channel)
                end
                put!(signal_channel, "shutdown")
                stopped = true
            elseif ismatch(r"\x02"six, temp)
                if length(signal_channel.data) > 0
                    take!(signal_channel)
                end
                put!(signal_channel, "shutdown")
                stopped = true
            end
        end
    end
    main_loop(audio, led_data, udpsock, signal_channel)
    close(audio)
    close(signal_channel)
end

function main_loop(audio, led_data, udpsock, signal_channel)
    shutdown = false
    for channel in led_data.channels
        channel[1:end] = colorant"black"
    end
    while !shutdown
        mode = fetch(signal_channel)
        if mode == "shutdown"
            shutdown = true
        end
        audioSamp = read(audio, (1/60)s)
        @async begin
            parseAndUpdate(audioSamp, led_data, udpsock, mode)
        end
    end
end

function parseAndUpdate(audioSamp, led_data, socket, mode)
    spec = fft(audioSamp[:,1])
    # use an implicit reference to the function if possible,
    # else fall back on the bars animation.
    if mode in keys(update_methods)
        led_data = update_methods[mode](led_data, audioSamp[:,1], spec)
    else
        led_data = getBarsFrame(led_data, audioSamp[:,1], spec)
    end
    push(led_data, socket)
end

function push(led_data::LEDArray, socket::UDPSocket)
    push.(led_data.controllers, socket)
end

function push(controller::LEDController, socket::UDPSocket)
    #println(length(filter(x->x==colorant"blue", controller.addrs)))
    #println(length(filter(x->x==colorant"red", controller.addrs)))
    raw_data = zeros(UInt8, length(controller.addrs)*3)
    raw_data .= vcat((convert_to_array.(controller.addrs))...)::Array{UInt8}
    #println(length(filter(x->x!=0x00, raw_data)))
    send(socket, controller.location[1], controller.location[2], raw_data)
end

function convert_to_array(color::ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}})
    return [color.r.i, color.g.i, color.b.i]
end

function toHexString(num)
    num <= 255 || error("Input Error")
    magic = "0123456789ABCDEF"
    num1 = floor(Int, num / 16)
    num2 = convert(Int, num % 16)
    return "$(magic[num1+1])$(magic[num2+1])"
end