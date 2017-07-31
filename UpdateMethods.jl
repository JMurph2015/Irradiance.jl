using PortAudio, SampledSignals, DSP, Colors, Interpolations
const FFT_SCALE_DEFAULT = 1000.0
const fft_scale = Ref(FFT_SCALE_DEFAULT)
const fft_rescale_up_counter = Ref(0)
const fft_rescale_down_counter = Ref(0)
const FLOAT32_MAX = 3.4028235f38
const INT_32_MAX = 2^32-1

mutable struct AudioAnalysis
    spec_bufs::Array{AFArray{Complex{Float64}},1}
    audio_buffers::Array{AFArray{Float64},1}
    spec_buf_order::Array{Int,1}
    audio_buffer_order::Array{Int,1}
    delta_buffers::Array{AFArray{Float64},1}
    spec_obj::SpectrumBuf
    function AudioAnalysis(cpuAudio::SampleBuf, numBufs::Int)
        audio_buffers = [AFArray{Float64}(convert.(Float64, cpuAudio.data[:,1])) for i in 1:numBufs]
        spec_bufs = [fft(audio_buffers[1]) for j in 1:numBufs]
        audio_buf_order = [numBufs - (k - 1) for k in 1:numBufs]
        spec_buf_order = [numBufs - (l - 1) for l in 1:numBufs]
        delta_buffers = [abs(spec_bufs[1]) - abs(spec_bufs[end]) for m in 1:numBufs]
        spec_obj = SpectrumBuf(Array(spec_bufs[spec_buf_order[1]]), nframes(cpuAudio)/samplerate(cpuAudio))
        return new(spec_bufs, audio_buffers, spec_buf_order, audio_buf_order, delta_buffers, spec_obj)
    end
end

function rotate_array_clockwise!(arr::Array)
    tmp1 = arr[1]
    tmp2 = arr[2]
    for i in eachindex(arr)
        if i != length(arr)
            tmp2 = arr[i+1]
            setindex!(arr, tmp1, i+1)
            tmp1 = tmp2
        else
            arr[1] = tmp1
        end
    end
end

function push_audio!(ana::AudioAnalysis, cpuAudio::Array{Float32,1})
    ana.audio_buffers[ana.audio_buffer_order[end]] = AFArray(convert(Array{Float64}, cpuAudio))
    rotate_array_clockwise!(ana.audio_buffer_order)
end

function process_audio!(ana::AudioAnalysis, cpuAudio::SampledSignals.SampleBuf)
    push_audio!(ana, cpuAudio.data[:,1])

    # For the moment, the deltas will just share order with the spectrums, but that could be added in the future if needed.
    ana.spec_bufs[ana.spec_buf_order[end]] = fft(ana.audio_buffers[ana.audio_buffer_order[1]])
    ana.delta_buffers[ana.spec_buf_order[end]] = abs(ana.spec_bufs[ana.spec_buf_order[end]]) - abs(ana.spec_bufs[ana.spec_buf_order[1]])
    rotate_array_clockwise!(ana.spec_buf_order)

    ana.spec_obj.data .= ana.spec_bufs[ana.spec_buf_order[1]]
    ana.spec_obj.samplerate = nframes(cpuAudio)/samplerate(cpuAudio)

    handle_scaling(ana)
end

function binFFT(ana::AudioAnalysis, nbins::Int)
    rawspec = ana.spec_bufs[ana.spec_buf_order[1]]
    nbin = nbins + 1
    f(x) = 2.0^x
    dom = domain(ana.spec_obj)
    range = linspace(log(dom[2])/log(2), log(dom[end-1])/log(2), nbin)[1:nbins]
    bands = collect(abs.(f.(range))*length(dom)/dom[end])
    spec = abs(approx1(ana.spec_bufs[ana.spec_buf_order[1]], AFArray{Float64}(bands), AF_INTERP_CUBIC_SPLINE, 0.0f0))
    maxspec = maximum(spec)
    if length(spec) > nbins
        return Array(spec)[1:nbins], maxspec
    else
        return Array(spec), maxspec
    end
end

