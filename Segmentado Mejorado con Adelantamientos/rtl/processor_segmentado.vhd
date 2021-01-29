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
	
  -- Seniales del procesador de P1
  signal sigPCNext : std_logic_vector(31 downto 0); -- Senial auxiliar con el valor del PC siguiente
  signal sigPC : std_logic_vector(31 downto 0); -- Senial auxiliar con el valor del PC actual
  signal sigWd3 : std_logic_vector(31 downto 0); -- Senial auxiliar conectada al dato para escribir en banco de registros
  signal sigALUControl : std_logic_vector(3 downto 0); -- Senial auxiliar con la operacion a realizar en la ALU
  signal sigShiftLeft1 : std_logic_vector(31 downto 0); -- Senial auxiliar del primer desplazamiento a la izquierda
  signal sigShiftLeft2 : std_logic_vector(27 downto 0); -- Senial auxiliar del segundo desplazamiento a la izquierda
  signal sigMultiplexorBranch : std_logic_vector(31 downto 0); -- Seniales auxiliares con el valor de los multiplexores de salto y del branch
  signal sigAND : std_logic; -- Senial auxiliar con el valor de la puerta AND
  signal sigOpB : std_logic_vector(31 downto 0); -- Senial auxiliar con el segundo valor que entra en la ALU
  signal sigEnable_IF_ID, sigEnable_ID_EX, sigEnable_EX_MEM, sigEnable_MEM_WB, sigEnable_PC : std_logic; -- Senial auxiliar de los enables de los pipes 
  signal sigInstruccion_IF, sigInstruccion_ID, sigInstruccion_EX : std_logic_vector(31 downto 0); -- Seniales auxiliares con la instruccion leida de la memoria de instrucciones
  signal sigPCMas4_IF, sigPCMas4_ID : std_logic_vector(31 downto 0); -- Seniales auxiliares con el valor del PC + 4 en el pipe IF/ID y ID/EX
  signal sigData1_ID, sigData1_EX : std_logic_vector(31 downto 0); -- Seniales auxiliares con el dato del registro 1 en el pipe ID/EX
  signal sigData2_ID, sigData2_EX, sigData2_MEM : std_logic_vector(31 downto 0); -- Seniales auxiliares con el dato del registro 2 en el pipe ID/EX y EX/MEM
  signal sigSignoExtendido_ID, sigSignoExtendido_EX : std_logic_vector(31 downto 0); -- Seniales auxiliares con la instruccion extendida 16 bits en el pipe ID/EX
  signal sigALUSrc_ID, sigRegWrite_ID1, sigRegWrite_ID2, sigMemToReg_ID, sigMemWrite_ID1, sigMemWrite_ID2, sigMemRead_ID, sigBranch_ID, sigRegDst_ID : std_logic; -- Seniales auxiliares de la unidad de control en el pipe ID/EX
  signal sigALUSrc_EX, sigRegWrite_EX, sigMemToReg_EX, sigMemWrite_EX, sigMemRead_EX, sigRegDst_EX : std_logic; -- Seniales auxiliares de la unidad de control en el pipe ID/EX
  signal sigRegWrite_MEM, sigMemToReg_MEM, sigMemWrite_MEM, sigMemRead_MEM : std_logic; -- Seniales auxiliares de la unidad de control en el pipe EX/MEM
  signal sigRegWrite_WB, sigMemToReg_WB : std_logic; -- Seniales auxiliares de la unidad de control en el pipe MEM/WB
  signal sigALUOp_ID, sigALUOp_EX : std_logic_vector(2 downto 0); -- Seniales auxiliares de ALUControl de la unidad de control en el pipe ID/EX
  signal sigResSumador_ID : std_logic_vector(31 downto 0); -- Seniales auxiliares con el resultado del sumador para las nuevas direcciones en el pipe EX/MEM
  signal sigIns1_ID, sigIns1_EX : std_logic_vector(20 downto 16); -- Seniales auxiliares con la instruccion 20-16 en el pipe ID/EX
  signal sigIns2_ID, sigIns2_EX : std_logic_vector(15 downto 11); -- Seniales auxiliares con la instruccion 15-11 en el pipe ID/EX
  signal sigA3_EX, sigA3_MEM, sigA3_WB : std_logic_vector(4 downto 0); -- Seniales auxiliares con el valor del multiplexor con la direccion del registro a escribir
  signal sigZFlag : std_logic; -- Senial auxiliar con el valor de la bandera Z en el pipe EX/MEM
  signal sigALUResultado_EX, sigALUResultado_MEM, sigALUResultado_WB : std_logic_vector(31 downto 0); -- Senial auxiliar con el resultado de la ALU en el pipe EX/MEM
  signal sigDataMem_MEM, sigDataMem_WB : std_logic_vector(31 downto 0); -- Seniales auxiliares con el dato leido de la memoria de datos en el pipe MEM/WB
  signal sigJ_ID: std_logic; -- Seniales auxiliares para la senial del salto de la unidad de control
  signal sigSaltoJ_ID: std_logic_vector(31 downto 0); -- Seniales con la direccion del salto J
  signal sigMultiplexorJ: std_logic_vector(31 downto 0); -- Senial auxiliar con el dato del salto J o el dato del multiplexor Branch
  
  -- Seniales del forwarding unit
  signal sigMuxFU1: std_logic_vector(1 downto 0); -- Senial que sale del Forwarding Unit hacia el multiplexor 1 
  signal sigMuxFU2: std_logic_vector(1 downto 0); -- Senial que sale del Forwarding Unit hacia el multiplexor 2
  signal sigResMuxFU1: std_logic_vector(31 downto 0); -- Senial que sale del multiplexor 1 
  signal sigResMuxFU2: std_logic_vector(31 downto 0); -- Senial que sale del multiplexor 2
  
  -- Seniales del hazard detection unit 
  signal sigMuxHU: std_logic_vector(10 downto 0); -- Senial que entra con los valores del control unit al multiplexor controlado por el Hazard Unit
  signal sigResMuxHU: std_logic_vector(10 downto 0); -- Senial resultante del multiplexor controlado por el Hazard Unit
  signal sigControlMuxHU: std_logic; -- Senial que controla el multiplexor del Hazard Unit
  signal sigZComp: std_logic; -- Senial que entra en la AND del Branch que sale del comparador de registros
  
