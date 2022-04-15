module romulus_datapath (/*AUTOARG*/
   // Outputs
   pdo, counter,
   // Inputs
   constant, decrypt, pdi, sdi, rdi, domain, clk, srst, senc, sen, xrst, xenc,
   xen, yrst, yenc, yen, zrst, zenc, zen, erst, correct_cnt, ring_en, iv
   ) ;
`include "romulus_config_pkg.v"

   output [BUSW-1:0] pdo;
   output [55:0]     counter;

   input [CONSTW-1:0] constant;
   input [BUSW/8-1:0] decrypt;
   input [BUSW-1:0]   pdi;
   input [BUSW-1:0]   sdi;
   input [RNDW-1:0]   rdi;
   input [7:0]        domain;

   input              clk;
   input              srst, senc, sen;
   input              xrst, xenc, xen;
   input              yrst, yenc, yen;
   input              zrst, zenc, zen;
   input              erst;
   input              correct_cnt;
   input [CLKS_PER_RND-1:0] ring_en;
   input                    iv;

   wire [128*STATESHARES-1:0] state_pg;
   wire [128*KEYSHARES-1:0]   key_pg;
   wire [128*STATESHARES-1:0] state_rtr;
   wire [128*KEYSHARES-1:0]   key_rtr;
   wire [127:0]               tweak_pg;
   wire [127:0]               domainseparator_pg;
   wire [CONSTW-1:0]          constant_pg;

   wire [128*STATESHARES-1:0] state;
   wire [128*KEYSHARES-1:0]   key, nextkey;
   wire [127:0]               tweak;
   wire [128*STATESHARES-1:0] tbcstate, nextstate;
   wire [128*KEYSHARES-1:0]   tkxtbc, tkxcorrect;
   wire [127:0]               tkytbc, tkycorrect;
   wire [127:0]               tkztbc, tkzcorrect, domainseparator;
   wire [128*KEYSHARES-1:0]   tka;
   wire [127:0]               tkb;
   wire [127:0]               tkc;
   wire [128*KEYSHARES-1:0]   tk1;
   wire [127:0]               tk2;
   wire [127:0]               tk3, cin;

   reg [23:0] 		      sbox_en;

   genvar                     i;

   always @ (posedge clk) begin
      if (ring_en[0] == 1) begin
	 sbox_en[0] <= 1;
      end
      
   end

   always @ (negedge clk) begin
      if (ring_en[0] ==1) begin
	 sbox_en[1] <= sbox_en[0];
      end
   end

   assign sbox_en <= {ring_en_ng[11],ring_en[11],
		      ring_en_ng[10],ring_en[10],
		      ring_en_ng[ 9],ring_en[ 9],
		      ring_en_ng[ 8],ring_en[ 8],
		      ring_en_ng[ 7],ring_en[ 7],
		      ring_en_ng[ 6],ring_en[ 6],
		      ring_en_ng[ 5],ring_en[ 5],
		      ring_en_ng[ 4],ring_en[ 4],
		      ring_en_ng[ 3],ring_en[ 3],
		      ring_en_ng[ 2],ring_en[ 2],
		      ring_en_ng[ 1],ring_en[ 1],
		      ring_en_ng[ 0],ring_en[ 0]
		      }

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

   tkx_update #(.shares(KEYSHARES)) TKEYX (.tkx(key),
                                            .sdi(sdi),
                                            .tkxtbc(tkxtbc),
                                            .tkxcorrect(tkxcorrect),
                                            .clk(clk),
                                            .rst(xrst),
                                            .tbc(xenc),
                                            .en(xen)
                                            ) ;

   tkx_update #(.shares(1)) TKEYY (.tkx(tweak),
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

   share_router share_switch (.tbcstate(state_rtr), .statein(state),
                              .tbckey(key_rtr), .keyin(key),
                              .stateout(tbcstate), .nextstate(nextstate),
                              .keycorrect(tkxcorrect),.pcorrectkey(tk1),
                              .keyout(tkxtbc), .nextkey(nextkey)
                              ) ;

   skinny_rnd tweakablecipher (.nextcnt(tkztbc),
                               .nextkey(nextkey),
                               .nexttweak(tkytbc),
                               .nextstate(nextstate),
                               .randomness(rdi),
                               .clk(clk),
                               .roundkey(key_pg),
                               .roundtweak(tweak_pg),
                               .roundcnt(domainseparator_pg),
                               .roundstate(state_pg),
                               .constant(constant_pg)
                               );
   generate
      for (i = 0; i < KEYSHARES; i = i + 1) begin:key_correction_shared
            skinny_correctfullperm PERMA (.tko(tka[127+128*i:128*i]),.tki(key_rtr[127+128*i:128*i]));
            skinny_lfsr2_20 LFSR3 (.so(tk1[127+128*i:128*i]), .si(tka[127+128*i:128*i]));
      end
   endgenerate
   skinny_correctfullperm PERMB (.tko(tkb),.tki(tweak));
   skinny_correctfullperm PERMC (.tko(tkc),.tki(domainseparator));

   skinny_lfsr3_20 LFSR2 (.so(tk2), .si(tkb));

   generate
      if (power_gated == 1) begin:power_gate_gen
         assign constant_pg = senc ? constant : 0;
         assign key_pg = senc ? key_rtr : 0;
         assign tweak_pg = senc ? tweak : 0;
         assign state_pg = senc ? state_rtr : 0;
         assign domainseparator_pg = senc ? domainseparator : 0;
      end
      else begin:no_power_gate_gen
         assign constant_pg = constant;
         assign key_pg = key_rtr;
         assign tweak_pg = tweak;
         assign state_pg = state_rtr;
         assign domainseparator_pg = domainseparator;
      end
   endgenerate

   assign cin = correct_cnt ? domainseparator : tkc;

   lfsr_gf56 CNT (.so(tk3),.si(cin),.domain(domain));


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
   output [128*STATESHARES-1:0] state_o;

   input [BUSW/8-1:0]           decrypt;
   input [BUSW-1:0]             pdi;
   input [128*STATESHARES-1:0]  state_i;
   input                        clk, rst, en, tbc, iv;

   wire [BUSW-1:0]              pdi_eff;
   wire [BUSW-1:0]              state_buf;
   wire [BUSW-1:0]              gofs;
   wire [128*STATESHARES-1:0]   si;

   reg [128*STATESHARES-1:0]    state;

   genvar                       i;

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
	       if (en[0]) begin
		  state[127:0] <= state_i[127:0];
	       end
	       else if (en[1]) begin
		  state[255:128] <= state_i[255:128];
	       end
	       else begin
		  state <= state;
	       end
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
   parameter shares = 1;

   output [128*shares-1:0] tkx;

   input [BUSW-1:0]           sdi;
   input [128*shares-1:0]  tkxtbc, tkxcorrect;
   input                      clk, rst, tbc, en;

   reg [128*shares-1:0]    state;

   assign tkx = state;

   generate
      always @ (posedge clk) begin
         if (rst) begin
            if (BUSW == 128*shares) begin:full_bus_width
               state <= sdi;
            end
            else begin:half_bus_width
               state <= {state[128*shares-BUSW-1:0],sdi};
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
   input          clk, rst, tbc, en;

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
   input [7:0]    domain;

   wire [55:0]    lfsr, lfsrs, lfsrn;

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
   input [127:0]  tki;

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

