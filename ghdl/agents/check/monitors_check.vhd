-- monitors_check:  the ATC unit and the two monitors, the logic analyzer (la_unit) and the ADC unit's capture, wired
-- as in the system:  ATC --(status, timestamp)--> LA <--CROSS_TRIGGER--> ADC capture, the ADC with the timestamp
-- too;  the monitors give nothing back to the ATC.
--
-- Over one REGBUS (the units' read data ORed, as in the hub):  an ATC marker (a poke routed to M1, ATC status bits
-- 7-4) triggers the LA on its sample bit and is recorded once;  the LA's trigger reaches the ADC capture;  the ADC's
-- trigger (FORCE) reaches the LA;  with both cross triggers enabled each fires once per ARM (no loop);  both keep
-- the same trigger timestamp, and the cross-triggered capture's triggering sample is the next one;  the LA with
-- acquisition disabled still passes the marker's trigger on.  The ATC timestamp counts every clock (CONFIG_UART 1),
-- and the ADC pins follow it (data = timestamp mod 4096), so the ADC samples say when they were taken.  Contracts:
-- the comments of la_unit.vhd, adc_unit.vhd, ../bram/bram_buffer.vhd, atc_unit.vhd and register_map.vhd.
-- Stimulus changes on falling clock edges.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_pkg.all;

entity monitors_check is
end monitors_check;

