

// RST Polarity
parameter neg_rst = 1;
parameter power_gated = 0;

// Bus related parameters
parameter BUSW = 32;
parameter RNDW = 128; // fresh randomness width
parameter BUSSHIFT = 2; // multiply the bus counter by 2^BUSSHIFT
parameter PBUSC = 8'h03; // value of cnt at the end of the pdi input block when loaded into S
parameter TBUSC = 8'h03; // value of cnt at the end of the pdi input block when loaded into T
parameter SBUSC = 8'h03; // value of cnt at the end of the sdi input block
parameter BBUSC = 8'h00; // Base counter value

// TBC related parameters
// 00: dummy, 01: skinny, 02: deoxys-bc
parameter DUMMY        = 7'h00; // Implementation of the modes without TBC
parameter SKINNY       = 7'h01;
parameter DEOXYS       = 7'h02;
parameter TBC          = SKINNY;
parameter FINCONST     = 39; // Indicates when the last round is reached
parameter CNTW         = 6; // The width of the constants counter
parameter RNDS_PER_CLK = 1;
parameter CONSTW       = 6;
parameter fullcnt = 1;
parameter CLKS_PER_RND = 5; // 1 for unrolled rounds
parameter STATESHARES  = 2; // Number of ptext/ctext shares
parameter KEYSHARES    = 2; // Number of key shares

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

// DOMAINS
parameter nadnormal = 8;
parameter adfinal = 24;
parameter adpadded = 26;
parameter nmsgnormal = 4;
parameter msgfinal = 20;
parameter msgpadded = 21;

parameter madnormal = 40;
parameter macnormal = 44;
parameter macfinal = 48;
parameter mmsgnormal = 36;

// Masking paramaters

parameter DOM1NP    = 0;
parameter DOM1LR    = 1;
parameter DOM1RPD   = 2;
parameter DOM1SNI   = 3;
parameter DOM1DEP   = 4;

parameter CMS1      = 5;
parameter CMS1RPD   = 6;

parameter HPC2_1    = 7;
parameter HPC2_1STR = 8;

parameter ISW1      = 9;
parameter ISW1BP    = 10;
parameter ISW1PINI  = 11;

parameter PARA1     = 12;

parameter PINI1     = 13;

parameter DOM1NC    = 14;

parameter MASKING = DOM1LR;


