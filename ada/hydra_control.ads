--  hydra_control.ads — HYDRA bounded device-control logic (Ada/SPARK).
--
--  Owns the two pieces of mutable state whose invariants the whole
--  protocol depends on:
--
--    * the nonce counter — strictly increasing under one session
--      key, never wrapping; exhaustion forces a rekey instead of
--      reuse (a wrapped ChaCha20-Poly1305 nonce under a fixed key
--      is catastrophic, so the control layer makes it unreachable);
--    * the challenge registry — a bounded set of accepted challenge
--      identifiers; a replayed identifier is rejected by
--      construction of the Accept transition.
--
--  The contracts are written for SPARK (they elaborate as assertions
--  under plain GNAT with -gnata). Formal verification of these
--  state transitions covers deterministic logic only — it is not a
--  proof about optical entropy or primitive security.

package Hydra_Control is

   Max_Challenges : constant := 128;
   Nonce_Max      : constant := 2_147_483_647;  -- 2^31 - 1

   type Session_State is
     (Idle,          -- no session key
      Ready,         -- key derived, counter armed
      Rekey_Required -- counter exhausted; no further sealing allowed
     );

   type Challenge_Id is array (1 .. 16) of Natural range 0 .. 255;

   type Registry is private;

   function State (R : Registry) return Session_State;
   function Counter (R : Registry) return Natural;
   function Seen (R : Registry; Id : Challenge_Id) return Boolean;

   --  Reset all state and arm the counter. Post: Ready, empty
   --  registry, counter zero.
   procedure Init (R : out Registry)
   with Post => State (R) = Ready and Counter (R) = 0;

   --  Accept a challenge identifier. Accepted is True exactly when
   --  the identifier was not already recorded; on acceptance it is
   --  recorded, so a second Accept of the same identifier returns
   --  Accepted = False (replay rejection by construction). A
   --  rejected accept leaves the registry unchanged.
   procedure Accept_Challenge
     (R        : in out Registry;
      Id       : in     Challenge_Id;
      Accepted :    out Boolean)
   with Pre  => State (R) = Ready,
        Post => Accepted = not Seen (R'Old, Id)
                and (if not Accepted then R = R'Old);

   --  Issue the next nonce counter value. When the counter would
   --  exceed Nonce_Max the registry transitions to Rekey_Required
   --  and Issued is False: the counter never wraps and no nonce is
   --  ever repeated under one key.
   procedure Next_Nonce
     (R      : in out Registry;
      Value  :    out Natural;
      Issued :    out Boolean)
   with Pre  => State (R) = Ready,
        Post => (if Issued then Value = Counter (R'Old) + 1
                          and Counter (R) = Value
                 else State (R) = Rekey_Required);

   --  Test support: position the counter (used by the demo to reach
   --  the exhaustion transition without 2^31 iterations).
   procedure Set_Counter_For_Test (R : in out Registry; V : Natural)
   with Pre => V <= Nonce_Max and State (R) = Ready;

private

   type Id_Array is array (1 .. Max_Challenges) of Challenge_Id;

   type Registry is record
      St    : Session_State := Idle;
      Ids   : Id_Array := (others => (others => 0));
      Count : Natural := 0;
      Ctr   : Natural := 0;
   end record;

end Hydra_Control;
