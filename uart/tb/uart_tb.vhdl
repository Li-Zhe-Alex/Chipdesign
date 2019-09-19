--------------------------------------------------------------------------------
-- Project     : Chipdesign 2018
-- Module      : UART Module
-- Filename    : uart_tb.vhdl
--
-- Authors     : Li, Zhe
-- Created     : 2018-05-03
-- Last Update : 2018-05-15
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tb is
	generic(
		data_send     : std_ulogic_vector(7 downto 0) := "01110101"
		
	);
end entity uart_tb;

architecture sim of uart_tb is
	        signal clock          : std_ulogic := '0';
		signal reset_n        : std_ulogic;
		signal iobus_cs       : std_ulogic;
		signal iobus_wr       : std_ulogic;
		signal iobus_addr     : std_ulogic_vector(1 downto 0);
		signal iobus_din      : std_ulogic_vector(7 downto 0);
		signal iobus_dout     : std_ulogic_vector(7 downto 0);
		signal iobus_irq_rxc  : std_ulogic;
		signal iobus_irq_udre : std_ulogic;
		signal iobus_irq_txc  : std_ulogic;
		signal iobus_ack_rxc  : std_ulogic;
		signal iobus_ack_udre : std_ulogic;
		signal iobus_ack_txc  : std_ulogic;
		--
		signal rx_en          : std_ulogic;
		signal tx_en          : std_ulogic;
		signal rx             : std_ulogic;
		signal tx             : std_ulogic;
		
		component uart is 
			generic(
				reg_size      : integer := 8;
				CW_IOBUS_DATA : integer := 8
			);
			port(
				clock          : in  std_ulogic	:= '0';
				reset_n        : in  std_ulogic;
				iobus_cs       : in  std_ulogic;
				iobus_wr       : in  std_ulogic;
				iobus_addr     : in  std_ulogic_vector(1 downto 0);
				iobus_din      : in  std_ulogic_vector(CW_IOBUS_DATA - 1 downto 0);
				iobus_dout     : out std_ulogic_vector(CW_IOBUS_DATA - 1 downto 0);
				iobus_irq_rxc  : out std_ulogic;
				iobus_irq_udre : out std_ulogic;
				iobus_irq_txc  : out std_ulogic;
				iobus_ack_rxc  : in  std_ulogic;
				iobus_ack_udre : in  std_ulogic;
				iobus_ack_txc  : in  std_ulogic;
				--
				rx_en          : out std_ulogic;
				tx_en          : out std_ulogic;
				rx             : in  std_ulogic;
				tx             : out std_ulogic
			);
		end component uart;
		
		begin
		uart_Inst : uart
			port map(
				clock,
				reset_n,
				iobus_cs,
				iobus_wr,
				iobus_addr,
				iobus_din,
				iobus_dout,
				iobus_irq_rxc,
				iobus_irq_udre,
				iobus_irq_txc,
				iobus_ack_rxc,
				iobus_ack_udre,
				iobus_ack_txc,
		
				rx_en,
				tx_en,
				rx,
				tx );



		rx <= tx;

		gen_clock : process(clock)
			begin
				clock <= not clock after 50 ns;
			end process gen_clock;
			
		
		rst : process
			begin
				reset_n   <= '0';
				iobus_cs  <= '0';
				iobus_ack_rxc <= '0';
				iobus_ack_txc <= '0';
				iobus_ack_udre <= '0';
				
				
				
				wait for 450 ns;
				reset_n   <= '1';

				
				-- setup baud rate
				wait for 1 us;
				iobus_cs <= '1';
				iobus_addr <= "01";
				iobus_wr   <= '1';
				iobus_din  <= "01000000";
				wait for 100 ns;
				iobus_wr   <= '0';
				iobus_cs <= '0';
				
				-- init the control register
				wait for 1 us;
				iobus_cs <= '1';
				iobus_addr <= "10";
				iobus_wr   <= '1';
				iobus_din  <= "11111000";
				wait for 100 ns;
				iobus_wr   <= '0';
				iobus_cs <= '0';
				
				
				
				
				
				
				
				
				-- trigger transmission
				wait for 1 us;
				iobus_cs <= '1';
				iobus_addr <= "00";
				iobus_wr   <= '1';
				iobus_din  <= "11001010";
				wait for 100 ns;
				iobus_wr   <= '0';
				iobus_cs <= '0';
				
				
				
				
				
				
				-- trigger another transmission
				wait for 0.3 ms;
				iobus_cs <= '1';
				iobus_addr <= "00";
				iobus_wr   <= '1';
				iobus_din  <= "00111100";
				wait for 100 ns;
				iobus_wr   <= '0';
				iobus_cs <= '0';

				-- acknowledge UD empty interrupt --
				wait for 200 ns;
				if iobus_irq_udre = '1' then
					wait for 100 ns;
					iobus_ack_udre <= '1';
					wait for 100 ns;
					iobus_ack_udre <= '0';
				end if;
				
				
				-- acknowledge TXC interrupt --
				wait until iobus_irq_txc = '1';
				wait for 100 ns;
				iobus_ack_txc <= '1';
				wait for 100 ns;
				iobus_ack_txc <= '0';
				







				-- get RX data --
				wait until iobus_irq_rxc = '1';
				wait for 100 ns;
				iobus_ack_rxc <= '1';
				wait for 100 ns;
				iobus_ack_rxc <= '0'; 
				
				-- read rx data --
				wait for 100 ns;
				iobus_cs <= '1';
				iobus_addr <= "00";
				wait for 100 ns;

								-- init the control register
				wait for 1 us;
				iobus_cs <= '1';
				iobus_addr <= "10";
				iobus_wr   <= '1';
				iobus_din  <= "00011000";
				wait for 100 ns;
				iobus_wr   <= '0';
				iobus_cs <= '0';
				
				wait;
				
			end process rst;

	
		
end sim;
		
		
		
		
