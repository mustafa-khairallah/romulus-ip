module load_key (/*AUTOARG*/ ) ;
`include "../src_rtl/romulus_config_pkg.v"
   parameter DEBUG = 0;

   wire [BUSW-1:0] do_data;
   wire            do_valid, pdi_ready, sdi_ready, do_last;

   reg [BUSW-1:0]  sdi_data, pdi_data;
   reg              sdi_valid, pdi_valid, do_ready;
   reg              rst, clk;

   reg [7:0]  pdi_fifo[1000:0];
   reg [7:0]  sdi_fifo[23:0];
   reg [7:0]  pdo_fifo[23:0];
   reg        sdi_rst;
   reg        pdi_rst;

   integer    sdi_cnt;
   integer    pdi_cnt;

   integer    i_sdi, i_pdi, j;
   integer    plain_len;

   genvar     z;

   LWC uut (
            // Outputs
            do_data, pdi_ready, sdi_ready, do_valid, do_last,
            // Inputs
            pdi_data, sdi_data, pdi_valid, sdi_valid, do_ready, clk, rst
            ) ;

   generate
      for (z = 0; z < BUSW/8; z = z + 1) begin:bus_mapping
         always @ (*) begin
            sdi_data[BUSW-1-8*z:BUSW-8-8*z] <= sdi_fifo[z];
            pdi_data[BUSW-1-8*z:BUSW-8-8*z] <= pdi_fifo[z];
         end
      end
   endgenerate

   // SDI FIFO
   always @(posedge clk) begin
      if (sdi_rst) begin
         sdi_fifo[0] <= LDKEY;
         sdi_fifo[1] <= 8'h00;
         sdi_fifo[2] <= 8'h00;
         sdi_fifo[3] <= 8'h00;

         sdi_fifo[4][7:4] <= KEY;
         sdi_fifo[4][3:0] <= 2;
         sdi_fifo[5] <= 8'h00;
         sdi_fifo[6] <= 8'h00;
         sdi_fifo[7] <= 8'h10;

         for (i_sdi = 0; i_sdi < 16; i_sdi = i_sdi + 1) begin
            sdi_fifo[i_sdi+8] <= i_sdi;
         end
         sdi_valid <= 1;
         sdi_cnt <= 24;
      end
      else if (sdi_ready && sdi_valid) begin
         $display("reading from sdi fifo ...");
         //for (i_sdi = 0; i_sdi < 40; i_sdi = i_sdi + 1) begin
            //$display("%h",sdi_fifo[i_sdi]);
         //end
         sdi_cnt <= sdi_cnt - BUSW/8;
         for (i_sdi = 0; i_sdi < 24-BUSW/8; i_sdi = i_sdi + 1) begin
            sdi_fifo[i_sdi] <= sdi_fifo[i_sdi+BUSW/8];
         end
         for (i_sdi = 24-BUSW/8; i_sdi < 24; i_sdi = i_sdi + 1) begin
            sdi_fifo[i_sdi] <= 0;
         end
         if (sdi_cnt == 0) begin
            sdi_valid <= 0;
         end
      end
   end // always @ (posedge clk)

   // PDI FIFO
   always @(posedge clk) begin
      if (pdi_rst) begin
         plain_len <= 31;

         j = 0;
         pdi_fifo[j] <= ACTKEY;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;

         j = j + 1;
         pdi_fifo[j] <= ENCM;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;

         j = j + 1;
         pdi_fifo[j][7:4] <= AD;
         pdi_fifo[j][3:0] <= 2;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h20;

         for (i_pdi = 0; i_pdi < 32; i_pdi = i_pdi + 1) begin
            j = j + 1;
            pdi_fifo[j] <= i_pdi;
         end // if (pdi_rst)

         j = j + 1;
         pdi_fifo[j][7:4] <= PLAIN;
         pdi_fifo[j][3:0] <= 2;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= plain_len;

         for (i_pdi = 0; i_pdi < 32; i_pdi = i_pdi + 1) begin
            j = j + 1;
            pdi_fifo[j] <= i_pdi;
         end

         j = j + 1;
         pdi_fifo[j][7:4] <= Npub;
         pdi_fifo[j][3:0] <= 2;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h10;

         for (i_pdi = 0; i_pdi < 16; i_pdi = i_pdi + 1) begin
            j = j + 1;
            pdi_fifo[j] <= i_pdi;
         end

         j = j + 1;
         pdi_fifo[j][7:4] <= PLAIN;
         pdi_fifo[j][3:0] <= 2;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= 8'h00;
         j = j + 1;
         pdi_fifo[j] <= plain_len;

         for (i_pdi = 0; i_pdi < 32; i_pdi = i_pdi + 1) begin
            j = j + 1;
            pdi_fifo[j] <= i_pdi;
         end

         pdi_valid <= 1;
         pdi_cnt <= 1000;
      end
      else if (pdi_ready && pdi_valid) begin
         pdi_cnt <= pdi_cnt - BUSW/8;
         for (i_pdi = 0; i_pdi < 1000-BUSW/8; i_pdi = i_pdi + 1) begin
            pdi_fifo[i_pdi] <= pdi_fifo[i_pdi+BUSW/8];
         end
         for (i_pdi = 1000-BUSW/8; i_pdi < 1000; i_pdi = i_pdi + 1) begin
            pdi_fifo[i_pdi] <= 0;
         end
         if (pdi_cnt == 0) begin
            pdi_valid <= 0;
         end
      end
   end

   // Clock
   initial begin
      clk = 0;
      forever begin
         #5 clk = ~clk;
      end
   end

   // FSM monitor

   always @ (posedge clk) begin
      if (DEBUG) begin
         $display("current state %d", uut.control_unit.fsm);
         $display("current state %h", uut.datapath.STATE.state);
         $display("current key %h", uut.datapath.TKEYX.state);
         $display("current tweak %h", uut.datapath.TKEYY.state);
         $display("current counter %h", uut.datapath.TKEYZ.state);
         $display("current tk3 %h", uut.datapath.tk3);
         $display("current empty %h", uut.control_unit.emptymsg);
         $display("current bus counter %h", uut.control_unit.cnt);
         $display("current segment length %h", uut.control_unit.seglen);
         $display("current pad mode %h", uut.control_unit.pad);
      end
      if (do_valid) begin
         //$display("current pdi %h", pdi_data);
         $display("current pdo %h", do_data);
      end
   end

   // Stimuli
   initial begin
      sdi_rst = 1;
      pdi_rst = 1;
      do_ready = 1;
      rst = ~neg_rst;

      #100;
      sdi_rst = 0;
      pdi_rst = 0;
      rst = neg_rst;

      #500;

      $finish();
   end

endmodule // load_key
