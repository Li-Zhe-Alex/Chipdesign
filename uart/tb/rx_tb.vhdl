--------------------------------------------------------------------------------
-- Project     : Chipdesign 2018
-- Module      : reciever
-- Filename    : rx_tb.vhdl
--
-- Authors     : Li, Zhe
-- Created     : 2018-04-29
-- Last Update : 2018-05-14 
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library meteo;
--use meteo.meteo_pkg.all;

entity rx_tb is
end rx_tb;

architecture rtl of rx_tb is
	signal clock         : std_ulogic                     := '0';
	signal reset_n       : std_ulogic;
	signal reg_baud      : std_ulogic_vector(7 downto 0) := "01000000"; --9600
	signal bclk          : std_ulogic;
	signal bclk16        : std_ulogic;
	signal tx            : std_ulogic;
	signal tx_enable     : std_ulogic;
	signal txc_flag      : std_ulogic;
	signal udre_flag     : std_ulogic;
	signal reg_data      : std_ulogic_vector(7 downto 0);
	signal reg_data_rx   : std_ulogic_vector(7 downto 0);
	signal rx_enable     : std_ulogic;
	signal rxc_flag      : std_ulogic;
	signal framing_error : std_ulogic;
	signal overrun       : std_ulogic;

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

	component transmitter is

		port(
			bclk16      : in  std_ulogic; --baudclock 16x 
			reset_n     : in  std_ulogic;
			tx_enable   : in  std_ulogic; --from control register
			tx_data_reg : in  std_ulogic_vector(7 downto 0);
			txc_flag    : out std_ulogic; --????
			udre_flag   : out std_ulogic;
			tx          : out std_ulogic
		);

	end component transmitter;
	component reciever is

		port(
			rx            : in  std_ulogic;
			bclk          : in  std_ulogic; --baudclock for sampling
			bclk16        : in  std_ulogic; --baudclock 16x 
			reset_n       : in  std_ulogic;
			rx_enable     : in  std_ulogic; --from control register		
			rxc_flag      : out std_ulogic; --to PC
			framing_error : out std_ulogic; --to USR
			overrun       : out std_ulogic; --to USR 
			--		iobus_ack_rxc : in  std_ulogic; --from PC
			rx_out        : out std_ulogic_vector(7 downto 0) -- to UDR
		);
	end component reciever;
begin
	rst : process
	begin
		reset_n   <= '0';
		wait for 40 ns;
		reset_n   <= '1';
		wait for 200 ns;
		tx_enable <= '0';
		reg_data  <= "01111011";
		wait for 400 ns;
		tx_enable <= '1';
		rx_enable <= '1';
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
	tx_inst : transmitter
		port map(
			bclk16      => bclk16,
			reset_n     => reset_n,
			tx_enable   => tx_enable,
			tx_data_reg => reg_data,
			txc_flag    => txc_flag,
			udre_flag   => udre_flag,
			tx          => tx
		);
	rx_inst : reciever
		port map(
			rx            => tx,
			bclk          => bclk,
			bclk16        => bclk16,
			reset_n       => reset_n,
			rx_enable     => rx_enable,
			rxc_flag      => rxc_flag,
			framing_error => framing_error,
			overrun       => overrun,
			rx_out        => reg_data_rx
		);
end architecture rtl;
