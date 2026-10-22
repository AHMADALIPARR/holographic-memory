--  hydra_control.adb — see hydra_control.ads for the contract story.

package body Hydra_Control is

   function State (R : Registry) return Session_State is (R.St);

   function Counter (R : Registry) return Natural is (R.Ctr);

   function Seen (R : Registry; Id : Challenge_Id) return Boolean is
   begin
      for I in 1 .. R.Count loop
         if R.Ids (I) = Id then
            return True;
         end if;
      end loop;
      return False;
   end Seen;

   procedure Init (R : out Registry) is
   begin
      R := (St    => Ready,
            Ids   => (others => (others => 0)),
            Count => 0,
            Ctr   => 0);
   end Init;

   procedure Accept_Challenge
     (R        : in out Registry;
      Id       : in     Challenge_Id;
      Accepted :    out Boolean)
   is
   begin
      if Seen (R, Id) or else R.Count >= Max_Challenges then
         Accepted := False;
         return;
      end if;
      R.Count := R.Count + 1;
      R.Ids (R.Count) := Id;
      Accepted := True;
   end Accept_Challenge;

   procedure Next_Nonce
     (R      : in out Registry;
      Value  :    out Natural;
      Issued :    out Boolean)
   is
   begin
      if R.Ctr >= Nonce_Max then
         R.St := Rekey_Required;
         Value := 0;
         Issued := False;
         return;
      end if;
      R.Ctr := R.Ctr + 1;
      Value := R.Ctr;
      Issued := True;
   end Next_Nonce;

   procedure Set_Counter_For_Test (R : in out Registry; V : Natural) is
   begin
      R.Ctr := V;
   end Set_Counter_For_Test;

end Hydra_Control;
