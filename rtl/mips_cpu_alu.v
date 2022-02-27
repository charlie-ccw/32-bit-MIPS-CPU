module alu(
    input logic[31:0] alu_op1, //rs
    input logic[31:0] alu_op2, //rt or immediate
    input logic[3:0] control,
    output logic[31:0] result
);

    always @(*) begin
        case (control)
            4'b0000: result <= $unsigned (alu_op1) + $unsigned (alu_op2); //0:ADDU
            4'b0001: result <= $unsigned (alu_op1) - $unsigned (alu_op2); //1:SUBU
            4'b0010: result <= alu_op1 & alu_op2; //2:AND 
            4'b0011: result <= alu_op1 | alu_op2; //3:OR
            4'b0100: result <= alu_op1 ^ alu_op2; //4:XOR
            4'b0101: result <= alu_op1 << alu_op2; //5:Shift left logic
            4'b0110: result <= alu_op1 >> alu_op2; //6:shift right logic
            4'b0111: result <= $signed (alu_op1) >>> alu_op2; //7:shift right arithmetic
            4'b1000: result <= $signed (alu_op1) < $signed (alu_op2) ? 1 : 0 ; //8:STL
            4'b1001: result <= (alu_op1 < alu_op2) ? 1 : 0 ; //9:STLU
            4'b1010: result <= (alu_op1 == alu_op2) ? 1 : 0 ; //*Branch on equal 0
            4'b1100: result <= (alu_op1 > 0) ? 1 : 0; //*Branch on greater than 0
            4'b1101: result <= (alu_op1 < 0) ? 1 : 0; //*Branch on less than 0
            //for STL and Branch case, the output is still 32bits, but only 1 or 0
            //default: result <= alu_op1;
        endcase
    end

endmodule