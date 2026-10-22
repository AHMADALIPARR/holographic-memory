import Mathlib

open scoped BigOperators

namespace Hrr

variable {d : ℕ}

def superpose (v w : Fin d → ℝ) : Fin d → ℝ :=
  fun i => v i + w i

axiom superpose_assoc (a b c : Fin d → ℝ) :
  superpose a (superpose b c) = superpose (superpose a b) c

axiom superpose_dim (a b : Fin d → ℝ) :
  (superpose a b) 0 = a 0 + b 0

end Hrr
