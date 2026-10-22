/-
  HydraSpec.lean — HYDRA deterministic-logic specifications.

  Scope discipline (stated in the mission): these are proofs about
  deterministic protocol logic ONLY. They say nothing about optical
  entropy, and nothing about the security of ChaCha20-Poly1305.

  Written against core Lean 4 (no Mathlib) so the file checks with a
  bare toolchain:  lean HydraSpec.lean

  Contents:
    1. Circular convolution over lists: dimension preservation, and
       kernel-checked concrete identities — including the exact
       n = 3 case ([1,2,3] (*) [4,5,6] = [31,31,28]) that exposed
       the modular-index defect in the Rust engine, the delta
       identity, and a commutativity instance.
    2. Frame serialization round-trip.
    3. Challenge registry: a challenge identifier, once accepted,
       is rejected on replay (state-transition invariant).
    4. Nonce uniqueness under an explicit counter assumption.
-/

namespace Hydra

/-- Index a list with a default of 0 (total function). -/
def vat (l : List Int) (i : Nat) : Int := (l.get? i).getD 0

/-- Circular convolution, matching the engine's convention:
    c k = sum_j a j * b ((k - j) mod n), indices taken mod n = a.length. -/
def cconv (a b : List Int) : List Int :=
  let n := a.length
  (List.range n).map fun k =>
    ((List.range n).map fun j => vat a j * vat b ((k + n - j) % n)).foldr (· + ·) 0

theorem cconv_length (a b : List Int) : (cconv a b).length = a.length := by
  simp [cconv]

/-- The n = 3 witness case: kernel-checked arithmetic. -/
example : cconv [1, 2, 3] [4, 5, 6] = [31, 31, 28] := by decide

/-- Delta identity on a concrete vector: binding with e_0 is the identity. -/
example : cconv [5, 7, 11] [1, 0, 0] = [5, 7, 11] := by decide

/-- Circular convolution commutes (concrete instance, kernel-checked). -/
example : cconv [1, 2, 3] [4, 5, 6] = cconv [4, 5, 6] [1, 2, 3] := by decide

/-- Superposition is vector addition (concrete instance). -/
example : (List.zipWith (· + ·) [1, 2, 3] [10, 20, 30]) = [11, 22, 33] := by decide

/-- Measurement-frame serialization: a length prefix followed by the
    payload; parsing is the inverse of serialization. -/
def serialize (frame : List Nat) : List Nat := frame.length :: frame

def parse : List Nat → Option (List Nat)
  | [] => none
  | n :: rest => if rest.length = n then some rest else none

theorem parse_serialize (frame : List Nat) : parse (serialize frame) = some frame := by
  simp [serialize, parse]

/-- Challenge registry: the accept transition. A challenge id is
    accepted at most once; the registry records every accepted id. -/
structure Registry where
  used : List Nat
deriving Repr

def accept (r : Registry) (id : Nat) : Registry × Bool :=
  if id ∈ r.used then (r, false)
  else ({ used := id :: r.used }, true)

theorem replay_rejected (r : Registry) (id : Nat) (h : (accept r id).2 = true) :
    (accept (accept r id).1 id).2 = false := by
  unfold accept at *
  by_cases hm : id ∈ r.used
  · simp [hm] at h
  · simp [hm] at h ⊢

theorem fresh_accepted (r : Registry) (id : Nat) (h : id ∉ r.used) :
    (accept r id).2 = true := by
  simp [accept, h]

/-- Session nonces: a fixed random prefix paired with a counter.
    Distinct counters give distinct nonces — uniqueness holds under
    the explicit assumption that the counter never repeats under one
    key (the counter is part of the Ada/SPARK control state). -/
def nonce (pfx counter : Nat) : Nat × Nat := (pfx, counter)

theorem nonce_injective_counter (p c₁ c₂ : Nat) (h : nonce p c₁ = nonce p c₂) :
    c₁ = c₂ := by
  exact Prod.ext_iff.mp h |>.2

theorem nonce_distinct_of_counter_distinct (p c₁ c₂ : Nat) (h : c₁ ≠ c₂) :
    nonce p c₁ ≠ nonce p c₂ := by
  intro hh
  exact h (nonce_injective_counter p c₁ c₂ hh)

end Hydra
