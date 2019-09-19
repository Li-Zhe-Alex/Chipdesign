--------------------------------------------------------------------------------
-- Project     : Chipdesign 2018
-- Module      : Baudbclk 16x
-- Filename    : baud16_tb.vhdl
--
-- Authors     : Li, Zhe
-- Created     : 2018-04-27
-- Last Update : 2018-05-14
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library meteo;
--use meteo.meteo_pkg.all;

entity baud16_tb is
end baud16_tb;

architecture rtl of baud16_tb is
	signal clock     : std_ulogic                     := '0';
	signal reset_n   : std_ulogic;
	signal reg_baud      : std_ulogic_vector(7 downto 0) := "01000000"; --9600
	signal bclk      : std_ulogic;
	signal bclk16    : std_ulogic;

	component baud is
		generic(
			sclk          : integer := 10000000;
			sclk_length   : integer := 24;
			reg_baud_size : integer := 8
		);
		port(
			clock    : in  std_ulogic;
			reset_n  : in  std_ulogic;
			reg_baud : in  std_ulogic_vector(reg_baud_size - 1 downto 0);
			bclk     : out std_ulogic
		);
	end component baud;

	component baud16 is
		generic(
			n      : integer := 16;
			length : integer := 5
		);
		port(
			bclk    : in  std_ulogic;
			reset_n : in  std_ulogic;
			bclk16  : out std_ulogic
		);
	end component baud16;

begin
	rst : process
	begin
		reset_n   <= '0';
		wait for 40 ns;
		reset_n   <= '1';
		wait;

	end process rst;

	gen_clock : process(clock)
	begin
		clock <= not clock after 50 ns;
	end process;
	baud_inst : baud
		port map(
			clock, reset_n, reg_baud, bclk
		);
	baud16_inst : baud16
		port map(
			bclk, reset_n, bclk16
		);
end architecture rtl;
