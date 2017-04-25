ex09———————————
a tiny problem with the UART_test.v, which triggers the transmit 1 clk cycle before the counter increments by 1, so when programmed to FPGA, the first time you push KEY 1 (next_byte active low), it transmits the data 8'h00 and then increments the counter to 8'h01, then the next time you push the button, the counter and data is transmitted correctly.
haven't made editing and testing to fix the problem.

ex10——————————
demo 2 not succeed

