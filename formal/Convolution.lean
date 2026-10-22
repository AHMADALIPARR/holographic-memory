import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Sigma
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Data.Fin.Basic
import Mathlib.Basic.Real.Basic

open scoped BigOperators

namespace Hrr

variable {d : ℕ}

/-!
Full formalization of circular convolution and correlation for
holographic reduced representations over `Fin d → ℝ`.

ASSISTANT REPAIR (2026-10-22, labeled): the definitions below were
completed from the original sketch in this file. The original index
expressions `((k.1 - j.1) % d)` and `((j.1 + k.1) % d)` used
truncated natural subtraction and an involuted correlation index;
at `k < j` the convolution index collapsed to 0 instead of wrapping
(the same defect class as the Rust engine's usize underflow, found
and fixed there the same day), and the correlation recovered the
index-reversed operand. The definitions now use `Fin` subtraction,
which is modular: `b (k - j)` and `b (j - k)`, matching the
repository's Rust, Fortran and WAT implementations. The two
distributivity examples from the original file are kept verbatim;
they hold for either index convention. The original `import
Mathlib` is narrowed to the modules actually used, so the file
checks in seconds rather than not at all. The modular index
lemmas are proved from `Fin.val_sub` by case analysis on the
wrap, with `omega` closing the resulting mod-free arithmetic.
-/

def circConv (a b : Fin d → ℝ) : Fin d → ℝ :=
  fun k => ∑ j : Fin d, a j * b (k - j)

def circCorr (a b : Fin d → ℝ) : Fin d → ℝ :=
  fun k => ∑ j : Fin d, a j * b (j - k)

def delta [NeZero d] (i : Fin d) : ℝ := if i = 0 then 1 else 0

-- Modular index identities on `Fin d`. `Fin.sub_val_of_le` covers
-- the non-wrapping case; the wrapping case follows from
-- `Fin.val_sub` and `Nat.mod_eq_of_lt`. Every identity the HRR
-- algebra needs is derived from those two.

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

theorem sub_sub_self_fin (k j : Fin d) : k - (k - j) = j := by
  apply Fin.ext
  by_cases h : j.val ≤ k.val
  · have e1 : (k - j).val = k.val - j.val := val_sub_wrap h
    have e2 : (k - (k - j)).val = k.val - (k - j).val :=
      val_sub_wrap (by rw [e1]; omega)
    rw [e2, e1]
    omega
  · have h' : k.val < j.val := by omega
    have e1 : (k - j).val = k.val + d - j.val := val_sub_wrap2 h'
    rw [Fin.val_sub, e1]
    have hlt : (d - (k.val + d - j.val)) + k.val = j.val := by
      have hj := j.isLt
      have hk := k.isLt
      omega
    rw [hlt]
    exact Nat.mod_eq_of_lt j.isLt

theorem sub_zero_fin [NeZero d] (k : Fin d) : k - 0 = k := by
  apply Fin.ext
  have e1 : (k - 0).val = k.val - 0 := val_sub_wrap (by simp)
  rw [e1]
  simp

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

theorem add_sub_cancel_fin (j l : Fin d) : (j + l) - j = l := by
  apply Fin.ext
  by_cases hA : j.val + l.val < d
  · have e_add : (j + l).val = j.val + l.val := by
      rw [Fin.val_add]
      exact Nat.mod_eq_of_lt hA
    have e1 : ((j + l) - j).val = (j + l).val - j.val :=
      val_sub_wrap (by rw [e_add]; omega)
    rw [e1, e_add]
    omega
  · have e_add : (j + l).val = j.val + l.val - d := by
      rw [Fin.val_add, Nat.mod_eq_sub_mod (by omega : d ≤ j.val + l.val)]
      exact Nat.mod_eq_of_lt (by
        have hj := j.isLt
        have hl := l.isLt
        omega)
    have e1 : ((j + l) - j).val = (j + l).val + d - j.val :=
      val_sub_wrap2 (by
        rw [e_add]
        have hj := j.isLt
        have hl := l.isLt
        omega)
    rw [e1, e_add]
    have hj := j.isLt
    have hl := l.isLt
    omega

theorem add_sub_self_fin (j m : Fin d) : j + (m - j) = m := by
  apply Fin.ext
  by_cases hB : m.val < j.val
  · have e1 : (m - j).val = m.val + d - j.val := val_sub_wrap2 hB
    rw [Fin.val_add, e1]
    have e : j.val + (m.val + d - j.val) = m.val + d := by
      have hj := j.isLt
      omega
    rw [e, Nat.add_mod_right]
    exact Nat.mod_eq_of_lt m.isLt
  · have h' : j.val ≤ m.val := by omega
    have e1 : (m - j).val = m.val - j.val := val_sub_wrap h'
    rw [Fin.val_add, e1]
    have e : j.val + (m.val - j.val) = m.val := by omega
    rw [e]
    exact Nat.mod_eq_of_lt m.isLt

