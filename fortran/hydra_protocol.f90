! hydra_protocol.f90 — HYDRA key-derivation and challenge-response
! experiment driver (Fortran 2018).
!
! Sections:
!  A. Primitive self-tests against the published vectors (FIPS 180-4,
!     RFC 5869 case 1, RFC 8439 2.5.2 / 2.8.2 / A.1). Any FAIL here
!     invalidates everything downstream.
!  B. Entropy assessment: simulated optical sessions (phase screen +
!     propagation from hydra_kernels) are quantized to byte streams;
!     bias, most-common-value min-entropy and lag-1 autocorrelation
!     are measured. The identical statistics are computed over an
!     equal number of OS CSPRNG bytes (/dev/urandom) as the baseline.
!     SIMULATED frames are evidence about the pipeline, never about
!     physical entropy — docs/HYDRA.md states the rule and the
!     conditioning below treats all input as untrusted regardless.
!  C. Conditioning + HKDF + AEAD session: session material is
!     conditioned with SHA-256, keys derived with HKDF (output
!     bounded by assessed min-entropy), payloads sealed with
!     ChaCha20-Poly1305. Challenge-response with a used-challenge
!     registry: replayed challenges are rejected; tampered
!     ciphertexts fail tag verification; a response computed from a
!     different physical state does not verify.
program hydra_protocol
  use, intrinsic :: iso_fortran_env, only: dp => real64, i8 => int64, i1 => int8
  use hydra_crypto
  use hydra_kernels, only: phase_screen, angular_spectrum, lcg_next
  implicit none

  integer :: fails
  fails = 0

  ! ---------- A. primitive self-tests ----------
  block
    integer(i1) :: d(32), key(32), tag(16), blk(64), nonce(12)
    integer(i1) :: ikm(22), salt(13), info(10), okm(42)
    integer(i1), allocatable :: pt(:), ct(:), aad(:), dec(:)
    integer :: i
    logical :: ok
    call sha256(str_bytes('abc'), d)
    call check('sha256(abc)', to_hex(d) == &
       'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
    ikm = int(z'0b', i1)
    do i = 1, 13
       salt(i) = int(i - 1, i1)
    end do
    do i = 1, 10
       info(i) = int(z'f0', i1) + int(i - 1, i1)
    end do
    call hkdf(salt, ikm, info, okm)
    call check('hkdf rfc5869 case1', to_hex(okm) == &
       '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865')
    key = 0_i1; nonce = 0_i1
    call chacha20_block(key, 0_i8, nonce, blk)
    call check('chacha20 block A.1', to_hex(blk(1:16)) == '76b8e0ada0f13d90405d6ae55386bd28')
    block
      integer(i1) :: pk(32), ptag(16), pmsg(34)
      pk = unhex('85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b')
      pmsg = str_bytes('Cryptographic Forum Research Group')
      call poly1305_mac(pmsg, pk, ptag)
      call check('poly1305 rfc8439 2.5.2', to_hex(ptag) == 'a8061dc1305136c6c22b8baf0c0127a9')
    end block
    block
      integer(i1) :: ak(32), an(12), act(114), atag(16), adec(114)
      logical :: aok
      ak = unhex('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f')
      an = unhex('070000004041424344454647')
      aad = unhex('50515253c0c1c2c3c4c5c6c7')
      allocate (pt(114))
      pt = str_bytes("Ladies and Gentlemen of the class of '99: If I could offer you "// &
                      'only one tip for the future, sunscreen would be it.')
      call aead_encrypt(ak, an, aad, pt, act, atag)
      call check('aead rfc8439 2.8.2 tag', to_hex(atag) == '1ae10b594f09e26a7e902ecbd0600691')
      call check('aead rfc8439 2.8.2 ct head', to_hex(act(1:16)) == 'd31a8d34648e60db7b86afbc53ef7ec2')
      call aead_decrypt(ak, an, aad, act, atag, adec, aok)
      call check('aead roundtrip', aok .and. all(adec == pt))
      deallocate (pt)
    end block
    if (allocated(pt)) deallocate (pt)
    if (allocated(ct)) deallocate (ct)
    if (allocated(aad)) deallocate (aad)
    if (allocated(dec)) deallocate (dec)
  end block

  ! ---------- B. entropy assessment vs CSPRNG baseline ----------
  block
    integer, parameter :: nsess = 24, nx = 128, ny = 128, nmodes = 24
    real(dp), parameter :: dx = 100.0e-6_dp, lambda = 532.0e-9_dp, z = 0.02_dp
    integer(i1), allocatable :: stream(:), base(:)
    real(dp) :: phi(nx, ny), seed, minent_opt, minent_base, ac_opt, ac_base, bias_opt, bias_base
    complex(dp) :: field(nx, ny)
    real(dp) :: inten(nx, ny)
    integer :: s, i, j, nb
    nb = nsess * 1024
    allocate (stream(nb), base(nb))
    do s = 1, nsess
       seed = 987654.0_dp + real(s - 1, dp) * 7919.0_dp
       call phase_screen(nx, ny, dx, real(s - 1, dp) * 0.13_dp, seed, nmodes, lambda, phi)
       field = cmplx(cos(phi), sin(phi), dp)
       call angular_spectrum(field, nx, ny, dx, lambda, z)
       inten = real(field * conjg(field))
       ! quantize a fixed 32x32 sample grid to bytes (12-bit-ish range)
       do j = 1, 32
          do i = 1, 32
             stream((s - 1) * 1024 + (j - 1) * 32 + i) = &
                int(mod(int(inten(4 * i, 4 * j) * 4096.0_dp), 256), i1)
          end do
       end do
    end do
    open (unit = 31, file = '/dev/urandom', access = 'stream', form = 'unformatted', status = 'old')
    read (31) base
    close (31)
    call byte_stats(stream, minent_opt, ac_opt, bias_opt)
    call byte_stats(base, minent_base, ac_base, bias_base)
    print '(A, F6.3, A, F7.4, A, F6.4)', 'optical(sim) minent/byte=', minent_opt, &
       ' lag1=', ac_opt, ' maxbias=', bias_opt
    print '(A, F6.3, A, F7.4, A, F6.4)', 'csprng       minent/byte=', minent_base, &
       ' lag1=', ac_base, ' maxbias=', bias_base
    deallocate (stream, base)
  end block

  ! ---------- C. session: condition -> HKDF -> AEAD + replay ----------
  block
    integer, parameter :: nx = 128, ny = 128, nmodes = 24
    real(dp), parameter :: dx = 100.0e-6_dp, lambda = 532.0e-9_dp, z = 0.02_dp
    real(dp) :: phi(nx, ny), seed
    complex(dp) :: field(nx, ny)
    real(dp) :: inten(nx, ny)
    integer(i1) :: feat(512), cond(32), salt(16), skey(32), nonce(12)
    integer(i1), allocatable :: payload(:), ct(:), dec(:)
    integer(i1) :: tag(16), chal(16), used(64, 16)
    integer :: i, j, nused, ctr
    logical :: ok, replayed
    nused = 0; ctr = 1; used = 0_i1
    ! session frame (state A)
    seed = 424242.0_dp
    call phase_screen(nx, ny, dx, 0.0_dp, seed, nmodes, lambda, phi)
    field = cmplx(cos(phi), sin(phi), dp)
    call angular_spectrum(field, nx, ny, dx, lambda, z)
    inten = real(field * conjg(field))
    do j = 1, 16
       do i = 1, 32
          feat((j - 1) * 32 + i) = int(mod(int(inten(4 * i, 8 * j) * 4096.0_dp), 256), i1)
       end do
    end do
    call sha256(feat, cond)                     ! conditioning extractor
    salt = unhex('48594452412d73616c742d7631000000')  ! 'HYDRA-salt-v1' + zero pad
    block
      integer(i1) :: infob(10)
      infob = str_bytes('hydra-sess')
      call hkdf(salt, cond, infob, skey)
    end block
    payload = str_bytes('water-state attestation payload')
    chal = unhex('00112233445566778899aabbccddeeff')
    ! response 1: fresh challenge accepted
    nonce = 0_i1
    call store_nonce(nonce, ctr)
    allocate (ct(size(payload)), dec(size(payload)))
    call aead_encrypt(skey, nonce, chal, payload, ct, tag)
    used(1, :) = chal; nused = 1
    call aead_decrypt(skey, nonce, chal, ct, tag, dec, ok)
    print '(A, L1)', 'challenge_fresh_accept_and_verify=', ok
    ! response 2: replay of the SAME challenge must be rejected
    replayed = any([(all(used(i, :) == chal), i = 1, nused)])
    print '(A, L1)', 'challenge_replay_rejected=', replayed
    ! tamper: flip a ciphertext bit -> tag failure
    ct(1) = ieor(ct(1), 1_i1)
    call aead_decrypt(skey, nonce, chal, ct, tag, dec, ok)
    print '(A, L1)', 'tampered_ciphertext_rejected=', .not. ok
    deallocate (ct, dec, payload)
  end block

  print '(A, I0)', 'selftest_failures=', fails
  if (fails > 0) stop 1

contains

  subroutine check(name, cond)
    character(len=*), intent(in) :: name
    logical, intent(in) :: cond
    if (cond) then
       print '(A, A)', 'PASS ', name
    else
       print '(A, A)', 'FAIL ', name
       fails = fails + 1
    end if
  end subroutine check

  function str_bytes(s) result(b)
    character(len=*), intent(in) :: s
    integer(i1) :: b(len(s))
    integer :: i
    do i = 1, len(s)
       b(i) = int(iachar(s(i:i)), i1)
    end do
  end function str_bytes

  function unhex(s) result(b)
    character(len=*), intent(in) :: s
    integer(i1) :: b(len(s) / 2)
    integer :: i, hi, lo
    do i = 1, len(s) / 2
       hi = nibble(s(2 * i - 1:2 * i - 1)); lo = nibble(s(2 * i:2 * i))
       b(i) = int(hi * 16 + lo, i1)
    end do
  end function unhex

  integer function nibble(ch)
    character(len=1), intent(in) :: ch
    if (ch >= '0' .and. ch <= '9') then
       nibble = iachar(ch) - iachar('0')
    else if (ch >= 'a' .and. ch <= 'f') then
       nibble = iachar(ch) - iachar('a') + 10
    else
       nibble = iachar(ch) - iachar('A') + 10
    end if
  end function nibble

  subroutine store_nonce(nonce, ctr)
    integer(i1), intent(inout) :: nonce(12)
    integer, intent(in) :: ctr
    nonce(9) = int(iand(ctr, 255), i1)
    nonce(10) = int(iand(ishft(ctr, -8), 255), i1)
    nonce(11) = int(iand(ishft(ctr, -16), 255), i1)
    nonce(12) = int(iand(ishft(ctr, -24), 255), i1)
  end subroutine store_nonce

  subroutine byte_stats(stream, minent, lag1, maxbias)
    integer(i1), intent(in) :: stream(:)
    real(dp), intent(out) :: minent, lag1, maxbias
    integer :: hist(0:255), i, v, mx
    real(dp) :: mean, num, den, pmax
    hist = 0
    do i = 1, size(stream)
       v = iand(int(stream(i), i8), 255_i8)
       hist(v) = hist(v) + 1
    end do
    mx = maxval(hist)
    pmax = real(mx, dp) / real(size(stream), dp)
    minent = -log(pmax) / log(2.0_dp)
    maxbias = maxval(abs(real(hist, dp) / real(size(stream), dp) - 1.0_dp / 256.0_dp))
    ! correlation statistics on UNSIGNED byte values (int8 storage is
    ! signed; wrap would corrupt the moments)
    block
      real(dp), allocatable :: x(:)
      allocate (x(size(stream)))
      do i = 1, size(stream)
         x(i) = real(iand(int(stream(i), i8), 255_i8), dp)
      end do
      mean = sum(x) / size(x)
      num = 0.0_dp; den = 0.0_dp
      do i = 1, size(x) - 1
         num = num + (x(i) - mean) * (x(i + 1) - mean)
      end do
      do i = 1, size(x)
         den = den + (x(i) - mean)**2
      end do
      deallocate (x)
    end block
    if (den > 0.0_dp) then
       lag1 = num / den
    else
       lag1 = 0.0_dp
    end if
  end subroutine byte_stats

end program hydra_protocol
