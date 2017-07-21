using PortAudio, SampledSignals, DSP, Colors, Interpolations
function binFFT(rawspec, nbins)
    nbin = nbins
    f(x) = 2^x
    dom = domain(rawspec)
    range = linspace(log(dom[2])/log(2), log(dom[end-1])/log(2), nbin)
    bands = real.(f.(range))*length(dom)/dom[end]
    itp = interpolate(rawspec, BSpline(Quadratic(Line())), OnCell())
    spec = zeros(Float64, length(bands))
    spec .= real.(abs.(getindex.([itp], bands)))
    maxspec = maximum(spec)
    if length(spec) > nbins
        return spec[1:nbins], maxspec
    end
    return spec, maxspec
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
    end
    return leddata
end
function rainbowBarsFrame(leddata, audioSamp, rawspec)
    colors = [convert(RGB, HSL(x, 1, 0.5)) for x in linspace(0,360,length(leddata.channels)+1)[1:end-1]]
    return nBarsFrame(leddata, audioSamp, rawspec, colors)
end

function nBarsFrame(leddata, audioSamp, rawspec)
    colors = [convert(RGB, HSL(240, x, 0.5)) for x in linspace(.25,1,length(leddata.channels))]
    return nBarsFrame(leddata, audioSamp, rawspec, colors)
end

function nBarsFrame(leddata, audioSamp, rawspec, colors)
    freqs = Array(domain(rawspec))
    samp = Array(audioSamp)
    spec,maxspec = binFFT(rawspec[1:floor(Int, min(length(rawspec),length(rawspec)/48*length(leddata.channels)))], length(leddata.channels))
    map!(spec,spec) do x
        if isnan(x)
            return 0
        else
            return x
        end
    end
    for i in eachindex(leddata.channels)
        chan = leddata.channels[i]
        ref_len = length(leddata.channels[i])
        crossover =  0
        tmp = ref_len*spec[i]/maxspec
        if isnan(tmp)
            crossover = 0
        else
            crossover = floor(Int, min(max(real(ref_len*spec[i]/maxspec),0),ref_len)::Float64)
        end
        #print(i)
        chan[1:crossover] = colors[i]
        chan[crossover+1:end] = colorant"black"
    end
    return leddata
end
const update_methods = Dict(
    "0"=>getBarsFrame,
    "1"=>nBarsFrame,
    "2"=>rainbowBarsFrame
)