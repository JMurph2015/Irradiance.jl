using Colors, Interpolations
import Base: getindex, length, setindex!, push!, lastindex, eachindex, size
import Sockets: IPAddr
import FixedPointNumbers

"""
    AbstractChannel
    
    This channel abstraction allows me to use circular referential types between
    LEDStrip, LEDChannel, and LEDController because Julia doesn't yet support the 
    forward lookahead necessary to use this feature with only the child types.
"""
abstract type AbstractChannel end
"""
    AbstractController
    
    This does the same for Controllers that AbstractChannel did for Channels:
    it allows me to use typed circular references without forward lookahead.
"""
abstract type AbstractController end

"""
    LEDStrip{T<:AbstractChannel, N<:AbstractController}
    
    Summary:  
        Represents a string of LEDs in an Array-like form

    Details:  
        This encapsulates the core representation of a string of LED's.
        It contains a view (a reference to a section of an array) of a portion of
        its controller's memory addresses.  It also has a reference to its controller
        which happends to be circular.

    Fields:
        name::String - A string representing the name of the strip of LEDs
            like "living room wall"
        controller::AbstractController - A reference to the LEDController
            which this particular LEDStrip is attached to
        subArray::SubArray - A reference to the relevant portion of the 
            controller's LED memory
        idxRange::UnitRange - A range reflecting which addresses this 
            LEDStrip refers to on its attached controller

    Inner Constructors:
        LEDStrip{T,N}(name::String, channel::T, controller::N, startAddr::Int, endAddr::Int) where {T<:AbstractChannel, N<:AbstractController}
            returns: LEDStrip{T,N} initialized with provided values
"""
mutable struct LEDStrip{T<:AbstractChannel, N<:AbstractController}
    name::String
    controller::N
    subArray::SubArray
    idxRange::UnitRange
    function LEDStrip{T,N}(name::String, channel::T, controller::N, startAddr::Int, endAddr::Int) where {T<:AbstractChannel, N<:AbstractController}
        x = new(name, controller, view(controller.addrs, startAddr:endAddr, :), startAddr:endAddr)
        push!(channel, x)
        push!(controller, x)
        return x
    end
end

#=
    Array-like interface implementation (Julia doesn't have interfaces, 
    but there are collections of functions informally expected to exist)

    Most of these use some form of redirection to the inner view of the
    LEDController memory, but some have significant customizations on that.
=#
"Implements an override for the base length function"
length(strip::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}= length(strip.subArray)

"Implements getting an index from the strip"
getindex(strip::LEDStrip{T, N}, i::Any...) where {T<:AbstractChannel, N<:AbstractController}= getindex(strip.subArray, i...)

"Implements the equivalent of Python's enumerate() instance method, returns a range of indices to iterate over"
eachindex(s::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}=eachindex(s.subArray)

"Implements a lastindex base function that returns the index of the last element"
lastindex(s::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController} = lastindex(s.subArray)

"Implements a size function for the LEDStrip, overrides the base function"
size(s::LEDStrip{T, N}, vargs...) where {T<:AbstractChannel, N<:AbstractController} = size(s.subArray, vargs...)

"Implements a function to set a particular index to a value for LEDStrip"
setindex!(strip::LEDStrip{T, N}, val::Any, idx::Any...) where {T<:AbstractChannel, N<:AbstractController} = setindex!(strip.subArray, val, idx...)

"Implements a vectorized form of setindex! to ensure maximum efficiency"
function setindex!(strip::LEDStrip{T, N}, val::Union{Array{UInt8},UInt8}, idx::Union{AbstractArray, Number, Colon}) where {T<:AbstractChannel, N<:AbstractController}
    return setindex!(strip.subArray, val, idx)
end

"""
    Implements another vectorized form to cover slightly different input 
    params, but still want to type specialize for maximum performance
"""
function setindex!(
                   strip::LEDStrip{T, N}, 
                   val::Union{Array{UInt8},UInt8}, 
                   idx::Union{AbstractArray, Number, Colon}, 
                   idx2::Union{AbstractArray, Number, Colon}
                  ) where {T<:AbstractChannel, N<:AbstractController}
    return setindex!(strip.subArray, val, idx, idx2)
