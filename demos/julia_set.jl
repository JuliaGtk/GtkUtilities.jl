# This file performs computations for rendering the Julia set iteration
#    z -> z - (z^3-1)/(3z^2)
# It takes a number of shortcuts and makes some optimizations for faster
# performance---this should not be viewed as definitive for computation
# of fractals.

const ITER = 15
const ITER_wait = 5
const sthresh = 5.0

function iterate!{T<:Real}(s::Matrix{T}, z_r::Matrix{T}, z_i::Matrix{T}, xlim, ylim)
    fill!(s, 0)
    one_third = convert(T, 1/3)
    @inbounds for (iy,yv) in enumerate(linspace(ylim[1],ylim[2],size(s,2)))
        for (ix,xv) in enumerate(linspace(xlim[1],xlim[2],size(s,1)))
            z_r[ix,iy] = xv
            z_i[ix,iy] = yv
        end
        for n = 1:ITER
            sf = n > ITER_wait ? 1 : 0
            @simd for ix = 1:size(s,1)
                # z -> z - (z^3-1)/(3*z^2) iteration, optimized for performance
                # The complex inversion is implemented manually, since we
                # have a real numerator
                x, y = z_r[ix,iy], z_i[ix,iy]
                x2, y2 = x*x, y*y
                p2 = x2 - y2
                f = 1/(p2*p2 + 4*x2*y2)
                z2inv_r, z2inv_i = f*p2, -2*f*x*y  # 1/z^2
                x, y = one_third*(2*x+z2inv_r), one_third*(2*y+z2inv_i)
                z_r[ix,iy], z_i[ix,iy] = x, y
                s[ix,iy] += sf*abs(x*x+y*y-1)
            end
        end
    end
    nothing
end

alloc{T}(::Type{T}, m, n=m) = zeros(T, m, n), zeros(T, m, n), zeros(T, m, n), Array(RGB{N0f8}, m, n)

function colorize!(col::Matrix{RGB{N0f8}}, s, z_r, z_i)
    for i in eachindex(s)
        if s[i] > sthresh
            col[i] = RGB(1,1,1)
        else
            sm = smap(s[i])
            if z_r[i] > 0
                col[i] = HSV(0,sm,1)
            else
                if z_i[i] > 0
                    col[i] = HSV(120,sm,1)
                else
                    col[i] = HSV(240,sm,1)
                end
            end
        end
    end
    col
end

smap(s) = clamp(log(sthresh/s)/5, 0, 1)
