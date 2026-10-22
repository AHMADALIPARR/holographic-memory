; HYDRA_SESSION — simulated detector-session experiment (IDL/GDL).
;
; Generates three SIMULATED detector frames through the water phase
; screen + angular-spectrum pipeline: same physical state at t=0 and
; t=0.35 s, and an independently prepared state (different seed).
; Prints intensity statistics per frame — the raw material the
; entropy assessment consumes. Simulated data; never physical
; entropy evidence (docs/HYDRA.md states the rule).

PRO HYDRA_SESSION
  nx = 128 & ny = 128
  dx = 100.0D-6
  lambda = 532.0D-9
  z = 0.02D

  labels = ['same-state t=0.00', 'same-state t=0.35', 'other-state t=0.00']
  times = [0.0D, 0.35D, 0.0D]
  seeds = [987654L, 987654L, 555555L]

  FOR r = 0, 2 DO BEGIN
    seed = seeds[r]
    phi = HYDRA_PHASE_SCREEN(nx, ny, dx, times[r], seed, LAMBDA=lambda)
    field = DCOMPLEX(COS(phi), SIN(phi))       ; unit-amplitude input
    det = HYDRA_PROPAGATE(field, dx, lambda, z)
    inten = ABS(det)^2
    m = MOMENT(inten)
    PRINT, labels[r], ' mean=', m[0], ' var=', m[1], ' max=', MAX(inten), $
      FORMAT = '(A, A, F8.5, A, F8.5, A, F8.5)'
  ENDFOR
END
