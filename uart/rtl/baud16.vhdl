--------------------------------------------------------------------------------
-- Project     : Chipdesign 2018
-- Module      : Baudbclk 16x
-- Filename    : baud16.vhdl
--
-- Authors     : Li, Zhe
-- Created     : 2018-04-25
-- Last Update : 2018-05-14
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library meteo;
--use meteo.meteo_pkg.all;
entity baud16 is
	generic(
		n      : integer := 16;
		length : integer := 5
	);
	port(
		sclk    : in  std_ulogic;
		bclk    : in  std_ulogic;
		reset_n : in  std_ulogic;
		bclk16  : out std_ulogic
	);
end baud16;

architecture rtl of baud16 is
	signal cnt         : unsigned(length - 1 downto 0);
	signal cnt_nxt     : unsigned(length - 1 downto 0);
	signal cnt_limit   : unsigned(length - 1 downto 0);
	signal bclk16_nxt  : std_ulogic;
	signal bclk16_wire : std_ulogic;
	signal bclk_reg    : std_ulogic;
begin
	cnt_limit <= resize(shift_right(to_unsigned(n, length), 1), length);
	bclk16    <= bclk16_wire;

	seq : process(reset_n, sclk)
	begin
		if reset_n = '0' then
			cnt         <= (others => '0');
			bclk16_wire <= '0';
		elsif rising_edge(sclk) then
			bclk_reg <= bclk;
			if (bclk_reg = '0') and (bclk = '1') then
				cnt         <= cnt_nxt;
				bclk16_wire <= bclk16_nxt;
			else
				cnt         <= cnt;
				bclk16_wire <= bclk16_wire;
			end if;
		end if;
	end process seq;

	komb : process(cnt, bclk16_wire, cnt_limit)
	begin
		if cnt <= cnt_limit - 2 then
			cnt_nxt    <= cnt + 1;
			bclk16_nxt <= bclk16_wire;
		else
			bclk16_nxt <= not bclk16_wire;
			cnt_nxt    <= (others => '0');
		end if;
	end process komb;
end architecture rtl;
