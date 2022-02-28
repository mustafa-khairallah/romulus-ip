module api (/*AUTOARG*/ ) ;
   // RST Polarity
   parameter neg_rst = 1;

   // Bus related parameters
   parameter BUSW = 32;
   parameter PBUSC = 8'h0F; // value of cnt at the end of the pdi input block
   parameter SBUSC = 8'h0F; // value of cnt at the end of the sdi input block
   parameter BBUSC = 8'h01; // Base counter value

   // TBC related parameters
   // 00: dummy, 01: skinny, 02: deoxys-bc
   parameter DUMMY        = 7'h00; // Implementation of the modes without TBC
   parameter SKINNY       = 7'h01;
   parameter DEOXYS       = 7'h02;
   parameter TBC          = DUMMY;
   parameter FINCONST     = 7'h02; // Indicates when the last round is reached
   parameter CNTW         = 6; // The width of the constants counter
   parameter RNDS_PER_CLK = 1;
   parameter CLKS_PER_RND = 1; // 1 for unrolled rounds 2
   parameter STATESHARES  = 1; // Number of ptext/ctext shares
   parameter KEYSHARES    = 1; // Number of key shares

   // BLK COUNTER INITIAL CONSTANT
   parameter INITCTR1 = 56'h02000000000000;
   parameter INITCTR2 = 56'h01000000000000;

   // INSTRUCTIONS
   parameter LDKEY   = 'h40;
   parameter ACTKEY  = 'h70;
   parameter ENCN    = 'h20; // Romulus-N
   parameter DECN    = 'h30;
   parameter ENCM    = 'h21; // Romulus-M
   parameter DECM    = 'h31;
   parameter ENCT    = 'h22; // Romulus-T
   parameter DECT    = 'h32;
   parameter ENCS    = 'h24; // Skinny-128-384+ Encryption
   parameter HASHR   = 'h80; // Romulus-H
   parameter HASHE   = 'h81; // Naito et al.
   parameter SUCCESS = 'hE0;
   parameter FAILURE = 'hF0;

   //SEGMENT HEADERS
   parameter RSRVD1 = 0;
   parameter AD = 1;
   parameter NpubAD = 2;
   parameter ADNpub = 3;
   parameter PLAIN = 4;
   parameter CIPHER = 5;
   parameter CIPHERTAG = 6;
   parameter RSRVD = 7;
   parameter TAG = 8;
   parameter RSRVD2 = 9;
   parameter LENGTH = 10;
   parameter RSRVD3 = 11;
   parameter KEY = 12;
   parameter Npub = 13;
   parameter Nsec = 14;
   parameter ENCNsec = 15;

   output reg [31:0] pdo_data, pdi;
   output reg        pdi_ready, sdi_ready, pdo_valid, do_last;
   output reg        xrst, xenc, xen;
   output reg        yrst, yenc, yen;
   output reg        zrst, zenc, zen;
   output reg        srst, senc, sen;
   output reg        correct_cnt;
   output reg [7:0]  domain;
   output [CNTW*RNDS_PER_CLK-1:0] constant;

   input [31:0]                   pdi_data, pdo, sdi_data;
   input                          pdi_valid, sdi_valid, pdo_ready;

   input             rst, clk;

   reg [15:0]        fsm, fsmn;
   reg [15:0]        seglen, seglenn;
   reg [CNTW-1:0]    cnt, cntn;
   reg [7:0]         instruction, instructionn;
   reg [3:0]         flags, flagsn;
   reg [7:0]         nonce_domain, nonce_domainn;

   wire [CNTW-1:0]   cntw;

   genvar            i;

   generate
      assign constant[CNTW-1:0] = cnt;
      if (TBC == DUMMY) begin:dummy_cnt
         assign cntw = cnt + 1;
      end
      else if (TBC == SKINNY) begin:skinny_cnt
         assign cntw = {cnt[4:0], cnt[5]^cnt[4]^1'b1};
      end
      for (i = 1; i < RNDS_PER_CLK; i = i + 1) begin:round_constants
         if (TBC == DUMMY) begin:dummy_constants
            assign constant[CNTW*(i+1)-1:CNTW*i] = constant[CNTW*i-1:CNTW*(i-1)];
         end
         else if (TBC == SKINNY) begin:skinny_constants
            assign constant[CNTW*(i+1)-1:CNTW*i] = {constant[CNTW*i-2:CNTW*(i-1)], constant[CNTW*i-1]^constant[CNTW*i-2]^1'b1};
         end
      end
   endgenerate

   generate
      if (neg_rst == 0) begin:negative_reset
         always @ (posedge clk) begin
            if (!rst) begin
               fsm <= idle;
               instruction <= 8'h00;
               cnt <= BBUSC;
               correct_cnt <= 1;
               seglen <= 0;
               flags <= 0;
               nonce_domain <= 0;
            end
            else begin
               fsm <= fsmn;
               instruction <= instructionn;
               cnt <= cntn;
               correct_cnt <= correct_cntn;
               seglen <= seglenn;
               flags <= flagsn;
               nonce_domain <= nonce_domainn;
            end
         end
      end
      else begin:positive_reset
      end // else: !if(neg_rst == 0)
   endgenerate

   always @ (*) begin
      fsmn <= fsm;
      pdi_ready <= 0;
      sdi_ready <= 0;
      xrst <= 0;
      xenc <= 0;
      xen  <= 0;
      yrst <= 0;
      yenc <= 0;
      yen  <= 0;
      zrst <= 0;
      zenc <= 0;
      zen  <= 0;
      srst <= 0;
      senc <= 0;
      sen  <= 0;
      nonce_domainn <= 0;
      seglenn <= seglen;
      flagsn <= flags;
      correct_cntn <= correct_cnt;
      instructionn <= instruction;
      cntn <= cnt;
      case (fsm)
        idle: begin
           if (pdi_valid) begin
              if (pdi_data[BUSW-1:BUSW-8] == ACTKEY) begin
                 pdi_ready <= 1;
                 instructionn <= pdi_data[BUSW-1:BUSW-8];
                 if (sdi_valid) begin
                    if (sdi_data[BUSW-1:BUSW-8] == LDKEY) begin
                       sdi_ready <= 1;
                       fsmn <= keyheader;
                    end
                 end
              end
              else begin
                 pdi_ready <= 1;
                 instructionn <= pdi_data[BUSW-1:BUSW-8];
                 case (pdi_data[BUSW-1:BUSW-8])
                   ENCN: begin
                      zrst <= 1;
                      srst <= 1;
                      correct_cntn <= 1;
                      fsmn <= adheader;
                   end
                   DECN: begin
                      zrst <= 1;
                      srst <= 1;
                      correct_cntn <= 1;
                      fsmn <= adheader;
                   end
                   ENCM: begin
                      zrst <= 1;
                      srst <= 1;
                      correct_cntn <= 1;
                      fsmn <= adheader;
                   end
                   DECM: begin
                      zrst <= 1;
                      srst <= 1;
                      correct_cntn <= 1;
                      fsmn <= adheader;
                   end
                   default: begin
                      fsmn <= idle;
                   end
                 endcase // case (pdi_data[BUSW-1:BUSW-8])
              end
           end
        end
        keyheader: begin
           if (sdi_valid) begin
              sdi_ready <= 1;
              if (sdi_data[BUSW-1:BUSW-4] == KEY) begin
                 fsmn <= storkey;
              end
           end
        end // case: keyheader
        storekey: begin
           if (sdi_valid) begin
              sdi_ready <= 1;
              xrst <= 1;
              if (cnt == SBUSC) begin
                 cntn <= BBUSC;
                 if (pdi_valid) begin
                    pdi_ready <= 1;
                    instructionn <= pdi_data[BUSW-1:BUSW-8];
                    case (pdi_data[BUSW-1:BUSW-8])
                      ENCN: begin
                         zrst <= 1;
                         srst <= 1;
                         correct_cntn <= 1;
                         fsmn <= adheader;
                      end
                      DECN: begin
                         zrst <= 1;
                         srst <= 1;
                         correct_cntn <= 1;
                         fsmn <= adheader;
                      end
                      ENCM: begin
                         zrst <= 1;
                         srst <= 1;
                         correct_cntn <= 1;
                         fsmn <= adheader;
                         zrst <= 1;
                         srst <= 1;
                         correct_cntn <= 1;
                         fsmn <= adheader;
                      end
                      default: begin
                         fsmn <= idle;
                      end
                    endcase // case (pdi_data[BUSW-1:BUSW-8])
                 end
                 else begin
                    fsmn <= idle;
                 end
              end
              else begin
                 cntn <= cntw;
              end
           end // if (sdi_valid)
        end // case: storekey
        adheader: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              if (pdi_data[BUS-1:BUSW-4] == AD) begin
                 seglenn <= pdi_data[BUS-17:BUS-32];
                 flagsn <= pdi_data[BUS-5:BUSW-8];
                 if ((pdi_data[BUSW-7] == 1) &&
                     (pdi_data[BUSW-17:BUSW-32] < 16)) begin
                    fsmn <= storeadsp;
                 end
                 else begin
                    fsmn <= storeadsf;
                 end
              end
           end
        end // case: adheader
        adheader2: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              if (pdi_data[BUS-1:BUSW-4] == AD) begin
                 seglenn <= pdi_data[BUS-17:BUS-32];
                 flagsn <= pdi_data[BUS-5:BUSW-8];
                 if ((pdi_data[BUSW-7] == 1) &&
                     (pdi_data[BUSW-17:BUSW-32] < 16)) begin
                    fsmn <= storeadtp;
                 end
                 else begin
                    fsmn <= storeadtf;
                 end
              end
           end
        end // case: adheader2
        storeadsf: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              sen <= 1;
              if (cnt == BBUSC) begin
                 seglenn <= seglen - 16;
                 cntn <= cntw;
              end
              else if (cnt == PBUSC) begin
                 if (counter != INITCTR2) begin
                    xen <= 1;
                 end
                 cntn <= BBUSC;
                 zen <= 1;
                 if (seglen == 0) begin
                    if (flags[1] == 1) begin
                       nonce_domainn <= adfinal;
                       if ((instruction == ENCN) ||
                           (instruction == DECN)) begin
                          fsmn <= nonceheader;
                          domain <= adfinal;
                       end
                       else if ((instruction == ENCM) ||
                                (instruction == DECM)) begin
                          fsmn <= macheader2;
                          domain <= macnormal;
                       end
                    end // if (flags[1] == 1)
                    else begin
                       fsmn <= adheader2;
                       domain <= adnormal;
                    end // else: !if(flags[1] == 1)
                 end // if (seglen == 0)
                 else if (seglen < 16) begin
                    fsmn <= storeadtp;
                    domain <= adnormal;
                 end
                 else begin
                    fsmn <= storeadtf;
                    domain <= adnormal;
                 end
              end // if (cnt == PBUSC)
              else begin
                 cntn <= cntw;
              end
           end // if (pdi_valid)
        end // case: storeadsf
        storeadsp: begin
        end
        storeadtf: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              yrst <= 1;
              if (cnt == BBUSC) begin
                 seglenn <= seglen - 16;
                 cntn <= cntw;
              end
              else if (cnt == PBUSC) begin
                 cntn <= BBUSC;
                 if (flags[1] == 1) begin
                    nonce_domainn <= adfinal;
                 end // if (flags[1] == 1)
                 fsmn <= encryptad;
              end
              else begin
                 cntn <= cntw;
              end
           end
        end
        storeadtp: begin
        end
        macheader: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              if (pdi_data[BUS-1:BUSW-4] == PLAIN) begin
                 seglenn <= pdi_data[BUS-17:BUS-32];
                 flagsn <= pdi_data[BUS-5:BUSW-8];
                 if ((pdi_data[BUSW-7] == 1) &&
                     (pdi_data[BUSW-17:BUSW-32] < 16)) begin
                    fsmn <= storemacsp;
                 end
                 else begin
                    fsmn <= storemacsf;
                 end
              end
           end
        end // case: macheader
        macheader2: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              if (pdi_data[BUS-1:BUSW-4] == AD) begin
                 seglenn <= pdi_data[BUS-17:BUS-32];
                 flagsn <= pdi_data[BUS-5:BUSW-8];
                 if ((pdi_data[BUSW-7] == 1) &&
                     (pdi_data[BUSW-17:BUSW-32] < 16)) begin
                    fsmn <= storemactp;
                 end
                 else begin
                    fsmn <= storemactf;
                 end
              end
           end
        end // case: macheader2
        storemacsf: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              sen <= 1;
              if (cnt == BBUSC) begin
                 seglenn <= seglen - 16;
                 cntn <= cntw;
              end
              else if (cnt == PBUSC) begin
                 if (counter != INITCTR2) begin
                    xen <= 1;
                 end
                 cntn <= BBUSC;
                 zen <= 1;
                 if (seglen == 0) begin
                    if (flags[1] == 1) begin
                       nonce_domainn <= nonce_domain ^ macfinal;
                       if ((instruction == ENCN) ||
                           (instruction == DECN)) begin
                          fsmn <= nonceheader;
                          domain <= nonce_domain ^ macfinal;
                       end
                       else if ((instruction == ENCM) ||
                                (instruction == DECM)) begin
                          fsmn <= nonceheader;
                          domain <= macnormal;
                       end
                    end // if (flags[1] == 1)
                    else begin
                       fsmn <= macheader2;
                       domain <= adnormal;
                    end // else: !if(flags[1] == 1)
                 end // if (seglen == 0)
                 else if (seglen < 16) begin
                    fsmn <= storemactp;
                    domain <= macnormal;
                 end
                 else begin
                    fsmn <= storemactf;
                    domain <= macnormal;
                 end
              end // if (cnt == PBUSC)
              else begin
                 cntn <= cntw;
              end
           end // if (pdi_valid)
        end // case: storeadsf
        storemacsp: begin
        end
        storemactf: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              yrst <= 1;
              if (cnt == BBUSC) begin
                 seglenn <= seglen - 16;
                 cntn <= cntw;
              end
              else if (cnt == PBUSC) begin
                 cntn <= BBUSC;
                 if (flags[1] == 1) begin
                    nonce_domainn <= nonce_domain ^ macfinal;
                 end // if (flags[1] == 1)
                 fsmn <= encryptmac;
              end
              else begin
                 cntn <= cntw;
              end
           end
        end
        storeamactp: begin
        end
        msgheader: begin
           if (pdi_valid) begin
              if (dec == 1) begin
                 if (pdi_data[31:28] == CIPHER) begin
                    seglenn <= pdi_data[15:0];
                    flagsn <= pdi_data[27:24];
                    if ((pdi_data[25] == 1) && (pdi_data[15:0] < 16)) begin
                       if (pdo_ready) begin
                          fsmn <= storemp;
                          pdi_ready <= 1;
                          pdo_valid <= 1;
                          pdo_data <= {PLAIN , pdi_data[27], 1'b0, pdi_data[25],pdi_data[25],pdi_data[23:0]};
                       end
                    end
                    else begin
                       if (pdo_ready) begin
                          pdi_ready <= 1;
                          fsmn <= storemf;
                          pdo_valid <= 1;
                          pdo_data <= {PLAIN , pdi_data[27], 1'b0, pdi_data[25],pdi_data[25],pdi_data[23:0]};
                       end
                    end
                 end
              end // if (dec == 1)
              else begin
                 seglenn <= pdi_data[15:0];
                 flagsn <= pdi_data[27:24];
                 if ((pdi_data[25] == 1) && (pdi_data[15:0] < 16)) begin
                    if (pdo_ready) begin
                       fsmn <= storemp;
                       pdi_ready <= 1;
                       pdo_valid <= 1;
                       pdo_data <= {CIPHER , pdi_data[27], 1'b0, pdi_data[25],1'b0,pdi_data[23:0]};
                    end
                 end
                 else begin
                    if (pdo_ready) begin
                       pdi_ready <= 1;
                       fsmn <= storemf;
                       pdo_valid <= 1;
                       pdo_data <= {CIPHER , pdi_data[27], 1'b0, pdi_data[25],1'b0,pdi_data[23:0]};
                    end
                 end // if (pdo_ready)
              end // else: !if(dec == 1)
           end // if (pdi_valid)
        end // case: msgheader
        storemf: begin
           if (pdi_valid) begin
              if (pdo_ready) begin
                 for (i = 0; i < BUSW/8; i = i + 1) begin
                    decrypt[i] <= dec;
                 end
                 pdo_valid <= 1;
                 pdo_data <= pdo;
                 pdi_ready <= 1;
                 senc <= 1;
                 sse <= 1;
                 if (cnt == BBUSC) begin
                    seglenn <= seglen - 16;
                 end
                 if (cnt == PBUSC) begin
                    zenc <= 1;
                    zse <= 1;
                    yenc <= 1;
                    yse <= 1;
                    xenc <= 1;
                    xse <= 1;
                    correct_cntn <= 1;
                    if ((seglen == 0) && (flags[1] == 1)) begin
                       domain <= msgfinal;
                       nonce_domainn <= adpadded;
                    end
                    else begin
                       domain <= msgnormal;
                    end
                    cntn <= 6'h01;
                    fsmn <= encryptm;
                 end
                 else begin
                    cntn <= cntw;
                 end
              end // if (pdo_ready)
           end
        end
        storemp: begin
        end
        nonceheader: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              if (pdi_data[BUSW-1:BUSW-4] == Npub) begin
                 fsmn <= storen;
              end
           end
        end
        storen: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              yenc <= 1;
              yse <= 1;
              yrst <= 1;
              if (cnt == PBUSC) begin
                 domain <= nonce_domain;
                 //zenc <= 1;
                 //zse <= 1;
                 //if (counter != INITCTR) begin
                 // xse <= 1;
                 // xenc <= 1;
                 //end
                 cntn <= 6'h01;
                 fsmn <= encryptn;
              end
              else begin
                 cntn <= cntw;
              end
           end
        end // case: storen
      endcase // case (fsm)
   end

endmodule // api
