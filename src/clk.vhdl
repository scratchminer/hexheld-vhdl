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
	process (CLK_SUB)
	begin
		if rising_edge(CLK_SUB) then
			sub_divider <= not sub_divider;
		end if;
	end process;
	
	process (CLK_BUS_s)
	begin
		CLK_BUS <= CLK_BUS_s;
		
		if rising_edge(CLK_BUS_s) then
			D_i <= (others => 'Z');
			
			if RD_n = '0' then
				if A = x"FFF33C" then
					-- CDIV
					if WORD_n = '1' then
						D_i(15 downto 8) <= x"00";
					else
						D_i(15 downto 8) <= CDIV_s(15 downto 8);
					end if;
					D_i(7 downto 0) <= CDIV_s(7 downto 0);
				elsif A = x"FFF33D" then
					-- CDIV
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
			
			if HALT_n = '0' and pending = '1' then
				pending <= '0';
				speed <= speed_s;
				enable <= enable_s;
			end if;
		end if;
	end process;
	
	process (CLK_OSC, RESET_n)
	begin
		if RESET_n = '0' then
			CDIV_s <= x"0000";
			CLK_BUS_s <= '0';
			sub_divider <= '0';
			speed <= "00";
			speed_s <= "00";
			enable <= '1';
			enable_s <= '1';
			pending <= '0';
		elsif enable = '1' and rising_edge(CLK_OSC) then
			CDIV <= std_logic_vector(unsigned(CDIV_s) + 1);
			CDIV_s <= std_logic_vector(unsigned(CDIV_s) + 1);
			
			case speed is
				when "00" => CLK_BUS_s <= CDIV_s(0);
				when "01" => CLK_BUS_s <= CDIV_s(1);
				when "10" => CLK_BUS_s <= CDIV_s(2);
				when others => CLK_BUS_s <= sub_divider;
			end case;
		elsif enable = '0' then
			CLK_BUS_s <= sub_divider;
		end if;
	end process;
end rtl;