end


"""
    LEDController <: AbstractController

    Summary:
        Represents a particular networked LED controller.  Contains most of the memory for "real" LEDs
        
    Details:
        Contains the core representation of a LEDController for Irradiance.
        This class contains a large portion of the actual memory allocations for the system
        because it holds the memory for physical LED addresses.

    Fields:
        addrs::Array{UInt8, 2} - The address space for this controller, one dimension is for different LEDs
            and the other channel is for the different color channels
        strips::Array{LEDStrip} - An array containing all LEDStrips that are controlled by this controller
            and thus have their memory mapped into this controller
        location::Tuple{IPAddr,Int} - A tuple of an IPAddr, which is the IP address of the controller, and an
            Int, which is the port to contact the controller on.
        raw_data::Array{UInt8, 1} - A flattened form of the addrs field, for sending over the wire to the
            controller.  In this array each LED gets three adjacent indexes and then the next LED gets the
            next three indexes, and so on.
    Inner Constructors:
        LEDController(sz::Int, location::Tuple{IPAddr,Int})
            returns: LEDController initialized with no LEDStrips attached and zeroed data arrays

"""
mutable struct LEDController <: AbstractController
    addrs::Array{UInt8, 2}
    strips::Array{LEDStrip}
    location::Tuple{IPAddr, Int}
    raw_data::Array{UInt8, 1}
    function LEDController(sz::Int, location::Tuple{IPAddr, Int})
        return new(zeros(UInt8, sz, 3), Array{LEDStrip, 1}(0), location, Array{UInt8, 1}(sz*3))
    end
end

#=
    The below section implements the Array-like interface for LEDControllers
    Once again, Julia doesn't have proper interfaces, but there are informal ones
    made of collections of methods
=#
"Implements the length function for LEDControllers"
length(controller::LEDController) = length(controller.addrs)

"Implements a push function for LEDControllers"
push!(controller::LEDController, val::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}= push!(controller.strips, val)

"Implments a getindex function for LEDControllers"
getindex(controller::LEDController, idx...) = getindex(controller.addrs, idx...)

"Implements the eachindex function for LEDControllers, returns a range of all valid indices for the LEDController"
eachindex(c::LEDController) = 1:length(c)

"Implements the lastindex function for LEDControllers, returns the last valid index of the LEDController"
lastindex(c::LEDController) = length(c)

"Implements the setindex! function for LEDControllers, sets an index of the LEDController to a given value"
function setindex!(controller::LEDController, val::Any, idx::Any...)
    setindex!(controller.addrs, val, idx...)
end

"""
    LEDChannel <: AbstractChannel

    Summary:
        Abstracts LEDStrips into amorpheous channels to which effects are applied.

    Details:
        This contains the implementation of a AbstractChannel for Irradiance. This is the main abstraction used
        in the rest of the program for a collection of LED's, all effects are applied to LEDChannels, not 
        LEDStrips, so that effects can be independent of the physical layout of the LED's

    Fields:
        map::Array{Tuple{LEDStrip{LEDChannel,LEDController}, Float64, Float64, AFArray{Float32,1}}, 1} -
            An array of large tuples that contain four things: the LEDStrip, its start on the channel, its
            end on the channel, and the array on the GPU that contains the pseudo-indexes for that LEDStrip
        virtualmem::Array{UInt8} - The abstraction of LEDs provided to effects so that they don't have to
            worry about the details of LED density, position, etc.  This way effects are much more portable
            across setups given that those setups have a reasonable LEDChannel map setup.
        gpu_virtualmem::AFArray{Float32,2} - The memory allocation on the GPU used for the virtual memory 
            mentioned above.  Since all of the interpolation is executed on the GPU, we allocate arrays on
            the GPU semi-permanently so that there is less allocation overhead.  All data going through the
            channel passes through here at least once per frame (unless one is using a function eval effect)
        precision::Float64 - A somewhat arbitrary variable that determines how much memory to allocate to the
            virtual memory abstraction.  Allows higher fidelity rendering of effects assuming one has as a dense
            enough LED mapping that it exceeds the default 100 per channel. Higher precisions obviously cause more
            computation workload per frame.

    Inner Constructors:
        LEDChannel( 
            map::Array{Tuple{LEDStrip{LEDChannel,LEDController}, Float64, Float64, AFArray{Float32,1}}, 1},
            precision::Int64
        )
            returns: A LEDChannel initialized with zeroed out virtual memory, uses given map and precision.

"""
mutable struct LEDChannel <: AbstractChannel
    map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}
    virtualmem::Array{UInt8,2}
    gpu_virtualmem::AFArray{Float32,2}
    precision::Float64
    function LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}, precision::Int64)
        init_virtualmem = zeros(UInt8, precision, 3)
        gpu_virtualmem = AFArray(convert(Array{Float32}, init_virtualmem))
        return new(map, init_virtualmem, gpu_virtualmem, precision)
    end
