library ieee;
use ieee.std_logic_1164.all;

entity IC is
   port (
      clk   : in    std_logic;
      rst   : in    std_logic;
      cs    : in    std_logic;
      rd    : in    std_logic;
      wr    : in    std_logic;
      inta  : in    std_logic;
      irq_v : in    std_logic_vector(7 downto 0);
      d     : inout std_logic_vector(7 downto 0);
      irq   : out   std_logic
      );
end entity IC;

architecture arc_IC of IC is
   signal msk_reg, irq_reg, prio : std_logic_vector(d'range);
   signal irq_reg_rst            : std_logic;   
begin
   d <= irq_reg when ((cs nor rd) = '1') else (others => 'Z');
   irq_reg_rst <= rst and inta;
   irq <= '0' when (irq_reg /= x"00") else '1';
   process(clk, rst)
   begin
      if (rst = '1') then
         msk_reg <= (others => '0');
      elsif rising_edge(clk) then
         if ((cs nor wr) = '1') then
            msk_reg <= d;
         end if;
      end if;
   end process;

   process(clk, irq_reg_rst)
   begin
      if (irq_reg_rst = '1') then
         irq_reg <= (others => '0');
      elsif rising_edge(clk) then
         if (irq_reg = x"00") then
            irq_reg <= prio;
         end if;
      end if;
   end process;

   process(msk_reg, irq_v) is
      variable tmp1, tmp2 : std_logic_vector(d'range);
   begin
      tmp1 := msk_reg and irq_v;
      tmp2 := (others => '0');
      for i in tmp1'range loop
         tmp2(i) := tmp1(i);
         exit when (tmp1(i) = '1');
      end loop;
      prio <= tmp2;
   end process;
end architecture arc_IC;
