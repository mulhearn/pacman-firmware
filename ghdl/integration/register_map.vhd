library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package register_map is

  -- Top Level SCOPE (4 - bits)
  constant C_SCOPE_GLOBAL   : integer := 2#1111#; -- GLOBAL = 0xF = 0b1111
  constant C_SCOPE_ATC      : integer := 2#1110#; -- ATC    = 0xE = 0b1110
  constant C_SCOPE_ADC      : integer := 2#1101#; -- ADC    = 0xD = 0b1101
  constant C_SCOPE_LA       : integer := 2#1100#; -- LA     = 0xC = 0b1100
  constant C_SCOPE_UPPER_TX : integer := 2#00#;   -- TX     =     = 0b00XX
  constant C_SCOPE_UPPER_RX : integer := 2#01#;   -- RX     =     = 0b01XX

  -- TX and RX address:  scope (2 bits), chan (6 bits), register (8 bits).  Special channels:
  constant C_CHAN_BROADCAST : integer := 16#3B#;  -- write to every UART
  constant C_CHAN_GLOBAL    : integer := 16#3F#;  -- registers not specific to a UART

  --
  -- Registers with SCOPE=GLOBAL
  --
  constant C_ADDR_GLOBAL_STATUS          : integer := 16#000#; -- Read Only
  constant C_ADDR_GLOBAL_ENABLES         : integer := 16#010#;
  constant C_ADDR_GLOBAL_LEDS            : integer := 16#014#;
  constant C_ADDR_GLOBAL_SCRATCH_A       : integer := 16#020#;
  constant C_ADDR_GLOBAL_SCRATCH_B       : integer := 16#024#;
  constant C_ADDR_GLOBAL_FIRMWARE_MAJOR  : integer := 16#F10#; -- Read Only
  constant C_ADDR_GLOBAL_FIRMWARE_MINOR  : integer := 16#F14#; -- Read Only
  constant C_ADDR_GLOBAL_FIRMWARE_PATCH  : integer := 16#F18#; -- Read Only
  constant C_ADDR_GLOBAL_HARDWARE_MAJOR  : integer := 16#F20#; -- Read Only
  constant C_ADDR_GLOBAL_HARDWARE_MINOR  : integer := 16#F24#; -- Read Only
  constant C_ADDR_GLOBAL_HARDWARE_PATCH  : integer := 16#F28#; -- Read Only
  constant C_ADDR_GLOBAL_SYNTHESIS_DATE  : integer := 16#F30#; -- Read Only
  constant C_ADDR_GLOBAL_GIT_HASH_UPPER  : integer := 16#F40#; -- Read Only
  constant C_ADDR_GLOBAL_GIT_HASH_LOWER  : integer := 16#F44#; -- Read Only
  constant C_ADDR_GLOBAL_BUILD_FLAGS     : integer := 16#F48#; -- Read Only: bit 0 DIRTY, bit 1 OFFICIAL_RELEASE
  constant C_ADDR_GLOBAL_VIVADO_MAJOR    : integer := 16#F50#; -- Read Only
  constant C_ADDR_GLOBAL_VIVADO_MINOR    : integer := 16#F54#; -- Read Only

  --
  -- Registers with SCOPE=ATC (ASIC Timing and Control)
  --
  constant C_ADDR_ATC_STATUS          : integer := 16#000#; --read only
  constant C_ADDR_ATC_TIMESTAMP       : integer := 16#004#; --read only

  constant C_ADDR_ATC_POKE_A          : integer := 16#0A0#; --write only
  constant C_ADDR_ATC_POKE_B          : integer := 16#0B0#; --write only
  constant C_ADDR_ATC_POKE_C          : integer := 16#0C0#; --write only
  constant C_ADDR_ATC_POKE_D          : integer := 16#0D0#; --write only

  constant C_ADDR_ATC_CONFIG_UART     : integer := 16#100#;
  constant C_ADDR_ATC_CONFIG_BAUD     : integer := 16#104#;
  constant C_ADDR_ATC_CONFIG_INPUT    : integer := 16#108#;
  constant C_ADDR_ATC_CONFIG_G        : integer := 16#110#;
  constant C_ADDR_ATC_CONFIG_H        : integer := 16#114#;
  constant C_ADDR_ATC_DST_LEMO_A      : integer := 16#120#;
  constant C_ADDR_ATC_DST_LEMO_B      : integer := 16#124#;
  constant C_ADDR_ATC_DST_POKE_A      : integer := 16#128#;
  constant C_ADDR_ATC_DST_POKE_B      : integer := 16#12C#;
  constant C_ADDR_ATC_DST_POKE_C      : integer := 16#130#;
  constant C_ADDR_ATC_DST_POKE_D      : integer := 16#134#;
  constant C_ADDR_ATC_DST_LOGIC_A     : integer := 16#138#;
  constant C_ADDR_ATC_DST_LOGIC_B     : integer := 16#13C#;

  constant C_ADDR_ATC_COUNT_REQ       : integer := 16#200#;
  constant C_ADDR_ATC_COUNT           : integer := 16#204#; --read only

  --
  -- Registers with SCOPE=UART_TX
  --
  -- Per UART registers, with chan = 0x00-0x28, and broadcast chan=0x3B (if writable):
  constant C_ADDR_TX_UART_STATUS    : integer := 16#00#; -- Read Only
  constant C_ADDR_TX_UART_CONFIG    : integer := 16#04#;
  constant C_ADDR_TX_UART_STARTS    : integer := 16#20#;
  constant C_ADDR_TX_UART_BEATS     : integer := 16#24#; -- count valid='1' & ready='1'

  -- Not UART specific, at chan=0x3F:
  -- TX look feature channel selection:
  constant C_ADDR_TX_LOOK_SELECT    : integer := 16#A0#;
  -- TX look feature UART data (MSB) B(32 bits) A(32 bits) (LSB):
  constant C_ADDR_TX_LOOK_LOWER     : integer := 16#A4#; -- Read Only
  constant C_ADDR_TX_LOOK_UPPER     : integer := 16#A8#; -- Read Only
  -- TX buffer status
  constant C_ADDR_TX_BUFFER_STATUS  : integer := 16#B0#;
  constant C_ADDR_TX_ZERO_CNTS      : integer := 16#F8#;

  --
  -- Registers with SCOPE=UART_RX
  --

  -- Per UART registers, with chan = 0x00-0x28, and broadcast chan=0x3B (if writable):
  constant C_ADDR_RX_UART_STATUS    : integer := 16#00#; -- Read Only
  constant C_ADDR_RX_UART_CONFIG    : integer := 16#04#;
  constant C_ADDR_RX_UART_CHAN      : integer := 16#08#;
  -- Counters: (Zero by writing ZERO_CNTS register on global channel 0x7F)
  constant C_ADDR_RX_UART_STARTS    : integer := 16#20#; -- count busy '0'->'1'
  constant C_ADDR_RX_UART_BEATS     : integer := 16#24#; -- count valid='1' & ready='1'
  constant C_ADDR_RX_UART_UPDATES   : integer := 16#28#; -- count update='1'
  constant C_ADDR_RX_UART_LOST      : integer := 16#2C#; -- count lost='1'
  constant C_ADDR_RX_UART_FRAME_ERR : integer := 16#30#; -- count frame_err='1'
  constant C_ADDR_RX_UART_NOISE     : integer := 16#34#; -- count noise='1'

  -- Not UART specific, at chan=0x3F:
  -- test pattern generation:
  constant C_ADDR_RX_PATTERN_LOWER  : integer := 16#80#;
  constant C_ADDR_RX_PATTERN_UPPER  : integer := 16#84#;
  constant C_ADDR_RX_PATTERN_DELAY  : integer := 16#88#;
  constant C_ADDR_RX_PATTERN_CONFIG : integer := 16#8C#;
  constant C_ADDR_RX_PATTERN_STATUS : integer := 16#90#;
  constant C_ADDR_RX_PATTERN_STARTS : integer := 16#94#;
  constant C_ADDR_RX_PATTERN_STOPS  : integer := 16#98#;

  -- RX look feature channel selection:
  constant C_ADDR_RX_LOOK_SELECT    : integer := 16#A0#;
  -- RX look feature UART data (MSB) B(32 bits) A(32 bits) (LSB):
  constant C_ADDR_RX_LOOK_LOWER     : integer := 16#A4#; -- Read Only
  constant C_ADDR_RX_LOOK_UPPER     : integer := 16#A8#; -- Read Only

  -- RX buffer status, config, and enables:
  constant C_ADDR_RX_BUFFER_STATUS  : integer := 16#B0#; -- Read Only
  constant C_ADDR_RX_BUFFER_CONFIG  : integer := 16#B4#;
  constant C_ADDR_RX_BUFFER_ENABLES : integer := 16#B8#;
  -- PACMAN ID:
  constant C_ADDR_RX_PACMAN         : integer := 16#BC#;

  -- FIFO counters from AXI Stream DATA FIFO
  constant C_ADDR_RX_FIFO_CNT  : integer := 16#F0#;
  constant C_ADDR_RX_FIFO_MAX  : integer := 16#F4#;
  constant C_ADDR_RX_ZERO_CNTS : integer := 16#F8#;

  -- Heartbeat and Sync Config regisiters
  constant C_ADDR_RX_HEARTBEAT_CONFIG : integer := 16#C0#;
  constant C_ADDR_RX_ROLLOVER_CONFIG  : integer := 16#C4#;
  -- LUT mapping 2-bit packet descriptor to one byte header field:
  constant C_ADDR_RX_WORD_TYPE_LUT    : integer := 16#C8#;

  constant C_ADDR_RX_HEADER_A         : integer := 16#D0#;
  constant C_ADDR_RX_HEADER_B         : integer := 16#D4#;
  constant C_ADDR_RX_HEADER_C         : integer := 16#D8#;
  constant C_ADDR_RX_HEADER_D         : integer := 16#DC#;

  constant C_ADDR_RX_EOP_HEADER       : integer := 16#E0#;

  -- Registers with SCOPE=ADC
  constant C_ADDR_ADC_STATUS          : integer := 16#000#;  -- R   0x00000ADC
  constant C_ADDR_ADC_CONFIG          : integer := 16#004#;  -- RW  bit 0:  ADC enable
  constant C_ADDR_ADC_LOOK            : integer := 16#010#;  -- R   the ADC data as selected by ADC_MUX:  bits 11-0, overflow bit 12
  -- ADC capture (bram_buffer.vhd), at the logic analyzer's offsets:  sample bits 11-0 data, 12 overflow, 13 comparator
  constant C_ADDR_ADC_PERIOD          : integer := 16#020#;  -- RW  sample every PERIOD clocks (0:  no samples)
  constant C_ADDR_ADC_MODE            : integer := 16#028#;  -- RW  bit 1:  acquisition enable (reset 1)
  constant C_ADDR_ADC_TRIG            : integer := 16#02C#;  -- RW  bits 4-0 trigger sample bit, 9-8 edge (0 rise, 1 fall, 2 either),
                                                             --     10 cross trigger (the logic analyzer's) enable
  constant C_ADDR_ADC_POST            : integer := 16#030#;  -- RW  samples after the triggering one
  constant C_ADDR_ADC_ARM             : integer := 16#040#;  -- W   start a capture
  constant C_ADDR_ADC_FORCE           : integer := 16#044#;  -- W   trigger now
  constant C_ADDR_ADC_START           : integer := 16#048#;  -- W   readout:  point at the oldest sample
  constant C_ADDR_ADC_NEXT            : integer := 16#04C#;  -- W   readout:  next sample
  constant C_ADDR_ADC_CAPTURE_STATUS  : integer := 16#050#;  -- R   bit 0 armed, 1 triggered, 2 done
  constant C_ADDR_ADC_TRIG_POS        : integer := 16#054#;  -- R   position of the triggering sample (0 = oldest)
  constant C_ADDR_ADC_COUNT           : integer := 16#058#;  -- R   samples in the buffer
  constant C_ADDR_ADC_DEPTH           : integer := 16#05C#;  -- R   buffer depth
  constant C_ADDR_ADC_TS_LOWER        : integer := 16#060#;  -- R   timestamp of the trigger, bits 31-0
  constant C_ADDR_ADC_TS_UPPER        : integer := 16#064#;  -- R   bits 63-32
  constant C_ADDR_ADC_DATA            : integer := 16#070#;  -- R   the sample pointed at
  -- ADC emulator (adc_emul.vhd)
  constant C_ADDR_ADC_EMUL_MIN        : integer := 16#080#;  -- RW  bits 11-0:  ramp start and minimum
  constant C_ADDR_ADC_EMUL_MAX        : integer := 16#084#;  -- RW  bits 11-0:  ramp maximum
  constant C_ADDR_ADC_EMUL_STEP       : integer := 16#088#;  -- RW  bits 12-0:  change per step (signed)
  constant C_ADDR_ADC_EMUL_PERIOD     : integer := 16#08C#;  -- RW  bits 15-0:  one step every PERIOD clocks (0:  hold)
  -- ADC mux (adc_mux.vhd)
  constant C_ADDR_ADC_MUX_SELECT      : integer := 16#090#;  -- RW  bit 0:  0 the ADC pins, 1 the emulator
  -- ADC comparator (adc_cmp.vhd)
  constant C_ADDR_ADC_CMP_THRESH      : integer := 16#0A0#;  -- RW  bits 11-0:  threshold
  constant C_ADDR_ADC_CMP_SWING       : integer := 16#0A4#;  -- RW  bits 11-0:  hysteresis
  constant C_ADDR_ADC_CMP_LEVEL       : integer := 16#0A8#;  -- R   bit 0:  comparator level

  -- Registers with SCOPE=LA (logic analyzer, la_unit.vhd)
  constant C_ADDR_LA_PERIOD           : integer := 16#020#;  -- RW  sample every PERIOD clocks (0:  no samples)
  constant C_ADDR_LA_PHASE            : integer := 16#024#;  -- RW  BAUD locked:  first sample PHASE clocks after BAUD
  constant C_ADDR_LA_MODE             : integer := 16#028#;  -- RW  bit 0:  BAUD locked;  1:  acquisition enable (reset 1)
  constant C_ADDR_LA_TRIG             : integer := 16#02C#;  -- RW  bits 4-0 trigger sample bit, 9-8 edge (0 rise, 1 fall, 2 either),
                                                             --     10 cross trigger (the ADC unit's) enable
  constant C_ADDR_LA_POST             : integer := 16#030#;  -- RW  samples after the triggering one
  constant C_ADDR_LA_ARM              : integer := 16#040#;  -- W   start a capture
  constant C_ADDR_LA_FORCE            : integer := 16#044#;  -- W   trigger now
  constant C_ADDR_LA_START            : integer := 16#048#;  -- W   readout:  point at the oldest sample
  constant C_ADDR_LA_NEXT             : integer := 16#04C#;  -- W   readout:  next sample
  constant C_ADDR_LA_STATUS           : integer := 16#050#;  -- R   bit 0 armed, 1 triggered, 2 done
  constant C_ADDR_LA_TRIG_POS         : integer := 16#054#;  -- R   position of the triggering sample (0 = oldest)
  constant C_ADDR_LA_COUNT            : integer := 16#058#;  -- R   samples in the buffer
  constant C_ADDR_LA_DEPTH            : integer := 16#05C#;  -- R   buffer depth
  constant C_ADDR_LA_TS_LOWER         : integer := 16#060#;  -- R   timestamp of the triggering sample, bits 31-0
  constant C_ADDR_LA_TS_UPPER         : integer := 16#064#;  -- R   bits 63-32
  constant C_ADDR_LA_DATA             : integer := 16#070#;  -- R   the sample pointed at
  constant C_ADDR_LA_TILE_A           : integer := 16#080#;  -- RW  bits 3-0:  tile of lane A (0-9;  10-15:  zeros)
  constant C_ADDR_LA_TILE_B           : integer := 16#084#;  -- RW  tile of lane B
  constant C_ADDR_LA_TILE_C           : integer := 16#088#;  -- RW  tile of lane C
  constant C_ADDR_LA_TILE_D           : integer := 16#08C#;  -- RW  tile of lane D
  constant C_ADDR_LA_MUX_SELECT_A     : integer := 16#100#;  -- RW  bits 4-0:  the lane in sample bits 3-0
  constant C_ADDR_LA_MUX_SELECT_B     : integer := 16#104#;  -- RW  the lane in sample bits 7-4
  constant C_ADDR_LA_MUX_SELECT_C     : integer := 16#108#;  -- RW  bits 11-8
  constant C_ADDR_LA_MUX_SELECT_D     : integer := 16#10C#;  -- RW  bits 15-12
  constant C_ADDR_LA_MUX_SELECT_E     : integer := 16#110#;  -- RW  bits 19-16
  constant C_ADDR_LA_MUX_SELECT_F     : integer := 16#114#;  -- RW  bits 23-20
  constant C_ADDR_LA_MUX_SELECT_G     : integer := 16#118#;  -- RW  bits 27-24
  constant C_ADDR_LA_MUX_SELECT_H     : integer := 16#11C#;  -- RW  bits 31-28
  -- logic analyzer lanes (values of MUX_SELECT_A-H):  4 bits each
  constant C_LA_LANE_ZERO             : integer := 0;
  constant C_LA_LANE_TILE_A_PISO      : integer := 1;        -- PISO 0-3 of lane A's tile, PISO 0 in the lowest bit
  constant C_LA_LANE_TILE_A_POSI      : integer := 2;
  constant C_LA_LANE_TILE_B_PISO      : integer := 3;
  constant C_LA_LANE_TILE_B_POSI      : integer := 4;
  constant C_LA_LANE_TILE_C_PISO      : integer := 5;
  constant C_LA_LANE_TILE_C_POSI      : integer := 6;
  constant C_LA_LANE_TILE_D_PISO      : integer := 7;
  constant C_LA_LANE_TILE_D_POSI      : integer := 8;
  constant C_LA_LANE_TILE_AB_GH       : integer := 9;        -- G A, H A, G B, H B (lowest bit first)
  constant C_LA_LANE_TILE_CD_GH       : integer := 10;       -- G C, H C, G D, H D
  constant C_LA_LANE_ATC_STATUS_LOWER : integer := 11;       -- ATC status bits 3-0:  UCLK, BAUD, LEMO A, LEMO B
  constant C_LA_LANE_ATC_STATUS_UPPER : integer := 12;       -- ATC status bits 7-4:  markers M0-M3
  constant C_LA_LANE_RX_STATUS_LOWER  : integer := 13;
  constant C_LA_LANE_RX_STATUS_UPPER  : integer := 14;
  constant C_LA_LANE_TX_STATUS_LOWER  : integer := 15;
  constant C_LA_LANE_TX_STATUS_UPPER  : integer := 16;       -- 17-31:  zeros

end package register_map;
