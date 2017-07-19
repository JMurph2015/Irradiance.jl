using Colors, Interpolations
import Base.getindex, Base.length, Base.setindex!, Base.push!, Base.setindex

abstract type AbstractChannel end
abstract type AbstractController end


# Make some types so that I don't go insane
mutable struct LEDStrip{T,N}
    name::String
    channel::T
    controller::N
    startAddr::Int
    endAddr::Int
    function LEDStrip{T,N}(name::String, channel::T, controller::N, startAddr::Int, endAddr::Int) where {T<:AbstractChannel, N<:AbstractController}
        x = new(name, channel, controller, startAddr, endAddr)
        push!(channel, x)
        push!(controller, x)
        return x
    end
end

length(strip::LEDStrip) = length(strip.endAddr - strip.startAddr + 1)
getindex(strip::LEDStrip, i::Any) = getindex(strip.controller.addrs, i + strip.startAddr-1)
function setindex!{T<:AbstractChannel, N<:AbstractController}(strip::LEDStrip{T, N}, val::Color, idx::Int)
    strip.controller[idx+strip.startAddr-1] = val
end
function setindex{T<:AbstractChannel, N<:AbstractController}(strip::LEDStrip{T, N}, val::Color, idx::Int)
    new_strip = deepcopy(strip)
    new_strip.controller[idx+strip.startAddr-1] = val
    return new_strip
end



mutable struct LEDController <: AbstractController
    addrs::Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}},1}
    strips::Array{LEDStrip}
    location::Tuple{IPAddr, Int}
    function LEDController(sz::Int, location::Tuple{IPAddr, Int})
        return new(Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}},1}(sz), Array{LEDStrip, 1}(0), location)
    end
end

length(controller::LEDController) = length(controller.addrs)
push!(controller::LEDController, val::LEDStrip) = push!(controller.strips, val)
function setindex!(controller::LEDController, val::Color, idx::Int)
    controller.addrs[idx] = val
end
function setindex(controller::LEDController, val::Color, idx::Int)
    new_controller = deepcopy(controller)
    new_controller.addrs[idx] = val
    return new_controller
end



mutable struct LEDChannel <: AbstractChannel
    strips::Array{LEDStrip}
    LEDChannel() = new(Array{LEDStrip, 1}(0))
end

getindex(channel::LEDChannel, idx::Int) = getindex(channel.strips[indmax(length.(channel.strips))], idx)
length(channel::LEDChannel) = maximum(length.(channel.strips))
push!(channel::LEDChannel, val::LEDStrip) = push!(channel.strips, val)

function setindex!(channel::LEDChannel, val::Color, i::Int)
    i >= length(channel) || error("Index Out Bounds For This Channel")

    homogeneous = true
    for i in 2:length(channel.strips)
        if length(channel.strips[i]) != length(channel.strips[i-1])
            homogeneous = false
            break
        end
    end
    if homogeneous
        setindex!.(channel.strips, val, i)
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

function setindex(channel::LEDChannel, val::Color, i::Int)
    i >= length(channel) || error("Index Out Bounds For This Channel")

    new_channel = deepcopy(channel)
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
    return new_channel
end

mutable struct LEDArray
    controllers::Array{LEDController}
    channels::Array{LEDChannel}
    strips::Array{LEDStrip}
end


function LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
    return LEDStrip{LEDChannel, LEDController}(name, channel, controller, startAddr, endAddr)
end