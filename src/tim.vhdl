-- HiveCraft Timers (TIM)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hivecraft_tim is
	port (
		-- Clock sources
		SYSDIV: in std_logic_vector(15 downto 0);
		CLK_SUB: in std_logic;
		EXT_n: in std_logic;
		
		-- Bus clock signal
		CLK_BUS: in std_logic;
		
		-- Buses
		A: in std_logic_vector(23 downto 0);
		D_i: out std_logic_vector(15 downto 0);
		D_o: in std_logic_vector(15 downto 0);
	
		-- Bus master control signals
		RESET_n: in std_logic;
		RD_n: in std_logic;
		WR_n: in std_logic;
		WORD_n: in std_logic;
		
		-- Reload signals (for interrupts, and clocking the DMA and serial/controller ports)
		TA_RELOAD_n: out std_logic;
		TB_RELOAD_n: out std_logic
	);
end hivecraft_tim;

architecture rtl of hivecraft_tim is
	-- Timer A reload signal
	signal TA_RELOAD_n_s: std_logic := '1';
	
	-- Timer A control
	signal tim_a_enable: std_logic := '0';
	signal tim_a_oneshot: std_logic := '0';
	signal tim_a_src: std_logic_vector(4 downto 0) := "00000";
	
	-- Timer B control
	signal tim_b_enable: std_logic := '0';
	signal tim_b_oneshot: std_logic := '0';
	signal tim_b_src: std_logic_vector(4 downto 0) := "00000";
	
	-- Enable latches (applied at the next timer clock)
	signal tim_a_enable_s: std_logic := '0';
	signal tim_b_enable_s: std_logic := '0';
	
	-- Multiplexed timer clock signals
	signal tim_a_clk: std_logic := '0';
	signal tim_b_clk: std_logic := '0';
	
	-- Reload latches
	signal tim_a_s: std_logic_vector(15 downto 0) := x"0000";
	signal tim_b_s: std_logic_vector(15 downto 0) := x"0000";
	
	-- Timer counters
	signal tim_a: std_logic_vector(15 downto 0) := x"FFFF";
	signal tim_b: std_logic_vector(15 downto 0) := x"FFFF";
