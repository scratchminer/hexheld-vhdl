-- HiveCraft Pilot24 Prefetch Queue (CPU_PFQ)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hivecraft_cpu_pfq is
	port (
		-- Clock
		CLK: in std_logic;
		
		-- Buses
		addr_i: in std_logic_vector(23 downto 0);
		addr_o: out std_logic_vector(23 downto 0);
		data_i: in std_logic_vector(15 downto 0);
		data_o: out std_logic_vector(15 downto 0);
		
		-- Control signals
		RESET_n: in std_logic;
		WAIT_n: in std_logic;
		read_n: out std_logic;
		word_n: out std_logic;
		word_ready_n: out std_logic;
		branch_n: in std_logic;
		hold_n: in std_logic
	);
end hivecraft_cpu_pfq;

architecture rtl of hivecraft_cpu_pfq is
	signal addr_s: std_logic_vector(23 downto 0);
	signal read_n_s: std_logic;
	signal word_ready_n_s: std_logic;
	signal empty_n: std_logic;
	signal word0: std_logic_vector(15 downto 0);
	signal word1: std_logic_vector(15 downto 0);
	signal word2: std_logic_vector(15 downto 0);
	signal word3: std_logic_vector(15 downto 0);
	signal word4: std_logic_vector(15 downto 0);
	signal ready_n: std_logic_vector(0 to 4);
begin
	word_ready_n <= word_ready_n_s;
	read_n <= read_n_s;
	
	addr_o <= addr_s;
	
	process (ready_n)
	begin
		if ready_n = "11111" then
			empty_n <= '0';
		else
			empty_n <= '1';
		end if;
	end process;
	
	process (CLK, RESET_n)
	begin
		if RESET_n = '0' then
			word_ready_n_s <= '1';
			read_n_s <= '1';
			word_n <= '1';
			ready_n <= "11111";
			addr_s <= x"FFCFF0";
		elsif rising_edge(CLK) then
			-- push each word one step further in the queue
			if empty_n = '1' and branch_n = '1' then
				if (WAIT_n = '1' and hold_n = '1') or word_ready_n_s = '1' then
					data_o <= word4;
					word_ready_n_s <= ready_n(4);
					ready_n(4) <= '1';
				end if;
				if ready_n(4) = '1' then
					word4 <= word3;
					ready_n(4) <= ready_n(3);
					ready_n(3) <= '1';
				end if;
				if ready_n(3) = '1' then
					word3 <= word2;
					ready_n(3) <= ready_n(2);
					ready_n(2) <= '1';
				end if;
				if ready_n(2) = '1' then
					word2 <= word1;
					ready_n(2) <= ready_n(1);
					ready_n(1) <= '1';
				end if;
				if ready_n(1) = '1' then
					word1 <= word0;
					ready_n(1) <= ready_n(0);
					ready_n(0) <= '1';
				end if;
			end if;
			-- latch a new word from the data bus if possible
			if branch_n = '1' and WAIT_n = '1' and ready_n(0) = '1' then
				word0 <= data_i;
				ready_n(0) <= '0';
			end if;
		elsif falling_edge(CLK) then
			if branch_n = '0' then
				ready_n <= "11111";
				addr_s <= addr_i;
				word_n <= '1';
				read_n_s <= '1';
			elsif WAIT_n = '1' then
				-- assert RD_n if a new word is needed...
				if ready_n(0) = '1' and read_n_s = '1' then
					read_n_s <= '0';
					word_n <= '0';
				end if;
				
				-- ...and negate it if not
				if ready_n(1 to 4) = "0000" then
					read_n_s <= '1';
					word_n <= '1';
				end if;
				
				-- increment the target address if currently reading
				if read_n_s = '0' then
					addr_s <= std_logic_vector(unsigned(addr_s) + 2);
				end if;
			end if;
		end if;
	end process;
end rtl;