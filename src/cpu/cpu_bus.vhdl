-- HiveCraft Pilot24 Bus Controller (CPU_BUS)

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.hivecraft_cpu_pack.all;

entity hivecraft_cpu_bus is
	port (
		-- Clock
		CLK: in std_logic;
		
		-- Control signals
		RESET_n: in std_logic;
		WAIT_n: in std_logic;
		
		-- Buses
		addr: out std_logic_vector(23 downto 0);
		data_i: in std_logic_vector(15 downto 0);
		data_o: out std_logic_vector(15 downto 0);
		
		-- Outputs to CPU top level
		read_n: out std_logic;
		write_n: out std_logic;
		word_n: out std_logic;
		
		-- Inputs from MCD
		control: in cpu_bus_control_t;
		
		-- Inputs from ALU
		src1: in std_logic_vector(23 downto 0);
		src2: in std_logic_vector(23 downto 0);
		dest: in std_logic_vector(23 downto 0);
		
		-- Outputs to REG
		mar: out std_logic_vector(23 downto 0);
		mdr: out std_logic_vector(23 downto 0)
	);
end hivecraft_cpu_bus;

architecture rtl of hivecraft_cpu_bus is
	signal mar_s: std_logic_vector(23 downto 0);
	signal mdr_s: std_logic_vector(23 downto 0);
	signal cycle_type_s: cpu_bus_cycle_type_t;
begin
	-- Output ports that need to be readable
	mar <= mar_s;
	addr <= mar_s;
	mdr <= mdr_s;
	
	process (CLK, RESET_n) is
	begin
		if RESET_n = '0' then
			read_n <= '1';
			write_n <= '1';
			word_n <= '1';
			data_o <= x"0000";
			mar_s <= x"000000";
			mdr_s <= x"000000";
			cycle_type_s <= BUS_CYCLE_NONE;
		elsif rising_edge(CLK) then
			if WAIT_n = '1' then
				if cycle_type_s = BUS_CYCLE_READ_BYTE then
					mdr_s(7 downto 0) <= data_i(7 downto 0);
				elsif cycle_type_s = BUS_CYCLE_READ_WORD then
					mdr_s(15 downto 0) <= data_i;
				elsif cycle_type_s = BUS_CYCLE_READ_HIGH then
					mdr_s(23 downto 16) <= data_i(7 downto 0);
				end if;
				
				if control.mode_mar = BUS_ADDRESS_ALU_SRC1 then
					mar_s <= src1;
				end if;
				if control.mode_mdr = BUS_DATA_ALU_SRC2 then
					mdr_s <= src2;
				end if;
			end if;
		elsif falling_edge(CLK) then
			if WAIT_n = '1' then
				if control.mode_mar = BUS_ADDRESS_ALU_DEST then
					mar_s <= dest;
				end if;
				if control.mode_mdr = BUS_DATA_ALU_DEST then
					mdr_s <= dest;
				end if;
				
				case control.cycle_type is
					when BUS_CYCLE_NONE =>
						read_n <= '1';
						write_n <= '1';
						word_n <= '1';
						data_o <= x"0000";
					when BUS_CYCLE_READ_BYTE =>
						read_n <= '0';
						write_n <= '1';
						word_n <= '1';
						data_o <= x"0000";
					when BUS_CYCLE_READ_WORD =>
						read_n <= '0';
						write_n <= '1';
						word_n <= '0';
						data_o <= x"0000";
					when BUS_CYCLE_READ_HIGH =>
						read_n <= '0';
						write_n <= '1';
						word_n <= '1';
						data_o <= x"0000";
					when BUS_CYCLE_WRITE_BYTE =>
						read_n <= '1';
						write_n <= '0';
						word_n <= '1';
						data_o <= x"00" & mdr_s(7 downto 0);
					when BUS_CYCLE_WRITE_WORD =>
						read_n <= '1';
						write_n <= '0';
						word_n <= '0';
						data_o <= mdr_s(15 downto 0);
					when BUS_CYCLE_WRITE_HIGH =>
						read_n <= '1';
						write_n <= '0';
						word_n <= '1';
						data_o <= x"00" & mdr_s(23 downto 16);
				end case;
				
				cycle_type_s <= control.cycle_type;
			end if;
		end if;
	end process;
end rtl;
