! hydra_kernels.f90 — HYDRA low-level kernels, Fortran 2018.
!
! Historical architecture, kept deliberately: the orchestration can
! live anywhere, but the arithmetic that touches the massive arrays
! lives here, in explicit memory-managed Fortran, with the vector
! algebra delegated to BLAS/LAPACK exactly as the hyperdimensional
! computing stacks of the FFT era were built:
!
!   superposition      -> DAXPY
!   similarity         -> DDOT / DNRM2
!   cleanup search     -> DGEMV (codebook matrix x probe)
!   binding/unbinding  -> circular convolution via DFT (radix-2 FFT
!                         with a Bluestein chirp-z path for the
!                         non-power-of-two dimension D = 10000)
!   wave propagation   -> angular spectrum, separable 2-D FFT
!   water phase screen -> precomputed sinusoid tables (direct
!                         memory-managed evaluation, no per-pixel
!                         transcendental calls in the hot loop)
!
! Conventions match the repository's Rust engine (post-repair):
!   convolution  c_k = sum_j a_j * b_{k-j}
!   correlation  r_k = sum_j a_j * b_{j-k}      (a = signal, b = key)
! so correlation(bind(role, value), role) recovers value.
module hydra_kernels
  use, intrinsic :: iso_fortran_env, only: dp => real64, i8 => int64
  implicit none
  private
  public :: fft1d, dft_any, idft_any, hrr_bind, hrr_correlate
  public :: cleanup_search, phase_screen, angular_spectrum
  public :: lcg_next

  real(dp), parameter :: pi = 3.14159265358979323846_dp

