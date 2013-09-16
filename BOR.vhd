library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity BOR is
   port (
      data_in      : in  std_logic_vector (31 downto 0);
      WR           : in  std_logic_vector (4 downto 0);  -- register in BOR data is written to
      RS1          : in  std_logic_vector (4 downto 0);  -- register in BOR data is read from
      RS2          : in  std_logic_vector (4 downto 0);  -- register in BOR data is read from
      RS1_fd       : in  std_logic;  -- data forwarding enable , hazard elimination
      RS2_fd       : in  std_logic;  -- data forwarding enable , hazard elimination
      data_out_1   : out std_logic_vector (31 downto 0);
      data_out_2   : out std_logic_vector (31 downto 0);
	  ALU_flag_upd : in std_logic_vector (31 downto 0);
	  ALU_data_in  : in std_logic_vector (31 downto 0); --ALU's result to DST register
	  clk          : in std_logic;
	  rst          : in std_logic
      );
end entity BOR;

architecture BOR_arc of BOR is
   type reg_bank is array(0 to 31) of std_logic_vector(31 downto 0);

   signal rbank : reg_bank; -- 32 registers of 32bit 

begin
	process (clk,rst) is
	  begin
		if (rst = '1') then -- resetting the array
			rbank <= (others=>(others => '0'));
			data_out_1 <=(others=>'0');
			data_out_2 <=(others=>'0');
	    elsif rising_edge(clk) then	
	      rbank(conv_integer(WR)) <= data_in;	
		  if (RS1_fd = '1') then 
		  	data_out_1 <= data_in; -- data forwarding 
		  else
		  	data_out_1 <= rbank(conv_integer(RS1)); 
		  end if;	
		  if (RS2_fd = '1') then 
		  	data_out_2 <= data_in; -- data forwarding
		  else  
		  	data_out_2 <= rbank(conv_integer(RS2));
	    end if;		
		end if;
		rbank(conv_integer(WR)) <= ALU_data_in; --updating DST register with ALU's result
		rbank(31) <=  ALU_flag_upd ; -- updating flag register - R31 by ALU
	end process;
end architecture BOR_arc;


