--------------------------------------------------------------------------------
-- Project     : Chipdesign 2018
-- Module      : reciever
-- Filename    : rx.vhdl
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

entity reciever is

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
		rx_out        : out std_ulogic_vector(7 downto 0) -- to UDR
	);
end reciever;

architecture rtl of reciever is

	signal overrun_nxt          : std_ulogic;
	signal framing_error_nxt    : std_ulogic;
	signal sample_dout          : std_ulogic;
	signal sample_dout_reg      : std_ulogic;
	signal sample_dout_nxt      : std_ulogic;
	signal threeforone          : std_ulogic_vector(2 downto 0);
	signal sample_reg           : std_ulogic_vector(15 downto 0);
	signal sample_reg_nxt       : std_ulogic_vector(15 downto 0);
	signal sample_cnt           : std_ulogic_vector(2 downto 0);
	signal sample_cnt_nxt       : std_ulogic_vector(2 downto 0);
	signal sample_cnt_reset     : std_ulogic;
	signal sample_cnt_reset_nxt : std_ulogic;
	signal sample_cnt_status    : std_ulogic;

	signal rx_shiftreg        : std_ulogic_vector(7 downto 0);
	signal rx_shiftreg_nxt    : std_ulogic_vector(7 downto 0);

	signal rxc_flag_nxt       : std_ulogic;
	signal rxc_flag_wire      : std_ulogic;
	signal rx_out_nxt         : std_ulogic_vector(7 downto 0);
	signal rx_out_wire        : std_ulogic_vector(7 downto 0);
	signal framing_error_wire : std_ulogic;
	signal overrun_wire       : std_ulogic;

	type rx_statetype is (rx_wait, rx_recieving, rx_stop, rx_idle);
	signal rx_state     : rx_statetype;
	signal rx_state_nxt : rx_statetype;

	signal bclk16_reg : std_ulogic;
	signal bclk_reg   : std_ulogic;
