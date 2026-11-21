from wave import bit, plot

V = "tx_delay_diagram_tb.vcd"
T = "tx_backpressure_diagram_tb."

# the frames of packets 1 and 2 on UART 1 with DELAY 5:  five bit periods between the stop bit and the next start bit
plot("tx_delay.pdf", V, [
    bit(T + "uut.posi_o[39:0]", "POSI(1)", bits=(1, 1)),
], 400, 8200, unit="us",
    points=[(7160, "POSI(1)", 1), (7760, "POSI(1)", 1)])
