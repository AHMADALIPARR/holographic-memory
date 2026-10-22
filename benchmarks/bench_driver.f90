! bench_driver.f90 - HYDRA benchmark harness (Fortran 2018).
!
! Measures the operations the repository README lists, using the
! shipped kernels in fortran/hydra_kernels.f90 and the same
! codebook recipe as fortran/hydra_driver.f90 (LCG-driven
! Box-Muller columns, unit-normalized):
!   1. direct O(n^2) convolution versus chirp-z hrr_bind
!   2. capacity sweep: recovery versus number of stored bindings
!   3. cleanup quality versus corruption ratio (zeroed trace share)
! Timing uses cpu_time over repeated calls; medians are reported.
!
! Build (from repo root):
!   gfortran-13 -O2 -o /tmp/hydra_bench fortran/hydra_kernels.f90 benchmarks/bench_driver.f90 /lib/x86_64-linux-gnu/libblas.so.3 /lib/x86_64-linux-gnu/liblapack.so.3
! Run:
!   /tmp/hydra_bench
program bench_driver
  use hydra_kernels
  use, intrinsic :: iso_fortran_env, only: dp => real64, int64
  implicit none

  integer, parameter :: reps = 5
  real(dp) :: t0, t1, times(reps)
  real(dp), external :: dnrm2

  write(*,'(A)') 'HYDRA benchmark harness (Fortran kernels, cpu_time, median of 5)'

  ! ---- 1. direct vs chirp-z convolution -------------------------
  write(*,'(A)') ''
  write(*,'(A)') 'direct O(n^2) convolution vs chirp-z hrr_bind:'
  write(*,'(A)') '     n     direct_ms    chirp-z_ms'
  block
    integer, parameter :: NSIZES(3) = [256, 1024, 4096]
    real(dp), allocatable :: a(:), b(:), out(:)
    integer :: i, r, n
    do i = 1, 3
      n = NSIZES(i)
      allocate(a(n), b(n), out(n))
      call fill_rand(a, 1000 + n); call fill_rand(b, 2000 + n)
      do r = 1, reps
        call cpu_time(t0); call conv_direct(a, b, out); call cpu_time(t1)
        times(r) = (t1 - t0) * 1000.0_dp
      end do
      write(*,'(I6, F12.3)', advance='no') n, median(times)
      do r = 1, reps
        call cpu_time(t0); out = hrr_bind(a, b); call cpu_time(t1)
        times(r) = (t1 - t0) * 1000.0_dp
      end do
      write(*,'(F13.3)') median(times)
      deallocate(a, b, out)
    end do
  end block

  ! ---- 2. capacity sweep at D = 10000 ---------------------------
  write(*,'(A)') ''
  write(*,'(A)') 'capacity sweep at D=10000 (chirp-z bind, cleanup_search):'
  write(*,'(A)') '  bindings   recovered   mean_cosine   bind_ms   cleanup_ms'
  block
    integer, parameter :: D = 10000, NS = 64
    real(dp) :: codebook(D, NS), tracev(D), probe(D)
    real(dp) :: state, u1, u2, nrm, cosim, cos_sum, bind_ms
    integer :: s, i, nb, r, best, rec
    state = 1234567.0_dp
    do s = 1, NS
      do i = 1, D
        u1 = max(lcg_next(state), 1.0e-12_dp); u2 = lcg_next(state)
        codebook(i, s) = sqrt(-2.0_dp * log(u1)) * cos(6.283185307179586_dp * u2)
      end do
      nrm = dnrm2(D, codebook(:, s), 1)
      call dscal(D, 1.0_dp / nrm, codebook(:, s), 1)
    end do
    do nb = 4, 32, 4
      do r = 1, reps
        tracev = 0.0_dp
        call cpu_time(t0)
        do i = 1, nb
          tracev = tracev + hrr_bind(codebook(:, 2 * i - 1), codebook(:, 2 * i))
        end do
        call cpu_time(t1); times(r) = (t1 - t0) * 1000.0_dp
      end do
      bind_ms = median(times)
      do r = 1, reps
        call cpu_time(t0)
        do i = 1, nb
          probe = hrr_correlate(tracev, codebook(:, 2 * i - 1))
          call cleanup_search(codebook, probe, best, cosim)
        end do
        call cpu_time(t1); times(r) = (t1 - t0) * 1000.0_dp
      end do
      rec = 0; cos_sum = 0.0_dp
      do i = 1, nb
        probe = hrr_correlate(tracev, codebook(:, 2 * i - 1))
        call cleanup_search(codebook, probe, best, cosim)
        cos_sum = cos_sum + cosim
        if (best == 2 * i) rec = rec + 1
      end do
      write(*,'(I10, I11, F13.4, F11.3, F12.3)') nb, rec, cos_sum / nb, bind_ms, median(times)
    end do
  end block

  ! ---- 3. cleanup quality versus corruption ---------------------
  write(*,'(A)') ''
  write(*,'(A)') 'corruption sweep at D=1024, 4 bindings (zeroed fraction of the trace):'
  write(*,'(A)') '  zero_frac   recovered_of_4   probe_cosine'
  block
    integer, parameter :: D = 1024, NS = 16, NB = 4
    real(dp) :: codebook(D, NS), tracev(D), dmg(D), probe(D)
    real(dp) :: state, u1, u2, nrm, cosim, zf
    integer :: s, i, k, best, rec
    state = 7654321.0_dp
    do s = 1, NS
      do i = 1, D
        u1 = max(lcg_next(state), 1.0e-12_dp); u2 = lcg_next(state)
        codebook(i, s) = sqrt(-2.0_dp * log(u1)) * cos(6.283185307179586_dp * u2)
      end do
      nrm = dnrm2(D, codebook(:, s), 1)
      call dscal(D, 1.0_dp / nrm, codebook(:, s), 1)
    end do
    tracev = 0.0_dp
    do i = 1, NB
      tracev = tracev + hrr_bind(codebook(:, 2 * i - 1), codebook(:, 2 * i))
    end do
    do k = 0, 4
      zf = 0.25_dp * k
      dmg = tracev
      dmg(1:int(D * zf)) = 0.0_dp
      rec = 0
      do i = 1, NB
        probe = hrr_correlate(dmg, codebook(:, 2 * i - 1))
        call cleanup_search(codebook, probe, best, cosim)
        if (best == 2 * i) rec = rec + 1
      end do
      probe = hrr_correlate(dmg, codebook(:, 1))
      call cleanup_search(codebook, probe, best, cosim)
      write(*,'(F10.2, I15, F15.4)') zf, rec, cosim
    end do
  end block

