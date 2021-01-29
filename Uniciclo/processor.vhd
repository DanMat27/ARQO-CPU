--------------------------------------------------------------------------------
-- Procesador MIPS con pipeline curso Arquitectura 2019-2020
--
-- Alumnos: Daniel Mateo Moreno
--          Franccy del Piero Sambrano Ganoza
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity processor is
   port(
      Clk         : in  std_logic; -- Reloj activo en flanco subida
      Reset       : in  std_logic; -- Reset asincrono activo nivel alto
      -- Instruction memory
      IAddr      : out std_logic_vector(31 downto 0); -- Direccion Instr
      IDataIn    : in  std_logic_vector(31 downto 0); -- Instruccion leida
      -- Data memory
      DAddr      : out std_logic_vector(31 downto 0); -- Direccion
      DRdEn      : out std_logic;                     -- Habilitacion lectura
      DWrEn      : out std_logic;                     -- Habilitacion escritura
      DDataOut   : out std_logic_vector(31 downto 0); -- Dato escrito
      DDataIn    : in  std_logic_vector(31 downto 0)  -- Dato leido
   );
end processor;

architecture rtl of processor is 

component alu
  port(
      OpA     : in  std_logic_vector (31 downto 0); -- Operando A
      OpB     : in  std_logic_vector (31 downto 0); -- Operando B
      Control : in  std_logic_vector ( 3 downto 0); -- Codigo de control=op. a ejecutar
      Result  : out std_logic_vector (31 downto 0); -- Resultado
      ZFlag   : out std_logic                       -- Flag Z 
  );
end component;

component alu_control
  port(
      ALUOp  : in std_logic_vector (2 downto 0); -- Codigo de control desde la unidad de control
      Funct  : in std_logic_vector (5 downto 0); -- Campo "funct" de la instruccion
      ALUControl : out std_logic_vector (3 downto 0) -- Define operacion a ejecutar por la ALU
  );
end component;

component control_unit
  port(
      -- Entrada = codigo de operacion en la instruccion:
      OpCode  : in  std_logic_vector (5 downto 0);
      -- Seniales para el PC
      Branch : out  std_logic; -- 1 = Ejecutandose instruccion branch
      -- Seniales relativas a la memoria
      MemToReg : out  std_logic; -- 1 = Escribir en registro la salida de la mem.
      MemWrite : out  std_logic; -- Escribir la memoria
      MemRead  : out  std_logic; -- Leer la memoria
      -- Seniales para la ALU
      ALUSrc : out  std_logic;                     -- 0 = oper.B es registro, 1 = es valor inm.
      ALUOp  : out  std_logic_vector (2 downto 0); -- Tipo operacion para control de la ALU
      -- Seniales para el GPR
      RegWrite : out  std_logic; -- 1=Escribir registro
      RegDst   : out  std_logic;  -- 0=Reg. destino es rt, 1=rd
      J : out std_logic -- 1=Salto 
     );
