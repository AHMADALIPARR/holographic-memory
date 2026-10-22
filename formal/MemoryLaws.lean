import Mathlib

open scoped BigOperators

namespace Hrr

variable {d : ℕ}

def superpose (v w : Fin d → ℝ) : Fin d → ℝ :=
  fun i => v i + w i

example (a b c : Fin d → ℝ) :
    superpose a (superpose b c) = superpose (superpose a b) c := by
  funext i
  simp [superpose, add_assoc]

end Hrr
