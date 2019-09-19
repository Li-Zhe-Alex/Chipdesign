--------------------------------------------------------------------------------
-- Project     : Chipdesign 2018
-- Module      : Baudclock_generator
-- Filename    : baud_tb.vhdl
-- baudclk generator for sampling!
-- Authors     : Li,Zhe
-- Created     : 2018-04-24
-- Last Update : 2018-05-14
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library meteo;
--use meteo.meteo_pkg.all;

entity baud_tb is
  
end baud_tb;

architecture rtl of baud_tb is
    signal clock : std_ulogic := '0';
	signal reset_n :std_ulogic ;
	signal reg_baud      : std_ulogic_vector(7 downto 0) := "01000000"; --9600
	signal bclk :std_ulogic;
	component baud is
	   generic(
   	sclk: integer := 10000000; --sclk freq
sclk_length   : integer := 24;
	reg_baud_size: integer := 8
   ); 
   port(
        clock:in std_ulogic;
        reset_n:in std_ulogic;
        reg_baud:in std_ulogic_vector(reg_baud_size-1 downto 0);
        bclk:out std_ulogic
       );
	end component;
	
        
begin
   rst : process
   begin
   reset_n <= '0';
   wait for 40 ns;
   reset_n <= '1';
   wait;
   end process rst;
   
   gen_clock : process(clock)
   begin
	clock <= not clock after 100 ns;

	end process;
	baud1: baud
	   port map(
        clock,
        reset_n,
        reg_baud,
        bclk
       );
end architecture rtl;
