module romulus_datapath (/*AUTOARG*/
   // Outputs
   pdo, counter,
   // Inputs
   constant, decrypt, pdi, sdi, domain, clk, srst, senc, sen, xrst, xenc, xen,
   yrst, yenc, yen, zrst, zenc, zen, erst, correct_cnt, iv
   ) ;
`include "romulus_config_pkg.v"

   output [BUSW-1:0] pdo;
   output [55:0]     counter;

   generate
      if (TBC=Deoxys) begin:deoxys_port
         input [8*(RNDS_PER_CLK+1)-1:0] constant;
      end
      else begin:constant_port
         input [CNTW*RNDS_PER_CLK-1:0] constant;
      end
   endgenerate
   input [BUSW/8-1:0] decrypt;
   input [BUSW-1:0]   pdi;
   input [BUSW-1:0]   sdi;
   input [7:0]            domain;

   input                  clk;
   input                  srst, senc, sen;
   input                  xrst, xenc, xen;
   input                  yrst, yenc, yen;
   input                  zrst, zenc, zen;
   input                  erst;
   input                  correct_cnt;
   input                  iv;

   wire [128*STATESHARES-1:0] state_pg;
   wire [128*KEYSHARES-1:0]   key_pg;
   wire [127:0] 	      tweak_pg;
   wire [127:0] 	      domain_separator_pg;
   generate
      if (TBC=Deoxys) begin:deoxys_port
         wire [8*(RNDS_PER_CLK+1)-1:0] constant_pg;
      end
      else begin:constant_port
         wire [CNTW*RNDS_PER_CLK-1:0] constant_pg;
      end
   endgenerate

   wire [128*STATESHARES-1:0]           state;
   wire [128*KEYSHARES-1:0] key;
   wire [127:0]             tweak;
   wire [127:0]             tbcstate;
   wire [128*KEYSHARES-1:0] tkxtbc, tkxcorrect;
   wire [127:0]             tkytbc, tkycorrect;
   wire [127:0]             tkztbc, tkzcorrect, domainseparator;
   wire [127:0]             tka, tkb;
   wire [127:0]             tkc;
   wire [127:0]             tk1, tk2;
   wire [127:0]             tk3, cin;

   state_update STATE (.pdo(pdo),
                       .state_o(state),
                       .decrypt(decrypt),
                       .pdi(pdi),
                       .state_i(tbcstate),
                       .clk(clk),
                       .rst(srst),
                       .en(sen),
                       .iv(iv),
                       .tbc(senc)
                       );

   tkx_update TKEYX (.tkx(key),
                     .sdi(sdi),
                     .tkxtbc(tkxtbc),
                     .tkxcorrect(tkxcorrect),
                     .clk(clk),
                     .rst(xrst),
                     .tbc(xenc),
                     .en(xen)
                     ) ;

   tkx_update TKEYY (.tkx(tweak),
                     .sdi(pdi),
                     .tkxtbc(tkytbc),
                     .tkxcorrect(tkycorrect),
                     .clk(clk),
                     .rst(yrst),
                     .tbc(yenc),
                     .en(yen)
                     ) ;

   tkz_update TKEYZ (.tkz(domainseparator),
                     .tkztbc(tkztbc),
                     .tkzcorrect(tkzcorrect),
                     .clk(clk),
                     .rst(zrst),
                     .tbc(zenc),
                     .domain(domain),
                     .en(zen)
                     ) ;

   generate
      if (TBC == DUMMY) begin
         dummy_rnd tweakablecipher (.nextcnt(tkztbc),
                                    .nextkey(tkxtbc),
                                    .nexttweak(tkytbc),
                                    .nextstate(tbcstate),
                                    .roundkey(key_pg),
                                    .roundtweak(tweak_pg),
                                    .roundcnt(domainseparator_pg),
                                    .roundstate(state_pg),
                                    .constant(constant_pg)
                                    );

         dummy_correctfullperm PERMA (.tko(tka),.tki(key));
         dummy_correctfullperm PERMB (.tko(tkb),.tki(tweak));
         dummy_correctfullperm PERMC (.tko(tkc),.tki(domainseparator));

         dummy_lfsr2_correct LFSR3 (.so(tk1), .si(tka));
         dummy_lfsr3_correct LFSR2 (.so(tk2), .si(tkb));
      end // if (TBC == DUMMY)
      else if (TBC == SKINNY) begin
	 
         skinny_rnd #(.numrnd(RNDS_PER_CLK)) tweakablecipher (.nextcnt(tkztbc),
                                                              .nextkey(tkxtbc),
                                                              .nexttweak(tkytbc),
                                                              .nextstate(tbcstate),
                                                              .roundkey(key_pg),
                                                              .roundtweak(tweak_pg),
                                                              .roundcnt(domainseparator_pg),
                                                              .roundstate(state_pg),
                                                              .constant(constant_pg)
                                                              );

         skinny_correctfullperm PERMA (.tko(tka),.tki(key));
         skinny_correctfullperm PERMB (.tko(tkb),.tki(tweak));
         skinny_correctfullperm PERMC (.tko(tkc),.tki(domainseparator));

         skinny_lfsr2_20 LFSR3 (.so(tk1), .si(tka));
         skinny_lfsr3_20 LFSR2 (.so(tk2), .si(tkb));
      end // if (TBC == SKINNY)
      else if (TBC == DEOXYS) begin
         deoxys_rnd #(.numrnd(RNDS_PER_CLK)) tweakablecipher (.nextcnt(tkztbc),
                                                              .nextkey(tkxtbc),
                                                              .nexttweak(tkytbc),
                                                              .nextstate(tbcstate),
                                                              .roundkey(key_pg),
                                                              .roundtweak(tweak_pg),
                                                              .roundcnt(domainseparator_pg),
                                                              .roundstate(state_pg),
                                                              .constant(constant_pg)
                                                              );

         assign tka = key;
         assign tkb = tweak;
         assign tkc = domainseparator;

         deoxys_lfsr2_20 LFSR3 (.so(tk1), .si(tka));
         deoxys_lfsr3_20 LFSR2 (.so(tk2), .si(tkb));
      end

      if (power_gated == 1) begin
	 assign constant_pg = senc ? constant : 0;
	 assign key_pg = senc ? key : 0;
	 assign tweak_pg = senc ? tweak : 0;
	 assign state_pg = senc ? state : 0;
	 assign domainseparator_pg = senc ? domainseparator : 0;
      end
      else begin
	 assign constant_pg = constant;
	 assign key_pg = key;
	 assign tweak_pg = tweak;
	 assign state_pg = state;
	 assign domainseparator_pg = domainseparator;
      end
   endgenerate

   assign cin = correct_cnt ? domainseparator : tkc;

   lfsr_gf56 CNT (.so(tk3),.si(cin),.domain(domain));

   assign tkxcorrect = tk1;
   assign tkycorrect = tk2;
   assign tkzcorrect = tk3;

endmodule // romulus_datapath

module state_update (/*AUTOARG*/
   // Outputs
   pdo, state_o,
   // Inputs
   decrypt, pdi, state_i, clk, rst, en, tbc, iv
   ) ;
`include "romulus_config_pkg.v"

   output [BUSW-1:0] pdo;
   output [128*STATESHARES-1:0]        state_o;

   input [BUSW/8-1:0] decrypt;
   input [BUSW-1:0]   pdi;
   input [128*STATESHARES-1:0]          state_i;
   input                                clk, rst, en, tbc, iv;

   wire [BUSW-1:0]    pdi_eff;
   wire [BUSW-1:0]    state_buf;
   wire [BUSW-1:0]    gofs;
   wire [128*STATESHARES-1:0]           si;

   reg [128*STATESHARES-1:0]            state;

   genvar                 i;

   assign state_o = state;

   generate
      for (i = 0; i < BUSW/8; i = i + 1) begin:decrypt_mux
         assign pdi_eff[8*i+7:8*i] = decrypt[i] ? pdo[8*i+7:8*i] : pdi[8*i+7:8*i];
      end
   endgenerate

   generate
      if (BUSW == 128*STATESHARES) begin:full_bus_width
         assign si = iv ? pdo : pdi_eff^state[128*STATESHARES-1:0];
      end
      else begin:part_bus_width
         assign si = iv ? {state[128*STATESHARES-BUSW-1:0],
                           pdo} :
                     {state[128*STATESHARES-BUSW-1:0],
                           pdi_eff^state[128*STATESHARES-1:128*STATESHARES-BUSW]};
      end
   endgenerate

   assign state_buf = state[128*STATESHARES-1:128*STATESHARES-BUSW];

   generate
      for (i = 0; i < BUSW/8; i = i + 1) begin:gmatrix
         assign gofs[8*i+7:8*i] = {state_buf[8*i+0]^state_buf[8*i+7],state_buf[8*i+7:8*i+1]};
      end
   endgenerate

   assign pdo = pdi ^ gofs;

   always @ (posedge clk) begin
      if (rst) begin
         state <= 0;
      end
      else begin
         if (en) begin
            if (tbc) begin
               state <= state_i;
            end
            else begin
               state <= si;
            end
         end
      end
   end // always @ (posedge clk)

