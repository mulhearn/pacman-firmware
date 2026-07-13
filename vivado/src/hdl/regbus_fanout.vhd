library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity regbus_fanout is
  generic (
    N_PRIMARY     : integer  := 3
  );
  port (
    -- Secondary REGBUS:
    S_REGBUS_RB_RUPDATE  : in   std_logic;
    S_REGBUS_RB_RADDR	 : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_RDATA	 : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_RACK     : out  std_logic;

    S_REGBUS_RB_WUPDATE  : in   std_logic;
    S_REGBUS_RB_WADDR	 : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_WDATA	 : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_WACK     : out  std_logic;

    -- Primary REGBUS arrays:
    P_REGBUS_RB_RUPDATE  : out  std_logic_vector(0 to N_PRIMARY-1);
    P_REGBUS_RB_RADDR	 : out  regbus_addr_array_t(0 to N_PRIMARY-1);
    -- NOTE: primaries must hold RDATA stable from one update to the next,
    -- and drive 0 when not addressed -- S_REGBUS_RB_RDATA below is a plain
    -- OR across all lanes, not ack-qualified, so this is load-bearing.
    P_REGBUS_RB_RDATA	 : in   regbus_data_array_t(0 to N_PRIMARY-1);
    P_REGBUS_RB_RACK     : in   std_logic_vector(0 to N_PRIMARY-1);

    P_REGBUS_RB_WUPDATE  : out  std_logic_vector(0 to N_PRIMARY-1);
    P_REGBUS_RB_WADDR	 : out  regbus_addr_array_t(0 to N_PRIMARY-1);
    P_REGBUS_RB_WDATA	 : out  regbus_data_array_t(0 to N_PRIMARY-1);
    P_REGBUS_RB_WACK     : in   std_logic_vector(0 to N_PRIMARY-1)
    );
end;

architecture behavioral of regbus_fanout is
  function reductive_or (a_vector : std_logic_vector) return std_logic is
    variable r : std_logic := '0';
  begin
    for i in a_vector'range loop
      r := r or a_vector(i);
    end loop;
    return r;
  end function;

  function reductive_or (data_array : regbus_data_array_t) return std_logic_vector is
    variable data : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  begin
    for i in data_array'range loop
      data := data or data_array(i);
    end loop;
    return data;
  end function;

begin
  -- broadcast secondary -> all primaries (write side, unconditional fanout):
  gen_fanout : for i in 0 to N_PRIMARY-1 generate
    P_REGBUS_RB_RUPDATE(i) <= S_REGBUS_RB_RUPDATE;
    P_REGBUS_RB_RADDR(i)   <= S_REGBUS_RB_RADDR;
    P_REGBUS_RB_WUPDATE(i) <= S_REGBUS_RB_WUPDATE;
    P_REGBUS_RB_WADDR(i)   <= S_REGBUS_RB_WADDR;
    P_REGBUS_RB_WDATA(i)   <= S_REGBUS_RB_WDATA;
  end generate;

  S_REGBUS_RB_RACK  <= reductive_or(P_REGBUS_RB_RACK);
  S_REGBUS_RB_WACK  <= reductive_or(P_REGBUS_RB_WACK);
  S_REGBUS_RB_RDATA <= reductive_or(P_REGBUS_RB_RDATA);

end;
