mutable struct WalkingPulseEffect{T<:AbstractFloat} <: ConfigurableEffect
    config::EffectConfig
    pulse_length::Int
    pulse::Array{UInt8}
    pulse_shape::Array{T}
    spec::Array{T}
    maxspec::T
    assgn::Array{Int}
    starts::StepRange
    walking_offset::Float64
    function WalkingPulseEffect{T}(leddata, config, ana) where T<:AbstractFloat
        pulse_length = round(Int, 15*config.scaling)
        pulse = zeros(UInt8, pulse_length)
        pulse_shape = zeros(pulse_length)
        spec, maxspec = binFFT(ana, 25)
        walking_offset = 0.0
        numPulses = floor(Int, size(leddata.channels[1],1)/30)
        starts = (1:floor(Int, size(leddata.channels[1],1)/numPulses ):size(leddata.channels[1],1))[1:end-1] + round(Int, walking_offset*size(leddata.channels[1],1)/100)
        assgn = (starts[1]:(starts[1]+size(pulse,1)-1)).%size(leddata.channels[1],1) + 1
        return new(config, pulse_length, pulse, pulse_shape, spec, maxspec, assgn, starts, walking_offset)
    end
end

function update_vars!(leddata::LEDArray, ana::AudioAnalysis, effect::WalkingPulseEffect)
    effect.spec, effect.maxspec = binFFT(ana, 25)
    effect.spec./=fft_scale[]
    effect.spec[isnan.(effect.spec)] = 0.0
    effect.spec .= abs.(effect.spec)
    effect.pulse_length = round(Int, 15*effect.config.scaling)
end

function update!(leddata::LEDArray, ana::AudioAnalysis, effect::WalkingPulseEffect)

    update_vars!(leddata, ana, effect)
    default_color = hsl_to_rgb(effect.config.secondary_color)
    pulse_coef = min(effect.spec[1]+effect.spec[2]+mean(effect.spec[3:5])/3.5, 1)
    pulse_coef = pulse_coef>0.05 ? pulse_coef : 0.0
    effect.pulse_shape = [i%effect.pulse_length/4==0 ? abs(rand()*0.5*pulse_coef) : abs(sin(pi/4*i)*pulse_coef) for i in linspace(0,4,effect.pulse_length)]
    effect.pulse_shape[isnan.(effect.pulse_shape)] = 0.0
    effect.pulse = zeros(UInt8, effect.pulse_length, 3)
    effect.pulse_shape .= (effect.pulse_shape).^0.25
    
    effect.pulse = vcat([hsl_to_rgb(effect.config.primary_color.h/360, 0.95*effect.pulse_shape[i]+0.05, 0.45*effect.pulse_shape[i]+0.05)' for i in 1:size(effect.pulse,1)]...)
    starts_dict = Dict{Int, StepRange}()
    assgn_dict = Dict{Tuple{Int,Int}, Array{Int,1}}()
    
    for channel in leddata.channels
        for j in 1:size(channel,1)
            for k in 1:size(channel,2)
                channel[j,k] = default_color[k]
            end
        end
        numPulses = floor(Int, size(channel,1)/30)
        
        if !(size(channel,1) in keys(starts_dict) && starts_dict[size(channel,1)][1] == 1 + round(Int, effect.walking_offset*size(channel,1)/100))
            effect.starts = (1:floor(Int, size(channel,1)/numPulses ):size(channel,1))[1:end-1] + round(Int, effect.walking_offset*size(channel,1)/100)
        else
            effect.starts = starts_dict[size(channel,1)]
        end
        for k in eachindex(effect.starts)
            if !((size(channel,1), effect.starts[k]) in keys(assgn_dict))
                effect.assgn = (effect.starts[k]:(effect.starts[k]+size(effect.pulse,1)-1)).%size(channel,1) + 1
                assgn_dict[(size(channel,1), effect.starts[k])] = effect.assgn
            else
                effect.assgn = assgn_dict[(size(channel,1), effect.starts[k])]
            end
            for i in eachindex(effect.assgn)
                for j in 1:3
                    channel[effect.assgn[i],j] = effect.pulse[i,j]
                end
            end
        end
        update!(channel)
    end
    
    if effect.walking_offset == 400.0
        effect.walking_offset -= 100.0
    end
    effect.walking_offset += 0.5
end