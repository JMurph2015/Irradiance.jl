using JSON
import Base.getindex
# Make some types so that I don't go insane
mutable struct LEDStrip
    channelNum::Int
    controller::LEDController
    numLED::Int
    startAddr::Int
    endAddr::Int
end
mutable struct LEDController
    addrs::Array{Int,1}
    strips::Array{LEDStrip}
end
getindex(strip::LEDStrip, i::Any) = getindex(strip.controller.addrs, i + strip.startAddr)
mutable struct LEDArray
    numChannels::Int
    controllers::Array{Int}
    strips::Array{LEDStrip}
end

function parse_config(filename)
    open(filename, "r") do f
        json_data = JSON.parse(f)
    end
end