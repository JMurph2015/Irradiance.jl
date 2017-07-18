using Colors, Interpolations
import Base.getindex, Base.length, Base.setindex!, Base.push!, Base.setindex
# Make some types so that I don't go insane
mutable struct LEDArray
    controllers::Array{LEDController}
    channels::Array{LEDChannel}
    strips::Array{LEDStrip}
end



mutable struct LEDStrip
    name::String
    channel::LEDChannel
    controller::LEDController
    startAddr::Int
    endAddr::Int
    function LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
        x = new(name, channel, controller, startAddr, endAddr)
        push!(channel, x)
        push!(controller, x)
        return x
    end
end

length(strip::LEDStrip) = length(strip.endAddr - strip.startAddr + 1)
getindex(strip::LEDStrip, i::Any) = getindex(strip.controller.addrs, i + strip.startAddr)



mutable struct LEDController
    addrs::Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}},1}
    strips::Array{LEDStrip}
    location::Tuple{IPAddr, Int}
    function LEDController(sz::Int, location::Tuple{IPAddr, Int})
        return new(Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}},1}(sz), Array{LEDStrip, 1}(0), location)
    end
end
length(controller::LEDController) = length(controller.addrs)
push!(controller::LEDController, val::LEDStrip) = push!(controller.strips, val)



mutable struct LEDChannel
    strips::Array{LEDStrip}
    LEDChannel() = new(Array{LEDStrip, 1}(0))
end

length(channel::LEDChannel) = max(length.(channel.strips))
push!(channel::LEDChannel, val::LEDStrip) = push!(channel.strips, val)

function setindex!(channel::LEDChannel, i::Int, val::Color)
    i >= length(channel) || error("Index Out Bounds For This Channel")

    homogeneous = True
    for i in 2:length(channel.strips)
        if length(channel.strips[i]) != length(channel.strips[i-1])
            homogeneous = false
            break
        end
    end
    if homogeneous
        setindex!.(channel.strips, i, val)
    else
        max_length = indmax(length.(channel.strips))
        channel.strips[max_length][i] = val
        itp = interpolate(channel.strips[max_length][i], BSpline(Cubic(Line())), OnCell())
        for j in eachindex(channel.strips)
            if j != max_length
                channel.strips[j] = itp[linspace(1,length(itp),length(channel.strips[j]))]
            end
        end
    end
end

function setindex(channel::LEDChannel, i::Int, val::Color)
    i >= length(channel) || error("Index Out Bounds For This Channel")

    new_channel = copy(channel)
    homogeneous = True
    for i in 2:length(new_channel.strips)
        if length(new_channel.strips[i]) != length(new_channel.strips[i-1])
            homogeneous = false
            break
        end
    end
    if homogeneous
        setindex!.(new_channel.strips, i, val)
    else
        max_length = indmax(length.(new_channel.strips))
        new_channel.strips[max_length][i] = val
        itp = interpolate(new_channel.strips[max_length][i], BSpline(Cubic(Line())), OnCell())
        for j in eachindex(new_channel.strips)
            if j != max_length
                new_channel.strips[j] = itp[linspace(1,length(itp),length(new_channel.strips[j]))]
            end
        end
    end
end