module bus_cpu_tb();
    logic clk;
    logic reset;
    logic active;
    logic[31:0] register_v0;
    logic[31:0] address;
    logic write;
    logic read;
    logic waitrequest;
    logic[31:0] writedata;
    logic[3:0] byteenable;
    logic[31:0] readdata;

    parameter TIME_OUT_CYCLE=10000;

    //logic activate_waitrequest;

    //parameter RAM_INIT_FILE = "test/1-binary/2-i-type.txt";

    parameter RAM_INIT_FILE = "";

    //RAM_16x4096_delay0 #(RAM_INIT_FILE) ramInst(clk, address, write, read, writedata, readdata);

    ram_mapped #(RAM_INIT_FILE) r0(clk, address, write, read, writedata, byteenable, readdata, waitrequest);
    
    mips_cpu_bus h0(.clk(clk), .reset(reset), .active(active), .register_v0(register_v0), .address(address),
        .write(write), .read(read), .waitrequest(waitrequest), .writedata(writedata), 
        .byteenable(byteenable), .readdata(readdata));

    initial begin
        clk = 1'b0;
        while(TIME_OUT_CYCLE)begin
            #10;
            clk = !clk;
        end
    end

    initial begin
        @(posedge clk); //initialize
        waitrequest = 0;
        reset=1;

        @(posedge clk); //fetch -1
        reset=0;

        while (active) begin
            @(posedge clk);
        end

        $display("register_v0_final ","%h",register_v0);

        $finish;

    end

endmodule