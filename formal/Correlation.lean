import Mathlib

open scoped BigOperators

namespace Hrr

variable {d : ℕ}

def circCorrIndex (a b : Fin d → ℝ) : Fin d → ℝ :=
  fun k => ∑ j : Fin d, a j * b ((j.1 + k.1) % d)

example (a : Fin d → ℝ) :
    circCorrIndex a (fun i => if i = 0 then (1 : ℝ) else 0) = a := by
  funext k
  simp [circCorrIndex]

end Hrr
