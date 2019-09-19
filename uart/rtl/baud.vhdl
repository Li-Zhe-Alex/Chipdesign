--------------------------------------------------------------------------------
-- Project     : Chipdesign 2018
-- Module      : Baudclock_generator
-- Filename    : baud.vhdl
-- baudclk generator for sampling!
-- Authors     : Li,Zhe
-- Created     : 2018-04-21
-- Last Update : 2018-05-14
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library meteo;
--use meteo.meteo_pkg.all;

entity baud is
	generic(
		reg_baud_size : integer := 8
	);
	port(
		clock    : in  std_ulogic;
		reset_n  : in  std_ulogic;
		reg_baud : in  std_ulogic_vector(reg_baud_size - 1 downto 0); 
		--sclk=10Mhz reg_baud="01000000" baudrate=9600 T=102.4us baudrate_in_practice= 1s/102.4us=9765 error_rate=1.73%<2%
		bclk     : out std_ulogic
	);
end baud;

architecture rtl of baud is
	signal cnt          : unsigned(reg_baud_size + 4 - 1 downto 0);
	signal cnt_nxt      : unsigned(reg_baud_size + 4 - 1 downto 0);

	signal cnt_limit    : unsigned(7 downto 0);
	signal bclk_nxt     : std_ulogic;
	signal bclk_wire    : std_ulogic;

begin

	cnt_limit    <= shift_right(unsigned(reg_baud),1);
	bclk         <= bclk_wire;
	seq : process(clock, reset_n)
	begin
		if reset_n = '0' then
			cnt       <= (others => '0');
			bclk_wire <= '0';
		elsif rising_edge(clock) then
			cnt       <= cnt_nxt;
			bclk_wire <= bclk_nxt;
		end if;
	end process seq;

	komb : process(cnt, bclk_wire,cnt_limit)
	begin
		if cnt < cnt_limit - 1 then
			cnt_nxt  <= cnt + 1;
			bclk_nxt <= bclk_wire;
		else
			bclk_nxt <= not bclk_wire;
			cnt_nxt  <= (others => '0');
		end if;
	end process komb;
end architecture rtl;
