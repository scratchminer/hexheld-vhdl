-- HiveCraft Pilot24 Register File (CPU_REG)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.hivecraft_cpu_pack.all;

entity hivecraft_cpu_reg is
	port (
		-- Clock
		CLK: in std_logic;
		
		-- Reset signal
		RESET_n: in std_logic;
		
		-- Inputs from ALU
		dest: in std_logic_vector(23 downto 0);
		aux_i: in std_logic;
		flags_i: in std_logic_vector(7 downto 0);
		
		-- Outputs to ALU
		src1: out std_logic_vector(23 downto 0);
		src2: out std_logic_vector(23 downto 0);
		
		-- Outputs to ALU and SEQ
		aux_o: out std_logic;
		flags_o: out std_logic_vector(7 downto 0);
		
		-- Inputs from BUS
		mar: in std_logic_vector(23 downto 0);
		mdr: in std_logic_vector(23 downto 0);
		
		-- Inputs from DCD
		immword0: in std_logic_vector(15 downto 0);
		immword1: in std_logic_vector(15 downto 0);
		immword2: in std_logic_vector(15 downto 0);
		rm_high: in std_logic;
		pgc_inc_n: in std_logic;
		
		-- Output to DCD
		pgc: out std_logic_vector(23 downto 0);
		
		-- Input from IRH (interrupt request handler)
		irl_i: in std_logic_vector(2 downto 0);
		
		-- Output to IRH
		irl_o: out std_logic_vector(2 downto 0);
		
		-- Inputs from SEQ
		src1_location: in cpu_alu_data_src_t;
		src2_location: in cpu_alu_data_src_t;
		dest_location: in cpu_alu_data_dst_t
	);
end hivecraft_cpu_reg;

architecture rtl of hivecraft_cpu_reg is
	type gpr_t is array (0 to 7) of std_logic_vector(23 downto 0);
	signal gpr: gpr_t;
	signal pgc_s: unsigned(23 downto 0);
	signal repi: std_logic_vector(4 downto 0);
	signal repr: unsigned(2 downto 0);
	signal flags_o_s: std_logic_vector(7 downto 0);
	signal aux_o_s: std_logic;
	signal irl_o_s: std_logic_vector(2 downto 0);
	signal factor: std_logic_vector(23 downto 0);
	signal operand: std_logic_vector(23 downto 0);
