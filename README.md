# Irradiance.jl
## Installation

## Usage

## What's In A Name?
This project was started out of frustration with [Radiance](https://github.com/zbanks/Radiance) and its lack of usability with simpler setups.  Radiance was intended for 2-D grid setups, but it doesn't do so well with strip based setups for two reasons.
1. Strips could only take advantage of a small number of its built-in effects
2. The Lux protocol that Lux uses as its primary backend is massive overkill for relatively uncomplicated controller setups.

This led me to create a new project targeted at strip-based lighting setups.  The two big differences in functionality are that it has a minimalist protocol that simplifies the client-controller code and that it's effects are targeted to look best on LED strips rather than screen-style 2-D grids.

## Why Is This Written In Julia?
Julia is a high-performance high-level language.  It is mostly aimed at the likes of MATLAB, but it also is a distinctly decent general purpose programming language.  The killer feature here is that it has libraries for PortAudio and FFTW