begin   


-- Instancia de reg_bank
  miBancoReg : reg_bank
  port map (
	Clk => Clk,
	Reset => Reset,
	A1 => sigInstruccion_ID(25 downto 21), -- Entrada direccion del registro 1 (Instruccion 25-21)  
    Rd1 => sigData1_ID, -- Dato leido del registro 1
    A2 => sigInstruccion_ID(20 downto 16), -- Entrada direccion del registro 2 (Instruccion 20-16)   
    Rd2 => sigData2_ID, -- Dato leido del registro 2
    A3 => sigA3_WB, -- Dato con la direccion del registro a escribir 
    Wd3 => sigWd3, -- Dato a escribir en el banco de registros   
    We3 => sigRegWrite_WB -- Habilitacion de escritura en registro
  );
 
-- Instancia de alu_control
  miALUControl : alu_control
  port map (
	 ALUOp => sigALUOp_EX,
	 Funct => sigSignoExtendido_EX(5 downto 0),
	 ALUControl => sigALUControl
  );
 
-- Instancia de alu
  miAlu : alu
  port map(
	OpA => sigResMuxFU1, 
    OpB => sigOpB,  
    Control => sigALUControl,
    Result => sigALUResultado_EX, 
    ZFlag => sigZFlag  
  );
  
 -- Instancia de control_unit
  miUnidadDeControl : control_unit
  port map (
    OpCode => sigInstruccion_ID(31 downto 26),
  	ALUSrc => sigMuxHU(0),
	 ALUOp => sigMuxHU(3 downto 1),
	 RegWrite => sigMuxHU(4),
	 MemtoReg => sigMuxHU(5),
	 MemWrite => sigMuxHU(6),
	 MemRead => sigMuxHU(7),
	 Branch => sigMuxHU(8),
	 RegDst => sigMuxHU(9),
	 J => sigMuxHU(10)
  );
 
  -- Pipe IF/ID
  process(Clk, Reset)
		begin
			if Reset = '1' then
				sigPCMas4_ID <= (others => '0');
				sigInstruccion_ID <= (others =>'0');
			elsif(rising_edge(Clk) and sigEnable_IF_ID = '1') then
				sigPCMas4_ID <= sigPCMas4_IF;
				sigInstruccion_ID <= sigInstruccion_IF;
			end if;
  end process;
	
  -- Pipe ID/EX
  process(Clk,Reset)
		begin
			if Reset = '1' then
				sigALUSrc_EX   <= '0';
				sigRegWrite_EX <= '0';
				sigMemToReg_EX <= '0';
				sigMemWrite_EX <= '0';
				sigMemRead_EX  <= '0';
				sigRegDst_EX   <= '0';
				sigALUOp_EX    <= (others => '0');
				sigData1_EX    <= (others => '0');
				sigData2_EX    <= (others => '0');
				sigSignoExtendido_EX <= (others => '0');
				sigIns1_EX     <= (others => '0');
				sigIns2_EX     <= (others => '0');
				sigInstruccion_EX <= (others => '0');
			elsif (rising_edge(Clk) and sigEnable_ID_EX = '1') then
				sigALUSrc_EX   <= sigALUSrc_ID;
				sigRegWrite_EX <= sigRegWrite_ID2;
				sigMemToReg_EX <= sigMemToReg_ID;
				sigMemWrite_EX <= sigMemWrite_ID2;
				sigMemRead_EX  <= sigMemRead_ID;
				sigRegDst_EX   <= sigRegDst_ID;
				sigALUOp_EX    <= sigALUOp_ID;
				sigData1_EX    <= sigData1_ID;
				sigData2_EX    <= sigData2_ID;
				sigSignoExtendido_EX <= sigSignoExtendido_ID;
				sigIns1_EX     <= sigIns1_ID;
				sigIns2_EX     <= sigIns2_ID;
				sigInstruccion_EX <= sigInstruccion_ID;				
			end if;		
	end process;
	
  -- Pipe EX/MEM
  process(Clk,Reset)
		begin
			if Reset = '1' then
				sigRegWrite_MEM     <= '0';
				sigMemToReg_MEM     <= '0';
				sigMemWrite_MEM     <= '0';
				sigMemRead_MEM      <= '0';	
				sigALUResultado_MEM <= (others => '0');	
				sigA3_MEM           <= (others => '0');
				sigData2_MEM        <= (others => '0');					
			elsif (rising_edge(Clk) and sigEnable_EX_MEM = '1') then
				sigRegWrite_MEM	    <= sigRegWrite_EX;
				sigMemToReg_MEM     <= sigMemToReg_EX;
				sigMemWrite_MEM     <= sigMemWrite_EX;
				sigMemRead_MEM      <= sigMemRead_EX;					
				sigALUResultado_MEM <= sigALUResultado_EX;	
				sigA3_MEM           <= sigA3_EX;
				sigData2_MEM        <= sigResMuxFU2;	
			end if;		
	end process;
	
  -- Pipe MEM/WB
    process(Clk,Reset)
		begin
			if Reset = '1' then
				sigRegWrite_WB     <= '0';
				sigMemToReg_WB     <= '0';
				sigDataMem_WB      <= (others => '0');
				sigALUResultado_WB <= (others => '0');	
				sigA3_WB           <= (others => '0');	 
			elsif (rising_edge(Clk) and sigEnable_EX_MEM = '1') then
				sigRegWrite_WB	   <= sigRegWrite_MEM;
				sigMemToReg_WB     <= sigMemToReg_MEM;	
				sigDataMem_WB      <= sigDataMem_MEM;
				sigALUResultado_WB <= sigALUResultado_MEM;
				sigA3_WB           <= sigA3_MEM;
			end if;		
	end process;
	
	-- Componente Forwanding Unit 

	sigMuxFU1 <= "10"when ((sigRegWrite_MEM = '1') and (sigA3_MEM /= "00000") and (sigA3_MEM = sigInstruccion_EX(25 downto 21))) else 
				"01" when ((sigRegWrite_WB = '1') and (sigA3_WB /= "00000") 
							and not ((sigRegWrite_MEM = '1') and (sigA3_MEM = sigInstruccion_EX(25 downto 21))) 
							and (sigA3_WB = sigInstruccion_EX(25 downto 21))) else
				"00";
	
	sigMuxFU2 <= "10"when ((sigRegWrite_MEM = '1') and (sigA3_MEM /= "00000") and (sigA3_MEM = sigIns1_EX)) else
				"01"when  ((sigRegWrite_WB = '1') and (sigA3_WB /= "00000") 
							and not ((sigRegWrite_MEM = '1') and (sigA3_MEM = sigIns1_EX)) 
							and (sigA3_WB = sigIns1_EX)) else
				"00";
					

  
  -- Componente Hazard Detection Unit
	SigControlMuxHU <= '0' when (((sigMemRead_EX = '1') and ((sigIns1_EX = sigInstruccion_ID(25 downto 21)) or (sigIns1_EX = sigIns1_ID)))) else				          
					            '1';
	SigEnable_IF_ID <= '0' when ((sigMemRead_EX = '1') and ((sigIns1_EX = sigInstruccion_ID(25 downto 21)) or (sigIns1_EX = sigIns1_ID))) else
					            '1';
	SigEnable_PC    <= '0' when ((sigMemRead_EX = '1') and ((sigIns1_EX = sigInstruccion_ID(25 downto 21)) or (sigIns1_EX = sigIns1_ID))) else				            
					            '1';
					
	

  -- Enables que valen 1 siempre
 	sigEnable_ID_EX  <= '1'; 
	sigEnable_EX_MEM <= '1'; 
	sigEnable_MEM_WB <= '1';
	
  -- Gestion del PC
	process(Clk, Reset)
	 begin
		if Reset = '1' then 
		  sigPC <= (others => '0');
		elsif (rising_edge(Clk) and sigEnable_PC = '1') then
		  sigPC <= sigPCNext;
		end if;
	end process; 
	 
	sigPCNext <= sigMultiplexorJ;
	IAddr <= sigPC;
	
	
 
 -- Seniales con el codigo de la instruccion
	sigInstruccion_IF <= IDataIn;
	sigIns1_ID <= sigInstruccion_ID(20 downto 16);
	sigIns2_ID <= sigInstruccion_ID(15 downto 11);
	 
	-- Extension de signo (Instruccion 15-0)
	sigSignoExtendido_ID <= sigInstruccion_ID(15)&sigInstruccion_ID(15)&sigInstruccion_ID(15)&sigInstruccion_ID(15)&
	sigInstruccion_ID(15)&sigInstruccion_ID(15)&sigInstruccion_ID(15)&sigInstruccion_ID(15)&sigInstruccion_ID(15)&
	sigInstruccion_ID(15)&sigInstruccion_ID(15)&sigInstruccion_ID(15)&sigInstruccion_ID(15)&sigInstruccion_ID(15)&
	sigInstruccion_ID(15)&sigInstruccion_ID(15)&sigInstruccion_ID(15 downto 0);
	 
	-- Multiplexor WR (Instruccion 20-16 o 15-11)
	sigA3_EX <= sigIns2_EX when sigRegDst_EX = '1' else 
		   sigIns1_EX;
	 

 -- Sumador del PC
  sigPCMas4_IF <= sigPC + 4;
	
