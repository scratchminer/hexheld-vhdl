-- HiveCraft High RAM (RAM)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hivecraft_ram is
	port (
		-- Clock
		CLK: in std_logic;
		
		-- Buses
		A: in std_logic_vector(23 downto 0);
		D_i: out std_logic_vector(15 downto 0);
		D_o: in std_logic_vector(15 downto 0);
		
		-- Control signals
		RD_n: in std_logic;
		WR_n: in std_logic;
		WORD_n: in std_logic
	);
end hivecraft_ram;

architecture rtl of hivecraft_ram is
	type hram_t is array (0 to 1535) of std_logic_vector(15 downto 0);
	signal hram: hram_t;
begin
	process (CLK)
		variable addr_int: integer range 0 to 16777215;
	begin
		if rising_edge(CLK) then
			if A(0) /= 'Z' and A(1) /= 'Z' then
				if WORD_n = '0' then
					addr_int := to_integer(unsigned(A and x"FFFFFE"));
				else
					addr_int := to_integer(unsigned(A));
				end if;
				
				if addr_int >= 16774144 then
					if WR_n = '0' then
						if WORD_n = '0' then
							hram(addr_int - 16774144) <= D_o;
						else
							if A(0) = '0' then
								hram(addr_int - 16774144)(7 downto 0) <= D_o(7 downto 0);
							else
								hram(addr_int - 16774144)(15 downto 8) <= D_o(7 downto 0);
							end if;
						end if;
					elsif RD_n = '0' then
						if WORD_n = '0' then
							D_i <= hram(addr_int - 16774144);
						else
							if A(0) = '0' then
								D_i <= x"00" & hram(addr_int - 16774144)(7 downto 0);
							else
								D_i <= x"00" & hram(addr_int - 16774144)(15 downto 8);
							end if;
						end if;
					else
						D_i <= (others => 'Z');
					end if;
				else
					D_i <= (others => 'Z');
				end if;
			else
				addr_int := 0;
				D_i <= (others => 'Z');
			end if;
		end if;
	end process;
end rtl;