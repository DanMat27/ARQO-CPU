--------------------------------------------------------------------------------
-- Bloque de control para la ALU. Arq0 2019-2020.
--
-- Alumnos: Daniel Mateo Moreno
--          Franccy del Piero Sambrano Ganoza
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity alu_control is
   port (
      -- Entradas:
      ALUOp  : in std_logic_vector (2 downto 0); -- Codigo de control desde la unidad de control
      Funct  : in std_logic_vector (5 downto 0); -- Campo "funct" de la instruccion
      -- Salida de control para la ALU:
      ALUControl : out std_logic_vector (3 downto 0) -- Define operacion a ejecutar por la ALU
   );
end alu_control;

architecture rtl of alu_control is
 
   -- Subtipo de operacion para la ALU
   subtype t_alu is std_logic_vector (3 downto 0);
   
   -- Constantes de operación:
   constant ALU_OR   : t_alu := "0111"; --OR  
   constant ALU_NOT  : t_alu := "0101"; --NOT
   constant ALU_XOR  : t_alu := "0110"; --XOR
   constant ALU_AND  : t_alu := "0100"; --AND
   constant ALU_SUB  : t_alu := "0001"; --SUB
   constant ALU_ADD  : t_alu := "0000"; --ADD
   constant ALU_SLT  : t_alu := "1010"; --SLT
   constant ALU_S16  : t_alu := "1101"; --S16
   
   -- Señales intermedias
   signal sigALUControl : std_logic_vector (3 downto 0); -- Señal interna de ALUControl

begin

   process (ALUOp, Funct)
   begin
   
     if ALUOp = "000" then 
	  
	     if    Funct = "100000" then sigALUControl<= ALU_ADD; --ADD
		   elsif Funct = "100010" then sigALUControl<= ALU_SUB; --SUB
		   elsif Funct = "100100" then sigALUControl<= ALU_AND; --AND
		   elsif Funct = "100101" then sigALUControl<= ALU_OR; --OR
		   elsif Funct = "100110" then sigALUControl<= ALU_XOR; --XOR
		   else  sigALUControl <= ALU_ADD; 
		   end if;
		 
	   elsif ALUOp = "001" then sigALUControl <= ALU_ADD; --LW SW ADDI
	   elsif ALUOp = "010" then sigALUControl <= ALU_SUB; --BEQ
	   elsif ALUOp = "100" then sigALUControl <= ALU_SLT; --SLTI
	   elsif ALUOp = "101" then sigALUControl <= ALU_S16; --LUI
	   else  sigALUControl <= ALU_ADD;
	  
     end if;	
	  
	end process;
	
	ALUControl <= sigALUControl;

end architecture;
