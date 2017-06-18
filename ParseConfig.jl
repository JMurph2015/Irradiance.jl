using IniFile
import Base.getindex
# Make some types so that I don't go insane
type LEDStrip
    channelNum::Int
    controller::Int
    numLED::Int
    startAddr::Int
    endAddr::Int
end
getindex(strip::LEDStrip,i::Int) = getindex([strip.startAddr strip.endAddr], i)
type LEDArray
    numChannels::Int
    controllers::Array{Int}
    strips::Array{LEDStrip}
end
