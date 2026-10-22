import Mathlib

open scoped BigOperators

namespace Hrr

variable {d : ℕ}

def circConv (a b : Fin d → ℝ) : Fin d → ℝ :=
  fun k => ∑ j : Fin d, a j * b ((k.1 - j.1) % d)

def circCorr (a b : Fin d → ℝ) : Fin d → ℝ :=
  fun k => ∑ j : Fin d, a j * b ((j.1 + k.1) % d)

axiom circConv_assoc (a b c : Fin d → ℝ) :
  circConv (circConv a b) c = circConv a (circConv b c)

axiom circConv_distrib (a b c : Fin d → ℝ) :
  circConv a (b + c) = circConv a b + circConv a c

axiom circConv_identity (a : Fin d → ℝ) :
  circConv a (fun i => if i = 0 then 1 else 0) = a

end Hrr
