using SampledSignals
import Base.getindex
import Base.setindex!
import Base.size
import Base.length
import Base.endof
mutable struct RotatingBuffer{T<:AbstractArray}
    data::Vector{T}
    current_order::Vector{Int64}
end
function RotatingBuffer(samp::T, num_bufs::Int64) where {T<:Any}
    init_data = [deepcopy(samp) for i in 1:num_bufs]
    init_order = [i for i in 1:num_bufs]
    return RotatingBuffer(init_data, init_order)
end
getindex(v::RotatingBuffer{T}, i::Int) where T<:AbstractArray = getindex(v.data, getindex(v.current_order, i));
setindex!(v::RotatingBuffer{T}, val::Any, i::Int) where T<:AbstractArray = setindex!(v.data, val, getindex(v.current_order, i));
size(v::RotatingBuffer{T}) where T<:AbstractArray = size(v.data);
length(v::RotatingBuffer{T}) where T<:AbstractArray = size(v.data);
endof(v::RotatingBuffer{T}) where T<:AbstractArray = endof(endof(current_order));
function rotate_clockwise!(v::RotatingBuffer{T}) where T<:AbstractArray
    if length(v.current_order) > 1
        tmp1 = v.current_order[1]
        tmp2 = v.current_order[2]
        for i in eachindex(v.current_order)
            if i != length(v.current_order)
                tmp2 = v.current_order[i+1]
                setindex!(v.current_order, tmp1, i+1)
                tmp1 = tmp2
            else
                v.current_order[1] = tmp1
            end
        end
    end
end