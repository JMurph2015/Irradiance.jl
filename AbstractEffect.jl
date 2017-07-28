using Colors, ColorTypes, FixedPointNumbers
abstract type Effect end
abstract type ConfigurableEffect <: Effect end
function update(e::Effect)
    throw(NullException())
end
mutable struct EffectConfig
    primary_color::HSL
    secondary_color::HSL
    scaling::AbstractFloat
    speed::AbstractFloat
    special::Dict{String, Any}
end

const file_regex = r".*?\.jl"six
for effectfile in readdir("./effects")
    if ismatch(file_regex, effectfile)
        include("./effects/$effectfile")
    end
end

const effect_types = Dict{String, Any}(
    "0"=>NBarsEffect
)