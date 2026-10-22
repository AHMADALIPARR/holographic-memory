; HYDRA_PHASE_SCREEN — water-surface phase screen, IDL/GDL.
;
; The imaging side of HYDRA in the language the optical labs used:
; whole-array operations and native FFT, no explicit pixel loops
; except inside the mode accumulation (IDL vectorizes over the grid).
;
; Surface height is a sum of sinusoidal modes with gravity-wave
; dispersion OMEGA^2 = g * |k|; the imparted optical phase is
;   PHI = (2*!PI/LAMBDA) * (n_water - n_air) * h(x,y,t)
; (thin-screen surface-relief model; approximations in docs/HYDRA.md).
;
;   seed    : RANDOMN seed state (caller-owned, advanced in place,
;             the IDL idiom) — same seed + same t reproduces a frame;
;             a different t or seed is a different physical state.
; Returns: DOUBLE phase array [nx, ny] in radians.

FUNCTION HYDRA_PHASE_SCREEN, nx, ny, dx, t, seed, NMODES=nmodes, LAMBDA=lambda
  IF N_ELEMENTS(nmodes) EQ 0 THEN nmodes = 24
  IF N_ELEMENTS(lambda) EQ 0 THEN lambda = 532.0D-9
  n_diff = 1.333D - 1.0003D

  x = DINDGEN(nx) * dx
  y = DINDGEN(ny) * dx
  h = DBLARR(nx, ny)

  FOR m = 0, nmodes - 1 DO BEGIN
    fx = (2.0D * RANDOMU(seed) - 1.0D) * 900.0D     ; cycles/m
    fy = (2.0D * RANDOMU(seed) - 1.0D) * 900.0D
    kmag = 2.0D * !DPI * SQRT(fx^2 + fy^2)
    amp = 2.2D-6 * EXP(-kmag / 4000.0D) * (0.5D + RANDOMU(seed))
    omg = SQRT(9.81D * MAX([kmag, 1.0D]))
    ph0 = 2.0D * !DPI * RANDOMU(seed)
    ; whole-array mode: sin(kx*X + ky*Y - om*t + ph0) via outer sums
    arg = (2.0D * !DPI * fx) * (x # REPLICATE(1.0D, ny)) $
        + (2.0D * !DPI * fy) * (REPLICATE(1.0D, nx) # y) $
        - omg * t + ph0
    h += amp * SIN(arg)
  ENDFOR

  RETURN, h * (2.0D * !DPI / lambda) * n_diff
END
