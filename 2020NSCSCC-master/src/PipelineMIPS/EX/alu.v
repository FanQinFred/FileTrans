`include "aludefines.vh"

module alu (
    input wire clk, rst,
    input wire flushE,
    input wire flush_exceptionM,
    input wire flush_branch_likely_M,
    input wire stallM,
    input wire [31:0] src_aE, src_bE,
    input wire [5:0] alu_controlE,
    input wire [4:0] sa,
    input wire [63:0] hilo,
    input wire stallD,
    input wire is_divD,
    input wire is_multD,
    input wire LLbit,

    output wire div_stallE,
    output wire mult_stallE,
    output wire [63:0] alu_outE,
    output wire overflowE,
    output wire [31:0] adder_result,
    output wire trap_resultE
);
    wire [63:0] alu_out_div, alu_out_mult;
    wire mult_sign;
    wire mult_valid;
    wire div_sign;
	wire div_valid;
    wire [31:0] alu_out_not_mul_div; //拓展成33位，便于判断溢出

    wire [63:0] alu_out_signed_mult, alu_out_unsigned_mult;
    wire signed_mult_ce, unsigned_mult_ce;

    wire alu_mthi, alu_mtlo;

    wire alu_and        ;      
    wire alu_or         ;      
    wire alu_nor        ;      
    wire alu_xor        ;      
    wire alu_add        ;      
    wire alu_addu       ;      
    wire alu_sub        ;      
    wire alu_subu       ;     
    wire alu_slt        ;      
    wire alu_sltu       ;

    wire alu_sll        ;      
    wire alu_sll_sa     ;      
    wire alu_sr         ;      
    wire alu_sr_sa      ;

    wire alu_lui        ;      
    wire alu_donothing  ;

    wire alu_clo, alu_clz;
    wire alu_madd, alu_maddu, alu_msub, alu_msubu, alu_madd_msub;
    wire alu_sc;
    wire alu_teq, alu_tne, alu_tge, alu_tgeu, alu_tlt, alu_tltu;

    wire [31:0] and_result          ;
    wire [31:0] or_result           ;
    wire [31:0] nor_result          ;
    wire [31:0] xor_result          ;

    wire [31:0] add_sub_result      ;
    wire [31:0] addu_result         ;
    wire [31:0] sub_result          ;
    wire [31:0] subu_result         ;

    wire [31:0] slt_result          ;
    wire [31:0] sltu_result         ;
    
    wire [31:0] sll_result          ;
    wire [31:0] sll_sa_result       ;
    wire [31:0] sr_result           ;
    wire [31:0] sr_sa_result        ;

    wire [31:0] lui_result          ;
    wire [31:0] donothing_result    ;

    wire [31:0] clzo_result         ;
    wire [31:0] sc_result           ;

    wire [63:0] madd_result         ; //madd, maddu
    wire [63:0] msub_result         ; //msub, msubu
    wire [63:0] madd_sub_result     ;

    assign alu_and       = !(alu_controlE ^ `ALU_AND      );
    assign alu_or        = !(alu_controlE ^ `ALU_OR       );
    assign alu_nor       = !(alu_controlE ^ `ALU_NOR      );
    assign alu_xor       = !(alu_controlE ^ `ALU_XOR      );
    assign alu_add       = !(alu_controlE ^ `ALU_ADD      );
    assign alu_addu      = !(alu_controlE ^ `ALU_ADDU     );
    assign alu_sub       = !(alu_controlE ^ `ALU_SUB      );
    assign alu_subu      = !(alu_controlE ^ `ALU_SUBU     );
    assign alu_slt       = !(alu_controlE ^ `ALU_SLT      );
    assign alu_sltu      = !(alu_controlE ^ `ALU_SLTU     );

    assign alu_sll       = !(alu_controlE ^ `ALU_SLL      );
    assign alu_sll_sa    = !(alu_controlE ^ `ALU_SLL_SA   );
    assign alu_srl       = !(alu_controlE ^ `ALU_SRL      );
    assign alu_sra       = !(alu_controlE ^ `ALU_SRA      );
    assign alu_srl_sa    = !(alu_controlE ^ `ALU_SRL_SA   );
    assign alu_sra_sa    = !(alu_controlE ^ `ALU_SRA_SA   );

    assign alu_lui       = !(alu_controlE ^ `ALU_LUI      );
    assign alu_donothing = !(alu_controlE ^ `ALU_DONOTHING);

    assign alu_clo       = !(alu_controlE ^ `ALU_CLO);
    assign alu_clz       = !(alu_controlE ^ `ALU_CLZ);
    assign alu_madd      = !(alu_controlE ^ `ALU_MADD_MULT);
    assign alu_maddu     = !(alu_controlE ^ `ALU_MADDU_MULT);
    assign alu_msub      = !(alu_controlE ^ `ALU_MSUB_MULT);
    assign alu_msubu     = !(alu_controlE ^ `ALU_MSUBU_MULT);
    assign alu_madd_msub = alu_madd | alu_maddu | alu_msub | alu_msubu;

    assign alu_mthi = !(alu_controlE ^ `ALU_MTHI);
    assign alu_mtlo = !(alu_controlE ^ `ALU_MTLO);

    assign alu_sc = !(alu_controlE ^ `ALU_SC);

    assign alu_teq       = !(alu_controlE ^ `ALU_TEQ);
    assign alu_tne       = !(alu_controlE ^ `ALU_TNE);
    assign alu_tge       = !(alu_controlE ^ `ALU_TGE);
    assign alu_tgeu      = !(alu_controlE ^ `ALU_TGEU);
    assign alu_tlt       = !(alu_controlE ^ `ALU_TLT);
    assign alu_tltu      = !(alu_controlE ^ `ALU_TLTU);

    assign and_result    = src_aE & src_bE;
    assign or_result     = src_aE | src_bE;
    assign nor_result    = ~or_result;
    assign xor_result    = src_aE ^ src_bE;
    assign lui_result    = {src_bE[15:0],  16'd0};


    wire [31:0] adder_a;
    wire [31:0] adder_b;
    wire        adder_cin;
    wire        adder_cout;
    wire [63:0] sr64_sa_result, sr64_result;

    // 这个是个蛇皮，这个补码是32位的补码，而非33位的补码；所以sltu_result[0] = ~adder_cout;
    // b + [b] = 1; 若a<b, 则 a + [b] < 1; 所以adder_cout = 0;
    // 溢出： 有符号相同符号相加可能会产生溢出，分为正溢出（{adder_cout, result[31]}: 01）与负溢出（{adder_cout, result[31]}:10）；
    // 建议通过有符号拓展理解；

    wire alu_trap_minus;        // 内陷指令处理：
    assign alu_trap_minus = alu_teq | alu_tne | alu_tge | alu_tgeu | alu_tlt | alu_tltu;
    
    assign adder_a = src_aE;
    assign adder_b = src_bE ^ {32{alu_sub | alu_subu | alu_slt | alu_sltu | alu_trap_minus}};
    assign adder_cin = alu_sub | alu_subu | alu_slt | alu_sltu | alu_trap_minus;
    assign {adder_cout,adder_result} =adder_a + adder_b + adder_cin;
    assign add_sub_result = adder_result;

    assign slt_result[31:1] = 31'd0;
    assign slt_result[0] = (src_aE[31] & ~src_bE[31]) |
                        (~(src_aE[31]^src_bE[31]) & adder_result[31]);
    //assign slt_result[0] = src_aE < src_bE ;

    assign sltu_result[31:1] = 31'd0;
    assign sltu_result[0] = ~adder_cout;
    //assign sltu_result = {1'b0,src_aE} < {1'b0,src_bE};

    assign sll_result  = src_bE << src_aE[4:0];                                     // sll
    assign sll_sa_result = src_bE << sa;                                            // sll_sa
    
    assign sr64_result = {{32{alu_sra & src_bE[31]}},src_bE[31:0]} >> src_aE[4:0]; // sra srl
    assign sr_result   = sr64_result[31:0];                                      
    assign sr64_sa_result = {{32{alu_sra_sa & src_bE[31]}},src_bE[31:0]} >> sa;       // sra_sa srl_sa
    assign sr_sa_result = sr64_sa_result[31:0];

    assign donothing_result = src_aE;

    wire [31:0] clzo_a; //clz or clo
    assign clzo_a = alu_clz ? src_aE : ~src_aE;
    assign clzo_result = 
                clzo_a[31] ?  0 : clzo_a[30] ?  1 : clzo_a[29] ?  2 : 
                clzo_a[28] ?  3 : clzo_a[27] ?  4 : clzo_a[26] ?  5 : 
                clzo_a[25] ?  6 : clzo_a[24] ?  7 : clzo_a[23] ?  8 : 
                clzo_a[22] ?  9 : clzo_a[21] ? 10 : clzo_a[20] ? 11 : 
                clzo_a[19] ? 12 : clzo_a[18] ? 13 : clzo_a[17] ? 14 : 
                clzo_a[16] ? 15 : clzo_a[15] ? 16 : clzo_a[14] ? 17 : 
                clzo_a[13] ? 18 : clzo_a[12] ? 19 : clzo_a[11] ? 20 : 
                clzo_a[10] ? 21 : clzo_a[ 9] ? 22 : clzo_a[ 8] ? 23 : 
                clzo_a[ 7] ? 24 : clzo_a[ 6] ? 25 : clzo_a[ 5] ? 26 : 
                clzo_a[ 4] ? 27 : clzo_a[ 3] ? 28 : clzo_a[ 2] ? 29 : 
                clzo_a[ 1] ? 30 : clzo_a[ 0] ? 31 : 32;
    
    assign sc_result = {31'b0, LLbit};
    assign madd_result = hilo + alu_out_mult;
    assign msub_result = hilo - alu_out_mult;
    assign madd_sub_result = alu_madd | alu_maddu ? madd_result : msub_result;

    assign alu_out_not_mul_div = 
                        ({32{alu_and        }} & and_result)            
                    |   ({32{alu_nor        }} & nor_result)            
                    |   ({32{alu_or         }} & or_result)             
                    |   ({32{alu_xor        }} & xor_result)  

                    |   ({32{alu_add | alu_addu | alu_sub | alu_subu}} & add_sub_result) 
                    
                    |   ({32{alu_slt        }} & slt_result)            
                    |   ({32{alu_sltu       }} & sltu_result)           
                    
                    |   ({32{alu_sll        }} & sll_result     )       
                    |   ({32{alu_sll_sa     }} & sll_sa_result  )       
                    |   ({32{alu_sra    | alu_srl    }} & sr_result      )
                    |   ({32{alu_sra_sa | alu_srl_sa }} & sr_sa_result   )
                    
                    |   ({32{alu_lui        }} & lui_result)            
                    
                    |   ({32{alu_clo | alu_clz}} & clzo_result)         
                    |   ({32{alu_sc         }} & sc_result)                      
                    
                    |   ({32{alu_donothing}} & donothing_result);

    assign trap_resultE =   alu_teq  & !(adder_result ^ 0)
                        |   alu_tne  & |(adder_result ^ 0) 
                        |   alu_tge  &  ~slt_result[0] 
                        |   alu_tgeu &  ~sltu_result[0] 
                        |   alu_tlt  &  slt_result[0] 
                        |   alu_tltu &  sltu_result[0]; 

    //divide
	assign div_sign  = (alu_controlE == `ALU_SIGNED_DIV);
	assign div_valid = (alu_controlE == `ALU_SIGNED_DIV || alu_controlE == `ALU_UNSIGNED_DIV);

    wire div_res_valid;
    wire div_res_ready;

    assign div_res_ready = div_valid & ~stallM;
    assign div_stallE = div_valid & ~div_res_valid & ~flush_exceptionM & ~flush_branch_likely_M;

	div_radix2 DIV(
		.clk(clk),
		.rst(rst | flushE | flush_branch_likely_M),
		.a(src_aE),         //divident
		.b(src_bE),         //divisor
		.sign(div_sign),    //1 signed

		.opn_valid(div_valid),
        .res_valid(div_res_valid),
        .res_ready(div_res_ready),
		.result(alu_out_div)
	);

    //multiply
    reg [3:0] cnt;

	assign mult_sign = (alu_controlE == `ALU_SIGNED_MULT) | alu_madd | alu_msub;
    assign mult_valid = (alu_controlE == `ALU_SIGNED_MULT) | (alu_controlE == `ALU_UNSIGNED_MULT) | alu_madd_msub;

    assign alu_out_mult = mult_sign ? alu_out_signed_mult : alu_out_unsigned_mult;

    wire mult_ready;
    assign mult_ready = !(cnt ^ 4'b1001);

    always@(posedge clk) begin
        cnt <= rst | (is_multD & ~stallD & ~flushE) | flushE   ?      (0 :      mult_ready ?   cnt : cnt + 1);
    end

    assign unsigned_mult_ce = ~mult_sign & mult_valid & ~mult_ready;
    assign signed_mult_ce = mult_sign & mult_valid & ~mult_ready;
    assign mult_stallE = mult_valid & ~mult_ready & ~flush_exceptionM & ~flush_branch_likely_M;

    signed_mult signed_mult0 (
        .CLK(clk),  // input wire CLK
        .A(src_aE),      // input wire [31 : 0] A
        .B(src_bE),      // input wire [31 : 0] B
        .CE(signed_mult_ce),    // input wire CE
        .SCLR(flushE | flush_branch_likely_M),
        .P(alu_out_signed_mult)      // output wire [63 : 0] P
    );

    unsigned_mult unsigned_mult0 (
        .CLK(clk),  // input wire CLK
        .A(src_aE),      // input wire [31 : 0] A
        .B(src_bE),      // input wire [31 : 0] B
        .CE(unsigned_mult_ce),    // input wire CE
        .SCLR(flushE | flush_branch_likely_M),
        .P(alu_out_unsigned_mult)      // output wire [63 : 0] P
    );

    //RESULT
    assign alu_outE = ({64{div_valid}} & alu_out_div)
                    | ({64{mult_valid & ~alu_madd_msub}} & alu_out_mult)
                    | ({64{alu_madd_msub}} & madd_sub_result)
                    | ({64{alu_mthi}} & {src_aE, hilo[31:0]})
                    | ({64{alu_mtlo}} & {hilo[63:32], src_aE})
                    | ({64{~mult_valid & ~div_valid & ~alu_mthi & ~alu_mtlo}} & {32'b0, alu_out_not_mul_div});

    assign overflowE = (alu_add || alu_sub) & (adder_cout ^ alu_out_not_mul_div[31]) & !(adder_a[31] ^ adder_b[31]);
endmodule