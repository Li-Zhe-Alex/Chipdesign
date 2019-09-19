--------------------------------------------------------------------------------
-- Project     : Chipdesign 2018
-- Module      : UART Module
-- Filename    : uart.vhdl
--
-- Authors     : Li, Zhe
-- Created     : 2018-04-09
-- Last Update : 2018-05-15
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library meteo;
--use meteo.meteo_pkg.all;

entity uart is
	generic(
		reg_size      : integer := 8;
		CW_IOBUS_DATA : integer := 8
	);
	port(
		clock          : in  std_ulogic;
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
end entity uart;

architecture toplevel of uart is
	
	signal reg_ctrl        : std_ulogic_vector(reg_size - 1 downto 0); --UCR
	signal reg_stat        : std_ulogic_vector(reg_size - 1 downto 0); --USR
	signal reg_baud        : std_ulogic_vector(reg_size - 1 downto 0); --UBR
	signal reg_data_rx     : std_ulogic_vector(reg_size - 1 downto 0); --UDR
	signal reg_data_tx     : std_ulogic_vector(reg_size - 1 downto 0); --UDR
	signal reg_ctrl_nxt    : std_ulogic_vector(reg_size - 1 downto 0); --UCR
	signal reg_stat_nxt    : std_ulogic_vector(reg_size - 1 downto 0); --USR
	signal reg_baud_nxt    : std_ulogic_vector(reg_size - 1 downto 0); --UBR
	signal reg_data_rx_nxt : std_ulogic_vector(reg_size - 1 downto 0); --UDR
	signal reg_data_tx_nxt : std_ulogic_vector(reg_size - 1 downto 0); --UDR

	signal bclk   : std_ulogic;
	signal bclk16 : std_ulogic;

	signal rx_enable     : std_ulogic;
	signal rx_enable_nxt : std_ulogic;
	signal rxc_flag      : std_ulogic;
	signal rxc_flag_ff   : std_ulogic;
	signal framing_error : std_ulogic;
	signal overrun       : std_ulogic;	

	signal tx_enable               : std_ulogic;
	signal start_tx                : std_ulogic;
	signal tx_enable_nxt           : std_ulogic;	
	signal txc_flag                : std_ulogic;
	signal udre_flag               : std_ulogic;
	signal tx_busy                 : std_ulogic;
	signal tx_busy_ff              : std_ulogic;
	signal udre_empty, tx_ack_udre : std_ulogic;

	signal iobus_dout_wire         : std_ulogic_vector(CW_IOBUS_DATA - 1 downto 0);
	signal iobus_irq_txc_wire      : std_ulogic;
	signal iobus_irq_rxc_wire      : std_ulogic;
	signal iobus_irq_udre_wire     : std_ulogic;
	signal iobus_irq_txc_wire_nxt  : std_ulogic;
	signal iobus_irq_rxc_wire_nxt  : std_ulogic;
	signal iobus_irq_udre_wire_nxt : std_ulogic;

	component baud is
		generic(
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
			sclk    : in  std_ulogic;
			bclk    : in  std_ulogic;
			reset_n : in  std_ulogic;
			bclk16  : out std_ulogic
		);
	end component baud16;

	component reciever is

		port(
			sclk          : in  std_ulogic;
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

	component transmitter is

		port(
			sclk        : in  std_ulogic;
			bclk16      : in  std_ulogic; --baudclock 16x 
			reset_n     : in  std_ulogic;
			tx_enable   : in  std_ulogic; --from control register
			tx_data_reg : in  std_ulogic_vector(7 downto 0);
			txc_flag    : out std_ulogic; --????
			busy        : out std_ulogic;
			start_tx    : in  std_ulogic;
			tx_ack_udre : out std_ulogic;
			tx          : out std_ulogic
		);

	end component transmitter;

begin
	iobus_dout     <= iobus_dout_wire;
	iobus_irq_txc  <= iobus_irq_txc_wire;
	iobus_irq_rxc  <= iobus_irq_rxc_wire;
	iobus_irq_udre <= iobus_irq_udre_wire;
	tx_en          <= tx_enable;
	rx_en          <= rx_enable;

	baud_inst : baud
		port map(
			clock, reset_n, reg_baud, bclk
		);
	baud16_inst : baud16
		port map(
			clock,bclk, reset_n, bclk16
		);
	rx_inst : reciever
		port map(
			sclk          => clock,
			rx            => rx,
			bclk          => bclk,
			bclk16        => bclk16,
			reset_n       => reset_n,
			rx_enable     => rx_enable,
			rxc_flag      => rxc_flag,
			framing_error => framing_error,
			overrun       => overrun,
			rx_out        => reg_data_rx_nxt
		);
	tx_inst : transmitter
		port map(
			sclk        => clock,
			bclk16      => bclk16,
			reset_n     => reset_n,
			tx_enable   => tx_enable,
			tx_data_reg => reg_data_tx,
			txc_flag    => txc_flag,
			busy        => tx_busy,
			start_tx    => start_tx,
			tx_ack_udre => tx_ack_udre,
			tx          => tx
		);

	seq : process(clock, reset_n)
	begin
		if reset_n = '0' then
			reg_data_rx         <= (others => '0');
			reg_data_tx         <= (others => '0');
			reg_baud            <= (others => '0');
			reg_stat            <= (others => '0');
			reg_ctrl            <= (others => '0');
			rx_enable           <= '0';
			tx_enable           <= '0';
			iobus_irq_rxc_wire  <= '0';
			iobus_irq_txc_wire  <= '0';
			iobus_irq_rxc_wire  <= '0';
			iobus_irq_udre_wire <= '0';
			udre_empty          <= '0';
			tx_busy_ff          <= '0';
			rxc_flag_ff         <= '0';
		elsif rising_edge(clock) then
			reg_data_rx         <= reg_data_rx_nxt;
			reg_data_tx         <= reg_data_tx_nxt;
			reg_baud            <= reg_baud_nxt;
			reg_stat            <= reg_stat_nxt;
			reg_ctrl            <= reg_ctrl_nxt;
			rx_enable           <= rx_enable_nxt;
			tx_enable           <= tx_enable_nxt;
			iobus_irq_rxc_wire  <= iobus_irq_rxc_wire_nxt;
			iobus_irq_txc_wire  <= iobus_irq_txc_wire_nxt;
			iobus_irq_rxc_wire  <= iobus_irq_rxc_wire_nxt;
			iobus_irq_udre_wire <= iobus_irq_udre_wire_nxt;
			tx_busy_ff          <= tx_busy;
			rxc_flag_ff         <= rxc_flag;

			-- udre register --
			if (iobus_cs = '1') and (iobus_addr = "00") and (iobus_wr = '1') then
				udre_empty <= '0';
			elsif (tx_ack_udre = '1') then
				udre_empty <= '1';
			end if;
		end if;
	end process seq;

	cpu_interface : process(iobus_din, iobus_cs, iobus_addr, iobus_wr, reg_baud, reg_ctrl, reg_stat, reg_data_tx, reg_data_rx, udre_empty, tx_busy)
		variable start_tx_v : std_ulogic;
	begin
		start_tx_v      := '0';
		reg_data_tx_nxt <= reg_data_tx;
		reg_baud_nxt    <= reg_baud;
		reg_ctrl_nxt    <= reg_ctrl;
		iobus_dout_wire <= (others => '0');

		if iobus_cs = '1' then
			if iobus_addr = "00" then
				if iobus_wr = '1' then
					reg_data_tx_nxt <= iobus_din;
					start_tx_v      := '1';
				else
					iobus_dout_wire <= reg_data_rx;
				end if;
			elsif iobus_addr = "01" then
				if iobus_wr = '1' then
					reg_baud_nxt <= iobus_din;
				else
					iobus_dout_wire <= reg_baud;
				end if;
			elsif iobus_addr = "10" then
				if iobus_wr = '1' then
					reg_ctrl_nxt <= iobus_din;
				else
					iobus_dout_wire <= reg_ctrl;
				end if;

			elsif iobus_addr = "11" then
				iobus_dout_wire <= reg_stat;
			end if;
		end if;

		-- TX trigger --
		start_tx <= start_tx_v or ((not udre_empty) and (not tx_busy));
	end process cpu_interface;

	-- UDRE flag --
	udre_flag <= '1' when (tx_busy = '0') or (udre_empty = '1') else '0';

	reg_stat_process : process(reg_stat, framing_error, overrun, iobus_ack_rxc, iobus_ack_udre, udre_flag, rxc_flag, iobus_ack_txc, txc_flag)
	begin
		reg_stat_nxt <= reg_stat;
		if iobus_ack_rxc = '1' then
			reg_stat_nxt(7) <= '0';
		elsif rxc_flag = '1' then
			reg_stat_nxt(7) <= '1';
		end if;

		if iobus_ack_txc = '1' then
			reg_stat_nxt(6) <= '0';
		elsif txc_flag = '1' then
			reg_stat_nxt(6) <= '1';
		end if;

		if iobus_ack_udre = '1' then
			reg_stat_nxt(5) <= '0';
		elsif udre_flag = '1' then
			reg_stat_nxt(5) <= '1';
		end if;

		if framing_error = '1' then
			reg_stat_nxt(4) <= '1';
		else
			reg_stat_nxt(4) <= '0';
		end if;

		if overrun = '1' then
			reg_stat_nxt(3) <= '1';
		else
			reg_stat_nxt(3) <= '0';
		end if;

	end process reg_stat_process;

	interrupt : process(tx_enable, iobus_ack_txc, iobus_ack_rxc, reg_ctrl, rx_enable, tx_busy_ff, udre_flag, iobus_ack_udre, rxc_flag, tx_busy, iobus_irq_udre_wire, iobus_irq_rxc_wire, iobus_irq_txc_wire, rxc_flag_ff)
	begin
		iobus_irq_rxc_wire_nxt  <= iobus_irq_rxc_wire;
		iobus_irq_txc_wire_nxt  <= iobus_irq_txc_wire;
		iobus_irq_udre_wire_nxt <= iobus_irq_udre_wire;
		rx_enable_nxt           <= rx_enable;
		tx_enable_nxt           <= tx_enable;

		-- r complete interrupt --
		if reg_ctrl(7) = '1' then
			if (rxc_flag = '1') and (rxc_flag_ff = '0') then
				iobus_irq_rxc_wire_nxt <= '1';
			elsif (iobus_ack_rxc = '1') then
				iobus_irq_rxc_wire_nxt <= '0';
			end if;
		else
			iobus_irq_rxc_wire_nxt <= '0';
		end if;

		-- tx complete interrupt --
		if reg_ctrl(6) = '1' then
			if (tx_busy = '0') and (tx_busy_ff = '1') then
				iobus_irq_txc_wire_nxt <= '1';
			elsif (iobus_ack_txc = '1') then
				iobus_irq_txc_wire_nxt <= '0';
			end if;
		else
			iobus_irq_txc_wire_nxt <= '0';
		end if;

		-- TX data empty interrupt --
		if reg_ctrl(5) = '1' then
			if (udre_flag = '1') then
				iobus_irq_udre_wire_nxt <= '1';
			elsif (iobus_ack_udre = '1') then
				iobus_irq_udre_wire_nxt <= '0';
			end if;
		else
			iobus_irq_udre_wire_nxt <= '0';
		end if;

		if reg_ctrl(4) = '1' then
			rx_enable_nxt <= '1';
		else
			rx_enable_nxt <= '0';
		end if;

		if reg_ctrl(3) = '1' then
			tx_enable_nxt <= '1';
		else
			tx_enable_nxt <= '0';
		end if;
	end process interrupt;
end architecture toplevel;
