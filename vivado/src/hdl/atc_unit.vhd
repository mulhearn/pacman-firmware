library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
library work;
use work.common.all;

entity atc_unit is
  port (
    -- clock and active-high reset
    ACLK                  : in std_logic; -- fast clock
    RST_I                 : in std_logic;

    -- REGBUS interface
    S_REGBUS_RB_RADDR	  : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_RDATA	  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_RUPDATE   : in  std_logic;
    S_REGBUS_RB_RACK      : out std_logic;

    S_REGBUS_RB_WUPDATE   : in  std_logic;
    S_REGBUS_RB_WADDR	  : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_WDATA	  : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_WACK      : out std_logic;

    -- front panel LEMO inputs:
    LEMO_A_I              : in std_logic;
    LEMO_B_I              : in std_logic;

    BAUD_O                : out std_logic;

    TIMESTAMP_O           : out std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
    RX_MARKER_O           : out std_logic_vector(C_NUM_MARKER-1 downto 0);

    UCLK_O                : out std_logic;
    G_O                   : out std_logic_vector(C_NUM_TILE-1 downto 0);
    H_O                   : out std_logic_vector(C_NUM_TILE-1 downto 0)
    );
end atc_unit;

architecture behaviour of atc_unit is
  component atc_registers is
    port (
      CLK_I : in std_logic;
      RST_I : in std_logic;

      S_REGBUS_RB_RUPDATE : in  std_logic;
      S_REGBUS_RB_RADDR	  : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_RDATA	  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_RACK    : out std_logic;
      S_REGBUS_RB_WUPDATE : in  std_logic;
      S_REGBUS_RB_WADDR	  : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_WDATA	  : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_WACK    : out std_logic;
      COUNT_REQ_O   : out std_logic;
      COUNT_CMD_O   : out std_logic_vector(C_BYTE_WIDTH-1 downto 0);
      COUNT_I       : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      POKE_A_O      : out std_logic;
      MASK_A_O      : out std_logic_vector(C_NUM_TILE-1 downto 0);
      POKE_B_O      : out std_logic;
      MASK_B_O      : out std_logic_vector(C_NUM_TILE-1 downto 0);
      POKE_C_O      : out std_logic;
      MASK_C_O      : out std_logic_vector(C_NUM_TILE-1 downto 0);
      POKE_D_O      : out std_logic;
      MASK_D_O      : out std_logic_vector(C_NUM_TILE-1 downto 0);
      CONFIG_INPUT_O : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CONFIG_UART_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CONFIG_BAUD_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CONFIG_G_O     : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CONFIG_H_O     : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LEMO_A_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LEMO_B_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_A_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_B_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_C_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_D_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LOGIC_A_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LOGIC_B_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      STATUS_I       : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      TIMESTAMP_I    : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0)
    );
  end component;

  component atc_timer is
    port (
      CLK_I      : in  std_logic;
      RST_I      : in  std_logic;
      CONFIG_UART_I : in  std_logic_vector(31 downto 0);
      CONFIG_BAUD_I : in  std_logic_vector(31 downto 0);
      UART_O     : out std_logic;
      BAUD_O     : out std_logic;
      UCLK_O     : out std_logic
    );
  end component;


  component rising_edge_sync is
    generic ( DEBOUNCE_CYCLES : integer);
    port (
      CLK_I  : in  std_logic;
      RST_I  : in  std_logic;

      ASYNC_SIGNAL_I : in std_logic;
      INVERT_I     : in std_logic;
      UPDATE_O       : out std_logic
      );
  end component;

  component atc_mux is
    port (
      CLK_I	   : in  std_logic;
      RST_I	   : in  std_logic;
      LEMO_A_I	   : in  std_logic;
      LEMO_B_I	   : in  std_logic;
      POKE_A_I	   : in  std_logic;
      POKE_B_I	   : in  std_logic;
      POKE_C_I	   : in  std_logic;
      POKE_D_I	   : in  std_logic;
      LOGIC_A_I	   : in  std_logic;
      LOGIC_B_I	   : in  std_logic;
      MASK_A_I       : in  std_logic_vector(C_NUM_TILE-1 downto 0);
      MASK_B_I       : in  std_logic_vector(C_NUM_TILE-1 downto 0);
      MASK_C_I       : in  std_logic_vector(C_NUM_TILE-1 downto 0);
      MASK_D_I       : in  std_logic_vector(C_NUM_TILE-1 downto 0);
      DST_LEMO_A_I   : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LEMO_B_I   : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_A_I   : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_B_I   : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_C_I   : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_D_I   : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LOGIC_A_I  : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LOGIC_B_I  : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      G_O            : out std_logic_vector(9 downto 0) := (others => '0');
      H_O            : out std_logic_vector(9 downto 0) := (others => '0');
      M_O            : out std_logic_vector(C_NUM_MARKER-1 downto 0) := (others => '0')
      );
  end component;

  component timer is
    port (
      CLK_I      : in  std_logic;
      RST_I      : in  std_logic;
      CONFIG_I   : in  std_logic_vector(31 downto 0);
      STROBE_O   : out std_logic
    );
  end component;

  component atc_counter is
    port (
      CLK_I	               : in  std_logic;
      RST_I	               : in  std_logic;

     --input signal
      LEMO_A_I	            : in  std_logic;
      LEMO_B_I	            : in  std_logic;
      POKE_A_I	            : in  std_logic;
      POKE_B_I	            : in  std_logic;
      POKE_C_I	            : in  std_logic;
      POKE_D_I	            : in  std_logic;
      M_I                   : in std_logic_vector(C_NUM_MARKER -1 downto 0) ;
      G_I                   : in std_logic_vector(C_NUM_TILE -1  downto 0) ;
      H_I                   : in std_logic_vector(C_NUM_TILE -1 downto 0) ;

      UPDATE_I              : in  std_logic;
      COMMAND_I             : in  std_logic_vector(7 downto 0);

    --output
      COUNT_O               : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
  );
  end component;

  component atc_buffer is
    port (
      CLK_I      : in  std_logic;
      RST_I      : in  std_logic;
      UART_I     : in  std_logic;
      SIG_I      : in  std_logic_vector(C_NUM_TILE-1 downto 0);
      CONFIG_I   : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      SIG_O      : out std_logic_vector(C_NUM_TILE-1 downto 0)
      );
  end component;

  component timestamp is
    port (
      CLK_I        : in  std_logic;
      RST_I        : in  std_logic;
      SYNC_I       : in  std_logic;
      ENABLE_I     : in  std_logic;
      TIMESTAMP_O  : out std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0)
    );
  end component;

  -- system clock domain:
  signal clk        : std_logic;
  signal rst        : std_logic;
  -- uart strobe, marking start of each UART clock period:
  signal uart       : std_logic;
  -- baud strobe, marking start of each baud period:
  signal baud       : std_logic;

  -- stimuli:
  signal lemo_a     : std_logic;
  signal lemo_b     : std_logic;
  signal poke_a     : std_logic;
  signal mask_a     : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal poke_b     : std_logic;
  signal mask_b     : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal poke_c     : std_logic;
  signal mask_c     : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal poke_d     : std_logic;
  signal mask_d     : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal logic_a    : std_logic;
  signal logic_b    : std_logic;

  -- output to ASICs:
  signal g          : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal h          : std_logic_vector(C_NUM_TILE-1 downto 0);

  --markers:
  signal m          : std_logic_vector(C_NUM_MARKER-1 downto 0) := (others => '0');

  -- configs:
  signal config_input : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal config_uart  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal config_baud  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal config_g     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal config_h     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal dst_lemo_a  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_lemo_b  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_poke_a  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_poke_b  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_poke_c  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_poke_d  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_logic_a : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dst_logic_b : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');

  -- counter request-driven interface:
  signal count_req    : std_logic;
  signal count_cmd    : std_logic_vector(C_BYTE_WIDTH-1 downto 0);
  signal count      : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  signal status     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal ts  : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0) := (others => '0');

