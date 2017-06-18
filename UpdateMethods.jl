using PortAudio, SampledSignals, DSP

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
    leftwall = 1:109
    frontwall = 110:309
    rightwall = 310:418
    backwall = 419:600
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
    lowNum = floor(Int, bottomEnd*length(frontwall))
    highNum = floor(Int, topEnd*length(rightwall))
    for i in eachindex(leddata)
        if (i >= leftwall[1] && i < leftwall[1]+highNum) || (i >= rightwall[1] && i < rightwall[1]+highNum)
            leddata[i] = [0, 0, 255]
        elseif (i >= frontwall[1] && i < frontwall[1]+lowNum) || (i >= backwall[1] && i < backwall[1]+lowNum)
            leddata[i] = [255, 0, 0]
        else
            leddata[i] = [120,120,120]
        end
    end
    return leddata
end
