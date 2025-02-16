-- HiveCraft Pilot24 (CPU)

library ieee;
use ieee.std_logic_1164.all;

entity hivecraft_cpu is
	port (
		-- Clock
		CLK: in std_logic;
		
		-- Interrupts
		NMI_n: in std_logic;
		IRQ_n: in std_logic_vector(1 to 7);
		IACK_n: out std_logic;
		
		-- Buses
		A: out std_logic_vector(23 downto 0);
		D_i: in std_logic_vector(15 downto 0);
		D_o: out std_logic_vector(15 downto 0);
		
		-- Control signals
		RESET_n: in std_logic;
		RD_n: out std_logic;
		WR_n: out std_logic;
		WORD_n: out std_logic;
		WAIT_n: in std_logic;
		BUSRQ_n: in std_logic;
		BUSACK_n: out std_logic;
		HALT_n: out std_logic
	);
end hivecraft_cpu;

architecture rtl of hivecraft_cpu is
	-- Bus latches
	signal A_s: std_logic_vector(23 downto 0) := x"FFCFF0";
	signal D_o_s: std_logic_vector(15 downto 0);
	signal RD_n_s: std_logic := '1';
	signal WR_n_s: std_logic := '1';
	signal WORD_n_s: std_logic := '1';
	
	-- Interconnects
	signal pfq_read_n: std_logic := '1';
	signal pfq_word_n: std_logic := '1';
	signal pfq_word_ready_n: std_logic := '1';
	signal pfq_addr: std_logic_vector(23 downto 0);
	
	signal dcd_branch_n: std_logic := '0';
	signal dcd_branch_addr: std_logic_vector(23 downto 0);
begin
	pfq: entity work.hivecraft_cpu_pfq(rtl) port map (
		CLK => CLK,
		addr_i => dcd_branch_addr,
		addr_o => pfq_addr,
		data_i => D_i,
		data_o => D_o_s,
		RESET_n => RESET_n,
		WAIT_n => WAIT_n,
		read_n => pfq_read_n,
		word_n => pfq_word_n,
		word_ready_n => pfq_word_ready_n,
		branch_n => dcd_branch_n,
		hold_n => '0'
	);
	
	RD_n <= RD_n_s;
	WR_n <= WR_n_s;
	WORD_n <= WORD_n_s;
	
	A <= A_s;
	
	process (RESET_n, pfq_read_n, pfq_word_n, pfq_addr)
	begin
		-- EXC takes bus priority, then PFQ
		if RESET_n = '0' then
			RD_n_s <= '1';
			WR_n_s <= '1';
			WORD_n_s <= '1';
		elsif pfq_read_n = '0' then
			A_s <= pfq_addr;
			RD_n_s <= pfq_read_n;
			WR_n_s <= '1';
			WORD_n_s <= pfq_word_n;
		else
			RD_n_s <= '1';
			WR_n_s <= '1';
			WORD_n_s <= '1';
		end if;
		
		-- core is incapable of writing so far
	end process;
	
	process (CLK, RESET_n)
	begin
		if RESET_n = '0' then
			IACK_n <= '1';
			BUSACK_n <= '1';
			HALT_n <= '1';
			dcd_branch_n <= '0';
			dcd_branch_addr <= x"FFCFF0";
		elsif rising_edge(CLK) then
			if WAIT_n = '1' then
				if dcd_branch_n = '0' then
					dcd_branch_n <= '1';
				end if;
			end if;
		elsif falling_edge(CLK) then
			if WAIT_n = '1' then
				-- Complete a write if needed
				if WR_n_s = '0' then
					D_o <= D_o_s;
				else
					D_o <= (others => 'Z');
				end if;
			end if;
		end if;
	end process;
end rtl;