begin
	rx_out        <= rx_out_wire;
	rxc_flag      <= rxc_flag_wire;
	framing_error <= framing_error_wire;
	overrun       <= overrun_wire;

	seq : process(reset_n, sclk)
	begin
		if reset_n = '0' then
			rx_shiftreg        <= (others => '0');
			rx_out_wire        <= (others => '0');
			sample_cnt         <= (others => '0');
			rx_state           <= rx_idle;
			sample_dout_reg    <= '0';
			sample_dout        <= '0';
			sample_cnt_reset   <= '0';
			overrun_wire       <= '0';
			framing_error_wire <= '0';
			rxc_flag_wire      <= '0';
		elsif rising_edge(sclk) then
			bclk_reg   <= bclk;
			bclk16_reg <= bclk16;
			if (bclk16_reg = '0') and (bclk16 = '1') then
				sample_dout        <= sample_dout_nxt;
				rx_state           <= rx_state_nxt;
				rx_shiftreg        <= rx_shiftreg_nxt;
				rx_out_wire        <= rx_out_nxt;
				sample_cnt         <= sample_cnt_nxt;
				rxc_flag_wire      <= rxc_flag_nxt;
				sample_dout_reg    <= sample_dout_nxt;
				framing_error_wire <= framing_error_nxt;
				overrun_wire       <= overrun_nxt;
				sample_cnt_reset   <= sample_cnt_reset_nxt;
			else
				sample_dout        <= sample_dout_nxt;
				rx_state           <= rx_state;
				rx_shiftreg        <= rx_shiftreg;
				rx_out_wire        <= rx_out_wire;
				sample_cnt         <= sample_cnt;
				rxc_flag_wire      <= rxc_flag_wire;
				sample_dout_reg    <= sample_dout_reg;
				framing_error_wire <= framing_error_wire;
				overrun_wire       <= overrun_wire;
				sample_cnt_reset   <= sample_cnt_reset;
			end if;
		end if;
	end process seq;

	sample_seq : process(sclk, reset_n)
	begin
		if reset_n = '0' then
			sample_reg <= (others => '0');
		elsif rising_edge(sclk) then
			if (bclk_reg = '0') and (bclk = '1') then
				sample_reg <= sample_reg_nxt;
			else
				sample_reg <= sample_reg;
			end if;
		end if;
	end process sample_seq;

	sample_reg_komb : process(rx, sample_reg(14 downto 0))
	begin
		sample_reg_nxt(0)           <= rx;
		sample_reg_nxt(15 downto 1) <= sample_reg(14 downto 0);
	end process sample_reg_komb;

	sample_cnt_komb : process(sample_cnt, sample_cnt_reset)
	begin
		if sample_cnt_reset = '1' then
			sample_cnt_nxt    <= "000";
			sample_cnt_status <= '0';
		elsif sample_cnt = "111" then   -- or 111 not sure, need simulate to determine
			sample_cnt_status <= '1';
			sample_cnt_nxt    <= sample_cnt;
		else
			sample_cnt_nxt    <= std_ulogic_vector(unsigned(sample_cnt) + to_unsigned(1, 3));
			sample_cnt_status <= '0';
		end if;
	end process sample_cnt_komb;

	sample_dout_komb : process(sample_reg, threeforone)
	begin
		threeforone <= sample_reg(6) & sample_reg(7) & sample_reg(8);
		case threeforone is
			when "111"  => sample_dout_nxt <= '1';
			when "110"  => sample_dout_nxt <= '1';
			when "101"  => sample_dout_nxt <= '1';
			when "011"  => sample_dout_nxt <= '1';
			when others => sample_dout_nxt <= '0';
		end case;
	end process sample_dout_komb;

	rx_shiftregister_fsm : process(rxc_flag_wire, sample_cnt_reset, sample_dout_nxt, framing_error_wire, overrun_wire, sample_dout_reg, sample_dout, rx_shiftreg, rx_enable, rx_out_wire, rx_state, sample_cnt_status)
	begin
		rx_state_nxt         <= rx_state;
		sample_cnt_reset_nxt <= '0';
		rx_out_nxt           <= rx_out_wire;
		sample_cnt_reset_nxt <= sample_cnt_reset;
		framing_error_nxt    <= framing_error_wire;
		overrun_nxt          <= overrun_wire;
		rx_shiftreg_nxt      <= rx_shiftreg;
		rxc_flag_nxt         <= rxc_flag_wire;

		case rx_state is

			when rx_idle =>

				rx_shiftreg_nxt   <= (others => '0');
				if rx_enable = '1' then
					rx_state_nxt         <= rx_wait;
					sample_cnt_reset_nxt <= '1';
				end if;
				rx_out_nxt        <= (others => '0');
				framing_error_nxt <= '0';
				overrun_nxt       <= '0';
				rxc_flag_nxt      <= '0';

			when rx_wait =>

				if rx_enable = '0' then
					rx_state_nxt <= rx_idle;
				else
					if (sample_dout_reg = '1') and (sample_dout_nxt = '0') then --start bit detected
						rx_state_nxt         <= rx_recieving;
						sample_cnt_reset_nxt <= '1';
					end if;
					rx_out_nxt <= (others => '0');
				end if;

			when rx_recieving =>

				if rx_enable = '0' then
					rx_state_nxt <= rx_idle;
				else
					sample_cnt_reset_nxt <= '0';
					if sample_cnt_status = '0' then --sample counter does not reach limitation
						rx_shiftreg_nxt(0)          <= sample_dout;
						rx_shiftreg_nxt(7 downto 1) <= rx_shiftreg(6 downto 0);
					else
						rx_state_nxt <= rx_stop;
					end if;
				end if;

			when rx_stop =>

				if rx_enable = '0' then
					rx_state_nxt <= rx_idle;
				else
					if rxc_flag_wire = '1' then
						overrun_nxt <= '1';
					end if;
					rx_out_nxt <= rx_shiftreg;
					rxc_flag_nxt <= '1';
					if sample_dout = '0' then
						framing_error_nxt <= '1';
					else
						framing_error_nxt <= '0';
					end if;
					rx_state_nxt <= rx_wait;

				end if;
		end case;
	end process rx_shiftregister_fsm;
end architecture rtl;

