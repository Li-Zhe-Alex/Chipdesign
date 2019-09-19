--------------------------------------------------------------------------------
-- Project     : Chipdesign 2018
-- Module      : transmitter
-- Filename    : tx.vhdl
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

entity transmitter is

	port(
		sclk        : in  std_ulogic;
		bclk16      : in  std_ulogic;   --baudclock 16x 
		reset_n     : in  std_ulogic;
		tx_enable   : in  std_ulogic;   --from control register
		tx_data_reg : in  std_ulogic_vector(7 downto 0);
		txc_flag    : out std_ulogic;   --????
		busy        : out std_ulogic;
		start_tx    : in  std_ulogic;
		tx_ack_udre : out std_ulogic;
		tx          : out std_ulogic
	);
end transmitter;

architecture rtl of transmitter is

	signal tx_shiftreg     : std_ulogic_vector(7 downto 0);
	signal tx_shiftreg_nxt : std_ulogic_vector(7 downto 0);
	signal tx_cnt          : std_ulogic_vector(2 downto 0);
	signal tx_cnt_nxt      : std_ulogic_vector(2 downto 0);
	signal tx_dout         : std_ulogic;
	signal tx_dout_nxt     : std_ulogic;
	signal tx_cnt_status   : std_ulogic;
	signal txc_flag_nxt    : std_ulogic;
	signal txc_flag_wire   : std_ulogic;

	type tx_statetype is (tx_idle, tx_wait, tx_sending, tx_stop);
	signal tx_state         : tx_statetype;
	signal tx_state_nxt     : tx_statetype;
	signal tx_cnt_reset     : std_ulogic;
	signal tx_cnt_reset_nxt : std_ulogic;

	signal bclk16_reg : std_ulogic;

begin

	tx       <= tx_dout;
	txc_flag <= txc_flag_wire;
	seq : process(sclk, reset_n)
	begin
		if reset_n = '0' then
			tx_shiftreg   <= (others => '1');
			tx_state      <= tx_idle;
			txc_flag_wire <= '0';
			tx_dout       <= '0';
			tx_cnt        <= "000";
		elsif rising_edge(sclk) then
			bclk16_reg <= bclk16;
			if (bclk16_reg = '0') and (bclk16 = '1') then
				tx_shiftreg   <= tx_shiftreg_nxt;
				tx_state      <= tx_state_nxt;
				tx_dout       <= tx_dout_nxt;
				tx_cnt        <= tx_cnt_nxt;
				txc_flag_wire <= txc_flag_nxt;
				tx_cnt_reset  <= tx_cnt_reset_nxt;
			else
				tx_shiftreg   <= tx_shiftreg;
				tx_state      <= tx_state;
				tx_dout       <= tx_dout;
				tx_cnt        <= tx_cnt;
				txc_flag_wire <= txc_flag_wire;
				tx_cnt_reset  <= tx_cnt_reset;
			end if;
		end if;
	end process seq;

	tx_cnt_komb : process(tx_cnt, tx_cnt_reset)
	begin
		if tx_cnt_reset = '1' then
			tx_cnt_nxt    <= "000";
			tx_cnt_status <= '0';
		elsif tx_cnt = "110" then       -- or 111 not sure, need simulate to determine
			tx_cnt_status <= '1';
			tx_cnt_nxt    <= tx_cnt;
		else
			tx_cnt_nxt    <= std_ulogic_vector(unsigned(tx_cnt) + to_unsigned(1, 3));
			tx_cnt_status <= '0';
		end if;
	end process tx_cnt_komb;

	busy <= '0' when (tx_state = tx_idle) else '1';

	tx_fsm : process(tx_data_reg, tx_dout, tx_enable, tx_shiftreg, tx_state, tx_cnt_status, tx_cnt_reset, txc_flag_wire, start_tx)
	begin
		tx_dout_nxt      <= tx_dout;
		tx_state_nxt     <= tx_state;
		tx_shiftreg_nxt  <= tx_shiftreg;
		tx_cnt_reset_nxt <= tx_cnt_reset;
		txc_flag_nxt     <= txc_flag_wire;
		tx_ack_udre      <= '0';

		case tx_state is

			when tx_idle =>
				txc_flag_nxt <= '0';
				tx_dout_nxt  <= '1';
				if tx_enable = '1' and start_tx = '1' then
					tx_state_nxt <= tx_wait;
				end if;

			when tx_wait =>
				txc_flag_nxt <= '0';
				if tx_enable = '0' then
					tx_state_nxt <= tx_idle;
				else
					tx_dout_nxt      <= '0'; --start bit
					tx_state_nxt     <= tx_sending;
					tx_cnt_reset_nxt <= '1';
					tx_shiftreg_nxt  <= tx_data_reg;
					tx_ack_udre      <= '1';
				end if;

			when tx_sending =>
				txc_flag_nxt <= '0';
				if tx_enable = '0' then
					tx_state_nxt <= tx_idle;
				else
					tx_cnt_reset_nxt            <= '0';
					tx_dout_nxt                 <= tx_shiftreg(7);
					tx_shiftreg_nxt(7 downto 1) <= tx_shiftreg(6 downto 0);
					if tx_cnt_status = '1' then --all 8 bits are transported, shiftreg is free
						tx_state_nxt <= tx_stop;
					else
						tx_state_nxt <= tx_sending;
					end if;
				end if;

			when tx_stop =>

				if tx_enable = '0' then
					tx_state_nxt <= tx_idle;
				else
					tx_dout_nxt  <= '1';
					txc_flag_nxt <= '1';
					tx_state_nxt <= tx_idle;
				end if;

		end case;
	end process tx_fsm;
end rtl;
