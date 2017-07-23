const walking_offset = [0]
@inline function walkingPulseFrame(leddata, audio_samp, raw_spec)
    
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
    for channel in leddata.channels
        numPulses = floor(Int, length(channel/30))
        pulse_shape = [i%3==0 ? abs(rand()) : abs(sin(pi/4*i))*normspec[1] for i in linspace(0,4,15)]
        pulse_shape[isnan.(pulse_shape)] = 0
        println(pulse_shape)
        pulse = @. convert(RGB, HSL(240,round(UInt8, 1*pulse_shape)/255,round(UInt8, 0.5*pulse_shape)/255))
        starts = (1:floor(Int, length(channel)/numPulses ):total_leds)[1:end-1] + walking_offset[1]
        for start in starts
            assgn = (start:(start+length(pulse)-1)).%length(channel) + 1
            channel[assgn] .= pulse
        end
        update!(channel)
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