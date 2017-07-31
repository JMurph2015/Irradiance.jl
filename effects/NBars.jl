mutable struct NBarsEffect{T<:AbstractFloat} <: ConfigurableEffect
    config::EffectConfig
    spec::Array{T}
    maxspec::AbstractFloat
    colors::Array{UInt8, 2}
    backgroundcolor::Array{UInt8}
    normspec::Array{T}
    function NBarsEffect{T}(leddata, config, ana) where T<:AbstractFloat
        spec, maxspec = binFFT(ana, length(leddata.channels), floor(Int, length(ana.spec_bufs[ana.spec_buf_order[1]])/2))
        colors = zeros(UInt8, length(leddata.channels), 3)
        prim_color = config.primary_color
        for i in 1:size(colors, 1)
            colors[i, :] .= round.(UInt8, hsl_to_rgb(prim_color.h/360, prim_color.s*(0.5*i/size(colors,1)+0.5), prim_color.l))
        end
        sec_color = config.secondary_color
        backgroundcolor = round.(UInt8, hsl_to_rgb(sec_color.h/360, sec_color.s, sec_color.l))
        normspec = zeros(length(spec))
        return new(config, spec, maxspec, colors, backgroundcolor, normspec)
    end
end

function update!(leddata::LEDArray, ana::AudioAnalysis, effect::NBarsEffect)
    # Abstract away updating arrays in the object
    update_vars!(leddata, ana, effect)    

    for i in eachindex(leddata.channels)
        
        chan = leddata.channels[i]
        crossover = max(0, min(size(chan,1), floor(Int, effect.normspec[i])))
        for j in 1:crossover
            for k in 1:size(chan,2)
                chan[j,k] = effect.colors[i,k]
            end
        end
        for j in (crossover+1):size(chan,1)
            for k in 1:size(chan, 2)
                chan[j,k] = effect.backgroundcolor[k]
            end
        end
        update!(chan)
    end
end

function process_colors!(leddata::LEDArray, ana::AudioAnalysis, effect::NBarsEffect)
    if !(size(effect.colors) == (length(leddata.channels, 3)))
        effect.colors = zeros(UInt8, length(leddata.channels), 3)
    end

    prim_color = effect.config.primary_color

    for i in 1:size(effect.colors, 1)
        effect.colors[i, :] .= round.(UInt8, hsl_to_rgb(prim_color.h/360, prim_color.s*(0.5*i/size(effect.colors,1)+0.5), prim_color.l))
    end

    sec_color = effect.config.secondary_color
    effect.backgroundcolor = round.(UInt8, hsl_to_rgb(sec_color.h/360, sec_color.s, sec_color.l))
end


function update_vars!(leddata::LEDArray, ana::AudioAnalysis, effect::NBarsEffect)
    effect.spec, effect.maxspec = binFFT(ana, length(leddata.channels), floor(Int, length(ana.spec_bufs[ana.spec_buf_order[1]])/2))
    if length(effect.normspec) != length(effect.spec)
        effect.normspec = zeros(length(effect.spec))
    end

    for i in eachindex(effect.spec)
        ref_len = size(leddata.channels[i],1)
        tmp = effect.spec[i]/fft_scale[]*ref_len
        if !isnan(tmp)
            effect.normspec[i]=abs(tmp)
        end
    end
end