contains

  subroutine fill_rand(v, seed)
    real(dp), intent(out) :: v(:)
    integer, intent(in) :: seed
    integer :: j
    integer(int64) :: s
    s = int(seed, int64)
    do j = 1, size(v)
      s = mod(s * 6364136223846793005_int64 + 1442695040888963407_int64, 9223372036854775807_int64)
      v(j) = real(mod(s, 2000000_int64), dp) / 1000000.0_dp - 1.0_dp
    end do
  end subroutine fill_rand

  subroutine conv_direct(a, b, out)
    real(dp), intent(in) :: a(:), b(:)
    real(dp), intent(out) :: out(:)
    integer :: k, j, idx, nn
    nn = size(a)
    do k = 1, nn
      out(k) = 0.0_dp
      do j = 1, nn
        idx = k - j + 1
        if (idx < 1) idx = idx + nn
        out(k) = out(k) + a(j) * b(idx)
      end do
    end do
  end subroutine conv_direct

  function median(x) result(m)
    real(dp), intent(in) :: x(:)
    real(dp) :: m, xs(size(x)), tmp
    integer :: i2, j2
    xs = x
    do i2 = 1, size(xs)
      do j2 = i2 + 1, size(xs)
        if (xs(j2) < xs(i2)) then; tmp = xs(i2); xs(i2) = xs(j2); xs(j2) = tmp; end if
      end do
    end do
    m = xs((size(xs) + 1) / 2)
  end function median

end program bench_driver