function binFFT(ana::AudioAnalysis, nbins::Int, cutoff::Int)
    rawspec = ana.spec_bufs[ana.spec_buf_order[1]][1:cutoff]
    nbin = nbins + 1
    f(x) = 2.0^x
    dom = domain(ana.spec_obj)
    range = linspace(log(dom[2])/log(2), log(dom[end-1])/log(2), nbin)[1:nbins]
    bands = collect(abs.(f.(range))*length(dom)/dom[end])
    spec = abs(approx1(ana.spec_bufs[ana.spec_buf_order[1]], AFArray{Float64}(bands), AF_INTERP_CUBIC_SPLINE, 0.0f0))
    maxspec = maximum(spec)
    if length(spec) > nbins
        return Array(spec)[1:nbins], maxspec
    else
        return Array(spec), maxspec
    end
end

@inline function hsl_to_rgb(color::ColorTypes.HSL)
    return hsl_to_rgb(color.h/360, color.s, color.l)
end

@inline function hsl_to_rgb(h::Real,s::Real,l::Real)::Array{UInt8}
    r = 0x00
    g = 0x00
    b = 0x00
    if s == 0
        r = round(UInt8, l*255)
        g = round(UInt8, l*255)
        b = round(UInt8, l*255)
    else
        q = l < 0.5 ? l * (1 + s) : l + s - l * s
        p = 2 * l - q
        r = hue2rgb(p, q, h + 1/3)*255
        g = hue2rgb(p, q, h)*255
        b = hue2rgb(p, q, h - 1/3)*255
        if isnan(r);r=0;end;
        if isnan(g);g=0;end;
        if isnan(b);b=0;end;
    end
    return round.(UInt8, [r, g, b])
end
function hue2rgb(p::Real, q::Real, t::Real)::Real
    if t < 0; t+=1; end;
    if t > 1; t-=1; end;
    if t < 1/6; return p + (q - p) * 6 * t; end;
    if t < 1/2; return q; end;
    if t < 2/3; return p + (q - p) * (2/3 - t) * 6; end;
    return p
end

function gfft(buf::SampledSignals.SampleBuf)
    return SpectrumBuf(Array(fft(ArrayFire.AFArray(buf.data))), nframes(buf)/samplerate(buf))
end

function gfft!(buf::SampledSignals.SampleBuf, gpu_buf1::AFArray, spec::SampledSignals.SpectrumBuf, gpu_buf2::AFArray)
    gpu_buf1 .= buf.data
    gpu_buf2 = fft(gpu_buf1)
    spec.data .= gpu_buf2
    spec.samplerate = nframes(buf)/samplerate(buf)
end

function handle_scaling(ana::AudioAnalysis)
    spec = abs(ana.spec_bufs[ana.spec_buf_order[1]])
    maxspec = maximum(spec)
    mean_delta = mean(abs(ana.delta_buffers[ana.spec_buf_order[1]]))
    spec_coef = (mean(spec)+maxspec+mean_delta)/3
    if maxspec > fft_scale[]*1.0
        spec.*=fft_scale[]/maxspec
        fft_scale[] = maxspec * 1.2
        fft_rescale_up_counter[] += 4
        if fft_rescale_up_counter[] > 35
            fft_scale[] *= 1.5
            fft_rescale_up_counter[] = 0
        end
    elseif spec_coef > fft_scale[]*0.50
        fft_rescale_up_counter[] += 2
        if fft_rescale_up_counter[] > 20
            fft_scale[] *= 1.25
        end
    elseif spec_coef > fft_scale[]*0.30
        fft_rescale_up_counter[] += 1
        if fft_rescale_up_counter[] > 15
            fft_scale[] *= 1.05
        end
    elseif spec_coef < fft_scale[] * 0.1 && maxspec > fft_scale[]/100
        fft_scale[] /= 1.05
        spec.*= !isnan(fft_scale[]/spec_coef * 0.25) ? fft_scale[]/spec_coef * 0.25 : fft_scale[]/0.1
        fft_rescale_down_counter[] += 4
        if fft_rescale_down_counter[] > 35
            fft_scale[] /= 1.5
            fft_rescale_down_counter[] = 0
        end
    elseif spec_coef < fft_scale[] * 0.20
        fft_rescale_down_counter[] += 1
        if fft_rescale_down_counter[] > 15
            fft_scale[] /= 1.05
        end
    end
    if maxspec < FFT_SCALE_DEFAULT/100 && fft_scale[] > FFT_SCALE_DEFAULT
        spec = zeros(AFArray{Float64}, size(spec))
        fft_scale[] = FFT_SCALE_DEFAULT
    end
    if maxspec > fft_scale[]
        spec = max(spec-fft_scale[], 0.0)+fft_scale[].*(spec.>fft_scale[])
    end
    return spec, maxspec
end