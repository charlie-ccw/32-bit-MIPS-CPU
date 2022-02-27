module ram_mapped(
    input logic clk,
    input logic[31:0] address,
    input logic write,
    input logic read,
    input logic[31:0] writedata,
    //input logic activate_waitrequest,
    input logic[3:0] byteenable,
    output logic[31:0] readdata,
    //output logic waitrequest
    input logic waitrequest
);
    parameter RAM_INIT_FILE = "";

    logic[8:0] mapped_address;
    reg [7:0] memory [0:511];

    always @(*) begin
        case(address[31:20])
            12'h000   : mapped_address = address[8:0];
            12'hBFC   : mapped_address = address[8:0] + 9'h100;	//Lowest 12 bits + 0x90 (144)
            //12'hFFF   : mapped_address =  address[7:0] + 8'haa;	////Lowest 12 bits + 0xaa (170)
        endcase
    end

    initial begin
        integer i;
        /* Initialise to zero by default */
        for (i=0; i<511; i++) begin
            memory[i]=0;
        end
        if (RAM_INIT_FILE != "") begin
            /* Load contents from file if specified */
            $display("RAM : INIT : Loading RAM contents from %s", RAM_INIT_FILE);
            $readmemh(RAM_INIT_FILE, memory);
        end
        //addiu $2, $2, 10  2442000a outcome $2 = 0x0000000a
        //big-endian
        // memory[0000]=8'h0a;
        // memory[0001]=8'h00;
        // memory[0002]=8'h42;
        // memory[0003]=8'h24;
    end


    //assign waitrequest = activate_waitrequest;
    
    /* Read path */
    always@(posedge clk) begin
		if(read && ~waitrequest ) begin
            //$display("RAM : INIT : Loading RAM contents from %s", RAM_INIT_FILE);
			//readdata <=  {memory[mapped_address],memory[mapped_address+1],memory[mapped_address+2],memory[mapped_address+3]};
            readdata[7:0] <= byteenable[0]? memory[mapped_address] : 8'hxx;
            readdata[15:8] <= byteenable[1]? memory[mapped_address+1] : 8'hxx;
            readdata[23:16] <= byteenable[2]? memory[mapped_address+2] : 8'hxx;
            readdata[31:24] <= byteenable[3]? memory[mapped_address+3] : 8'hxx;
            $display("TB : INFO : RAM_ACCESS: Read from 0x%h, data: 0x%h",address, {memory[mapped_address],memory[mapped_address+1],memory[mapped_address+2],memory[mapped_address+3]});
        end
    end

    /* Write path */
    always @(posedge clk) begin
        if (write && ~waitrequest) begin
            if(byteenable[3])begin
                memory[mapped_address+3] <= writedata[7:0];
            end
            if(byteenable[2])begin
                memory[mapped_address+2] <= writedata[15:8];
            end
            if(byteenable[1])begin
                memory[mapped_address+1] <= writedata[23:16];
            end
            if(byteenable[0])begin
                memory[mapped_address] <= writedata[31:24];
            end
            $display("TB : INFO : RAM_ACCESS: Store to 0x%h, data: 0x%h",address, {memory[mapped_address],memory[mapped_address+1],memory[mapped_address+2],memory[mapped_address+3]});
        end
    end

endmodule