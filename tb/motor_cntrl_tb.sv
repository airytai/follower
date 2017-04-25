module motor_cntrl_tb();

    // input and output signals
    logic [10:0] lft, rht;
    logic fwd_lft, rev_lft, fwd_rht, rev_rht;
    logic rst_n, clk;

    // initialize monitor
    initial $monitor("time: %t, lft: %d, rht: %d, fwd_lft: %d, rev_lft: %d, fwd_rht: %d, rev_rht: %d", $time, lft, rht, fwd_lft, rev_lft, fwd_rht, rev_rht);

    // initialize clk
    always #10 clk = ~clk;

    // instantiate iDUT
    motor_cntrl iDUT(.lft(lft), .rht(rht), .fwd_lft(fwd_lft), .rev_lft(rev_lft), .fwd_rht(fwd_rht), .rev_rht(rev_rht), .rst_n(rst_n), .clk(clk));

    // intial test
    initial begin
        rst_n = 1'b0;
        clk = 1'b0;
        
        // start the test string
        repeat(1'b1)@(posedge clk);// asserted for half clk
        rst_n = 1;
        // lft foward, right foward, set every lft and rht clk cycle
        lft = 11'b010_0000_0000;
        rht = 11'b001_0000_0000;
        repeat(12'h200)@(posedge clk); // 0010_0000_0000, count to left duty cycle
        repeat(12'h200)@(posedge clk); // 0100_0000_0000, PWM cnt count 11_1111_1111, set both PWM_sig_lft and PWM_sig_rht
        repeat(12'h300)@(posedge clk); // 0111_0000_0000, pass PWM_rht duty cycle, and reach PWM_lft duty cycle, reset both to 0
        // lft foward, right reverse, set every lft and rht clk cycle
        lft = 11'b000_0100_0000;
        rht = 11'b100_1000_0000;
        repeat(12'h200)@(posedge clk); // 0010_0000_0000, pass both duty cycle but not reach 11_1111_1111 (PWM cnt set), both stay 0
        repeat(12'h200)@(posedge clk); // 0100_0000_0000, PWM cnt count 11_1111_1111, set both PWM_sig_lft and PWM_sig_rht
        repeat(12'h200)@(posedge clk); // 0110_0000_0000, pass both duty cycle, reset both to 0
        // lft reverse, right reverse, set every lft and rht clk cycle
        lft = 11'b100_0010_0000;
        rht = 11'b100_0001_0000;
        repeat(12'h200)@(posedge clk); // 0010_0000_0000, pass both duty but not reach 11_1111_1111, both 0
        repeat(12'h200)@(posedge clk); // 0100_0000_0000, set both 1
        repeat(12'h200)@(posedge clk); // 0110_0000_0000, set both 0
        // lft reverse, right forwad, set every lft and rht clk cycle
        lft = 11'b100_0000_0100;
        rht = 11'b000_0000_1000;
        repeat(12'h200)@(posedge clk); // 0010_0000_0000, set both 0
        repeat(12'h200)@(posedge clk); // 0100_0000_0000, set both 1
        repeat(12'h200)@(posedge clk); // 0110_0000_0000, set both 0
        // brake left
        lft = 11'b000_0000_0000;
        rht = 11'b000_1011_0010; // high for twice
        repeat(12'h200)@(posedge clk); // 0010_0000_0000, set right 0, set left 1
        repeat(12'h200)@(posedge clk); // 0100_0000_0000, set right 1, set left 1
        repeat(12'h200)@(posedge clk); // 0110_0000_0000, set right 0, set left 1
        // brake right
        lft = 11'b001_0001_0100; // high once
        rht = 11'b000_0000_0000;
        repeat(12'h200)@(posedge clk); // 0010_0000_0000, set left 0, set right 1
        repeat(12'h200)@(posedge clk); // 0100_0000_0000, set left 1, set right 1
        repeat(12'h200)@(posedge clk); // 0110_0000_0000, set left 0, set right 1
        // brake both
        lft = 11'b000_0000_0000;
        rht = 11'b000_0000_0000;
        repeat(12'h200)@(posedge clk); // 0010_0000_0000, set both 1 (brake)
        repeat(12'h200)@(posedge clk); // 0100_0000_0000, set both 1 (brake)
        repeat(12'h200)@(posedge clk); // 0110_0000_0000, set both 1 (brake)
        $stop;
        
    end
endmodule