architecture behaviour of monitors_check is
  constant PERIOD  : time := 10 ns;
  constant DEPTH   : integer := 64;

  signal clk     : std_logic := '0';
  signal rst     : std_logic := '1';
  signal done    : boolean := false;

  signal raddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal rupdate : std_logic := '0';
  signal waddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal wupdate : std_logic := '0';
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal rdata, rdata_atc, rdata_la, rdata_adc : std_logic_vector(31 downto 0);
  signal rack, rack_atc, rack_la, rack_adc     : std_logic;
  signal wack, wack_atc, wack_la, wack_adc     : std_logic;

  signal baud    : std_logic;
  signal ts      : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal g, h    : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal atc_status : std_logic_vector(C_STATUS_BITS-1 downto 0);
  signal la_to_adc, adc_to_la : std_logic;
  signal n_la_to_adc, n_adc_to_la : integer := 0;   -- cross trigger pulses

  function atc(reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_ATC * 16#1000# + reg, 16));
  end function;

  function la(reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_LA * 16#1000# + reg, 16));
  end function;

  function adc(reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_ADC * 16#1000# + reg, 16));
  end function;

  function u32(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 32));
  end function;
begin
  atc0: entity work.atc_unit
    port map (
      ACLK => clk, RST_I => rst,
      S_REGBUS_RB_RADDR => raddr, S_REGBUS_RB_RDATA => rdata_atc, S_REGBUS_RB_RUPDATE => rupdate,
      S_REGBUS_RB_RACK => rack_atc, S_REGBUS_RB_WUPDATE => wupdate, S_REGBUS_RB_WADDR => waddr,
      S_REGBUS_RB_WDATA => wdata, S_REGBUS_RB_WACK => wack_atc,
      LEMO_A_I => '0', LEMO_B_I => '0', BAUD_O => baud, TIMESTAMP_O => ts,
      RX_MARKER_O => open, UCLK_O => open, G_O => g, H_O => h, STATUS_O => atc_status);

  la0: entity work.la_unit
    generic map (C_DEPTH_LOG2 => 6)
    port map (
      ACLK => clk, RST_I => rst,
      S_REGBUS_RB_RUPDATE => rupdate, S_REGBUS_RB_RADDR => raddr, S_REGBUS_RB_RDATA => rdata_la,
      S_REGBUS_RB_RACK => rack_la, S_REGBUS_RB_WUPDATE => wupdate, S_REGBUS_RB_WADDR => waddr,
      S_REGBUS_RB_WDATA => wdata, S_REGBUS_RB_WACK => wack_la,
      PISO_I => (others => '0'), POSI_I => (others => '0'), G_I => g, H_I => h, BAUD_I => baud,
      ATC_STATUS_I => atc_status, RX_STATUS_I => (others => '0'), TX_STATUS_I => (others => '0'),
      TIMESTAMP_I => ts, CROSS_TRIGGER_I => adc_to_la, CROSS_TRIGGER_O => la_to_adc);

  adc0: entity work.adc_unit
    generic map (C_DEPTH_LOG2 => 6)
    port map (
      ACLK => clk, RST_I => rst,
      S_REGBUS_RB_RUPDATE => rupdate, S_REGBUS_RB_RADDR => raddr, S_REGBUS_RB_RDATA => rdata_adc,
      S_REGBUS_RB_RACK => rack_adc, S_REGBUS_RB_WUPDATE => wupdate, S_REGBUS_RB_WADDR => waddr,
      S_REGBUS_RB_WDATA => wdata, S_REGBUS_RB_WACK => wack_adc,
      ADC_EN_O => open, ADC_CLK_O => open, ADC_DATA_I => ts(ADC_DATA_WIDTH-1 downto 0), ADC_DOF_I => '0',
      TIMESTAMP_I => ts, CROSS_TRIGGER_I => la_to_adc, CROSS_TRIGGER_O => adc_to_la);

  rdata <= rdata_atc or rdata_la or rdata_adc;
  rack  <= rack_atc or rack_la or rack_adc;
  wack  <= wack_atc or wack_la or wack_adc;

  clock_until(clk, done, PERIOD);

  pulses: process(clk)
  begin
    if rising_edge(clk) then
      if la_to_adc = '1' then n_la_to_adc <= n_la_to_adc + 1; end if;
      if adc_to_la = '1' then n_adc_to_la <= n_adc_to_la + 1; end if;
    end if;
  end process;

  test: process
    variable v, ts_la, ts_adc : std_logic_vector(31 downto 0);
    variable a     : boolean;
    variable n1, n2, cnt, pos, ones : integer;
    variable first, x : integer;

    procedure reg_write(addr : std_logic_vector(15 downto 0); data : std_logic_vector(31 downto 0)) is
      variable acked : boolean := false;
    begin
      wait until falling_edge(clk);
      waddr <= addr; wdata <= data; wupdate <= '1';
      wait until falling_edge(clk);
      wupdate <= '0';
      for i in 1 to 8 loop
        wait until rising_edge(clk);
        if wack = '1' then acked := true; exit; end if;
      end loop;
      check(acked, "write to 0x" & hex(addr) & " acknowledged");
    end procedure;

    procedure reg_read(addr : std_logic_vector(15 downto 0); data : out std_logic_vector(31 downto 0)) is
      variable acked : boolean := false;
    begin
      data := (others => '0');
      wait until falling_edge(clk);
      raddr <= addr; rupdate <= '1';
      wait until falling_edge(clk);
      rupdate <= '0';
      for i in 1 to 8 loop
        wait until rising_edge(clk);
        if rack = '1' then acked := true; data := rdata; exit; end if;
      end loop;
      check(acked, "read of 0x" & hex(addr) & " acknowledged");
    end procedure;

    -- STATUS (LA) or CAPTURE_STATUS (ADC) until done
    procedure wait_done(addr : std_logic_vector(15 downto 0); msg : string) is
      variable d : std_logic_vector(31 downto 0);
    begin
      for i in 1 to 400 loop
        reg_read(addr, d);
        exit when d(2) = '1';
      end loop;
      check_equal(d, x"00000004", msg & ":  capture done");
    end procedure;

    -- both trigger timestamps (bits 31-0)
    procedure read_ts is
    begin
      reg_read(la(C_ADDR_LA_TS_LOWER), ts_la);
      reg_read(adc(C_ADDR_ADC_TS_LOWER), ts_adc);
    end procedure;

    -- the ADC capture's triggering sample:  its data (the timestamp, mod 4096, when it was taken)
    procedure adc_trig_data(res : out integer) is
      variable d : std_logic_vector(31 downto 0);
      variable p : integer;
    begin
      reg_read(adc(C_ADDR_ADC_TRIG_POS), d);
      p := to_integer(unsigned(d));
      reg_write(adc(C_ADDR_ADC_START), x"00000000");
      for i in 1 to p loop
        reg_write(adc(C_ADDR_ADC_NEXT), x"00000000");
      end loop;
      reg_read(adc(C_ADDR_ADC_DATA), d);
      res := to_integer(unsigned(d(11 downto 0)));
    end procedure;

    function lo12(d : std_logic_vector(31 downto 0)) return integer is
    begin
      return to_integer(unsigned(d(11 downto 0)));
    end function;

    procedure arm_both is
    begin
      reg_write(la(C_ADDR_LA_ARM), x"00000000");
      reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    end procedure;
  begin
    wait for 3*PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 2*PERIOD;

    -- ATC:  timestamp every clock;  poke A to marker 1 only (no G/H, no tiles)
    reg_write(atc(C_ADDR_ATC_CONFIG_UART), u32(1));
    reg_write(atc(C_ADDR_ATC_DST_POKE_A), x"00000008");
    -- LA:  nibble A = ATC status 7-4 (markers M0-M3:  bit 1 = M1), nibble B = ATC status 3-0, the rest zero
    reg_write(la(C_ADDR_LA_MUX_SELECT_A), u32(C_LA_LANE_ATC_STATUS_UPPER));
    reg_write(la(C_ADDR_LA_MUX_SELECT_B), u32(C_LA_LANE_ATC_STATUS_LOWER));
    reg_write(la(C_ADDR_LA_POST), u32(20));
    reg_write(adc(C_ADDR_ADC_POST), u32(20));

    print("-- ATC marker M1 -> LA (rising edge of sample bit 1) -> ADC (cross trigger)");
    reg_write(la(C_ADDR_LA_TRIG), u32(1));
    reg_write(adc(C_ADDR_ADC_TRIG), u32(16#400# + 31));
    for k in 0 to 2 loop
      n1 := n_la_to_adc; n2 := n_adc_to_la;
      arm_both;
      wait for (10 + 3*k)*PERIOD;
      reg_write(atc(C_ADDR_ATC_POKE_A), x"00000000");
      wait_done(la(C_ADDR_LA_STATUS), "marker -> LA");
      wait_done(adc(C_ADDR_ADC_CAPTURE_STATUS), "marker -> LA -> ADC");
      read_ts;
      check_equal(ts_adc, ts_la, "marker -> LA -> ADC (" & dec(k) & "):  the same trigger timestamp");
      adc_trig_data(x);
      check_equal(x, (lo12(ts_la) + 1) mod 4096,
                  "marker -> LA -> ADC (" & dec(k) & "):  the ADC's triggering sample one clock later");
      check_equal(n_la_to_adc - n1, 1, "marker -> LA -> ADC:  one LA CROSS_TRIGGER_O pulse");
      check_equal(n_adc_to_la - n2, 1, "marker -> LA -> ADC:  one ADC CROSS_TRIGGER_O pulse (back to the LA, ignored)");
    end loop;

    print("-- the marker in the LA capture:  one sample with M1, at the trigger");
    reg_read(la(C_ADDR_LA_COUNT), v);       cnt := to_integer(unsigned(v));
    reg_read(la(C_ADDR_LA_TRIG_POS), v);    pos := to_integer(unsigned(v));
    reg_write(la(C_ADDR_LA_START), x"00000000");
    ones := 0; first := -1;
    for i in 0 to cnt-1 loop
      reg_read(la(C_ADDR_LA_DATA), v);
      if v(1) = '1' then
        ones := ones + 1;
        if first < 0 then first := i; end if;
      end if;
      check(v(0) = '0' and v(3 downto 2) = "00", "marker capture:  markers 0, 2, 3 quiet (sample " & dec(i) & ")");
      reg_write(la(C_ADDR_LA_NEXT), x"00000000");
    end loop;
    check_equal(ones, 1, "marker capture:  M1 (a one-clock pulse) in exactly one sample");
    check_equal(first, pos, "marker capture:  that sample is the triggering one");

    print("-- ADC FORCE -> LA (cross trigger);  both enabled:  one pulse each (no loop)");
    reg_write(la(C_ADDR_LA_TRIG), u32(16#400# + 31));
    for k in 0 to 2 loop
      n1 := n_la_to_adc; n2 := n_adc_to_la;
      arm_both;
      wait for (10 + 3*k)*PERIOD;
      reg_write(adc(C_ADDR_ADC_FORCE), x"00000000");
      wait_done(adc(C_ADDR_ADC_CAPTURE_STATUS), "ADC FORCE");
      wait_done(la(C_ADDR_LA_STATUS), "ADC -> LA");
      read_ts;
      check_equal(ts_la, ts_adc, "ADC -> LA (" & dec(k) & "):  the same trigger timestamp");
      adc_trig_data(x);
      check_equal(x, lo12(ts_adc), "ADC FORCE (" & dec(k) & "):  triggering sample = its timestamp");
      check_equal(n_adc_to_la - n1 + n_la_to_adc - n2, 2, "ADC -> LA:  one CROSS_TRIGGER_O pulse each way");
    end loop;

    print("-- LA acquisition disabled:  a trigger router for the marker");
    reg_write(la(C_ADDR_LA_MODE), x"00000000");
    reg_write(la(C_ADDR_LA_TRIG), u32(1));
    arm_both;
    wait for 10*PERIOD;
    reg_write(atc(C_ADDR_ATC_POKE_A), x"00000000");
    wait_done(adc(C_ADDR_ADC_CAPTURE_STATUS), "marker -> LA (disabled) -> ADC");
    wait_done(la(C_ADDR_LA_STATUS), "LA disabled");
    reg_read(la(C_ADDR_LA_COUNT), v);
    check_equal(v, x"00000000", "LA disabled:  nothing written");
    read_ts;
    check_equal(ts_adc, ts_la, "LA disabled:  the same trigger timestamp");
    check(unsigned(ts_adc) /= 0, "LA disabled:  the ADC captured (timestamp " & hex(ts_adc) & ")");

    finish("monitors_check");
    done <= true;
    wait;
  end process;
end behaviour;
