-- HiveCraft VHDL Core

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hivecraft is
	generic (
		-- HiveCraft's version
		HCVER: std_logic_vector(7 downto 0) := x"01"
	);
	port (
		-- Clocks
		CLK_OSC: in std_logic;
		CLK_SUB: in std_logic;
		
		-- Bus clock output
		CLK_BUS: out std_logic;
		
		-- Buses
		A: out std_logic_vector(23 downto 0);
		D: inout std_logic_vector(7 downto 0);
		
		-- Control signals
		RESET_n: in std_logic;
		RD_n: out std_logic;
		WR_n: out std_logic;
		PPUSEL_n: out std_logic;
		WRAMSEL_n: out std_logic;
		VRAMSEL_n: out std_logic;
		
		-- Hexridge interface
		EXT_n: in std_logic;
		CS1_n: out std_logic;
		CS2_n: out std_logic;
		ROMSEL_n: out std_logic;
		
		-- Link port
		SER_T: out std_logic;
		SER_TCLK: out std_logic;
		SER_TAUX: out std_logic;
		SER_R: in std_logic;
		SER_RCLK: in std_logic;
		SER_RAUX: in std_logic;
		
		-- Controller ports
		CON_R1: in std_logic;
		CON_R2: in std_logic;
		CON_R3: in std_logic;
		CON_CLK: out std_logic;
		CON_LATCH: out std_logic;
		
		-- Analog-to-digital converter (from a transmission gate, RC filter and Schmitt-trigger inverter)
		AD_IN_n: in std_logic_vector(3 downto 0);
		AD_SAMP_n: out std_logic_vector(3 downto 0);
		
		-- Audio output (PWM at 16 MHz, to a low-pass filter)
		AOUT_L: out std_logic;
		AOUT_R: out std_logic;
		
		-- Expansion audio enable (to mixer)
		XAEN_L_n: out std_logic;
		XAEN_R_n: out std_logic;
		
		-- Infrared port
		IR_R: in std_logic;
		IR_T: out std_logic;
		
		-- Console buttons
		NMI_n: in std_logic;
		BTN_n: in std_logic_vector(5 downto 0)
	);
end hivecraft;

architecture rtl of hivecraft is
	-- Internal bus clock
	signal CLK_BUS_s: std_logic := '0';
	
	-- Master clock divider
	signal sysdiv: std_logic_vector(15 downto 0);
	
	-- Bus latches
	signal A_s: std_logic_vector(23 downto 0) := x"000000";
	signal A_s_s: std_logic_vector(23 downto 0) := x"000000";
	signal RD_n_s: std_logic := '1';
	signal WR_n_s: std_logic := '1';
	signal CS1_n_s: std_logic := '1';
	signal CS2_n_s: std_logic := '1';
	signal ROMSEL_n_s: std_logic := '1';
	
	-- Is the access internal to the HiveCraft?
	signal internal_n: std_logic := '1';
	
	-- 16-bit bus control
	signal upper_byte_n: std_logic := '1';
	signal upper_byte_n_s: std_logic := '1';
	signal word_n: std_logic := '1';
	signal D_i_s: std_logic_vector(15 downto 0) := x"0000";
	signal D_o_s: std_logic_vector(15 downto 0) := x"0000";
	
	-- Bus master wait signal (either CPU, DMA1, or DMA2)
	signal bus_wait_n: std_logic := '1';
	
	-- Is an access waiting?
	signal wait_n: std_logic := '1';
	signal rom_waiting_n: std_logic := '1';
	signal cs1_waiting_n: std_logic := '1';
	signal cs2_waiting_n: std_logic := '1';
	
	-- Wait count latches
	signal rom_wait_s: std_logic_vector(2 downto 0) := "000";
	signal cs1_wait_s: std_logic_vector(2 downto 0) := "000";
	signal cs2_wait_s: std_logic_vector(2 downto 0) := "000";
	
	-- Wait counters
	signal rom_wait: std_logic_vector(2 downto 0) := "000";
	signal cs1_wait: std_logic_vector(2 downto 0) := "000";
	signal cs2_wait: std_logic_vector(2 downto 0) := "000";
	
	-- CPU's HALT signal (used for clock switching)
	signal cpu_HALT_n: std_logic := '1';
	
	-- IR signals
	signal ir_enable: std_logic := '0';
	signal IR_T_s: std_logic := '0';
