using PortAudio, SampledSignals, DSP, Colors
const update_methods = Dict(
    "0"=>getBarsFrame
)
function binFFT(rawspec, nbins)
    nbin = nbins+1
    f(x) = 2^x
    dom = domain(rawspec)
    range = linspace(log(100)/log(2), log(25600)/log(2), nbin)
    bands = f.(range)
    idxs = zeros(Int64, length(bands))
    for i in eachindex(idxs)
        idxs[i] = indmin(abs(dom.-bands[i]))
    end
    spec = zeros(nbin)
    for i in eachindex(spec)
        if length(rawspec[i:idxs[i]]) > 1
            spec[i] = sum(abs(rawspec[i:idxs[i]]))
        else
            spec[i] = abs(rawspec[i:idxs[i]])[1]
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
    crossover = floor(Int, length(spec)/2)
    bottomEnd = mean((spec[1:crossover]))
    topEnd = mean(spec[crossover+1:end])
    for i in eachindex(leddata.channels)
        chan = leddata.channels[i]
        if i % 4 == 1
            leddata[1:bottomEnd*length(chan)] = colorant"blue"
        elseif i % 4 == 2
            leddata[1:topEnd*length(chan)] = colorant"red"
        elseif i % 4 == 3
            leddata[(1-bottomEnd)*length(chan):end] = colorant"blue"
        elseif i % 4 == 0
            leddata[(1-topEnd)*length(chan):end] = colorant"red"
        else
            error("Weird modulo arithmetic failed.  Probably should've thrown an eror before this")
    end
    return leddata
end
