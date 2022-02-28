module LWC (/*AUTOARG*/
            // Outputs
            do_data, pdi_ready, sdi_ready, do_valid, do_last,
               // Inputs
            pdi_data, sdi_data, pdi_valid, sdi_valid, do_ready, clk, rst
            ) ;
`include "romulus_config_pkg.v"
   output [BUSW-1:0] do_data;
   output        pdi_ready, sdi_ready, do_valid, do_last;

   input [BUSW-1:0]  pdi_data, sdi_data;
   input         pdi_valid, sdi_valid, do_ready;

   input         clk, rst;

   wire [BUSW-1:0] pdi, pdo;

   wire            xrst, xenc, xen;
   wire            yrst, yenc, yen;
   wire            zrst, zenc, zen;
   wire            srst, senc, sen;

   wire [CNTW*RNDS_PER_CLK-1:0] constant;

   romulus_multi_dim_api control_unit (
                                       // Outputs
                                       .pdo_data(do_data),
                                       .pdi(pdi),
                                       .pdi_ready(pdi_ready),
                                       .sdi_ready(sdi_ready),
                                       .pdo_valid(pdo_valid),
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
                                       .constant(constant),
                                       // Inputs
                                       .pdi_data(pdi_data),
                                       .pdo(pdo),
                                       .sdi_data(sdi_data),
                                       .pdi_valid(pdi_valid),
                                       .sdi_valid(sdi_valid),
                                       .pdo_ready(pdo_ready),
                                       .rst(rst),
                                       .clk(clk)
                                       ) ;
   

endmodule
