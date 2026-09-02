-- HiveCraft Pilot24 (CPU)

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.hivecraft_cpu_pack.all;

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
		BUSREQ_n: in std_logic;
		BUSACK_n: out std_logic;
		HALT_n: out std_logic
	);
end hivecraft_cpu;

architecture rtl of hivecraft_cpu is
	-- temporary
	constant mcd_default: cpu_mcd_entry_t := (
		entry_type => MCD_NOP,
		inst_size => ALU_SIZE_POINTER,
		cycle_type => BUS_CYCLE_NONE
	);
	
	-- Bus latches
	signal D_o_s: std_logic_vector(15 downto 0);
	signal WR_n_s: std_logic;
	
	-- Interconnects
	signal alu_src1_i: std_logic_vector(23 downto 0) := x"000000";
	signal alu_src2_i: std_logic_vector(23 downto 0) := x"000000";
	signal alu_src1_o: std_logic_vector(23 downto 0);
	signal alu_src2_o: std_logic_vector(23 downto 0);
	signal alu_dest: std_logic_vector(23 downto 0);
	
	signal bus_read_n: std_logic;
	signal bus_write_n: std_logic;
	signal bus_word_n: std_logic;
	signal bus_addr: std_logic_vector(23 downto 0);
	signal bus_data_o: std_logic_vector(15 downto 0);
	signal bus_mar: std_logic_vector(23 downto 0);
	signal bus_mdr: std_logic_vector(23 downto 0);
	
	signal dcd_branch_n: std_logic;
	signal dcd_branch_addr: std_logic_vector(23 downto 0);
	
	signal mcd_alu_ctrl: cpu_alu_control_t;
	signal mcd_reg_ctrl: std_logic_vector(7 downto 0);
	signal mcd_bus_ctrl: cpu_bus_control_t;
	signal mcd_seq_ctrl: cpu_seq_control_t;
	
	signal pfq_read_n: std_logic;
	signal pfq_word_n: std_logic;
	signal pfq_word_ready_n: std_logic;
	signal pfq_addr: std_logic_vector(23 downto 0);
	signal pfq_data_o: std_logic_vector(15 downto 0);
begin
	cpu_alu: entity work.hivecraft_cpu_alu(rtl) port map (
		CLK => CLK,
		RESET_n => RESET_n,
		WAIT_n => WAIT_n,
		control => mcd_alu_ctrl,
		src1_i => alu_src1_i,
		src2_i => alu_src2_i,
		src1_o => alu_src1_o,
		src2_o => alu_src2_o,
		dest => alu_dest,
		aux_i => '0',
		flags_i => x"00"
		-- aux_o => reg_aux_i,
		-- flags_o => reg_flags_i
	);
	
	cpu_bus: entity work.hivecraft_cpu_bus(rtl) port map (
		CLK => CLK,
		RESET_n => RESET_n,
		WAIT_n => WAIT_n,
		addr => bus_addr,
		data_i => D_i,
		data_o => bus_data_o,
		read_n => bus_read_n,
		write_n => bus_write_n,
		word_n => bus_word_n,
		control => mcd_bus_ctrl,
		src1 => alu_src1_o,
		src2 => alu_src2_o,
		dest => alu_dest,
		mar => bus_mar,
		mdr => bus_mdr
	);
	
	cpu_mcd: entity work.hivecraft_cpu_mcd(rtl) port map (
		WAIT_n => WAIT_n,
		addr => mcd_default,
		alu_ctrl => mcd_alu_ctrl,
		reg_ctrl => mcd_reg_ctrl,
		bus_ctrl => mcd_bus_ctrl,
		seq_ctrl => mcd_seq_ctrl
	);
	
	cpu_pfq: entity work.hivecraft_cpu_pfq(rtl) port map (
		CLK => CLK,
		RESET_n => RESET_n,
		WAIT_n => WAIT_n,
		addr_i => dcd_branch_addr,
		addr_o => pfq_addr,
		data_i => D_i,
		data_o => pfq_data_o,
		read_n => pfq_read_n,
		word_n => pfq_word_n,
		branch_n => dcd_branch_n,
		hold_n => '0',
		word_ready_n => pfq_word_ready_n
	);
	
	-- Output port that needs to be readable
	WR_n <= WR_n_s;
	
	process (RESET_n, pfq_read_n, pfq_word_n, pfq_addr, bus_read_n, bus_write_n, bus_word_n, bus_addr) is
	begin
		-- BUS takes bus priority, then PFQ
		if RESET_n = '0' then
			RD_n <= '1';
			WR_n_s <= '1';
			WORD_n <= '1';
		elsif bus_read_n = '0' or bus_write_n = '0' then
			A <= bus_addr;
			RD_n <= bus_read_n;
			WR_n_s <= bus_write_n;
			WORD_n <= bus_word_n;
		elsif pfq_read_n = '0' then
			A <= pfq_addr;
			RD_n <= pfq_read_n;
			WR_n_s <= '1';
			WORD_n <= pfq_word_n;
		else
			RD_n <= '1';
			WR_n_s <= '1';
			WORD_n <= '1';
		end if;
	end process;
	
	process (CLK, RESET_n) is
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
