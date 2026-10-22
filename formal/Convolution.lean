import Mathlib

open scoped BigOperators

namespace Hrr

variable {d : ℕ}

def circConv (a b : Fin d → ℝ) : Fin d → ℝ :=
  fun k => ∑ j : Fin d, a j * b ((k.1 - j.1) % d)

def circCorr (a b : Fin d → ℝ) : Fin d → ℝ :=
  fun k => ∑ j : Fin d, a j * b ((j.1 + k.1) % d)

example (a b c : Fin d → ℝ) :
    circConv a (b + c) = circConv a b + circConv a c := by
  funext k
  simp [circConv, Finset.sum_add_distrib, add_mul, mul_add]

example (a b c : Fin d → ℝ) :
    circCorr a (b + c) = circCorr a b + circCorr a c := by
  funext k
  simp [circCorr, Finset.sum_add_distrib, add_mul, mul_add]

end Hrr