begin
	flags_o <= flags_o_s;
	aux_o <= aux_o_s;
	irl_o <= irl_o_s;
	pgc <= std_logic_vector(pgc_s);
	
	process (CLK, RESET_n) is
		variable src1_is_sp: std_logic;
	begin
		if RESET_n = '0' then
			for i in 0 to 7 loop
				gpr(i) <= x"000000";
			end loop;
			pgc_s <= x"FFCFF0";
			repi <= "00000";
			repr <= "000";
			src1 <= x"000000";
			src2 <= x"000000";
			aux_o_s <= '0';
			flags_o_s <= x"00";
			irl_o_s <= "000";
			factor <= x"000000";
			operand <= x"000000";
			src1_is_sp := '0';
		elsif rising_edge(CLK) then
			-- Latch WF and the aux latch
			flags_o_s <= flags_i;
			aux_o_s <= aux_i;
			irl_o_s <= irl_i;
			
			-- Increment PGC if DCD signals for it
			if pgc_inc_n = '0' then
				pgc_s <= pgc_s + 2;
			end if;
			
			-- Read from src1's location, and check if it is SP
			case src1_location.location is
				when ALU_DATA_ZERO =>
					src1 <= x"000000";
					src1_is_sp := '0';
				when ALU_DATA_SIZE =>
					if src1_location.size = ALU_SIZE_BYTE then
						src1 <= x"000001";
					elsif src1_location.size = ALU_SIZE_WORD then
						src1 <= x"000002";
					else
						src1 <= x"000004";
					end if;
					src1_is_sp := '0';
				when ALU_DATA_NUMBITS =>
					if src1_location.size = ALU_SIZE_BYTE then
						src1 <= x"000008";
					elsif src1_location.size = ALU_SIZE_WORD then
						src1 <= x"000010";
					else
						src1 <= x"000018";
					end if;
					src1_is_sp := '0';
				when ALU_DATA_REG_R0 =>
					src1 <= gpr(0);
					src1_is_sp := '0';
				when ALU_DATA_REG_F =>
					src1 <= x"0000" & flags_i;
					src1_is_sp := '0';
				when ALU_DATA_REG_W =>
					src1 <= x"0000" & "00000" & irl_i;
					src1_is_sp := '0';
				when ALU_DATA_REG_WF =>
					src1 <= "00000" & irl_i & flags_i;
					src1_is_sp := '0';
				when ALU_DATA_REG_SP =>
					src1 <= gpr(7);
					src1_is_sp := '1';
				when ALU_DATA_REG_PGC =>
					src1 <= std_logic_vector(pgc_s);
					src1_is_sp := '0';
				when ALU_DATA_LATCH_REPI =>
					src1 <= x"0000" & "000" & repi;
					src1_is_sp := '0';
				when ALU_DATA_LATCH_REPR =>
					src1 <= x"0000" & "00000" & std_logic_vector(repr);
					src1_is_sp := '0';
				when ALU_DATA_LATCH_MAR =>
					src1 <= mar;
					src1_is_sp := '0';
				when ALU_DATA_LATCH_MDR =>
					src1 <= mdr;
					src1_is_sp := '0';
				when ALU_DATA_LATCH_FACTOR =>
					src1 <= factor;
					src1_is_sp := '0';
				when ALU_DATA_LATCH_OPERAND =>
					src1 <= operand;
					src1_is_sp := '0';
				when ALU_DATA_IMMWORD_0 =>
					src1 <= x"00" & immword0;
					src1_is_sp := '0';
				when ALU_DATA_IMMWORD_1 =>
					src1 <= x"00" & immword1;
					src1_is_sp := '0';
				when ALU_DATA_IMMWORD_2 =>
					src1 <= x"00" & immword2;
					src1_is_sp := '0';
				when ALU_DATA_IMMWORD_HML =>
					src1 <= immword0(7 downto 0) & immword1;
					src1_is_sp := '0';
				when ALU_DATA_IMMWORD_HML_RM =>
					src1 <= immword2(7 downto 0) & immword1;
					src1_is_sp := '0';
				when ALU_DATA_IMMWORD_SHORT_2_RM =>
					if rm_high = '1' then
						src1 <= x"00000" & immword0(11 downto 8);
					else
						src1 <= x"00000" & immword0(5 downto 2);
					end if;
					src1_is_sp := '0';
				when ALU_DATA_IMMWORD_0_REG_2_RM =>
					if rm_high = '1' then
						if src1_location.size = ALU_SIZE_BYTE then
							if immword0(4) = '1' then
								src1 <= x"0000" & gpr(to_integer(unsigned(immword0(3 downto 2))))(15 downto 8);
							else
								src1 <= x"0000" & gpr(to_integer(unsigned(immword0(3 downto 2))))(7 downto 0);
							end if;
						else
							src1 <= gpr(to_integer(unsigned(immword0(4 downto 2))));
						end if;
						if immword0(4 downto 2) = "111" then
							src1_is_sp := '1';
						else
							src1_is_sp := '0';
						end if;
					else
						if src1_location.size = ALU_SIZE_BYTE then
							if immword0(10) = '1' then
								src1 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(15 downto 8);
							else
								src1 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(7 downto 0);
							end if;
						else
							src1 <= gpr(to_integer(unsigned(immword0(10 downto 8))));
						end if;
						if immword0(10 downto 8) = "111" then
							src1_is_sp := '1';
						else
							src1_is_sp := '0';
						end if;
					end if;
				when ALU_DATA_IMMWORD_0_REG_8 =>
					if src1_location.size = ALU_SIZE_BYTE then
						if immword0(10) = '1' then
							src1 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(15 downto 8);
						else
							src1 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(7 downto 0);
						end if;
						src1_is_sp := '0';
					else
						src1 <= gpr(to_integer(unsigned(immword0(10 downto 8))));
						if immword0(10 downto 8) = "111" then
							src1_is_sp := '1';
						else
							src1_is_sp := '0';
						end if;
					end if;
				when ALU_DATA_IMMWORD_1_REG_2 =>
					if src1_location.size = ALU_SIZE_BYTE then
						if immword1(4) = '1' then
							src1 <= x"0000" & gpr(to_integer(unsigned(immword1(3 downto 2))))(15 downto 8);
						else
							src1 <= x"0000" & gpr(to_integer(unsigned(immword1(3 downto 2))))(7 downto 0);
						end if;
						src1_is_sp := '0';
					else
						src1 <= gpr(to_integer(unsigned(immword1(4 downto 2))));
						if immword1(4 downto 2) = "111" then
							src1_is_sp := '1';
						else
							src1_is_sp := '0';
						end if;
					end if;
				when ALU_DATA_IMMWORD_1_REG_8 =>
					if src1_location.size = ALU_SIZE_BYTE then
						if immword1(10) = '1' then
							src1 <= x"0000" & gpr(to_integer(unsigned(immword1(9 downto 8))))(15 downto 8);
						else
							src1 <= x"0000" & gpr(to_integer(unsigned(immword1(9 downto 8))))(7 downto 0);
						end if;
						src1_is_sp := '0';
					else
						src1 <= gpr(to_integer(unsigned(immword1(10 downto 8))));
						if immword1(10 downto 8) = "111" then
							src1_is_sp := '1';
						else
							src1_is_sp := '0';
						end if;
					end if;
				when ALU_DATA_IMMWORD_2_REG_8 =>
					if src1_location.size = ALU_SIZE_BYTE then
						if immword0(10) = '1' then
							src1 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(15 downto 8);
						else
							src1 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(7 downto 0);
						end if;
						src1_is_sp := '0';
					else
						src1 <= gpr(to_integer(unsigned(immword0(10 downto 8))));
						if immword0(10 downto 8) = "111" then
							src1_is_sp := '1';
						else
							src1_is_sp := '0';
						end if;
					end if;
				when ALU_DATA_REPR =>
					src1 <= gpr(to_integer(repr));
					if repr = "111" then
						src1_is_sp := '1';
					else
						src1_is_sp := '0';
					end if;
				when ALU_DATA_DMX_IMM =>
					src1 <= x"000000";
					src1(to_integer(unsigned(immword0(10 downto 8)))) <= '1';
					src1_is_sp := '0';
				when ALU_DATA_DMX_P0 =>
					src1 <= x"000000";
					src1(to_integer(unsigned(gpr(0)(10 downto 8)))) <= '1';
					src1_is_sp := '0';
			end case;
			
			-- Read from src2's location
			case src2_location.location is
				when ALU_DATA_ZERO =>
					src2 <= x"000000";
				when ALU_DATA_SIZE =>
					if src2_location.size = ALU_SIZE_BYTE then
						if src1_is_sp = '1' then
							src2 <= x"000002";
						else
							src2 <= x"000001";
						end if;
					elsif src2_location.size = ALU_SIZE_WORD then
						src2 <= x"000002";
					else
						src2 <= x"000004";
					end if;
				when ALU_DATA_NUMBITS =>
					if src2_location.size = ALU_SIZE_BYTE then
						src2 <= x"000008";
					elsif src2_location.size = ALU_SIZE_WORD then
						src2 <= x"000010";
					else
						src2 <= x"000018";
					end if;
				when ALU_DATA_REG_R0 =>
					src2 <= gpr(0);
				when ALU_DATA_REG_F =>
					src2 <= x"0000" & flags_i;
				when ALU_DATA_REG_W =>
					src2 <= x"0000" & "00000" & irl_i;
				when ALU_DATA_REG_WF =>
					src2 <= "00000" & irl_i & flags_i;
				when ALU_DATA_REG_SP =>
					src2 <= gpr(7);
				when ALU_DATA_REG_PGC =>
					src2 <= std_logic_vector(pgc_s);
				when ALU_DATA_LATCH_REPI =>
					src2 <= x"0000" & "000" & repi;
				when ALU_DATA_LATCH_REPR =>
					src2 <= x"0000" & "00000" & std_logic_vector(repr);
				when ALU_DATA_LATCH_MAR =>
					src2 <= mar;
				when ALU_DATA_LATCH_MDR =>
					src2 <= mdr;
				when ALU_DATA_LATCH_FACTOR =>
					src2 <= factor;
				when ALU_DATA_LATCH_OPERAND =>
					src2 <= operand;
				when ALU_DATA_IMMWORD_0 =>
					src2 <= x"00" & immword0;
				when ALU_DATA_IMMWORD_1 =>
					src2 <= x"00" & immword1;
				when ALU_DATA_IMMWORD_2 =>
					src2 <= x"00" & immword2;
				when ALU_DATA_IMMWORD_HML =>
					src2 <= immword0(7 downto 0) & immword1;
				when ALU_DATA_IMMWORD_HML_RM =>
					src2 <= immword2(7 downto 0) & immword1;
				when ALU_DATA_IMMWORD_SHORT_2_RM =>
					if rm_high = '1' then
						src2 <= x"00000" & immword0(11 downto 8);
					else
						src2 <= x"00000" & immword0(5 downto 2);
					end if;
				when ALU_DATA_IMMWORD_0_REG_2_RM =>
					if rm_high = '1' then
						if src2_location.size = ALU_SIZE_BYTE then
							if immword0(4) = '1' then
								src2 <= x"0000" & gpr(to_integer(unsigned(immword0(3 downto 2))))(15 downto 8);
							else
								src2 <= x"0000" & gpr(to_integer(unsigned(immword0(3 downto 2))))(7 downto 0);
							end if;
						else
							src2 <= gpr(to_integer(unsigned(immword0(4 downto 2))));
						end if;
					else
						if src2_location.size = ALU_SIZE_BYTE then
							if immword0(10) = '1' then
								src2 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(15 downto 8);
							else
								src2 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(7 downto 0);
							end if;
						else
							src2 <= gpr(to_integer(unsigned(immword0(10 downto 8))));
						end if;
					end if;
				when ALU_DATA_IMMWORD_0_REG_8 =>
					if src2_location.size = ALU_SIZE_BYTE then
						if immword0(10) = '1' then
							src2 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(15 downto 8);
						else
							src2 <= x"0000" & gpr(to_integer(unsigned(immword0(9 downto 8))))(7 downto 0);
						end if;
					else
						src2 <= gpr(to_integer(unsigned(immword0(10 downto 8))));
					end if;
				when ALU_DATA_IMMWORD_1_REG_2 =>
					if src2_location.size = ALU_SIZE_BYTE then
						if immword1(4) = '1' then
							src2 <= x"0000" & gpr(to_integer(unsigned(immword1(3 downto 2))))(15 downto 8);
						else
							src2 <= x"0000" & gpr(to_integer(unsigned(immword1(3 downto 2))))(7 downto 0);
						end if;
					else
						src2 <= gpr(to_integer(unsigned(immword1(4 downto 2))));
					end if;
				when ALU_DATA_IMMWORD_1_REG_8 =>
					if src2_location.size = ALU_SIZE_BYTE then
						if immword1(10) = '1' then
							src2 <= x"0000" & gpr(to_integer(unsigned(immword1(9 downto 8))))(15 downto 8);
						else
							src2 <= x"0000" & gpr(to_integer(unsigned(immword1(9 downto 8))))(7 downto 0);
						end if;
					else
						src2 <= gpr(to_integer(unsigned(immword1(10 downto 8))));
					end if;
				when ALU_DATA_IMMWORD_2_REG_8 =>
					if src2_location.size = ALU_SIZE_BYTE then
						if immword2(10) = '1' then
							src2 <= x"0000" & gpr(to_integer(unsigned(immword2(9 downto 8))))(15 downto 8);
						else
							src2 <= x"0000" & gpr(to_integer(unsigned(immword2(9 downto 8))))(7 downto 0);
						end if;
					else
						src2 <= gpr(to_integer(unsigned(immword2(10 downto 8))));
					end if;
				when ALU_DATA_REPR =>
					src2 <= gpr(to_integer(repr));
				when ALU_DATA_DMX_IMM =>
					src2 <= x"000000";
					src2(to_integer(unsigned(immword0(10 downto 8)))) <= '1';
				when ALU_DATA_DMX_P0 =>
					src2 <= x"000000";
					src2(to_integer(unsigned(gpr(0)(10 downto 8)))) <= '1';
			end case;
		elsif falling_edge(CLK) then
			-- Write to dest's location
			if dest_location.location = ALU_DATA_REG_R0 then
				if dest_location.size = ALU_SIZE_BYTE then
					gpr(0)(7 downto 0) <= dest(7 downto 0);
				elsif dest_location.size = ALU_SIZE_WORD then
					gpr(0)(15 downto 0) <= dest(15 downto 0);
				else
					gpr(0) <= dest;
				end if;
			elsif dest_location.location = ALU_DATA_REG_F then
				flags_o_s <= dest(7 downto 0);
			elsif dest_location.location = ALU_DATA_REG_W then
				irl_o_s <= dest(2 downto 0);
			elsif dest_location.location = ALU_DATA_REG_WF then
				flags_o_s <= dest(7 downto 0);
				irl_o_s <= dest(10 downto 8);
			elsif dest_location.location = ALU_DATA_REG_SP then
				if dest_location.size = ALU_SIZE_BYTE then
					gpr(7)(7 downto 0) <= dest(7 downto 0);
				elsif dest_location.size = ALU_SIZE_WORD then
					gpr(7)(15 downto 0) <= dest(15 downto 0);
				else
					gpr(7) <= dest;
				end if;
			elsif dest_location.location = ALU_DATA_REG_PGC then
				if dest_location.size = ALU_SIZE_BYTE then
					-- RST branches are handled by writing a single byte to PGC
					pgc_s <= x"FFD000";
					pgc_s(11 downto 4) <= unsigned(dest(7 downto 0));
				else
					pgc_s <= unsigned(dest(23 downto 1) & '0');
				end if;
			elsif dest_location.location = ALU_DATA_LATCH_REPI then
				repi <= dest(4 downto 0);
			elsif dest_location.location = ALU_DATA_LATCH_REPR then
				repr <= unsigned(dest(2 downto 0));
			elsif dest_location.location = ALU_DATA_LATCH_FACTOR then
				if dest_location.size = ALU_SIZE_BYTE then
					factor <= x"0000" & dest(7 downto 0);
				elsif dest_location.size = ALU_SIZE_WORD then
					factor <= x"00" & dest(15 downto 0);
				else
					factor <= dest;
				end if;
			elsif dest_location.location = ALU_DATA_LATCH_OPERAND then
				if dest_location.size = ALU_SIZE_BYTE then
					operand <= x"0000" & dest(7 downto 0);
				elsif dest_location.size = ALU_SIZE_WORD then
					operand <= x"00" & dest(15 downto 0);
				else
					operand <= dest;
				end if;
			elsif dest_location.location = ALU_DATA_IMMWORD_0_REG_2_RM then
				if rm_high = '1' then
					if dest_location.size = ALU_SIZE_BYTE then
						if immword0(4) = '1' then
							gpr(to_integer(unsigned(immword0(3 downto 2))))(15 downto 8) <= dest(7 downto 0);
						else
							gpr(to_integer(unsigned(immword0(3 downto 2))))(7 downto 0) <= dest(7 downto 0);
						end if;
					elsif dest_location.size = ALU_SIZE_WORD then
						gpr(to_integer(unsigned(immword0(4 downto 2))))(15 downto 0) <= dest(15 downto 0);
					else
						gpr(to_integer(unsigned(immword0(4 downto 2)))) <= dest;
					end if;
				else
					if dest_location.size = ALU_SIZE_BYTE then
						if immword0(10) = '1' then
							gpr(to_integer(unsigned(immword0(9 downto 8))))(15 downto 8) <= dest(7 downto 0);
						else
							gpr(to_integer(unsigned(immword0(9 downto 8))))(7 downto 0) <= dest(7 downto 0);
						end if;
					elsif dest_location.size = ALU_SIZE_WORD then
						gpr(to_integer(unsigned(immword0(10 downto 8))))(15 downto 0) <= dest(15 downto 0);
					else
						gpr(to_integer(unsigned(immword0(10 downto 8)))) <= dest;
					end if;
				end if;
			elsif dest_location.location = ALU_DATA_IMMWORD_0_REG_8 then
				if dest_location.size = ALU_SIZE_BYTE then
					if immword0(10) = '1' then
						gpr(to_integer(unsigned(immword0(9 downto 8))))(15 downto 8) <= dest(7 downto 0);
					else
						gpr(to_integer(unsigned(immword0(9 downto 8))))(7 downto 0) <= dest(7 downto 0);
					end if;
				elsif dest_location.size = ALU_SIZE_WORD then
					gpr(to_integer(unsigned(immword0(10 downto 8))))(15 downto 0) <= dest(15 downto 0);
				else
					gpr(to_integer(unsigned(immword0(10 downto 8)))) <= dest;
				end if;
			elsif dest_location.location = ALU_DATA_IMMWORD_1_REG_2 then
				if dest_location.size = ALU_SIZE_BYTE then
					if immword1(4) = '1' then
						gpr(to_integer(unsigned(immword1(3 downto 2))))(15 downto 8) <= dest(7 downto 0);
					else
						gpr(to_integer(unsigned(immword1(3 downto 2))))(7 downto 0) <= dest(7 downto 0);
					end if;
				elsif dest_location.size = ALU_SIZE_WORD then
					gpr(to_integer(unsigned(immword1(4 downto 2))))(15 downto 0) <= dest(15 downto 0);
				else
					gpr(to_integer(unsigned(immword1(4 downto 2)))) <= dest;
				end if;
			elsif dest_location.location = ALU_DATA_IMMWORD_1_REG_8 then
				if dest_location.size = ALU_SIZE_BYTE then
					if immword1(10) = '1' then
						gpr(to_integer(unsigned(immword1(9 downto 8))))(15 downto 8) <= dest(7 downto 0);
					else
						gpr(to_integer(unsigned(immword1(9 downto 8))))(7 downto 0) <= dest(7 downto 0);
					end if;
				elsif dest_location.size = ALU_SIZE_WORD then
					gpr(to_integer(unsigned(immword1(10 downto 8))))(15 downto 0) <= dest(15 downto 0);
				else
					gpr(to_integer(unsigned(immword1(10 downto 8)))) <= dest;
				end if;
			elsif dest_location.location = ALU_DATA_IMMWORD_2_REG_8 then
				if dest_location.size = ALU_SIZE_BYTE then
					if immword2(10) = '1' then
						gpr(to_integer(unsigned(immword2(9 downto 8))))(15 downto 8) <= dest(7 downto 0);
					else
						gpr(to_integer(unsigned(immword2(9 downto 8))))(7 downto 0) <= dest(7 downto 0);
					end if;
				elsif dest_location.size = ALU_SIZE_WORD then
					gpr(to_integer(unsigned(immword2(10 downto 8))))(15 downto 0) <= dest(15 downto 0);
				else
					gpr(to_integer(unsigned(immword2(10 downto 8)))) <= dest;
				end if;
			elsif dest_location.location = ALU_DATA_REPR then
				gpr(to_integer(repr)) <= dest;
			end if;
		end if;
	end process;
end rtl;
