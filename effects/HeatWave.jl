using Colors
mutable struct HeatWaveEffect <: ConfigurableEffect
    config::EffectConfig
    colormap::Array{UInt8, 2}
    colorgrad::Array{RGB}
    spec::Array{T} where T<: AbstractFloat
    maxspec::T where T<: AbstractFloat
    function HeatWaveEffect(leddata::LEDArray, config::EffectConfig, ana::AudioAnalysis)
        init_spec, maxspec = binFFT(ana, 25)
        num_colors = 100*config.scaling
        init_colorgrad = linspace(config.primary_color, config.secondary_color, num_colors)
        init_colormap = vcat([hsl_to_rgb(c.h/360, c.s, c.l) for c in init_colorgrad]...)
        return new(config, init_colormap, init_colorgrad, init_spec, maxspec)
    end
end
function update_vars!(leddata::LEDArray, ana::AudioAnalysis, effect::HeatWaveEffect)
    effect.num_colors = effect.config.scaling * 100
    effect.colorgrad = linspace(effect.config.primary_color, effect.config.secondary_color, effect.num_colors)
    effect.colormap = vcat([hsl_to_rgb(c.h/360, c.s, c.l) for c in effect.colorgrad]...)
    effect.spec, effect.maxspec = binFFT(ana, 25)
end
function update!(leddata::LEDArray, ana::AudioAnalysis, effect::HeatWaveEffect)
    update_vars!(leddata, ana, effect)
    color_idx = @bounded( round(Int, mean(effect.spec[1:5])*size(effect.colormap,1)), 1, size(effect.colormap,1) )
    for channel in leddata.channels
        for i in 1:size(channel, 1)
            channel[i, :] = effect.colormap[color_idx, :]
        end
        update!(channel)
    end
end
