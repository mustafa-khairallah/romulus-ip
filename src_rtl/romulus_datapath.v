module romulus_datapath (/*AUTOARG*/
   // Outputs
   pdo, counter,
   // Inputs
   constant, decrypt, pdi, sdi, domain, clk, srst, senc, sen, xrst, xenc, xen,
   yrst, yenc, yen, zrst, zenc, zen, erst, correct_cnt, tk1s
   ) ;
   parameter buswidth = 128;
   parameter constantwidth = 12;
   parameter fullcnt = 0; // 1 if we want full 128 bit tweakey physically,
   // 0 for seleting half the key (useful for skinny)

   output [buswidth-1:0] pdo;
   output [55:0]         counter;

   input [constantwidth-1:0] constant;
   input [buswidth/8-1:0]    decrypt;
   input [buswidth-1:0]      pdi;
   input [buswidth-1:0]      sdi;
   input [7:0]               domain;

   input                     clk;
   input                     srst, senc, sen;
   input                     xrst, xenc, xen;
   input                     yrst, yenc, yen;
   input                     zrst, zenc, zen;
   input                     erst;
   input                     correct_cnt;
   input                     tk1s;

   wire [127:0]              state, key, tweak;
   wire [127:0]              tbcstate;
   wire [127:0]              tkxtbc, tkxcorrect;
   wire [127:0]              tkytbc, tkycorrect;
   wire [63+64*fullcnt:0]    tkztbc, tkzcorrect, domainseperator;
   wire [127:0]              tka, tkb;
   wire [63+64*fullcnt:0]    tkc;
   wire [127:0]              tk1, tk2;
   wire [63+64*fullcnt:0]    tk3, cin;

   assign counter = domainseparator [63+64*fullcnt:8+64*fullcnt];
   assign cin = correct_cnt ? domainseparator[63+64*fullcnt:8+64*fullcnt] : tkc[63+64*fullcnt:8+64*fullcnt];

   state_update #(.buswidth(buswidth)) STATE (.pdo(pdo),
                                              .state_o(state),
                                              .decrypt(decrypt),
                                              .pdi(pdi),
                                              .state_i(tbcstate),
                                              .clk(clk),
                                              .rst(srst),
                                              .en(sen),
                                              .tbc(senc)
                                              );

   tkx_update #(.buswidth(buswidth)) TKEYX (.tkx(key),
                                            .sdi(sdi),
                                            .tkxtbc(tkxtbc),
                                            .tkxcorrect(tkxcorrect),
                                            .clk(clk),
                                            .rst(xrst),
                                            .tbc(xenc),
                                            .en(xen)
                                            ) ;

   tkx_update #(.buswidth(buswidth)) TKEYY (.tkx(tweak),
                                            .sdi(pdi),
                                            .tkxtbc(tkytbc),
                                            .tkxcorrect(tkycorrect),
                                            .clk(clk),
                                            .rst(yrst),
                                            .tbc(yenc),
                                            .en(yen)
                                            ) ;

   tkz_update #(.fullcnt(fullcnt)) TKEYZ (.tkz(domainseparator),
                                          .tkztbc(tkztbc),
                                          .tkzcorrect(tkzcorrect),
                                          .clk(clk),
                                          .rst(zrst),
                                          .tbc(zenc),
                                          .en(zen)
                                          ) ;

   correctfullperm PERMA (.tko(tka),.tki(key));
   correctfullperm PERMB (.tko(tkb),.tki(tweak));
   generate
      if (fullcnt) begin: cnt_correction
         correctfullperm PERMC (.tko(tkc),.tki(domainseperator));
      end
      else begin
         correcthalfperm PERMC (.tko(tkc),.tki(domainseperator));
      end
   endgenerate

   lfsr_counter #(.fullcnt(fullcnt)) CNT (.so(tk3),si(cin),.domain(domain));
   lfsr2_correct LFSR3 (.so(tk1), .si(tka));
   lfsr3_correct LFSR2 (.so(tk2), .si(tkb));

   assign tkxcorrect = tk1;
   assign tkycorrect = tk2;
   assign tkzcorrect = tk3;

   roundfunction #(.fullcnt(fullcnt)) tweakablecipher (.nextcnt(tkztbc),
                                                       .nextkey(tkxtbc),
                                                       .nexttweak(tkytbc),
                                                       .nextstate(tbcstate),
                                                       .roundkey(key),
                                                       .roundtweak(tweak),
                                                       .roundcnt(domainseparator),
                                                       .roundstate(state),
                                                       .constant(constant)
                                                       );

endmodule // romulus_datapath

module state_update (/*AUTOARG*/
   // Outputs
   pdo, state_o,
   // Inputs
   decrypt, pdi, state_i, clk, rst, en, tbc
   ) ;
   parameter buswidth;

   output [buswidth-1:0] pdo;
   output [127:0]        state_o;

   input [buswidth/8-1:0] decrypt;
   input [buswidth-1:0]   pdi;
   input [127:0]          state_i;
   input                  clk, rst, en, tbc;

   wire [buswidth-1:0]    pdi_eff;
   wire [buswidth-1:0]    state_buf;
   wire [buswidth-1:0]    gofs;
   wire [127:0]           si;

   reg [127:0]            state;

   genvar                 i;

   generate
      for (i = 0; i < buswidth/8; i = i + 1) begin:decrypt_mux
         assign pdi_eff[8*i+7:8*i] = decrypt[i] ? pdo[8*i+7:8*i] : pdi[8*i+7:8*i];
      end
   endgenerate

   assign si = {state[128-buswidth-1:0],
                pdi_eff^state[127:128-buswidth]};

   assign state_buf = state[127:96-buswidth];

   generate
      for (i = 0; i < buswidth/8; i = i + 1) begin:gmatrix
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
   parameter buswidth = 128;

   output [127:0] tkx;

   input [buswidth-1:0] sdi;
   input [127:0]        tkxtbc, tkxcorrect;
   input                clk, rst, tbc, en;

   reg [127:0]          state;

   always @ (posedge clk) begin
      if (rst) begin
         state <= {state[128-buswidth-1:0],sdi};
      end
      else if (en) begin
         if (tbc) begin
            state <= tkxtbc;
         end
         else begin
            state <= tkxcorrect;
         end
      end
   end

endmodule // tkx_update

module tkz_update (/*AUTOARG*/
   // Outputs
   tkz,
   // Inputs
   tkztbc, tkzcorrect, clk, rst, tbc, en
   ) ;
   parameter fullcnt = 0;

   output [63+fullcnt*64:0] tkz;

   input [63fullcnt*64:0]   tkztbc, tkzcorrect;
   input                    clk, rst, tbc, en;

   reg [63fullcnt*64:0]     state;

   always @ (posedge clk) begin
      if (rst) begin
         generate
              if (fullcnt == 1) begin:initial_counter_state
              state <= 128'h01000000000000000000000000000000;
           end
           else begin
              state <= 64'h0100000000000000;
           end
         endgenerate
      end
      else if (en) begin
         if (tbc) begin
            state <= tkztbc;
         end
         else begin
            state <= tkzcorrect;
         end
      end
   end

endmodule // tkz_update

