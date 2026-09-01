-- HiveCraft Pilot24 Arithmetic Logic Unit (CPU_ALU)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.hivecraft_cpu_pack.all;

entity hivecraft_cpu_alu is
	port (
		-- Clock
		CLK: in std_logic;
		
		-- Control signals
		RESET_n: in std_logic;
		WAIT_n: in std_logic;
		control: in cpu_alu_control_t;
		
		-- Source values
		src1_i: in std_logic_vector(23 downto 0);
		src2_i: in std_logic_vector(23 downto 0);
		
		-- Source value outputs (for MAR/MDR latching)
		src1_o: out std_logic_vector(23 downto 0);
		src2_o: out std_logic_vector(23 downto 0);
		
		-- Destination value
		dest: out std_logic_vector(23 downto 0);
		
		-- Flag inputs
		aux_i: in std_logic;
		flags_i: in std_logic_vector(7 downto 0);
		
		-- Flag outputs
		aux_o: out std_logic;
		flags_o: out std_logic_vector(7 downto 0)
	);
end hivecraft_cpu_alu;

architecture rtl of hivecraft_cpu_alu is
	signal carry_i_s: std_logic;
	signal shifter_carry: std_logic;
	
	signal dest_s: unsigned(23 downto 0);
	signal aux_o_s: std_logic;
	signal flags_o_s: std_logic_vector(7 downto 0);
