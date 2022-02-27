module reg_file(
    input  logic clk,
    input  logic reset,
    input  logic write_enable,
    input logic [31:0] reg_data_in_1,
    input logic [4:0] write_address,
    input logic [4:0] read_address_1,
    input logic [4:0] read_address_2,
    output logic [31:0] reg_out_1,
    output logic [31:0] reg_out_2,
    output logic [31:0] register_v0
);
    logic [31:0] regs [31:0];  //define 32 32 bits registers

    assign register_v0=regs[2];

    //reset & write
    always @(posedge clk or posedge reset) begin
        integer k; // loop variable
        if (reset) begin
            for (k=0; k<=31; k=k+1) begin
                regs[k] <= 0;
            end
        end
        else if ((write_enable == 1) && (write_address > 0) ) begin
            regs[write_address]=reg_data_in_1;
        end
    end

    //read value
    always_comb begin
        if (!reset) begin
            reg_out_1=regs[read_address_1];
            reg_out_2=regs[read_address_2];
        end
        else begin
            reg_out_1=0;
            reg_out_2=0;
        end
    end

endmodule