end

"""
    getGPUIdxArray(strip::LEDStrip, x::Float64, y::Float64, precision::Real)::AFArray{Float32}

    Summary:
        Translates the 1:end indexes of the strip into pseudo-indexes for interpolation on the GPU

    Details:
        This function gets the virtual memory addresses corresponding to the real indices of the given
        strip.  Essentially it returns an array of equal size to the input strip, but each element in the
        returned array is the index that the LED at that position should reference in the GPU.  Note that
        these can be Float32s, this is intentional, since this data is then fed into in interpolation algorithm
        that doesn't mind non-integer indices.

    Arguments:
        strip::LEDStrip - The strip for which to get indexes
        x::Float64 - The start point of the strip in the LEDChannel
        y::Float64 - The end point of the strip in the LEDChannel
        precision - The precision of the LEDChannel being indexed

    Returns:
        AFArray{Float32, 1} (Array on GPU) of pseudo-indexes mapping to the LEDs in the LEDStrip
"""
function getGPUIdxArray(strip::LEDStrip, x::Float64, y::Float64, precision::Real)
    return AFArray(convert.(Float32, collect(linspace(x/100*precision, y/100*precision, size(strip,1)))))
end

"""
    LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64},1}, precision::Float64)

    Summary:
        Convenience constructor for an LEDChannel that starts with the given (non-GPU) map and precision

    Details:
        This function is a convenience constructor for LEDChannel that first creates a map with the proper
        gpuIdxArrays initialized on the GPU, then initializes an LEDChannel with that new, valid map.  Prevents
        us from having to do the GPU setup manually with every initialization of an LEDChannel.  This is the
        primary constructor used to build other more convenient constructors.

    Returns:
        LEDChannel initialized with zeroed out virtual memory and the given map and precision.
"""
function LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64},1}, precision::Float64)
    new_map = map(map) do x
        return (x[1:3]..., getGPUIdxArray(x[1:3]..., precision))
    end
    return LEDChannel(new_map, precision)
end

"LEDChannel overload to pass only the map and use a default precision"
LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}) = LEDChannel(map, 100)

"LEDChannel overload to pass only the precision and use a default (empty) map"
LEDChannel(precision::Int64) = LEDChannel(Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}(0), precision)

"LEDChannel overload to pass no arguments at all and use a default map, precision, etc."
LEDChannel() = LEDChannel(Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}(0), 100)

"Implements getindex for LEDChannel in a maximally generic way"
getindex(channel::LEDChannel, idx::Any...) = getindex(channel.virtualmem, idx...)

"Implements setindex! for LEDChannel in a very generic way"
setindex!(channel::LEDChannel, val, idx::Any...) = setindex!(channel.virtualmem, val, idx...)

"Implements setindex! for LEDChannel for a specialized value type of RGB for convenience in writing effects"
function setindex!(channel::LEDChannel, val::ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}}, idx...) 
    channel.virtualmem[idx...,1] = val.r.i
    channel.virtualmem[idx...,2] = val.g.i
    channel.virtualmem[idx...,3] = val.b.i
    return channel.virtualmem[idx...,:]
end

