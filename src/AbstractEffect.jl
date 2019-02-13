using Colors, ColorTypes, FixedPointNumbers
abstract type Effect end
abstract type ConfigurableEffect <: Effect end
function update(e::Effect)
    throw(NullException())
end
struct EffectConfig{T<:AbstractFloat}
    primary_color::HSL{T}
    secondary_color::HSL{T}
    scaling::T
    speed::T
    special::Dict{String, Any}
end

function EffectConfig(primary_color::HSL, secondary_color::HSL, scaling::Number, speed::Number, special::Dict{String, Any})
    target = eltype(primary_color)
    return EffectConfig(primary_color, convert(HSL{target}, secondary_color), convert(target, scaling), convert(target, speed), special)
end


const file_regex = r".*?\.jl"six
for effectfile in readdir("./src/effects")
    if match(file_regex, effectfile) != nothing
        include("./effects/$effectfile")
    end
end

const effect_types = Dict{String, Any}(
    "0"=>NBarsEffect{Float64},
    "1"=>WalkingPulseEffect{Float64},
    "2"=>HeatWaveEffect
)
