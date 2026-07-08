library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;

entity atc_registers is
  port (
    CLK_I : in std_logic;
    RST_I : in std_logic;

    S_REGBUS_RB_RUPDATE : in  std_logic;
    S_REGBUS_RB_RADDR	: in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_RDATA	: out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_RACK    : out std_logic;
    S_REGBUS_RB_WUPDATE : in  std_logic;
    S_REGBUS_RB_WADDR	: in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_WDATA	: in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_WACK    : out std_logic;

    -- request update of counts: (from UCLK to CLK)
    COUNT_REQ_O         : out std_logic;
    COUNT_CMD_O         : out std_logic_vector(C_BYTE_WIDTH-1 downto 0);
    COUNT_I             : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

    -- poke stimuli, each with associated mask, handled expiditiously:
    POKE_A_O            : out std_logic;
    MASK_A_O            : out std_logic_vector(C_NUM_TILE-1 downto 0);
    POKE_B_O            : out std_logic;
    MASK_B_O            : out std_logic_vector(C_NUM_TILE-1 downto 0);
    POKE_C_O            : out std_logic;
    MASK_C_O            : out std_logic_vector(C_NUM_TILE-1 downto 0);
    POKE_D_O            : out std_logic;
    MASK_D_O            : out std_logic_vector(C_NUM_TILE-1 downto 0);

    -- ATC unit configuration:
    CONFIG_INPUT_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    CONFIG_UART_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    CONFIG_BAUD_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    CONFIG_G_O      : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    CONFIG_H_O      : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_LEMO_A_O    : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_LEMO_B_O    : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_POKE_A_O    : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_POKE_B_O    : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_POKE_C_O    : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_POKE_D_O    : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_LOGIC_A_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_LOGIC_B_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

    STATUS_I        : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    TIMESTAMP_I     : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0)
  );
end;

architecture behavioral of atc_registers is
  signal clk : std_logic;
  signal rst : std_logic;

  signal rupdate  : std_logic;
  signal raddr    : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal rdata    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal rack     : std_logic := '0';
  signal wupdate  : std_logic;
  signal waddr    : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal wdata    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal wack     : std_logic := '0';

  signal config_input : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0):= (others => '0');
  signal config_uart  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0):= (others => '0');
  signal config_baud  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0):= (others => '0');
  signal config_g     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0):= (others => '0');
  signal config_h     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0):= (others => '0');
  signal dst_lemo_a  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_lemo_b  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_poke_a  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_poke_b  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_poke_c  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_poke_d  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_logic_a : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_logic_b : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');

