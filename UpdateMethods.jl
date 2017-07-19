using PortAudio, SampledSignals, DSP, Colors
function binFFT(rawspec, nbins)
    nbin = nbins+1
    f(x) = 2^x
    dom = domain(rawspec)
    range = linspace(log(100)/log(2), log(25600)/log(2), nbin)
    bands = f.(range)
    idxs = zeros(Int64, length(bands))
    for i in eachindex(idxs)
        idxs[i] = indmin(abs.(dom.-bands[i]))
    end
    spec = zeros(nbin)
    for i in eachindex(spec)
        if length(rawspec[i:idxs[i]]) > 1
            spec[i] = sum(abs.(rawspec[i:idxs[i]]))
        else
            spec[i] = abs.(rawspec[i:idxs[i]])[1]
        end
    end
    maxspec = maximum(spec)
    return (spec/maxspec)[1:end-1], maxspec
end
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
    maxAmp = maximum(spec)
    crossover = floor(Int, length(spec)/1.5)
    bottomEnd = mean((spec[1:crossover]))
    topEnd = mean(spec[crossover+1:end])/2
    for i in eachindex(leddata.channels)
        chan = leddata.channels[i]
        ref_len = length(leddata.channels[i])
        #print(i)
        if i % 4 == 1
            lows = round(Int,bottomEnd*ref_len)
            chan[1:lows] = colorant"blue"
            chan[lows+1:end] = colorant"black"
            #println(lows)
        elseif i % 4 == 2
            highs = round(Int,topEnd*ref_len)
            chan[1:highs] = colorant"red"
            chan[highs+1:end] = colorant"black"
            #println(highs)
        elseif i % 4 == 3
            lows = round(Int,bottomEnd*ref_len)
            chan[1:end-lows-1] = colorant"black"
            chan[end-lows:end] = colorant"blue"
            #println(lows)
        elseif i % 4 == 0
            highs = round(Int,topEnd*ref_len)
            chan[1:end-highs-1] = colorant"black"
            chan[end-highs:end] = colorant"red"
            #println(highs)
        else
            error("Weird modulo arithmetic failed.  Probably should've thrown an eror before this")
        end
    end
    return leddata
end
const update_methods = Dict(
    "0"=>getBarsFrame
)