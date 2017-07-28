mutable struct NBarsEffect <: ConfigurableEffect
    config::EffectConfig
    spec::Array{T} where T<:AbstractFloat
    maxspec::AbstractFloat
    colors::Array{UInt8, 2}
    backgroundcolor::Array{UInt8}
    normspec::Array{T} where T<:AbstractFloat
    function NBarsEffect(leddata, config, ana)
        spec, maxspec = binFFT(ana, length(leddata.channels), floor(Int, length(ana.spec_bufs[ana.spec_buf_order[1]])/2))
        colors = zeros(UInt8, length(leddata.channels), 3)
        prim_color = config.primary_color
        for i in size(colors, 1)
            colors[i, :] .= hsl_to_rgb(prim_color.h/360, prim_color.s, prim_color.l)
        end
        sec_color = config.secondary_color
        backgroundcolor = hsl_to_rgb(sec_color.h/360, sec_color.s, sec_color.l)
        normspec = zeros(length(spec))
        return new(config, spec, maxspec, colors, backgroundcolor, normspec)
    end
end

function update!(leddata::LEDArray, ana::AudioAnalysis, effect::NBarsEffect)
    # Abstract away updating arrays in the object
    update_vars!(leddata, ana, effect)    

    for i in eachindex(leddata.channels)
        chan = leddata.channels[i]
        ref_len = length(leddata.channels[i]);
        crossover = max(0, min(length(chan), floor(Int, effect.normspec[i])))
        chan[1:crossover, :] .= effect.colors[i]';
        chan[crossover+1:ref_len, :] .= effect.backgroundcolor';
        update!(chan)
    end
end

function process_colors!(leddata::LEDArray, ana::AudioAnalysis, effect::NBarsEffect)
    if !(size(effect.colors) == (length(leddata.channels, 3)))
        effect.colors = zeros(UInt8, length(leddata.channels), 3)
    end

    prim_color = effect.config.primary_color

    for i in size(effect.colors, 1)
        effect.colors[i, :] .= hsl_to_rgb(prim_color.h/360, prim_color.s, prim_color.l)
    end

    sec_color = effect.config.secondary_color
    effect.backgroundcolor .= [sec_color.r.i, sec_color.g.i, sec_color.b.i]
end


function update_vars!(leddata::LEDArray, ana::AudioAnalysis, effect::NBarsEffect)
    effect.spec, effect.maxspec = binFFT(ana, length(leddata.channels), floor(Int, length(ana.spec_bufs[ana.spec_buf_order[1]])/2))

    if length(effect.normspec) != length(effect.spec)
        effect.normspec = zeros(length(effect.spec))
    end

    for i in eachindex(effect.spec)
        ref_len = length(leddata.channels[i])
        tmp = effect.spec[i]/fft_scale[]*ref_len
        if !isnan(tmp)
            effect.normspec[i]=abs(tmp)
        end
    end
end