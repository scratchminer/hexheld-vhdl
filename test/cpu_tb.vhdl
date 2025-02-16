library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity cpu_tb is
end cpu_tb;

architecture testbench of cpu_tb is
	signal CLK_OSC: std_logic := '0';
	signal CLK_SUB: std_logic := '0';
	
	signal CLK_BUS: std_logic := '0';
	
	signal A: std_logic_vector(23 downto 0);
	signal D: std_logic_vector(7 downto 0) := "ZZZZZZZZ";
	
	signal RESET_n: std_logic := '0';
	signal RD_n: std_logic;
	signal WR_n: std_logic;
	
	signal ROMSEL_n: std_logic;
	
	signal step: std_logic_vector(1 downto 0) := "00";
begin
	dut: entity work.hivecraft(rtl) port map (
		CLK_OSC => CLK_OSC,
		CLK_SUB => CLK_SUB,
		
		CLK_BUS => CLK_BUS,
		
		A => A,
		D => D,
		RESET_n => RESET_n,
		RD_n => RD_n,
		WR_n => WR_n,
		--PPUSEL_n => '1',
		--WRAMSEL_n => '1',
		--VRAMSEL_n => '1',
		
		EXT_n => '1',
		--CS1_n => '1',
		--CS2_n => '1',
		ROMSEL_n => ROMSEL_n,
		
		--SER_T => '0',
		--SER_TCLK => '0',
		--SER_TAUX => '0',
		SER_R => '0',
		SER_RCLK => '0',
		SER_RAUX => '0',
		
		CON_R1 => '0',
		CON_R2 => '0',
		CON_R3 => '0',
		--CON_CLK => '0',
		--CON_LATCH => '0',
		
		--AOUT_L => '0',
		--AOUT_R => '0',
		
		IR_R => '0',
		--IR_T => '0',
		
		NMI_n => '1',
		BTN_n => "000000"
	);
	
	CLK_OSC <= not CLK_OSC after 31.25 ns;
	CLK_SUB <= not CLK_SUB after 15.2587890625 us;
	
	process
	begin
		wait for 400 ns;
		RESET_n <= '1';
		report "RESET";
		wait;
	end process;
	
	process (CLK_BUS)
		-- from https://github.com/texane/vhdl
		function hstr(slv: std_logic_vector; size: integer) return string is
				variable hexlen: integer;
				variable longslv : std_logic_vector((size + 3) downto 0):=(others => '0');
				variable hex : string(1 to size);
				variable fourbit : std_logic_vector(3 downto 0);
			begin
				hexlen:=(slv'left+1)/4;
				if (slv'left+1) mod 4/=0 then
					hexlen := hexlen + 1;
				end if;
				longslv(slv'left downto 0) := slv;
				for i in (hexlen-1) downto 0 loop
					fourbit:=longslv(((i*4)+3) downto (i*4));
					case fourbit is
						when "0000" => hex(hexlen-I):='0';
						when "0001" => hex(hexlen-I):='1';
						when "0010" => hex(hexlen-I):='2';
						when "0011" => hex(hexlen-I):='3';
						when "0100" => hex(hexlen-I):='4';
						when "0101" => hex(hexlen-I):='5';
						when "0110" => hex(hexlen-I):='6';
						when "0111" => hex(hexlen-I):='7';
						when "1000" => hex(hexlen-I):='8';
						when "1001" => hex(hexlen-I):='9';
						when "1010" => hex(hexlen-I):='A';
						when "1011" => hex(hexlen-I):='B';
						when "1100" => hex(hexlen-I):='C';
						when "1101" => hex(hexlen-I):='D';
						when "1110" => hex(hexlen-I):='E';
						when "1111" => hex(hexlen-I):='F';
						when "ZZZZ" => hex(hexlen-I):='Z';
						when "UUUU" => hex(hexlen-I):='U';
						when "XXXX" => hex(hexlen-I):='X';
						when others => hex(hexlen-I):='?';
					end case;
				end loop;
			return hex(1 to hexlen);
		end function hstr;
	begin
		if rising_edge(CLK_BUS) then
			if ROMSEL_n = '0' then
				if WR_n = '0' then
					step <= std_logic_vector(unsigned(step) + 1);
					report "WR " & hstr(D, 8) & " -> " & hstr(A, 24);
				elsif RD_n = '0' then
					if step = "00" then
						D <= x"00";
					elsif step = "01" then
						D <= x"44";
					elsif step = "10" then
						D <= x"88";
					elsif step = "11" then
						D <= x"CC";
					end if;
					
					step <= std_logic_vector(unsigned(step) + 1);
					report "RD " & hstr(A, 24);
				end if;
			end if;
		end if;
	end process;
end testbench;