"Implements setindex! for LEDChannel for an array type of RGB for convenience and performance in writing effects"
function setindex!(channel::LEDChannel, val::Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}}}, idx...)
    setindex!(channel, [getfield(v, f).i for v in val, f in fieldnames(eltype(val))], idx..., :)
end

"Implements a length function for LEDChannels"
length(channel::LEDChannel) = length(channel.virtualmem)

"Implements a size function for LEDChannels, the most basic overload"
size(channel::LEDChannel, x::Int) = size(channel.virtualmem, x)

"""
    Implements a more generic size function for LEDChannels that catches more 
    at the expense of being less specialized (and thus slower, usually)
"""
size(channel::LEDChannel, x...) = size(channel.virtualmem, x...)

"""
    Implements an eachindex function for LEDChannels that allows easy iteration 
    by returning a range of valid indicies
"""
eachindex(channel::LEDChannel) = 1:length(channel)

"Implements the lastindex function for LEDChannel, returns the last valid index"
lastindex(c::LEDChannel) = length(c)

"""
    update!(f:Function, channel::LEDChannel)
    
    Summary:
        Updates the representations of physical LEDs according to a continuous function over [0.0,100.0]

    Details:
        The update! functions are probably two of the most carefully implemented functions in the
        whole project because there is a potentially a huge amount of processing to be done and
        this function has to be performant because it is called at least once every frame of
        execution.

        This version takes in a function and evaluates that function at all of the virtual indexes
        that the LEDChannel mapping specifies.  It writes the results of that function evaluation
        to the LEDStrip memory (and by reference the LEDController memory), which then can be sent
        out to the real controller and rendered onto the real LEDs.

        Note: Since the function is the first argument, this supports Julia's "do syntax".

    Arguments:
        f::Function - A continuous function from 0.0 to 100.0 that outputs a color for the LED at
            virtual index
        channel::LEDChannel - The channel on which to render the functional effect.

    Returns:
        None
"""
function update!(f::Function, channel::LEDChannel)
    for m in channel.map
        indicies = linspace(m[2]/100*precision, m[3]/100*channel.precision, size(m[1],1))
        m[1] .= f.(indices)
    end
end

"""
    update!(channel::LEDChannel)

    Summary:
        Updates the representations of physical LEDs by interpolating the virtual memory

    Details:
        This function is the bread and butter of most of the existing effects because it
        most closely mimics programming real LEDs, just in this case they aren't actually real.
        It works by taking the current state of the virtual memory and transferring that to a
        pre-allocated array on the GPU.  Then it considers a strip and within that strip a single
        color channel.  Using the LEDChannel's map's gpuIdxArray to provide the pseudo-indexes of
        the strip, it interpolates for each channel.  Then it transfers the data back to main
        memory, after which it applies bounds that prevent the data from overflowing a UInt8.
        Lastly it rounds the whole array to UInt8 and assigns those values to the strip.  
        
        This can be a rather large amount of work when there are many channels (i.e. 55) and large 
        numbers of LEDs per channel (i.e. 397).  Those numbers mentioned just so happen to be the 
        maximum currently possible with only one controller because UDP packet size limits me to 
        21835 LEDs per controller.  Thus a decent bit of care was taken to make this function efficient.

        Note: Presently this function is not thread safe as it does not have any sort of lock on
        the gpu_virtualmem as it transfers that to the GPU, nor does it lock the output path, like
        the controller memory or the strip memory view.

    Arguments:
        channel::LEDChannel - The channel to interpolate to concrete LED values.

    Returns:
        None
    
"""
function update!(channel::LEDChannel)
    channel.gpu_virtualmem::AFArray{Float32,2} = AFArray(convert.(Float32, channel.virtualmem))
    for m in channel.map
        strip = m[1]
        for k in 1:size(strip, 2)
            strip.subArray[:,k] .= round.(UInt8, min.( max.( Array( approx1(channel.gpu_virtualmem[:,k], m[4], AF_INTERP_CUBIC_SPLINE, 0f0) ), 0.0f0), 255.0f0) )
            #setindex!(strip.subArray, tmp, 1:size(strip.subArray,1), k)
        end
    end
end

