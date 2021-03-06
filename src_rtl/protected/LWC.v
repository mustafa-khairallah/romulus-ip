module LWC (/*AUTOARG*/
   // Outputs
   do_data, pdi_ready, sdi_ready, do_valid, rdi_ready, do_last,
   // Inputs
   pdi_data, sdi_data, rdi_data, pdi_valid, sdi_valid, rdi_valid, do_ready, clk,
   rst
   ) ;
`include "romulus_config_pkg.v"
   output [BUSW-1:0] do_data;
   output        pdi_ready, sdi_ready, do_valid, rdi_ready, do_last;

   input [BUSW-1:0]  pdi_data, sdi_data;
   input [RNDW-1:0]  rdi_data;
   input         pdi_valid, sdi_valid, rdi_valid, do_ready;

   input         clk, rst;

   wire [BUSW-1:0] pdi, pdo;

   wire            xrst, xenc, xen;
   wire            yrst, yenc, yen;
   wire            zrst, zenc, zen;
   wire            srst, senc, sen;

   wire [CONSTW-1:0] constant;
   wire                         correct_cnt;
   wire                         iv;

   wire [55:0]                 counter;
   wire [7:0]                  domain;
   wire [3:0]                  decrypt;
   wire [CLKS_PER_RND-1:0]     enrnd;
   wire [1:0] 		       share_en;   

   generate
      if (MASKING == DOM1NC) begin:nc_impl
         romulus_datapath_nc datapath (
                                       // Outputs
                                       .pdo(pdo),
                                       .counter(counter),
                                       // Inputs
                                       .constant(constant),
                                       .decrypt(decrypt),
                                       .pdi(pdi),
                                       .sdi(sdi_data),
                                       .domain(domain),
                                       .clk(clk),
                                       .xrst(xrst),
                                       .xenc(xenc),
                                       .xen(xen),
                                       .yrst(yrst),
                                       .yenc(yenc),
                                       .rdi(rdi_data),
                                       .yen(yen),
                                       .zrst(zrst),
                                       .zenc(zenc),
                                       .zen(zen),
                                       .srst(srst),
                                       .senc(senc),
                                       .sen(sen),
                                       .erst(erst),
                                       .correct_cnt(correct_cnt),
                                       .iv(iv),
                                       .ring_en(enrnd),
                                       .share_en(share_en)
                                       ) ;

         romulus_multi_dim_api_nc control_unit (
                                             // Outputs
                                             .pdo_data(do_data),
                                             .pdi(pdi),
                                             .pdi_ready(pdi_ready),
                                             .sdi_ready(sdi_ready),
                                             .rdi_ready(rdi_ready),
                                             .pdo_valid(do_valid),
                                             .do_last(do_last),
                                             .xrst(xrst),
                                             .xenc(xenc),
                                             .xen(xen),
                                             .yrst(yrst),
                                             .yenc(yenc),
                                             .yen(yen),
                                             .zrst(zrst),
                                             .zenc(zenc),
                                             .zen(zen),
                                             .srst(srst),
                                             .senc(senc),
                                             .sen(sen),
                                             .correct_cnt(correct_cnt),
                                             .constant(constant),
                                             .domain(domain),
                                             .decrypt(decrypt),
                                             .enrnd(enrnd),
                                             .iv(iv),
                                             // Inputs
                                             .rdi(rdi_data),
                                             .rdi_valid(rdi_valid),
                                             .pdi_data(pdi_data),
                                             .pdo(pdo),
                                             .sdi_data(sdi_data),
                                             .pdi_valid(pdi_valid),
                                             .sdi_valid(sdi_valid),
                                             .pdo_ready(do_ready),
                                             .counter(counter),
                                             .rst(rst),
                                             .clk(clk),
                                             .share_en(share_en)
                                             ) ;
      end
      else begin:normal_impl
         romulus_datapath datapath (
                                    // Outputs
                                    .pdo(pdo),
                                    .counter(counter),
                                    // Inputs
                                    .constant(constant),
                                    .decrypt(decrypt),
                                    .pdi(pdi),
                                    .sdi(sdi_data),
                                    .domain(domain),
                                    .clk(clk),
                                    .xrst(xrst),
                                    .xenc(xenc),
                                    .xen(xen),
                                    .yrst(yrst),
                                    .yenc(yenc),
                                    .rdi(rdi_data),
                                    .yen(yen),
                                    .zrst(zrst),
                                    .zenc(zenc),
                                    .zen(zen),
                                    .srst(srst),
                                    .senc(senc),
                                    .sen(sen),
                                    .erst(erst),
                                    .correct_cnt(correct_cnt),
                                    .iv(iv),
                                    .ring_en(enrnd)
                                    ) ;

   romulus_multi_dim_api control_unit (
                                       // Outputs
                                       .pdo_data(do_data),
                                       .pdi(pdi),
                                       .pdi_ready(pdi_ready),
                                       .sdi_ready(sdi_ready),
                                       .rdi_ready(rdi_ready),
                                       .pdo_valid(do_valid),
                                       .do_last(do_last),
                                       .xrst(xrst),
                                       .xenc(xenc),
                                       .xen(xen),
                                       .yrst(yrst),
                                       .yenc(yenc),
                                       .yen(yen),
                                       .zrst(zrst),
                                       .zenc(zenc),
                                       .zen(zen),
                                       .srst(srst),
                                       .senc(senc),
                                       .sen(sen),
                                       .correct_cnt(correct_cnt),
                                       .constant(constant),
                                       .domain(domain),
                                       .decrypt(decrypt),
                                       .enrnd(enrnd),
                                       .iv(iv),
                                       // Inputs
                                       .rdi(rdi_data),
                                       .rdi_valid(rdi_valid),
                                       .pdi_data(pdi_data),
                                       .pdo(pdo),
                                       .sdi_data(sdi_data),
                                       .pdi_valid(pdi_valid),
                                       .sdi_valid(sdi_valid),
                                       .pdo_ready(do_ready),
                                       .counter(counter),
                                       .rst(rst),
                                       .clk(clk)
                                       ) ;
      end // block: normal_impl
   endgenerate

endmodule