endmodule // state_update


module tkx_update (/*AUTOARG*/
   // Outputs
   tkx,
   // Inputs
   sdi, tkxtbc, tkxcorrect, clk, rst, tbc, en
   ) ;
`include "romulus_config_pkg.v"

   output [128*KEYSHARES-1:0] tkx;

   input [BUSW-1:0] sdi;
   input [128*KEYSHARES-1:0] tkxtbc, tkxcorrect;
   input                     clk, rst, tbc, en;

   reg [128*KEYSHARES-1:0]   state;

   assign tkx = state;

   generate
   always @ (posedge clk) begin
      if (rst) begin
         if (BUSW == 128*KEYSHARES) begin:full_bus_width
            state <= sdi;
         end
         else begin:half_bus_width
            state <= {state[128*KEYSHARES-BUSW-1:0],sdi};
         end
      end
      else if (en) begin
         if (tbc) begin
            state <= tkxtbc;
         end
         else begin
            state <= tkxcorrect;
         end
      end
   end // always @ (posedge clk)
   endgenerate

endmodule // tkx_update

module tkz_update (/*AUTOARG*/
   // Outputs
   tkz,
   // Inputs
   tkztbc, tkzcorrect, domain, clk, rst, tbc, en
   ) ;
`include "romulus_config_pkg.v"

   output [127:0] tkz;

   input [127:0]  tkztbc, tkzcorrect;
   input [7:0]    domain;
   input                    clk, rst, tbc, en;

   reg [127:0]    state;

   assign tkz = state;

   generate
      always @ (posedge clk) begin
         if (rst) begin
            state <= {56'h01000000000000,domain,64'h00};
         end
         else if (en) begin
            if (tbc) begin
               state <= tkztbc;
            end
            else begin
               state <= tkzcorrect;
            end
         end
      end // always @ (posedge clk)
   endgenerate

