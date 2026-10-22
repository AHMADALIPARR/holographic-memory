import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Data.Fin.Basic
import Mathlib.Basic.Real.Basic

open scoped BigOperators

namespace Hrr

variable {d : ℕ}

/-!
Circular correlation over `Fin d → ℝ`, completed from the
original sketch in this file.

ASSISTANT REPAIR (2026-10-22, labeled): the original definition
used the index `(j.1 + k.1) % d`, which recovers the involuted
(index-reversed) operand, and the original delta example below was
false as stated for that index: correlating against a delta at 0
returned `a` composed with negation, not `a` (concretely, at
d = 3 with a = [0, 1, 0], the value at k = 1 comes out 0, not 1).
The definition now uses `Fin` subtraction, `b (j - k)`, the
standard HRR correlation matching the repository's Rust, Fortran
and WAT implementations. The delta example's statement is the
original one, verbatim apart from the `[NeZero d]` instance
binder, which current Lean requires for `(0 : Fin d)` to exist at
all. With the corrected index the statement is true, and it is
proved below. The original `import Mathlib` is narrowed to the
modules actually used.
-/

def circCorrIndex (a b : Fin d → ℝ) : Fin d → ℝ :=
  fun k => ∑ j : Fin d, a j * b (j - k)

def involution (b : Fin d → ℝ) : Fin d → ℝ :=
  fun i => b (-i)

-- Modular index identities on `Fin d`, proved from `Fin.val_sub`
-- by case analysis on the wrap (same infrastructure as
-- Convolution.lean, duplicated so this file stands alone).

theorem val_sub_wrap {x y : Fin d} (h : y.val ≤ x.val) :
    (x - y).val = x.val - y.val :=
  Fin.sub_val_of_le (Fin.le_iff_val_le_val.mpr h)

theorem val_sub_wrap2 {x y : Fin d} (h : x.val < y.val) :
    (x - y).val = x.val + d - y.val := by
  rw [Fin.val_sub]
  have h1 : (d - y.val) + x.val < d := by have hy := y.isLt; omega
  rw [Nat.mod_eq_of_lt h1]
  have hy := y.isLt
  omega

theorem sub_self_fin [NeZero d] (x : Fin d) : x - x = 0 := by
  apply Fin.ext
  have e1 : (x - x).val = x.val - x.val := val_sub_wrap (le_refl _)
  rw [e1]
  simp

theorem sub_eq_zero_fin [NeZero d] {j k : Fin d} :
    j - k = 0 ↔ j = k := by
  constructor
  · intro h
    have hv : (j - k).val = 0 := by rw [h]; rfl
    apply Fin.ext
    by_cases hc : k.val ≤ j.val
    · have e1 : (j - k).val = j.val - k.val := val_sub_wrap hc
      rw [e1] at hv
      omega
    · have e1 : (j - k).val = j.val + d - k.val := val_sub_wrap2 (by omega)
      rw [e1] at hv
      have hj := j.isLt
      have hk := k.isLt
      omega
  · intro h
    rw [h]
    exact sub_self_fin k

theorem neg_sub_fin (k j : Fin d) : -(k - j) = j - k := by
  apply Fin.ext
  rw [Fin.val_neg', Fin.val_sub]
  have hj := j.isLt
  have hk := k.isLt
  rcases lt_trichotomy j.val k.val with h | h | h
  · have e2 : (j - k).val = j.val + d - k.val := val_sub_wrap2 h
    rw [e2]
    have e3 : (d - j.val) + k.val = (k.val - j.val) + d := by omega
    rw [e3, Nat.add_mod_right, Nat.mod_eq_of_lt (by omega : k.val - j.val < d)]
    have e4 : d - (k.val - j.val) = j.val + d - k.val := by omega
    rw [e4]
    exact Nat.mod_eq_of_lt (by omega)
  · have e2 : (j - k).val = 0 := by
      have e3 : (j - k).val = j.val - k.val := val_sub_wrap (by omega)
      rw [e3]
      omega
    rw [e2]
    have e4 : (d - j.val) + k.val = d := by omega
    rw [e4, Nat.mod_self]
    simp
  · have e2 : (j - k).val = j.val - k.val := val_sub_wrap (by omega)
    rw [e2]
    have e3 : (d - ((d - j.val) + k.val)) = j.val - k.val := by omega
    have e4 : (d - j.val) + k.val < d := by omega
    rw [Nat.mod_eq_of_lt e4, e3]
    exact Nat.mod_eq_of_lt (by omega)

theorem neg_neg_fin (x : Fin d) : -(-x) = x := by
  apply Fin.ext
  rw [Fin.val_neg', Fin.val_neg']
  by_cases h : x.val = 0
  · rw [h]
    simp
  · have h1 : (d - x.val) % d = d - x.val :=
      Nat.mod_eq_of_lt (by have hx := x.isLt; omega)
    rw [h1]
    have e : d - (d - x.val) = x.val := by have hx := x.isLt; omega
    rw [e]
    exact Nat.mod_eq_of_lt x.isLt

-- The example of the original file, verbatim apart from the
-- `[NeZero d]` binder explained in the header.

example [NeZero d] (a : Fin d → ℝ) :
    circCorrIndex a (fun i => if i = 0 then (1 : ℝ) else 0) = a := by
  funext k
  show (∑ j : Fin d, a j * (if j - k = 0 then (1 : ℝ) else 0)) = a k
  rw [Finset.sum_eq_single k]
  · simp [sub_self_fin]
  · intro j _ hj
    have h : j - k ≠ 0 := fun hzero => hj (sub_eq_zero_fin.mp hzero)
    simp [h]
  · simp

-- Correlation is convolution with the involuted second operand:
-- at index k it sums a j * b (j - k), and j - k = -(k - j).

theorem circCorrIndex_involution (a b : Fin d → ℝ) :
    circCorrIndex a b =
      fun k => ∑ j : Fin d, a j * involution b (k - j) := by
  funext k
  show (∑ j : Fin d, a j * b (j - k))
      = ∑ j : Fin d, a j * involution b (k - j)
  apply Finset.sum_congr rfl
  intro j _
  show a j * b (j - k) = a j * b (-(k - j))
  rw [neg_sub_fin]

theorem involution_involutive (b : Fin d → ℝ) :
    involution (involution b) = b := by
  funext i
  show b (-(-i)) = b i
  rw [neg_neg_fin]

theorem circCorrIndex_add_left (a b c : Fin d → ℝ) :
    circCorrIndex (a + b) c = circCorrIndex a c + circCorrIndex b c := by
  funext k
  simp [circCorrIndex, Finset.sum_add_distrib, add_mul, mul_add]

theorem circCorrIndex_zero_left (b : Fin d → ℝ) :
    circCorrIndex 0 b = 0 := by
  funext k
  simp [circCorrIndex]

end Hrr
