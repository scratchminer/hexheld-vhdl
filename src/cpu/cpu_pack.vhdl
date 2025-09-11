-- HiveCraft Pilot24 (CPU) shared package

library ieee;
use ieee.std_logic_1164.all;

package hivecraft_cpu_pack is
	type cpu_alu_data_size_t is (SIZE_BYTE, SIZE_WORD, SIZE_POINTER);
	type cpu_alu_data_location_t is (
		-- Zero
		DATA_ZERO,
		-- Current ALU destination size
		DATA_SIZE,
		-- 8, 16, or 24, depending on the current ALU destination size
		DATA_NUMBITS,
		-- L0, W0, or P0, depending on the current ALU destination size
		DATA_REG_R0,
		-- Lower half flags
		DATA_REG_F,
		-- Upper half flags
		DATA_REG_W,
		-- Flags
		DATA_REG_WF,
		-- Easy P7 access
		DATA_REG_SP,
		-- Program counter
		DATA_REG_PGC,
		-- REPI state (REPI / MULU / MULS / DIVU / DIVS)
		DATA_LATCH_REPI,
		-- REPR state
		DATA_LATCH_REPR,
		-- Memory address register
		DATA_LATCH_MAR,
		-- Memory data register
		DATA_LATCH_MDR,
		-- Factor latch (MULU / MULS)
		DATA_MULDIV_FACTOR,
		-- Operand latch (MULU / MULS / DIVU / DIVS)
		DATA_MULDIV_OPERAND,
		-- Instruction word
		DATA_IMMWORD_0,
		-- Immediate word 1
		DATA_IMMWORD_1,
		-- Immediate word 2
		DATA_IMMWORD_2,
		-- Immediate HML (H = LSB of immediate word 0)
		DATA_IMMWORD_HML,
		-- Immediate HML (H = LSB of immediate word 2)
		DATA_IMMWORD_HML_RM,
		-- Bits 2-5 of the instruction word
		DATA_IMMWORD_SHORT_2,
		-- Bits 8-11 of the instruction word
		DATA_IMMWORD_SHORT_8,
		-- Immediate word following any extra words for first RM operand
		DATA_RM2WORD_1,
		-- Immediate word following DATA_RM2WORD_1
		DATA_RM2WORD_2,
		-- Immediate HML (H = LSB of DATA_RM2WORD_2)
		DATA_RM2WORD_HML_RM,
		-- Register pointed to by bits 2-4 of the instruction word
		DATA_IMMWORD_0_REG_2,
		-- Register pointed to by bits 8-10 of the instruction word
		DATA_IMMWORD_0_REG_8,
		-- Register pointed to by bits 2-4 of immediate word 1
		DATA_IMMWORD_1_REG_2,
		-- Register pointed to by bits 8-10 of immediate word 1
		DATA_IMMWORD_1_REG_8,
		-- Register pointed to by bits 8-10 of immediate word 2
		DATA_IMMWORD_2_REG_8,
		-- Register pointed to by bits 2-4 of DATA_RM2WORD_1
		DATA_RM2WORD_1_REG_2,
		-- Register pointed to by bits 8-10 of DATA_RM2WORD_1
		DATA_RM2WORD_1_REG_8,
		-- Register pointed to by bits 8-10 of DATA_RM2WORD_2
		DATA_RM2WORD_2_REG_8,
		-- Register pointed to by the REPR state
		DATA_REPR,
		-- Outputs from a 3-to-8 demultiplexer hooked up to bits 8-10 of the instruction word
		DATA_DMX_IMM,
		-- Outputs from a 3-to-8 demultiplexer hooked up to bits 8-10 of the P0 register
		DATA_DMX_P0
	);
	type cpu_alu_operation_t is (ALU_ADD, ALU_AND, ALU_OR, ALU_XOR);
	type cpu_alu_shift_operation_t is (
		-- ABCDEFGH to ABCDEFGH; carry out = 0
		ALU_SHIFT_NONE,
		-- ABCDEFGH to BCDEFGH0; carry out = A
		ALU_SHIFT_LEFT,
		-- ABCDEFGH to BCDEFGHX; carry out = A
		ALU_SHIFT_LEFT_CARRY,
		-- ABCDEFGH to BCDEFGHA; carry out = 0
		ALU_SHIFT_LEFT_BARREL,
		-- ABCDEFGH to 0ABCDEFG; carry out = H
		ALU_SHIFT_RIGHT_LOGICAL,
		-- ABCDEFGH to AABCDEFG; carry out = H
		ALU_SHIFT_RIGHT_ARITHMETIC,
		-- ABCDEFGH to XABCDEFG; carry out = H
		ALU_SHIFT_RIGHT_CARRY,
		-- ABCDEFGH to HABCDEFG; carry out = 0
		ALU_SHIFT_RIGHT_BARREL,
		-- ABCDEFGH to EFGHABCD; carry out = 0
		ALU_SHIFT_SWAP
	);
	type cpu_alu_aux_mode_t is (
		-- Do not write the aux latch
		ALU_AUX_NONE,
		-- Clear the aux latch
		ALU_AUX_CLEAR,
		-- Write the ALU zero flag to the aux latch
		ALU_AUX_ZERO,
		-- Write the ALU carry flag to the aux latch
		ALU_AUX_CARRY
	);
	type cpu_alu_carry_mode_t is (
		-- Write to the ALU carry flag normally
		ALU_CARRY_NORMAL,
		-- Write an inverted carry output to the ALU carry flag
		ALU_CARRY_INVERT
	);
	type cpu_alu_zero_mode_t is (
		-- Write to the ALU zero flag normally
		ALU_ZERO_NORMAL,
		-- AND the current ALU zero flag with a zero flag based on the ALU result
		ALU_ZERO_ACCUMULATE,
		-- Write to the ALU zero flag based on a bitwise AND of the two ALU sources
		ALU_ZERO_TEST
	);
	type cpu_alu_overflow_mode_t is (
		-- Write to the ALU overflow flag normally
		ALU_OVERFLOW_NORMAL,
		-- Clear the ALU overflow flag
		ALU_OVERFLOW_CLEAR,
		-- OR the current ALU overflow flag with an overflow flag based on the ALU result
		ALU_OVERFLOW_ACCUMULATE,
		-- Write the ALU shifter carry to the ALU overflow flag
		ALU_OVERFLOW_CARRY
	);
	
	type cpu_alu_data_src_t is record
		size: cpu_alu_data_size_t;
		location: cpu_alu_data_location_t;
		sign_extend: std_logic;
	end record cpu_alu_data_src_t;
	type cpu_alu_data_dst_t is record
		size: cpu_alu_data_size_t;
		location: cpu_alu_data_location_t;
	end record cpu_alu_data_dst_t;
	type cpu_alu_control_t is record
		operation: cpu_alu_operation_t;
		src1: cpu_alu_data_src_t;
		src2: cpu_alu_data_src_t;
		src2_shift: cpu_alu_shift_operation_t;
		src2_add_carry: boolean;
		src2_negate: boolean;
		src2_aux_gate: boolean;
		dest: cpu_alu_data_dst_t;
		mode_aux: cpu_alu_aux_mode_t;
		mode_carry: cpu_alu_carry_mode_t;
		mode_zero: cpu_alu_zero_mode_t;
		mode_overflow: cpu_alu_overflow_mode_t;
	end record cpu_alu_control_t;
	
	type cpu_bus_address_mode_t is (
		-- Do not write to MAR
		BUS_ADDRESS_NONE,
		-- Write the ALU's first operand to MAR in the first half of the cycle
		BUS_ADDRESS_ALU_SRC1,
		-- Write the ALU's result to MAR in the second half of the cycle
		BUS_ADDRESS_ALU_DEST
	);
	type cpu_bus_data_mode_t is (
		-- Do not write to MDR
		BUS_DATA_NONE,
		-- Write the ALU's second operand to MDR in the first half of the cycle
		BUS_DATA_ALU_SRC2,
		-- Write the ALU's result to MDR in the second half of the cycle
		BUS_DATA_ALU_DEST,
		-- Shift the existing MDR value right 16 bits, so $AABBCC becomes $0000AA
		BUS_DATA_SHIFT
	);
	type cpu_bus_cycle_type_t is (
		-- Ignore the data bus
		BUS_CYCLE_NONE,
		-- Read the lower 8 bits of the data bus into the lower 8 bits of MDR
		BUS_CYCLE_READ_BYTE,
		-- Read the data bus into the lower 16 bits of MDR
		BUS_CYCLE_READ_WORD,
		-- Write the lower 8 bits of MDR to the lower 8 bits of the data bus
		BUS_CYCLE_WRITE_BYTE,
		-- Write the lower 16 bits of MDR to the data bus
		BUS_CYCLE_WRITE_WORD
	);
	type cpu_bus_control_t is record
		mode_mar: cpu_bus_address_mode_t;
		mode_mdr: cpu_bus_data_mode_t;
		cycle_type: cpu_bus_cycle_type_t;
	end record cpu_bus_control_t;
	
	type cpu_seq_branch_condition_t is (
		-- Z or (S xor VP)
		SEQ_CONDITION_LE,
		-- Z nor (S xor VP)
		SEQ_CONDITION_GT,
		-- S xor VP
		SEQ_CONDITION_LT,
		-- S xnor VP
		SEQ_CONDITION_GE,
		-- C or Z
		SEQ_CONDITION_ULE,
		-- C nor Z
		SEQ_CONDITION_UGT,
		-- C
		SEQ_CONDITION_C,
		-- not C
		SEQ_CONDITION_NC,
		-- S
		SEQ_CONDITION_M,
		-- not S
		SEQ_CONDITION_P,
		-- VP
		SEQ_CONDITION_OV,
		-- not VP
		SEQ_CONDITION_NOV,
		-- Z
		SEQ_CONDITION_Z,
		-- not Z
		SEQ_CONDITION_NZ,
		-- 1
		SEQ_CONDITION_ALWAYS,
		-- not AUX
		SEQ_CONDITION_DJNZ
	);
	type cpu_seq_control_t is record
		cond: cpu_seq_branch_condition_t;
		run_next_true: ;
		run_next_false: ;
		halt: boolean;
		final: boolean;
	end record cpu_seq_control_t;
	
	type cpu_mucode_entry_idx_t is (
		-- No operation
		MU_NONE,
		-- Request memory (@imm)
		MU_MREQ_ABS,
		-- Request memory (@imm+reg)
		MU_MREQ_ABS_IDX,
		-- Request memory (@reg)
		MU_MREQ_REG_IND,
		-- Request memory (@reg+)
		MU_MREQ_REG_IND_POSTINC,
		-- Request memory (@-reg)
		MU_MREQ_REG_IND_PREDEC,
		-- Request memory (@reg+imm)
		MU_MREQ_REG_REL,
		-- Request memory (@reg+reg)
		MU_MREQ_REG_IDX,
		-- Request memory (@PGC+imm)
		MU_MREQ_PGC_REL,
		-- Request memory (@PGC+(offset8<<1))
		MU_MREQ_PGC_OFF_SHORT,
		-- Request memory (@PGC+hml)
		MU_MREQ_PGC_OFF_LONG,
		-- Request memory (@MAR+)
		MU_MREQ_MAR_POSTINC,
		-- Request memory (@MAR+, before all 24-bit register post-increments)
		MU_MREQ_MAR_POSTINC_REG_POSTINC,
		-- Perform a register post-increment
		MU_POSTINC,
		-- Perform a repeat step (REPI)
		MU_REPI,
		-- Perform a repeat step (MULU / MULS / DIVU)
		MU_MULDIV_REPI,
		-- Perform a repeat step (DIVS)
		MU_DIVS_REPI,
		-- Perform a repeat step (REPR)
		MU_REPR,
		-- Subtract 2 from PGC so an interrupt during a REPR will push the correct PGC value
		MU_ADJUST_PGC,
		-- Load the factorA latch with a register operand (MULU / MULS, setup phase)
		MU_MUL_LD_FACTORA,
		-- Clear the low destination register (MULU / MULS, setup phase)
		MU_MUL_CLR_REG,
		-- Clear R0, the high destination register (MULU / MULS, setup phase)
		MU_MUL_CLR_R0,
		-- Load the REPI state with the instruction size in bits (MULU / MULS / DIVU / DIVS, setup phase)
		MU_MULDIV_LD_REPI,
		-- Perform an SLA operation on the low destination register (MULU / MULS, loop phase)
		MU_MUL_SLA_REG,
		-- Perform an RL operation on R0 (MULU / MULS, loop phase)
		MU_MUL_RL_R0,
		-- Perform an SLA operation on the factorB latch (MULU / MULS, loop phase)
		MU_MUL_SLA_FACTORB,
		-- Conditionally add the factorB latch to the low destination register (MULU / MULS, loop phase)
		MU_MUL_ADD_REG,
		-- Process any carry from MU_MUL_ADD_REG by adding it to R0 (MULU / MULS, loop phase)
		MU_MUL_ADX_R0,
		-- Store the sign bit of R0 (DIVS, setup phase)
		MU_DIVS_TST_R0,
		-- Conditionally perform a NEG operaton on R0 if it is negative (DIVS, setup phase)
		MU_DIVS_ABS_R0,
		-- Store the sign bit of the factorB latch (DIVS, setup phase)
		MU_DIVS_TST_FACTORB,
		-- Conditionally perform a NEG operaton on the factorB latch if it is negative (DIVS, setup phase)
		MU_DIVS_ABS_FACTORB,
		-- Perform an SLA operation on the destination register (DIVU / DIVS, loop phase)
		MU_DIV_SLA_REG,
		-- Perform an RL operation on R0 (DIVU / DIVS, loop phase)
		MU_DIV_RL_R0,
		-- Subtract the factorB latch from R0 and throw the result away, saving the inverted borrow bit (DIVU / DIVS, loop phase)
		MU_DIV_CP_FACTORB,
		-- Process the inverted borrow from MU_DIV_CP_FACTORB by adding it to the destination register (DIVU / DIVS, loop phase)
		MU_DIV_ADX_REG,
		-- Conditionally subtract the factorB latch from R0 (DIVU / DIVS, loop phase)
		MU_DIV_SUB_FACTORB,
		-- Conditionally perform a NEG operation on R0 if the result of MU_DIVS_TST_R0 was 1 (DIVS, post-loop phase)
		MU_DIVS_NEG_R0,
		-- Conditionally perform a NEG operation on the destination register if the exclusive-OR of the two bit tests was 1 (DIVS, post-loop phase)
		MU_DIVS_NEG_REG,
		-- Decrement the stack pointer by 4 in preparation for pushing PGC (jumps / calls / exceptions / interrupts)
		MU_CALL_SP_IND_PREDEC,
		-- Write PGC to @SP (jumps / calls / exceptions / interrupts)
		MU_CALL_LD_PGC,
		-- Decrement the stack pointer by 2 in preparation for pushing WF (exceptions / interrupts)
		MU_IRQ_SP_IND_PREDEC,
		-- Write WF to @SP (exceptions / interrupts)
		MU_IRQ_LD_WF
	);
end hivecraft_cpu_pack;