begin
	-- Output port that needs to be readable
	TA_RELOAD_n <= TA_RELOAD_n_s;
	
	-- Multiplex timer A's clock sources onto one signal
	process (tim_a_src, SYSDIV, CLK_SUB, EXT_n)
		variable src_int: integer range 0 to 31;
	begin
		src_int := to_integer(unsigned(tim_a_src));
		case src_int is
			when 0 to 15 => tim_a_clk <= SYSDIV(src_int);
			when 16 => tim_a_clk <= CLK_SUB;
			when 17 => tim_a_clk <= not EXT_n;
			when others => tim_a_clk <= '0';
		end case;
	end process;
	
	-- Multiplex timer B's clock sources onto one signal
	process (tim_b_src, SYSDIV, CLK_SUB, EXT_n, TA_RELOAD_n_s)
		variable src_int: integer range 0 to 31;
	begin
		src_int := to_integer(unsigned(tim_b_src));
		case src_int is
			when 0 to 15 => tim_b_clk <= SYSDIV(src_int);
			when 16 => tim_b_clk <= CLK_SUB;
			when 17 => tim_b_clk <= not EXT_n;
			when 18 => tim_b_clk <= not TA_RELOAD_n_s;
			when others => tim_b_clk <= '0';
		end case;
	end process;
	
	-- If timer A is enabled, increment its counter on the rising edge of its clock
	process (tim_a_clk, RESET_n)
	begin
		if RESET_n = '0' then
			tim_a <= x"FFFF";
			tim_a_enable <= '0';
			TA_RELOAD_n_s <= '1';
		elsif rising_edge(tim_a_clk) then
			tim_a_enable <= tim_a_enable_s;
			if tim_a_enable = '1' then
				if tim_a = x"FFFF" then
					tim_a <= tim_a_s;
					TA_RELOAD_n_s <= '0';
					if tim_a_oneshot = '1' then
						tim_a_enable <= '0';
					end if;
				else
					TA_RELOAD_n_s <= '1';
					tim_a <= std_logic_vector(unsigned(tim_a) + 1);
				end if;
			else
				TA_RELOAD_n_s <= '1';
			end if;
		end if;
	end process;
	
	-- If timer B is enabled, increment its counter on the rising edge of its clock
	process (tim_b_clk, RESET_n)
	begin
		if RESET_n = '0' then
			tim_b <= x"FFFF";
			tim_b_enable <= '0';
			TB_RELOAD_n <= '1';
		elsif rising_edge(tim_b_clk) then
			tim_b_enable <= tim_b_enable_s;
			if tim_b_enable = '1' then
				if tim_b = x"FFFF" then
					tim_b <= tim_b_s;
					TB_RELOAD_n <= '0';
					if tim_b_oneshot = '1' then
						tim_b_enable <= '0';
					end if;
				else
					TB_RELOAD_n <= '1';
					tim_b <= std_logic_vector(unsigned(tim_b) + 1);
				end if;
			else
				TB_RELOAD_n <= '1';
			end if;
		end if;
	end process;
	
	process (CLK_BUS, RESET_n)
	begin
		if RESET_n = '0' then
			tim_a_enable_s <= '0';
			tim_a_oneshot <= '0';
			tim_a_src <= "00000";
			
			tim_b_enable_s <= '0';
			tim_b_oneshot <= '0';
			tim_b_src <= "00000";
			
			tim_a_s <= x"0000";
			tim_b_s <= x"0000";
		elsif rising_edge(CLK_BUS) then
			-- Needed for every I/O device to make sure the data bus isn't being driven again
			D_i <= (others => 'Z');
			
			-- Timer-related HiveCraft I/O registers
			if RD_n = '0' then
				if A = x"FFF300" then
					-- TA_CTL
					if WORD_n = '1' then
						D_i(15 downto 8) <= x"00";
					else
						D_i(15 downto 8) <= tim_b_enable_s & '0' & tim_b_oneshot & tim_b_src;
					end if;
					D_i(7 downto 0) <= tim_a_enable_s & '0' & tim_a_oneshot & tim_a_src;
				elsif A = x"FFF301" then
					-- TB_CTL
					D_i <= x"00" & tim_b_enable_s & '0' & tim_b_oneshot & tim_b_src;
				elsif A = x"FFF302" then
					-- TA_C (low)
					if WORD_n = '1' then
						D_i(15 downto 8) <= x"00";
					else
						D_i(15 downto 8) <= tim_a(15 downto 8);
					end if;
					D_i(7 downto 0) <= tim_a(7 downto 0);
				elsif A = x"FFF303" then
					-- TA_C (high)
					D_i <= x"00" & tim_a(7 downto 0);
				elsif A = x"FFF304" then
					-- TB_C (low)
					if WORD_n = '1' then
						D_i(15 downto 8) <= x"00";
					else
						D_i(15 downto 8) <= tim_b(15 downto 8);
					end if;
					D_i(7 downto 0) <= tim_b(7 downto 0);
				elsif A = x"FFF305" then
					-- TB_C (high)
					D_i <= x"00" & tim_b(7 downto 0);
				elsif A = x"FFF306" then
					-- TA_R (low)
					if WORD_n = '1' then
						D_i(15 downto 8) <= x"00";
					else
						D_i(15 downto 8) <= tim_a_s(15 downto 8);
					end if;
					D_i(7 downto 0) <= tim_a_s(7 downto 0);
				elsif A = x"FFF307" then
					-- TA_R (high)
					D_i <= x"00" & tim_a_s(7 downto 0);
				elsif A = x"FFF308" then
					-- TB_R (low)
					if WORD_n = '1' then
						D_i(15 downto 8) <= x"00";
					else
						D_i(15 downto 8) <= tim_b_s(15 downto 8);
					end if;
					D_i(7 downto 0) <= tim_b_s(7 downto 0);
				elsif A = x"FFF309" then
					-- TB_R (high)
					D_i <= x"00" & tim_b_s(7 downto 0);
				end if;
			elsif WR_n = '0' then
				if A = x"FFF300" then
					-- TA_CTL
					if WORD_n = '0' then
						tim_b_enable_s <= D_o(15);
						tim_b_oneshot <= D_o(13);
						tim_b_src <= D_o(12 downto 8);
					end if;
					tim_a_enable_s <= D_o(7);
					tim_a_oneshot <= D_o(5);
					tim_a_src <= D_o(4 downto 0);
				elsif A = x"FFF301" then
					-- TB_CTL
					tim_b_enable_s <= D_o(7);
					tim_b_oneshot <= D_o(5);
					tim_b_src <= D_o(4 downto 0);
				elsif A = x"FFF302" then
					-- TA_C (low)
					if WORD_n = '0' then
						tim_a(15 downto 8) <= D_o(15 downto 8);
					end if;
					tim_a(7 downto 0) <= D_o(7 downto 0);
				elsif A = x"FFF303" then
					-- TA_C (high)
					tim_a(15 downto 8) <= D_o(7 downto 0);
				elsif A = x"FFF304" then
					-- TB_C (low)
					if WORD_n = '0' then
						tim_b(15 downto 8) <= D_o(15 downto 8);
					end if;
					tim_b(7 downto 0) <= D_o(7 downto 0);
				elsif A = x"FFF305" then
					-- TB_C (high)
					D_i <= x"00" & tim_b(7 downto 0);
				elsif A = x"FFF306" then
					-- TA_R (low)
					if WORD_n = '0' then
						tim_a_s(15 downto 8) <= D_o(15 downto 8);
					end if;
					tim_a_s(7 downto 0) <= D_o(7 downto 0);
				elsif A = x"FFF307" then
					-- TA_R (high)
					tim_a_s(15 downto 8) <= D_o(7 downto 0);
				elsif A = x"FFF308" then
					-- TB_R (low)
					if WORD_n = '0' then
						tim_b_s(15 downto 8) <= D_o(15 downto 8);
					end if;
					tim_b_s(7 downto 0) <= D_o(7 downto 0);
				elsif A = x"FFF309" then
					-- TB_R (high)
					tim_b_s(15 downto 8) <= D_o(7 downto 0);
				end if;
			end if;
		end if;
	end process;
end rtl;