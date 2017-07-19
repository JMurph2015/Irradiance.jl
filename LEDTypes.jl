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
endof(s::LEDStrip) = length(s)
function setindex!{T<:AbstractChannel, N<:AbstractController}(strip::LEDStrip{T, N}, val::Color, idx::Any)
    setindex!(strip.controller, val, idx+(strip.startAddr-1))
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
endof(c::LEDController) = length(c)
function setindex!(controller::LEDController, val::Color, idx::Any)
    setindex!(controller.addrs, val, idx)
end


mutable struct LEDChannel <: AbstractChannel
    strips::Array{LEDStrip}
    LEDChannel() = new(Array{LEDStrip, 1}(0))
end

getindex(channel::LEDChannel, idx::Int) = getindex(channel.strips[indmax(length.(channel.strips))], idx)
length(channel::LEDChannel) = maximum(length.(channel.strips))
push!(channel::LEDChannel, val::LEDStrip) = push!(channel.strips, val)

function setindex!(channel::LEDChannel, val::Color, i::Any)

    homogeneous = true
    for i in 2:length(channel.strips)
        if length(channel.strips[i]) != length(channel.strips[i-1])
            homogeneous = false
            break
        end
    end
    if homogeneous
        for strip in channel.strips
            setindex!(strip, val, i)
        end
    else
        max_length = indmax(length.(channel.strips))
        setindex!(channel.strips[max_length], val, i)
        itp = interpolate(channel.strips[max_length][i], BSpline(Cubic(Line())), OnCell())
        for j in eachindex(channel.strips)
            if j != max_length
                setindex!(channel.strips, itp[linspace(1,length(itp),length(channel.strips[j]))], : )
            end
        end
    end
end
endof(c::LEDChannel) = length(c)

mutable struct LEDArray
    controllers::Array{LEDController}
    channels::Array{LEDChannel}
    strips::Array{LEDStrip}
end


function LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
    return LEDStrip{LEDChannel, LEDController}(name, channel, controller, startAddr, endAddr)
end