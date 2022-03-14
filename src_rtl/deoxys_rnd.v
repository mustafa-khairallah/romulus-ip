module deoxys_rnd (/*AUTOARG*/
   // Outputs
   nextcnt, nextkey, nexttweak, nextstate,
   // Inputs
   roundkey, roundtweak, roundstate, roundcnt, constant
   ) ;
   parameter numrnd = 16;
   parameter fullcnt = 1;

   output [63+64*fullcnt:0] nextcnt;
   output [127:0]           nextkey, nexttweak, nextstate;
   input [127:0]            roundkey, roundtweak, roundstate;
   input [63+64*fullcnt:0]  roundcnt;
   input [7+8*(numrnd-1):0] constant;

   genvar                   i, j;

   wire [63+64*fullcnt:0]   rndcnt [numrnd:0];
   wire [127:0]             sb [0:numrnd-1];
   wire [127:0]             rkey [0:numrnd];
   wire [127:0]             atk [0:numrnd-1];
   wire [127:0]             shr [0:numrnd-1];
   wire [127:0]             x2 [0:numrnd-1];
   wire [127:0]             x3 [0:numrnd-1];
   wire [127:0]             mxc [0:numrnd-1];
   wire [127:0]             rndkey [0:numrnd];
   wire [127:0]             rndtweak [0:numrnd];

   wire [5:0]               rndconstant [numrnd-1:0];

   assign atk[0] = rkey[0] ^ roundstate;

   generate
      for (i = 0; i < numrnd; i = i + 1) begin:unrolled_rounds
         // Substitution
         for (j = 0; j < 16; j = j + 1) begin:sbox_layer
            bSbox sboxi (.Q(sb[i][8*j+7:8*j]),
                         .encrypt(1),
                         .A(atk[i][8*j+7:8*j]));
         end

         // ShiftRows
         assign shr[i][127:96] =  sb[i][127:96];
         assign shr[i][ 95:64] = {sb[i][ 87:64],sb[i][95:88]};
         assign shr[i][ 63:32] = {sb[i][ 47:32],sb[i][63:48]};
         assign shr[i][ 31: 0] = {sb[i][  7: 0],sb[i][31: 8]};

         // MixColumn Coeffs.
         for (j = 0; j < 16; j = j + 1) begin:mxc_coeff
            assign x2[i][8*j+7:8*j] = {shr[i][8*j+6:8*j],1'b0} ^
                                       {3'b0,shr[i][8*j+7],
                                        shr[i][8*j+7],
                                        1'b0,
                                        shr[i][8*j+7],
                                        shr[i][8*j+7]
                                       };
            assign x3[i][8*j+7:8*j] = x2[i][8*j+7:8*j] ^
                                      shr[i][8*j+7:8*j];
         end

         // Mixcolumn
         assign mxc[i][127:96] = x2[i][127:96] ^
                                 x3[i][95:64] ^
                                 shr[i][63:32] ^
                                 shr[i][31:0];
         assign mxc[i][95:64]  = shr[i][127:96] ^
                                 x2[i][95:64] ^
                                 x3[i][63:32] ^
                                 shr[i][31:0];
         assign mxc[i][63:32]  = shr[i][127:96] ^
                                 shr[i][95:64] ^
                                 x2[i][63:32] ^
                                 x3[i][31:0];
         assign mxc[i][31:0]   = x3[i][127:96] ^
                                 shr[i][95:64] ^
                                 shr[i][63:32] ^
                                 x2[i][31:0];

         if (i < (numrnd-1)) begin:second_atk
            assign atk[i+1] = rkey[i] ^ mxc[i];
         end
      end // block: unrolled_rounds

      assign nextstate = (constant[8*numrnd-1:8*numrnd-8] == 8'h39) ?
                         mxc[numrnd-1] ^ rkey[numrnd] : mxc[numrnd-1];

   endgenerate

   generate
      for (i = 0; i < numrnd; i = i + 1) begin:round_constant
         assign rndconstant[i] = constant[7+8*i:0+8*i];
      end
   endgenerate

   generate
      for (i = 0; i < numrnd; i = i + 1) begin:keyexpansion
         key_expansion tk3 (.ko(rndkey[i+1]),.ki(rndkey[i]));
         tweak2_expansion tk2 (.ko(rndtweak[i+1]),.ki(rndtweak[i]));
         tweak1_expansion tk1 (.ko(rndcnt[i+1]),.ki(rndcnt[i]));

         assign rkey[i] = rndkey[i] ^ rndcnt[i] ^ rndtweak[i] ^
                           {8'h01,rndconstant[i],16'h0000,
                            8'h02,rndconstant[i],16'h0000,
                            8'h04,rndconstant[i],16'h0000,
                            8'h08,rndconstant[i],16'h0000
                           };

      end
   endgenerate

   assign nextkey = rndkey[numrnd];
   assign nexttweak = rndtweak[numrnd];
   assign nextcnt = rndcnt[numrnd];
endmodule // deoxys_rnd


module aes_sbox (/*AUTOARG*/
   // Outputs
   so,
   // Inputs
   si
   ) ;
   output [7:0] so;
   input [7:0]  si;

   wire [7 : 0] sbox [0 : 255];

   assign so = sbox[si];

   assign sbox[8'h00] = 8'h63;
   assign sbox[8'h01] = 8'h7c;
   assign sbox[8'h02] = 8'h77;
   assign sbox[8'h03] = 8'h7b;
   assign sbox[8'h04] = 8'hf2;
   assign sbox[8'h05] = 8'h6b;
   assign sbox[8'h06] = 8'h6f;
   assign sbox[8'h07] = 8'hc5;
   assign sbox[8'h08] = 8'h30;
   assign sbox[8'h09] = 8'h01;
   assign sbox[8'h0a] = 8'h67;
   assign sbox[8'h0b] = 8'h2b;
   assign sbox[8'h0c] = 8'hfe;
   assign sbox[8'h0d] = 8'hd7;
   assign sbox[8'h0e] = 8'hab;
   assign sbox[8'h0f] = 8'h76;
   assign sbox[8'h10] = 8'hca;
   assign sbox[8'h11] = 8'h82;
   assign sbox[8'h12] = 8'hc9;
   assign sbox[8'h13] = 8'h7d;
   assign sbox[8'h14] = 8'hfa;
   assign sbox[8'h15] = 8'h59;
   assign sbox[8'h16] = 8'h47;
   assign sbox[8'h17] = 8'hf0;
   assign sbox[8'h18] = 8'had;
   assign sbox[8'h19] = 8'hd4;
   assign sbox[8'h1a] = 8'ha2;
   assign sbox[8'h1b] = 8'haf;
   assign sbox[8'h1c] = 8'h9c;
   assign sbox[8'h1d] = 8'ha4;
   assign sbox[8'h1e] = 8'h72;
   assign sbox[8'h1f] = 8'hc0;
   assign sbox[8'h20] = 8'hb7;
   assign sbox[8'h21] = 8'hfd;
   assign sbox[8'h22] = 8'h93;
   assign sbox[8'h23] = 8'h26;
   assign sbox[8'h24] = 8'h36;
   assign sbox[8'h25] = 8'h3f;
   assign sbox[8'h26] = 8'hf7;
   assign sbox[8'h27] = 8'hcc;
   assign sbox[8'h28] = 8'h34;
   assign sbox[8'h29] = 8'ha5;
   assign sbox[8'h2a] = 8'he5;
   assign sbox[8'h2b] = 8'hf1;
   assign sbox[8'h2c] = 8'h71;
   assign sbox[8'h2d] = 8'hd8;
   assign sbox[8'h2e] = 8'h31;
   assign sbox[8'h2f] = 8'h15;
   assign sbox[8'h30] = 8'h04;
   assign sbox[8'h31] = 8'hc7;
   assign sbox[8'h32] = 8'h23;
   assign sbox[8'h33] = 8'hc3;
   assign sbox[8'h34] = 8'h18;
   assign sbox[8'h35] = 8'h96;
   assign sbox[8'h36] = 8'h05;
   assign sbox[8'h37] = 8'h9a;
   assign sbox[8'h38] = 8'h07;
   assign sbox[8'h39] = 8'h12;
   assign sbox[8'h3a] = 8'h80;
   assign sbox[8'h3b] = 8'he2;
   assign sbox[8'h3c] = 8'heb;
   assign sbox[8'h3d] = 8'h27;
   assign sbox[8'h3e] = 8'hb2;
   assign sbox[8'h3f] = 8'h75;
   assign sbox[8'h40] = 8'h09;
   assign sbox[8'h41] = 8'h83;
   assign sbox[8'h42] = 8'h2c;
   assign sbox[8'h43] = 8'h1a;
   assign sbox[8'h44] = 8'h1b;
   assign sbox[8'h45] = 8'h6e;
   assign sbox[8'h46] = 8'h5a;
   assign sbox[8'h47] = 8'ha0;
   assign sbox[8'h48] = 8'h52;
   assign sbox[8'h49] = 8'h3b;
   assign sbox[8'h4a] = 8'hd6;
   assign sbox[8'h4b] = 8'hb3;
   assign sbox[8'h4c] = 8'h29;
   assign sbox[8'h4d] = 8'he3;
   assign sbox[8'h4e] = 8'h2f;
   assign sbox[8'h4f] = 8'h84;
   assign sbox[8'h50] = 8'h53;
   assign sbox[8'h51] = 8'hd1;
   assign sbox[8'h52] = 8'h00;
   assign sbox[8'h53] = 8'hed;
   assign sbox[8'h54] = 8'h20;
   assign sbox[8'h55] = 8'hfc;
   assign sbox[8'h56] = 8'hb1;
   assign sbox[8'h57] = 8'h5b;
   assign sbox[8'h58] = 8'h6a;
   assign sbox[8'h59] = 8'hcb;
   assign sbox[8'h5a] = 8'hbe;
   assign sbox[8'h5b] = 8'h39;
   assign sbox[8'h5c] = 8'h4a;
   assign sbox[8'h5d] = 8'h4c;
   assign sbox[8'h5e] = 8'h58;
   assign sbox[8'h5f] = 8'hcf;
   assign sbox[8'h60] = 8'hd0;
   assign sbox[8'h61] = 8'hef;
   assign sbox[8'h62] = 8'haa;
   assign sbox[8'h63] = 8'hfb;
   assign sbox[8'h64] = 8'h43;
   assign sbox[8'h65] = 8'h4d;
   assign sbox[8'h66] = 8'h33;
   assign sbox[8'h67] = 8'h85;
   assign sbox[8'h68] = 8'h45;
   assign sbox[8'h69] = 8'hf9;
   assign sbox[8'h6a] = 8'h02;
   assign sbox[8'h6b] = 8'h7f;
   assign sbox[8'h6c] = 8'h50;
   assign sbox[8'h6d] = 8'h3c;
   assign sbox[8'h6e] = 8'h9f;
   assign sbox[8'h6f] = 8'ha8;
   assign sbox[8'h70] = 8'h51;
   assign sbox[8'h71] = 8'ha3;
   assign sbox[8'h72] = 8'h40;
   assign sbox[8'h73] = 8'h8f;
   assign sbox[8'h74] = 8'h92;
   assign sbox[8'h75] = 8'h9d;
   assign sbox[8'h76] = 8'h38;
   assign sbox[8'h77] = 8'hf5;
   assign sbox[8'h78] = 8'hbc;
   assign sbox[8'h79] = 8'hb6;
   assign sbox[8'h7a] = 8'hda;
   assign sbox[8'h7b] = 8'h21;
   assign sbox[8'h7c] = 8'h10;
   assign sbox[8'h7d] = 8'hff;
   assign sbox[8'h7e] = 8'hf3;
   assign sbox[8'h7f] = 8'hd2;
   assign sbox[8'h80] = 8'hcd;
   assign sbox[8'h81] = 8'h0c;
   assign sbox[8'h82] = 8'h13;
   assign sbox[8'h83] = 8'hec;
   assign sbox[8'h84] = 8'h5f;
   assign sbox[8'h85] = 8'h97;
   assign sbox[8'h86] = 8'h44;
   assign sbox[8'h87] = 8'h17;
   assign sbox[8'h88] = 8'hc4;
   assign sbox[8'h89] = 8'ha7;
   assign sbox[8'h8a] = 8'h7e;
   assign sbox[8'h8b] = 8'h3d;
   assign sbox[8'h8c] = 8'h64;
   assign sbox[8'h8d] = 8'h5d;
   assign sbox[8'h8e] = 8'h19;
   assign sbox[8'h8f] = 8'h73;
   assign sbox[8'h90] = 8'h60;
   assign sbox[8'h91] = 8'h81;
   assign sbox[8'h92] = 8'h4f;
   assign sbox[8'h93] = 8'hdc;
   assign sbox[8'h94] = 8'h22;
   assign sbox[8'h95] = 8'h2a;
   assign sbox[8'h96] = 8'h90;
   assign sbox[8'h97] = 8'h88;
   assign sbox[8'h98] = 8'h46;
   assign sbox[8'h99] = 8'hee;
   assign sbox[8'h9a] = 8'hb8;
   assign sbox[8'h9b] = 8'h14;
   assign sbox[8'h9c] = 8'hde;
   assign sbox[8'h9d] = 8'h5e;
   assign sbox[8'h9e] = 8'h0b;
   assign sbox[8'h9f] = 8'hdb;
   assign sbox[8'ha0] = 8'he0;
   assign sbox[8'ha1] = 8'h32;
   assign sbox[8'ha2] = 8'h3a;
   assign sbox[8'ha3] = 8'h0a;
   assign sbox[8'ha4] = 8'h49;
   assign sbox[8'ha5] = 8'h06;
   assign sbox[8'ha6] = 8'h24;
   assign sbox[8'ha7] = 8'h5c;
   assign sbox[8'ha8] = 8'hc2;
   assign sbox[8'ha9] = 8'hd3;
   assign sbox[8'haa] = 8'hac;
   assign sbox[8'hab] = 8'h62;
   assign sbox[8'hac] = 8'h91;
   assign sbox[8'had] = 8'h95;
   assign sbox[8'hae] = 8'he4;
   assign sbox[8'haf] = 8'h79;
   assign sbox[8'hb0] = 8'he7;
   assign sbox[8'hb1] = 8'hc8;
   assign sbox[8'hb2] = 8'h37;
   assign sbox[8'hb3] = 8'h6d;
   assign sbox[8'hb4] = 8'h8d;
   assign sbox[8'hb5] = 8'hd5;
   assign sbox[8'hb6] = 8'h4e;
   assign sbox[8'hb7] = 8'ha9;
   assign sbox[8'hb8] = 8'h6c;
   assign sbox[8'hb9] = 8'h56;
   assign sbox[8'hba] = 8'hf4;
   assign sbox[8'hbb] = 8'hea;
   assign sbox[8'hbc] = 8'h65;
   assign sbox[8'hbd] = 8'h7a;
   assign sbox[8'hbe] = 8'hae;
   assign sbox[8'hbf] = 8'h08;
   assign sbox[8'hc0] = 8'hba;
   assign sbox[8'hc1] = 8'h78;
   assign sbox[8'hc2] = 8'h25;
   assign sbox[8'hc3] = 8'h2e;
   assign sbox[8'hc4] = 8'h1c;
   assign sbox[8'hc5] = 8'ha6;
   assign sbox[8'hc6] = 8'hb4;
   assign sbox[8'hc7] = 8'hc6;
   assign sbox[8'hc8] = 8'he8;
   assign sbox[8'hc9] = 8'hdd;
   assign sbox[8'hca] = 8'h74;
   assign sbox[8'hcb] = 8'h1f;
   assign sbox[8'hcc] = 8'h4b;
   assign sbox[8'hcd] = 8'hbd;
   assign sbox[8'hce] = 8'h8b;
   assign sbox[8'hcf] = 8'h8a;
   assign sbox[8'hd0] = 8'h70;
   assign sbox[8'hd1] = 8'h3e;
   assign sbox[8'hd2] = 8'hb5;
   assign sbox[8'hd3] = 8'h66;
   assign sbox[8'hd4] = 8'h48;
   assign sbox[8'hd5] = 8'h03;
   assign sbox[8'hd6] = 8'hf6;
   assign sbox[8'hd7] = 8'h0e;
   assign sbox[8'hd8] = 8'h61;
   assign sbox[8'hd9] = 8'h35;
   assign sbox[8'hda] = 8'h57;
   assign sbox[8'hdb] = 8'hb9;
   assign sbox[8'hdc] = 8'h86;
   assign sbox[8'hdd] = 8'hc1;
   assign sbox[8'hde] = 8'h1d;
   assign sbox[8'hdf] = 8'h9e;
   assign sbox[8'he0] = 8'he1;
   assign sbox[8'he1] = 8'hf8;
   assign sbox[8'he2] = 8'h98;
   assign sbox[8'he3] = 8'h11;
   assign sbox[8'he4] = 8'h69;
   assign sbox[8'he5] = 8'hd9;
   assign sbox[8'he6] = 8'h8e;
   assign sbox[8'he7] = 8'h94;
   assign sbox[8'he8] = 8'h9b;
   assign sbox[8'he9] = 8'h1e;
   assign sbox[8'hea] = 8'h87;
   assign sbox[8'heb] = 8'he9;
   assign sbox[8'hec] = 8'hce;
   assign sbox[8'hed] = 8'h55;
   assign sbox[8'hee] = 8'h28;
   assign sbox[8'hef] = 8'hdf;
   assign sbox[8'hf0] = 8'h8c;
   assign sbox[8'hf1] = 8'ha1;
   assign sbox[8'hf2] = 8'h89;
   assign sbox[8'hf3] = 8'h0d;
   assign sbox[8'hf4] = 8'hbf;
   assign sbox[8'hf5] = 8'he6;
   assign sbox[8'hf6] = 8'h42;
   assign sbox[8'hf7] = 8'h68;
   assign sbox[8'hf8] = 8'h41;
   assign sbox[8'hf9] = 8'h99;
   assign sbox[8'hfa] = 8'h2d;
   assign sbox[8'hfb] = 8'h0f;
   assign sbox[8'hfc] = 8'hb0;
   assign sbox[8'hfd] = 8'h54;
   assign sbox[8'hfe] = 8'hbb;
   assign sbox[8'hff] = 8'h16;

endmodule // aes_sbox

module tweak1_expansion (/*AUTOARG*/
   // Outputs
   ko,
   // Inputs
   ki
   ) ;
   parameter fullcnt = 0;

   output [127:0] ko;
   input [127:0]  ki;

   wire [127:0]   kp;

   assign kp[127:120] = ki[ 23: 16];
   assign kp[119:112] = ki[ 15:  8];
   assign kp[111:104] = ki[  7:  0];
   assign kp[103: 96] = ki[ 31: 24];
   assign kp[ 95: 88] = ki[127:120];
   assign kp[ 87: 80] = ki[119:112];
   assign kp[ 79: 72] = ki[111:104];
   assign kp[ 71: 64] = ki[103: 96];
   assign kp[ 63: 56] = ki[ 71: 64];
   assign kp[ 55: 48] = ki[ 95: 88];
   assign kp[ 47: 40] = ki[ 87: 80];
   assign kp[ 39: 32] = ki[ 79: 72];
   assign kp[ 31: 24] = ki[ 47: 40];
   assign kp[ 23: 16] = ki[ 39: 32];
   assign kp[ 15:  8] = ki[ 63: 56];
   assign kp[  7:  0] = ki[ 55: 48];

   assign ko = kp;

endmodule // tweak1_expansion

module tweak2_expansion (/*AUTOARG*/
   // Outputs
   ko,
   // Inputs
   ki
   ) ;

   output [127:0] ko;
   input [127:0]  ki;

   wire [127:0]   kp;

   assign kp[127:120] = ki[ 23: 16];
   assign kp[119:112] = ki[ 15:  8];
   assign kp[111:104] = ki[  7:  0];
   assign kp[103: 96] = ki[ 31: 24];
   assign kp[ 95: 88] = ki[127:120];
   assign kp[ 87: 80] = ki[119:112];
   assign kp[ 79: 72] = ki[111:104];
   assign kp[ 71: 64] = ki[103: 96];
   assign kp[ 63: 56] = ki[ 71: 64];
   assign kp[ 55: 48] = ki[ 95: 88];
   assign kp[ 47: 40] = ki[ 87: 80];
   assign kp[ 39: 32] = ki[ 79: 72];
   assign kp[ 31: 24] = ki[ 47: 40];
   assign kp[ 23: 16] = ki[ 39: 32];
   assign kp[ 15:  8] = ki[ 63: 56];
   assign kp[  7:  0] = ki[ 55: 48];

   assign ko[127:120] = {kp[126:120],kp[127]^kp[125]};
   assign ko[119:112] = {kp[118:112],kp[119]^kp[117]};
   assign ko[111:104] = {kp[110:104],kp[111]^kp[109]};
   assign ko[103: 96] = {kp[102: 96],kp[103]^kp[101]};
   assign ko[ 95: 88] = {kp[ 94: 88],kp[ 95]^kp[ 93]};
   assign ko[ 87: 80] = {kp[ 86: 80],kp[ 87]^kp[ 85]};
   assign ko[ 79: 72] = {kp[ 78: 72],kp[ 79]^kp[ 77]};
   assign ko[ 71: 64] = {kp[ 70: 64],kp[ 71]^kp[ 69]};
   assign ko[ 63: 56] = {kp[ 62: 56],kp[ 63]^kp[ 61]};
   assign ko[ 55: 48] = {kp[ 54: 48],kp[ 55]^kp[ 53]};
   assign ko[ 47: 40] = {kp[ 46: 40],kp[ 47]^kp[ 45]};
   assign ko[ 39: 32] = {kp[ 38: 32],kp[ 39]^kp[ 37]};
   assign ko[ 31: 24] = {kp[ 30: 24],kp[ 31]^kp[ 29]};
   assign ko[ 23: 16] = {kp[ 22: 16],kp[ 23]^kp[ 21]};
   assign ko[ 15:  8] = {kp[ 14:  8],kp[ 15]^kp[ 13]};
   assign ko[  7:  0] = {kp[  6:  0],kp[  7]^kp[  5]};

endmodule // tweak2_expansion

module key_expansion (/*AUTOARG*/
   // Outputs
   ko,
   // Inputs
   ki
   ) ;

   output [127:0] ko;
   input [127:0]  ki;

   wire [127:0]   kp;

   assign kp[127:120] = ki[ 23: 16];
   assign kp[119:112] = ki[ 15:  8];
   assign kp[111:104] = ki[  7:  0];
   assign kp[103: 96] = ki[ 31: 24];
   assign kp[ 95: 88] = ki[127:120];
   assign kp[ 87: 80] = ki[119:112];
   assign kp[ 79: 72] = ki[111:104];
   assign kp[ 71: 64] = ki[103: 96];
   assign kp[ 63: 56] = ki[ 71: 64];
   assign kp[ 55: 48] = ki[ 95: 88];
   assign kp[ 47: 40] = ki[ 87: 80];
   assign kp[ 39: 32] = ki[ 79: 72];
   assign kp[ 31: 24] = ki[ 47: 40];
   assign kp[ 23: 16] = ki[ 39: 32];
   assign kp[ 15:  8] = ki[ 63: 56];
   assign kp[  7:  0] = ki[ 55: 48];

   assign ko[127:120] = {kp[120]^kp[126],kp[127:121]};
   assign ko[119:112] = {kp[112]^kp[118],kp[119:113]};
   assign ko[111:104] = {kp[104]^kp[110],kp[111:105]};
   assign ko[103: 96] = {kp[ 96]^kp[102],kp[103: 97]};
   assign ko[ 95: 88] = {kp[ 88]^kp[ 94],kp[ 95: 89]};
   assign ko[ 87: 80] = {kp[ 80]^kp[ 86],kp[ 87: 81]};
   assign ko[ 79: 72] = {kp[ 72]^kp[ 78],kp[ 79: 73]};
   assign ko[ 71: 64] = {kp[ 64]^kp[ 70],kp[ 71: 65]};
   assign ko[ 63: 56] = {kp[ 56]^kp[ 62],kp[ 63: 57]};
   assign ko[ 55: 48] = {kp[ 48]^kp[ 54],kp[ 55: 49]};
   assign ko[ 47: 40] = {kp[ 40]^kp[ 46],kp[ 47: 41]};
   assign ko[ 39: 32] = {kp[ 32]^kp[ 38],kp[ 39: 33]};
   assign ko[ 31: 24] = {kp[ 24]^kp[ 30],kp[ 31: 25]};
   assign ko[ 23: 16] = {kp[ 16]^kp[ 22],kp[ 23: 17]};
   assign ko[ 15:  8] = {kp[  8]^kp[ 14],kp[ 15:  9]};
   assign ko[  7:  0] = {kp[  0]^kp[  6],kp[  7:  1]};

endmodule // key_expansion

/* square in GF(2^2), using normal basis [Omega^2,Omega]
 * inverse is the same as square in GF(2^2), using any normal basis
 */
module GF_SQ_2 ( A, Q );
  input [1:0] A;
  output [1:0] Q;

  assign Q = { A[0], A[1] };
endmodule

/* scale by w = Omega in GF(2^2), using normal basis [Omega^2,Omega] */
module GF_SCLW_2 ( A, Q );
  input [1:0] A;
  output [1:0] Q;
  assign Q = { (A[1] ^ A[0]), A[1] };
endmodule

/* scale by w^2 = Omega^2 in GF(2^2), using normal basis [Omega^2,Omega] */
module GF_SCLW2_2 ( A, Q );
  input [1:0] A;
  output [1:0] Q;
  assign Q = { A[0], (A[1] ^ A[0]) };
endmodule

/* multiply in GF(2^2), shared factors, module GF_MULS_2 ( A, ab, B, cd, Q );
using normal basis [Omega^2,Omega] */
module GF_MULS_2 ( A, ab, B, cd, Q );
  input [1:0] A;
  input ab;
  input [1:0] B;
  input cd;
  output [1:0] Q;
  wire abcd, p, q;
  assign abcd = ~(ab & cd);  /* note:~& syntax for NAND won’t compile */
  assign p = (~(A[1] & B[1])) ^ abcd;
  assign q = (~(A[0] & B[0])) ^ abcd;
  assign Q = { p, q };
endmodule

/* multiply & scale by N in GF(2^2), shared factors, basis [Omega^2,Omega] */
module GF_MULS_SCL_2 ( A, ab, B, cd, Q );
  input [1:0] A;
  input ab;
  input [1:0] B;
  input cd;
  output [1:0] Q;
  wire t, p, q;

  assign t = ~(A[0] & B[0]); /* note: ~& syntax for NAND won’t compile */
  assign p = (~(ab & cd)) ^ t;
  assign q = (~(A[1] & B[1])) ^ t;
  assign Q = { p, q };
endmodule

module GF_INV_4 ( A, Q );
  input [3:0] A; output [3:0] Q;
  wire [1:0] a, b, c,d,p,q;
  wire sa, sb, sd; /* for shared factors in multipliers */

  assign a = A[3:2]; assign b = A[1:0];
  assign sa = a[1] ^ a[0];
  assign sb = b[1] ^ b[0];
  /* optimize this section as shown below
    GF_MULS_2 abmul(a, sa, b, sb, ab);
    GF_SQ_2 absq( (a ^ b), ab2);
    GF_SCLW2_2 absclN( ab2, ab2N);
    GF_SQ_2 dinv( (ab ^ ab2N), d);
  */
  assign c = { /* note: ~| syntax for NOR won’t compile */
    ~(a[1] | b[1]) ^ (~(sa &  sb)) ,
    ~(sa | sb) ^ (~(a[0] & b[0])) };
  /* end of optimization */

  assign sd = d[1] ^ d[0];
  GF_MULS_2 pmul(d, sd, b, sb, p);
  GF_MULS_2 qmul(d, sd, a, sa, q);
  assign Q = { p, q };
endmodule

/* square & scale by nu in GF(2^4)/GF(2^2),
 * in the normal basis [alpha^8, alpha^2]:
 *
 * nu = beta^8 = N^2*alpha^2, N = w^2
 */
module GF_SQ_SCL_4 ( A, Q );
  input [3:0] A;
  output [3:0] Q;
  wire [1:0] a, b, ab2, b2, b2N2;
  assign a = A[3:2];
  assign b = A[1:0];
  GF_SQ_2 absq(a ^ b, ab2);
  GF_SQ_2 bsq(b, b2);
  GF_SCLW_2 bmulN2(b2, b2N2);

  assign Q = { ab2, b2N2 };
endmodule

/* multiply in GF(2^4)/GF(2^2), shared factors, basis [alpha^8, alpha^2] */
module GF_MULS_4 ( A, a, Al, Ah, aa, B, b, Bl, Bh, bb, Q );
  input [3:0] A;
  input [1:0] a;
  input Al;
  input Ah;
  input aa;
  input [3:0] B;
  input [1:0] b;
  input Bl;
  input Bh;
  input bb;
  output [3:0] Q;
  wire [1:0] ph, pl, ps, p;
  wire t;

  GF_MULS_2 himul(A[3:2], Ah, B[3:2], Bh, ph);
  GF_MULS_2 lomul(A[1:0], Al, B[1:0], Bl, pl);
  GF_MULS_SCL_2 summul( a, aa, b, bb, p);
  assign Q = { (ph ^ p), (pl ^ p) };
endmodule

/* inverse in GF(2^8)/GF(2^4), using normal basis [d^16, d] */
module GF_INV_8 ( A, Q );
  input [7:0] A;
  output [7:0] Q;
  wire [3:0] a, b, c, d, p, q;
  wire [1:0] sa, sb, sd, t; /* for shared factors in multipliers */
  wire al, ah, aa, bl, bh, bb, dl, dh, dd; /* for shared factors */
  wire c1, c2, c3; /* for temp var */

  assign a = A[7:4];
  assign b = A[3:0];
  assign sa = a[3:2] ^ a[1:0];
  assign sb = b[3:2] ^ b[1:0];
  assign al = a[1] ^ a[0];
  assign ah = a[3] ^ a[2];
  assign aa = sa[1] ^ sa[0];
  assign bl = b[1] ^ b[0];
  assign bh = b[3] ^ b[2];
  assign bb = sb[1] ^ sb[0];

  /* optimize this section as shown below
  GF_MULS_4 abmul(a, sa, al, ah, aa, b, sb, bl, bh, bb, ab);
  GF_SQ_SCL_4 absq( (a ^ b), ab2);
  GF_INV_4 dinv( (ab ^ ab2), d);
  */
  assign c1 = ~(ah & bh);
  assign c2 = ~(sa[0] & sb[0]);
  assign c3 = ~(aa & bb);
  assign c = {
    (~(sa[0] | sb[0]) ^ (~(a[3] & b[3]))) ^ c1 ^ c3 ,
    (~(sa[1] | sb[1]) ^ (~(a[2] & b[2]))) ^ c1 ^ c2 ,
    (~(al | bl) ^ (~(a[1] & b[1]))) ^ c2 ^ c3 ,
    (~(a[0] | b[0]) ^ (~(al & bl))) ^ (~(sa[1] & sb[1])) ^ c2
    };
  GF_INV_4 dinv( c, d);
  /* end of optimization */
  assign sd = d[3:2] ^ d[1:0];
  assign dl = d[1] ^ d[0];
  assign dh = d[3] ^ d[2];
  assign dd = sd[1] ^ sd[0];
  GF_MULS_4 pmul(d, sd, dl, dh, dd, b, sb, bl, bh, bb, p);
  GF_MULS_4 qmul(d, sd, dl, dh, dd, a, sa, al, ah, aa, q);
  assign Q = { p, q };
endmodule

/* MUX21I is an inverting 2:1 multiplexor */
module MUX21I ( A, B, s, Q );
  input A;
  input B;
  input s;
  output Q;

  assign Q = ~( s ? A : B );
endmodule

/* select and invert (NOT) byte, using MUX21I */
module SELECT_NOT_8 ( A, B, s, Q );
  input [7:0] A;
  input [7:0] B;
  input s;
  output [7:0] Q;
  MUX21I m7(A[7], B[7], s, Q[7]);
  MUX21I m6(A[6], B[6], s, Q[6]);
  MUX21I m5(A[5], B[5], s, Q[5]);
  MUX21I m4(A[4], B[4], s, Q[4]);
  MUX21I m3(A[3], B[3], s, Q[3]);
  MUX21I m2(A[2], B[2], s, Q[2]);
  MUX21I m1(A[1], B[1], s, Q[1]);
  MUX21I m0(A[0], B[0], s, Q[0]);
endmodule


/* find either Sbox or its inverse in GF(2^8), by Canright Algorithm */
module bSbox ( A, encrypt, Q );
  input [7:0] A;
  input encrypt; /* 1 for Sbox, 0 for inverse Sbox */
  output [7:0] Q;
  wire [7:0] B, C, D, X, Y, Z;
  wire R1, R2, R3, R4, R5, R6, R7, R8, R9;
  wire T1, T2, T3, T4, T5, T6, T7, T8, T9, T10;

  /* change basis from GF(2^8)
  /* combine with bit inverse matrix multiply of Sbox */
  assign R1 = A[7] ^ A[5] ;
  assign R2 = A[7] ~^ A[4] ;
  assign R3 = A[6] ^ A[0] ;
  assign R4 = A[5] ~^ R3 ;
  assign R5 = A[4] ^ R4 ;
  assign R6 = A[3] ^ A[0] ;
  assign R7 = A[2] ^ R1 ;
  assign R8 = A[1] ^ R3 ;
  assign R9 = A[3] ^ R8 ;
  assign B[7] = R7 ~^ R8 ;
  assign B[6] = R5 ;
  assign B[5] = A[1] ^ R4 ;
  assign B[4] = R1 ~^ R3 ;
  assign B[3] = A[1]^ R2 ^ R6 ;
  assign B[2] = ~ A[0] ;
  assign B[1] = R4 ;
  assign B[0] = A[2] ~^ R9 ;
  assign Y[7] = R2 ;
  assign Y[6] = A[4] ^ R8 ;

  assign Y[5] = A[6] ^ A[4] ;
  assign Y[4] = R9 ;
  assign Y[3] = A[6] ~^ R2 ;
  assign Y[2] = R7 ;
  assign Y[1] = A[4] ^ R6 ;
  assign Y[0] = A[1] ^ R5 ;

  SELECT_NOT_8 sel_in( B, Y, encrypt, Z );
  GF_INV_8 inv( Z, C );
  /* change basis back from GF(2^8)/GF(2^4)/GF(2^2) to GF(2^8) */
  assign T1 = C[7] ^ C[3];
  assign T2 = C[6] ^ C[4];
  assign T3 = C[6] ^ C[0];
  assign T4 = C[5] ~^ C[3] ;
  assign T5 = C[5] ~^ T1 ;
  assign T6 = C[5] ~^ C[1] ;
  assign T7 = C[4] ~^ T6 ;
  assign T8 = C[2] ^ T4 ;
  assign T9 = C[1] ^ T2 ;
  assign T10 = T3 ^ T5 ;
  assign D[7] = T4 ;
  assign D[6] = T1 ;
  assign D[5] = T3 ;
  assign D[4] = T5 ;
  assign D[3] = T2 ^ T5;
  assign D[2] = T3 ^ T8;
  assign D[1] = T7 ;
  assign D[0] = T9 ;
  assign X[7] = C[4] ~^ C[1] ;
  assign X[6] = C[1] ^ T10 ;
  assign X[5] = C[2] ^ T10 ;
  assign X[4] = C[6] ~^ C[1] ;
  assign X[3] = T8 ^ T9 ;
  assign X[2] = C[7] ~^ T7 ;
  assign X[1] = T6 ;
  assign X[0] = ~ C[2] ;
  SELECT_NOT_8 sel_out( D, X, encrypt, Q );
endmodule

