clone the git repository, for modelsim, add all the .s or .sv file.

current stage: pass all.
for each test, need to update both analog.data and follower_tb.v.

file:
  (our work)
  	A2D_intf.sv         /* Instantiate SPI master */
	SPI_mstr.sv         /* MOSI, MISO */
	UART_rcv.v
	UART_tx.v
	alu.sv
	barcode.sv          /* INPUT BC, OUTPUT ID, ID_vld*/
	cmd_contrl.sv       /* INPUT cmd, OK2Move, ID, OUTPUT buzz, in_transit, go */
	motion_cntrl.sv     /* INPUT go, cnv_cmplt, A2D_res, OUTPUT strt_cnv, chnnl, IR_in_en, IR_mid_en, IR_out_en, LEDs, lft, rht */
	motor_cntrl.sv      /* INPUT lft, rht, OUTPUT fwd_lft, rev_lft, fwd_rht, rev_rht */
	pwm.sv              /* 8 bit width PWM used in motion_cntrl */ 
	pwm_10.sv           /* 10 bit width PWM used in motor_cntrl */ 

  
  	A2D_test.sv         /* maynot need in final project, for ex10 demo, demo 2 not pass */
  
  (professor provide)
  	dig_core.sv         /* Instantiate cmd_contrl and motion_cntrl */
	follower.v          /* Instantiate dig_core, uart_rcv, motor_cntrl, barcode, A2D_intf */
  	reset_synch.v
  	ADC128S.sv          /* Instantiate SPI_ADC128S, used with analog.dat, may not need in Quartux */
  	SPI_ADC128S.sv      /* Slave */
  	analog.dat          /* analog.dat to simulate data input, may not need in Quartux*/
  	barcode_mimic.sv
	buzz_cntr.v
	check_math.pl
  	Follower.qpf        /* Quartux files for FPGA board */
	Follower.qsf
	
 
 directory:
	Tests/              /* test cases provided by professor */ 
  	tb/                 /* some of our own testbenches */ 


Note:

ex09———————————
a tiny problem with the UART_test.v, which triggers the transmit 1 clk cycle before the counter increments by 1, so when programmed to FPGA, the first time you push KEY 1 (next_byte active low), it transmits the data 8'h00 and then increments the counter to 8'h01, then the next time you push the button, the counter and data is transmitted correctly.
haven't made editing and testing to fix the problem.

ex10——————————
demo 2 not succeed

ex08——————————
some combine of blocking and non-blocking assignment.

Clear Up Step:
change all decimal to formated to reduce design area (e.g. 4 -> 4'h4)
