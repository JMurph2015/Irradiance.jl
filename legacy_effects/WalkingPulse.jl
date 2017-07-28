function walkingPulseFrame(leddata, audio_samp, raw_spec)
    if !("walking_offset" in keys(leddata.state))
        leddata.state["walking_offset"] = 0
    end
    if ("walking_pulse_spec" in keys(leddata.state))
        spec = leddata.state["walking_pulse_spec"]
        spec, maxspec = binFFT(raw_spec, 25)
    else
        spec,maxspec = binFFT(raw_spec, 25)
        leddata.state["walking_pulse_spec"] = spec
    end
    
    spec./=fft_scale[]
    spec[isnan.(spec)] = 0
    spec .= abs.(spec)
    pulse_length = 15
    default_color = colorant"black"
    pulse_coef = min(spec[1]+spec[2]+mean(spec[3:5])/3, 1)
    pulse_coef = pulse_coef>0.05 ? pulse_coef : 0
    pulse_shape = [i%pulse_length/4==0 ? abs(rand()*0.5*pulse_coef) : abs(sin(pi/4*i)*pulse_coef) for i in linspace(0,4,pulse_length)]
    pulse_shape[isnan.(pulse_shape)] = 0
    pulse = zeros(UInt8, pulse_length, 3)
    pulse_shape .= (pulse_shape).^0.25
    for i in 1:size(pulse,1)
        pulse[i, :] .= hsl_to_rgb(240/360, 0.95*pulse_shape[i]+0.05, 0.45*pulse_shape[i]+0.05)
    end
    for channel in leddata.channels
        setindex!(channel, default_color, 1:length(channel))
        numPulses = floor(Int, length(channel)/30)
        starts = (1:floor(Int, length(channel)/numPulses ):length(channel))[1:end-1] + round(Int, leddata.state["walking_offset"]*length(channel)/100)
        for start in starts
            assgn = (start:(start+size(pulse,1)-1)).%length(channel) + 1
            for i in eachindex(assgn)
                for j in 1:3
                    channel[assgn[i],j] = pulse[i,j]
                end
            end
        end
        update!(channel)
    end
    
    if leddata.state["walking_offset"] == 400
        leddata.state["walking_offset"] -= 100
    end
    leddata.state["walking_offset"] += 0.5
end