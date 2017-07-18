using PortAudio, SampledSignals, DSP

include("./LEDTypes.jl")
include("./ParseConfig.jl")
include("./UpdateMethods.jl")

function main()
    led_data = parse_config("./lights.json")
    signal_channel = Channel{String}(1)
    audio = PortAudioStream()
    udpsock = UDPSocket()
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
    main_loop(audio, led_data, udpsock, signal_channel)
end

function main_loop(audio, led_data, udpsock, signal_channel)
    shutdown = false
    while !shutdown
        mode = fetch(signal_channel)
        if mode == "shutdown"
            shutdown = true
        end
        audioSamp = read(audio, (1/30)s)
        parseAndUpdate(audioSamp, led_data, udpsock, mode)
    end
end

function parseAndUpdate(audioSamp, led_data, socket, mode)
    spec = fft(audioSamp[:,1])
    # use an implicit reference to the function if possible,
    # else fall back on the bars animation.
    if mode in update_methods
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
    raw_data = zeros(UInt8, length(controller)*3)
    raw_data .= convert_to_array.(controller.addrs)
    send(socket, controller.location..., raw_data)
end

function convert_to_array(color::ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}})
    return [color.r, color.g, color.b]
end

function toHexString(num)
    num <= 255 || error("Input Error")
    magic = "0123456789ABCDEF"
    num1 = floor(Int, num / 16)
    num2 = convert(Int, num % 16)
    return "$(magic[num1+1])$(magic[num2+1])"
end