endmodule // tkz_update

module dummy_rnd (/*AUTOARG*/
   // Outputs
   nextcnt, nextkey, nexttweak, nextstate,
   // Inputs
   roundkey, roundtweak, roundstate, roundcnt, constant
   ) ;
   output [127:0] nextcnt;
   output [127:0] nextkey, nexttweak, nextstate;
   input [127:0]  roundkey, roundtweak, roundstate;
   input [127:0]  roundcnt;
   input [5:0]    constant;

   assign nextcnt = roundcnt + 1;
   assign nextkey = roundkey + 1;
   assign nexttweak = roundtweak + 1;
   assign nextstate = roundstate + 1;

endmodule // dummy_rnd

module lfsr_gf56 (/*AUTOARG*/
   // Outputs
   so,
   // Inputs
   si, domain
   ) ;
   output [127:0] so;
   input [127:0]  si;
   input [7:0]   domain;

   wire [55:0]   lfsr, lfsrs, lfsrn;

   assign lfsr = {
                  si[ 7+64+8: 0+64+8],
		              si[15+64+8: 8+64+8],
		              si[23+64+8:16+64+8],
		              si[31+64+8:24+64+8],
		              si[39+64+8:32+64+8],
		              si[47+64+8:40+64+8],
		              si[55+64+8:48+64+8]
		              };

   assign lfsrs = {lfsr[54:0],lfsr[55]};
   assign lfsrn = lfsrs ^ {lfsr[55],2'b0,lfsr[55],1'b0,lfsr[55],2'b0};

   assign so = {lfsrn[7:0],
		            lfsrn[15:8],
		            lfsrn[23:16],
		            lfsrn[31:24],
		            lfsrn[39:32],
		            lfsrn[47:40],
		            lfsrn[55:48],
		            domain,
                64'h00};

endmodule // lfsr_gf56

module dummy_correctfullperm (/*AUTOARG*/
   // Outputs
   tko,
   // Inputs
   tki
   ) ;
   output [127:0] tko;
   input [127:0] tki;

   assign tko = tki - 2;
endmodule // dummy_correctfullperm

module dummy_lfsr2_correct (/*AUTOARG*/
   // Outputs
   so,
   // Inputs
   si
   ) ;
   output [127:0] so;
   input [127:0]  si;

   assign so = si;

endmodule // dummy_lfsr2_correct

module dummy_lfsr3_correct (/*AUTOARG*/
   // Outputs
   so,
   // Inputs
   si
   ) ;
   output [127:0] so;
   input [127:0]  si;

   assign so = si;

endmodule // dummy_lfsr3_correct

