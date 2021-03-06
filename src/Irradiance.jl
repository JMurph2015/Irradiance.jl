module Irradiance
export run_app
using PortAudio, SampledSignals, DSP
import Pkg
const usegpu = "ArrayFire" in keys(Pkg.installed())
using ArrayFire

include("./RotatingBuffer.jl")
include("./LEDTypes.jl")
include("./ParseConfig.jl")
include("./UpdateMethods.jl")
include("./AbstractEffect.jl")
include("./IrradianceCLI.jl")

const old_data = Array{Any, 1}(undef, 0)

function run_app(remote::Bool, args...)
    #ArrayFire.set_backend(AF_BACKEND_OPENCL)
    if remote
        if length(args) >= 1
            args[1]::Int
        end
        if length(args) >= 2
            args[2]::Int
        end
        if length(args) >= 3
            args[3]::IPAddr
        end
        socket = UDPSocket()
        bind(socket, ip"0.0.0.0", 0)
        Sockets.setopt(socket, enable_broadcast=1)
        led_data = remote_config(
            socket, 
            length(args)>=1 ? args[1] : 8080, 
            length(args)>=2 ? args[2] : 37322, 
            length(args)>=3 ? args[3] : ip"10.42.0.255"
        )
    else
        led_data = parse_config(length(args)>=1 && typeof(args[1]) == String ? args[1] : "./lights.json")
        socket = UDPSocket()
    end
    main(led_data, socket)
end

function main(led_data, udpsock)
    signal_channel = Channel{String}(2)
    config_channel = Channel{EffectConfig}(2)
    channels = [signal_channel, config_channel]
    push!(config_channel, EffectConfig(
        HSL(240, 1, 0.5),
        HSL(240, 0, 0.0),
        1,
        1,
        Dict{String, Any}()
    ))
    push!(signal_channel, "1")
    audio = PortAudioStream("default")
    @async handle_cli(channels)
    main_loop(audio, led_data, udpsock, channels)
    close(audio)
    close.(channels)
end

function main_loop(audio, led_data, udpsock, channels)
    signal_channel = channels[1]
    config_channel = channels[2]
    shutdown = false
    clearline = join([" " for i in 1:80])
    for channel in led_data.channels
        channel[1:size(channel,1)] = colorant"black"
    end
    frame_length = (1/10)s
    @sync audio_samp = read(audio, frame_length)
    audio_buf = RotatingBuffer(audio_samp, 2)
    ana = AudioAnalysis(audio_buf[1], 3)
    config = fetch(config_channel)
    current_effect = effect_types["1"](led_data, config, ana)
    current_mode = ""
    while !shutdown
        mode = fetch(signal_channel)
        if fetch(config_channel) != config
            config = fetch(config_channel)
            if issubtype(typeof(current_effect), ConfigurableEffect)
                current_effect.config = config
            end
        end
        if mode != current_mode
            if mode == "shutdown"
                shutdown = true
                current_mode = mode
            elseif mode in keys(effect_types)
                current_effect = effect_types[mode](led_data, config, ana)
                current_mode = mode
            end
        end

        Threads.@threads for i in 1:2
            if Threads.threadid() == 1
                audio_buf[1] = @sync read(audio, frame_length)
            else
                # does the magic of ffts and rotating buffers
                process_audio!(ana, audio_buf[1])

                update!(led_data, ana, current_effect)
            end
        end
        
        push(led_data, udpsock)
        rotate_clockwise!(audio_buf)
    end
end

function push(led_data::LEDArray, socket::UDPSocket)
    for controller in led_data.controllers
        push(controller, socket)
    end
end

function push(controller::LEDController, socket::UDPSocket)
    controller.raw_data = reshape(controller.addrs', :)
    send(socket, controller.location[1], controller.location[2], controller.raw_data)
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
