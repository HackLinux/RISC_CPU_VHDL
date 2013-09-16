library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
--use IEEE.NUMERIC_STD.ALL;
library work;
--library ieee_proposed;
use work.inst_pack.all;
use work.fixed_float_types.all;
use work.float_pkg.all;
--use work.fixed_pkg.all;
library lpm; 
USE lpm.lpm_components.all;

entity alu is

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
	  
end entity ALU;

architecture ALU_arc of ALU is

type fpu_reg_bank is array(0 to 7) of std_logic_vector(31 downto 0);  

component LPM_DIVIDE is
        generic (LPM_WIDTHN : natural;    -- MUST be greater than 0 <TODO> prevent division by 0
                 LPM_WIDTHD : natural;    -- MUST be greater than 0
				 LPM_NREPRESENTATION : string := "UNSIGNED";
				 LPM_DREPRESENTATION : string := "UNSIGNED";
                 LPM_PIPELINE : natural := 0;
				 LPM_TYPE : string := L_DIVIDE;
				 LPM_HINT : string := "UNUSED");
		port (NUMER : in std_logic_vector(LPM_WIDTHN-1 downto 0);
			  DENOM : in std_logic_vector(LPM_WIDTHD-1 downto 0);
			  ACLR : in std_logic := '0';
			  CLOCK : in std_logic := '0';
			  CLKEN : in std_logic := '1';
			  QUOTIENT : out std_logic_vector(LPM_WIDTHN-1 downto 0);
			  REMAIN : out std_logic_vector(LPM_WIDTHD-1 downto 0));
end component;

