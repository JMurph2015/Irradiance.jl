using Interpolations
function parseAndUpdate(audioSamp::SampledSignals.SampleBuf, spec::SampledSignals.SpectrumBuf, led_data::LEDArray, socket::UDPSocket, mode::String)
    if usegpu[]
        spec .= fft(audioSamp[:,1])
    else
        spec .= fft(audioSamp[:,1])
    end
    # use an implicit reference to the function if possible,
    # else fall back on the bars animation.
    if mode in keys(update_methods)
        update_methods[mode](led_data, audioSamp[:,1], spec)
    else
        getBarsFrame(led_data, audioSamp[:,1], spec)
    end
    push(led_data, socket)
end

@inline function update!(channel::LEDChannel)
    Threads.@threads for i in eachindex(channel.itps)
        channel.itps[i] = interpolate(channel.virtualmem[:,i], BSpline(Quadratic(Natural())), OnCell())
    end
    for m in channel.map
        indicies = linspace(m[1]/100*channel.precision, m[2]/100*channel.precision, length(m[3]))
        Threads.@threads for i in 1:size(m[3],1)
            m[3][i,:] = round.(UInt8, map!(safeFloat, getindex.(channel.itps', indicies[i])))
        end
    end
end