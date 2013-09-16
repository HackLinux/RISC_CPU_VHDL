library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity CC_LRU is
   port (
      clk           : in  std_logic;
      rst           : in  std_logic;
      addr          : in  std_logic_vector(31 downto 0);
      memory_read   : in  std_logic;
      inst_from_mem : in  std_logic_vector(31 downto 0);
      mem_done      : in  std_logic;
      inst_to_cpu   : out std_logic_vector(31 downto 0);
      done          : out std_logic);
end entity CC_LRU;

architecture arc_CC_LRU of CC_LRU is
   signal hit, miss : std_logic;
   signal cache_upd : std_logic;
   signal read_en   : std_logic;
   signal data_sel  : std_logic;
   type   mem_arr is array (0 to 256) of
      std_logic_vector(51 downto 0);
   signal cache_mem_0 : mem_arr;         --two banks for LRU algorithm
   signal cache_mem_1 : mem_arr;
   signal flag       : std_logic_vector(255 downto 0);  --flag for last accessed bank
   alias cache_addr  : std_logic_vector(11 downto 0) is
      addr(11 downto 0);
   alias tag : std_logic_vector(19 downto 0) is addr(31 downto 12);
   type   fsm_st is (idle, wait_on_cache, wait_on_mem);
   signal cs : fsm_st;
begin
   -- cache memory and cache status flags (hit &  miss)
   process (clk, rst) is
   begin
      if (rst = '1') then
         hit         <= '0';
         miss        <= '0';
         cache_mem_0 <= (others => (others => '0'));
         cache_mem_1 <= (others => (others => '0'));
         flag        <= (others => '0');
      elsif rising_edge(clk) then
         hit  <= '0';
         miss <= '0';
         if (read_en = '1') then
            if (flag(conv_integer(cache_addr)) = '0') then  --flag check
               if (tag = cache_mem_0(conv_integer(cache_addr))(51 downto 32)) then
                  hit <= '1';
               elsif (tag = cache_mem_1(conv_integer(cache_addr))) then
                  hit                            <= '1';
                  flag(conv_integer(cache_addr)) <= '1';
               else
                  cache_upd                      <= '1';
                  miss                           <= '1';
                  flag(conv_integer(cache_addr)) <= '1';
               end if;
            elsif (tag = cache_mem_1(conv_integer(cache_addr))(51 downto 32)) then
               hit <= '1';
            elsif (tag = cache_mem_0(conv_integer(cache_addr))) then
               hit                            <= '1';
               flag(conv_integer(cache_addr)) <= '0';
            else
               cache_upd                      <= '1';
               miss                           <= '1';
               flag(conv_integer(cache_addr)) <= '0';
            end if;
         end if;
         if (cache_upd = '1') then  --updating cache memory at the last accessed bank
            if (flag(conv_integer(cache_addr)) = '0') then
               cache_mem_0(conv_integer(cache_addr)) <= tag & inst_from_mem;
            else
               cache_mem_1(conv_integer(cache_addr)) <= tag & inst_from_mem;
            end if;
         end if;
      end if;
 
  --transfer of the selected instruction to cpu
  if (data_sel = '1') then
   
   if (flag(conv_integer(cache_addr)) = '0') then
      inst_to_cpu <= cache_mem_0(conv_integer(cache_addr))(inst_to_cpu'range) ; 
 elsif (flag(conv_integer(cache_addr)) = '1') then
   inst_to_cpu <= cache_mem_1(conv_integer(cache_addr))(inst_to_cpu'range) ; 
 end if;
 elsif (data_sel = '0') then
   inst_to_cpu <= inst_from_mem ;
 end if;
 end process;

   --Mealy FSM description by single process with registered outputs
   process (clk, rst) is
      variable ns : fsm_st;
   begin
      if (rst = '1') then
         done      <= '0';
         cache_upd <= '0';
         read_en   <= '0';
         data_sel  <= '1';
         cs        <= idle;
      elsif rising_edge(clk) then
         ns        := cs;
         done      <= '0';
         cache_upd <= '0';
         read_en   <= '0';
         data_sel  <= '1';
         case cs is
            when idle => if (memory_read = '1') then
                            ns      := wait_on_cache;
                            read_en <= '1';
                         end if;
            when wait_on_cache => if (hit = '1') then
                                     ns   := idle;
                                     done <= '1';
                                  elsif (miss = '1') then
                                     ns := wait_on_mem;
                                  end if;
            when wait_on_mem => if (mem_done = '1') then
                                   ns        := idle;
                                   done      <= '1';
                                   cache_upd <= '1';
                                   data_sel  <= '0';
                                end if;
            when others => null;
         end case;
         cs <= ns;
      end if;
   end process;
end architecture arc_CC_LRU;