begin
	clk: entity work.hivecraft_clk(rtl) port map (
		CLK_OSC => CLK_OSC,
		CLK_SUB => CLK_SUB,
		CLK_BUS => CLK_BUS_s,
		CDIV => sysdiv,
		A => A_s,
		D_i => D_i_s,
		D_o => D_o_s,
		RESET_n => RESET_n,
		RD_n => RD_n_s,
		WR_n => WR_n_s,
		WORD_n => word_n,
		HALT_n => cpu_HALT_n
	);
	
	ram: entity work.hivecraft_ram(rtl) port map (
		CLK => CLK_BUS_s,
		A => A_s,
		D_i => D_i_s,
		D_o => D_o_s,
		RD_n => RD_n_s,
		WR_n => WR_n_s,
		WORD_n => word_n
	);
	
	tim: entity work.hivecraft_tim(rtl) port map (
		SYSDIV => sysdiv,
		CLK_SUB => CLK_SUB,
		EXT_n => EXT_n,
		CLK_BUS => CLK_BUS_s,
		A => A_s,
		D_i => D_i_s,
		D_o => D_o_s,
		RESET_n => RESET_n,
		RD_n => RD_n_s,
		WR_n => WR_n_s,
		WORD_n => word_n --,
		-- TA_RELOAD_n => '1',
		-- TB_RELOAD_n => '1'
	);
	
	cpu: entity work.hivecraft_cpu(rtl) port map (
		CLK => CLK_BUS_s,
		NMI_n => NMI_n,
		IRQ_n => "0000000",
		--IACK_n => '1',
		A => A_s_s,
		D_i => D_i_s,
		D_o => D_o_s,
		RESET_n => RESET_n,
		RD_n => RD_n_s,
		WR_n => WR_n_s,
		WORD_n => word_n,
		WAIT_n => bus_wait_n,
		BUSRQ_n => '1',
		--BUSACK_n => '1',
		HALT_n => cpu_HALT_n
	);
	
	-- Assert wait_n if we're waiting on an external access
	wait_n <= rom_waiting_n and cs1_waiting_n and cs2_waiting_n;
	
	-- Output ports that need to be readable
	CLK_BUS <= CLK_BUS_s;
	
	IR_T <= IR_T_s;
	
	CS1_n <= CS1_n_s;
	CS2_n <= CS2_n_s;
	ROMSEL_n <= ROMSEL_n_s;
	
	RD_n <= RD_n_s;
	WR_n <= WR_n_s;
	
	-- Set bus_wait_n if the HiveCraft is either waiting on an access, or has only fetched one byte of a two-byte access
	process (RESET_n, wait_n, word_n, upper_byte_n_s, RD_n_s, WR_n_s)
	begin
		if RESET_n = '0' then
			bus_wait_n <= '1';
		else
			bus_wait_n <= (wait_n and (word_n or not upper_byte_n_s)) or (RD_n_s and WR_n_s);
		end if;
	end process;
	
	-- Set the chip selects according to the address bus's contents
	process (A_s)
		variable addr_int: integer range 0 to 16777215;
	begin
		addr_int := 0;
		
		PPUSEL_n <= '1';
		WRAMSEL_n <= '1';
		VRAMSEL_n <= '1';
		CS1_n_s <= '1';
		CS2_n_s <= '1';
		ROMSEL_n_s <= '1';
		internal_n <= '1';
		
		-- Prevent errors when the bus is in the high-impedance state
		if A_s(0) /= 'Z' and A_s(1) /= 'Z' then
			addr_int := to_integer(unsigned(A_s));
			
			case addr_int is
				when 0 to 32767 => WRAMSEL_n <= '0';
				when 32768 to 65535 => VRAMSEL_n <= '0';
				when 65536 to 1048575 => CS1_n_s <= '0';
				when 1048576 to 2097151 => CS2_n_s <= '0';
				when 2097152 to 16769023 => ROMSEL_n_s <= '0';
				when 16773760 to 16773887 => PPUSEL_n <= '0';
				when others => internal_n <= '0';
			end case;
		end if;
		
		A <= A_s;
	end process;
	
	-- Drive the address bus only if we're making an access -- its contents technically shouldn't matter during this time though
	process (A_s_s, RD_n_s, WR_n_s)
	begin
		if RD_n_s = '0' or WR_n_s = '0' then
			A_s(23 downto 1) <= A_s_s(23 downto 1);
		else
			A_s(23 downto 1) <= (others => 'Z');
		end if;
	end process;
	
	process (CLK_BUS_s, RESET_n, rom_wait_s, cs1_wait_s, cs2_wait_s)
	begin
		if RESET_n = '0' then
			upper_byte_n <= '1';
			rom_waiting_n <= '1';
			cs1_waiting_n <= '1';
			cs2_waiting_n <= '1';
			
			rom_wait <= rom_wait_s;
			cs1_wait <= cs1_wait_s;
			cs2_wait <= cs2_wait_s;
			
			D_i_s <= x"0000";
			D_o_s <= (others => 'Z');
		elsif rising_edge(CLK_BUS_s) then
			upper_byte_n_s <= upper_byte_n;
			
			-- Miscellaneous HiveCraft I/O registers
			if A_s = x"FFF330" then
				-- BUS_CTL (low)
				if RD_n_s = '0' then
					if word_n = '0' then
						D_i_s(15 downto 8) <= x"00";
					else
						D_i_s(15 downto 8) <= "00000" & cs2_wait_s;
					end if;
					D_i_s(7 downto 0) <= "0" & cs1_wait_s & "0" & rom_wait_s;
				elsif WR_n_s = '0' then
					if word_n = '0' then
						cs2_wait_s <= D_o_s(10 downto 8);
						cs2_wait <= D_o_s(10 downto 8);
					end if;
					cs1_wait_s <= D_o_s(6 downto 4);
					cs1_wait <= D_o_s(6 downto 4);
					rom_wait_s <= D_o_s(2 downto 0);
					rom_wait <= D_o_s(2 downto 0);
				end if;
			elsif A_s = x"FFF331" then
				-- BUS_CTL (high)
				if RD_n_s = '0' then
					D_i_s <= "0000000000000" & cs2_wait_s;
				elsif WR_n_s = '0' then
					cs2_wait_s <= D_o_s(2 downto 0);
				end if;
			elsif A_s = x"FFF332" then
				-- IR_CTL
				if RD_n_s = '0' then
					D_i_s <= x"00" & (IR_R and ir_enable) & "00000" & ir_enable & IR_T_s;
				elsif WR_n_s = '0' then
					ir_enable <= D_o_s(1);
					IR_T_s <= D_o_s(0);
				end if;
			elsif A_s = x"FFF334" and RD_n_s = '0' then
				-- CONSBTN
				D_i_s <= "0000000000" & BTN_n;
			elsif A_s = x"FFF33F" and RD_n_s = '0' then
				-- HCVER
				D_i_s <= x"00" & HCVER;
			end if;
			
			-- If the HiveCraft is waiting on a cartridge access, tick the corresponding wait state counter down
			if ROMSEL_n_s = '0' then
				if rom_wait = "000" then
					rom_wait <= rom_wait_s;
					rom_waiting_n <= '1';
				else
					rom_wait <= std_logic_vector(unsigned(rom_wait) - 1);
					rom_waiting_n <= '0';
				end if;
			elsif CS1_n_s = '0' then
				if cs1_wait = "000" then
					cs1_wait <= cs1_wait_s;
					cs1_waiting_n <= '1';
				else
					cs1_wait <= std_logic_vector(unsigned(cs1_wait) - 1);
					cs1_waiting_n <= '0';
				end if;
			elsif CS2_n_s = '0' then
				if cs2_wait = "000" then
					cs2_wait <= cs2_wait_s;
					cs2_waiting_n <= '1';
				else
					cs2_wait <= std_logic_vector(unsigned(cs2_wait) - 1);
					cs2_waiting_n <= '0';
				end if;
			elsif internal_n = '0' then
				-- Needed for every I/O device to make sure the data bus isn't being driven again
				D_i_s <= (others => 'Z');
			end if;
		elsif falling_edge(CLK_BUS_s) then
			upper_byte_n_s <= upper_byte_n;
			
			-- Handle external 16-bit accesses by turning them into 8-bit accesses
			if wait_n = '1' and internal_n = '1' then
				if RD_n_s = '0' then
					-- 16-bit reads: low byte from A_s_s, high byte from A_s_s + 1
					if upper_byte_n = '1' then
						D_i_s(7 downto 0) <= D;
						D_i_s(15 downto 8) <= x"00";
						if word_n = '0' then
							upper_byte_n <= '0';
							A_s(0) <= '1';
						else
							A_s(0) <= A_s_s(0);
						end if;
					else
						D_i_s(15 downto 8) <= D;
						upper_byte_n <= '1';
						A_s(0) <= '0';
					end if;
				elsif WR_n_s = '0' then
					-- 16-bit writes: low byte to A_s_s, high byte to A_s_s + 1
					if upper_byte_n = '1' then
						D <= D_o_s(7 downto 0);
						if word_n = '0' then
							upper_byte_n <= '0';
							A_s(0) <= '1';
						else
							A_s(0) <= A_s_s(0);
						end if;
					else
						D <= D_o_s(15 downto 8);
						upper_byte_n <= '1';
						A_s(0) <= '0';
					end if;
				end if;
				
				-- Drive the bidirectional data bus only if the HiveCraft is in the process of doing an external write
				if WR_n_s = '1' then
					D <= (others => 'Z');
				end if;
			elsif WR_n_s = '1' then
				D <= (others => 'Z');
			end if;
		end if;
	end process;
end rtl;