! hydra_crypto.f90 — HYDRA cryptographic primitives in Fortran 2018.
!
! SHA-256 (FIPS 180-4), HKDF (RFC 5869), ChaCha20-Poly1305 AEAD
! (RFC 8439). All 32-bit arithmetic is carried in int64 with explicit
! masking: Fortran has no unsigned types, and every value here is
! kept in [0, 2^32), where int64 shifts and adds are exact.
!
! These implementations are verified against the published test
! vectors by hydra_protocol.f90 (self-test section): FIPS 180-4
! examples, RFC 5869 test case 1, RFC 8439 sections 2.5.2 and 2.8.2
! and appendix A.1. The same vectors pass in the project's reference
! implementation; two independent implementations agreeing with the
! RFCs is the correctness evidence.
module hydra_crypto
  use, intrinsic :: iso_fortran_env, only: i8 => int64, i1 => int8
  implicit none
  private
  public :: sha256, hmac_sha256, hkdf, chacha20_block
  public :: poly1305_mac, aead_encrypt, aead_decrypt, to_hex

  integer(i8), parameter :: M32 = 4294967295_i8

contains

  pure function rotr(x, n) result(r)
    integer(i8), intent(in) :: x
    integer, intent(in) :: n
    integer(i8) :: r
    r = iand(ior(ishft(x, -n), ishft(x, 32 - n)), M32)
  end function rotr

  pure function rotl(x, n) result(r)
    integer(i8), intent(in) :: x
    integer, intent(in) :: n
    integer(i8) :: r
    r = iand(ior(ishft(x, n), ishft(x, n - 32)), M32)
  end function rotl

  pure function load32le(b, off) result(w)
    integer(i1), intent(in) :: b(:)
    integer, intent(in) :: off          ! 0-based byte offset
    integer(i8) :: w
    w = iand(int(b(off + 1), i8), 255_i8) &
        + ishft(iand(int(b(off + 2), i8), 255_i8), 8) &
        + ishft(iand(int(b(off + 3), i8), 255_i8), 16) &
        + ishft(iand(int(b(off + 4), i8), 255_i8), 24)
  end function load32le

  pure function load32be(b, off) result(w)
    integer(i1), intent(in) :: b(:)
    integer, intent(in) :: off
    integer(i8) :: w
    w = ishft(iand(int(b(off + 1), i8), 255_i8), 24) &
        + ishft(iand(int(b(off + 2), i8), 255_i8), 16) &
        + ishft(iand(int(b(off + 3), i8), 255_i8), 8) &
        + iand(int(b(off + 4), i8), 255_i8)
  end function load32be

  pure subroutine store32be(w, b, off)
    integer(i8), intent(in) :: w
    integer(i1), intent(inout) :: b(:)
    integer, intent(in) :: off
    b(off + 1) = int(iand(ishft(w, -24), 255_i8), i1)
    b(off + 2) = int(iand(ishft(w, -16), 255_i8), i1)
    b(off + 3) = int(iand(ishft(w, -8), 255_i8), i1)
    b(off + 4) = int(iand(w, 255_i8), i1)
  end subroutine store32be

  pure subroutine store32le(w, b, off)
    integer(i8), intent(in) :: w
    integer(i1), intent(inout) :: b(:)
    integer, intent(in) :: off
    b(off + 1) = int(iand(w, 255_i8), i1)
    b(off + 2) = int(iand(ishft(w, -8), 255_i8), i1)
    b(off + 3) = int(iand(ishft(w, -16), 255_i8), i1)
    b(off + 4) = int(iand(ishft(w, -24), 255_i8), i1)
  end subroutine store32le

  function to_hex(b) result(s)
    integer(i1), intent(in) :: b(:)
    character(len=2 * size(b)) :: s
    character(len=16), parameter :: digits = '0123456789abcdef'
    integer :: i, v
    do i = 1, size(b)
       v = iand(int(b(i), i8), 255_i8)
       s(2 * i - 1:2 * i - 1) = digits(v / 16 + 1:v / 16 + 1)
       s(2 * i:2 * i) = digits(mod(v, 16) + 1:mod(v, 16) + 1)
    end do
  end function to_hex

  ! ---------------- SHA-256 ----------------
  subroutine sha256(msg, digest)
    integer(i1), intent(in) :: msg(:)
    integer(i1), intent(out) :: digest(32)
    integer(i8), parameter :: kk(64) = [ &
       int(z'428a2f98', i8), int(z'71374491', i8), int(z'b5c0fbcf', i8), int(z'e9b5dba5', i8), &
       int(z'3956c25b', i8), int(z'59f111f1', i8), int(z'923f82a4', i8), int(z'ab1c5ed5', i8), &
       int(z'd807aa98', i8), int(z'12835b01', i8), int(z'243185be', i8), int(z'550c7dc3', i8), &
       int(z'72be5d74', i8), int(z'80deb1fe', i8), int(z'9bdc06a7', i8), int(z'c19bf174', i8), &
       int(z'e49b69c1', i8), int(z'efbe4786', i8), int(z'0fc19dc6', i8), int(z'240ca1cc', i8), &
       int(z'2de92c6f', i8), int(z'4a7484aa', i8), int(z'5cb0a9dc', i8), int(z'76f988da', i8), &
       int(z'983e5152', i8), int(z'a831c66d', i8), int(z'b00327c8', i8), int(z'bf597fc7', i8), &
       int(z'c6e00bf3', i8), int(z'd5a79147', i8), int(z'06ca6351', i8), int(z'14292967', i8), &
       int(z'27b70a85', i8), int(z'2e1b2138', i8), int(z'4d2c6dfc', i8), int(z'53380d13', i8), &
       int(z'650a7354', i8), int(z'766a0abb', i8), int(z'81c2c92e', i8), int(z'92722c85', i8), &
       int(z'a2bfe8a1', i8), int(z'a81a664b', i8), int(z'c24b8b70', i8), int(z'c76c51a3', i8), &
       int(z'd192e819', i8), int(z'd6990624', i8), int(z'f40e3585', i8), int(z'106aa070', i8), &
       int(z'19a4c116', i8), int(z'1e376c08', i8), int(z'2748774c', i8), int(z'34b0bcb5', i8), &
       int(z'391c0cb3', i8), int(z'4ed8aa4a', i8), int(z'5b9cca4f', i8), int(z'682e6ff3', i8), &
       int(z'748f82ee', i8), int(z'78a5636f', i8), int(z'84c87814', i8), int(z'8cc70208', i8), &
       int(z'90befffa', i8), int(z'a4506ceb', i8), int(z'bef9a3f7', i8), int(z'c67178f2', i8)]
    integer(i8) :: h(0:7), w(0:63), a, b, c, d, e, f, g, hh, s0, s1, t1, t2, ch, maj
    integer(i1), allocatable :: padded(:)
    integer :: n, total, blk, i
    h = [int(z'6a09e667', i8), int(z'bb67ae85', i8), int(z'3c6ef372', i8), int(z'a54ff53a', i8), &
         int(z'510e527f', i8), int(z'9b05688c', i8), int(z'1f83d9ab', i8), int(z'5be0cd19', i8)]
    n = size(msg)
    total = ((n + 9 + 63) / 64) * 64
    allocate (padded(total))
    padded = 0_i1
    if (n > 0) padded(1:n) = msg
    padded(n + 1) = int(z'80', i1)
    ! 64-bit big-endian bit length in the last 8 bytes (messages here
    ! are far below 2^32 bits; write the low word only, big-endian)
    block
      integer(i8) :: bits
      bits = int(n, i8) * 8_i8
      padded(total - 3) = int(iand(ishft(bits, -24), 255_i8), i1)
      padded(total - 2) = int(iand(ishft(bits, -16), 255_i8), i1)
      padded(total - 1) = int(iand(ishft(bits, -8), 255_i8), i1)
      padded(total) = int(iand(bits, 255_i8), i1)
    end block
    do blk = 0, total / 64 - 1
       do i = 0, 15
          w(i) = load32be(padded, blk * 64 + 4 * i)
       end do
       do i = 16, 63
          s0 = ieor(ieor(rotr(w(i - 15), 7), rotr(w(i - 15), 18)), ishft(w(i - 15), -3))
          s1 = ieor(ieor(rotr(w(i - 2), 17), rotr(w(i - 2), 19)), ishft(w(i - 2), -10))
          w(i) = iand(w(i - 16) + s0 + w(i - 7) + s1, M32)
       end do
       a = h(0); b = h(1); c = h(2); d = h(3); e = h(4); f = h(5); g = h(6); hh = h(7)
       do i = 0, 63
          s1 = ieor(ieor(rotr(e, 6), rotr(e, 11)), rotr(e, 25))
          ch = ieor(iand(e, f), iand(not(e), g))
          t1 = iand(hh + s1 + ch + kk(i + 1) + w(i), M32)
          s0 = ieor(ieor(rotr(a, 2), rotr(a, 13)), rotr(a, 22))
          maj = ieor(ieor(iand(a, b), iand(a, c)), iand(b, c))
          t2 = iand(s0 + maj, M32)
          hh = g; g = f; f = e; e = iand(d + t1, M32)
          d = c; c = b; b = a; a = iand(t1 + t2, M32)
       end do
       h(0) = iand(h(0) + a, M32); h(1) = iand(h(1) + b, M32)
       h(2) = iand(h(2) + c, M32); h(3) = iand(h(3) + d, M32)
       h(4) = iand(h(4) + e, M32); h(5) = iand(h(5) + f, M32)
       h(6) = iand(h(6) + g, M32); h(7) = iand(h(7) + hh, M32)
    end do
    do i = 0, 7
       call store32be(h(i), digest, 4 * i)
    end do
    deallocate (padded)
  end subroutine sha256

  subroutine hmac_sha256(key, msg, mac)
    integer(i1), intent(in) :: key(:), msg(:)
    integer(i1), intent(out) :: mac(32)
    integer(i1) :: k64(64), inner(64 + size(msg)), outer(96), kh(32)
    integer :: i
    k64 = 0_i1
    if (size(key) > 64) then
       call sha256(key, kh); k64(1:32) = kh
    else
       k64(1:size(key)) = key
    end if
    do i = 1, 64
       inner(i) = ieor(k64(i), int(z'36', i1))
    end do
    if (size(msg) > 0) inner(65:) = msg
    call sha256(inner, kh)
    do i = 1, 64
       outer(i) = ieor(k64(i), int(z'5c', i1))
    end do
    outer(65:96) = kh
    call sha256(outer, mac)
  end subroutine hmac_sha256

  subroutine hkdf(salt, ikm, info, okm)
    integer(i1), intent(in) :: salt(:), ikm(:), info(:)
    integer(i1), intent(out) :: okm(:)
    integer(i1) :: prk(32), t(32), cat(32 + size(info) + 1)
    integer :: need, done, ctr, take
    if (size(salt) == 0) then
       block
         integer(i1) :: zeros(32)
         zeros = 0_i1
         call hmac_sha256(zeros, ikm, prk)
       end block
    else
       call hmac_sha256(salt, ikm, prk)
    end if
    need = size(okm); done = 0; ctr = 1; t = 0_i1
    do while (done < need)
       cat = 0_i1
       if (ctr > 1) cat(1:32) = t
       cat(33:32 + size(info)) = info
       cat(33 + size(info)) = int(ctr, i1)
       if (ctr == 1) then
          call hmac_sha256(prk, cat(33:33 + size(info)), t)
       else
          call hmac_sha256(prk, cat(1:32 + size(info) + 1), t)
       end if
       take = min(32, need - done)
       okm(done + 1:done + take) = t(1:take)
       done = done + take; ctr = ctr + 1
    end do
  end subroutine hkdf

  ! ---------------- ChaCha20 ----------------
  subroutine qr(x, a, b, c, d)
    integer(i8), intent(inout) :: x(0:15)
    integer, intent(in) :: a, b, c, d
    x(a) = iand(x(a) + x(b), M32); x(d) = rotl(ieor(x(d), x(a)), 16)
    x(c) = iand(x(c) + x(d), M32); x(b) = rotl(ieor(x(b), x(c)), 12)
    x(a) = iand(x(a) + x(b), M32); x(d) = rotl(ieor(x(d), x(a)), 8)
    x(c) = iand(x(c) + x(d), M32); x(b) = rotl(ieor(x(b), x(c)), 7)
  end subroutine qr

  subroutine chacha20_block(key, counter, nonce, block_out)
    integer(i1), intent(in) :: key(32), nonce(12)
    integer(i8), intent(in) :: counter
    integer(i1), intent(out) :: block_out(64)
    integer(i8) :: st(0:15), x(0:15)
    integer :: i, r
    st(0) = int(z'61707865', i8); st(1) = int(z'3320646e', i8)
    st(2) = int(z'79622d32', i8); st(3) = int(z'6b206574', i8)
    do i = 0, 7
       st(4 + i) = load32le(key, 4 * i)
    end do
    st(12) = counter
    do i = 0, 2
       st(13 + i) = load32le(nonce, 4 * i)
    end do
    x = st
    do r = 1, 10
       call qr(x, 0, 4, 8, 12); call qr(x, 1, 5, 9, 13)
       call qr(x, 2, 6, 10, 14); call qr(x, 3, 7, 11, 15)
       call qr(x, 0, 5, 10, 15); call qr(x, 1, 6, 11, 12)
       call qr(x, 2, 7, 8, 13); call qr(x, 3, 4, 9, 14)
    end do
    do i = 0, 15
       call store32le(iand(x(i) + st(i), M32), block_out, 4 * i)
    end do
  end subroutine chacha20_block

  subroutine chacha20_xor(key, counter, nonce, data)
    integer(i1), intent(in) :: key(32), nonce(12)
    integer(i8), intent(in) :: counter
    integer(i1), intent(inout) :: data(:)
    integer(i1) :: blk(64)
    integer(i8) :: ctr
    integer :: off, take, i
    ctr = counter; off = 0
    do while (off < size(data))
       call chacha20_block(key, ctr, nonce, blk)
       take = min(64, size(data) - off)
       do i = 1, take
          data(off + i) = ieor(data(off + i), blk(i))
       end do
       off = off + take; ctr = ctr + 1
    end do
  end subroutine chacha20_xor

  ! ---------------- Poly1305 (26-bit limbs, as in the reference) ----
  subroutine poly1305_mac(msg, key, tag)
    integer(i1), intent(in) :: msg(:), key(32)
    integer(i1), intent(out) :: tag(16)
    integer(i8) :: t0, t1, t2, t3, r0, r1, r2, r3, r4, s1, s2, s3, s4
    integer(i8) :: h0, h1, h2, h3, h4, d0, d1, d2, d3, d4, c
    integer(i8) :: g0, g1, g2, g3, g4, w0, w1, w2, w3, p0, p1, p2, p3
    integer(i1) :: blk(17)
    integer :: off, take, i
    t0 = load32le(key, 0); t1 = load32le(key, 4)
    t2 = load32le(key, 8); t3 = load32le(key, 12)
    r0 = iand(t0, int(z'3ffffff', i8))
    r1 = iand(ior(ishft(t0, -26), ishft(t1, 6)), int(z'3ffff03', i8))
    r2 = iand(ior(ishft(t1, -20), ishft(t2, 12)), int(z'3ffc0ff', i8))
    r3 = iand(ior(ishft(t2, -14), ishft(t3, 18)), int(z'3f03fff', i8))
    r4 = iand(ishft(t3, -8), int(z'fffff', i8))
    s1 = r1 * 5; s2 = r2 * 5; s3 = r3 * 5; s4 = r4 * 5
    h0 = 0; h1 = 0; h2 = 0; h3 = 0; h4 = 0
    off = 0
    do while (off < size(msg))
       take = min(16, size(msg) - off)
       blk = 0_i1
       if (take > 0) blk(1:take) = msg(off + 1:off + take)
       blk(take + 1) = 1_i1
       t0 = load32le(blk, 0); t1 = load32le(blk, 4)
       t2 = load32le(blk, 8); t3 = load32le(blk, 12)
       h0 = h0 + iand(t0, int(z'3ffffff', i8))
       h1 = h1 + iand(ior(ishft(t0, -26), ishft(t1, 6)), int(z'3ffffff', i8))
       h2 = h2 + iand(ior(ishft(t1, -20), ishft(t2, 12)), int(z'3ffffff', i8))
       h3 = h3 + iand(ior(ishft(t2, -14), ishft(t3, 18)), int(z'3ffffff', i8))
       h4 = h4 + iand(ishft(t3, -8), int(z'3ffffff', i8)) + ishft(int(blk(17), i8), 24)
       d0 = h0 * r0 + h1 * s4 + h2 * s3 + h3 * s2 + h4 * s1
       d1 = h0 * r1 + h1 * r0 + h2 * s4 + h3 * s3 + h4 * s2
       d2 = h0 * r2 + h1 * r1 + h2 * r0 + h3 * s4 + h4 * s3
       d3 = h0 * r3 + h1 * r2 + h2 * r1 + h3 * r0 + h4 * s4
       d4 = h0 * r4 + h1 * r3 + h2 * r2 + h3 * r1 + h4 * r0
       c = ishft(d0, -26); h0 = iand(d0, int(z'3ffffff', i8)); d1 = d1 + c
       c = ishft(d1, -26); h1 = iand(d1, int(z'3ffffff', i8)); d2 = d2 + c
       c = ishft(d2, -26); h2 = iand(d2, int(z'3ffffff', i8)); d3 = d3 + c
       c = ishft(d3, -26); h3 = iand(d3, int(z'3ffffff', i8)); d4 = d4 + c
       c = ishft(d4, -26); h4 = iand(d4, int(z'3ffffff', i8))
       h0 = h0 + c * 5
       c = ishft(h0, -26); h0 = iand(h0, int(z'3ffffff', i8)); h1 = h1 + c
       off = off + 16
    end do
    ! full carry
    c = ishft(h1, -26); h1 = iand(h1, int(z'3ffffff', i8)); h2 = h2 + c
    c = ishft(h2, -26); h2 = iand(h2, int(z'3ffffff', i8)); h3 = h3 + c
    c = ishft(h3, -26); h3 = iand(h3, int(z'3ffffff', i8)); h4 = h4 + c
    c = ishft(h4, -26); h4 = iand(h4, int(z'3ffffff', i8))
    h0 = h0 + c * 5
    c = ishft(h0, -26); h0 = iand(h0, int(z'3ffffff', i8)); h1 = h1 + c
    ! g = h + 5 - p ; select g if g4 >= 0 else h
    g0 = h0 + 5; c = ishft(g0, -26); g0 = iand(g0, int(z'3ffffff', i8))
    g1 = h1 + c; c = ishft(g1, -26); g1 = iand(g1, int(z'3ffffff', i8))
    g2 = h2 + c; c = ishft(g2, -26); g2 = iand(g2, int(z'3ffffff', i8))
    g3 = h3 + c; c = ishft(g3, -26); g3 = iand(g3, int(z'3ffffff', i8))
    g4 = h4 + c - ishft(1_i8, 26)
    if (g4 >= 0) then
       h0 = g0; h1 = g1; h2 = g2; h3 = g3; h4 = iand(g4, int(z'3ffffff', i8))
    end if
    ! serialize h as four 32-bit words, add pad s = key(17:32)
    w0 = ior(h0, ishft(iand(h1, 63_i8), 26))
    w1 = ior(ishft(h1, -6), ishft(iand(h2, 4095_i8), 20))
    w2 = ior(ishft(h2, -12), ishft(iand(h3, 262143_i8), 14))
    w3 = ior(ishft(h3, -18), ishft(iand(h4, 16777215_i8), 8))
    p0 = load32le(key, 16); p1 = load32le(key, 20)
    p2 = load32le(key, 24); p3 = load32le(key, 28)
    w0 = w0 + p0
    w1 = w1 + p1 + ishft(w0, -32); w0 = iand(w0, M32)
    w2 = w2 + p2 + ishft(w1, -32); w1 = iand(w1, M32)
    w3 = w3 + p3 + ishft(w2, -32); w2 = iand(w2, M32)
    w3 = iand(w3, M32)
    call store32le(w0, tag, 0); call store32le(w1, tag, 4)
    call store32le(w2, tag, 8); call store32le(w3, tag, 12)
  end subroutine poly1305_mac

  ! ---------------- AEAD ----------------
  subroutine aead_encrypt(key, nonce, aad, pt, ct, tag)
    integer(i1), intent(in) :: key(32), nonce(12), aad(:), pt(:)
    integer(i1), intent(out) :: ct(size(pt)), tag(16)
    integer(i1) :: blk(64), otk(32)
    call chacha20_block(key, 0_i8, nonce, blk)
    otk = blk(1:32)
    ct = pt
    call chacha20_xor(key, 1_i8, nonce, ct)
    call aead_tag(otk, aad, ct, tag)
  end subroutine aead_encrypt

  subroutine aead_decrypt(key, nonce, aad, ct, tag, pt, ok)
    integer(i1), intent(in) :: key(32), nonce(12), aad(:), ct(:), tag(16)
    integer(i1), intent(out) :: pt(size(ct))
    logical, intent(out) :: ok
    integer(i1) :: blk(64), otk(32), expect(16)
    integer :: i
    integer(i8) :: diff
    call chacha20_block(key, 0_i8, nonce, blk)
    otk = blk(1:32)
    call aead_tag(otk, aad, ct, expect)
    diff = 0_i8
    do i = 1, 16
       diff = ior(diff, int(ieor(expect(i), tag(i)), i8))
    end do
    ok = (diff == 0)
    pt = ct
    if (ok) call chacha20_xor(key, 1_i8, nonce, pt)
  end subroutine aead_decrypt

  subroutine aead_tag(otk, aad, ct, tag)
    integer(i1), intent(in) :: otk(32), aad(:), ct(:)
    integer(i1), intent(out) :: tag(16)
    integer(i1), allocatable :: buf(:)
    integer :: na, nc, total, i
    na = size(aad); nc = size(ct)
    total = ((na + 15) / 16) * 16 + ((nc + 15) / 16) * 16 + 16
    allocate (buf(total))
    buf = 0_i1
    if (na > 0) buf(1:na) = aad
    if (nc > 0) buf(((na + 15) / 16) * 16 + 1:((na + 15) / 16) * 16 + nc) = ct
    do i = 0, 7
       buf(total - 15 + i) = int(iand(ishft(int(na, i8), -8 * i), 255_i8), i1)
       buf(total - 7 + i) = int(iand(ishft(int(nc, i8), -8 * i), 255_i8), i1)
    end do
    call poly1305_mac(buf, otk, tag)
    deallocate (buf)
  end subroutine aead_tag

end module hydra_crypto