contains

  ! ---------------- deterministic portable PRNG ----------------
  ! Double-precision LCG, exact in IEEE double (same construction as
  ! matlab/keyed_randn.m): modulus 2^32, multiplier 1664525.
  function lcg_next(state) result(u)
    real(dp), intent(inout) :: state
    real(dp) :: u
    state = mod(1664525.0_dp * state + 1013904223.0_dp, 4294967296.0_dp)
    u = state / 4294967296.0_dp
  end function lcg_next

  ! ---------------- FFT ----------------
  ! Iterative radix-2 FFT, in place. Forward sign convention: exp(-i * angle).
  subroutine fft1d(x, invert)
    complex(dp), intent(inout) :: x(:)
    logical, intent(in) :: invert
    integer :: n, i, j, len, k, bit
    real(dp) :: ang
    complex(dp) :: wlen, w, u, v, tmp
    n = size(x)
    ! bit reversal
    j = 0
    do i = 1, n - 1
       bit = ishft(n, -1)
       do while (iand(j, bit) /= 0)
          j = ieor(j, bit)
          bit = ishft(bit, -1)
       end do
       j = ieor(j, bit)
       if (i < j) then
          tmp = x(i + 1); x(i + 1) = x(j + 1); x(j + 1) = tmp
       end if
    end do
    len = 2
    do while (len <= n)
       ang = 2.0_dp * pi / real(len, dp)
       if (.not. invert) ang = -ang
       wlen = cmplx(cos(ang), sin(ang), dp)
       do i = 1, n, len
          w = cmplx(1.0_dp, 0.0_dp, dp)
          do k = 0, len / 2 - 1
             u = x(i + k)
             v = x(i + k + len / 2) * w
             x(i + k) = u + v
             x(i + k + len / 2) = u - v
             w = w * wlen
          end do
       end do
       len = len * 2
    end do
    if (invert) x = x / real(n, dp)
  end subroutine fft1d

  ! Exact DFT of arbitrary length via Bluestein's chirp-z algorithm.
  function dft_any(x) result(out)
    complex(dp), intent(in) :: x(:)
    complex(dp) :: out(size(x))
    integer :: n, m, k
    complex(dp), allocatable :: a(:), b(:), fa(:), fb(:)
    real(dp) :: ang
    n = size(x)
    if (iand(n, n - 1) == 0) then
       out = x
       call fft1d(out, .false.)
       return
    end if
    m = 1
    do while (m < 2 * n)
       m = m * 2
    end do
    allocate (a(m), b(m), fa(m), fb(m))
    a = cmplx(0.0_dp, 0.0_dp, dp); b = a
    do k = 0, n - 1
       ang = -pi * real(k, dp)**2 / real(n, dp)
       a(k + 1) = x(k + 1) * cmplx(cos(ang), sin(ang), dp)
       ang = pi * real(k, dp)**2 / real(n, dp)
       b(k + 1) = cmplx(cos(ang), sin(ang), dp)
       if (k > 0) b(m - k + 1) = b(k + 1)
    end do
    fa = a; fb = b
    call fft1d(fa, .false.); call fft1d(fb, .false.)
    fa = fa * fb
    call fft1d(fa, .true.)
    do k = 0, n - 1
       ang = -pi * real(k, dp)**2 / real(n, dp)
       out(k + 1) = fa(k + 1) * cmplx(cos(ang), sin(ang), dp)
    end do
    deallocate (a, b, fa, fb)
  end function dft_any

  function idft_any(x) result(out)
    complex(dp), intent(in) :: x(:)
    complex(dp) :: out(size(x))
    out = conjg(dft_any(conjg(x))) / real(size(x), dp)
  end function idft_any

  ! ---------------- HRR algebra ----------------
  function hrr_bind(a, b) result(c)
    real(dp), intent(in) :: a(:), b(:)
    real(dp) :: c(size(a))
    complex(dp), allocatable :: fa(:), fb(:)
    allocate (fa(size(a)), fb(size(a)))
    fa = dft_any(cmplx(a, 0.0_dp, dp))
    fb = dft_any(cmplx(b, 0.0_dp, dp))
    c = real(idft_any(fa * fb))
    deallocate (fa, fb)
  end function hrr_bind

  function hrr_correlate(a, b) result(r)
    ! r_k = sum_j a_j * b_{j-k}: convolution of a with the involution
    ! of b, b*_i = b_{-i mod n}.
    real(dp), intent(in) :: a(:), b(:)
    real(dp) :: r(size(a))
    real(dp) :: binv(size(a))
    integer :: n, i
    n = size(a)
    binv(1) = b(1)
    do i = 2, n
       binv(i) = b(n - i + 2)
    end do
    r = hrr_bind(a, binv)
  end function hrr_correlate

  ! Cleanup: codebook columns are symbols; scores = C^T . probe via
  ! DGEMV; returns the 1-based index of the best match and its cosine.
  subroutine cleanup_search(codebook, probe, best, best_cos)
    real(dp), intent(in) :: codebook(:, :)   ! (dim, nsym), column-major
    real(dp), intent(in) :: probe(:)
    integer, intent(out) :: best
    real(dp), intent(out) :: best_cos
    real(dp), allocatable :: scores(:), norms(:)
    real(dp) :: ddot, dnrm2, pn
    integer :: nsym, s
    external :: dgemv, ddot, dnrm2
    nsym = size(codebook, 2)
    allocate (scores(nsym), norms(nsym))
    call dgemv('T', size(codebook, 1), nsym, 1.0_dp, codebook, &
               size(codebook, 1), probe, 1, 0.0_dp, scores, 1)
    do s = 1, nsym
       norms(s) = dnrm2(size(codebook, 1), codebook(:, s), 1)
    end do
    pn = dnrm2(size(probe), probe, 1)
    best = 1; best_cos = -2.0_dp
    do s = 1, nsym
       if (norms(s) > 0.0_dp .and. pn > 0.0_dp) then
          if (scores(s) / (norms(s) * pn) > best_cos) then
             best_cos = scores(s) / (norms(s) * pn)
             best = s
          end if
       end if
    end do
    deallocate (scores, norms)
  end subroutine cleanup_search

  ! ---------------- water phase screen ----------------
  ! Surface height h(x,y,t) as a finite sum of sinusoidal modes with
  ! gravity-wave dispersion omega^2 = g * |k|. The phase imparted to a
  ! beam crossing the surface relief is
  !   phi(x,y,t) = (2 pi / lambda) * (n_water - n_air) * h(x,y,t)
  ! (thin-screen / surface-relief approximation; see docs/HYDRA.md).
  ! Sinusoid tables are precomputed once into caller-owned arrays:
  ! direct memory-managed evaluation, per the design note.
  subroutine phase_screen(nx, ny, dx, t, seed, nmodes, lambda, phi)
    integer, intent(in) :: nx, ny, nmodes
    real(dp), intent(in) :: dx, t, lambda
    real(dp), intent(inout) :: seed
    real(dp), intent(out) :: phi(nx, ny)
    real(dp) :: fx(nmodes), fy(nmodes), amp(nmodes), omg(nmodes), ph0(nmodes)
    real(dp) :: u, kx, ky, kmag, n_diff
    integer :: m, i, j
    real(dp), allocatable :: sx(:), cx(:)
    n_diff = 1.333_dp - 1.0003_dp
    do m = 1, nmodes
       u = lcg_next(seed); fx(m) = (2.0_dp * u - 1.0_dp) * 900.0_dp  ! cycles/m, +-900
       u = lcg_next(seed); fy(m) = (2.0_dp * u - 1.0_dp) * 900.0_dp
       kmag = 2.0_dp * pi * sqrt(fx(m)**2 + fy(m)**2)
       u = lcg_next(seed); amp(m) = 2.2e-6_dp * exp(-kmag / 4000.0_dp) * (0.5_dp + u)
       omg(m) = sqrt(9.81_dp * max(kmag, 1.0_dp))
       u = lcg_next(seed); ph0(m) = 2.0_dp * pi * u
    end do
    allocate (sx(nx), cx(nx))
    phi = 0.0_dp
    do m = 1, nmodes
       kx = 2.0_dp * pi * fx(m); ky = 2.0_dp * pi * fy(m)
       ! Precompute this mode's x-sinusoids once; each row then needs
       ! only sin(A + B) = sinA cosB + cosA sinB with B = ky*y - om*t
       ! + p0. No transcendental calls inside the pixel loop.
       do i = 1, nx
          sx(i) = sin(kx * real(i - 1, dp) * dx)
          cx(i) = cos(kx * real(i - 1, dp) * dx)
       end do
       do j = 1, ny
          block
            real(dp) :: bphase, cb, sb
            bphase = ky * real(j - 1, dp) * dx - omg(m) * t + ph0(m)
            cb = cos(bphase); sb = sin(bphase)
            do i = 1, nx
               phi(i, j) = phi(i, j) + amp(m) * (sx(i) * cb + cx(i) * sb)
            end do
          end block
       end do
    end do
    deallocate (sx, cx)
    phi = phi * (2.0_dp * pi / lambda) * n_diff
  end subroutine phase_screen

  ! ---------------- angular-spectrum propagation ----------------
  ! Propagate a complex field by distance z:
  !   E_z = IFFT2( FFT2(E_0) * H ),  H = exp(i 2 pi z sqrt(1/lambda^2
  !         - fx^2 - fy^2)), evanescent components (|f| > 1/lambda)
  !         are set to zero.
  subroutine angular_spectrum(field, nx, ny, dx, lambda, z)
    complex(dp), intent(inout) :: field(nx, ny)
    integer, intent(in) :: nx, ny
    real(dp), intent(in) :: dx, lambda, z
    complex(dp), allocatable :: col(:), row(:)
    real(dp) :: fx, fy, arg
    integer :: i, j
    allocate (col(ny), row(nx))
    do j = 1, ny
       row = field(:, j); call fft1d(row, .false.); field(:, j) = row
    end do
    do i = 1, nx
       col = field(i, :); call fft1d(col, .false.); field(i, :) = col
    end do
    do j = 1, ny
       fy = freq_of(j, ny, dx)
       do i = 1, nx
          fx = freq_of(i, nx, dx)
          arg = 1.0_dp / lambda**2 - fx**2 - fy**2
          if (arg <= 0.0_dp) then
             field(i, j) = cmplx(0.0_dp, 0.0_dp, dp)
          else
             field(i, j) = field(i, j) * cmplx(cos(2.0_dp * pi * z * sqrt(arg)), &
                                               sin(2.0_dp * pi * z * sqrt(arg)), dp)
          end if
       end do
    end do
    do j = 1, ny
       row = field(:, j); call fft1d(row, .true.); field(:, j) = row
    end do
    do i = 1, nx
       col = field(i, :); call fft1d(col, .true.); field(i, :) = col
    end do
    deallocate (col, row)
  contains
    function freq_of(idx, n, d) result(f)
      integer, intent(in) :: idx, n
      real(dp), intent(in) :: d
      real(dp) :: f
      if (idx - 1 <= n / 2) then
         f = real(idx - 1, dp) / (real(n, dp) * d)
      else
         f = real(idx - 1 - n, dp) / (real(n, dp) * d)
      end if
    end function freq_of
  end subroutine angular_spectrum

end module hydra_kernels