"""
    push!(channel::LEDChannel, val::LEDStrip{T,N}) where {T<:AbstractChannel, N<:AbstractChannel}

    Summary:
        This function adds an LEDStrip to the LEDChannel's map in the default configuration

    Details:
        Adds an LEDStrip to the LEDChannel's map in the default configuration which is that the
        LEDStrip spans the whole channel range, [0.0,100.0].  If it already exists in the map,
        nothing is changed.

    Arguments:
        channel::LEDChannel - The channel to which to add the strip
        val::LEDStrip - The strip to add to the channel's map.

    Returns:
        LEDStrip which was added to the channel
    
"""
function push!(channel::LEDChannel, val::LEDStrip{T,N}) where {T<:AbstractChannel, N<:AbstractController}
    return push!(channel, val, 0.0, 100.0)
end

"""
    push!(channel::LEDChannel, val::LEDStrip{T,N}, startLoc::Real, endLoc::Real) where {T<:AbstractChannel, N:<AbstractController}

    Summary:
        This function adds an LEDStrip to the LEDChannel's map in the specified mapping

    Details:
        Adds an LEDStrip to the LEDChannel's map with the specified start and end location.
        This function does nothing if the value is already present in the LEDChannel's map.

    Arguments:
        channel::LEDChannel - The channel to which to add the strip
        val::LEDStrip - The strip to add to the channel's map
        startLoc::Real - A number representing the beginning of the strip's pseudo-indexes on the channel
        endLoc::Real - A number representing the end of the strip's pseudo-indexes on the channel

    Returns:
        LEDStrip which was added or already present on the channel

"""
function push!(channel::LEDChannel, val::LEDStrip{T,N}, startLoc::Real, endLoc::Real) where {T<:AbstractChannel, N<:AbstractController}
    if !((startLoc >= 0.0 && startLoc <= 100.0) && (endLoc >= 0.0 && endLoc <= 100.0))
        error("Strips must be assigned to locations between 0.0 and 100.0 on a channel")
    end
    if !(val in getindex.(channel.map, 3))
        return push!(channel.map, (val, startLoc, endLoc, getGPUIdxArray(val, startLoc, endLoc, channel.precision)))
    else 
        return val
    end
end

"""
    LEDChannel(channel1::LEDChannel, channel2::LEDChannel, offset::Float64)

    Summary:
        Another constructor overload for LEDChannel that allows merging and concatenating channels

    Details:
        Another constructor overload for LEDChannel that creates a new channel by merging
        two existing channels with a given offset.  So if you wanted to set them up to mirror
        each other, the offset would be zero, if you wanted to concatenate them, you would specify
        an offset of 100.0.  Negative offsets are also supported in case one wants to overlay the
        second channel to the left of the first channel.

    Arguments:
        channel1::LEDChannel - the first LEDChannel to merge or concatenate
        channel2::LEDChannel - the second LEDChannel to merge or concatenate
        offset::Float64 - A number representing how much to offset the channels when remapping,
            the resultant channel will be renomalized against the new overall width so 
            values from ~(-1000.0) to ~(+1000.0) are allowable.

    Returns:
        LEDChannel the resultant channel from the merge.
"""
function LEDChannel(channel1::LEDChannel, channel2::LEDChannel, offset::Float64)
    new_virtual_space = 100 + abs(offset)
    multiplier = 100/new_virtual_space
    old_map1 = deepcopy(channel1.map)
    old_map2 = deepcopy(channel2.map)
    new_map = Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}(length(channel1.map)+length(channel2.map))
    new_precision = max(channel1.precision, channel2.precision)
    indexed = 0
    offset1 = 0
    offset2 = 0
    if offset < 0
        offset1 = abs(offset)
    else
        offset2 = abs(offset)
    end
    for i in eachindex(channel1.map)
        indexed = i
        new_map[i] = old_map1[i]
        @. new_map[i][2:3] = (new_map[i][2:3]+offset1)*multiplier
        new_map[i][4] = getGPUIdxArray()
    end
    for i in eachindex(channel2.map)
        new_map[i+indexed] = old_map2[i]
        @. new_map[i+indexed][2:3] = (new_map[i+indexed][2:3]+offset2)*multiplier
        new_map[i+indexed][4] = getGPUIdxArray(new_map[i+indexed][1:3]..., new_precision)
    end
    return LEDChannel(new_map, new_precision)
