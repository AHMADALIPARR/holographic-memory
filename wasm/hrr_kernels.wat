;; hrr_kernels.wat - HRR arithmetic kernels in WebAssembly text format.
;;
;; This module owns ALL bulk f64 arithmetic for the engine: circular
;; convolution, circular correlation, FFT convolution, dot products
;; and vector accumulation. The Rust crate keeps only the functor
;; API (bind / unbind / superimpose / cleanup / codebook) and the
;; f64 host glue that moves vectors in and out of linear memory.
;;
;; Linear-memory layout (byte offsets, sized for n <= 16384):
;;   A    0        input vector a, 8 bytes per element
;;   B    131072   input vector b, 8 bytes per element
;;   OUT  262144   result vector, 8 bytes per element
;;   CA   393216   complex scratch A, 16 bytes per element (re, im)
;;   CB   655360   complex scratch B, 16 bytes per element (re, im)
;; Memory: 16 pages = 1 MiB, exported as "mem".
;;
;; The FFT mirrors, operation for operation, the iterative radix-2
;; implementation that used to live in src/convolution.rs: same
;; bit-reversal, same twiddle recurrence (w = w * wlen), forward
;; angle -2*pi/len, inverse angle +2*pi/len with 1/n scaling applied
;; by the caller-visible fft_conv export. cos/sin are imported from
;; the host ("env"), the only two imports.
;;
;; Exports (n is the vector length, passed as i32):
;;   conv(n)        OUT[k] = sum_j A[j] * B[(k - j) mod n]
;;   corr(n)        OUT[k] = sum_j A[j] * B[(j - k) mod n]
;;   fft_conv(n)    OUT = circular convolution via FFT (n power of 2)
;;   dot_ab(n)      returns sum_j A[j] * B[j] as f64
;;   add_a_to_out(n)  OUT[j] = OUT[j] + A[j]
;;   zero_out(n)      OUT[j] = 0
;;
;; Build: wat2wasm hrr_kernels.wat -o hrr_kernels.wasm

