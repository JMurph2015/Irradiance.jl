function getBarsFrame(leddata, audioSamp, rawspec)
    freqs = Array(domain(rawspec))
    samp = Array(audioSamp)
    spec = zeros(100)
    spec,maxspec = binFFT(rawspec, 10)
    for i in eachindex(spec)
        if isnan(spec[i])
            spec[i] = 0
        end
    end
    crossover = floor(Int, length(spec)/1.5)
    bottomEnd = mean((spec[1:crossover]))/maxspec
    topEnd = mean(spec[crossover+1:end])/maxspec
    for i in eachindex(leddata.channels)
        chan = leddata.channels[i]
        ref_len = length(leddata.channels[i])
        #print(i)
        if i % 4 == 1
            lows = !isnan(bottomEnd*ref_len) ? round(Int,bottomEnd*ref_len) : 0
            chan[1:lows] = colorant"blue"
            chan[lows+1:end] = colorant"black"
            #println(lows)
        elseif i % 4 == 2
            highs = !isnan(bottomEnd*ref_len) ? round(Int,topEnd*ref_len) : 0
            chan[1:highs] = colorant"red"
            chan[highs+1:end] = colorant"black"
            #println(highs)
        elseif i % 4 == 3
            lows = !isnan(bottomEnd*ref_len) ? round(Int,bottomEnd*ref_len) : 0
            chan[1:end-lows-1] = colorant"black"
            chan[end-lows:end] = colorant"blue"
            #println(lows)
        elseif i % 4 == 0
            highs = !isnan(bottomEnd*ref_len) ? round(Int,topEnd*ref_len) : 0
            chan[1:end-highs-1] = colorant"black"
            chan[end-highs:end] = colorant"red"
            #println(highs)
        else
            error("Weird modulo arithmetic failed.  Probably should've thrown an eror before this")
        end
        update!(chan)
    end
end
function rainbowBarsFrame(leddata, audioSamp, rawspec)
    colors = [convert(RGB{FixedPointNumbers.Normed{UInt8,8}}, HSL(x, 1, 0.5)) for x in linspace(0,360,length(leddata.channels)+1)[1:end-1]]
    return nBarsFrame(leddata, audioSamp, rawspec, colors)
end

function nBarsFrame(leddata, audioSamp, rawspec)
    colors = [convert(RGB{FixedPointNumbers.Normed{UInt8,8}}, HSL(240, x, 0.5)) for x in linspace(.25,1,length(leddata.channels))]
    return nBarsFrame(leddata, audioSamp, rawspec, colors)
end

function nBarsFrame(leddata, audioSamp, rawspec, colors)
    spec,maxspec = binFFT(rawspec[1:floor(Int, min(length(rawspec),length(rawspec)/48*length(leddata.channels)))], length(leddata.channels))
    default_color = colorant"black"
    normspec = zeros(length(spec))
    for i in eachindex(spec)
        ref_len = length(leddata.channels[i])
        tmp = spec[i]/fft_scale[]*ref_len
        if !isnan(tmp)
            normspec[i]=abs(tmp)
        end
    end
    min_cross = 0
    for i in eachindex(leddata.channels)
        chan = leddata.channels[i]
        ref_len = length(leddata.channels[i]);
        crossover = floor(Int, normspec[i])
        color_range = [i<=crossover for i in 1:ref_len]
        chan[1:crossover] = colors[i];
        chan[crossover+1:ref_len] = default_color;
        update!(chan)
    end
end