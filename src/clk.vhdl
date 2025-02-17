-- HiveCraft Clock Control (CLK)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hivecraft_clk is
	port (
		-- Input clock signals
		CLK_OSC: in std_logic;
		CLK_SUB: in std_logic;
		
		-- Output clock signals
		CLK_BUS: out std_logic;
		CDIV: out std_logic_vector(15 downto 0);
		
		-- Buses
		A: in std_logic_vector(23 downto 0);
		D_i: out std_logic_vector(15 downto 0);
		D_o: in std_logic_vector(15 downto 0);
		
		-- Bus master control signals
		RESET_n: in std_logic;
		RD_n: in std_logic;
		WR_n: in std_logic;
		WORD_n: in std_logic;
		HALT_n: in std_logic
	);
end hivecraft_clk;

architecture rtl of hivecraft_clk is
	-- Clock dividers
	signal CDIV_s: std_logic_vector(15 downto 0) := x"0000";
	signal CLK_BUS_s: std_logic := '0';
	signal sub_divider: std_logic := '0';
	
	-- Divider control
	signal speed_s: std_logic_vector(1 downto 0) := "00";
	signal enable_s: std_logic := '1';
	signal pending: std_logic := '0';
	
	-- Actual speed and enable signals
	signal speed: std_logic_vector(1 downto 0) := "00";
	signal enable: std_logic := '1';
begin
	-- Output ports that need to be readable
	CDIV <= CDIV_s;
	CLK_BUS <= CLK_BUS_s;
	
	-- Divide the 32 kHz oscillator by 2 for the last clock speed setting
	process (CLK_SUB, RESET_n)
	begin
		if RESET_n = '0' then
			sub_divider <= '0';
		elsif rising_edge(CLK_SUB) then
			sub_divider <= not sub_divider;
		end if;
	end process;
	
	-- Clock the divider only if the main oscillator is enabled, and multiplex CLK_BUS_s from one of four clock outputs
	process (CLK_OSC, RESET_n)
	begin
		if RESET_n = '0' then
			CLK_BUS_s <= '0';
			CDIV_s <= x"0000";
		elsif rising_edge(CLK_OSC) and enable = '1' then
			CDIV_s <= std_logic_vector(unsigned(CDIV_s) + 1);
			
			case speed is
				when "00" => CLK_BUS_s <= CDIV_s(0);
				when "01" => CLK_BUS_s <= CDIV_s(1);
				when "10" => CLK_BUS_s <= CDIV_s(2);
				when others => CLK_BUS_s <= sub_divider;
			end case;
		end if;
	end process;
	
	process (CLK_BUS_s, RESET_n)
	begin
		if RESET_n = '0' then
			speed <= "00";
			speed_s <= "00";
			enable <= '1';
			enable_s <= '1';
			pending <= '0';
		elsif rising_edge(CLK_BUS_s) then
			-- Needed for every I/O device to make sure the data bus isn't being driven again
			D_i <= (others => 'Z');
			
			-- Clock-related HiveCraft I/O registers
			if RD_n = '0' then
				if A = x"FFF33C" then
					-- CDIV (low)
					if WORD_n = '1' then
						D_i(15 downto 8) <= x"00";
					else
						D_i(15 downto 8) <= CDIV_s(15 downto 8);
					end if;
					D_i(7 downto 0) <= CDIV_s(7 downto 0);
				elsif A = x"FFF33D" then
					-- CDIV (high)
					D_i <= x"00" & CDIV_s(15 downto 8);
				elsif A = x"FFF33E" then
					-- OSC_CTL
					D_i <= x"00" & pending & "0000" & enable_s & speed_s;
				end if;
			elsif WR_n = '0' and A = x"FFF33E" then
				-- OSC_CTL
				speed_s <= D_o(1 downto 0);
				enable_s <= D_o(2);
				pending <= '1';
			end if;
			
			-- Apply the changes when the CPU halts
			if HALT_n = '0' and pending = '1' then
				pending <= '0';
				speed <= speed_s;
				enable <= enable_s;
			end if;
		end if;
	end process;
end rtl;