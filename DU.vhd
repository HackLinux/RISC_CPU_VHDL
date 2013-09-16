library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity DU is

	
   port (
      instruction_in : in  std_logic_vector (31 downto 0);
      opcode         : out std_logic_vector (5 downto 0); -- connects to ALU via register
	  opcode_direct  : out std_logic_vector (5 downto 0); -- connects to pipeline controller, no register
      imm            : out std_logic_vector (31 downto 0); 
      jmp            : out std_logic_vector (31 downto 0);  
      SRC1           : out std_logic_vector (4 downto 0);  
      SRC2           : out std_logic_vector (4 downto 0); 
      DST            : out std_logic_vector (4 downto 0); -- connects to bor AND ALU (for fpu)
	  clk            : in std_logic;
	  rst            : in std_logic
      );
	  
end entity DU;

architecture DU_arc of DU is
  signal opcode_sig : std_logic_vector(5 downto 0);

begin   
    opcode_direct <= instruction_in(31 downto 26); -- opcode transfer to pipeline controller
	process (clk,rst) is
	  begin
		if (rst = '1') then -- resetting outputs , opcode 000000 = "nop" 
			opcode<= (others => '0'); 
			imm <= (others => '0');
			jmp <= (others => '0');
			SRC1 <= (others => '0');
			SRC2 <= (others => '0');
			DST <= (others => '0');
			opcode_sig <= (others => '0');
		elsif rising_edge(clk) then
			opcode <= instruction_in(31 downto 26);
			DST <= instruction_in(25 downto 21);
			opcode_sig <= instruction_in(31 downto 26);
			case opcode_sig is
			when "000001" | "000010" | "000100" | "000101" | "000110" | "000111" | "001000" | "001001" | "001010" | 
			     "001011" | "001100" | "001101" | "001110" | "001111" 
				 =>  SRC1 <= instruction_in(20 downto 16); -- CMD_3_REGS 
					 SRC2 <= instruction_in(15 downto 11); 	 
		    when "010000" | "010001" | "010010" | "010011" | "010100" | "010101" | "010110" | "010111" | "011000" |
				 "011001" | "011010" | "111100" 
				 =>  SRC1 <= instruction_in(20 downto 16); -- CMD_2_REGS
			when "011011" | "011100" | "011101" | "011110" | "011111" | "100000" | "100001" | "100010" | "100011" |
				 "100100" | "100101" | "100110" | "100111" | "101000" | "101001" 
				 => SRC1 <= instruction_in(20 downto 16); -- CMD_2_REGS_IMM
					imm(15 downto 0 ) <= instruction_in(15 downto 0); -- imm max size limited to 16bit  by binary code
					imm(31 downto 16) <= (others => instruction_in(15)); -- sign extension
			when "111000"  | "110010" | "110011" | "110100" | "110101" | "110110" | "110111"   
				 => imm(20 downto 0) <= instruction_in(20 downto 0);  -- CMD_REG_IMM shift/rotate values limited to 21bit by binary code
					imm(31 downto 21) <=(others=>'0');	 
					SRC1 <= instruction_in(25 downto 21); -- instruction with single register, transferring DST to ALU in SRC1 line
			 when "101010" | "101011" | "101100" | "101101" | "101110" | "101111" | "110000" | "111111"
				 => imm(9 downto 0) <= instruction_in(25 downto 16); -- GOTO instruction memory address limited to 1024=10bit
			 when "111001" | "111010" | "110001" 
				=> imm(9 downto 0) <= instruction_in(20 downto 11); --ldm stm jmpr data memory address limited to 1024=10bit 
				   imm(31 downto 21) <= (others=>'0');
			 when others => null ;
			end case;
		 
		end if;
	end process;

end architecture DU_arc;


