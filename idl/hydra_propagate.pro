; HYDRA_PROPAGATE — angular-spectrum propagation of a complex field.
;
;   E_z = IFFT( FFT(E_0) * H ),  H = exp(i 2 pi z sqrt(1/lambda^2
;         - fx^2 - fy^2)); components with fx^2 + fy^2 > 1/lambda^2
;         are evanescent and zeroed.
;
; IDL's FFT is unnormalized in the forward direction and carries the
; 1/N factor on the inverse — the same convention as the Fortran
; kernels in ../fortran, so intensity statistics are comparable
; across the two stacks.

FUNCTION HYDRA_FREQ, n, dx
  ; wrapped frequency axis (cycles/m) for an n-point grid
  f = DINDGEN(n)
  half = n / 2
  IF n GT 1 THEN f[half + 1:*] = f[half + 1:*] - n
  RETURN, f / (n * dx)
END

FUNCTION HYDRA_PROPAGATE, field, dx, lambda, z
  dims = SIZE(field, /DIMENSIONS)
  nx = dims[0] & ny = dims[1]
  fx = HYDRA_FREQ(nx, dx)
  fy = HYDRA_FREQ(ny, dx)
  FX = fx # REPLICATE(1.0D, ny)
  FY = REPLICATE(1.0D, nx) # fy
  arg = 1.0D / lambda^2 - FX^2 - FY^2
  H = DCOMPLEXARR(nx, ny)
  vis = WHERE(arg GT 0.0D, count)
  IF count GT 0 THEN $
    H[vis] = EXP(DCOMPLEX(0.0D, 2.0D * !DPI * z) * SQRT(arg[vis]))
  spec = FFT(field, -1)
  spec *= H
  RETURN, FFT(spec, 1)
END