-- Multiplexor del segundo dato de la ALU 
    sigOpB <= sigSignoExtendido_EX when sigALUSrc_EX = '1' else
		   sigResMuxFU2;
	
 
 -- Seniales con conexion a la memoria de datos
	sigDataMem_MEM <= DDataIn;
	
	-- Activar escritura en memoria
	DWrEn <= sigMemWrite_MEM;
	
	-- Activar lectura en memoria
	DRdEn <= sigMemRead_MEM;
	
	-- Entrada direccion de memoria del dato a leer
	DAddr <= sigALUResultado_MEM;
	
	-- Entrada dato a escribir en memoria
	DDataOut <= sigData2_MEM;
	
	-- Multiplexor dato leido memoria o calculado en ALU
	sigWd3 <= sigDataMem_WB when sigMemToReg_WB = '1' else
			  sigALUResultado_WB;


-- Seniales para calculo de saltos
	-- Shift left 2 (Primero)
    sigShiftLeft1 <= sigSignoExtendido_ID(29 downto 0) & "00";
	
	-- Sumador de la señal PC+4 y el desplazamiento anterior
	sigResSumador_ID <= sigPCMas4_ID + sigShiftLeft1;
	
	-- Puerta AND entre entre el Branch y la flag Z
	sigAND <= sigZComp AND sigBranch_ID;
	
	-- Multiplexor controlado por la AND (Branch and Z)
	sigMultiplexorBranch <= sigResSumador_ID when sigAND = '1' else 
							sigPCMas4_IF;
							
	-- Desplazamiento izquierda de la instruccion (J)	
	sigShiftLeft2 <= sigInstruccion_ID(25 downto 0) & "00";
	
	-- Calculo de la direccion del salto J
	sigSaltoJ_ID <= sigPCMas4_ID(31 downto 28) & sigShiftLeft2;
	
	-- Multiplexor controlado por la J
	sigMultiplexorJ <= sigSaltoJ_ID when sigJ_ID = '1' else
					   sigMultiplexorBranch;