begin
  clk <= ACLK;
  rst <= RST_I;

  TIMESTAMP_O <= ts;
  RX_MARKER_O <= m;

  ts0: timestamp port map (
    CLK_I        => clk,
    RST_I        => rst,
    SYNC_I       => m(0),
    ENABLE_I     => uart,
    TIMESTAMP_O  => ts
  );

  timer0: atc_timer port map (
    CLK_I      => clk,
    RST_I      => rst,
    CONFIG_UART_I => config_uart,
    CONFIG_BAUD_I => config_baud,
    UART_O     => uart,
    BAUD_O     => baud,
    UCLK_O     => UCLK_O
  );

  logic_a_timer: timer
    port map (
      CLK_I      => clk,
      RST_I      => rst,
      CONFIG_I   => x"00000000",
      STROBE_O   => logic_a
      );

  logic_b_timer: timer
    port map (
      CLK_I      => clk,
      RST_I      => rst,
      CONFIG_I   => x"00000000",
      STROBE_O   => logic_b
      );



  atcreg0:atc_registers port map (
    CLK_I               => clk,
    RST_I               => rst,
    S_REGBUS_RB_RUPDATE => S_REGBUS_RB_RUPDATE,
    S_REGBUS_RB_RADDR   => S_REGBUS_RB_RADDR,
    S_REGBUS_RB_RDATA   => S_REGBUS_RB_RDATA,
    S_REGBUS_RB_RACK    => S_REGBUS_RB_RACK,
    S_REGBUS_RB_WUPDATE => S_REGBUS_RB_WUPDATE,
    S_REGBUS_RB_WADDR   => S_REGBUS_RB_WADDR,
    S_REGBUS_RB_WDATA   => S_REGBUS_RB_WDATA,
    S_REGBUS_RB_WACK    => S_REGBUS_RB_WACK,

    CONFIG_INPUT_O => config_input,
    CONFIG_UART_O  => config_uart,
    CONFIG_BAUD_O  => config_baud,
    CONFIG_G_O     => config_g,
    CONFIG_H_O     => config_h,
    DST_LEMO_A_O   => dst_lemo_a,
    DST_LEMO_B_O   => dst_lemo_b,
    DST_POKE_A_O   => dst_poke_a,
    DST_POKE_B_O   => dst_poke_b,
    DST_POKE_C_O   => dst_poke_c,
    DST_POKE_D_O   => dst_poke_d,
    DST_LOGIC_A_O  => dst_logic_a,
    DST_LOGIC_B_O  => dst_logic_b,

    COUNT_REQ_O         => count_req,
    COUNT_CMD_O         => count_cmd,
    POKE_A_O            => poke_a,
    MASK_A_O            => mask_a,
    POKE_B_O            => poke_b,
    MASK_B_O            => mask_b,
    POKE_C_O            => poke_c,
    MASK_C_O            => mask_c,
    POKE_D_O            => poke_d,
    MASK_D_O            => mask_d,
    STATUS_I            => status,
    COUNT_I             => count,
    TIMESTAMP_I         => ts
  );


 lemoa0: rising_edge_sync
   generic map(
     DEBOUNCE_CYCLES => 4
     )

   port map (
     CLK_I  => clk,
     RST_I  => rst,
     ASYNC_SIGNAL_I => LEMO_A_I,
     INVERT_I => config_input(0),
     UPDATE_O => lemo_a
   );

  lemob0: rising_edge_sync
    generic map(
      DEBOUNCE_CYCLES => 4
     )
   port map (
     CLK_I  => clk,
     RST_I  => rst,
     ASYNC_SIGNAL_I => LEMO_B_I,
     INVERT_I => config_input(1),
     UPDATE_O => lemo_b
   );

  atcmux0: atc_mux port map (
    CLK_I         => clk,
    RST_I         => rst,
    LEMO_A_I	  => lemo_a,
    LEMO_B_I	  => lemo_b,
    POKE_A_I	  => poke_a,
    POKE_B_I	  => poke_b,
    POKE_C_I	  => poke_c,
    POKE_D_I      => poke_d,
    LOGIC_A_I	  => logic_a,
    LOGIC_B_I	  => logic_b,
    MASK_A_I      => mask_a,
    MASK_B_I      => mask_b,
    MASK_C_I      => mask_c,
    MASK_D_I      => mask_d,
    DST_LEMO_A_I  => dst_lemo_a,
    DST_LEMO_B_I  => dst_lemo_b,
    DST_POKE_A_I  => dst_poke_a,
    DST_POKE_B_I  => dst_poke_b,
    DST_POKE_C_I  => dst_poke_c,
    DST_POKE_D_I  => dst_poke_d,
    DST_LOGIC_A_I => dst_logic_a,
    DST_LOGIC_B_I => dst_logic_b,
    G_O           => g,
    H_O           => h,
    M_O           => m
    );

  atccnt0: atc_counter port map (
    CLK_I	     => clk,
    RST_I 	     => rst,
    LEMO_A_I	     => lemo_a,
    LEMO_B_I	     => lemo_b,
    POKE_A_I	     => poke_a,
    POKE_B_I	     => poke_b,
    POKE_C_I	     => poke_c,
    POKE_D_I	     => poke_d,
    G_I              => g,
    H_I              => h,
    M_I              => m,
    UPDATE_I         => count_req,
    COMMAND_I        => count_cmd,
    COUNT_O          => count
  );

  BAUD_O <= baud;

  gbuf0: atc_buffer port map (
    CLK_I	=> clk,
    RST_I 	=> rst,
    UART_I      => uart,
    SIG_I	=> g,
    CONFIG_I    => config_g,
    SIG_O	=> G_O
  );

  hbuf0: atc_buffer port map (
    CLK_I	=> clk,
    RST_I 	=> rst,
    UART_I      => uart,
    SIG_I	=> h,
    CONFIG_I    => config_h,
    SIG_O	=> H_O
  );





end behaviour;