end

"""
    LEDChannel(channels::Array{LEDChannels}, offsets::Array{Float64})
    
    Summary:
        Takes an Array of LEDChannels and merges them according to an array of offsets

    Details:
        A constructor overload that creates a new channel from an array of channels
        and an array of offsets (the first of which is the offset of the first channel
        and so on).  The merging process normalizes everything against the channel offset
        furthest to the left (furthest negative, even!).

    Arguments:
        channels::Array{LEDChannel} - An array of channels to be merged together
        offsets::Array{Float64} - An array (equal length as channels) of the offsets
            to be used to merge the channels

    Returns:
        LEDChannel the resultant channel from the merge.
"""
function LEDChannel(channels::Array{LEDChannel}, offsets::Array{Float64})
    root_offset = 0
    max_offset = maximum(offsets)
    min_offset = minimum(offsets)
    if min_offset < 0
        root_offset -= min_offset
        offsets .-= min_offset
    end
    new_virtual_space = (max_offset+100) - min_offset
    multiplier = 100/new_virtual_space
    new_precision = maximum(getfield.(maps, :precision))
    maps = deepcopy.(getfield.(channels, :map))
    for i in eachindex(maps)
        if i == 1
            map!(maps[i]) do x
                tmp = (x[1], ((x[2:3]+root_offset)*multiplier)..., x[4])
                tmp[4] = getGPUIdxArray(tmp[1:3]..., new_precision)
                return tmp
            end
        else
            map!(maps[i]) do x
                tmp = (x[1], ((x[2:3]+offsets[i-1])*multiplier)..., x[4])
                tmp[4] = getGPUIdxArray(tmp[1:3]..., new_precision)
                return tmp
            end
        end
    end
    return LEDChannel(vcat(maps...), new_precision)
end

"""
    LEDArray

    Summary:
        A convenience bundle that contains all of the relavent data to update
        the LEDs.
    
    Details:
        This structure bundles all of the important structures used by Irradiance
        into one large structure for convenience.

    Fields:
        controllers::Array{LEDController,1} - All of the active LEDControllers
        inactive_channels::Array{LEDChannel,1} - All of the inactive LEDChannels that
            are worth keeping around, such as "root channels" which only hold one
            LEDStrip mapped across the whole channel.
        channels::Array{LEDChannel,1} - All of the active channels that are being rendered to
        strips::Array{LEDStrip{LEDController,LEDChannel},1} - All of the currently known strips

    Inner Constructors:
        (default) LEDArray(
            controllers::Array{LEDController}, 
            inactive_channels::Array{LEDChannel,1},
            channels::Array{LEDChannel,1},
            strips::Array{LEDStrip{LEDController, LEDChannel},1}
            )
            Returns:
                LEDArray with specified values exactly as passed

"""
mutable struct LEDArray
    controllers::Array{LEDController,1}
    inactive_channels::Array{LEDChannel,1}
    channels::Array{LEDChannel,1}
    strips::Array{LEDStrip{LEDChannel, LEDController},1}
end

"""
    LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
    
    Summary:
        Concrete constructor free of the generic types previously needed to get around lookahead issues.

    Details:
        This is the concrete constructor for LEDStrip that uses the concrete implementations of LEDController
        and LEDChannel. Using as concrete of types as possible is good performance in Julia, so this was worth
        the parameterization etc. to get here.

    Arguments:
        name::String - A name for the strip
        channel::LEDChannel - The channel to attach this strip to
        controller::LEDController - The controller to attach this strip to
        startAddr::Int - The first index on the controller that this strip represents
        endAddr::Int - The last index on the controller that this strip represents

    Returns:
        LEDStrip{LEDChannel, LEDController} with the specified arguments set, and a reference to the relevant
            controller memory.
"""
function LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
    return LEDStrip{LEDChannel, LEDController}(name, channel, controller, startAddr, endAddr)
end