-- Tenemos en cuenta la instruccion NOP aqui (0 en enables de escritura)
  sigRegWrite_ID2 <= '0' when sigInstruccion_ID = x"00000000" else
               sigRegWrite_ID1;
  sigMemWrite_ID2 <= '0' when sigInstruccion_ID = x"00000000" else
               sigMemWrite_ID1;						
			
			
--Multiplexores controlados por la Forwanding Unit
  -- 1
  sigResMuxFU1 <= sigData1_EX          when sigMuxFU1 = "00" else
				          sigWd3               when sigMuxFU1 = "01" else
				          sigALUResultado_MEM  when sigMuxFU1 = "10" else
				          x"00000000";
  -- 2
  sigResMuxFU2 <= sigData2_EX          when sigMuxFU2 = "00" else
				          sigWd3               when sigMuxFU2 = "01" else
				          sigALUResultado_MEM  when sigMuxFU2 = "10" else
				          x"00000000";
				  
				  
--Multiplexor controlado por el Hazard Unit
  sigResMuxHU <= "00000000000" when sigControlMuxHU = '0' else
				 sigMuxHU;			  
			  
-- Asignamos los bits que salen del multiplexor anterior a las seniales del control unit en la etapa ID
  sigALUSrc_ID <= SigResMuxHU(0);
  sigALUOp_ID <= SigResMuxHU(3 downto 1);
  sigRegWrite_ID1 <= SigResMuxHU(4);  
  sigMemToReg_ID <= SigResMuxHU(5); 
  sigMemWrite_ID1 <= SigResMuxHU(6); 
  sigMemRead_ID <= SigResMuxHU(7); 
  sigBranch_ID <= SigResMuxHU(8);
  sigRegDst_ID <= SigResMuxHU(9);
  sigJ_ID <= SigResMuxHU(10);
  
  
-- Comparador de registros
  sigZComp <= '1' when sigData1_ID = sigData2_ID else
			  '0';	
  
end rtl;