begin
	dest <= std_logic_vector(dest_s);
	aux_o <= aux_o_s;
	flags_o <= flags_o_s;
	
	process (control.mode_aux, control.mode_carry, aux_i, flags_i) is
	begin
		if control.mode_aux = ALU_AUX_CARRY then
			if control.mode_carry = ALU_CARRY_INVERT then
				carry_i_s <= not aux_i;
			else
				carry_i_s <= aux_i;
			end if;
		else
			if control.mode_carry = ALU_CARRY_INVERT then
				carry_i_s <= not flags_i(0);
			else
				carry_i_s <= flags_i(0);
			end if;
		end if;
	end process;
	
	process (CLK, RESET_n) is
		variable src1_int: unsigned(23 downto 0);
		variable src2_int: unsigned(23 downto 0);
	begin
		if RESET_n = '0' then
			src1_o <= x"000000";
			src2_o <= x"000000";
			shifter_carry <= '0';
			dest_s <= x"000000";
			aux_o_s <= '0';
			flags_o_s <= x"00";
		elsif rising_edge(CLK) then
			if WAIT_n = '1' then
				src1_int := unsigned(src1_i);
				
				-- Shift src2 if requested
				case control.src2_shift is
					when ALU_SHIFT_NONE =>
						src2_int := unsigned(src2_i);
						shifter_carry <= '0';
					when ALU_SHIFT_LEFT =>
						src2_int := shift_left(src2_int, 1);
						if control.src2.size = ALU_SIZE_BYTE then
							shifter_carry <= src2_int(7);
						elsif control.src2.size = ALU_SIZE_WORD then
							shifter_carry <= src2_int(15);
						else
							shifter_carry <= src2_int(23);
						end if;
					when ALU_SHIFT_LEFT_CARRY =>
						src2_int := shift_left(src2_int, 1);
						src2_int(0) := carry_i_s;
						if control.src2.size = ALU_SIZE_BYTE then
							shifter_carry <= src2_int(7);
						elsif control.src2.size = ALU_SIZE_WORD then
							shifter_carry <= src2_int(15);
						else
							shifter_carry <= src2_int(23);
						end if;
					when ALU_SHIFT_LEFT_BARREL =>
						src2_int := rotate_left(src2_int, 1);
						if control.src2.size = ALU_SIZE_BYTE then
							shifter_carry <= src2_int(7);
						elsif control.src2.size = ALU_SIZE_WORD then
							shifter_carry <= src2_int(15);
						else
							shifter_carry <= src2_int(23);
						end if;
					when ALU_SHIFT_RIGHT_LOGICAL =>
						src2_int := shift_right(src2_int, 1);
						shifter_carry <= src2_int(0);
					when ALU_SHIFT_RIGHT_ARITHMETIC =>
						src2_int := unsigned(shift_right(signed(src2_int), 1));
						shifter_carry <= src2_int(0);
					when ALU_SHIFT_RIGHT_CARRY =>
						src2_int := shift_right(src2_int, 1);
						if control.src2.size = ALU_SIZE_BYTE then
							src2_int(7) := carry_i_s;
						elsif control.src2.size = ALU_SIZE_WORD then
							src2_int(15) := carry_i_s;
						else
							src2_int(23) := carry_i_s;
						end if;
						shifter_carry <= src2_int(0);
					when ALU_SHIFT_RIGHT_BARREL =>
						src2_int := rotate_right(src2_int, 1);
						shifter_carry <= src2_int(0);
					when ALU_SHIFT_SWAP =>
						if control.src2.size = ALU_SIZE_BYTE then
							src2_int := x"0000" & src2_int(3 downto 0) & src2_int(7 downto 4);
						elsif control.src2.size = ALU_SIZE_WORD then
							src2_int := x"00" & src2_int(7 downto 0) & src2_int(15 downto 8);
						else
							src2_int := src2_int(7 downto 0) & src2_int(15 downto 8) & src2_int(23 downto 16);
						end if;
						shifter_carry <= '0';
				end case;
				
				-- Add the carry to src2 if requested
				if control.src2_add_carry and carry_i_s = '1' then
					src2_int := src2_int + 1;
				end if;
				
				-- Negate src2 if requested
				if control.src2_negate then
					src2_int := (not src2_int) + 1;
				end if;
				
				-- Gate src2 with the aux latch if requested
				if control.src2_aux_gate and aux_i = '0' then
					src2_int := x"000000";
				end if;
				
				-- Sign-extend the source operands if requested
				if control.src1.sign_extend then
					if control.src1.size = ALU_SIZE_BYTE then
						src1_int := unsigned(resize(signed(src1_int(7 downto 0)), 24));
					elsif control.src1.size = ALU_SIZE_WORD then
						src1_int := unsigned(resize(signed(src1_int(15 downto 0)), 24));
					end if;
				else
					if control.src1.size = ALU_SIZE_BYTE then
						src1_int := resize(src1_int(7 downto 0), 24);
					elsif control.src1.size = ALU_SIZE_WORD then
						src1_int := resize(src1_int(15 downto 0), 24);
					end if;
				end if;
				if control.src2.sign_extend then
					if control.src2.size = ALU_SIZE_BYTE then
						src2_int := unsigned(resize(signed(src2_int(7 downto 0)), 24));
					elsif control.src2.size = ALU_SIZE_WORD then
						src2_int := unsigned(resize(signed(src2_int(15 downto 0)), 24));
					end if;
				else
					if control.src2.size = ALU_SIZE_BYTE then
						src2_int := resize(src2_int(7 downto 0), 24);
					elsif control.src2.size = ALU_SIZE_WORD then
						src2_int := resize(src2_int(15 downto 0), 24);
					end if;
				end if;
				
				-- Set the source outputs
				src1_o <= std_logic_vector(src1_int);
				src2_o <= std_logic_vector(src2_int);
				
				-- Prepare the operation
				case control.operation is
					when ALU_OP_ADD =>
						dest_s <= src1_int + src2_int;
					when ALU_OP_AND =>
						dest_s <= src1_int and src2_int;
					when ALU_OP_OR =>
						dest_s <= src1_int or src2_int;
					when ALU_OP_XOR =>
						dest_s <= src1_int xor src2_int;
				end case;
			end if;
		elsif falling_edge(CLK) then
			if WAIT_n = '1' then
				-- todo: set flags according to dest_s
			end if;
		end if;
	end process;
end rtl;
