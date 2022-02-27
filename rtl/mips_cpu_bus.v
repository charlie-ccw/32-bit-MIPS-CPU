module mips_cpu_bus(
    /* Standard signals */
    input logic clk,
    input logic reset,
    output logic active,
    output logic[31:0] register_v0,

    /* Avalon memory mapped bus controller (master) */
    output logic[31:0] address,
    output logic write,
    output logic read,
    input logic waitrequest,
    output logic[31:0] writedata,
    output logic[3:0] byteenable,
    input logic[31:0] readdata
);

    /* ------------------------------------------------------ Wires Declearation ------------------------------------------------------ */
    logic[31:0]  data_address;
    logic data_write;
    logic data_read;
    
    logic instr_read;   //instructino read_enable
    
    logic[31:0] instruction; //instruction given by memory 
    logic[5:0] opcode;

    logic[3:0] alu_control; //ALU
    logic[31:0] alu_op1;
    logic[31:0] alu_op2;
    logic[31:0] alu_result;

    logic reg_write_enable; //reg_file
    logic[31:0] reg_write_data;
    logic[4:0] rd;
    logic[4:0] rs;
    logic[4:0] rt;
    logic[31:0] rs_data;
    logic[31:0] rt_data;

    logic[31:0] pc_next; //pc to be confirmed
    logic[31:0] pc;

    logic[5:0] rtype_control; //R-type
    logic[31:0] HI; 
    logic[31:0] LO;
    logic[63:0] MULT_result;

    logic[31:0] branch_offset;  //Branch & J-Type
    logic[31:0] memory_offset; 
    logic[27:0] true_target;
    logic[5:0] branch_control;
    logic[1:0] JR_detector;
    logic[3:0] pc_upper;

    logic j_halt;

    logic[15:0] immediate; //I-type
    logic[31:0] extended_immediate; //I-Type

    logic[1:0] state;
    logic[1:0] next_state;
    logic[31:0] readdata_rev;

    /* ----------------------------------------------------- CPU Sub-modules --------------------------------------------------------- */
    reg_file R0(
        .clk(clk), 
        .reset(reset), 
        .register_v0(register_v0),
        .write_enable(reg_write_enable), 
        .reg_data_in_1(reg_write_data), 
        .write_address(rd),
        .read_address_1(rs),
        .read_address_2(rt),
        .reg_out_1(rs_data),
        .reg_out_2(rt_data)
    );

    alu ALU0(
        .alu_op1(alu_op1),
        .alu_op2(alu_op2),
        .control(alu_control),
        .result(alu_result)
    );

    assign read = (data_read || instr_read) && ~waitrequest;
    assign write = data_write && ~waitrequest;
    assign readdata_rev={{readdata[7:0]},{readdata[15:8]},{readdata[23:16]},{readdata[31:24]}};

    /* ----------------------------------------------------- Statemachine & CPU Clock & reset ------------------------------------------------------- */
    always @(posedge clk)begin
        if(reset)begin
            pc <= 32'hBFC00000;
            active <= 1;
            next_state <= 2'b00;
            j_halt=0;
        end
        else begin
            state = next_state;
            if(state==2'b10) begin
                if (pc_next != pc+4) begin
                    if (j_halt==1) begin
                        j_halt=0;
                        pc=pc_next;
                    end
                    else begin
                        j_halt=1;
                        pc=pc+4;
                    end
                end
                else begin
                    pc=pc_next;
                end
            end
            else if(state==2'b00) begin
                active = (pc != 32'h00000000);
            end
            case(waitrequest)
                1'b0:begin
                    next_state = (next_state==2'b10) ? 2'b00 : next_state+1;
                end
                1'b1:begin
                    next_state = next_state;
                end
            endcase
        end
    end

    /* -------------------------------------------------- CPU Combinatory Logic Part 1 ------------------------------------------------- */
    always @(*) begin
        /* ----------------------------------------------------- EXEC2 ------------------------------------------------------- */
        if ((state==2'b10) && (waitrequest==0)) begin 
            if(instruction[31:29]==3'b100)begin
                rd=instruction[20:16]; reg_write_enable=1;
                    case(opcode) 
                        6'b100011: reg_write_data=readdata_rev; //LW
                        6'b100000: begin    //LB
                            case(byteenable)
                                4'b1000: reg_write_data = {{24{readdata_rev[7]}}, {readdata_rev[7:0]}};
                                4'b0100: reg_write_data = {{24{readdata_rev[15]}},{readdata_rev[15:8]}};
                                4'b0010: reg_write_data = {{24{readdata_rev[23]}},{readdata_rev[23:16]}};
                                4'b0001: reg_write_data = {{24{readdata_rev[31]}},{readdata_rev[31:24]}};
                            endcase
                        end
                        6'b100100: begin    //LBU
                            case(byteenable)
                                4'b1000: reg_write_data = {24'b0,readdata_rev[7:0]};
                                4'b0100: reg_write_data = {24'b0,readdata_rev[15:8]};
                                4'b0010: reg_write_data = {24'b0,readdata_rev[23:16]};
                                4'b0001: reg_write_data = {24'b0,readdata_rev[31:24]};
                            endcase
                        end
                        6'b100001: begin    //LH
                            case(byteenable)
                                4'b1100: reg_write_data = {{16{readdata_rev[15]}},{readdata_rev[15:0]}};
                                4'b0011: reg_write_data = {{16{readdata_rev[31]}},{readdata_rev[31:16]}};
                            endcase
                        end
                        6'b100101: begin    //LHU
                            case(byteenable)
                                4'b1100: reg_write_data = {16'b0,readdata_rev[15:0]};
                                4'b0011: reg_write_data = {16'b0,readdata_rev[31:16]};
                            endcase
                        end
                        6'b100010: begin    //LWL
                            case(byteenable)
                                4'b1111: reg_write_data = readdata_rev;
                                4'b1110: reg_write_data = {readdata_rev[23:0], rt_data[7:0]};
                                4'b1100: reg_write_data = {readdata_rev[15:0], rt_data[15:0]};
                                4'b1000: reg_write_data = {readdata_rev[7:0], rt_data[23:0]};
                            endcase
                        end
                        6'b100110: begin    //LWR
                            case(byteenable)
                                4'b0001: reg_write_data = {rt_data[31:8], readdata_rev[31:24]};
                                4'b0011: reg_write_data = {rt_data[31:16], readdata_rev[31:16]};
                                4'b0111: reg_write_data = {rt_data[31:24], readdata_rev[31:8]};
                                4'b1111: reg_write_data = readdata_rev;
                            endcase  
                        end
                    endcase
            end
            data_write = 1'b0;
            data_read = 1'b0;
        end
        /* ---------------------------------------------------------- EXEC1 ------------------------------------------------------------ */
        else if (state==2'b01 && waitrequest==0) begin
            instr_read = 1'b0;
            instruction=readdata_rev;
            opcode=instruction[31:26];
            rs=instruction[25:21];
            rt=instruction[20:16];
            /* --------------------------------- R-Type & JR ----------------------------------- */
            if(opcode==000000) begin
                rtype_control=instruction[5:0];
                rd=instruction[15:11];
                JR_detector = (rtype_control==6'b001000) ? 2'b10 : (rtype_control==6'b001001) ? 2'b11 : 00; //JR/JALR detector
                pc_next = (j_halt==1) ? pc_next : (JR_detector==2'b00) ? pc+4 : pc_next;
                //                     ADDU         AND          OR           SLT          SLTU         SUBU        XOR 
                if((rtype_control==6'b100001) || (rtype_control==6'b100100) || (rtype_control==6'b100101) || (rtype_control==6'b101010) || (rtype_control==6'b101011) || (rtype_control==6'b100011) || (rtype_control==6'b100110)) begin
                    alu_op1=rs_data;
                    alu_op2=rt_data;
                    reg_write_enable=1;
                    reg_write_data=alu_result;
                    case(rtype_control)
                        6'b100001: alu_control = 4'b0000;  //ADDU
                        6'b100100: alu_control = 4'b0010;  //AND
                        6'b100101: alu_control = 4'b0011;  //OR
                        6'b101010: alu_control = 4'b1000;  //SLT
                        6'b101011: alu_control = 4'b1001;  //SLTU
                        6'b100011: alu_control = 4'b0001;  //SUBU
                        6'b100110: alu_control = 4'b0100;  //XOR
                    endcase
                end                      
                else if((rtype_control==6'b000100) || (rtype_control==6'b000111) || (rtype_control==6'b000110)) begin    //    SLLV         SRAV         SRLV
                    alu_op1 = rt_data;
                    alu_op2 = rs_data;
                    reg_write_enable = 1;
                    reg_write_data = alu_result;
                    case(rtype_control)
                        6'b000100: alu_control <= 4'b0101;  //SLLV
                        6'b000111: alu_control <= 4'b0111;  //SRAV
                        6'b000110: alu_control <= 4'b0110;  //SRLV
                    endcase
                end          
                else if((rtype_control==6'b000000) || (rtype_control==6'b000011) || (rtype_control==6'b000010)) begin    //     SLL          SRA           SRL
                    alu_op1 = rt_data;
                    alu_op2 = {27'b0,instruction[10:6]};
                    reg_write_enable = 1;
                    reg_write_data = alu_result;
                    case(rtype_control)
                        6'b000000: alu_control <= 4'b0101;  //SLL
                        6'b000011: alu_control <= 4'b0111;  //SRA
                        6'b000010: alu_control <= 4'b0110;  //SRL
                    endcase
                end
                else if(JR_detector==2'b10) begin //JR
                    pc_next=rs_data;
                end
                else if(JR_detector==2'b11) begin //JALR
                    rd=31; reg_write_enable=1; pc_next=rs_data; reg_write_data=pc+4;
                end
                else begin
                    case(rtype_control)
                        6'b011010: begin    //DIV
                            HI <= $signed(rs_data) % $signed(rt_data);
                            LO <= $signed(rs_data) / $signed(rt_data); 
                        end
                        6'b011011: begin    //DIVU
                            HI <= $unsigned(rs_data) % $unsigned(rt_data);
                            LO <= $unsigned(rs_data) / $unsigned(rt_data);
                        end
                        6'b011000: begin    //MULT
                            MULT_result = $signed(rs_data) * $signed(rt_data);
                            HI = MULT_result[63:32];
                            LO = MULT_result[31:0];
                        end
                        6'b011001: begin    //MULTU
                            MULT_result = $unsigned(rs_data) * $unsigned(rt_data);
                            HI = MULT_result[63:32];
                            LO = MULT_result[31:0];
                        end
                         6'b010000: begin
                            reg_write_enable=1;
                            reg_write_data=HI;
                        end
                        6'b010010: begin
                            reg_write_enable=1;
                            reg_write_data=LO;
                        end
                        6'b010001: HI = rs_data;
                        6'b010011: LO = rs_data;
                    endcase
                end
            end
            /* ----------------------------------- I-Type ------------------------------------- */
            else if (instruction[31:29]==3'b001) begin
                pc_next = (j_halt==1) ? pc_next : pc+4;
                immediate = instruction[15:0]; rd=rt; rt=0; alu_op1=rs_data; reg_write_enable=1; 
                if ((opcode==6'b001100) || (opcode==6'b001101) || (opcode==6'b001110)) begin //ANDI, ORI, XORI
                    extended_immediate={16'h0000, immediate};
                end
                else begin
                    extended_immediate={{16{instruction[15]}}, immediate};
                end
                alu_op2=extended_immediate;
                case(opcode)
                    6'b001001 : alu_control <= 4'b0000; //ADDIU
                    6'b001100 : alu_control <= 4'b0010; //ANDI
                    6'b001101 : alu_control <= 4'b0011; //ORI
                    6'b001110 : alu_control <= 4'b0100; //XORI
                    6'b001010 : alu_control <= 4'b1000; //SLTI
                    6'b001011 : alu_control <= 4'b1001; //SLTIU
                    6'b001111 : reg_write_data = {16'h0000, immediate} << 16; //LUI
                endcase
                reg_write_data = (opcode==6'b001111) ? reg_write_data : alu_result;
            end
            /* --------------------------- Conditional Branch & Memory Access ---------------------------- */
            else begin
                branch_control=instruction[20:16]; branch_offset={{14{instruction[15]}}, instruction[15:0], 2'b00}; 
                memory_offset={{16{instruction[15]}}, instruction[15:0]};
                true_target={instruction[25:0], 2'b00}; pc_upper=pc[31:28];
            /* --------------------------------- Memory Access ---------------------------------- */
                if (instruction[31:29]==3'b100) begin //load    LB LBU LH LHU LWL LWR
                    data_read=1; data_address=$signed(rs_data)+$signed(memory_offset); pc_next = (j_halt==1) ? pc_next : pc+4;
                    case(opcode)
                        6'b100000: begin  //LB
                            address = (data_address/4)*4;
                            case(data_address % 4)
                                0:byteenable = 4'b0001;
                                1:byteenable = 4'b0010;
                                2:byteenable = 4'b0100;
                                3:byteenable = 4'b1000;
                            endcase
                        end
                        6'b100100: begin    //LBU
                            address = (data_address/4)*4;
                            case(data_address % 4)
                                0:byteenable = 4'b0001;
                                1:byteenable = 4'b0010;
                                2:byteenable = 4'b0100;
                                3:byteenable = 4'b1000;
                            endcase
                        end
                        6'b100001: begin     //LH
                            address = (data_address/4)*4;
                            case(data_address % 4)
                                0:byteenable = 4'b0011;
                                2:byteenable = 4'b1100;
                            endcase
                        end
                        6'b100101:begin     //LHU
                            address = (data_address/4)*4;
                            case(data_address % 4)
                                0:byteenable = 4'b0011;
                                2:byteenable = 4'b1100;
                            endcase
                        end
                        6'b100011: begin                //LW
                            address = data_address; 
                            byteenable = 4'b1111;
                        end
                        6'b100010: begin                //LWL
                            address = (data_address/4)*4;
                            case(data_address % 4)
                                0:byteenable = 4'b1111;
                                1:byteenable = 4'b1110;
                                2:byteenable = 4'b1100;
                                3:byteenable = 4'b1000;
                            endcase
                        end
                        6'b100110: begin                 //LWR
                            address = (data_address/4)*4;;
                            case(data_address % 4)
                                0:byteenable = 4'b0001;
                                1:byteenable = 4'b0011;
                                2:byteenable = 4'b0111;
                                3:byteenable = 4'b1111;
                            endcase
                        end
                    endcase
                end
                else if (instruction[31:29]==3'b101) begin //store  SB SH SW
                    data_write = 1'b1; data_address=$signed(rs_data)+$signed(memory_offset);
                    case(opcode)
                        6'b101000:begin                 //SB
                            address = (data_address/4)*4;
                            case(data_address % 4)
                                0:begin
                                    byteenable = 4'b0001;
                                    writedata = {rt_data[7:0],24'bx};
                                end
                                1:begin
                                    byteenable = 4'b0010;
                                    writedata = {8'bx,rt_data[7:0],16'bx};
                                end
                                2:begin
                                    byteenable = 4'b0100;
                                    writedata = {16'bx,rt_data[7:0],8'bx};
                                end
                                3:begin
                                    byteenable = 4'b1000;
                                    writedata = {24'bx,rt_data[7:0]};
                                end
                            endcase
                        end
                        6'b101001:begin                 //SH
                            address = (data_address/4)*4;
                            case(data_address % 4)
                                0:begin
                                    byteenable = 4'b0011;
                                    writedata = {rt_data[15:0],16'bx};
                                end
                                2:begin
                                    byteenable = 4'b1100;
                                    writedata = {16'bx,rt_data[15:0]};
                                end
                            endcase
                        end
                        6'b101011:begin                 //SW
                            address = data_address;
                            byteenable = 4'b1111;
                            writedata = rt_data;
                        end
                    endcase
                end
                else if (j_halt==0) begin 
            /* --------------------------- Conditional Branch & Jump ----------------------------- */
                    reg_write_enable=0;
                    case(opcode)
                        6'b000100: pc_next = (rs_data==rt_data) ? $signed(pc)+$signed(branch_offset) : pc+4; //BEQ
                        6'b000101: pc_next = (rs_data==rt_data) ? pc+4 : $signed(pc)+$signed(branch_offset); //BNE
                        6'b000001: begin
                            if ($signed(rs_data)<0) begin
                                case(branch_control)
                                    5'b00000: pc_next=$signed(pc)+$signed(branch_offset); //BLTZ
                                    5'b10000: begin
                                        rd=31; reg_write_enable=1; pc_next=$signed(pc)+$signed(branch_offset); reg_write_data=pc+4; //BLTZAL
                                    end
                                    default: pc_next=pc+4;         
                                endcase               
                            end
                            else begin
                                case(branch_control)
                                    5'b00001: pc_next=$signed(pc)+$signed(branch_offset); //BGEZ
                                    5'b10001: begin
                                        rd=31; reg_write_enable=1; pc_next=$signed(pc)+$signed(branch_offset); reg_write_data=pc+4;  //BGEZAL
                                    end
                                    default: pc_next=pc+4;
                                endcase
                            end
                        end
                        6'b000111: pc_next = ($signed(rs_data)>0) ? $signed(pc)+$signed(branch_offset) : pc+4;//BGTZ  //>0
                        6'b000110: pc_next = ($signed(rs_data)>0) ? pc+4 : $signed(pc)+$signed(branch_offset);//BLEZ
                        6'b000010: pc_next = {pc_upper,true_target}; //J
                        6'b000011: begin
                            rd=31; reg_write_enable=1; pc_next={pc_upper, true_target}; reg_write_data=pc+4; //JAL //change
                        end
                    endcase
                end
            end
        end
        /* ----------------------------------------------------- FETCH ------------------------------------------------------- */
        else if(state == 2'b00 && waitrequest==0) begin
            byteenable = 4'hf;
            address = pc;
            instr_read = 1'b1;
        end
    end
endmodule