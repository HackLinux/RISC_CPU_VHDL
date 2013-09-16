library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use ieee.std_logic_textio.all;


entity ALU_tb  is

end entity ALU_tb;

architecture ALU_tb_arc of ALU_tb is

	component ALU is

   port (
      opcode       : in  std_logic_vector (5 downto 0);
	  SRC1_in      : in  std_logic_vector (31 downto 0);
	  SRC2_in      : in  std_logic_vector (31 downto 0);
	  JMP32_in     : in  std_logic_vector (31 downto 0);
	  IMM32_in     : in  std_logic_vector (31 downto 0);
	  RES32_out    : out std_logic_vector (31 downto 0); -- ALU's result to data memory and BOR
	  flag_reg_upd : out std_logic_vector (31 downto 0); -- updating flag register - R31 in BOR
	  FP_DST_in    : in std_logic_vector (4 downto 0); -- register in fp bank data is written to 
	  clk          : in std_logic;
	  rst          : in std_logic;
      div_done     : in std_logic                      -- from pipeline controller
      );
	  
    end component ALU;
	  
		signal opcode_in_sig     :  std_logic_vector (5 downto 0);
		signal SRC1_in_sig       :  std_logic_vector (31 downto 0); 
		signal SRC2_in_sig       :  std_logic_vector (31 downto 0); 
		signal JMP32_in_sig       :  std_logic_vector (31 downto 0);
		signal IMM32_in_sig       :  std_logic_vector (31 downto 0);		
		signal RES32_out_sig     :  std_logic_vector (31 downto 0); 
		signal flag_reg_upd_sig  :  std_logic_vector (31 downto 0);  
		signal FP_DST_in_sig     :  std_logic_vector (4 downto 0);  
		signal clk               :  std_logic := '0' ; --clock start
		signal rst               :  std_logic  := '1';
		signal div_done_sig      :  std_logic := '1' ;  
		
 
	  begin
	  
	  DUT : ALU
	  port map (
			opcode       => opcode_in_sig ,   
			SRC1_in      => SRC1_in_sig ,  
			SRC2_in      => SRC2_in_sig ,
			JMP32_in     => JMP32_in_sig ,    
			IMM32_in     => IMM32_in_sig ,    
			RES32_out    => RES32_out_sig ,  
			flag_reg_upd => flag_reg_upd_sig,
			FP_DST_in    => FP_DST_in_sig, 
			clk          => clk ,       
			rst          => rst,        
			div_done     => div_done_sig                   
			);
			
		  

			clk <= not clk after 50 ns ;
			
			 
			rst <= --'1' , --system reset
			'0' after 10 ns;
			
			
			---------------------------------
			-- read opcodes from file 
			---------------------------------
			process is
			  file opcode_file : text; --bit_vector_file open read_mode is "C:/sim/opcodes_in_binary.txt";
			  variable ln : line;
			  variable input_opcode : bit_vector(5 downto 0);
			  variable good : boolean;
			  
		  begin
		     file_open(opcode_file, "C:/sim/opcodes_in_binary.txt", read_mode);
			   wait for 100 ns;
			   assert(false)
			     report "Input file opened"
			   severity note;
			    
			   --for i in 0 to 63 loop
			   while not endfile(opcode_file) loop
			     readline(opcode_file, ln);
			     read(ln, input_opcode, good);
			     next when not good;
			     wait for 100 ns;		
			     -- opcode_in_sig <= "100101" ; --add fpi
			     opcode_in_sig <= to_stdlogicvector(input_opcode);
			     SRC1_in_sig <= x"3eaaaaab"; --value 1/3
			     SRC2_in_sig <= x"3eaaaaab"; --value 1/3
			     JMP32_in_sig <= x"00000008";
			     IMM32_in_sig <= x"00000010";
			     FP_DST_in_sig <= "00011";
			   end loop;
			    
			   file_close(opcode_file);
			   assert(false)
			     report "Input file closed"
			   severity note;
			   wait;
			end process;
			
			
end architecture ALU_tb_arc;
			
	  
	   
	  

  