begin

  -- Clock and reset inputs:
  clk <= CLK_I;
  rst <= RST_I;

  --REGBUS read signals
  rupdate  <= S_REGBUS_RB_RUPDATE;
  raddr    <= S_REGBUS_RB_RADDR;
  S_REGBUS_RB_RDATA <= rdata;
  S_REGBUS_RB_RACK  <= rack;
  --REGBUS write signals
  wupdate  <= S_REGBUS_RB_WUPDATE;
  waddr    <= S_REGBUS_RB_WADDR;
  wdata    <= S_REGBUS_RB_WDATA;
  S_REGBUS_RB_WACK	 <= wack;

  -- output registers:
  CONFIG_INPUT_O  <= config_input;
  CONFIG_UART_O   <= config_uart;
  CONFIG_BAUD_O   <= config_baud;
  CONFIG_G_O      <= config_g;
  CONFIG_H_O      <= config_h;
  DST_LEMO_A_O    <= dst_lemo_a;
  DST_LEMO_B_O    <= dst_lemo_b;
  DST_POKE_A_O    <= dst_poke_a;
  DST_POKE_B_O    <= dst_poke_b;
  DST_POKE_C_O    <= dst_poke_c;
  DST_POKE_D_O    <= dst_poke_d;
  DST_LOGIC_A_O   <= dst_logic_a;
  DST_LOGIC_B_O   <= dst_logic_b;

  -- Handle Read Request:
  process(clk, rst)
    variable scope   : integer range 0 to 16#F#;
    variable reg     : integer range 0 to 16#FFF#;
  begin
    if (rst = '1') then
      rack <= '0';
      rdata <= x"00000000";
    elsif (rising_edge(clk)) then
      rack <= '0';
      if (rupdate='1') then
        scope := to_integer(unsigned(raddr(15 downto 12)));
        reg   := to_integer(unsigned(raddr(11 downto 0)));
        rdata <= x"00000000";
        if (scope = C_SCOPE_ATC) then
          rdata <= x"EEEEEEEE";
          if(reg= C_ADDR_ATC_CONFIG_UART) then
            rdata <= config_uart;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_CONFIG_BAUD) then
            rdata <= config_baud;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_CONFIG_INPUT) then
            rdata <= config_input;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_CONFIG_G) then
            rdata <= config_g;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_CONFIG_H) then
            rdata <= config_h;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_LEMO_A) then
            rdata <= dst_lemo_a;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_LEMO_B) then
            rdata <= dst_lemo_b;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_POKE_A) then
            rdata <= dst_poke_a;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_POKE_B) then
            rdata <= dst_poke_b;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_POKE_C) then
            rdata <= dst_poke_c;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_POKE_D) then
            rdata <= dst_poke_d;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_LOGIC_A) then
            rdata <= dst_logic_a;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_LOGIC_B) then
            rdata <= dst_logic_b;
            rack  <= '1';
          elsif(reg= C_ADDR_ATC_COUNT) then
            rdata <= COUNT_I;
            rack  <= '1';
          elsif (reg= C_ADDR_ATC_STATUS) then
            rdata <= STATUS_I;
            rack  <= '1';
          elsif (reg= C_ADDR_ATC_TIMESTAMP) then
            rdata <= TIMESTAMP_I(31 downto 0);
            rack  <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Handle Write Request:
  process(clk, rst)
    variable scope   : integer range 0 to 16#F#;
    variable reg     : integer range 0 to 16#FFF#;
  begin
    if (rst = '1') then
      wack  <= '0';
      COUNT_REQ_O  <= '0';
      COUNT_CMD_O  <= (others => '0');
      POKE_A_O <= '0';
      POKE_B_O <= '0';
      POKE_C_O <= '0';
      POKE_D_O <= '0';
      MASK_A_O <= (others => '0');
      MASK_B_O <= (others => '0');
      MASK_C_O <= (others => '0');
      MASK_D_O <= (others => '0');
      config_uart  <= std_logic_vector(to_unsigned(C_DEFAULT_ATC_CONFIG_UART, C_RB_DATA_WIDTH));
      config_baud  <= std_logic_vector(to_unsigned(C_DEFAULT_ATC_CONFIG_BAUD, C_RB_DATA_WIDTH));
      config_input <= (others => '0');
      config_g     <= (others => '0');
      config_h     <= (others => '0');
      dst_lemo_a   <= (others => '0');
      dst_lemo_b   <= (others => '0');
      dst_poke_a   <= (others => '0');
      dst_poke_b   <= (others => '0');
      dst_poke_c   <= (others => '0');
      dst_poke_d   <= (others => '0');
      dst_logic_a  <= (others => '0');
      dst_logic_b  <= (others => '0');
    elsif (rising_edge(clk)) then
      wack <= '0';
      COUNT_REQ_O  <= '0';
      COUNT_CMD_O  <= (others => '0');
      POKE_A_O <= '0';
      POKE_B_O <= '0';
      POKE_C_O <= '0';
      POKE_D_O <= '0';
      MASK_A_O <= (others => '0');
      MASK_B_O <= (others => '0');
      MASK_C_O <= (others => '0');
      MASK_D_O <= (others => '0');
      if (wupdate='1') then
        scope := to_integer(unsigned(waddr(15 downto 12)));
        reg   := to_integer(unsigned(waddr(11 downto 0)));
        if (scope=C_SCOPE_ATC) then
          if(reg= C_ADDR_ATC_COUNT_REQ) then
            COUNT_REQ_O <= '1';
            COUNT_CMD_O <= wdata(C_BYTE_WIDTH-1 downto 0);
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_POKE_A) then
            POKE_A_O <= '1';
            MASK_A_O <= wdata(C_NUM_TILE-1 downto 0);
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_POKE_B) then
            POKE_B_O <= '1';
            MASK_B_O <= wdata(C_NUM_TILE-1 downto 0);
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_POKE_C) then
            POKE_C_O <= '1';
            MASK_C_O <= wdata(C_NUM_TILE-1 downto 0);
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_POKE_D) then
            POKE_D_O <= '1';
            MASK_D_O <= wdata(C_NUM_TILE-1 downto 0);
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_CONFIG_UART) then
            config_uart <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_CONFIG_BAUD) then
            config_baud <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_CONFIG_INPUT) then
            config_input <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_CONFIG_G) then
            config_g <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_CONFIG_H) then
            config_h <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_LEMO_A) then
            dst_lemo_a <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_LEMO_B) then
            dst_lemo_b <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_POKE_A) then
            dst_poke_a <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_POKE_B) then
            dst_poke_b <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_POKE_C) then
            dst_poke_c <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_POKE_D) then
            dst_poke_d <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_LOGIC_A) then
            dst_logic_a <= wdata;
            wack  <= '1';
          elsif(reg= C_ADDR_ATC_DST_LOGIC_B) then
            dst_logic_b <= wdata;
            wack  <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

end;