end component;
 
 component reg_bank 
    port (
      Clk   : in std_logic; -- Reloj activo en flanco de subida
      Reset : in std_logic; -- Reset asíncrono a nivel alto
      A1    : in std_logic_vector(4 downto 0);   -- Dirección para el puerto Rd1
      Rd1   : out std_logic_vector(31 downto 0); -- Dato del puerto Rd1
      A2    : in std_logic_vector(4 downto 0);   -- Dirección para el puerto Rd2
      Rd2   : out std_logic_vector(31 downto 0); -- Dato del puerto Rd2
      A3    : in std_logic_vector(4 downto 0);   -- Dirección para el puerto Wd3
      Wd3   : in std_logic_vector(31 downto 0);  -- Dato de entrada Wd3
      We3   : in std_logic -- Habilitación de la escritura de Wd3
   ); 
 end component;

  signal sigPCNext : std_logic_vector(31 downto 0); -- Senial auxiliar con el valor del PC siguiente
  signal sigPC : std_logic_vector(31 downto 0); -- Senial auxiliar con el valor del PC actual
  signal sigPCMas4 : std_logic_vector(31 downto 0); -- Senial auxiliar con el valor 
  signal sigInstruccion : std_logic_vector(31 downto 0); -- Senial auxiliar con la instruccion leida de la memoria de instrucciones
  signal sigSignoExtendido : std_logic_vector(31 downto 0); -- Senial auxiliar con la instruccion extendida 16 bits
  signal sigData1 : std_logic_vector(31 downto 0); -- Senial auxiliar con el dato del registro 1
  signal sigData2 : std_logic_vector(31 downto 0); -- Senial auxiliar con el dato del registro 2
  signal sigWd3 : std_logic_vector(31 downto 0); -- Senial auxiliar conectada al dato para escribir en banco de registros
  signal sigA3 : std_logic_vector(4 downto 0); -- Senial auxiliar con el valor del multiplexor con la direccion del registro a escribir
  signal sigALUControl : std_logic_vector(3 downto 0); -- Senial auxiliar con la operacion a realizar en la ALU
  signal sigALUResultado : std_logic_vector(31 downto 0); -- Senial auxiliar con el resultado de la ALU
  signal sigDataMem : std_logic_vector(31 downto 0); -- Senial auxiliar con el dato leido de la memoria de datos
  signal sigALUSrc, sigRegWrite1, sigRegWrite2, sigMemToReg, sigMemWrite1, sigMemWrite2, sigMemRead, sigBranch, sigRegDst, sigJ : std_logic; -- Seniales auxiliares de la unidad de control
  signal sigALUOp : std_logic_vector(2 downto 0); -- Senial auxiliar ALUControl de la unidad de control
  signal sigShiftLeft1 : std_logic_vector(31 downto 0); -- Senial auxiliare del primer desplazamiento a la izquierda
  signal sigShiftLeft2 : std_logic_vector(27 downto 0);  -- Senial auxiliar del segundo desplazamiento a la izquierda
  signal sigResSumador : std_logic_vector(31 downto 0); -- Senial auxiliar con el resultado del sumador para las nuevas direcciones 
  signal sigMultiplexorBranch, sigMultiplexorJ : std_logic_vector(31 downto 0); -- Seniales auxiliares con el valor de los multiplexores de salto y del branch
  signal sigSalto : std_logic_vector(31 downto 0); -- Senial auxiliar con el valor del salto
  signal sigAND : std_logic; -- Senial auxiliar con el valor de la puerta AND
  signal sigZFlag : std_logic; -- Senial auxiliar con el valor de la bandera Z
  signal sigOpB : std_logic_vector(31 downto 0); -- Senial auxiliar con el segundo valor que entra en la ALU
 
begin   


-- Instancia de reg_bank
  miBancoReg : reg_bank
  port map (
	  Clk => Clk,
	  Reset => Reset,
	  A1 => sigInstruccion(25 downto 21), -- Entrada direccion del registro 1 (Instruccion 25-21)  
    Rd1 => sigData1, -- Dato leido del registro 1
    A2 => sigInstruccion(20 downto 16), -- Entrada direccion del registro 2 (Instruccion 20-16)   
    Rd2 => sigData2, -- Dato leido del registro 2
    A3 => sigA3, -- Dato con la direccion del registro a escribir 
    Wd3 => sigWd3, -- Dato a escribir en el banco de registros   
    We3 => sigRegWrite2 -- Habilitacion de escritura en registro
  );
 
-- Instancia de alu_control
  miALUControl : alu_control
  port map (
	 ALUOp => sigALUOp,
	 Funct => sigInstruccion(5 downto 0),
	 ALUControl => sigALUControl
  );
 
