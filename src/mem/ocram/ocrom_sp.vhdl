-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:				 	Martin Zabel
--									Patrick Lehmann
-- 
-- Module:				 	Single-port memory.
--
-- Description:
-- ------------------------------------
-- Inferring / instantiating single-port read-only memory
--
-- - single clock, clock enable
-- - 1 read port
-- 
-- 
-- License:
-- ============================================================================
-- Copyright 2008-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================


library STD;
use			STD.TextIO.all;

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;
use			IEEE.std_logic_textio.all;

library	PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.strings.all;


entity ocrom_sp is
	generic (
		A_BITS		: positive;
		D_BITS		: positive;
		FILENAME	: STRING		:= ""
	);
	port (
		clk	: in	std_logic;
		ce	: in	std_logic;
		a		: in	unsigned(A_BITS-1 downto 0);
		q		: out	std_logic_vector(D_BITS-1 downto 0)
	);
end entity;


architecture rtl of ocrom_sp is
	constant DEPTH				: positive := 2**A_BITS;

begin

	gInfer: if VENDOR = VENDOR_XILINX generate
		-- RAM can be inferred correctly
		-- XST Advanced HDL Synthesis generates single-port memory as expected.
		subtype word_t	is std_logic_vector(D_BITS - 1 downto 0);
		type		rom_t		is array(0 to DEPTH - 1) of word_t;
		
	begin
		genLoadFile : if (str_length(FileName) /= 0) generate
			-- Read a *.mem or *.hex file
			impure function ocram_ReadMemFile(FileName : STRING) return rom_t is
				file FileHandle				: TEXT open READ_MODE is FileName;
				variable CurrentLine	: LINE;
				variable TempWord			: STD_LOGIC_VECTOR((div_ceil(word_t'length, 4) * 4) - 1 downto 0);
				variable Result				: rom_t		:= (others => (others => '0'));
				
			begin
				-- discard the first line of a mem file
				if (str_to_lower(FileName(FileName'length - 3 to FileName'length)) = ".mem") then
					readline(FileHandle, CurrentLine);
				end if;

				for i in 0 to DEPTH - 1 loop
					exit when endfile(FileHandle);

					readline(FileHandle, CurrentLine);
					hread(CurrentLine, TempWord);
					Result(i)		:= resize(TempWord, word_t'length);
				end loop;

				return Result;
			end function;

			constant rom	: rom_t		:= ocram_ReadMemFile(FILENAME);
			signal a_reg	: unsigned(A_BITS-1 downto 0);
		begin
			process (clk)
			begin
				if rising_edge(clk) then
					if ce = '1' then
						a_reg <= a;
					end if;
				end if;
			end process;

			q <= rom(to_integer(a_reg));					-- gets new data
		end generate;
		genNoLoadFile : if (str_length(FileName) = 0) generate
			assert FALSE report "Do you really want to generate a block of zeros?" severity FAILURE;
		end generate;
	end generate gInfer;

	gAltera: if VENDOR = VENDOR_ALTERA generate
		component ocram_sp_altera
			generic (
				A_BITS		: positive;
				D_BITS		: positive;
				FILENAME	: STRING		:= ""
			);
			port (
				clk : in	std_logic;
				ce	: in	std_logic;
				we	: in	std_logic;
				a	 : in	unsigned(A_BITS-1 downto 0);
				d	 : in	std_logic_vector(D_BITS-1 downto 0);
				q	 : out std_logic_vector(D_BITS-1 downto 0));
		end component;
	begin
		-- Direct instantiation of altsyncram (including component
		-- declaration above) is not sufficient for ModelSim.
		-- That requires also usage of altera_mf library.
		i: ocram_sp_altera
			generic map (
				A_BITS		=> A_BITS,
				D_BITS		=> D_BITS,
				FILENAME	=> FILENAME
			)
			port map (
				clk => clk,
				ce	=> ce,
				we	=> '0',
				a	 => a,
				d	 => (others => '0'),
				q	 => q
			);
	end generate gAltera;
	
	assert VENDOR = VENDOR_XILINX or VENDOR = VENDOR_ALTERA
		report "Device not yet supported."
		severity failure;
end rtl;