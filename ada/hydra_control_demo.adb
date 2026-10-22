--  hydra_control_demo.adb — exercises the control invariants:
--  fresh challenge accepted, replay rejected, nonces strictly
--  increasing, exhaustion transitions to Rekey_Required instead of
--  wrapping the counter.

with Ada.Text_IO; use Ada.Text_IO;
with Hydra_Control; use Hydra_Control;

procedure Hydra_Control_Demo is
   R     : Registry;
   Id_A  : constant Challenge_Id := (1, 2, 3, 4, 5, 6, 7, 8,
                                     9, 10, 11, 12, 13, 14, 15, 16);
   Id_B  : constant Challenge_Id := (16, 15, 14, 13, 12, 11, 10, 9,
                                     8, 7, 6, 5, 4, 3, 2, 1);
   Ok    : Boolean;
   V     : Natural;
begin
   Init (R);
   Accept_Challenge (R, Id_A, Ok);
   Put_Line ("fresh challenge accepted:   " & Boolean'Image (Ok));
   Accept_Challenge (R, Id_A, Ok);
   Put_Line ("replayed challenge rejected:" & Boolean'Image (not Ok));
   Accept_Challenge (R, Id_B, Ok);
   Put_Line ("second challenge accepted:  " & Boolean'Image (Ok));

   Next_Nonce (R, V, Ok);
   Put_Line ("nonce 1 issued:" & Boolean'Image (Ok) & " value" & Natural'Image (V));
   Next_Nonce (R, V, Ok);
   Put_Line ("nonce 2 issued:" & Boolean'Image (Ok) & " value" & Natural'Image (V));

   Set_Counter_For_Test (R, Nonce_Max);
   Next_Nonce (R, V, Ok);
   Put_Line ("exhaustion: issued" & Boolean'Image (Ok)
             & ", state " & Session_State'Image (State (R)));
end Hydra_Control_Demo;
