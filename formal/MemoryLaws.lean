import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Data.Fin.Basic
import Mathlib.Basic.Real.Basic

open scoped BigOperators

namespace Hrr

variable {d : ℕ}

/-!
Superposition laws for holographic memory traces over
`Fin d → ℝ`, completed from the original sketch in this file.
The definition and the associativity example are the original
ones, verbatim; the remaining laws of the superposition algebra
(commutativity, zero, and the bridge to pointwise addition, which
is what the distributivity laws of Convolution.lean consume) are
proved alongside. The original `import Mathlib` is narrowed to
the modules actually used.
-/

def superpose (v w : Fin d → ℝ) : Fin d → ℝ :=
  fun i => v i + w i

-- The example of the original file, verbatim.

example (a b c : Fin d → ℝ) :
    superpose a (superpose b c) = superpose (superpose a b) c := by
  funext i
  simp [superpose, add_assoc]

theorem superpose_comm (a b : Fin d → ℝ) :
    superpose a b = superpose b a := by
  funext i
  simp [superpose, add_comm]

theorem superpose_zero_right (a : Fin d → ℝ) :
    superpose a 0 = a := by
  funext i
  simp [superpose]

theorem superpose_zero_left (a : Fin d → ℝ) :
    superpose 0 a = a := by
  funext i
  simp [superpose]

theorem superpose_eq_add (a b : Fin d → ℝ) :
    superpose a b = a + b := by
  funext i
  rfl

theorem superpose_assoc (a b c : Fin d → ℝ) :
    superpose a (superpose b c) = superpose (superpose a b) c := by
  funext i
  simp [superpose, add_assoc]

end Hrr
