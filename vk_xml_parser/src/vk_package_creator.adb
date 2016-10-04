with Vk_XML;
with Aida.Text_IO;
with Aida.UTF8;
with Ada.Text_IO;
with Std_String;
with Aida.Strings;
with Aida.UTF8_Code_Point;
with Aida.Containers;
with GNAT.Source_Info;
with Ada.Containers.Formal_Hashed_Maps;
with Ada.Strings.Fixed.Hash;
with Ada.Containers.Generic_Constrained_Array_Sort;
with Ada.Containers.Formal_Vectors;
with Ada.Strings.Fixed;

package body Vk_Package_Creator with SPARK_Mode is

   use all type Aida.UTF8_Code_Point.T;
   use all type Aida.Containers.Count_Type;
   use all type Aida.Strings.Unbounded_String_Type;

   use all type Vk_XML.XML_Text.T;
   use all type Vk_XML.Registry_Shared_Ptr.T;
   use all type Vk_XML.Registry.Fs.Child_Vectors.Immutable_T;
   use all type Vk_XML.Registry.Fs.Child_Kind_Id_T;
   use all type Vk_XML.XML_Out_Commented_Message_Shared_Ptr.T;
   use all type Vk_XML.Types_Shared_Ptr.T;
   use all type Vk_XML.Types.Fs.Child_Vectors.Immutable_T;
   use all type Vk_XML.Types.Fs.Child_Kind_Id_T;
   use all type Vk_XML.Nested_Type.Fs.Value.T;
   use all type Vk_XML.Nested_Type_Shared_Ptr.T;
   use all type Vk_XML.Type_T.Fs.Category.T;
   use all type Vk_XML.Type_T.Fs.Requires.T;
   use all type Vk_XML.Type_T.Fs.Child_Vectors.Immutable_T;
   use all type Vk_XML.Type_T.Fs.Child_Kind_Id_T;
   use all type Vk_XML.Type_T.Fs.Name.T;
   use all type Vk_XML.Type_Shared_Ptr.T;
   use all type Vk_XML.Name.Fs.Value.T;
   use all type Vk_XML.Name_Shared_Ptr.T;
   use all type Vk_XML.Enums.Fs.Child_Vectors.Immutable_T;
   use all type Vk_XML.Enums.Fs.Name.T;
   use all type Vk_XML.Enums.Fs.Child_Kind_Id_T;
   use all type Vk_XML.Enums.Fs.Type_Attribue_T;
   use all type Vk_XML.Enums_Enum.Fs.Comment.T;
   use all type Vk_XML.Enums_Shared_Ptr.T;
   use all type Vk_XML.Enums_Enum_Shared_Ptr.T;
   use all type Vk_XML.Enums_Enum.Fs.Value.T;
   use all type Vk_XML.Enums_Enum.Fs.Name.T;

   T_End  : constant String := "_T";
   AT_End : constant String := "_Ptr";

   File : Ada.Text_IO.File_Type;

   function Hash_Of_Unbounded_String (Key : Aida.Strings.Unbounded_String_Type) return Ada.Containers.Hash_Type is
   begin
      return Ada.Strings.Fixed.Hash (Aida.Strings.To_String (Key));
   end Hash_Of_Unbounded_String;

   package C_Type_Name_To_Ada_Name_Map_Owner is new Ada.Containers.Formal_Hashed_Maps (Key_Type        => Aida.Strings.Unbounded_String_Type,
                                                                                       Element_Type    => Aida.Strings.Unbounded_String_Type,
                                                                                       Hash            => Hash_Of_Unbounded_String,
                                                                                       Equivalent_Keys => Aida.Strings."=",
                                                                                       "="             => Aida.Strings."=");

   use type C_Type_Name_To_Ada_Name_Map_Owner.Cursor;

   C_Type_Name_To_Ada_Name_Map : C_Type_Name_To_Ada_Name_Map_Owner.Map (1000, 1000);

   procedure Put_Tabs (N : Natural) is
   begin
      for I in Natural range 1..N loop
         Ada.Text_IO.Put (File => File,
                          Item => "   ");
      end loop;
   end Put_Tabs;

   procedure Put_Line (Text : String) is
   begin
      Ada.Text_IO.Put_Line (File => File,
                            Item => Text);
   end Put_Line;

   procedure Put (Text : String) is
   begin
      Ada.Text_IO.Put (File => File,
                       Item => Text);
   end Put;

   -- Remove VK_ if the identifier begins with that
   -- Will not remove VK_ if it would result in a reserved word in Ada
   function Adaify_Constant_Name (N : String) return String is
   begin
      if Std_String.Starts_With (This         => N,
                                 Searched_For => "VK_")
      then
         if N'Length > 3 then
            declare
               Short_N : String := N (N'First + 3..N'Last);
            begin
               if Short_N = "TRUE" or Short_N = "FALSE" then
                  return N;
               else
                  return N (N'First + 3..N'Last);
               end if;
            end;
         else
            return N;
         end if;
      else
         return N;
      end if;
   end Adaify_Constant_Name;

   procedure Remove_Initial_Vk (New_Name : in out Aida.Strings.Unbounded_String_Type) is
   begin
      if
        New_Name.Length = 3 and then
        New_Name.Equals ("Vk_")
      then
         New_Name.Initialize ("");
         --        else
         --           Aida.Text_IO.Put_Line (New_Name.To_String & " != Vk_");
      end if;
   end Remove_Initial_Vk;

   procedure Adaify_Name (Old_Name : String;
                          New_Name : in out Aida.Strings.Unbounded_String_Type)
   is
      P : Integer := Old_Name'First;

      CP : Aida.UTF8_Code_Point.T := 0;

      Is_Previous_Lowercase : Boolean := False;
      Is_Previous_A_Number  : Boolean := False;
      Is_Previous_An_Undercase  : Boolean := False;
   begin
      New_Name.Initialize ("");
      Aida.UTF8.Get (Source  => Old_Name,
                     Pointer => P,
                     Value   => CP);

      if Is_Uppercase (CP) then
         New_Name.Append (Image (CP));
      else
         New_Name.Append (Image (To_Uppercase (CP)));
      end if;

      while P <= Old_Name'Last loop
         Aida.UTF8.Get (Source  => Old_Name,
                        Pointer => P,
                        Value   => CP);

         if Image (CP) = "_" then
            New_Name.Append ("_");
            Remove_Initial_Vk (New_Name);
            Is_Previous_An_Undercase := True;
         else
            if Is_Digit (CP) then
               if Is_Previous_A_Number then
                  New_Name.Append (Image (CP));
               else
                  New_Name.Append ("_");
                  Remove_Initial_Vk (New_Name);
                  New_Name.Append (Image (CP));
               end if;

               Is_Previous_A_Number := True;
            else
               if Is_Uppercase (CP) then
                  if Is_Previous_Lowercase then
                     New_Name.Append ("_");
                     Remove_Initial_Vk (New_Name);
                     New_Name.Append (Image (CP));
                     Is_Previous_Lowercase := False;
                  else
                     New_Name.Append (Image (To_Lowercase (CP)));
                  end if;
               else
                  if Is_Previous_An_Undercase then
                     New_Name.Append (Image (To_Uppercase (CP)));
                  else
                     New_Name.Append (Image (CP));
                  end if;
                  Is_Previous_Lowercase := True;
               end if;

               Is_Previous_A_Number := False;
            end if;

            Is_Previous_An_Undercase := False;
         end if;

      end loop;
   end Adaify_Name;

   procedure Adaify_Type_Name (Old_Name : String;
                               New_Name : in out Aida.Strings.Unbounded_String_Type) is
   begin
      Adaify_Name (Old_Name => Old_Name,
                   New_Name => New_Name);
      Aida.Strings.Append (This => New_Name,
                           Text => T_End);
   end Adaify_Type_Name;

   function Value_Of_Bit (B : Vk_XML.Enums_Enum.Fs.Bit_Position_T) return Long_Integer is
   begin
      return 2 ** Integer (B);
   end Value_Of_Bit;

   procedure Handle_Child_Type (Type_V : Vk_XML.Type_Shared_Ptr.T;
                                R      : Vk_XML.Registry_Shared_Ptr.T)
   is

      procedure Generate_Code_For_Enum_Bitmask_If_Found (Searched_For     : Vk_XML.Type_T.Fs.Requires.T;
                                                         Parent_Type_Name : Aida.Strings.Unbounded_String_Type) is
         Shall_Continue_Search : Boolean := True;

         procedure Search_Enum_Tags_And_Generate_Code_If_Found (Enums_V : Vk_XML.Enums_Shared_Ptr.T) is

            procedure Auto_Generate_Code_For_Found_Enum is

               Adafied_Name : Aida.Strings.Unbounded_String_Type;

               procedure Handle_Enum_Bitmask (Enum_V : Vk_XML.Enums_Enum_Shared_Ptr.T) is
               begin
                  if Name (Enum_V).Exists then
                     if Bit_Position (Enum_V).Exists then
                        declare
                           V : Vk_XML.Enums_Enum.Fs.Bit_Position_T := Bit_Position (Enum_V).Value;
                           N : String := To_String (Name (Enum_V).Value);
                        begin
                           Put_Tabs (1);
                           Put (Adaify_Constant_Name (N));
                           Put (" : ");
                           Put (To_String (Adafied_Name));
                           Put (" := ");
                           Put (Value_Of_Bit (V)'Img & ";");

                           if Comment (Enum_V).Exists then
                              Put (" -- ");
                              Put (To_String (Comment (Enum_V).Value));
                           end if;
                           Put_Line ("");
                        end;
                     elsif Value (Enum_V).Exists then
                        declare
                           V : Aida.Strings.Unbounded_String_Type;
                           N : String := To_String (Name (Enum_V).Value);
                           Extracted_Text : Aida.Strings.Unbounded_String_Type;
                        begin
                           Aida.Strings.Initialize (This => V,
                                                    Text => To_String (Value (Enum_V).Value_V));
                           if
                             Aida.Strings.Starts_With (This         => V,
                                                       Searched_For => "0x")
                           then
                              Aida.Strings.Substring (This        => V,
                                                      Begin_Index => 3,
                                                      Result      => Extracted_Text);
                              Put_Tabs (1);
                              Put (Adaify_Constant_Name (N));
                              Put (" : ");
                              Put (To_String (Adafied_Name));
                              Put (" := 16#");
                              Put (To_String (Extracted_Text));
                              Put ("#;");

                              if Comment (Enum_V).Exists then
                                 Put (" -- ");
                                 Put (To_String (Comment (Enum_V).Value));
                              end if;
                              Put_Line ("");
                           elsif Equals (V, "0") then
                              Put_Tabs (1);
                              Put (Adaify_Constant_Name (N));
                              Put (" : ");
                              Put (To_String (Adafied_Name));
                              Put (" := ");
                              Put (To_String (V));
                              Put (";");

                              if Comment (Enum_V).Exists then
                                 Put (" -- ");
                                 Put (To_String (Comment (Enum_V).Value));
                              end if;
                              Put_Line ("");
                           else
                              Aida.Text_IO.Put_Line (GNAT.Source_Info.Source_Location & ", Cannot interpret value of  <enum> tag!? ");
                              To_Standard_Out (Enum_V);
                           end if;
                        end;
                     else
                        Aida.Text_IO.Put_Line (GNAT.Source_Info.Source_Location & ", A <enum> tag exists without Bit position attribute!? ");
                        To_Standard_Out (Enum_V);
                     end if;
                  else
                     Aida.Text_IO.Put_Line (GNAT.Source_Info.Source_Location & ", A <enum> tag exists without Name attribute!?");
                  end if;
               end Handle_Enum_Bitmask;

               Is_First_Enum : Boolean := True;

               Name_To_Adafy : String := To_String (Name (Enums_V).Value);
            begin
               Adaify_Type_Name (Old_Name => Name_To_Adafy,
                                 New_Name => Adafied_Name);

               Put_Tabs (1);
               Put ("type ");
               Put (Adafied_Name.To_String);
               Put (" is new ");
               Put (To_String (Parent_Type_Name));
               Put_Line (";");

               for I in Positive range First_Index (Children (Enums_V))..Last_Index (Children (Enums_V)) loop
                  case Element (Children (Enums_V), I).Kind_Id is
                     when Child_Enums_Enum => Handle_Enum_Bitmask (Element (Children (Enums_V), I).Enums_Enum_V);
                     when others           => null;
                  end case;
               end loop;

--                 Put_Tabs (1);
--                 Put_Line (");");
--                 Put_Tabs (1);
--                 Put ("for ");
--                 Put (Adafied_Name.To_String);
--                 Put_Line (" use (");
--
--                 Is_First_Enum := True;
--                 for I in Permutation_Array'Range loop
--                    Handle_Child_Enums_Enum_Representation_Clause (Permutation_Array (I), Is_First_Enum);
--                 end loop;
--                 Put_Line ("");
--                 Put_Tabs (1);
--                 Put_Line (");");
                 Put_Line ("");
            end Auto_Generate_Code_For_Found_Enum;

         begin
            if Name (Enums_V).Exists then
               if To_String (Name (Enums_V).Value) = To_String (Searched_For) then
                  if Type_Attribue (Enums_V).Exists then
                     case Type_Attribue (Enums_V).Value is
                        when Enum     => null;
                        when Bit_Mask =>
                           Auto_Generate_Code_For_Found_Enum;
                           Shall_Continue_Search := False;
                     end case;
                  end if;
               end if;
            end if;
         end Search_Enum_Tags_And_Generate_Code_If_Found;

      begin
         for I in Positive range First_Index (Children (R))..Last_Index (Children (R)) loop
            case Element (Children (R), I).Kind_Id is
               when Child_Enums =>
                  Search_Enum_Tags_And_Generate_Code_If_Found (Element (Children (R), I).Enums_V);
               when others =>
                  null;
            end case;

            if not Shall_Continue_Search then
               exit;
            end if;
         end loop;

         if Shall_Continue_Search then
            Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", could not find enum bitmask with name " & To_String (Searched_For));
            Aida.Text_IO.Put_Line (To_String (Type_V));
         end if;
      end Generate_Code_For_Enum_Bitmask_If_Found;

   begin
      if
        To_String (Category (Type_V)) = "include" and then
        not Requires (Type_V).Exists
      then
         null; -- ignore for example <type category="include">#include "<name>vulkan.h</name>"</type>
      elsif
        Requires (Type_V).Exists and then
        Name (Type_V).Exists and then (
                                       To_String (Requires (Type_V).Value) = "X11/Xlib.h" or
                                         To_String (Requires (Type_V).Value) = "android/native_window.h" or
                                           To_String (Requires (Type_V).Value) = "mir_toolkit/client_types.h" or
                                         To_String (Requires (Type_V).Value) = "wayland-client.h" or
                                           To_String (Requires (Type_V).Value) = "windows.h" or
                                         To_String (Requires (Type_V).Value) = "xcb/xcb.h"
                                      )
      then
         null; -- ignore for example <type requires="android/native_window.h" name="ANativeWindow"/>
      elsif To_String (Category (Type_V)) = "define" then
         null; -- ignore for example <type category="define">#define <name>VK_VERSION_MAJOR</name>(version) ((uint32_t)(version) &gt;&gt; 22)</type>
      elsif
        To_String (Category (Type_V)) = "basetype" and then
        Length (Children (Type_V)) = 4
      then
         declare
            Typedef_Element : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)));
            Type_Element    : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 1);
            Name_Element    : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 2);
         begin
            if
              Typedef_Element.Kind_Id = Child_XML_Text and then
              To_String (Typedef_Element.XML_Text_V) = "typedef "
            then
               if
                 Name_Element.Kind_Id = Child_Name
               then
                  if
                    Type_Element.Kind_Id = Child_Nested_Type and then
                    Value (Type_Element.Nested_Type_V).Exists
                  then
                     declare
                        New_Type_Name : Aida.Strings.Unbounded_String_Type;
                        Parent_Type_Name : Aida.Strings.Unbounded_String_Type;
                     begin
                        if To_String (Value (Type_Element.Nested_Type_V).Value_V) = "uint32_t" then
                           Aida.Strings.Append (This => Parent_Type_Name,
                                                Text => "Interfaces.Unsigned_32");
                        elsif To_String (Value (Type_Element.Nested_Type_V).Value_V) = "uint64_t" then
                           Aida.Strings.Append (This => Parent_Type_Name,
                                                Text => "Interfaces.Unsigned_64");
                        end if;

                        if Aida.Strings.Length (Parent_Type_Name) > 0 then
                           Adaify_Type_Name (Old_Name => To_String (Value (Name_Element.Name_V)),
                                             New_Name => New_Type_Name);
                           Put_Tabs (1);
                           Put ("type ");
                           Put (To_String (New_Type_Name));
                           Put (" is new ");
                           Put (To_String (Parent_Type_Name));
                           Put_Line (";");
                           Put_Line ("");

                           declare
                              C_Type_Name : Aida.Strings.Unbounded_String_Type;
                           begin
                              Aida.Strings.Initialize (This => C_Type_Name,
                                                       Text => To_String (Value (Name_Element.Name_V)));
                              C_Type_Name_To_Ada_Name_Map_Owner.Insert (Container => C_Type_Name_To_Ada_Name_Map,
                                                                        Key       => C_Type_Name,
                                                                        New_Item  => New_Type_Name);
                           end;
                        else
                           Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Erroneous conversion of ");
                           Aida.Text_IO.Put_Line (To_String (Type_V));
                        end if;
                     end;
                  else
                     Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Skipping conversion of ");
                     Aida.Text_IO.Put_Line (To_String (Type_V));
                  end if;
               else
                  Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Skipping conversion of ");
                  Aida.Text_IO.Put_Line (To_String (Type_V));
               end if;
            else
               Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Skipping conversion of ");
               Aida.Text_IO.Put_Line (To_String (Type_V));
            end if;
         end;
      elsif
        Requires (Type_V).Exists and then
        To_String (Requires (Type_V).Value) = "vk_platform" and then
        Name (Type_V).Exists and then (
                                       To_String (Name (Type_V).Value) = "void" or
                                         To_String (Name (Type_V).Value) = "char" or
                                           To_String (Name (Type_V).Value) = "float" or
                                         To_String (Name (Type_V).Value) = "uint8_t" or
                                           To_String (Name (Type_V).Value) = "uint32_t" or
                                         To_String (Name (Type_V).Value) = "uint64_t" or
                                           To_String (Name (Type_V).Value) = "int32_t" or
                                         To_String (Name (Type_V).Value) = "size_t"
                                      )
      then
         null;
      elsif
        To_String (Category (Type_V)) = "bitmask" and then
        Length (Children (Type_V)) = 4
      then
         declare
            Typedef_Element : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)));
            Type_Element    : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 1);
            Name_Element    : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 2);
         begin
            if
              Typedef_Element.Kind_Id = Child_XML_Text and then
              To_String (Typedef_Element.XML_Text_V) = "typedef "
            then
               if
                 Name_Element.Kind_Id = Child_Name
               then
                  if
                    Type_Element.Kind_Id = Child_Nested_Type and then
                    Value (Type_Element.Nested_Type_V).Exists
                  then
                     declare
                        New_Type_Name : Aida.Strings.Unbounded_String_Type;
                        Parent_Type_Name : Aida.Strings.Unbounded_String_Type;

                        Searched_For : Aida.Strings.Unbounded_String_Type;

                        Cursor_V : C_Type_Name_To_Ada_Name_Map_Owner.Cursor;
                     begin
                        Aida.Strings.Initialize (This => Searched_For,
                                                 Text => To_String (Value (Type_Element.Nested_Type_V).Value_V));

                        Cursor_V := C_Type_Name_To_Ada_Name_Map_Owner.Find (Container => C_Type_Name_To_Ada_Name_Map,
                                                                            Key       => Searched_For);

                        if Cursor_V /= C_Type_Name_To_Ada_Name_Map_Owner.No_Element then
                           Adaify_Type_Name (Old_Name => To_String (Value (Type_Element.Nested_Type_V).Value_V),
                                             New_Name => Parent_Type_Name);
                        end if;

                        if Aida.Strings.Length (Parent_Type_Name) > 0 then
                           Adaify_Type_Name (Old_Name => To_String (Value (Name_Element.Name_V)),
                                             New_Name => New_Type_Name);
                           Put_Tabs (1);
                           Put ("type ");
                           Put (To_String (New_Type_Name));
                           Put (" is new ");
                           Put (To_String (Parent_Type_Name));
                           Put_Line (";");
                           Put_Line ("");

                           declare
                              C_Type_Name : Aida.Strings.Unbounded_String_Type;
                           begin
                              Aida.Strings.Initialize (This => C_Type_Name,
                                                       Text => To_String (Value (Name_Element.Name_V)));
                              C_Type_Name_To_Ada_Name_Map_Owner.Insert (Container => C_Type_Name_To_Ada_Name_Map,
                                                                        Key       => C_Type_Name,
                                                                        New_Item  => New_Type_Name);
                           end;

                           if Requires (Type_V).Exists then
                              Generate_Code_For_Enum_Bitmask_If_Found (Requires (Type_V).Value,
                                                                       New_Type_Name);
                           end if;
                        else
                           Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Erroneous conversion of ");
                           Aida.Text_IO.Put_Line (To_String (Type_V));
                        end if;
                     end;
                  else
                     Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Skipping conversion of ");
                     Aida.Text_IO.Put_Line (To_String (Type_V));
                  end if;
               else
                  Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Skipping conversion of ");
                  Aida.Text_IO.Put_Line (To_String (Type_V));
               end if;
            else
               Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Skipping conversion of ");
               Aida.Text_IO.Put_Line (To_String (Type_V));
            end if;
         end;
      elsif
        To_String (Category (Type_V)) = "handle" and then
        Length (Children (Type_V)) = 4
      then
         declare
            Nested_Type_Element   : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)));
            Left_Bracket_Element  : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 1);
            Name_Element          : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 2);
            Right_Bracket_Element : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 3);
         begin
            if
              (Left_Bracket_Element.Kind_Id = Child_XML_Text and then
               To_String (Left_Bracket_Element.XML_Text_V) = "(") and
              (Right_Bracket_Element.Kind_Id = Child_XML_Text and then
               To_String (Right_Bracket_Element.XML_Text_V) = ")") and
              (Nested_Type_Element.Kind_Id = Child_Nested_Type and then
              Value (Nested_Type_Element.Nested_Type_V).Exists and then
                   (To_String (Value (Nested_Type_Element.Nested_Type_V).Value_V) = "VK_DEFINE_HANDLE" or To_String (Value (Nested_Type_Element.Nested_Type_V).Value_V) = "VK_DEFINE_NON_DISPATCHABLE_HANDLE")) and
              Name_Element.Kind_Id = Child_Name
            then
               declare
                  New_Type_Name : Aida.Strings.Unbounded_String_Type;
               begin
                  Adaify_Type_Name (Old_Name => To_String (Value (Name_Element.Name_V)),
	                            New_Name => New_Type_Name);

                  Put_Tabs (1);
                  Put ("type ");
                  Put (To_String (New_Type_Name));
                  Put_Line (" is private;");
                  Put_Line ("");
               end;
            end if;
         end;
      elsif
        To_String (Category (Type_V)) = "enum" and then
        Name (Type_V).Exists
      then
         null; -- Skip these since they are generated from the enum type definitions
               -- It should be checked that all expected enum type definitions has been generated in this step!
               -- TODO: Add this extra nice feature!
      elsif
        To_String (Category (Type_V)) = "funcpointer" and then
        not Name (Type_V).Exists
      then
         declare
            Typedef_Void_VKAPI_Ptr_Element : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)));
            Procedure_Name_Element : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 1);
         begin
            if (Typedef_Void_VKAPI_Ptr_Element.Kind_Id = Child_XML_Text and then
                To_String (Typedef_Void_VKAPI_Ptr_Element.XML_Text_V) = "typedef void (VKAPI_PTR *") and
              Procedure_Name_Element.Kind_Id = Child_Name
            then
               declare
                  New_Type_Name : Aida.Strings.Unbounded_String_Type;
               begin
                  Adaify_Type_Name (Old_Name => To_String (Value (Procedure_Name_Element.Name_V)),
                                    New_Name => New_Type_Name);

                  if
                    Length (Children (Type_V)) = 3 and then
                    Element (Children (Type_V), First_Index (Children (Type_V)) + 2).Kind_Id = Child_XML_Text and then
                    To_String (Element (Children (Type_V), First_Index (Children (Type_V)) + 2).XML_Text_V) = ")(void);"
                  then
                     Put_Tabs (1);
                     Put ("type ");
                     Put (To_String (New_Type_Name));
                     Put_Line (" is access procedure;");
                     Put_Line ("");
                  else
                     Put_Tabs (1);
                     Put ("type ");
                     Put (To_String (New_Type_Name));
                     Put_Line (" is access procedure (");
                     Put_Tabs (1);

                     for I in Positive range First_Index (Children (Type_V)) + 3..Last_Index (Children (Type_V)) loop
                        declare
                           Nested_Type_Element : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), I);
                           Nested_Type_Name : Aida.Strings.Unbounded_String_Type;

                           Searched_For_Cursor : C_Type_Name_To_Ada_Name_Map_Owner.Cursor;
                        begin
                           if
                             Nested_Type_Element.Kind_Id = Child_Nested_Type and then
                             Value (Nested_Type_Element.Nested_Type_V).Exists
                           then
                              Nested_Type_Name.Initialize (To_String (Value (Nested_Type_Element.Nested_Type_V).Value_V));

                              Searched_For_Cursor := C_Type_Name_To_Ada_Name_Map_Owner.Find (Container => C_Type_Name_To_Ada_Name_Map,
                                                                                             Key       => Nested_Type_Name);

                              if Searched_For_Cursor /= C_Type_Name_To_Ada_Name_Map_Owner.No_Element then
                                 declare
                                    C_Var_Name_Element : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), I + 1);
                                 begin
                                    if C_Var_Name_Element.Kind_Id = Child_XML_Text then
                                       declare
                                          C_Var_Name : Aida.Strings.Unbounded_String_Type;
                                          Comma_Index : Natural;
                                          Has_Found : Boolean;
                                       begin
                                          C_Var_Name.Initialize (To_String (C_Var_Name_Element.XML_Text_V));
                                          C_Var_Name.Find_First_Index (To_Search_For => ",",
                                                                       Found_Index   => Comma_Index,
                                                                       Has_Found     => Has_Found);

                                          if Has_Found then
                                             declare
                                                Total         : String := To_String (C_Var_Name);
                                                N_With_Spaces : String := Total (Total'First+1..Comma_Index - 1);
                                                N             : String := Ada.Strings.Fixed.Trim (Source => N_With_Spaces,
                                                                                                  Side   => Ada.Strings.Both);
                                             begin
                                                if Total (Total'First) = '*' then
                                                   null;
                                                else
                                                   Put_Tabs (2);
                                                   Put (N);
                                                   Put (" : ");
                                                   Put_Line (";");
                                                end if;
                                             end;
                                          else
                                             null; -- May be last parameter
                                          end if;
                                       end;
                                    else
                                       Aida.Text_IO.Put_Line (GNAT.Source_Info.Source_Location & ", Skipping conversion of ");
                                    end if;
                                 end;
                              else
                                 Aida.Text_IO.Put_Line (GNAT.Source_Info.Source_Location & ", could not find type: " & Nested_Type_Name.To_String);
                              end if;
                           end if;
                        end;
                     end loop;

                     Put (");");
                     Put_Line ("");
                  end if;

               end;
            else
               Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Skipping conversion of ");
               Aida.Text_IO.Put_Line (To_String (Type_V));
            end if;
         end;
      else
         Aida.Text_IO.Put (GNAT.Source_Info.Source_Location & ", Skipping conversion of ");
         Aida.Text_IO.Put_Line (To_String (Type_V));
      end if;
   end Handle_Child_Type;

   procedure Handle_Out_Commented_Message (Out_Commented_Message_V : Vk_XML.XML_Out_Commented_Message_Shared_Ptr.T) is
   begin
      null;
      --        Aida.Text_IO.Put ("Out commented message:");
      --        Aida.Text_IO.Put_Line (Vk_XML.XML_Out_Commented_Message_Shared_Ptr.To_String (Out_Commented_Message_V));
   end Handle_Out_Commented_Message;

   procedure Handle_API_Constants_Enum (Enum_V : Vk_XML.Enums_Enum_Shared_Ptr.T) is
   begin
      if Name (Enum_V).Exists then
         if Value (Enum_V).Exists then
            declare
               Has_Failed : Boolean;
               I : Integer;
               V : String := To_String (Value (Enum_V).Value_V);
               N : String := To_String (Name (Enum_V).Value);
            begin
               Std_String.To_Integer (Source => V,
                                      Target => I,
                                      Has_Failed => Has_Failed);

               if Has_Failed then
                  Aida.Text_IO.Put ("Could not convert '");
                  Aida.Text_IO.Put (V);
                  Aida.Text_IO.Put ("' to integer for ");
                  Aida.Text_IO.Put_Line (N);
               else
                  Put_Tabs (1);
                  Put (Adaify_Constant_Name (N));
                  Put (" : constant := ");
                  Put (V);
                  Put_Line (";");
               end if;
            end;
         else
            Aida.Text_IO.Put_Line ("A <enum> tag exists without Value attribute!?");
         end if;
      else
         Aida.Text_IO.Put_Line ("A <enum> tag exists without Name attribute!?");
      end if;
   end Handle_API_Constants_Enum;

   procedure Handle_Child_Enums_Enum (Enum_V       : Vk_XML.Enums_Enum_Shared_Ptr.T;
                                      Is_Last_Enum : in Boolean) is
   begin
      if Name (Enum_V).Exists then
         if Value (Enum_V).Exists then
            declare
               Has_Failed : Boolean;
               I : Integer;
               V : String := To_String (Value (Enum_V).Value_V);
               N : String := To_String (Name (Enum_V).Value);
            begin
               Std_String.To_Integer (Source => V,
                                      Target => I,
                                      Has_Failed => Has_Failed);

               if Has_Failed then
                  Aida.Text_IO.Put ("Could not convert '");
                  Aida.Text_IO.Put (V);
                  Aida.Text_IO.Put ("' to integer for ");
                  Aida.Text_IO.Put_Line (N);
               else
                  Put_Tabs (2);
                  Put (Adaify_Constant_Name (N));
                  if not Is_Last_Enum then
                     Put (",");
                  end if;

                  if Comment (Enum_V).Exists then
                     Put (" -- ");
                     Put (To_String (Comment (Enum_V).Value));
                  end if;
                  Put_Line ("");
               end if;
            end;
         else
            Aida.Text_IO.Put_Line ("A <enum> tag exists without Value attribute!?");
         end if;
      else
         Aida.Text_IO.Put_Line ("A <enum> tag exists without Name attribute!?");
      end if;
   end Handle_Child_Enums_Enum;

   procedure Handle_Child_Enums_Enum_Representation_Clause (Enum_V        : Vk_XML.Enums_Enum_Shared_Ptr.T;
                                                            Is_First_Enum : in out Boolean) is
   begin
      if Name (Enum_V).Exists then
         if Value (Enum_V).Exists then
            declare
               Has_Failed : Boolean;
               I : Integer;
               V : String := To_String (Value (Enum_V).Value_V);
               N : String := To_String (Name (Enum_V).Value);
            begin
               Std_String.To_Integer (Source => V,
                                      Target => I,
                                      Has_Failed => Has_Failed);

               if Has_Failed then
                  Aida.Text_IO.Put ("Could not convert '");
                  Aida.Text_IO.Put (V);
                  Aida.Text_IO.Put ("' to integer for ");
                  Aida.Text_IO.Put_Line (N);
               else
                  if Is_First_Enum then
                     Is_First_Enum := False;
                  else
                     Put_Line (",");
                  end if;
                  Put_Tabs (2);
                  Put (Adaify_Constant_Name (N));
                  Put (" => ");
                  Put (V);
               end if;
            end;
         else
            Aida.Text_IO.Put_Line ("A <enum> tag exists without Value attribute!?");
         end if;
      else
         Aida.Text_IO.Put_Line ("A <enum> tag exists without Name attribute!?");
      end if;
   end Handle_Child_Enums_Enum_Representation_Clause;

   package Enum_Vectors is new Ada.Containers.Formal_Vectors (Index_Type   => Positive,
                                                              Element_Type => Vk_XML.Enums_Enum_Shared_Ptr.T,
                                                              "="          => Vk_XML.Enums_Enum_Shared_Ptr."=",
                                                              Bounded      => True);

   procedure Handle_Registry_Child_Enums (Enums_V : Vk_XML.Enums_Shared_Ptr.T) is

      procedure Handle_Type_Attribute_Exists is
         Name_To_Adafy : String := To_String (Name (Enums_V).Value);
         Adafied_Name : Aida.Strings.Unbounded_String_Type;

         procedure Auto_Generate_Code_For_Enum is
            Is_First_Enum : Boolean := True;
            Is_Last_Enum : Boolean;

            Enum_Vector : Enum_Vectors.Vector (1000);

            procedure Populate_Enum_Vector is
            begin
               for I in Positive range First_Index (Children (Enums_V))..Last_Index (Children (Enums_V)) loop
                  case Element (Children (Enums_V), I).Kind_Id is
                  when Child_XML_Dummy             => null;
                  when Child_Enums_Enum            =>
                     declare
                        Test : Vk_XML.Enums_Enum_Shared_Ptr.T := Element (Children (Enums_V), I).Enums_Enum_V;
                     begin
                        Enum_Vectors.Append (Container => Enum_Vector,
                                             New_Item  => Test);
                     end;
                  when Child_Out_Commented_Message => null;
                  when Child_Unused                => null;
                  end case;
               end loop;
            end Populate_Enum_Vector;

            procedure Populate_Permutation_Array_And_Then_Generate_Ada_Code is

               type Array_Index_T is new Integer range Enum_Vectors.First_Index (Enum_Vector)..Enum_Vectors.Last_Index (Enum_Vector);

               type Permutation_Array_T is array (Array_Index_T) of Vk_XML.Enums_Enum_Shared_Ptr.T;

               Permutation_Array : Permutation_Array_T;

               function "<" (L, R : Vk_XML.Enums_Enum_Shared_Ptr.T) return Boolean is
                  Has_Failed : Boolean;
                  LI : Integer;
                  LV : String := To_String (Value (L).Value_V);

                  RI : Integer;
                  RV : String := To_String (Value (R).Value_V);
               begin
                  Std_String.To_Integer (Source => LV,
                                         Target => LI,
                                         Has_Failed => Has_Failed);

                  if Has_Failed then
                     raise Constraint_Error with "Could not convert '" & LV & "' to integer";
                  else
                     Std_String.To_Integer (Source => RV,
                                            Target => RI,
                                            Has_Failed => Has_Failed);

                     if Has_Failed then
                        raise Constraint_Error with "Could not convert '" & RV & "' to integer";
                     else
                        return LI < RI;
                     end if;
                  end if;
               end "<";

               procedure Sort is new Ada.Containers.Generic_Constrained_Array_Sort (Index_Type   => Array_Index_T,
                                                                                    Element_Type => Vk_XML.Enums_Enum_Shared_Ptr.T,
                                                                                    Array_Type   => Permutation_Array_T,
                                                                                    "<"          => "<");

               procedure Populate_Permutation_Array is
               begin
                  for I in Positive range Enum_Vectors.First_Index (Enum_Vector)..Enum_Vectors.Last_Index (Enum_Vector) loop
                     Permutation_Array (Array_Index_T (I)) := Enum_Vectors.Element (Container => Enum_Vector,
                                                                                    Index     => I);
                  end loop;

                  Sort (Permutation_Array);
               end Populate_Permutation_Array;

            begin
               Populate_Permutation_Array;

               Put_Tabs (1);
               Put ("type ");
               Put (Adafied_Name.To_String);
               Put_Line (" is (");

               for I in Permutation_Array'Range loop
                  Is_Last_Enum := (I = Permutation_Array'Last);
                  Handle_Child_Enums_Enum (Permutation_Array (I), Is_Last_Enum);
               end loop;

               Put_Tabs (1);
               Put_Line (");");
               Put_Tabs (1);
               Put ("for ");
               Put (Adafied_Name.To_String);
               Put_Line (" use (");

               Is_First_Enum := True;
               for I in Permutation_Array'Range loop
                  Handle_Child_Enums_Enum_Representation_Clause (Permutation_Array (I), Is_First_Enum);
               end loop;
               Put_Line ("");
               Put_Tabs (1);
               Put_Line (");");
               Put_Line ("");
            end Populate_Permutation_Array_And_Then_Generate_Ada_Code;

         begin
            Populate_Enum_Vector;
            Populate_Permutation_Array_And_Then_Generate_Ada_Code;
         end Auto_Generate_Code_For_Enum;

      begin
         Adaify_Type_Name (Old_Name => Name_To_Adafy,
                           New_Name => Adafied_Name);

         case Type_Attribue (Enums_V).Value is
            when Enum     => Auto_Generate_Code_For_Enum;
            when Bit_Mask => null; -- The bit mask information is/will be used when generating code for <type>-tags.
         end case;
      end Handle_Type_Attribute_Exists;

   begin
      if Name (Enums_V).Exists then
         if To_String (Name (Enums_V).Value) = "API Constants" then
            for I in Positive range First_Index (Children (Enums_V))..Last_Index (Children (Enums_V)) loop
               case Element (Children (Enums_V), I).Kind_Id is
                  when Child_XML_Dummy             => null;
                  when Child_Enums_Enum            => Handle_API_Constants_Enum (Element (Children (Enums_V), I).Enums_Enum_V);
                  when Child_Out_Commented_Message => null;--Handle_Out_Commented_Message(Element (Children (Types_V), I).Out_Commented_Message_V);
                  when Child_Unused                => null;
               end case;
            end loop;
            Put_Line ("");
         else
            if Type_Attribue (Enums_V).Exists then
               Handle_Type_Attribute_Exists;
            else
               Aida.Text_IO.Put_Line (GNAT.Source_Info.Source_Location & ", A <enums> tag exists without Type attribute!?");
            end if;
         end if;
      else
         Aida.Text_IO.Put_Line (GNAT.Source_Info.Source_Location & ", A <enums> tag exists without Name attribute!?");
      end if;
   end Handle_Registry_Child_Enums;

   procedure Create_Vk_Package (R : Vk_XML.Registry_Shared_Ptr.T) is

      procedure Generate_Code_For_The_Public_Part  is

         procedure Handle_Child_Types (Types_V : Vk_XML.Types_Shared_Ptr.T;
                                       R       : Vk_XML.Registry_Shared_Ptr.T) is
         begin
            for I in Positive range First_Index (Children (Types_V))..Last_Index (Children (Types_V)) loop
               case Element (Children (Types_V), I).Kind_Id is
               when Child_XML_Dummy             => null;
               when Child_Type                  => Handle_Child_Type (Element (Children (Types_V), I).Type_V, R);
               when Child_Out_Commented_Message => Handle_Out_Commented_Message(Element (Children (Types_V), I).Out_Commented_Message_V);
               end case;
            end loop;
         end Handle_Child_Types;

      begin
         Put_Line ("");
         Put_Tabs (1); Put_Line ("pragma Linker_Options (""-lvulkan-1"");");
         Put_Line ("");

         for I in Positive range First_Index (Children (R))..Last_Index (Children (R)) loop
            case Element (Children (R), I).Kind_Id is
            when Child_Comment =>
               --                 Aida.Text_IO.Put ("Registry child comment with value:");
               --                 Aida.Text_IO.Put_Line (Vk_XML.Comment.Fs.Value.To_String (Vk_XML.Comment_Shared_Ptr.Value (Vk_XML.Registry.Fs.Child_Vectors.Element (Children (R), I).C)));
               null;
            when Child_Out_Commented_Message =>
               --                 Aida.Text_IO.Put ("Registry child out commented message:");
               --                 Aida.Text_IO.Put_Line (Vk_XML.XML_Out_Commented_Message_Shared_Ptr.To_String (Vk_XML.Registry.Fs.Child_Vectors.Element (Children (R), I).Out_Commented_Message_V));
               null;
            when Child_Vendor_Ids =>
               null;
            when Child_Tags =>
               null;
            when Child_Types =>
               Handle_Child_Types (Element (Children (R), I).Types_V, R);
            when Child_Enums =>
               Handle_Registry_Child_Enums (Element (Children (R), I).Enums_V);
            when Child_Commands =>
               null;
            when Child_Feature =>
               null;
            when Child_Extensions =>
               null;
            when Child_XML_Dummy =>
               null;
            when Child_XML_Text =>
               null;
            end case;
         end loop;
      end Generate_Code_For_The_Public_Part;

      procedure Generate_Code_For_The_Private_Part is

         procedure Handle_Child_Types (Types_V : Vk_XML.Types_Shared_Ptr.T;
                                       R       : Vk_XML.Registry_Shared_Ptr.T)
         is

            procedure Handle_Child_Type_In_The_Private_Part (Type_V : Vk_XML.Type_Shared_Ptr.T;
                                                             R      : Vk_XML.Registry_Shared_Ptr.T)
            is
            begin
               if
                 To_String (Category (Type_V)) = "handle" and then
                 Length (Children (Type_V)) = 4
               then
                  declare
                     Nested_Type_Element   : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)));
                     Left_Bracket_Element  : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 1);
                     Name_Element          : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 2);
                     Right_Bracket_Element : Vk_XML.Type_T.Fs.Child_T renames Element (Children (Type_V), First_Index (Children (Type_V)) + 3);
                  begin
                     if
                       (Left_Bracket_Element.Kind_Id = Child_XML_Text and then
                        To_String (Left_Bracket_Element.XML_Text_V) = "(") and
                       (Right_Bracket_Element.Kind_Id = Child_XML_Text and then
                        To_String (Right_Bracket_Element.XML_Text_V) = ")") and
                       (Nested_Type_Element.Kind_Id = Child_Nested_Type and then
                        Value (Nested_Type_Element.Nested_Type_V).Exists and then
                            (To_String (Value (Nested_Type_Element.Nested_Type_V).Value_V) = "VK_DEFINE_HANDLE" or To_String (Value (Nested_Type_Element.Nested_Type_V).Value_V) = "VK_DEFINE_NON_DISPATCHABLE_HANDLE")) and
                       Name_Element.Kind_Id = Child_Name
                     then
                        declare
                           New_Type_Name : Aida.Strings.Unbounded_String_Type;
                        begin
                           Adaify_Type_Name (Old_Name => To_String (Value (Name_Element.Name_V)),
                                             New_Name => New_Type_Name);

                           declare
                              Hidden_Type_Name : String := "Hidden_" & To_String (New_Type_Name);
                           begin
                              Put_Tabs (1);
                              Put ("type ");
                              Put (Hidden_Type_Name);
                              Put_Line (" is null record;");

                              Put_Tabs (1);
                              Put ("type ");
                              Put (To_String (New_Type_Name));
                              Put (" is access ");
                              Put (Hidden_Type_Name);
                              Put_Line (";");
                              Put_Line ("");
                           end;
                        end;
                     end if;
                  end;
               end if;
            end Handle_Child_Type_In_The_Private_Part;

         begin
            for I in Positive range First_Index (Children (Types_V))..Last_Index (Children (Types_V)) loop
               case Element (Children (Types_V), I).Kind_Id is
                  when Child_Type => Handle_Child_Type_In_The_Private_Part (Element (Children (Types_V), I).Type_V, R);
                  when others     => null;
               end case;
            end loop;
         end Handle_Child_Types;

      begin
         for I in Positive range First_Index (Children (R))..Last_Index (Children (R)) loop
            case Element (Children (R), I).Kind_Id is
               when Child_Types =>
                  Handle_Child_Types (Element (Children (R), I).Types_V, R);
               when others =>
                  null;
            end case;
         end loop;
      end Generate_Code_For_The_Private_Part;

   begin
      Ada.Text_IO.Create (File => File,
                          Mode => Ada.Text_IO.Out_File,
                          Name => "vk.ads");
      Put_Line ("with Interfaces.C;");
      Put_Line ("");
      Put_Line ("package Vk is");

      Generate_Code_For_The_Public_Part;

      Put_Line ("");
      Put_Line ("private");
      Put_Line ("");

      Generate_Code_For_The_Private_Part;

      Put_Line ("");
      Put_Line ("end Vk;");

      Ada.Text_IO.Close (File);
   end Create_Vk_Package;

end Vk_Package_Creator;
