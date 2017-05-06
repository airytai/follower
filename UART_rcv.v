module uart_rcv(clk, rst_n, RX, rx_rdy, rx_data, clr_rx_rdy);

    input clk, rst_n;
    input RX;
    output rx_rdy;
    output [7:0] rx_data;
    input clr_rx_rdy; // assert to deassert rx_rdy
    
    reg state, nxt_state; // tune in two states
    reg [9:0] shift_reg; // 10-bit shifter
    reg [3:0] bit_cnt; // 4-bit bit counter
    reg [11:0] baud_cnt; // baud rate counter

    reg half_baud; // count for half baud time

    //reg shift_out;

    reg strt_rcv, receiving; // assigned in state machine
    reg rcv_done;

    wire shift;

    localparam IDLE = 1'b0;
    localparam TX = 1'b1;

    // Infer state flop next
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;

    // Infer bit_cnt
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            bit_cnt <= 4'b0000;
        else if (strt_rcv)
            bit_cnt <= 4'b0000;
        else if (shift)
            bit_cnt <= bit_cnt+1'b1;

    // Infer shift register
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            shift_reg <= 10'h3FF;		// reset to idle state being transmitted
        else if (strt_rcv)
             shift_reg <= 10'h3FF;      // function as reset
        else if (shift) begin
            shift_reg <= {RX, shift_reg[9:1]};
            //shift_out <= shift_reg[0];
        end

    // Infer baud_cnt
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            baud_cnt <= 12'h5D3;		// (4095 - 2604) = 0x5D3
            half_baud <= 1'b0;
        end
        else if (strt_rcv || shift) begin
            baud_cnt <= 12'h5D3;		// reset when baud count indicates 19200 baud
            half_baud <= 1'b0;
        end
        else if (receiving) begin
            baud_cnt <= baud_cnt+1'b1;		// only burn power incrementing if tranmitting
            half_baud <= 1'b0;
            if(baud_cnt == 12'hAE9 && bit_cnt == 0)            // (4095 - 1302) = AE9
                half_baud <= 1'b1;
        end
        
    // state machine
    always @(state, strt_rcv, shift, bit_cnt, RX)
        begin
            //////////////////////////////////////
            // Default assign all output of SM //
            ////////////////////////////////////
            strt_rcv  = 0;
            receiving = 0;
            nxt_state = IDLE;	// always a good idea to default to IDLE state
            rcv_done = 1'b0;
            
            case (state)
            IDLE : begin
                if (!RX) // receive the first 0 bit of RX
                    begin
                        nxt_state = TX;
                        strt_rcv = 1;
                    end
                else nxt_state = IDLE;
            end
            default : begin		// this is TX state
                receiving = 1;
		if (bit_cnt==4'b1010) begin
                    rcv_done = 1'b1;
                    nxt_state = IDLE;
                end else
                    nxt_state = TX;
                
            end
            endcase
        end

    assign shift = ((bit_cnt == 4'b1010)  ?  1'b0 : (  (&baud_cnt) ? 1'b1 : ((half_baud)? 1'b1 : 1'b0)  )    );
    assign rx_data = shift_reg[8:1];
    assign rx_rdy = (clr_rx_rdy || strt_rcv) ? 1'b0 : ((rcv_done) ? 1'b1 : 1'b0);
endmodule