signal fpbank : fpu_reg_bank; -- fpu registers
signal remain0 : std_logic_vector(31 downto 0); -- signal for div operation remain 
signal remain1 : std_logic_vector(31 downto 0); -- signal for div operation remain 
signal temp_div0 : std_logic_vector(31 downto 0);
signal temp_div1 : std_logic_vector(31 downto 0);
signal afp, bfp : float32 ; -- signals for fp operations
begin

     div_cmp0: LPM_DIVIDE --for div operation
        generic map (LPM_WIDTHN =>32,
                 LPM_WIDTHD =>32,
				 LPM_NREPRESENTATION => "SIGNED",
				 LPM_DREPRESENTATION => "SIGNED",
                 LPM_PIPELINE => 32,
				 LPM_TYPE => L_DIVIDE,
				 LPM_HINT => "UNUSED")
		port map (NUMER => SRC1_in,
			  DENOM => SRC2_in,
			  ACLR =>rst,
			  CLOCK =>clk,
			  CLKEN => '1',
			  QUOTIENT => temp_div0,
			  REMAIN => remain0
			  );
	  div_cmp1: LPM_DIVIDE --for divi operation
        generic map (LPM_WIDTHN =>32,
                 LPM_WIDTHD =>32,
				 LPM_NREPRESENTATION => "SIGNED",
				 LPM_DREPRESENTATION => "SIGNED",
                 LPM_PIPELINE => 32,
				 LPM_TYPE => L_DIVIDE,
				 LPM_HINT => "UNUSED")
		port map (NUMER => SRC1_in,
			  DENOM => IMM32_in,
			  ACLR =>rst,
			  CLOCK =>clk,
			  CLKEN => '1',
			  QUOTIENT => temp_div1,
			  REMAIN => remain1
			  );
	afp <= to_float (SRC1_in , afp); 
	bfp <= to_float (SRC2_in, bfp);
	process (clk,rst) is
	variable temp_Res : std_logic_vector(32 downto 0); --temp variable for overflow, 33bit
	variable temp_Res_mul : std_logic_vector(63 downto 0); --temp variable for overflow, 33bit
	begin
		if (rst = '1') then 
			RES32_out <= (others => '0'); 
			temp_Res := (others => '0');
			flag_reg_upd <= (others => '0');
			fpbank <= (others=>(others => '0'));
		elsif rising_edge(clk) then
			case opcode is
			
			when xor1 
			=> RES32_out <= SRC1_in xor SRC2_in ;
			when and1
			=> RES32_out <= SRC1_in and SRC2_in ; 
			when nxor1 
			=> RES32_out <= SRC1_in xnor SRC2_in ; 
			when nor1 
			=> RES32_out <= SRC1_in nor SRC2_in ;
			when nand1  
			=> RES32_out <= SRC1_in nand SRC2_in ;
			when add1 
			=> temp_Res := (SRC1_in(31) & SRC1_in)	+ (SRC2_in(31) & SRC2_in);
				RES32_out <= temp_Res(31 downto 0);
				if (temp_Res(32) = '1') then
				   flag_reg_upd(31) <= '1' ; -- add overflow flag
				end if;
			when sub1 
			=> temp_Res := (SRC1_in(31) & SRC1_in) - (SRC2_in(31) & SRC2_in);
				RES32_out <= temp_Res(31 downto 0);
				if (temp_Res(32) = '1') then
			flag_reg_upd(30) <= '1' ; -- sub underflow flag
			end if;
			when mul1 
			=> temp_Res_mul := SRC1_in * SRC2_in;
				RES32_out <= temp_Res_mul(31 downto 0);
				if (temp_Res_mul(63 downto 32) /= 0) then
					flag_reg_upd(29) <= '1' ; -- mul overflow flag
				end if;
			when div1 => if (div_done = '1') then
			                 RES32_out <= temp_div0 ;
				              if (remain0 /= 0) then 
									    flag_reg_upd(28) <= '1' ;
				              end if;
				           end if;	  		  
			when addfp1 
			=> fpbank(conv_integer(FP_DST_in)) <= to_slv(afp + bfp) ; 
			when subfp1 
			=>  fpbank(conv_integer(FP_DST_in)) <= to_slv(afp - bfp) ;
			when mulfp1 
			=> fpbank(conv_integer(FP_DST_in)) <= to_slv(afp * bfp) ; 
			when divfp1 
			=> fpbank(conv_integer(FP_DST_in)) <= to_slv(afp / bfp) ; 
			when cmpreg1 -- stores in DST the maximal value between SRC1 and SRC2
			=> if (SRC1_in > SRC2_in) then
				RES32_out <= SRC1_in;
				else RES32_out <= SRC2_in;
				end if;
			when not1    
			=> RES32_out <=  not SRC1_in ;
			when abs1 
			=> RES32_out <= '0' & SRC1_in(30 downto 0);
			when absfp1 
			=> fpbank(conv_integer(FP_DST_in)) <= to_slv(abs(to_float(SRC1_in)));
			when sllr1 => 
				case conv_integer(SRC2_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <= SRC1_in(30 downto 0) & '0';
					when 2  => RES32_out <= SRC1_in(29 downto 0) & "00";
					when 3  => RES32_out <= SRC1_in(28 downto 0) & "000";
					when 4  => RES32_out <= SRC1_in(27 downto 0) & "0000";
					when 5  => RES32_out <= SRC1_in(26 downto 0) & "00000";
					when 6  => RES32_out <= SRC1_in(25 downto 0) & "000000";
					when 7  => RES32_out <= SRC1_in(24 downto 0) & "0000000";
					when 8  => RES32_out <= SRC1_in(23 downto 0) & "00000000";
					when 9  => RES32_out <= SRC1_in(22 downto 0) & "000000000";
					when 10 => RES32_out <= SRC1_in(21 downto 0) & "0000000000";
					when 11 => RES32_out <= SRC1_in(20 downto 0) & "00000000000";
					when 12 => RES32_out <= SRC1_in(19 downto 0) & "000000000000";
					when 13 => RES32_out <= SRC1_in(18 downto 0) & "0000000000000";
					when 14 => RES32_out <= SRC1_in(17 downto 0) & "00000000000000";
					when 15 => RES32_out <= SRC1_in(16 downto 0) & "000000000000000";
					when 16 => RES32_out <= SRC1_in(15 downto 0) & "0000000000000000";
					when 17 => RES32_out <= SRC1_in(14 downto 0) & "00000000000000000";
					when 18 => RES32_out <= SRC1_in(13 downto 0) & "000000000000000000";
					when 19 => RES32_out <= SRC1_in(12 downto 0) & "0000000000000000000";
					when 20 => RES32_out <= SRC1_in(11 downto 0) & "00000000000000000000";
					when 21 => RES32_out <= SRC1_in(10 downto 0) & "000000000000000000000";
					when 22 => RES32_out <= SRC1_in( 9 downto 0) & "0000000000000000000000";
					when 23 => RES32_out <= SRC1_in( 8 downto 0) & "00000000000000000000000";
					when 24 => RES32_out <= SRC1_in( 7 downto 0) & "000000000000000000000000";
					when 25 => RES32_out <= SRC1_in( 6 downto 0) & "0000000000000000000000000";
					when 26 => RES32_out <= SRC1_in( 5 downto 0) & "00000000000000000000000000";
					when 27 => RES32_out <= SRC1_in( 4 downto 0) & "000000000000000000000000000";
					when 28 => RES32_out <= SRC1_in( 3 downto 0) & "0000000000000000000000000000";
					when 29 => RES32_out <= SRC1_in( 2 downto 0) & "00000000000000000000000000000";
					when 30 => RES32_out <= SRC1_in( 1 downto 0) & "000000000000000000000000000000";
					when 31 => RES32_out <= SRC1_in(0) & "0000000000000000000000000000000";
					when 32 => RES32_out <= (others=>'0');
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;	
			when slar1 =>
			case conv_integer(SRC2_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <= SRC1_in(31) & SRC1_in(29 downto 0) & '0';
					when 3  => RES32_out <= SRC1_in(31) & SRC1_in(28 downto 0) & "00";
					when 4  => RES32_out <= SRC1_in(31) & SRC1_in(27 downto 0) & "000";
					when 5  => RES32_out <= SRC1_in(31) & SRC1_in(26 downto 0) & "0000";
					when 6  => RES32_out <= SRC1_in(31) & SRC1_in(25 downto 0) & "00000";
					when 7  => RES32_out <= SRC1_in(31) & SRC1_in(24 downto 0) & "000000";
					when 8  => RES32_out <= SRC1_in(31) & SRC1_in(23 downto 0) & "0000000";
					when 9  => RES32_out <= SRC1_in(31) & SRC1_in(22 downto 0) & "00000000";
					when 10 => RES32_out <= SRC1_in(31) & SRC1_in(21 downto 0) & "000000000";
					when 11 => RES32_out <= SRC1_in(31) & SRC1_in(20 downto 0) & "0000000000";
					when 12 => RES32_out <= SRC1_in(31) & SRC1_in(19 downto 0) & "00000000000";
					when 13 => RES32_out <= SRC1_in(31) & SRC1_in(18 downto 0) & "000000000000";
					when 14 => RES32_out <= SRC1_in(31) & SRC1_in(17 downto 0) & "0000000000000";
					when 15 => RES32_out <= SRC1_in(31) & SRC1_in(16 downto 0) & "00000000000000";
					when 16 => RES32_out <= SRC1_in(31) & SRC1_in(15 downto 0) & "000000000000000";
					when 17 => RES32_out <= SRC1_in(31) & SRC1_in(14 downto 0) & "0000000000000000";
					when 18 => RES32_out <= SRC1_in(31) & SRC1_in(13 downto 0) & "00000000000000000";
					when 19 => RES32_out <= SRC1_in(31) & SRC1_in(12 downto 0) & "000000000000000000";
					when 20 => RES32_out <= SRC1_in(31) & SRC1_in(11 downto 0) & "0000000000000000000";
					when 21 => RES32_out <= SRC1_in(31) & SRC1_in(10 downto 0) & "00000000000000000000";
					when 22 => RES32_out <= SRC1_in(31) & SRC1_in( 9 downto 0) & "000000000000000000000";
					when 23 => RES32_out <= SRC1_in(31) & SRC1_in( 8 downto 0) & "0000000000000000000000";
					when 24 => RES32_out <= SRC1_in(31) & SRC1_in( 7 downto 0) & "00000000000000000000000";
					when 25 => RES32_out <= SRC1_in(31) & SRC1_in( 6 downto 0) & "000000000000000000000000";
					when 26 => RES32_out <= SRC1_in(31) & SRC1_in( 5 downto 0) & "0000000000000000000000000";
					when 27 => RES32_out <= SRC1_in(31) & SRC1_in( 4 downto 0) & "00000000000000000000000000";
					when 28 => RES32_out <= SRC1_in(31) & SRC1_in( 3 downto 0) & "000000000000000000000000000";
					when 29 => RES32_out <= SRC1_in(31) & SRC1_in( 2 downto 0) & "0000000000000000000000000000";
					when 30 => RES32_out <= SRC1_in(31) & SRC1_in( 1 downto 0) & "00000000000000000000000000000";
					when 31 => RES32_out <= SRC1_in(31) &                        "0000000000000000000000000000000";
					when 32 => RES32_out <= (others=>'0');
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;	
			when srlr1
			=> case conv_integer(SRC2_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <=  '0' & SRC1_in(31 downto 1) ;
					when 2  => RES32_out <= "00" & SRC1_in(31 downto 2) ;
					when 3  => RES32_out <= "000" & SRC1_in(31 downto 3) ;
					when 4  => RES32_out <= "0000" & SRC1_in(31 downto 4) ;
					when 5  => RES32_out <= "00000" & SRC1_in(31 downto 5) ;
					when 6  => RES32_out <= "000000" & SRC1_in(31 downto 6) ;
					when 7  => RES32_out <= "0000000" & SRC1_in(31 downto 7) ;
					when 8  => RES32_out <= "00000000" & SRC1_in(31 downto 8) ;
					when 9  => RES32_out <= "000000000" & SRC1_in(31 downto 9) ;
					when 10 => RES32_out <= "0000000000" & SRC1_in(31 downto 10) ;
					when 11 => RES32_out <= "00000000000" & SRC1_in(31 downto 11) ;
					when 12 => RES32_out <= "000000000000" & SRC1_in(31 downto 12) ;
					when 13 => RES32_out <= "0000000000000" & SRC1_in(31 downto 13) ;
					when 14 => RES32_out <= "00000000000000" & SRC1_in(31 downto 14) ;
					when 15 => RES32_out <= "000000000000000" & SRC1_in(31 downto 15) ;
					when 16 => RES32_out <= "0000000000000000" & SRC1_in(31 downto 16) ;
					when 17 => RES32_out <= "00000000000000000" & SRC1_in(31 downto 17) ;
					when 18 => RES32_out <= "000000000000000000" & SRC1_in(31 downto 18) ;
					when 19 => RES32_out <= "0000000000000000000" & SRC1_in(31 downto 19) ;
					when 20 => RES32_out <= "00000000000000000000" & SRC1_in(31 downto 20) ;
					when 21 => RES32_out <= "000000000000000000000" & SRC1_in(31 downto 21) ;
					when 22 => RES32_out <= "0000000000000000000000" & SRC1_in( 31 downto 22) ;
					when 23 => RES32_out <= "00000000000000000000000" & SRC1_in( 31 downto 23) ;
					when 24 => RES32_out <= "000000000000000000000000" & SRC1_in( 31 downto 24) ;
					when 25 => RES32_out <= "0000000000000000000000000" & SRC1_in( 31 downto 25) ;
					when 26 => RES32_out <= "00000000000000000000000000" & SRC1_in( 31 downto 26) ;
					when 27 => RES32_out <= "000000000000000000000000000" & SRC1_in( 31 downto 27) ;
					when 28 => RES32_out <= "0000000000000000000000000000" & SRC1_in( 31 downto 28) ;
					when 29 => RES32_out <= "00000000000000000000000000000" & SRC1_in( 31 downto 29) ;
					when 30 => RES32_out <= "000000000000000000000000000000" & SRC1_in( 31 downto 30) ;
					when 31 => RES32_out <= "0000000000000000000000000000000" & SRC1_in(31) ;
					when 32 => RES32_out <= (others=>'0');
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;
			when srar1  
			=>  if (SRC1_in(31)='0') then
			case conv_integer(SRC2_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <=  '0' & SRC1_in(31 downto 1) ;
					when 2  => RES32_out <= "00" & SRC1_in(31 downto 2) ;
					when 3  => RES32_out <= "000" & SRC1_in(31 downto 3) ;
					when 4  => RES32_out <= "0000" & SRC1_in(31 downto 4) ;
					when 5  => RES32_out <= "00000" & SRC1_in(31 downto 5) ;
					when 6  => RES32_out <= "000000" & SRC1_in(31 downto 6) ;
					when 7  => RES32_out <= "0000000" & SRC1_in(31 downto 7) ;
					when 8  => RES32_out <= "00000000" & SRC1_in(31 downto 8) ;
					when 9  => RES32_out <= "000000000" & SRC1_in(31 downto 9) ;
					when 10 => RES32_out <= "0000000000" & SRC1_in(31 downto 10) ;
					when 11 => RES32_out <= "00000000000" & SRC1_in(31 downto 11) ;
					when 12 => RES32_out <= "000000000000" & SRC1_in(31 downto 12) ;
					when 13 => RES32_out <= "0000000000000" & SRC1_in(31 downto 13) ;
					when 14 => RES32_out <= "00000000000000" & SRC1_in(31 downto 14) ;
					when 15 => RES32_out <= "000000000000000" & SRC1_in(31 downto 15) ;
					when 16 => RES32_out <= "0000000000000000" & SRC1_in(31 downto 16) ;
					when 17 => RES32_out <= "00000000000000000" & SRC1_in(31 downto 17) ;
					when 18 => RES32_out <= "000000000000000000" & SRC1_in(31 downto 18) ;
					when 19 => RES32_out <= "0000000000000000000" & SRC1_in(31 downto 19) ;
					when 20 => RES32_out <= "00000000000000000000" & SRC1_in(31 downto 20) ;
					when 21 => RES32_out <= "000000000000000000000" & SRC1_in(31 downto 21) ;
					when 22 => RES32_out <= "0000000000000000000000" & SRC1_in( 31 downto 22) ;
					when 23 => RES32_out <= "00000000000000000000000" & SRC1_in( 31 downto 23) ;
					when 24 => RES32_out <= "000000000000000000000000" & SRC1_in( 31 downto 24) ;
					when 25 => RES32_out <= "0000000000000000000000000" & SRC1_in( 31 downto 25) ;
					when 26 => RES32_out <= "00000000000000000000000000" & SRC1_in( 31 downto 26) ;
					when 27 => RES32_out <= "000000000000000000000000000" & SRC1_in( 31 downto 27) ;
					when 28 => RES32_out <= "0000000000000000000000000000" & SRC1_in( 31 downto 28) ;
					when 29 => RES32_out <= "00000000000000000000000000000" & SRC1_in( 31 downto 29) ;
					when 30 => RES32_out <= "000000000000000000000000000000" & SRC1_in( 31 downto 30) ;
					when 31 => RES32_out <= "0000000000000000000000000000000" & SRC1_in(31) ;
					when 32 => RES32_out <= (others=>'0');
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;
			end if;
			
			if (SRC1_in(31)='1') then
			case conv_integer(SRC2_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <=  '1' & SRC1_in(30 downto 0) ;
					when 2  => RES32_out <= "11" & SRC1_in(29 downto 0) ;
					when 3  => RES32_out <= "111" & SRC1_in(28 downto 0) ;
					when 4  => RES32_out <= "1111" & SRC1_in(27 downto 0) ;
					when 5  => RES32_out <= "11111" & SRC1_in(26 downto 0) ;
					when 6  => RES32_out <= "111111" & SRC1_in(25 downto 0) ;
					when 7  => RES32_out <= "1111111" & SRC1_in(24 downto 0) ;
					when 8  => RES32_out <= "11111111" & SRC1_in(23 downto 0) ;
					when 9  => RES32_out <= "111111111" & SRC1_in(22 downto 0) ;
					when 10 => RES32_out <= "1111111111" & SRC1_in(21 downto 0) ;
					when 11 => RES32_out <= "11111111111" & SRC1_in(20 downto 0) ;
					when 12 => RES32_out <= "111111111111" & SRC1_in(19 downto 0) ;
					when 13 => RES32_out <= "1111111111111" & SRC1_in(18 downto 0) ;
					when 14 => RES32_out <= "11111111111111" & SRC1_in(17 downto 0) ;
					when 15 => RES32_out <= "111111111111111" & SRC1_in(16 downto 0) ;
					when 16 => RES32_out <= "1111111111111111" & SRC1_in(15 downto 0) ;
					when 17 => RES32_out <= "11111111111111111" & SRC1_in(14 downto 0) ;
					when 18 => RES32_out <= "111111111111111111" & SRC1_in(13 downto 0) ;
					when 19 => RES32_out <= "1111111111111111111" & SRC1_in(12 downto 0) ;
					when 20 => RES32_out <= "11111111111111111111" & SRC1_in(11 downto 0) ;
					when 21 => RES32_out <= "111111111111111111111" & SRC1_in(10 downto 0) ;
					when 22 => RES32_out <= "1111111111111111111111" & SRC1_in( 9 downto 0) ;
					when 23 => RES32_out <= "11111111111111111111111" & SRC1_in( 8 downto 0) ;
					when 24 => RES32_out <= "111111111111111111111111" & SRC1_in( 7 downto 0) ;
					when 25 => RES32_out <= "1111111111111111111111111" & SRC1_in( 6 downto 0) ;
					when 26 => RES32_out <= "11111111111111111111111111" & SRC1_in( 5 downto 0) ;
					when 27 => RES32_out <= "111111111111111111111111111" & SRC1_in( 4 downto 0) ;
					when 28 => RES32_out <= "1111111111111111111111111111" & SRC1_in( 3 downto 0) ;
					when 29 => RES32_out <= "11111111111111111111111111111" & SRC1_in( 2 downto 0) ;
					when 30 => RES32_out <= "111111111111111111111111111111" & SRC1_in( 1 downto 0) ;
					when 31 => RES32_out <= "1111111111111111111111111111111" & SRC1_in(0) ;
					when 32 => RES32_out <= (others=>'0');
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;
			end if;
			
			
			when rotlr1  
			=> case conv_integer(SRC2_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <= SRC1_in(30 downto 0) & SRC1_in(31);
					when 2  => RES32_out <= SRC1_in(29 downto 0) & SRC1_in(31 downto 30);
					when 3  => RES32_out <= SRC1_in(28 downto 0) & SRC1_in(31 downto 29);
					when 4  => RES32_out <= SRC1_in(27 downto 0) & SRC1_in(31 downto 28);
					when 5  => RES32_out <= SRC1_in(26 downto 0) & SRC1_in(31 downto 27);
					when 6  => RES32_out <= SRC1_in(25 downto 0) & SRC1_in(31 downto 26);
					when 7  => RES32_out <= SRC1_in(24 downto 0) & SRC1_in(31 downto 25);
					when 8  => RES32_out <= SRC1_in(23 downto 0) & SRC1_in(31 downto 24);
					when 9  => RES32_out <= SRC1_in(22 downto 0) & SRC1_in(31 downto 23);
					when 10 => RES32_out <= SRC1_in(21 downto 0) & SRC1_in(31 downto 22);
					when 11 => RES32_out <= SRC1_in(20 downto 0) & SRC1_in(31 downto 21);
					when 12 => RES32_out <= SRC1_in(19 downto 0) & SRC1_in(31 downto 20);
					when 13 => RES32_out <= SRC1_in(18 downto 0) & SRC1_in(31 downto 19);
					when 14 => RES32_out <= SRC1_in(17 downto 0) & SRC1_in(31 downto 18);
					when 15 => RES32_out <= SRC1_in(16 downto 0) & SRC1_in(31 downto 17);
					when 16 => RES32_out <= SRC1_in(15 downto 0) & SRC1_in(31 downto 16);
					when 17 => RES32_out <= SRC1_in(14 downto 0) & SRC1_in(31 downto 15);
					when 18 => RES32_out <= SRC1_in(13 downto 0) & SRC1_in(31 downto 14);
					when 19 => RES32_out <= SRC1_in(12 downto 0) & SRC1_in(31 downto 13);
					when 20 => RES32_out <= SRC1_in(11 downto 0) & SRC1_in(31 downto 12);
					when 21 => RES32_out <= SRC1_in(10 downto 0) & SRC1_in(31 downto 11);
					when 22 => RES32_out <= SRC1_in( 9 downto 0) & SRC1_in(31 downto 10);
					when 23 => RES32_out <= SRC1_in( 8 downto 0) & SRC1_in(31 downto 9);
					when 24 => RES32_out <= SRC1_in( 7 downto 0) & SRC1_in(31 downto 8);
					when 25 => RES32_out <= SRC1_in( 6 downto 0) & SRC1_in(31 downto 7);
					when 26 => RES32_out <= SRC1_in( 5 downto 0) & SRC1_in(31 downto 6);
					when 27 => RES32_out <= SRC1_in( 4 downto 0) & SRC1_in(31 downto 5);
					when 28 => RES32_out <= SRC1_in( 3 downto 0) & SRC1_in(31 downto 4);
					when 29 => RES32_out <= SRC1_in( 2 downto 0) & SRC1_in(31 downto 3);
					when 30 => RES32_out <= SRC1_in( 1 downto 0) & SRC1_in(31 downto 2);
					when 31 => RES32_out <= SRC1_in(0) & SRC1_in(31 downto 1);
					when 32 => RES32_out <= SRC1_in;
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;	
			when rotrr1 
			=> case conv_integer(SRC2_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <= SRC1_in(0) & SRC1_in(31 downto 1) ;
					when 2  => RES32_out <= SRC1_in(1 downto 0) & SRC1_in(31 downto 2) ;
					when 3  => RES32_out <= SRC1_in(2 downto 0) & SRC1_in(31 downto 3) ;
					when 4  => RES32_out <= SRC1_in(3 downto 0) & SRC1_in(31 downto 4) ;
					when 5  => RES32_out <= SRC1_in(4 downto 0) & SRC1_in(31 downto 5) ;
					when 6  => RES32_out <= SRC1_in(5 downto 0) & SRC1_in(31 downto 6) ;
					when 7  => RES32_out <= SRC1_in(6 downto 0) & SRC1_in(31 downto 7) ;
					when 8  => RES32_out <= SRC1_in(7 downto 0) & SRC1_in(31 downto 8) ;
					when 9  => RES32_out <= SRC1_in(8 downto 0) & SRC1_in(31 downto 9) ;
					when 10 => RES32_out <= SRC1_in(9 downto 0) & SRC1_in(31 downto 10) ;
					when 11 => RES32_out <= SRC1_in(10 downto 0) &SRC1_in(31 downto 11) ;
					when 12 => RES32_out <= SRC1_in(11 downto 0) & SRC1_in(31 downto 12) ;
					when 13 => RES32_out <= SRC1_in(12 downto 0) & SRC1_in(31 downto 13) ;
					when 14 => RES32_out <= SRC1_in(13 downto 0) & SRC1_in(31 downto 14) ;
					when 15 => RES32_out <= SRC1_in(14 downto 0) & SRC1_in(31 downto 15) ;
					when 16 => RES32_out <= SRC1_in(15 downto 0) & SRC1_in(31 downto 16) ;
					when 17 => RES32_out <= SRC1_in(16 downto 0) & SRC1_in(31 downto 17) ;
					when 18 => RES32_out <= SRC1_in(17 downto 0) & SRC1_in(31 downto 18) ;
					when 19 => RES32_out <= SRC1_in(18 downto 0) & SRC1_in(31 downto 19) ;
					when 20 => RES32_out <= SRC1_in(19 downto 0) & SRC1_in(31 downto 20) ;
					when 21 => RES32_out <= SRC1_in(20 downto 0) & SRC1_in(31 downto 21) ;
					when 22 => RES32_out <= SRC1_in(21 downto 0) & SRC1_in(31 downto 22) ;
					when 23 => RES32_out <= SRC1_in(22 downto 0) & SRC1_in(31 downto 23) ;
					when 24 => RES32_out <= SRC1_in(23 downto 0) & SRC1_in(31 downto 24) ;
					when 25 => RES32_out <= SRC1_in(24 downto 0) & SRC1_in(31 downto 25) ;
					when 26 => RES32_out <= SRC1_in(25 downto 0) & SRC1_in(31 downto 26) ;
					when 27 => RES32_out <= SRC1_in(26 downto 0) & SRC1_in(31 downto 27) ;
					when 28 => RES32_out <= SRC1_in(27 downto 0) & SRC1_in(31 downto 28) ;
					when 29 => RES32_out <= SRC1_in(28 downto 0) & SRC1_in(31 downto 29) ;
					when 30 => RES32_out <= SRC1_in(29 downto 0) & SRC1_in(31 downto 30) ;
					when 31 => RES32_out <= SRC1_in(30 downto 0) & SRC1_in(0) ;
					when 32 => RES32_out <= SRC1_in;
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;
			when ldr1  
			=> null;--***pplc 
			when str1  
			=> null;--***pplc
			when xori1   
			=> RES32_out <= SRC1_in xor IMM32_in ;
			when andi1
			=> RES32_out <= SRC1_in and IMM32_in ;
			when ori1 
			=>  RES32_out <= SRC1_in or IMM32_in ;
			when nxori1 
			=>  RES32_out <= SRC1_in xnor IMM32_in ;
			when nori1  
			=>  RES32_out <= SRC1_in or IMM32_in ;
			when nandi1
			=>  RES32_out <= SRC1_in and IMM32_in ;
			when addi1 
			=> temp_Res := (SRC1_in(31) & SRC1_in) + IMM32_in;
				RES32_out <= temp_Res(31 downto 0);
				if (temp_Res(32) = '1') then
				flag_reg_upd(31) <= '1' ; -- add overflow flag
				end if;
			when subi1  
			=> temp_Res := (SRC1_in(31) & SRC1_in) - IMM32_in;
				RES32_out <= temp_Res(31 downto 0);
			   flag_reg_upd(30) <= '1' ; -- sub underflow flag
			when muli1 
			=> temp_Res_mul := SRC1_in * IMM32_in;
				RES32_out <= temp_Res_mul(31 downto 0);
				if (temp_Res_mul(63 downto 32) /= 0) then
				flag_reg_upd(29) <= '1' ; -- mul overflow flag
				end if;
			when divi1 
			=> if (div_done = '1') then
			                 RES32_out <= temp_div1 ;
				              if (remain1 /= 0) then 
									    flag_reg_upd(28) <= '1' ;
				              end if;
				           end if;
			when addfpi1
			=> fpbank(conv_integer(FP_DST_in)) <= to_slv(to_float32(afp + conv_integer(IMM32_in))); -- <TODO> overflow?
			when subfpi1 
			=> fpbank(conv_integer(FP_DST_in)) <= to_slv(afp - conv_integer(IMM32_in)); -- <TODO> underflow?
			when mulfpi1 
			=> fpbank(conv_integer(FP_DST_in)) <= to_slv(afp * conv_integer(IMM32_in)); -- <TODO> overflow?
			when divfpi1 
			=> fpbank(conv_integer(FP_DST_in)) <= to_slv(afp / conv_integer(IMM32_in)); -- <TODO> remain?
			when cmpregi1  
			=> if (SRC1_in > IMM32_in) then
				RES32_out <= SRC1_in;
				else RES32_out <= IMM32_in;
				end if;
			when jmp1 
			=>null;--**pplc
			when bre1  
			=>null;--**pplc
			when brue1 
			=>null;--**pplc
			when brg1 
			=>null;--**pplc
			when bls1 
			=>null;--**pplc
			when btr1 
			=>null;--**pplc
			when bfs1  
			=>null;--**pplc
			when jmpr1
			=>null;--**pplc
			when slli1 
			=> case conv_integer(IMM32_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <= SRC1_in(30 downto 0) & '0';
					when 2  => RES32_out <= SRC1_in(29 downto 0) & "00";
					when 3  => RES32_out <= SRC1_in(28 downto 0) & "000";
					when 4  => RES32_out <= SRC1_in(27 downto 0) & "0000";
					when 5  => RES32_out <= SRC1_in(26 downto 0) & "00000";
					when 6  => RES32_out <= SRC1_in(25 downto 0) & "000000";
					when 7  => RES32_out <= SRC1_in(24 downto 0) & "0000000";
					when 8  => RES32_out <= SRC1_in(23 downto 0) & "00000000";
					when 9  => RES32_out <= SRC1_in(22 downto 0) & "000000000";
					when 10 => RES32_out <= SRC1_in(21 downto 0) & "0000000000";
					when 11 => RES32_out <= SRC1_in(20 downto 0) & "00000000000";
					when 12 => RES32_out <= SRC1_in(19 downto 0) & "000000000000";
					when 13 => RES32_out <= SRC1_in(18 downto 0) & "0000000000000";
					when 14 => RES32_out <= SRC1_in(17 downto 0) & "00000000000000";
					when 15 => RES32_out <= SRC1_in(16 downto 0) & "000000000000000";
					when 16 => RES32_out <= SRC1_in(15 downto 0) & "0000000000000000";
					when 17 => RES32_out <= SRC1_in(14 downto 0) & "00000000000000000";
					when 18 => RES32_out <= SRC1_in(13 downto 0) & "000000000000000000";
					when 19 => RES32_out <= SRC1_in(12 downto 0) & "0000000000000000000";
					when 20 => RES32_out <= SRC1_in(11 downto 0) & "00000000000000000000";
					when 21 => RES32_out <= SRC1_in(10 downto 0) & "000000000000000000000";
					when 22 => RES32_out <= SRC1_in( 9 downto 0) & "0000000000000000000000";
					when 23 => RES32_out <= SRC1_in( 8 downto 0) & "00000000000000000000000";
					when 24 => RES32_out <= SRC1_in( 7 downto 0) & "000000000000000000000000";
					when 25 => RES32_out <= SRC1_in( 6 downto 0) & "0000000000000000000000000";
					when 26 => RES32_out <= SRC1_in( 5 downto 0) & "00000000000000000000000000";
					when 27 => RES32_out <= SRC1_in( 4 downto 0) & "000000000000000000000000000";
					when 28 => RES32_out <= SRC1_in( 3 downto 0) & "0000000000000000000000000000";
					when 29 => RES32_out <= SRC1_in( 2 downto 0) & "00000000000000000000000000000";
					when 30 => RES32_out <= SRC1_in( 1 downto 0) & "000000000000000000000000000000";
					when 31 => RES32_out <= SRC1_in(0) & "0000000000000000000000000000000";
					when 32 => RES32_out <= (others=>'0');
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;
			when slai1 
			=> case conv_integer(IMM32_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <= SRC1_in(31) & SRC1_in(29 downto 0) & '0';
					when 3  => RES32_out <= SRC1_in(31) & SRC1_in(28 downto 0) & "00";
					when 4  => RES32_out <= SRC1_in(31) & SRC1_in(27 downto 0) & "000";
					when 5  => RES32_out <= SRC1_in(31) & SRC1_in(26 downto 0) & "0000";
					when 6  => RES32_out <= SRC1_in(31) & SRC1_in(25 downto 0) & "00000";
					when 7  => RES32_out <= SRC1_in(31) & SRC1_in(24 downto 0) & "000000";
					when 8  => RES32_out <= SRC1_in(31) & SRC1_in(23 downto 0) & "0000000";
					when 9  => RES32_out <= SRC1_in(31) & SRC1_in(22 downto 0) & "00000000";
					when 10 => RES32_out <= SRC1_in(31) & SRC1_in(21 downto 0) & "000000000";
					when 11 => RES32_out <= SRC1_in(31) & SRC1_in(20 downto 0) & "0000000000";
					when 12 => RES32_out <= SRC1_in(31) & SRC1_in(19 downto 0) & "00000000000";
					when 13 => RES32_out <= SRC1_in(31) & SRC1_in(18 downto 0) & "000000000000";
					when 14 => RES32_out <= SRC1_in(31) & SRC1_in(17 downto 0) & "0000000000000";
					when 15 => RES32_out <= SRC1_in(31) & SRC1_in(16 downto 0) & "00000000000000";
					when 16 => RES32_out <= SRC1_in(31) & SRC1_in(15 downto 0) & "000000000000000";
					when 17 => RES32_out <= SRC1_in(31) & SRC1_in(14 downto 0) & "0000000000000000";
					when 18 => RES32_out <= SRC1_in(31) & SRC1_in(13 downto 0) & "00000000000000000";
					when 19 => RES32_out <= SRC1_in(31) & SRC1_in(12 downto 0) & "000000000000000000";
					when 20 => RES32_out <= SRC1_in(31) & SRC1_in(11 downto 0) & "0000000000000000000";
					when 21 => RES32_out <= SRC1_in(31) & SRC1_in(10 downto 0) & "00000000000000000000";
					when 22 => RES32_out <= SRC1_in(31) & SRC1_in( 9 downto 0) & "000000000000000000000";
					when 23 => RES32_out <= SRC1_in(31) & SRC1_in( 8 downto 0) & "0000000000000000000000";
					when 24 => RES32_out <= SRC1_in(31) & SRC1_in( 7 downto 0) & "00000000000000000000000";
					when 25 => RES32_out <= SRC1_in(31) & SRC1_in( 6 downto 0) & "000000000000000000000000";
					when 26 => RES32_out <= SRC1_in(31) & SRC1_in( 5 downto 0) & "0000000000000000000000000";
					when 27 => RES32_out <= SRC1_in(31) & SRC1_in( 4 downto 0) & "00000000000000000000000000";
					when 28 => RES32_out <= SRC1_in(31) & SRC1_in( 3 downto 0) & "000000000000000000000000000";
					when 29 => RES32_out <= SRC1_in(31) & SRC1_in( 2 downto 0) & "0000000000000000000000000000";
					when 30 => RES32_out <= SRC1_in(31) & SRC1_in( 1 downto 0) & "00000000000000000000000000000";
					when 31 => RES32_out <= SRC1_in(31) & "0000000000000000000000000000000";
					when 32 => RES32_out <= (others=>'0');
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;	
			when srli1 
			=> case conv_integer(IMM32_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <=  '0' & SRC1_in(31 downto 1) ;
					when 2  => RES32_out <= "00" & SRC1_in(31 downto 2) ;
					when 3  => RES32_out <= "000" & SRC1_in(31 downto 3) ;
					when 4  => RES32_out <= "0000" & SRC1_in(31 downto 4) ;
					when 5  => RES32_out <= "00000" & SRC1_in(31 downto 5) ;
					when 6  => RES32_out <= "000000" & SRC1_in(31 downto 6) ;
					when 7  => RES32_out <= "0000000" & SRC1_in(31 downto 7) ;
					when 8  => RES32_out <= "00000000" & SRC1_in(31 downto 8) ;
					when 9  => RES32_out <= "000000000" & SRC1_in(31 downto 9) ;
					when 10 => RES32_out <= "0000000000" & SRC1_in(31 downto 10) ;
					when 11 => RES32_out <= "00000000000" & SRC1_in(31 downto 11) ;
					when 12 => RES32_out <= "000000000000" & SRC1_in(31 downto 12) ;
					when 13 => RES32_out <= "0000000000000" & SRC1_in(31 downto 13) ;
					when 14 => RES32_out <= "00000000000000" & SRC1_in(31 downto 14) ;
					when 15 => RES32_out <= "000000000000000" & SRC1_in(31 downto 15) ;
					when 16 => RES32_out <= "0000000000000000" & SRC1_in(31 downto 16) ;
					when 17 => RES32_out <= "00000000000000000" & SRC1_in(31 downto 17) ;
					when 18 => RES32_out <= "000000000000000000" & SRC1_in(31 downto 18) ;
					when 19 => RES32_out <= "0000000000000000000" & SRC1_in(31 downto 19) ;
					when 20 => RES32_out <= "00000000000000000000" & SRC1_in(31 downto 20) ;
					when 21 => RES32_out <= "000000000000000000000" & SRC1_in(31 downto 21) ;
					when 22 => RES32_out <= "0000000000000000000000" & SRC1_in( 31 downto 22) ;
					when 23 => RES32_out <= "00000000000000000000000" & SRC1_in( 31 downto 23) ;
					when 24 => RES32_out <= "000000000000000000000000" & SRC1_in( 31 downto 24) ;
					when 25 => RES32_out <= "0000000000000000000000000" & SRC1_in( 31 downto 25) ;
					when 26 => RES32_out <= "00000000000000000000000000" & SRC1_in( 31 downto 26) ;
					when 27 => RES32_out <= "000000000000000000000000000" & SRC1_in( 31 downto 27) ;
					when 28 => RES32_out <= "0000000000000000000000000000" & SRC1_in( 31 downto 28) ;
					when 29 => RES32_out <= "00000000000000000000000000000" & SRC1_in( 31 downto 29) ;
					when 30 => RES32_out <= "000000000000000000000000000000" & SRC1_in( 31 downto 30) ;
					when 31 => RES32_out <= "0000000000000000000000000000000" & SRC1_in(31) ;
					when 32 => RES32_out <= (others=>'0');
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;
			when srai1 
			=> if (IMM32_in(31)='0') then
			case conv_integer(SRC2_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <=  '0' & SRC1_in(31 downto 1) ;
					when 2  => RES32_out <= "00" & SRC1_in(31 downto 2) ;
					when 3  => RES32_out <= "000" & SRC1_in(31 downto 3) ;
					when 4  => RES32_out <= "0000" & SRC1_in(31 downto 4) ;
					when 5  => RES32_out <= "00000" & SRC1_in(31 downto 5) ;
					when 6  => RES32_out <= "000000" & SRC1_in(31 downto 6) ;
					when 7  => RES32_out <= "0000000" & SRC1_in(31 downto 7) ;
					when 8  => RES32_out <= "00000000" & SRC1_in(31 downto 8) ;
					when 9  => RES32_out <= "000000000" & SRC1_in(31 downto 9) ;
					when 10 => RES32_out <= "0000000000" & SRC1_in(31 downto 10) ;
					when 11 => RES32_out <= "00000000000" & SRC1_in(31 downto 11) ;
					when 12 => RES32_out <= "000000000000" & SRC1_in(31 downto 12) ;
					when 13 => RES32_out <= "0000000000000" & SRC1_in(31 downto 13) ;
					when 14 => RES32_out <= "00000000000000" & SRC1_in(31 downto 14) ;
					when 15 => RES32_out <= "000000000000000" & SRC1_in(31 downto 15) ;
					when 16 => RES32_out <= "0000000000000000" & SRC1_in(31 downto 16) ;
					when 17 => RES32_out <= "00000000000000000" & SRC1_in(31 downto 17) ;
					when 18 => RES32_out <= "000000000000000000" & SRC1_in(31 downto 18) ;
					when 19 => RES32_out <= "0000000000000000000" & SRC1_in(31 downto 19) ;
					when 20 => RES32_out <= "00000000000000000000" & SRC1_in(31 downto 20) ;
					when 21 => RES32_out <= "000000000000000000000" & SRC1_in(31 downto 21) ;
					when 22 => RES32_out <= "0000000000000000000000" & SRC1_in( 31 downto 22) ;
					when 23 => RES32_out <= "00000000000000000000000" & SRC1_in( 31 downto 23) ;
					when 24 => RES32_out <= "000000000000000000000000" & SRC1_in( 31 downto 24) ;
					when 25 => RES32_out <= "0000000000000000000000000" & SRC1_in( 31 downto 25) ;
					when 26 => RES32_out <= "00000000000000000000000000" & SRC1_in( 31 downto 26) ;
					when 27 => RES32_out <= "000000000000000000000000000" & SRC1_in( 31 downto 27) ;
					when 28 => RES32_out <= "0000000000000000000000000000" & SRC1_in( 31 downto 28) ;
					when 29 => RES32_out <= "00000000000000000000000000000" & SRC1_in( 31 downto 29) ;
					when 30 => RES32_out <= "000000000000000000000000000000" & SRC1_in( 31 downto 30) ;
					when 31 => RES32_out <= "0000000000000000000000000000000" & SRC1_in(31) ;
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;
			end if;
			
			if (IMM32_in(31)='1') then
			case conv_integer(SRC2_in(4 downto 0)) is 
				   when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <=  '1' & SRC1_in(31 downto 1) ;
					when 2  => RES32_out <= "11" & SRC1_in(31 downto 2) ;
					when 3  => RES32_out <= "111" & SRC1_in(31 downto 3) ;
					when 4  => RES32_out <= "1111" & SRC1_in(31 downto 4) ;
					when 5  => RES32_out <= "11111" & SRC1_in(31 downto 5) ;
					when 6  => RES32_out <= "111111" & SRC1_in(31 downto 6) ;
					when 7  => RES32_out <= "1111111" & SRC1_in(31 downto 7) ;
					when 8  => RES32_out <= "11111111" & SRC1_in(31 downto 8) ;
					when 9  => RES32_out <= "111111111" & SRC1_in(31 downto 9) ;
					when 10 => RES32_out <= "1111111111" & SRC1_in(31 downto 10) ;
					when 11 => RES32_out <= "11111111111" & SRC1_in(31 downto 11) ;
					when 12 => RES32_out <= "111111111111" & SRC1_in(31 downto 12) ;
					when 13 => RES32_out <= "1111111111111" & SRC1_in(31 downto 13) ;
					when 14 => RES32_out <= "11111111111111" & SRC1_in(31 downto 14) ;
					when 15 => RES32_out <= "111111111111111" & SRC1_in(31 downto 15) ;
					when 16 => RES32_out <= "1111111111111111" & SRC1_in(31 downto 16) ;
					when 17 => RES32_out <= "11111111111111111" & SRC1_in(31 downto 17) ;
					when 18 => RES32_out <= "111111111111111111" & SRC1_in(31 downto 18) ;
					when 19 => RES32_out <= "1111111111111111111" & SRC1_in(31 downto 19) ;
					when 20 => RES32_out <= "11111111111111111111" & SRC1_in(31 downto 20) ;
					when 21 => RES32_out <= "111111111111111111111" & SRC1_in(31 downto 21) ;
					when 22 => RES32_out <= "1111111111111111111111" & SRC1_in(31 downto 22) ;
					when 23 => RES32_out <= "11111111111111111111111" & SRC1_in( 31 downto 23) ;
					when 24 => RES32_out <= "111111111111111111111111" & SRC1_in( 31 downto 24) ;
					when 25 => RES32_out <= "1111111111111111111111111" & SRC1_in( 31 downto 25) ;
					when 26 => RES32_out <= "11111111111111111111111111" & SRC1_in( 31 downto 26) ;
					when 27 => RES32_out <= "111111111111111111111111111" & SRC1_in( 31 downto 27) ;
					when 28 => RES32_out <= "1111111111111111111111111111" & SRC1_in( 31 downto 28) ;
					when 29 => RES32_out <= "11111111111111111111111111111" & SRC1_in( 31 downto 29) ;
					when 30 => RES32_out <= "111111111111111111111111111111" & SRC1_in( 31 downto 30) ;
					when 31 => RES32_out <= "1111111111111111111111111111111" & SRC1_in(31) ;
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;
			end if;
			when rotli1 
			=> case conv_integer(IMM32_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <= SRC1_in(30 downto 0) & SRC1_in(31);
					when 2  => RES32_out <= SRC1_in(29 downto 0) & SRC1_in(31 downto 30);
					when 3  => RES32_out <= SRC1_in(28 downto 0) & SRC1_in(31 downto 29);
					when 4  => RES32_out <= SRC1_in(27 downto 0) & SRC1_in(31 downto 28);
					when 5  => RES32_out <= SRC1_in(26 downto 0) & SRC1_in(31 downto 27);
					when 6  => RES32_out <= SRC1_in(25 downto 0) & SRC1_in(31 downto 26);
					when 7  => RES32_out <= SRC1_in(24 downto 0) & SRC1_in(31 downto 25);
					when 8  => RES32_out <= SRC1_in(23 downto 0) & SRC1_in(31 downto 24);
					when 9  => RES32_out <= SRC1_in(22 downto 0) & SRC1_in(31 downto 23);
					when 10 => RES32_out <= SRC1_in(21 downto 0) & SRC1_in(31 downto 22);
					when 11 => RES32_out <= SRC1_in(20 downto 0) & SRC1_in(31 downto 21);
					when 12 => RES32_out <= SRC1_in(19 downto 0) & SRC1_in(31 downto 20);
					when 13 => RES32_out <= SRC1_in(18 downto 0) & SRC1_in(31 downto 19);
					when 14 => RES32_out <= SRC1_in(17 downto 0) & SRC1_in(31 downto 18);
					when 15 => RES32_out <= SRC1_in(16 downto 0) & SRC1_in(31 downto 17);
					when 16 => RES32_out <= SRC1_in(15 downto 0) & SRC1_in(31 downto 16);
					when 17 => RES32_out <= SRC1_in(14 downto 0) & SRC1_in(31 downto 15);
					when 18 => RES32_out <= SRC1_in(13 downto 0) & SRC1_in(31 downto 14);
					when 19 => RES32_out <= SRC1_in(12 downto 0) & SRC1_in(31 downto 13);
					when 20 => RES32_out <= SRC1_in(11 downto 0) & SRC1_in(31 downto 12);
					when 21 => RES32_out <= SRC1_in(10 downto 0) & SRC1_in(31 downto 11);
					when 22 => RES32_out <= SRC1_in( 9 downto 0) & SRC1_in(31 downto 10);
					when 23 => RES32_out <= SRC1_in( 8 downto 0) & SRC1_in(31 downto 9);
					when 24 => RES32_out <= SRC1_in( 7 downto 0) & SRC1_in(31 downto 8);
					when 25 => RES32_out <= SRC1_in( 6 downto 0) & SRC1_in(31 downto 7);
					when 26 => RES32_out <= SRC1_in( 5 downto 0) & SRC1_in(31 downto 6);
					when 27 => RES32_out <= SRC1_in( 4 downto 0) & SRC1_in(31 downto 5);
					when 28 => RES32_out <= SRC1_in( 3 downto 0) & SRC1_in(31 downto 4);
					when 29 => RES32_out <= SRC1_in( 2 downto 0) & SRC1_in(31 downto 3);
					when 30 => RES32_out <= SRC1_in( 1 downto 0) & SRC1_in(31 downto 2);
					when 31 => RES32_out <= SRC1_in(0) & SRC1_in(31 downto 1);
					when 32 => RES32_out <= SRC1_in;
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
				end case;	
			when rotri1  
			=> case conv_integer(IMM32_in(4 downto 0)) is 
				    when 0  => RES32_out <= SRC1_in;
					when 1  => RES32_out <= SRC1_in(0) & SRC1_in(31 downto 1) ;
					when 2  => RES32_out <= SRC1_in(1 downto 0) & SRC1_in(31 downto 2) ;
					when 3  => RES32_out <= SRC1_in(2 downto 0) & SRC1_in(31 downto 3) ;
					when 4  => RES32_out <= SRC1_in(3 downto 0) & SRC1_in(31 downto 4) ;
					when 5  => RES32_out <= SRC1_in(4 downto 0) & SRC1_in(31 downto 5) ;
					when 6  => RES32_out <= SRC1_in(5 downto 0) & SRC1_in(31 downto 6) ;
					when 7  => RES32_out <= SRC1_in(6 downto 0) & SRC1_in(31 downto 7) ;
					when 8  => RES32_out <= SRC1_in(7 downto 0) & SRC1_in(31 downto 8) ;
					when 9  => RES32_out <= SRC1_in(8 downto 0) & SRC1_in(31 downto 9) ;
					when 10 => RES32_out <= SRC1_in(9 downto 0) & SRC1_in(31 downto 10) ;
					when 11 => RES32_out <= SRC1_in(10 downto 0) &SRC1_in(31 downto 11) ;
					when 12 => RES32_out <= SRC1_in(11 downto 0) & SRC1_in(31 downto 12) ;
					when 13 => RES32_out <= SRC1_in(12 downto 0) & SRC1_in(31 downto 13) ;
					when 14 => RES32_out <= SRC1_in(13 downto 0) & SRC1_in(31 downto 14) ;
					when 15 => RES32_out <= SRC1_in(14 downto 0) & SRC1_in(31 downto 15) ;
					when 16 => RES32_out <= SRC1_in(15 downto 0) & SRC1_in(31 downto 16) ;
					when 17 => RES32_out <= SRC1_in(16 downto 0) & SRC1_in(31 downto 17) ;
					when 18 => RES32_out <= SRC1_in(17 downto 0) & SRC1_in(31 downto 18) ;
					when 19 => RES32_out <= SRC1_in(18 downto 0) & SRC1_in(31 downto 19) ;
					when 20 => RES32_out <= SRC1_in(19 downto 0) & SRC1_in(31 downto 20) ;
					when 21 => RES32_out <= SRC1_in(20 downto 0) & SRC1_in(31 downto 21) ;
					when 22 => RES32_out <= SRC1_in(21 downto 0) & SRC1_in(31 downto 22) ;
					when 23 => RES32_out <= SRC1_in(22 downto 0) & SRC1_in(31 downto 23) ;
					when 24 => RES32_out <= SRC1_in(23 downto 0) & SRC1_in(31 downto 24) ;
					when 25 => RES32_out <= SRC1_in(24 downto 0) & SRC1_in(31 downto 25) ;
					when 26 => RES32_out <= SRC1_in(25 downto 0) & SRC1_in(31 downto 26) ;
					when 27 => RES32_out <= SRC1_in(26 downto 0) & SRC1_in(31 downto 27) ;
					when 28 => RES32_out <= SRC1_in(27 downto 0) & SRC1_in(31 downto 28) ;
					when 29 => RES32_out <= SRC1_in(28 downto 0) & SRC1_in(31 downto 29) ;
					when 30 => RES32_out <= SRC1_in(29 downto 0) & SRC1_in(31 downto 30) ;
					when 31 => RES32_out <= SRC1_in(30 downto 0) & SRC1_in(0) ;
					when 32 => RES32_out <= SRC1_in;
					when others =>  RES32_out <= (others=>'0');
									flag_reg_upd(27)<='1';
	         end case;
			when li1  
			=>null; --<TODO>
			when ldm1 
			=>  null;--***pplc 
			when stm1 
			=>  null;--***pplc 
			when goto1  
			=>null; --<TODO>
			when mov1  
			=> RES32_out <= SRC1_in;
			when clr1 
			=> RES32_out <= (others => '0'); 
				temp_Res := (others => '0');	
			
			 when others => null ; --nop
			end case;
		 
		end if;
		
	end process;

end architecture ALU_arc;


