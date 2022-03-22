module romulus_multi_dim_api (/*AUTOARG*/
   // Outputs
   pdo_data, pdi, pdi_ready, rdi_ready, sdi_ready, pdo_valid, do_last, domain,
   xrst, xenc, xen, yrst, yenc, yen, zrst, zenc, zen, srst, senc, sen, iv,
   correct_cnt, decrypt, enrnd, constant,
   // Inputs
   counter, rdi, pdi_data, pdo, sdi_data, pdi_valid, rdi_valid, sdi_valid,
   pdo_ready, rst, clk
   ) ;
`include "romulus_config_pkg.v"
`include "romulus_states.v"

   output reg [BUSW-1:0] pdo_data;
   output reg [BUSW-1:0] pdi;
   output reg            pdi_ready;
   output reg            rdi_ready;
   output reg            sdi_ready;
   output reg            pdo_valid;
   output reg            do_last;

   output reg [7:0]      domain;

   output reg            xrst, xenc, xen;
   output reg            yrst, yenc, yen;
   output reg            zrst, zenc, zen;
   output reg            srst, senc, sen;
   output reg            iv;
   output reg            correct_cnt;
   output reg [3:0]      decrypt;
   output reg [CLKS_PER_RND-1:0] enrnd;

   output [CONSTW-1:0] constant;

   input [55:0]      counter;
   input [RNDW-1:0]  rdi;
   input [BUSW-1:0]      pdi_data;
   input [BUSW-1:0]      pdo;
   input [BUSW-1:0]      sdi_data;
   input                 pdi_valid;
   input                 rdi_valid;
   input                 sdi_valid;
   input                 pdo_ready;

   input                 rst;
   input                 clk;

   reg [15:0]            fsm, fsmn;
   reg [CNTW-1:0]        cnt, cntn;
   reg [15:0]            seglen, seglenn;
   reg [7:0]             instruction, instructionn;
   reg [3:0]             flags, flagsn;
   reg [7:0]             nonce_domain, nonce_domainn;
   reg                   correct_cntn;
   reg [CLKS_PER_RND-1:0] enrndn;
   reg                    dec, decn;
   reg                    emptymsg, emptymsgn;
   reg                    ncrct, ncrctn;
   reg                    last;
   reg                    pad;
   reg                    share_pad;

   reg [BUSW-1:0]         tag_verifier, tag_verifiern;

   reg [7:0]              adnormal, msgnormal;

   reg [STATESHARES-1:0]  share_en, share_enn;

   wire [CNTW-1:0]       cntw;

   wire [BUSW-1:0]       pdi_padded;

   genvar                i;
   integer               i_dec, j_dec;

   assign cntw = cnt + 1;
   generate
      if (TBC == DUMMY) begin:dummy_cnt
         assign constant[CNTW-1:0] = cnt;
      end
      else if (TBC == SKINNY) begin:skinny_cnt
         skinny_constants #(.RNDS_PER_CLK(RNDS_PER_CLK)) constant_gen (.constant(constant),.cnt(cnt));
      end
      else if (TBC == DEOXYS) begin:skinny_cnt
         deoxys_constants #(.RNDS_PER_CLK(RNDS_PER_CLK)) constant_gen (.constant(constant),.cnt(cnt));
      end
   endgenerate

   padding_mux padder (
                       // Outputs
                       .pdi_padded(pdi_padded),
                       // Inputs
                       .pdi_data(pdi_data),
                       .cnt(cnt),
                       .pad(pad),
                       .rdi(rdi[BUSW-1:0]),
                       .share(share_pad),
                       .seglen(seglen[3:0]),
                       .last(last)
                       ) ;

   generate
      if (neg_rst) begin:negative_reset
         always @ (posedge clk) begin
            if (!rst) begin
               fsm <= idle;
               cnt <= BBUSC;
               instruction <= 8'h00;
               seglen <= 0;
               flags <= 0;
               nonce_domain <= 0;
               correct_cnt <= 1;
               enrnd <= 1;
               dec <= 0;
               emptymsg <= 1;
               share_en <= 1;
               ncrct <= 0;
               tag_verifier <= 0;
            end
            else begin
               fsm <= fsmn;
               cnt <= cntn;
               instruction <= instructionn;
               seglen <= seglenn;
               flags <= flagsn;
               nonce_domain <= nonce_domainn;
               correct_cnt <= correct_cntn;
               enrnd <= enrndn;
               dec <= decn;
               emptymsg <= emptymsgn;
               share_en <= share_enn;
               ncrct <= ncrctn;
               tag_verifier <= tag_verifiern;
            end
         end
      end
      else begin:positive_reset
         always @ (posedge clk) begin
            if (rst) begin
               fsm <= idle;
               cnt <= BBUSC;
               instruction <= 8'h00;
               seglen <= 0;
               flags <= 0;
               nonce_domain <= 0;
               correct_cnt <= 1;
               enrnd <= 1;
               dec <= 0;
               emptymsg <= 1;
               share_en <= 1;
               ncrct <= 0;
               tag_verifier <= 0;
            end
            else begin
               fsm <= fsmn;
               cnt <= cntn;
               instruction <= instructionn;
               seglen <= seglenn;
               flags <= flagsn;
               nonce_domain <= nonce_domainn;
               correct_cnt <= correct_cntn;
               enrnd <= enrndn;
               dec <= decn;
               emptymsg <= emptymsgn;
               share_en <= share_enn;
               ncrct <= ncrctn;
               tag_verifier <= tag_verifiern;
            end
         end
      end
   endgenerate

   always @ (*) begin
      adnormal <= ((instruction == ENCN) || (instruction == DECN)) ?
                 nadnormal : madnormal;
      msgnormal <= ((instruction == ENCN) || (instruction == DECN)) ?
                   nmsgnormal : mmsgnormal;
      fsmn <= fsm;
      cntn <= cnt;
      nonce_domainn <= nonce_domain;
      domain <= 0;
      instructionn <= instruction;
      seglenn <= seglen;
      flagsn <= flags;
      correct_cntn <= correct_cnt;
      enrndn <= enrnd;
      emptymsgn <= emptymsg;
      decn <= dec;
      share_enn <= share_en;
      sdi_ready <= 0;
      pdi_ready <= 0;
      pdo_valid <= 0;
      do_last <= 0;
      rdi_ready <= 0;
      share_pad <= 0;
      xrst <= 0;
      xenc <= 0;
      xen <= 0;
      yrst <= 0;
      yenc <= 0;
      yen <= 0;
      zrst <= 0;
      zenc <= 0;
      zen <= 0;
      srst <= 0;
      senc <= 0;
      sen <= 0;
      iv <= 0;
      pdi <= pdi_padded;
      pdo_data <= 0;
      decrypt <= 4'h0;
      last <= 0;
      pad <= 0;
      tag_verifiern <= tag_verifier;
      case (fsm)
        idle: begin
           cntn <= BBUSC;
           instructionn <= 8'h00;
           seglenn <= 0;
           flagsn <= 0;
           nonce_domainn <= 0;
           correct_cntn <= 1;
           enrndn <= 1;
           decn <= 0;
           emptymsgn <= 1;
           share_enn <= 1;
           ncrctn <= 0;
           if (pdi_valid) begin
              if (pdi_data[BUSW-1:BUSW-8] == ACTKEY) begin
                 pdi_ready <= 1;
                 if (sdi_valid) begin
                    if (sdi_data[BUSW-1:BUSW-8] == LDKEY) begin
                       sdi_ready <= 1;
                       fsmn <= keyheader;
                    end // LDKEY
                 end // sdi_valid
                 else begin
                    fsmn <= idle;
                 end
              end // ACTKEY
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
                      decn <= 1;
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
                      decn <= 1;
                      correct_cntn <= 1;
                      fsmn <= tagheader;
                   end
                   default: begin
                      fsmn <= idle;
                   end
                 endcase // case (pdi_data[BUSW-1:BUSW-8])
              end
           end // pdi_valid
        end // idle
        keyheader: begin
           if (sdi_valid) begin
              sdi_ready <= 1;
              if (sdi_data[BUSW-1:BUSW-4] == KEY) begin
                 fsmn <= storekey;
              end
           end
        end // keyheader
        storekey: begin
           if (sdi_valid) begin
              sdi_ready <= 1;
              xrst <= 1;
              if (cnt == SBUSC) begin
                 if (share_en[KEYSHARES-1] == 1) begin
                    cntn <= BBUSC;
                    fsmn <= idle;
                    share_enn <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end // SBUSC
              else begin
                 if (share_en[KEYSHARES-1] == 1) begin
                    cntn <= cntw;
                    share_enn <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end // else: !if(cnt == SBUSC)
           end // if (sdi_valid)
        end // storekey
        adheader: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              if (pdi_data[BUSW-1:BUSW-4] == AD) begin
                 seglenn <= pdi_data[BUSW-17:BUSW-32];
                 flagsn <= pdi_data[BUSW-5:BUSW-8];
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
              if (pdi_data[BUSW-1:BUSW-4] == AD) begin
                 seglenn <= pdi_data[BUSW-17:BUSW-32];
                 flagsn <= pdi_data[BUSW-5:BUSW-8];
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
        macheader: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              if (pdi_data[BUSW-1:BUSW-4] == PLAIN) begin
                 seglenn <= pdi_data[BUSW-17:BUSW-32];
                 flagsn <= pdi_data[BUSW-5:BUSW-8];
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
              if (pdi_data[BUSW-1:BUSW-4] == PLAIN) begin
                 seglenn <= pdi_data[BUSW-17:BUSW-32];
                 flagsn <= pdi_data[BUSW-5:BUSW-8];
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
        storeadsf: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              sen <= 1;
              if (cnt == BBUSC) begin
                 if (share_en[0] == 1) begin
                    seglenn <= seglen - 16;
                 end
                 if (share_en[STATESHARES-1] == 1) begin
                    cntn <= cntw;
                    share_enn <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end
              else if (cnt == PBUSC) begin
                 if (share_en[STATESHARES-1] == 1) begin
                    if (counter != INITCTR2) begin
                       xen <= 1;
                    end
                    cntn <= BBUSC;
                    share_enn <= 1;
                    if (seglen == 0) begin
                       if (flags[1] == 1) begin
                          if ((instruction == ENCN) ||
                              (instruction == DECN)) begin
                             fsmn <= nonceheader;
                             nonce_domainn <= adfinal;
                             domain <= adfinal;
                          end
                          else if ((instruction == ENCM) ||
                                   (instruction == DECM)) begin
                             fsmn <= macheader2;
                             domain <= macnormal;
                             nonce_domainn <= macfinal;
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
                 end // if (share_en[STATESHARES-1] == 1)
                 else begin
                    share_enn <= share_en << 1;
                 end
              end // if (cnt == PBUSC)
              else begin
                 if (share_en[STATESHARES-1] == 1) begin
                    cntn <= cntw;
                    share_enn <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end // else: !if(cnt == PBUSC)
           end // if (pdi_valid)
        end // case: storeadsf
        storeadsp: begin
           pad <= 1;
           share_pad <= 1;
           if (seglen[3:0] > (cnt << BUSSHIFT)) begin
              if (pdi_valid) begin
                 pdi_ready <= 1;
                 sen <= 1;
                 if ((cnt == PBUSC) && (share_en[STATESHARES-1] == 1)) begin
                    seglenn <= 0;
                    cntn <= BBUSC;
                    share_enn <= 1;
                    rdi_ready <= 1;
                    last <= 1;
                    if ((instruction == ENCN) || (instruction == DECN)) begin
                       fsmn <= nonceheader;
                       nonce_domainn <= adpadded;
                    end
                    else if ((instruction == ENCM) || (instruction == DECM)) begin
                       fsmn <= macheader2;
                       nonce_domainn <= macfinal ^ 2;
                    end
                 end
                 else begin
                    if (share_en[STATESHARES-1] == 1) begin
                       cntn <= cntw;
                       share_enn <= 1;
                       rdi_ready <= 1;
                    end
                    else begin
                       share_enn <= share_en << 1;
                    end
                 end
              end
           end
           else begin
              sen <= 1;
              if ((cnt == PBUSC) && (share_en[STATESHARES-1] == 1)) begin
                 seglenn <= 0;
                 cntn <= BBUSC;
                 share_enn <= 1;
                 rdi_ready <= 1;
                 last <= 1;
                 if ((instruction == ENCN) || (instruction == DECN)) begin
                    fsmn <= nonceheader;
                    nonce_domainn <= adpadded;
                 end
                 else if ((instruction == ENCM) || (instruction == DECM)) begin
                    fsmn <= macheader2;
                    nonce_domainn <= macfinal ^ 2;
                 end
              end
              else begin
                 if (share_en[STATESHARES-1] == 1) begin
                    cntn <= cntw;
                    share_enn <= 1;
                    rdi_ready <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end
           end
        end
        storeadtf: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              yrst <= 1;
              if (cnt == BBUSC) begin
                 seglenn <= seglen - 16;
                 cntn <= cntw;
              end
              else if (cnt == TBUSC) begin
                 cntn <= BBUSC;
                 zen <= 1;
                 domain <= adnormal;
                 if (flags[1] == 1) begin
                    if ((instruction == ENCM) || (instruction == DECM)) begin
                       nonce_domainn <= macfinal ^ 8;
                    end
                    else begin
                       nonce_domainn <= adfinal;
                    end
                 end // if (flags[1] == 1)
                 fsmn <= encryptad;
              end
              else begin
                 cntn <= cntw;
              end
           end
        end
        storeadtp: begin
           pad <= 1;
           if (seglen > (cnt << BUSSHIFT)) begin
              if (pdi_valid) begin
                 pdi_ready <= 1;
                 yrst <= 1;
                 if (cnt == BBUSC) begin
                    cntn <= cntw;
                 end
                 else if (cnt == TBUSC) begin
                    seglenn <= 0;
                    cntn <= BBUSC;
                    domain <= adnormal;
                    zen <= 1;
                    last <= 1;
                    if ((instruction == ENCN) || (instruction == DECN)) begin
                       nonce_domainn <= adpadded;
                    end
                    else if ((instruction == ENCM) || (instruction == DECM)) begin
                       nonce_domainn <= macfinal ^ 8 ^ 2;
                    end
                    fsmn <= encryptad;
                 end
                 else begin
                    cntn <= cntw;
                 end
              end
           end
           else begin
              yrst <= 1;
              if (cnt == BBUSC) begin
                 cntn <= cntw;
              end
              else if (cnt == TBUSC) begin
                 seglenn <= 0;
                 domain <= adnormal;
                 zen <= 1;
                 cntn <= BBUSC;
                 last <= 1;
                 if ((instruction == ENCN) || (instruction == DECN)) begin
                    nonce_domainn <= adpadded;
                 end
                 else if ((instruction == ENCM) || (instruction == DECM)) begin
                    nonce_domainn <= macfinal ^ 8 ^ 2;
                 end
                 fsmn <= encryptad;
              end
              else begin
                 cntn <= cntw;
              end
           end
        end // case: storeadtp
        storemacsf: begin
           if (pdi_valid) begin
              emptymsgn <= 0;
              pdi_ready <= 1;
              sen <= 1;
              if (cnt == BBUSC) begin
                 if (share_en[0] == 1) begin
                    seglenn <= seglen - 16;
                 end
                 if (share_en[STATESHARES-1] == 1) begin
                    cntn <= cntw;
                    share_enn <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end
              else if (cnt == PBUSC) begin
                 if (share_en[STATESHARES-1] == 1) begin
                    xen <= 1;
                    cntn <= BBUSC;
                    share_enn <= 1;
                    zen <= 1;
                    correct_cntn <= 1;
                    if (seglen == 0) begin
                       if (flags[1] == 1) begin
                          fsmn <= nonceheader;
                          nonce_domainn <= nonce_domain ^ 4 ^ {5'h0,nonce_domain[3],2'h0};
                          domain <= nonce_domain;
                       end // if (flags[1] == 1)
                       else begin
                          fsmn <= macheader2;
                          domain <= macnormal;
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
                 end // if (share_en[STATESHARES-1] == 1)
                 else begin
                    share_enn <= share_en << 1;
                 end
              end // if (cnt == PBUSC)
              else begin
                 if (share_en[STATESHARES-1] == 1) begin
                    cntn <= cntw;
                    share_enn <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end // else: !if(cnt == PBUSC)
           end // if (pdi_valid)
        end // case: storemacsf
        storemacsp: begin
           pad <= 1;
           if (seglen[3:0] > (cnt << BUSSHIFT)) begin
              if (pdi_valid) begin
                 emptymsgn <= 0;
                 pdi_ready <= 1;
                 sen <= 1;
                 if ((cnt == PBUSC) && (share_en[STATESHARES-1] == 1)) begin
                    seglenn <= 0;
                    cntn <= BBUSC;
                    share_enn <= 1;
                    rdi_ready <= 1;
                    last <= 1;
                    zen <= 1;
                    correct_cntn <= 1;
                    fsmn <= nonceheader;
                    nonce_domainn <= nonce_domain ^ 1 ^ 4 ^ {5'h0,nonce_domain[3],2'h0};
                 end
                 else begin
                    if (share_en[STATESHARES-1] == 1) begin
                       cntn <= cntw;
                       share_enn <= 1;
                       rdi_ready <= 1;
                    end
                    else begin
                       share_enn <= share_en << 1;
                    end
                 end
              end
           end
           else begin
              sen <= 1;
              if ((cnt == PBUSC) && (share_en[STATESHARES-1] == 1)) begin
                 seglenn <= 0;
                 cntn <= BBUSC;
                 share_enn <= 1;
                 rdi_ready <= 1;
                 last <= 1;
                 fsmn <= nonceheader;
                 zen <= 1;
                 correct_cntn <= 1;
                 nonce_domainn <= nonce_domain ^ 1 ^ 4 ^ {5'h0,nonce_domain[3],2'h0};
              end
              else begin
                 if (share_en[STATESHARES-1] == 1) begin
                    cntn <= cntw;
                    share_enn <= 1;
                    rdi_ready <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end
           end
        end // case: storemacsp
        storemactf: begin
           if (pdi_valid) begin
              emptymsgn <= 0;
              pdi_ready <= 1;
              yrst <= 1;
              if (cnt == BBUSC) begin
                 seglenn <= seglen - 16;
                 cntn <= cntw;
              end
              else if (cnt == TBUSC) begin
                 cntn <= BBUSC;
                 zen <= 1;
                 domain <= macnormal;
                 if ((seglen == 0) && (flags[1] == 1)) begin
                    nonce_domainn <= nonce_domain ^ 0 ^ {5'h0,nonce_domain[3],2'h0};
                 end // if (flags[1] == 1)
                 fsmn <= encryptmac;
              end
              else begin
                 cntn <= cntw;
              end
           end
        end
        storemactp: begin
           pad <= 1;
           if (seglen > (cnt << BUSSHIFT)) begin
              if (pdi_valid) begin
                 emptymsgn <= 0;
                 pdi_ready <= 1;
                 yrst <= 1;
                 if (cnt == BBUSC) begin
                    cntn <= cntw;
                 end
                 else if (cnt == TBUSC) begin
                    cntn <= BBUSC;
                    domain <= macnormal;
                    seglenn <= 0;
                    zen <= 1;
                    last <= 1;
                    nonce_domainn <= nonce_domain ^ 1 ^ {5'h0,nonce_domain[3],2'h0};
                    fsmn <= encryptmac;
                 end
                 else begin
                    cntn <= cntw;
                 end
              end
           end
           else begin
              yrst <= 1;
              if (cnt == BBUSC) begin
                 cntn <= cntw;
              end
              else if (cnt == TBUSC) begin
                 seglenn <= 0;
                 domain <= macnormal;
                 zen <= 1;
                 cntn <= BBUSC;
                 last <= 1;
                 nonce_domainn <= nonce_domain ^ 1 ^ {5'h0,nonce_domain[3],2'h0};
                 fsmn <= encryptmac;
              end
              else begin
                 cntn <= cntw;
              end
           end
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
              yrst <= 1;
              if (cnt == TBUSC) begin
                 zen <= 1;
                 domain <= nonce_domain;
                 cntn <= BBUSC;
                 fsmn <= encryptn;
                 enrndn <= 1;
                 if (ncrct) begin
                    xen <= 1;
                    zen <= 1;
                 end
              end // SBUSC
              else begin
                 cntn <= cntw;
              end
           end // sdi_valid
        end // case: storen
        encryptn: begin
           correct_cntn <= 0;
           if (enrnd[CLKS_PER_RND-1] == 1) begin
              sen <= 1;
              xen <= 1;
              yen <= 1;
              zen <= 1;
              senc <= 1;
              xenc <= 1;
              yenc <= 1;
              zenc <= 1;
              cntn <= cntw;
              if (cnt == FINCONST) begin
                 cntn <= BBUSC;
                 if (instruction == ENCM) begin
                    fsmn <= outputtag0;
                    zrst <= 1;
                    correct_cntn <= 1;
                 end
                 else if (instruction == DECM) begin
                    fsmn <= verifytag0;
                    zrst <= 1;
                    correct_cntn <= 1;
                 end
                 else if (instruction == ENCN) begin
                    fsmn <= msgheader;
                    zrst <= 1;
                    correct_cntn <= 1;
                 end
                 else if (instruction == DECN) begin
                    fsmn <= msgheader;
                    zrst <= 1;
                    correct_cntn <= 1;
                 end
              end // if (cnt == FINCONST)
           end // if (enrnd[CLKS_PER_RND-1] == 1)
           else begin
              if (CLKS_PER_RND > 1) begin
                 enrndn <= {enrnd[CLKS_PER_RND-2:0],enrnd[CLKS_PER_RND-1]};
              end
           end // else: !if(enrnd[CLKS_PER_RND-1] == 1)
        end // case: encryptn
        encryptmac: begin
           ncrctn <= 1;
           correct_cntn <= 0;
           if (enrnd[CLKS_PER_RND-1] == 1) begin
              sen <= 1;
              xen <= 1;
              yen <= 1;
              zen <= 1;
              senc <= 1;
              xenc <= 1;
              yenc <= 1;
              zenc <= 1;
              cntn <= cntw;
              if (cnt == FINCONST) begin
                 cntn <= BBUSC;
                 if ((seglen == 0) && (flags[1] == 1)) begin
                    fsmn <= nonceheader;
                 end
                 else begin
                    fsmn <= macheader;
                 end
              end // if (cnt == FINCONST)
           end // if (enrnd[CLKS_PER_RND-1] == 1)
           else begin
              if (CLKS_PER_RND > 1) begin
                 enrndn <= {enrnd[CLKS_PER_RND-2:0],enrnd[CLKS_PER_RND-1]};
              end
           end // else: !if(enrnd[CLKS_PER_RND-1] == 1)
        end // case: encryptmac
        encryptad: begin
           ncrctn <= 1;
           correct_cntn <= 0;
           if (enrnd[CLKS_PER_RND-1] == 1) begin
              sen <= 1;
              xen <= 1;
              yen <= 1;
              zen <= 1;
              senc <= 1;
              xenc <= 1;
              yenc <= 1;
              zenc <= 1;
              cntn <= cntw;
              if (cnt == FINCONST) begin
                 cntn <= BBUSC;
                 if ((seglen == 0) && (flags[1] == 1)) begin
                    if ((instruction == ENCN) || (instruction == DECN)) begin
                       fsmn <= nonceheader;
                    end
                    else if ((instruction == ENCM) || (instruction == DECM)) begin
                       fsmn <= macheader;
                    end
                 end
                 else begin
                    fsmn <= adheader;
                 end
              end // if (cnt == FINCONST)
           end // if (enrnd[CLKS_PER_RND-1] == 1)
           else begin
              if (CLKS_PER_RND > 1) begin
                 enrndn <= {enrnd[CLKS_PER_RND-2:0],enrnd[CLKS_PER_RND-1]};
              end
           end // else: !if(enrnd[CLKS_PER_RND-1] == 1)
        end // case: encryptad
        msgheader: begin
           if (pdi_valid) begin
              if (dec == 0) begin
                 if (pdi_data[BUSW-1:BUSW-4] == PLAIN) begin
                    seglenn <= pdi_data[BUSW-17:BUSW-32];
                    flagsn <= pdi_data[BUSW-5:BUSW-8];
                    if ((pdi_data[BUSW-7] == 1) &&
                        (pdi_data[BUSW-17:BUSW-32] < 16)) begin
                       if (pdo_ready) begin
                          fsmn <= storemp;
                          pdi_ready <= 1;
                          pdo_valid <= 1;
                          pdo_data <= {CIPHER , pdi_data[27], 1'b0, pdi_data[25],pdi_data[25],pdi_data[23:0]};
                       end
                    end
                    else begin
                       if (pdo_ready) begin
                          pdi_ready <= 1;
                          fsmn <= storemf;
                          pdo_valid <= 1;
                          pdo_data <= {CIPHER , pdi_data[27], 1'b0, pdi_data[25],pdi_data[25],pdi_data[23:0]};
                       end
                    end // else: !if((pdi_data[BUSW-7] == 1) &&...
                 end // if (pdi_data[BUSW-1:BUSW-4] == PLAIN)
              end // if (dec == 0)
              else begin
                 if (pdi_data[BUSW-1:BUSW-4] == CIPHER) begin
                    seglenn <= pdi_data[BUSW-17:BUSW-32];
                    flagsn <= pdi_data[BUSW-5:BUSW-8];
                    if ((pdi_data[BUSW-7] == 1) &&
                        (pdi_data[BUSW-17:BUSW-32] < 16)) begin
                       if (pdo_ready) begin
                          fsmn <= storemp;
                          pdi_ready <= 1;
                          pdo_valid <= 1;
                          pdo_data <= {PLAIN , pdi_data[27], 1'b0, pdi_data[25],1'b0,pdi_data[23:0]};
                       end
                    end
                    else begin
                       if (pdo_ready) begin
                          fsmn <= storemf;
                          pdi_ready <= 1;
                          pdo_valid <= 1;
                          pdo_data <= {PLAIN , pdi_data[27], 1'b0, pdi_data[25],1'b0,pdi_data[23:0]};
                       end
                    end // else: !if((pdi_data[BUSW-7] == 1) &&...
                 end // if (pdi_data[BUSW-1:BUSW-4] == CIPHER)
              end // else: !if(dec == 0)
           end // if (pdi_valid)
        end // case: msgheader
        storemf: begin
           if (pdi_valid) begin
              if (pdo_ready) begin
                 for (i_dec = 0; i_dec < BUSW/8; i_dec = i_dec + 1) begin:dec_mux_full
                    decrypt[i_dec] <= dec;
                 end
                 pdo_valid <= 1;
                 pdo_data <= pdo;
                 pdi_ready <= 1;
                 sen <= 1;
                 if (cnt == BBUSC) begin
                    if (share_en[0] == 1) begin
                       seglenn <= seglen - 16;
                    end
                    if (share_en[STATESHARES-1] == 1) begin
                       cntn <= cntw;
                       share_enn <= 1;
                    end
                    else begin
                       share_enn <= share_en << 1;
                    end
                 end
                 else if (cnt == PBUSC) begin
                    if (((seglen == 0) && (flags[1] == 1))
                        && ((instruction == ENCN) || (instruction == DECN)))
                      begin
                       domain <= msgfinal;
                    end
                    else begin
                       domain <= msgnormal;
                    end
                    if (share_en[STATESHARES-1] == 1) begin
                       if (instruction == ENCN) begin
                          fsmn <= encryptm;
                       end
                       else if (instruction == DECN) begin
                          fsmn <= encryptm;
                       end
                       else if (instruction == ENCM) begin
                          if ((seglen == 0) && (flags[1] == 1)) begin
                             fsmn <= statuse;
                          end
                          else begin
                             fsmn <= encryptm;
                          end
                       end
                       else if (instruction == DECM) begin
                          if ((seglen == 0) && (flags[1] == 1)) begin
                             fsmn <= adheader;
                          end
                          else begin
                             fsmn <= encryptm;
                          end
                       end
                       zen <= 1;
                       yen <= 1;
                       xen <= 1;
                       correct_cntn <= 1;
                       cntn <= BBUSC;
                       share_enn <= 1;
                    end
                    else begin
                       share_enn <= share_en << 1;
                    end
                 end // if (cnt == PBUSC)
                 else begin
                    if (share_en[STATESHARES-1] == 1) begin
                       cntn <= cntw;
                       share_enn <= 1;
                    end
                    else begin
                       share_enn <= share_en << 1;
                    end
                 end
              end
           end
        end
        storemp: begin
           pad <= 1;
           share_pad <= 1;
           if (seglen[3:0] > (cnt << BUSSHIFT)) begin
              if (pdi_valid) begin
                 if (pdo_ready) begin
                    for (i_dec = 0; i_dec < BUSW/8; i_dec = i_dec + 1) begin:dec_mux_part
                       if (seglen[3:0] > ((cnt << BUSSHIFT)+i_dec)) begin
                          decrypt[BUSW/8-1-i_dec] <= dec;
                          for (j_dec = 0; j_dec < 8; j_dec = j_dec + 1) begin
                             pdo_data[BUSW-1-8*i_dec-j_dec] <= pdo[BUSW-1-8*i_dec-j_dec];
                          end
                       end
                       else begin
                          decrypt[BUSW/8-1-i_dec] <= 0;
                          for (j_dec = 0; j_dec < 8; j_dec = j_dec + 1) begin
                             pdo_data[BUSW-1-8*i_dec-j_dec] <= 0;
                          end
                       end
                    end
                    pdo_valid <= 1;
                    pdi_ready <= 1;
                    sen <= 1;
                    if (cnt == BBUSC) begin
                       if (share_en[STATESHARES-1] == 1) begin
                          cntn <= cntw;
                          share_enn <= 1;
                          rdi_ready <= 1;
                       end
                       else begin
                          share_enn <= share_en << 1;
                       end
                    end
                    else if (cnt == PBUSC) begin
                       if ((instruction == ENCN) || (instruction == DECN))
                         begin
                            domain <= msgpadded;
                         end
                       if (share_en[STATESHARES-1] == 1) begin
                          if (instruction == ENCN) begin
                             fsmn <= encryptm;
                          end
                          else if (instruction == DECN) begin
                             fsmn <= encryptm;
                          end
                          else if (instruction == ENCM) begin
                             fsmn <= statuse;
                          end
                          else if (instruction == DECM) begin
                             fsmn <= adheader;
                          end
                          zen <= 1;
                          yen <= 1;
                          xen <= 1;
                          correct_cntn <= 1;
                          cntn <= BBUSC;
                          share_enn <= 1;
                          rdi_ready <= 1;
                       end
                       else begin
                          share_enn <= share_en << 1;
                       end
                    end // if (cnt == PBUSC)
                    else begin
                       if (share_en[STATESHARES-1] == 1) begin
                          cntn <= cntw;
                          share_enn <= 1;
                          rdi_ready <= 1;
                       end
                       else begin
                          share_enn <= share_en << 1;
                       end
                    end // else: !if(cnt == PBUSC)
                 end // if (pdo_ready)
              end // if (pdi_valid)
           end // if (seglen[3:0] > (cnt << BUSSHIFT))
           else begin
              sen <= 1;
              decrypt <= 0;
              pdo_data <= 0;
              if (cnt == BBUSC) begin
                 if (share_en[STATESHARES-1] == 1) begin
                    cntn <= cntw;
                    share_enn <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end
              else if (cnt == PBUSC) begin
                 if ((instruction == ENCN) || (instruction == DECN))
                   begin
                      domain <= msgpadded;
                   end
                 if (share_en[STATESHARES-1] == 1) begin
                    zen <= 1;
                    yen <= 1;
                    xen <= 1;
                    correct_cntn <= 1;
                    cntn <= BBUSC;
                    share_enn <= 1;
                    if (instruction == ENCN) begin
                       fsmn <= encryptm;
                    end
                    else if (instruction == DECN) begin
                       fsmn <= encryptm;
                    end
                    else if (instruction == ENCM) begin
                       fsmn <= statuse;
                    end
                    else if (instruction == DECM) begin
                       fsmn <= adheader;
                    end
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end
              else begin
                 if (share_en[STATESHARES-1] == 1) begin
                    cntn <= cntw;
                    share_enn <= 1;
                 end
                 else begin
                    share_enn <= share_en << 1;
                 end
              end // else: !if(cnt == PBUSC)
           end // else: !if(seglen[3:0] > (cnt << BUSSHIFT))
        end // case: storemp
        encryptm: begin
           correct_cntn <= 0;
           if (enrnd[CLKS_PER_RND-1] == 1) begin
              sen <= 1;
              xen <= 1;
              yen <= 1;
              zen <= 1;
              senc <= 1;
              xenc <= 1;
              yenc <= 1;
              zenc <= 1;
              cntn <= cntw;
              if (cnt == FINCONST) begin
                 cntn <= BBUSC;
                 if ((instruction == ENCN) || (instruction == DECN)) begin
                    if (seglen == 0) begin
                       if (flags[1] == 1) begin
                          if (dec == 1) begin
                             fsmn <= verifytag0;
                          end
                          else begin
                             fsmn <= outputtag0;
                          end
                          seglenn <= 0;
                       end
                       else begin
                          fsmn <= msgheader;
                       end
                    end
                    else if (seglen < 16) begin
                       fsmn <= storemp;
                    end
                    else begin
                       fsmn <= storemf;
                    end
                 end
                 else if (instruction == ENCM) begin
                    if (emptymsg == 0) begin
                       emptymsgn <= 1;
                       fsmn <= msgheader;
                    end
                    else if (seglen < 16) begin
                       fsmn <= storemp;
                    end
                    else begin
                       fsmn <= storemf;
                    end
                 end
                 else if (instruction == DECM) begin
                    if (seglen < 16) begin
                       fsmn <= storemp;
                    end
                    else begin
                       fsmn <= storemf;
                    end
                 end
              end // if (cnt == FINCONST)
           end // if (enrnd[CLKS_PER_RND-1] == 1)
           else begin
              if (CLKS_PER_RND > 1) begin
                 enrndn <= {enrnd[CLKS_PER_RND-2:0],enrnd[CLKS_PER_RND-1]};
              end
           end // else: !if(enrnd[CLKS_PER_RND-1] == 1)
        end // case: encryptm
        outputtag0: begin
           if (pdo_ready) begin
              seglenn <= 0;
              pdo_valid <= 1;
              share_enn <= 1;
              pdo_data <= {TAG,4'h3,8'h0,16'h010};
              fsmn <= outputtag1;
           end
        end
        outputtag1: begin
           if (pdo_ready) begin
              sen <= 1;
              pad <= 1;
              pdo_valid <= 1;
              pdo_data <= pdo;
              if (instruction == ENCM) begin
                 iv <= 1;
              end
              if (cnt == PBUSC) begin
                 if (share_en[STATESHARES-1] == 1) begin
                    share_enn <= 1;
                    cntn <= BBUSC;
                    if (instruction == ENCN) begin
                       fsmn <= statuse;
                       xen <= 1;
                       yen <= 1;
                    end
                    else if (instruction == ENCM) begin
                       if (emptymsg) begin
                          fsmn <= ctxtempty;
                          xen <= 1;
                          yen <= 1;
                       end
                       else begin
                          fsmn <= encryptm;
                          xen <= 1;
                          yen <= 1;
                          zrst <= 1;
                          domain <= msgnormal;
                       end
                    end // if (instruction == ENCM)
                 end // if (share_en[STATESHARES-1] == 1)
                 else begin
                    share_enn <= share_en << 1;
                 end // else: !if(share_en[STATESHARES-1] == 1)
              end // if (cnt == PBUSC)
              else if (share_en[STATESHARES-1] == 1) begin
                 cntn <= cntw;
                 share_enn <= 1;
              end
              else begin
                 share_enn <= share_en << 1;
              end
           end // if (pdo_ready)
        end // case: outputtag1
        ctxtempty: begin
           if (pdo_ready) begin
              pdo_valid <= 1;
              pdo_data <= {CIPHER, 4'h3, 24'h0};
              fsmn <= statuse;
           end
        end
        statuse: begin
           if (pdo_ready) begin
              pdo_valid <= 1;
              pdo_data <= {SUCCESS, 24'h0};
              do_last <= 1;
              fsmn <= idle;
           end
        end
        verifytag0: begin
           if (pdi_valid) begin
              if (pdi_data[BUSW-1:BUSW-4] == TAG) begin
                 seglenn <= 0;
                 fsmn <= verifytag1;
                 tag_verifiern <= 0;
                 pdi_ready <= 1;
              end
           end
        end
        verifytag1: begin
           if (pdi_valid) begin
              pdi_ready <= 1;
              pad <= 1;
              if (cnt == PBUSC) begin
                 if (share_en[STATESHARES-1] == 1) begin
                    share_enn <= 1;
                    cntn <= BBUSC;
                    tag_verifiern <= 0;
                    if (((pdo^tag_verifier) != 0) || (dec == 0)) begin
                       fsmn <= statusdf;
                    end
                    else begin
                       fsmn <= statusds;
                    end // else: !if((pdo != 32'h0) || (dec == 0))
                 end
                 else begin
                    share_enn <= share_en << 1;
                    tag_verifiern <= pdo^tag_verifier;
                 end
              end // if (cnt == PBUSC)
              else begin
                 if (share_en[STATESHARES-1] == 1) begin
                    share_enn <= 1;
                    cntn <= cntw;
                    tag_verifiern <= 0;
                    sen <= 1;
                    if ((pdo^tag_verifier) != 0) begin
                       decn <= 0;
                    end
                 end
                 else begin
                    tag_verifiern <= pdo^tag_verifier;
                    share_enn <= share_en << 1;
                 end
              end
           end // if (pdi_valid)
        end // case: verifytag1
        statusds: begin
           if (pdo_ready) begin
              pdo_valid <= 1;
              pdo_data <= {SUCCESS, 24'h0};
              do_last <= 1;
              fsmn <= idle;
              xen <= 1;
           end
        end
        statusdf: begin
           if (pdo_ready) begin
              pdo_valid <= 1;
              pdo_data <= {FAILURE, 24'h0};
              do_last <= 1;
              fsmn <= idle;
              xen <= 1;
           end
        end
      endcase // case (fsm)
   end
endmodule // romulus_multi_dim_api