-- Instancia de alu
  miAlu : alu
  port map(
	  OpA => sigData1, 
    OpB => sigOpB,  
    Control => sigALUControl,
    Result => sigALUResultado, 
    ZFlag => sigZFlag  
  );
  
 -- Instancia de control_unit
  miUnidadDeControl : control_unit
  port map (
   OpCode => sigInstruccion(31 downto 26),
  	ALUSrc => sigALUSrc,
	 ALUOp => sigALUOp,
	 RegWrite => sigRegWrite1,
	 MemtoReg => sigMemToReg,
	 MemWrite => sigMemWrite1,
	 MemRead => sigMemRead,
	 Branch => sigBranch,
	 RegDst => sigRegDst,
	 J => sigJ
  );
 
 
  -- Gestion del PC
	process(Clk, Reset)
	 begin
		if Reset = '1' then 
		  sigPC <= (others => '0');
		elsif (rising_edge(Clk)) then
		  sigPC <= sigPCNext;
		end if;
	end process; 
	 
	sigPCNext <= sigMultiplexorJ;
	IAddr <= sigPC;
	
 
 -- Seniales con el codigo de la instruccion
	sigInstruccion <= IDataIn;
	 
	-- Extension de signo (Instruccion 15-0)
	sigSignoExtendido <= sigInstruccion(15)&sigInstruccion(15)&sigInstruccion(15)&sigInstruccion(15)&
	sigInstruccion(15)&sigInstruccion(15)&sigInstruccion(15)&sigInstruccion(15)&sigInstruccion(15)&
	sigInstruccion(15)&sigInstruccion(15)&sigInstruccion(15)&sigInstruccion(15)&sigInstruccion(15)&
	sigInstruccion(15)&sigInstruccion(15)&sigInstruccion(15 downto 0);
	 
	-- Multiplexor WR (Instruccion 20-16 o 15-11)
	sigA3 <= sigInstruccion(15 downto 11) when sigRegDst = '1' else 
		   sigInstruccion(20 downto 16);
	 

 -- Sumador del PC
  sigPCMas4 <= sigPC + 4;
	
	-- Multiplexor del segundo dato de la ALU 
	sigOpB <= sigSignoExtendido when sigALUSrc = '1' else
		   sigData2;
	
 
 -- Seniales con conexion a la memoria de datos
	sigDataMem <= DDataIn;
	
	-- Activar escritura en memoria
	DWrEn <= sigMemWrite2;
	
	-- Activar lectura en memoria
	DRdEn <= sigMemRead;
	
	-- Entrada direccion de memoria del dato a leer
	DAddr <= sigALUResultado;
	
	-- Entrada dato a escribir en memoria
	DDataOut <= sigData2;
	
	-- Multiplexor dato leido memoria o calculado en ALU
	sigWd3 <= sigDataMem when sigMemToReg = '1' else
			  sigALUResultado;

-- Seniales para calculo de saltos
	-- Shift left 2 (Primero)
  sigShiftLeft1 <= sigSignoExtendido(29 downto 0) & "00";
	
	-- Shift left 2 (Segundo)
  sigShiftLeft2 <= sigInstruccion(25 downto 0) & "00";
	
	-- Puerta AND entre entre el Branch y la flag Z
	sigAND <= sigZFlag AND sigBranch;
	
	-- Calculo del valor del salto
	sigSalto <= sigPCMas4(31 downto 28) & sigShiftLeft2; 
	
	-- Sumador de la señal PC+4 y el desplazamiento anterior
	sigResSumador <= sigPCMas4 + sigShiftLeft1;
	
	-- Multiplexor controlado por la AND (Branch and Z)
	sigMultiplexorBranch <= sigResSumador when sigAND = '1' else 
							sigPCMas4;
							
	-- Multiplexor controlado por la J
	sigMultiplexorJ <= sigSalto when sigJ = '1' else 
					   sigMultiplexorBranch;

-- Tenemos en cuenta la instruccion NOP aqui (0 en enables de escritura)
  sigRegWrite2 <= '0' when sigInstruccion = x"00000000" else
               sigRegWrite1;
  sigMemWrite2 <= '0' when sigInstruccion = x"00000000" else
               sigMemWrite1;

end rtl;
