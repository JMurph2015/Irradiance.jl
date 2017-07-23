const walking_offset = [0]
@inline function walkingPulseFrame(leddata, audio_samp, raw_spec)
    numPulses = 50
    spec,maxspec = binFFT(raw_spec, 25)
    normspec = zeros(length(spec))
    Threads.@threads for i in eachindex(spec)
        ref_len = length(leddata.channels[i])
        tmp = spec[i]/maxspec*ref_len
        if !isnan(tmp)
            normspec[i]=abs(tmp)
        end
    end
    
    
    default_color = colorant"black"
    pulse_shape = [i%3==0 ? abs(rand()) : abs(sin(pi/4*i))*normspec[1]/maxspec for i in linspace(0,4,15)]
    pulse_shape[isnan.(pulse_shape)] = 0
    println(pulse_shape)
    pulse = @. convert(RGB, HSL(240,round(UInt8, 1*pulse_shape)/255,round(UInt8, 0.5*pulse_shape)/255))
    min_cross = 0
    total_leds = sum(length.(leddata.channels))
    starts = 1:floor(Int, (total_leds-length(pulse))/numPulses ):total_leds + walking_offset[1]
    for start in starts
        assgn = (start:(start+length(pulse)-1)).%total_leds + 1
        unionsetindex!(leddata.channels, pulse, assgn)
    end
    #=
    assigned = 1
    Threads.@threads for i in eachindex(leddata.channels)
        chan = leddata.channels[i]
        chan[:] .= alladdrs[assigned:length(chan)-1];
        assigned += length(chan)
    end
    =#
    walking_offset[1] += 1
    return leddata
end


unionsetindex!(channels, val, i::AbstractArray{T}) where {T<:Int} = unionsetindex!.([channels], val, i)
function unionsetindex!(channels, val, i::Int)
    for channel in channels
        if i <= length(channel)
            channel[i] = val
            break
        else
            i-=length(channel)
        end
    end
end