theorem sub_add_fin (x y z : Fin d) : x - (y + z) = (x - y) - z := by
  apply Fin.ext
  have e_yz : (y + z).val = if y.val + z.val < d then y.val + z.val
      else y.val + z.val - d := by
    by_cases hA : y.val + z.val < d
    · rw [if_pos hA, Fin.val_add]
      exact Nat.mod_eq_of_lt hA
    · rw [if_neg hA, Fin.val_add,
        Nat.mod_eq_sub_mod (by omega : d ≤ y.val + z.val)]
      exact Nat.mod_eq_of_lt (by
        have hy := y.isLt
        have hz := z.isLt
        omega)
  have eL : (x - (y + z)).val
      = if (y + z).val ≤ x.val then x.val - (y + z).val
        else x.val + d - (y + z).val := by
    by_cases h1 : (y + z).val ≤ x.val
    · rw [if_pos h1]
      exact val_sub_wrap h1
    · rw [if_neg h1]
      exact val_sub_wrap2 (by omega)
  have e_xy : (x - y).val
      = if y.val ≤ x.val then x.val - y.val else x.val + d - y.val := by
    by_cases h2 : y.val ≤ x.val
    · rw [if_pos h2]
      exact val_sub_wrap h2
    · rw [if_neg h2]
      exact val_sub_wrap2 (by omega)
  have eR : ((x - y) - z).val
      = if z.val ≤ (x - y).val then (x - y).val - z.val
        else (x - y).val + d - z.val := by
    by_cases h3 : z.val ≤ (x - y).val
    · rw [if_pos h3]
      exact val_sub_wrap h3
    · rw [if_neg h3]
      exact val_sub_wrap2 (by omega)
  rw [eL, eR]
  have hx := x.isLt
  have hy := y.isLt
  have hz := z.isLt
  by_cases hA : y.val + z.val < d
  · rw [if_pos hA] at e_yz
    by_cases h1 : (y + z).val ≤ x.val
    · rw [if_pos h1]
      by_cases h2 : y.val ≤ x.val
      · rw [if_pos h2] at e_xy
        by_cases h3 : z.val ≤ (x - y).val
        · rw [if_pos h3]
          omega
        · rw [if_neg h3]
          omega
      · rw [if_neg h2] at e_xy
        by_cases h3 : z.val ≤ (x - y).val
        · rw [if_pos h3]
          omega
        · rw [if_neg h3]
          omega
    · rw [if_neg h1]
      by_cases h2 : y.val ≤ x.val
      · rw [if_pos h2] at e_xy
        by_cases h3 : z.val ≤ (x - y).val
        · rw [if_pos h3]
          omega
        · rw [if_neg h3]
          omega
      · rw [if_neg h2] at e_xy
        by_cases h3 : z.val ≤ (x - y).val
        · rw [if_pos h3]
          omega
        · rw [if_neg h3]
          omega
  · rw [if_neg hA] at e_yz
    by_cases h1 : (y + z).val ≤ x.val
    · rw [if_pos h1]
      by_cases h2 : y.val ≤ x.val
      · rw [if_pos h2] at e_xy
        by_cases h3 : z.val ≤ (x - y).val
        · rw [if_pos h3]
          omega
        · rw [if_neg h3]
          omega
      · rw [if_neg h2] at e_xy
        by_cases h3 : z.val ≤ (x - y).val
        · rw [if_pos h3]
          omega
        · rw [if_neg h3]
          omega
    · rw [if_neg h1]
      by_cases h2 : y.val ≤ x.val
      · rw [if_pos h2] at e_xy
        by_cases h3 : z.val ≤ (x - y).val
        · rw [if_pos h3]
          omega
        · rw [if_neg h3]
          omega
      · rw [if_neg h2] at e_xy
        by_cases h3 : z.val ≤ (x - y).val
        · rw [if_pos h3]
          omega
        · rw [if_neg h3]
          omega

-- The two examples of the original file, verbatim.

example (a b c : Fin d → ℝ) :
    circConv a (b + c) = circConv a b + circConv a c := by
  funext k
  simp [circConv, Finset.sum_add_distrib, add_mul, mul_add]

example (a b c : Fin d → ℝ) :
    circCorr a (b + c) = circCorr a b + circCorr a c := by
  funext k
  simp [circCorr, Finset.sum_add_distrib, add_mul, mul_add]

