-- regbus_system_check:  the register path as the PS sees it
--
-- AXI-Lite master (this testbench) -> axil_to_regbus -> regbus_hub ->
-- the global unit (S clock) and, through the hub's CDC, the TX, RX, ATC, ADC
-- and LA units (P clock, a different frequency).  Checks that every unit
-- answers with the right data, that back-to-back reads across units never
-- mix their data (the hub's RDATA is a plain OR of all units), that writes
-- land in the right unit only, that unmapped addresses time out with
-- 0xEEEEEEEE without hanging the bus, and the global unit's outputs.
--
-- Contracts: regbus_fanout.vhd (units drive 0 when not addressed, hold RDATA
-- between updates), regbus_cdc.vhd, axil_to_regbus.vhd (timeout sentinel),
-- register_map.vhd.  Stimulus changes on falling clock edges.
--
-- Design assumption (regbus_hub.vhd): after an access to an S-domain unit
-- (global), the next access to a P-domain unit (TX, RX, ATC, ADC, LA) comes later
-- than the CDC crossing.  Every request also enters the CDC, and a strobe
-- still crossing would pick up the next request's address.  AXI-Lite from
-- the PS is not that fast (hardware check: G stress test), so the helpers
-- below wait C_CDC_SETTLE before a P access that follows an S access.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_pkg.all;

entity regbus_system_check is
end regbus_system_check;

architecture behaviour of regbus_system_check is
  constant S_PERIOD : time := 10 ns;   -- AXI / hub S side, global
  constant P_PERIOD : time := 16 ns;   -- TX, RX, ATC, ADC, LA (62.5 MHz)
  -- CDC crossing: request toggle through 4 P-clock flops, plus margin
  constant C_CDC_SETTLE : time := 8 * P_PERIOD;

  signal s_clk, p_clk : std_logic := '0';
  signal rst          : std_logic := '1';
  signal aresetn      : std_logic := '0';
  signal done         : boolean := false;

  -- AXI-Lite
  signal araddr  : std_logic_vector(15 downto 0) := (others => '0');
  signal arvalid : std_logic := '0';
  signal arready : std_logic;
  signal rdata   : std_logic_vector(31 downto 0);
  signal rvalid  : std_logic;
  signal rready  : std_logic := '0';
  signal awaddr  : std_logic_vector(15 downto 0) := (others => '0');
  signal awvalid : std_logic := '0';
  signal awready : std_logic;
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wvalid  : std_logic := '0';
  signal wready  : std_logic;
  signal bvalid  : std_logic;
  signal bready  : std_logic := '0';

  -- REGBUS: bridge -> hub
  signal b_rupdate, b_rack, b_wupdate, b_wack : std_logic;
  signal b_raddr, b_waddr : std_logic_vector(15 downto 0);
  signal b_rdata, b_wdata : std_logic_vector(31 downto 0);

  -- hub -> units: A global, L tx, M rx, N atc, O adc, P la
  type lane_t is record
    rupdate, rack, wupdate, wack : std_logic;
    raddr, waddr : std_logic_vector(15 downto 0);
    rdata, wdata : std_logic_vector(31 downto 0);
  end record;
  signal la, ll, lm, ln, lo, lp : lane_t;

  -- unit outputs
  signal analog_pwr : std_logic;
  signal tile_en    : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal leds       : std_logic_vector(C_NUM_LED-1 downto 0);
  signal baud       : std_logic;
  signal timestamp  : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal markers    : std_logic_vector(C_NUM_MARKER-1 downto 0);
  signal posi       : std_logic_vector(C_NUM_UART-1 downto 0);
  signal g, h       : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal piso_sync  : std_logic_vector(C_NUM_UART-1 downto 0);
  signal atc_status, rx_status, tx_status : std_logic_vector(C_STATUS_BITS-1 downto 0);
  signal la_to_adc, adc_to_la : std_logic;
begin
  rst <= not aresetn;

  bridge: entity work.axil_to_regbus
    port map (
      S_AXI_ACLK => s_clk, S_AXI_ARESETN => aresetn,
      S_AXI_ARADDR => araddr, S_AXI_ARVALID => arvalid, S_AXI_ARREADY => arready,
      S_AXI_RDATA => rdata, S_AXI_RRESP => open, S_AXI_RVALID => rvalid, S_AXI_RREADY => rready,
      S_AXI_AWADDR => awaddr, S_AXI_AWVALID => awvalid, S_AXI_AWREADY => awready,
      S_AXI_WDATA => wdata, S_AXI_WSTRB => "1111", S_AXI_WVALID => wvalid, S_AXI_WREADY => wready,
      S_AXI_BRESP => open, S_AXI_BVALID => bvalid, S_AXI_BREADY => bready,
      P_REGBUS_RB_RUPDATE => b_rupdate, P_REGBUS_RB_RADDR => b_raddr,
      P_REGBUS_RB_RDATA => b_rdata, P_REGBUS_RB_RACK => b_rack,
      P_REGBUS_RB_WUPDATE => b_wupdate, P_REGBUS_RB_WADDR => b_waddr,
      P_REGBUS_RB_WDATA => b_wdata, P_REGBUS_RB_WACK => b_wack);

  hub: entity work.regbus_hub
    port map (
      S_CLK_I => s_clk, S_RST_I => rst, P_CLK_I => p_clk, P_RST_I => rst,
      S_REGBUS_RB_RUPDATE => b_rupdate, S_REGBUS_RB_RADDR => b_raddr,
      S_REGBUS_RB_RDATA => b_rdata, S_REGBUS_RB_RACK => b_rack,
      S_REGBUS_RB_WUPDATE => b_wupdate, S_REGBUS_RB_WADDR => b_waddr,
      S_REGBUS_RB_WDATA => b_wdata, S_REGBUS_RB_WACK => b_wack,
      PA_REGBUS_RB_RUPDATE => la.rupdate, PA_REGBUS_RB_RADDR => la.raddr, PA_REGBUS_RB_RDATA => la.rdata,
      PA_REGBUS_RB_RACK => la.rack, PA_REGBUS_RB_WUPDATE => la.wupdate, PA_REGBUS_RB_WADDR => la.waddr,
      PA_REGBUS_RB_WDATA => la.wdata, PA_REGBUS_RB_WACK => la.wack,
      PL_REGBUS_RB_RUPDATE => ll.rupdate, PL_REGBUS_RB_RADDR => ll.raddr, PL_REGBUS_RB_RDATA => ll.rdata,
      PL_REGBUS_RB_RACK => ll.rack, PL_REGBUS_RB_WUPDATE => ll.wupdate, PL_REGBUS_RB_WADDR => ll.waddr,
      PL_REGBUS_RB_WDATA => ll.wdata, PL_REGBUS_RB_WACK => ll.wack,
      PM_REGBUS_RB_RUPDATE => lm.rupdate, PM_REGBUS_RB_RADDR => lm.raddr, PM_REGBUS_RB_RDATA => lm.rdata,
      PM_REGBUS_RB_RACK => lm.rack, PM_REGBUS_RB_WUPDATE => lm.wupdate, PM_REGBUS_RB_WADDR => lm.waddr,
      PM_REGBUS_RB_WDATA => lm.wdata, PM_REGBUS_RB_WACK => lm.wack,
      PN_REGBUS_RB_RUPDATE => ln.rupdate, PN_REGBUS_RB_RADDR => ln.raddr, PN_REGBUS_RB_RDATA => ln.rdata,
      PN_REGBUS_RB_RACK => ln.rack, PN_REGBUS_RB_WUPDATE => ln.wupdate, PN_REGBUS_RB_WADDR => ln.waddr,
      PN_REGBUS_RB_WDATA => ln.wdata, PN_REGBUS_RB_WACK => ln.wack,
      PO_REGBUS_RB_RUPDATE => lo.rupdate, PO_REGBUS_RB_RADDR => lo.raddr, PO_REGBUS_RB_RDATA => lo.rdata,
      PO_REGBUS_RB_RACK => lo.rack, PO_REGBUS_RB_WUPDATE => lo.wupdate, PO_REGBUS_RB_WADDR => lo.waddr,
      PO_REGBUS_RB_WDATA => lo.wdata, PO_REGBUS_RB_WACK => lo.wack,
      PP_REGBUS_RB_RUPDATE => lp.rupdate, PP_REGBUS_RB_RADDR => lp.raddr, PP_REGBUS_RB_RDATA => lp.rdata,
      PP_REGBUS_RB_RACK => lp.rack, PP_REGBUS_RB_WUPDATE => lp.wupdate, PP_REGBUS_RB_WADDR => lp.waddr,
      PP_REGBUS_RB_WDATA => lp.wdata, PP_REGBUS_RB_WACK => lp.wack,
      DEBUG => open);

  global0: entity work.global_unit
    port map (
      ACLK => s_clk, RST_I => rst,
      S_REGBUS_RB_RADDR => la.raddr, S_REGBUS_RB_RDATA => la.rdata, S_REGBUS_RB_RUPDATE => la.rupdate,
      S_REGBUS_RB_RACK => la.rack, S_REGBUS_RB_WUPDATE => la.wupdate, S_REGBUS_RB_WADDR => la.waddr,
      S_REGBUS_RB_WDATA => la.wdata, S_REGBUS_RB_WACK => la.wack,
      ANALOG_PWR_EN_O => analog_pwr, TILE_EN_O => tile_en, LED_O => leds);

  adc0: entity work.adc_unit
    port map (
      ACLK => p_clk, RST_I => rst,
      S_REGBUS_RB_RUPDATE => lo.rupdate, S_REGBUS_RB_RADDR => lo.raddr, S_REGBUS_RB_RDATA => lo.rdata,
      S_REGBUS_RB_RACK => lo.rack, S_REGBUS_RB_WUPDATE => lo.wupdate, S_REGBUS_RB_WADDR => lo.waddr,
      S_REGBUS_RB_WDATA => lo.wdata, S_REGBUS_RB_WACK => lo.wack,
      ADC_EN_O => open, ADC_CLK_O => open, ADC_DATA_I => (others => '0'), ADC_DOF_I => '0',
      TIMESTAMP_I => timestamp, CROSS_TRIGGER_I => la_to_adc, CROSS_TRIGGER_O => adc_to_la);

  la_unit0: entity work.la_unit
    port map (
      ACLK => p_clk, RST_I => rst,
      S_REGBUS_RB_RUPDATE => lp.rupdate, S_REGBUS_RB_RADDR => lp.raddr, S_REGBUS_RB_RDATA => lp.rdata,
      S_REGBUS_RB_RACK => lp.rack, S_REGBUS_RB_WUPDATE => lp.wupdate, S_REGBUS_RB_WADDR => lp.waddr,
      S_REGBUS_RB_WDATA => lp.wdata, S_REGBUS_RB_WACK => lp.wack,
      PISO_I => piso_sync, POSI_I => posi, G_I => g, H_I => h, BAUD_I => baud,
      ATC_STATUS_I => atc_status, RX_STATUS_I => rx_status, TX_STATUS_I => tx_status, TIMESTAMP_I => timestamp,
      CROSS_TRIGGER_I => adc_to_la, CROSS_TRIGGER_O => la_to_adc);

  tx0: entity work.tx_unit
    port map (
      ACLK => p_clk, RST_I => rst, BAUD_I => baud,
      S_AXIS_TDATA => (others => '0'), S_AXIS_TVALID => '0', S_AXIS_TREADY => open,
      S_AXIS_TKEEP => (others => '1'), S_AXIS_TLAST => '0',
      S_REGBUS_RB_RADDR => ll.raddr, S_REGBUS_RB_RDATA => ll.rdata, S_REGBUS_RB_RUPDATE => ll.rupdate,
      S_REGBUS_RB_RACK => ll.rack, S_REGBUS_RB_WUPDATE => ll.wupdate, S_REGBUS_RB_WADDR => ll.waddr,
      S_REGBUS_RB_WDATA => ll.wdata, S_REGBUS_RB_WACK => ll.wack,
      POSI_O => posi, STATUS_O => tx_status, DEBUG_O => open);

  rx0: entity work.rx_unit
    port map (
      ACLK => p_clk, RST_I => rst, BAUD_I => baud,
      M_AXIS_TDATA => open, M_AXIS_TVALID => open, M_AXIS_TREADY => '1', M_AXIS_TKEEP => open,
      M_AXIS_TLAST => open,
      S_REGBUS_RB_RADDR => lm.raddr, S_REGBUS_RB_RDATA => lm.rdata, S_REGBUS_RB_RUPDATE => lm.rupdate,
      S_REGBUS_RB_RACK => lm.rack, S_REGBUS_RB_WUPDATE => lm.wupdate, S_REGBUS_RB_WADDR => lm.waddr,
      S_REGBUS_RB_WDATA => lm.wdata, S_REGBUS_RB_WACK => lm.wack,
      TIMESTAMP_I => timestamp, RX_MARKER_I => markers, FIFO_COUNT_I => x"00000123",
      PISO_I => (others => '1'), PISO_SYNC_O => piso_sync, LOOPBACK_I => posi, STATUS_O => rx_status);

  atc0: entity work.atc_unit
    port map (
      ACLK => p_clk, RST_I => rst,
      S_REGBUS_RB_RADDR => ln.raddr, S_REGBUS_RB_RDATA => ln.rdata, S_REGBUS_RB_RUPDATE => ln.rupdate,
      S_REGBUS_RB_RACK => ln.rack, S_REGBUS_RB_WUPDATE => ln.wupdate, S_REGBUS_RB_WADDR => ln.waddr,
      S_REGBUS_RB_WDATA => ln.wdata, S_REGBUS_RB_WACK => ln.wack,
      LEMO_A_I => '0', LEMO_B_I => '0', BAUD_O => baud, TIMESTAMP_O => timestamp,
      RX_MARKER_O => markers, UCLK_O => open, G_O => g, H_O => h, STATUS_O => atc_status);

  clock_until(s_clk, done, S_PERIOD);
  clock_until(p_clk, done, P_PERIOD);

  test: process
    -- previous access was to an S-domain unit (see the design assumption above)
    variable prev_s : boolean := false;

    function s_domain(addr : std_logic_vector(15 downto 0)) return boolean is
    begin
      return addr(15 downto 12) = x"F";   -- global scope (the ADC is on the P side, PO)
    end function;

    procedure settle(addr : std_logic_vector(15 downto 0)) is
    begin
      if prev_s and not s_domain(addr) then
        wait for C_CDC_SETTLE;
      end if;
      prev_s := s_domain(addr);
    end procedure;

    -- AXI-Lite read, as the PS does it (no outstanding transactions)
    procedure axi_read(addr : std_logic_vector(15 downto 0); data : out std_logic_vector(31 downto 0)) is
      variable n : integer := 0;
    begin
      settle(addr);
      wait until falling_edge(s_clk);
      araddr  <= addr;
      arvalid <= '1';
      rready  <= '1';
      loop
        wait until rising_edge(s_clk);
        exit when arready = '1';
      end loop;
      wait until falling_edge(s_clk);
      arvalid <= '0';
      loop
        wait until rising_edge(s_clk);
        n := n + 1;
        exit when rvalid = '1' or n > 2000;
      end loop;
      check(rvalid = '1', "read 0x" & hex(addr) & " completes");
      data := rdata;
      wait until falling_edge(s_clk);
      rready <= '0';
    end procedure;

    procedure axi_write(addr : std_logic_vector(15 downto 0); data : std_logic_vector(31 downto 0)) is
      variable n : integer := 0;
    begin
      settle(addr);
      wait until falling_edge(s_clk);
      awaddr  <= addr;
      wdata   <= data;
      awvalid <= '1';
      wvalid  <= '1';
      bready  <= '1';
      loop
        wait until rising_edge(s_clk);
        exit when awready = '1';
      end loop;
      check(wready = '1', "WREADY with AWREADY");
      wait until falling_edge(s_clk);
      awvalid <= '0';
      wvalid  <= '0';
      loop
        wait until rising_edge(s_clk);
        n := n + 1;
        exit when bvalid = '1' or n > 2000;
      end loop;
      check(bvalid = '1', "write 0x" & hex(addr) & " completes");
      wait until falling_edge(s_clk);
      bready <= '0';
    end procedure;

    procedure expect(addr : std_logic_vector(15 downto 0); expected : std_logic_vector(31 downto 0); msg : string) is
      variable v : std_logic_vector(31 downto 0);
    begin
      axi_read(addr, v);
      check_equal(v, expected, msg & " (0x" & hex(addr) & ")");
    end procedure;

    -- one readable/writable register per unit, with a value that uses every bit
    type reg_list_t is array (0 to 5) of std_logic_vector(15 downto 0);
    type val_list_t is array (0 to 5) of std_logic_vector(31 downto 0);
    constant REG : reg_list_t := (
      x"F020",                                               -- global SCRATCH_A
      x"D004",                                               -- adc CONFIG
      x"0004",                                               -- tx UART_CONFIG ch0
      x"7FBC",                                               -- rx PACMAN
      x"E110",                                               -- atc CONFIG_G
      x"C020");                                              -- la PERIOD
    constant VAL : val_list_t := (x"A1B2C3D4", x"0000F00D", x"5A5A0006", x"C3C3C3C3", x"0F1E2D3C", x"89ABCDEF");
    constant NAME : string := "global adc    tx     rx     atc    la     ";

    variable v, v2 : std_logic_vector(31 downto 0);
    variable j     : integer;
  begin
    aresetn <= '0';
    wait for 20 * P_PERIOD;
    wait until falling_edge(s_clk);
    aresetn <= '1';
    wait for 20 * P_PERIOD;

    print("-- each unit answers its own registers");
    req("REG-1.1");
    expect(x"FF10", x"00000003", "global FIRMWARE_MAJOR");
    expect(x"FF14", x"00000006", "global FIRMWARE_MINOR");
    expect(x"FF24", x"00000005", "global HARDWARE_MINOR (hw1v5)");
    expect(x"D000", x"00000ADC", "adc STATUS");
    expect(x"0004", x"00000006", "tx UART_CONFIG ch0 default");
    expect(x"4004", x"000A1104", "rx UART_CONFIG ch0 default");
    expect(x"7FF0", x"00000123", "rx FIFO_CNT (input)");
    expect(x"E100", x"0000000A", "atc CONFIG_UART default");
    expect(x"C05C", x"00008000", "la DEPTH");
    expect(x"D05C", x"00004000", "adc DEPTH (capture)");

    print("-- writes land in their unit only");
    req("REG-2.1");
    for i in 0 to 5 loop
      axi_write(REG(i), VAL(i));
    end loop;
    for i in 0 to 5 loop
      expect(REG(i), VAL(i), NAME(7*i+1 to 7*i+6) & " read back");
    end loop;
    req("REG-2.2");
    expect(x"F024", x"00000000", "global SCRATCH_B untouched");
    expect(x"0104", x"00000006", "tx UART_CONFIG ch1 untouched");

    print("-- back-to-back reads across every pair of units (C_CDC_SETTLE after S -> P): no mixed data");
    req("REG-3.2");
    for i in 0 to 5 loop
      for j in 0 to 5 loop
        axi_read(REG(i), v);
        axi_read(REG(j), v2);
        check_equal(v,  VAL(i), "pair " & NAME(7*i+1 to 7*i+6) & " -> " & NAME(7*j+1 to 7*j+6) & ": first");
        check_equal(v2, VAL(j), "pair " & NAME(7*i+1 to 7*i+6) & " -> " & NAME(7*j+1 to 7*j+6) & ": second");
      end loop;
    end loop;

    print("-- the same across clock phases: 0-15 idle cycles between accesses");
    req("REG-3.2");
    for gap in 0 to 15 loop
      for i in 0 to 5 loop
        j := (i + 1 + gap) mod 6;
        if j = i then
          j := (j + 1) mod 6;
        end if;
        axi_read(REG(i), v);
        wait for gap * S_PERIOD;
        axi_read(REG(j), v2);
        check_equal(v,  VAL(i), "gap " & integer'image(gap) & " " & NAME(7*i+1 to 7*i+6) & " -> " & NAME(7*j+1 to 7*j+6) & ": first");
        check_equal(v2, VAL(j), "gap " & integer'image(gap) & " " & NAME(7*i+1 to 7*i+6) & " -> " & NAME(7*j+1 to 7*j+6) & ": second");
        -- write one unit, then another right away: each lands once, in its own unit
        axi_write(REG(i), VAL(i) xor x"FFFFFFFF");
        wait for gap * S_PERIOD;
        axi_write(REG(j), VAL(j) xor x"FFFFFFFF");
        axi_read(REG(i), v);
        axi_read(REG(j), v2);
        check_equal(v,  VAL(i) xor x"FFFFFFFF", "gap " & integer'image(gap) & " write " & NAME(7*i+1 to 7*i+6) & " then " & NAME(7*j+1 to 7*j+6) & ": first");
        check_equal(v2, VAL(j) xor x"FFFFFFFF", "gap " & integer'image(gap) & " write " & NAME(7*i+1 to 7*i+6) & " then " & NAME(7*j+1 to 7*j+6) & ": second");
        axi_write(REG(i), VAL(i));
        axi_write(REG(j), VAL(j));
      end loop;
    end loop;

    print("-- unmapped addresses time out with 0xEEEEEEEE; the bus keeps working");
    req("REG-1.3");
    expect(x"9000", x"EEEEEEEE", "reserved scope 0x9");
    expect(x"7FFC", x"EEEEEEEE", "undefined rx register");
    expect(x"F030", x"EEEEEEEE", "undefined global register");
    -- broadcast channel (0x3B) is write only: no ack, so the bridge's timeout answers
    expect(x"3B04", x"EEEEEEEE", "tx broadcast UART_CONFIG read");
    expect(x"7B04", x"EEEEEEEE", "rx broadcast UART_CONFIG read");
    axi_write(x"9000", x"12345678");                 -- must complete (timeout), not hang
    expect(REG(3), VAL(3), "rx after timeouts");
    expect(REG(0), VAL(0), "global after timeouts");
    expect(REG(4), VAL(4), "atc after timeouts");

    print("-- global unit outputs follow ENABLES and LEDS");
    req("GLB-1.1");
    axi_write(x"F010", x"000103FF");
    wait for 100 ns;
    check_equal(tile_en, "1111111111", "TILE_EN_O all on");
    check_equal(analog_pwr, '1', "ANALOG_PWR_EN_O on (bit 16)");
    axi_write(x"F010", x"00000201");
    wait for 100 ns;
    check_equal(tile_en, "1000000001", "TILE_EN_O tiles 0 and 9");
    check_equal(analog_pwr, '0', "ANALOG_PWR_EN_O off");
    axi_write(x"F014", x"00000002");
    wait for 100 ns;
    req("GLB-1.2");
    check_equal(leds, "10", "LED_O follows LEDS");

    print("-- ATC timestamp advances; the RX unit sees the same clock domain");
    req("ATC-1.2");
    axi_read(x"E004", v);
    wait for 1 us;
    axi_read(x"E004", v2);
    check(unsigned(v2) > unsigned(v), "ATC TIMESTAMP increases (0x" & hex(v) & " -> 0x" & hex(v2) & ")");

    print("-- reset restores defaults everywhere");
    req("REG-4.1");
    wait until falling_edge(s_clk);
    aresetn <= '0';
    wait for 10 * P_PERIOD;
    wait until falling_edge(s_clk);
    aresetn <= '1';
    wait for 10 * P_PERIOD;
    expect(REG(0), x"00000000", "global SCRATCH_A after reset");
    expect(REG(2), x"00000006", "tx UART_CONFIG ch0 after reset");
    expect(REG(3), x"00000000", "rx PACMAN after reset");
    expect(REG(4), x"00000000", "atc CONFIG_G after reset");
    check_equal(tile_en, "0000000000", "TILE_EN_O off after reset");

    finish("regbus_system_check");
    done <= true;
    wait;
  end process;
end behaviour;