(module
  (import "env" "cos" (func $cos (param f64) (result f64)))
  (import "env" "sin" (func $sin (param f64) (result f64)))
  (memory (export "mem") 16)

  (global $A i32 (i32.const 0))
  (global $B i32 (i32.const 131072))
  (global $OUT i32 (i32.const 262144))
  (global $CA i32 (i32.const 393216))
  (global $CB i32 (i32.const 655360))

  (func $ld (param $base i32) (param $i i32) (result f64)
    (f64.load (i32.add (local.get $base) (i32.mul (local.get $i) (i32.const 8)))))
  (func $st (param $base i32) (param $i i32) (param $v f64)
    (f64.store (i32.add (local.get $base) (i32.mul (local.get $i) (i32.const 8))) (local.get $v)))
  (func $ldr (param $base i32) (param $i i32) (result f64)
    (f64.load (i32.add (local.get $base) (i32.mul (local.get $i) (i32.const 16)))))
  (func $ldi (param $base i32) (param $i i32) (result f64)
    (f64.load (i32.add (i32.add (local.get $base) (i32.mul (local.get $i) (i32.const 16))) (i32.const 8))))
  (func $str (param $base i32) (param $i i32) (param $v f64)
    (f64.store (i32.add (local.get $base) (i32.mul (local.get $i) (i32.const 16))) (local.get $v)))
  (func $sti (param $base i32) (param $i i32) (param $v f64)
    (f64.store (i32.add (i32.add (local.get $base) (i32.mul (local.get $i) (i32.const 16))) (i32.const 8)) (local.get $v)))

  (func (export "conv") (param $n i32)
    (local $k i32) (local $j i32) (local $idx i32) (local $acc f64)
    (local.set $k (i32.const 0))
    (block $bdone (loop $lout
      (br_if $bdone (i32.ge_s (local.get $k) (local.get $n)))
      (local.set $acc (f64.const 0))
      (local.set $j (i32.const 0))
      (block $bj (loop $lin
        (br_if $bj (i32.ge_s (local.get $j) (local.get $n)))
        (local.set $idx (i32.sub (local.get $k) (local.get $j)))
        (if (i32.lt_s (local.get $idx) (i32.const 0))
          (then (local.set $idx (i32.add (local.get $idx) (local.get $n)))))
        (local.set $acc (f64.add (local.get $acc)
          (f64.mul (call $ld (global.get $A) (local.get $j))
                   (call $ld (global.get $B) (local.get $idx)))))
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br $lin)))
      (call $st (global.get $OUT) (local.get $k) (local.get $acc))
      (local.set $k (i32.add (local.get $k) (i32.const 1)))
      (br $lout))))

  (func (export "corr") (param $n i32)
    (local $k i32) (local $j i32) (local $idx i32) (local $acc f64)
    (local.set $k (i32.const 0))
    (block $bdone (loop $lout
      (br_if $bdone (i32.ge_s (local.get $k) (local.get $n)))
      (local.set $acc (f64.const 0))
      (local.set $j (i32.const 0))
      (block $bj (loop $lin
        (br_if $bj (i32.ge_s (local.get $j) (local.get $n)))
        (local.set $idx (i32.sub (local.get $j) (local.get $k)))
        (if (i32.lt_s (local.get $idx) (i32.const 0))
          (then (local.set $idx (i32.add (local.get $idx) (local.get $n)))))
        (local.set $acc (f64.add (local.get $acc)
          (f64.mul (call $ld (global.get $A) (local.get $j))
                   (call $ld (global.get $B) (local.get $idx)))))
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br $lin)))
      (call $st (global.get $OUT) (local.get $k) (local.get $acc))
      (local.set $k (i32.add (local.get $k) (i32.const 1)))
      (br $lout))))

  (func (export "dot_ab") (param $n i32) (result f64)
    (local $j i32) (local $acc f64)
    (local.set $acc (f64.const 0))
    (local.set $j (i32.const 0))
    (block $bd (loop $l
      (br_if $bd (i32.ge_s (local.get $j) (local.get $n)))
      (local.set $acc (f64.add (local.get $acc)
        (f64.mul (call $ld (global.get $A) (local.get $j))
                 (call $ld (global.get $B) (local.get $j)))))
      (local.set $j (i32.add (local.get $j) (i32.const 1)))
      (br $l)))
    (local.get $acc))

  (func (export "add_a_to_out") (param $n i32)
    (local $j i32)
    (local.set $j (i32.const 0))
    (block $bd (loop $l
      (br_if $bd (i32.ge_s (local.get $j) (local.get $n)))
      (call $st (global.get $OUT) (local.get $j)
        (f64.add (call $ld (global.get $OUT) (local.get $j))
                 (call $ld (global.get $A) (local.get $j))))
      (local.set $j (i32.add (local.get $j) (i32.const 1)))
      (br $l))))

  (func (export "zero_out") (param $n i32)
    (local $j i32)
    (local.set $j (i32.const 0))
    (block $bd (loop $l
      (br_if $bd (i32.ge_s (local.get $j) (local.get $n)))
      (call $st (global.get $OUT) (local.get $j) (f64.const 0))
      (local.set $j (i32.add (local.get $j) (i32.const 1)))
      (br $l))))

  ;; In-place iterative radix-2 FFT on the complex array at $base.
  ;; $inv = 0: forward, angle -2*pi/len. $inv = 1: inverse direction,
  ;; angle +2*pi/len, WITHOUT the 1/n scaling (fft_conv applies it).
  (func $fft (param $base i32) (param $n i32) (param $inv i32)
    (local $i i32) (local $j i32) (local $bit i32) (local $len i32) (local $half i32)
    (local $k i32) (local $p i32) (local $q i32)
    (local $angle f64) (local $wlr f64) (local $wli f64) (local $wr f64) (local $wi f64)
    (local $ur f64) (local $ui f64) (local $v0r f64) (local $v0i f64)
    (local $vr f64) (local $vi f64) (local $tr f64) (local $ti f64)
    ;; bit-reversal permutation
    (local.set $j (i32.const 0))
    (local.set $i (i32.const 1))
    (block $bd (loop $l
      (br_if $bd (i32.ge_s (local.get $i) (local.get $n)))
      (local.set $bit (i32.shr_s (local.get $n) (i32.const 1)))
      (block $bw (loop $lw
        (br_if $bw (i32.eqz (i32.and (local.get $j) (local.get $bit))))
        (local.set $j (i32.xor (local.get $j) (local.get $bit)))
        (local.set $bit (i32.shr_s (local.get $bit) (i32.const 1)))
        (br $lw)))
      (local.set $j (i32.xor (local.get $j) (local.get $bit)))
      (if (i32.lt_s (local.get $i) (local.get $j)) (then
        (local.set $tr (call $ldr (local.get $base) (local.get $i)))
        (local.set $ti (call $ldi (local.get $base) (local.get $i)))
        (call $str (local.get $base) (local.get $i) (call $ldr (local.get $base) (local.get $j)))
        (call $sti (local.get $base) (local.get $i) (call $ldi (local.get $base) (local.get $j)))
        (call $str (local.get $base) (local.get $j) (local.get $tr))
        (call $sti (local.get $base) (local.get $j) (local.get $ti))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $l)))
    ;; butterfly stages
    (local.set $len (i32.const 2))
    (block $bd2 (loop $l2
      (br_if $bd2 (i32.gt_s (local.get $len) (local.get $n)))
      (local.set $half (i32.shr_s (local.get $len) (i32.const 1)))
      (local.set $angle (f64.div
        (if (result f64) (i32.eq (local.get $inv) (i32.const 1))
          (then (f64.const 6.283185307179586))
          (else (f64.const -6.283185307179586)))
        (f64.convert_i32_s (local.get $len))))
      (local.set $wlr (call $cos (local.get $angle)))
      (local.set $wli (call $sin (local.get $angle)))
      (local.set $i (i32.const 0))
      (block $bd3 (loop $l3
        (br_if $bd3 (i32.ge_s (local.get $i) (local.get $n)))
        (local.set $wr (f64.const 1))
        (local.set $wi (f64.const 0))
        (local.set $k (i32.const 0))
        (block $bd4 (loop $l4
          (br_if $bd4 (i32.ge_s (local.get $k) (local.get $half)))
          (local.set $p (i32.add (local.get $i) (local.get $k)))
          (local.set $q (i32.add (local.get $p) (local.get $half)))
          (local.set $ur (call $ldr (local.get $base) (local.get $p)))
          (local.set $ui (call $ldi (local.get $base) (local.get $p)))
          (local.set $v0r (call $ldr (local.get $base) (local.get $q)))
          (local.set $v0i (call $ldi (local.get $base) (local.get $q)))
          (local.set $vr (f64.sub (f64.mul (local.get $v0r) (local.get $wr))
                                   (f64.mul (local.get $v0i) (local.get $wi))))
          (local.set $vi (f64.add (f64.mul (local.get $v0r) (local.get $wi))
                                   (f64.mul (local.get $v0i) (local.get $wr))))
          (call $str (local.get $base) (local.get $p) (f64.add (local.get $ur) (local.get $vr)))
          (call $sti (local.get $base) (local.get $p) (f64.add (local.get $ui) (local.get $vi)))
          (call $str (local.get $base) (local.get $q) (f64.sub (local.get $ur) (local.get $vr)))
          (call $sti (local.get $base) (local.get $q) (f64.sub (local.get $ui) (local.get $vi)))
          (local.set $tr (f64.sub (f64.mul (local.get $wr) (local.get $wlr))
                                   (f64.mul (local.get $wi) (local.get $wli))))
          (local.set $ti (f64.add (f64.mul (local.get $wr) (local.get $wli))
                                   (f64.mul (local.get $wi) (local.get $wlr))))
          (local.set $wr (local.get $tr))
          (local.set $wi (local.get $ti))
          (local.set $k (i32.add (local.get $k) (i32.const 1)))
          (br $l4)))
        (local.set $i (i32.add (local.get $i) (local.get $len)))
        (br $l3)))
      (local.set $len (i32.shl (local.get $len) (i32.const 1)))
      (br $l2))))

  (func (export "fft_conv") (param $n i32)
    (local $j i32) (local $ar f64) (local $ai f64) (local $br f64) (local $bi f64)
    ;; load A into CA and B into CB with zero imaginary parts
    (local.set $j (i32.const 0))
    (block $bd (loop $l
      (br_if $bd (i32.ge_s (local.get $j) (local.get $n)))
      (call $str (global.get $CA) (local.get $j) (call $ld (global.get $A) (local.get $j)))
      (call $sti (global.get $CA) (local.get $j) (f64.const 0))
      (call $str (global.get $CB) (local.get $j) (call $ld (global.get $B) (local.get $j)))
      (call $sti (global.get $CB) (local.get $j) (f64.const 0))
      (local.set $j (i32.add (local.get $j) (i32.const 1)))
      (br $l)))
    (call $fft (global.get $CA) (local.get $n) (i32.const 0))
    (call $fft (global.get $CB) (local.get $n) (i32.const 0))
    ;; pointwise complex product into CA
    (local.set $j (i32.const 0))
    (block $bd2 (loop $l2
      (br_if $bd2 (i32.ge_s (local.get $j) (local.get $n)))
      (local.set $ar (call $ldr (global.get $CA) (local.get $j)))
      (local.set $ai (call $ldi (global.get $CA) (local.get $j)))
      (local.set $br (call $ldr (global.get $CB) (local.get $j)))
      (local.set $bi (call $ldi (global.get $CB) (local.get $j)))
      (call $str (global.get $CA) (local.get $j)
        (f64.sub (f64.mul (local.get $ar) (local.get $br)) (f64.mul (local.get $ai) (local.get $bi))))
      (call $sti (global.get $CA) (local.get $j)
        (f64.add (f64.mul (local.get $ar) (local.get $bi)) (f64.mul (local.get $ai) (local.get $br))))
      (local.set $j (i32.add (local.get $j) (i32.const 1)))
      (br $l2)))
    (call $fft (global.get $CA) (local.get $n) (i32.const 1))
    ;; write real parts, scaled by 1/n, to OUT
    (local.set $j (i32.const 0))
    (block $bd3 (loop $l3
      (br_if $bd3 (i32.ge_s (local.get $j) (local.get $n)))
      (call $st (global.get $OUT) (local.get $j)
        (f64.div (call $ldr (global.get $CA) (local.get $j)) (f64.convert_i32_s (local.get $n))))
      (local.set $j (i32.add (local.get $j) (i32.const 1)))
      (br $l3))))
)