-- Left distributivity, zero and scalar laws.

theorem circConv_add_left (a b c : Fin d → ℝ) :
    circConv (a + b) c = circConv a c + circConv b c := by
  funext k
  simp [circConv, Finset.sum_add_distrib, add_mul, mul_add]

theorem circCorr_add_left (a b c : Fin d → ℝ) :
    circCorr (a + b) c = circCorr a c + circCorr b c := by
  funext k
  simp [circCorr, Finset.sum_add_distrib, add_mul, mul_add]

theorem circConv_zero_left (b : Fin d → ℝ) : circConv 0 b = 0 := by
  funext k
  simp [circConv]

theorem circConv_zero_right (a : Fin d → ℝ) : circConv a 0 = 0 := by
  funext k
  simp [circConv]

theorem circCorr_zero_left (b : Fin d → ℝ) : circCorr 0 b = 0 := by
  funext k
  simp [circCorr]

theorem circConv_smul (r : ℝ) (a b : Fin d → ℝ) :
    circConv (r • a) b = r • circConv a b := by
  funext k
  simp [circConv, Finset.mul_sum, mul_assoc]

-- Delta (identity element) laws. `NeZero d` excludes the empty
-- index type, where `Fin d → ℝ` carries no distinguished basis
-- vector to state them with.

theorem circConv_delta_left [NeZero d] (a : Fin d → ℝ) :
    circConv delta a = a := by
  funext k
  show (∑ j : Fin d, delta j * a (k - j)) = a k
  rw [Finset.sum_eq_single 0]
  · simp [delta, sub_zero_fin]
  · intro j _ hj
    simp [delta, hj]
  · simp

theorem circConv_delta_right [NeZero d] (a : Fin d → ℝ) :
    circConv a delta = a := by
  funext k
  show (∑ j : Fin d, a j * delta (k - j)) = a k
  rw [Finset.sum_eq_single k]
  · simp [delta, sub_self_fin]
  · intro j _ hj
    have h : k - j ≠ 0 := by
      intro hzero
      have hkj : k = j := sub_eq_zero_fin.mp hzero
      exact hj hkj.symm
    simp [delta, h]
  · simp

theorem circCorr_delta [NeZero d] (a : Fin d → ℝ) :
    circCorr a delta = a := by
  funext k
  show (∑ j : Fin d, a j * delta (j - k)) = a k
  rw [Finset.sum_eq_single k]
  · simp [delta, sub_self_fin]
  · intro j _ hj
    have h : j - k ≠ 0 := fun hzero => hj (sub_eq_zero_fin.mp hzero)
    simp [delta, h]
  · simp

-- Commutativity, by reindexing with the involution `j ↦ k - j`.

theorem circConv_comm (a b : Fin d → ℝ) :
    circConv a b = circConv b a := by
  funext k
  show (∑ j : Fin d, a j * b (k - j)) = ∑ j : Fin d, b j * a (k - j)
  let e : Fin d ≃ Fin d :=
    ⟨fun j => k - j, fun j => k - j,
     fun j => sub_sub_self_fin k j, fun j => sub_sub_self_fin k j⟩
  rw [← Equiv.sum_comp e (fun j => b j * a (k - j))]
  apply Finset.sum_congr rfl
  intro j _
  show a j * b (k - j) = b (k - j) * a (k - (k - j))
  rw [sub_sub_self_fin]
  exact mul_comm _ _

-- Associativity. Both sides reduce to the triple sum over
-- `a j * b l * c ((k - j) - l)`; the middle index is reindexed by
-- the translation `l ↦ j + l`.

theorem circConv_assoc (a b c : Fin d → ℝ) :
    circConv (circConv a b) c = circConv a (circConv b c) := by
  funext k
  show (∑ m : Fin d, (∑ j : Fin d, a j * b (m - j)) * c (k - m))
      = ∑ j : Fin d, a j * (∑ l : Fin d, b l * c ((k - j) - l))
  simp only [Finset.sum_mul, Finset.mul_sum]
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl
  intro j _
  let e : Fin d ≃ Fin d :=
    ⟨fun l => j + l, fun m => m - j,
     fun l => add_sub_cancel_fin j l, fun m => add_sub_self_fin j m⟩
  rw [← Equiv.sum_comp e (fun m => a j * b (m - j) * c (k - m))]
  apply Finset.sum_congr rfl
  intro l _
  show a j * b (j + l - j) * c (k - (j + l))
      = a j * (b l * c ((k - j) - l))
  rw [add_sub_cancel_fin, sub_add_fin, mul_assoc]

end Hrr
