! hydra_driver.f90 — HYDRA Fortran experiment driver.
!
! Experiments, in order:
!  1. Reference check: D=64, a=sin(i), b=cos(i) circular convolution
!     through hydra_kernels must reproduce the repository's own
!     reference value (reference/hrr_reference.f90): max_abs ~ 30.2156
!  2. HRR at D=10000 (the hyperdimensional regime): 16-symbol
!     codebook, 8 role-filler bindings superposed via DAXPY into one
!     memory vector; each filler recovered by correlation and cleanup
!     (DGEMV). Reports per-binding cosine and correctness.
!  3. Water-optics sessions: two phase screens from the same mode
!     seed at different times (plus one different-seed screen),
!     angular-spectrum propagation to a detector plane, intensity
!     statistics. Shows the physical layer produces distinguishable,
!     time-varying frames (SIMULATED data; see docs/HYDRA.md).
program hydra_driver
  use, intrinsic :: iso_fortran_env, only: dp => real64
  use hydra_kernels
  implicit none
  external :: daxpy, dscal
  real(dp) :: dnrm2
  external :: dnrm2

  ! ---------- 1. reference check ----------
  block
    integer, parameter :: d = 64
    real(dp) :: a(d), b(d), c(d)
    integer :: i
    do i = 1, d
       a(i) = sin(real(i, dp)); b(i) = cos(real(i, dp))
    end do
    c = hrr_bind(a, b)
    print '(A, F12.7)', 'refcheck_max_abs=', maxval(abs(c))
  end block

  ! ---------- 2. HRR at D = 10000 ----------
  block
    integer, parameter :: d = 10000, nsym = 16, nbind = 8
    real(dp), allocatable :: codebook(:, :), memory(:), probe(:)
    real(dp), allocatable :: bound(:), rec(:)
    real(dp) :: state, u1, u2, nrm, cosim
    integer :: s, i, k, best, correct
    allocate (codebook(d, nsym), memory(d), probe(d), bound(d), rec(d))
    state = 1234567.0_dp
    do s = 1, nsym
       do i = 1, d
          u1 = max(lcg_next(state), 1.0e-12_dp); u2 = lcg_next(state)
          codebook(i, s) = sqrt(-2.0_dp * log(u1)) * cos(6.283185307179586_dp * u2)
       end do
       nrm = dnrm2(d, codebook(:, s), 1)
       call dscal(d, 1.0_dp / nrm, codebook(:, s), 1)
    end do
    memory = 0.0_dp
    do k = 1, nbind
       bound = hrr_bind(codebook(:, 2 * k - 1), codebook(:, 2 * k))
       call daxpy(d, 1.0_dp, bound, 1, memory, 1)
    end do
    correct = 0
    do k = 1, nbind
       rec = hrr_correlate(memory, codebook(:, 2 * k - 1))
       call cleanup_search(codebook, rec, best, cosim)
       if (best == 2 * k) correct = correct + 1
       print '(A, I0, A, I0, A, F8.5, A, I0)', 'bind ', k, ' expect ', 2 * k, &
          ' cos=', cosim, ' got=', best
    end do
    print '(A, I0, A, I0)', 'hrr_recovered=', correct, '/', nbind
    deallocate (codebook, memory, probe, bound, rec)
  end block

  ! ---------- 3. water-optics sessions ----------
  block
    integer, parameter :: nx = 128, ny = 128, nmodes = 24
    real(dp), parameter :: dx = 100.0e-6_dp, lambda = 532.0e-9_dp, z = 0.02_dp
    real(dp) :: phi(nx, ny), seed
    complex(dp) :: field(nx, ny)
    real(dp) :: inten(nx, ny), stats(3)
    integer :: rep
    do rep = 1, 3
       seed = 987654.0_dp
       if (rep == 3) seed = 555555.0_dp       ! different physical state
       if (rep == 1) call phase_screen(nx, ny, dx, 0.00_dp, seed, nmodes, lambda, phi)
       if (rep == 2) call phase_screen(nx, ny, dx, 0.35_dp, seed, nmodes, lambda, phi)
       if (rep == 3) call phase_screen(nx, ny, dx, 0.00_dp, seed, nmodes, lambda, phi)
       field = cmplx(cos(phi), sin(phi), dp)  ! unit amplitude, phase = water
       call angular_spectrum(field, nx, ny, dx, lambda, z)
       inten = real(field * conjg(field))
       stats(1) = sum(inten) / real(nx * ny, dp)
       stats(2) = sum((inten - stats(1))**2) / real(nx * ny, dp)
       stats(3) = maxval(inten)
       print '(A, I0, A, F9.5, A, F9.5, A, F9.5)', 'frame ', rep, &
          ' mean=', stats(1), ' var=', stats(2), ' max=', stats(3)
       if (rep == 1) then
          open (unit = 21, file = 'results/frame_t0.txt', status = 'replace')
       else if (rep == 2) then
          open (unit = 21, file = 'results/frame_t1.txt', status = 'replace')
       else
          open (unit = 21, file = 'results/frame_other.txt', status = 'replace')
       end if
       write (21, *) inten(1, 1), inten(64, 64), inten(128, 128), stats(1), stats(2)
       close (21)
    end do
  end block

  print '(A)', 'hydra_driver: done'
end program hydra_driver
