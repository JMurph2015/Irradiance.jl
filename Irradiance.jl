__precompile__(true)
module Irradiance
export run_app
using PortAudio, SampledSignals, DSP
const usegpu = Ref(false)
import Base.fft

try
    import ArrayFire
    usegpu[] = true
end

if usegpu[]
    function gfft(buf::SampledSignals.SampleBuf)
        return SpectrumBuf(Array(fft(ArrayFire.AFArray(buf.data))), nframes(buf)/samplerate(buf))
    end
end


include("./LEDTypes.jl")
include("./ParseConfig.jl")
include("./UpdateMethods.jl")

const old_data = Array{Any, 1}(0)

function run_app(remote::Bool, args...)
    if remote
        if length(args) >= 1
            args[1]::Int
        end
        if length(args) >= 2
            args[2]::Int
        end
        socket = UDPSocket()
        led_data = remote_config(socket, length(args)>=1 ? args[1] : 8080, length(args)>=2 ? args[2] : 37322)
    else
        led_data = parse_config(length(args)>=1 && typeof(args[1]) == String ? args[1] : "./lights.json")
        socket = UDPSocket()
    end
    main(led_data, socket)
end

function main(led_data, udpsock)
    signal_channel = Channel{String}(1)
    push!(signal_channel, "1")
    audio = PortAudioStream("default")
    valid_modes = r"\d{1,2}"
    @async begin
        stopped = false
        while !stopped
            print("irradiance>")
            temp = readline(STDIN)
            if typeof(temp) == Char
                temp = convert(String, [temp])
            end
            if ismatch(valid_modes, temp)
                if length(signal_channel.data) > 0
                    take!(signal_channel)
                end
                put!(signal_channel, temp)
            elseif ismatch(r"shutdown|quit"six, temp)
                if length(signal_channel.data) > 0
                    take!(signal_channel)
                end
                put!(signal_channel, "shutdown")
                stopped = true
            elseif ismatch(r"\x03"six, temp)
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
    frame_length = (1/60)s
    audioSamp = read(audio, frame_length)
    spec = fft(audioSamp[:,1])
    while !shutdown
        mode = fetch(signal_channel)
        if mode == "shutdown"
            shutdown = true
        end
        audioSamp .= read(audio, frame_length)
        parseAndUpdate(audioSamp, spec, led_data, udpsock, mode)
    end
end

@inline function parseAndUpdate(audioSamp, spec, led_data, socket, mode)
    if usegpu[]
        spec .= fft(audioSamp[:,1])
    else
        spec .= fft(audioSamp[:,1])
    end
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
    for controller in led_data.controllers
        push(controller, socket)
    end
end

function push(controller::LEDController, socket::UDPSocket)
    #println(length(filter(x->x==colorant"blue", controller.addrs)))
    #println(length(filter(x->x==colorant"red", controller.addrs)))
    tmp = 0
    for j in eachindex(controller.addrs)
        tmp = 3*(j-1)
        controller.raw_data[tmp+1] = controller.addrs[j].r.i
        controller.raw_data[tmp+2] = controller.addrs[j].g.i
        controller.raw_data[tmp+3] = controller.addrs[j].b.i
    end
    #controller.raw_data .= vcat((convert_to_array.(controller.addrs))...)::Array{UInt8}
    #println(length(filter(x->x!=0x00, raw_data)))
    send(socket, controller.location..., controller.raw_data)
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

end