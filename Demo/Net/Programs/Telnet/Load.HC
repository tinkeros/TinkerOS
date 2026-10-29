#include "Bookmarks"

#define TT_CFG_PATH "::/Home/.config"
#define TT_CFG_FILE "telnet.cfg"
#define PROMPT_Q 0xFFFF
#define REMOTE_Q 0xFFFE
#define TERM_DBG 0

// TODO add blank space between lines?

#define TERM_ROW_SPACING 8

I64 term_width=640,term_height=480;
I64 term_rows=term_height/(FONT_HEIGHT+TERM_ROW_SPACING),term_cols=80;

CDoc *dbgput=Fs->put_doc;

CDC *tt_buf;
I64 tt_cur_x=0;
I64 tt_cur_y=0;
I64 tt_cur_bg=BLACK;
I64 tt_cur_fg=WHITE;
I64 tt_cur_int=0;
I64 tt_sr_y1=0;
I64 tt_sr_y2=23;

I64 res=0;

CTCPSock  *tcp = TCPSock(AF_INET);
CSockAddrIPV4 sock_addr;
CIPV4Addr       ip_addr;


Bool ansikeys=FALSE;

// TODO

static U8    last_rx_hex_buf[2*ETH_FRAME_SIZE];




//TODO
I64 last_sc;
//I64 last_hex_len;

I64 isArrow()
{
  I64 i=kbd.scan_code & 0xFF;
  if (i==72) { return 1; };
  if (i==75) { return 1; };
  if (i==80) { return 1; };
  if (i==77) { return 1; };
  if (i==SC_F12) { return 1; };
  return 0;
}

I64 GetChar2(I64 *_scan_code=NULL,Bool echo=TRUE,Bool raw_cursor=FALSE)
{//Waits for non-zero $LK,"ASCII",A="MN:CH_CTRLA"$ key or arrow key.
//Sets $LK,"scan_code",A="FI:::/Doc/CharOverview.DD"$.
  I64 ch1;
  do ch1=GetKey(_scan_code,FALSE,raw_cursor);
  while (!ch1 && !isArrow);
  if (echo)
    "$$PT$$%c$$FG$$",ch1;
  if (isArrow) { return 0; };
  return ch1;
}

U0 TDrawIt(CTask *,CDC *dc)
{
  if (!Blink)
  {
    tt_buf->color=YELLOW;
  }
    else
  {
    tt_buf->color=tt_cur_bg;
  };

  // TODO Cursor
  GrRect(tt_buf,tt_cur_x*8,tt_cur_y*(8+TERM_ROW_SPACING),8,8);        
  GrBlot(dc,0,0,tt_buf);
}


#define DO 0xfd
#define WONT 0xfc
#define WILL 0xfb
#define DONT 0xfe
#define CMD 0xff
#define CMD_ECHO 1
#define CMD_WINDOW_SIZE 31

static  U8  negtmp1[3]={255,251,31};

//TODO make term size changable

//static  U8  negtmp2[9]={255,250,31,0,80,0,24,255,240};

static  U8  negtmp2[9]={255,250,31,0,80,0,60,255,240};


U0 TelnetNeg(CTCPSock  *tcp, U8 *buf, I64 len)
{

  I64 i;



  if (buf[1]==DO && buf[2]==CMD_WINDOW_SIZE) {
    TCPSockSendAll(tcp,negtmp1,3);
    negtmp2[4]=term_cols;

    negtmp2[6]=24;
    TCPSockSendAll(tcp,negtmp2,9);
    return;
  }

  for (i=0;i<len;i++)
  {
    if (buf[i]==DO) {
      buf[i]=WONT;
    }
    else if (buf[i]==WILL)
     buf[i]=DO;
  }
  TCPSockSendAll(tcp,buf,len);
}


U0 TempleTermSession(I64 data)
{

  CTCPSock  *sock = data;
  CDC *tt_buf2=DCNew(term_width,term_height);


  DCFill(tt_buf,tt_cur_bg);
  tt_buf->color=tt_cur_fg;

  I64 rv;

  I64 ansi_pos=0;  
  I64 i=0;
  I64 in_esc=0;
  I64 sp_x=0;
  I64 sp_y=0;
  I64 sp_bg=0;
  I64 sp_fg=0;


  I64 j,k,l;

  I64 ii;
  I64 bold;

  //U8 *rx_buf=CAlloc(1024);
  U8 *rx_buf=CAlloc(ETH_FRAME_SIZE);
  U8 *rx_hex_buf=CAlloc(2*ETH_FRAME_SIZE);


  U8 *ad_seq=CAlloc(6);
  U8 *sr_buf=CAlloc(32);
  CDC *sr_dc;
  U8 cpos_buf[64];
  U8 ansi_buf[64];
  U8 rx_u8[2]; 

  i=0;
  while(i<64) { cpos_buf[i]=0; ansi_buf[i]=0; i++; };

  rx_u8[1]=0;

  StrPrint(ad_seq+1,"[?6c");
  ad_seq[0]=27;

  bold=0;

  U8 ich[2];
  ich[1]=0;

  I64 got, pos;

  //tcp->timeout=0;
  while (TRUE)
  {
    GrRect(tt_buf,tt_cur_x*8,tt_cur_y*(8+TERM_ROW_SPACING),8,8);        

    tt_buf->color=tt_cur_fg;
//TODO
  //  DocPrint(dbgput,"HERE recieve try\n");


    got = TCPSockRx(sock, rx_buf, ETH_FRAME_SIZE);
    tcp->timeout=1000;

    // TODO detect disconnect
    // TODO reduce timeout delay
    /*
    if (got<0)
    {
      //TODO what to do on timeout here?

      DocPrint(dbgput,"HERE got<0, trying to continue!\n");
    }
    */

    if (got>0) {
     rx_hex_buf[0]=0;

    if (TERM_DBG) {
     for(ii=0;ii<got;ii++)
     {
       CatPrint(rx_hex_buf+ii*2,"%02x",rx_buf[ii]); 
     }
     rx_hex_buf[got*2]='\n';
     rx_hex_buf[got*2+1]=0;

     MemCpy(last_rx_hex_buf,rx_hex_buf,2*ETH_FRAME_SIZE);
     DocPrint(dbgput,"Got hex: %s\n",rx_hex_buf);
    }
    }

    // before TERM=ansi I get 0x08 0x20 0x08
    // after I get Got hex: 1b5b441b5b4b


    if (got==3 && rx_buf[0]==0x08 && rx_buf[1]==0x20 && rx_buf[2]==0x80)
    {
          tt_buf->color=tt_cur_bg;
          GrRect(tt_buf,(tt_cur_x--)*8,tt_cur_y*(8+TERM_ROW_SPACING),16,8);        

          tt_buf->color=tt_cur_fg;


      got=0;
    }

    if (got>0)
    {
      pos=0;

      while (pos<got)
      {

        if(pos==0)
        {
          tt_buf->color=tt_cur_bg;
          GrRect(tt_buf,tt_cur_x*8,tt_cur_y*(8+TERM_ROW_SPACING),8,(8+TERM_ROW_SPACING));        
          tt_buf->color=tt_cur_fg;
        };



        if (in_esc==2)
        {
          ansi_buf[ansi_pos]=0;          
          switch(ansi_buf[ansi_pos-1])
          {

            // detect ansi
            case 'n':
              if (StrFind("[6n",ansi_buf))
              {
                cpos_buf[0]=27;
                StrPrint(cpos_buf+1, "[%d;%dR",tt_cur_y,tt_cur_x);
                TCPSockSendStr(tcp,cpos_buf);
              };
              break;
            
            case 'c':
            case 'Z':
              TCPSockSendAll(tcp,ad_seq,5);
              break;

            case 'r':
              StrPrint(sr_buf, ansi_buf);
              StrFirstOcc(sr_buf,"r")[0]=0;
              tt_sr_y2=Str2I64(StrFirstOcc(sr_buf,";")+1);
              StrFirstOcc(sr_buf,";")[0]=0;
              tt_sr_y1=Str2I64(sr_buf+1);               
              break;

            case 'S':
              StrPrint(sr_buf, ansi_buf);
              StrFirstOcc(sr_buf,"S")[0]=0;
              sr_dc=DCNew(term_width,(tt_sr_y2*8)-(tt_sr_y1*8));
              GrBlot(sr_dc,0,-((tt_sr_y1+Str2I64(sr_buf+1))*8),tt_buf);
              GrBlot(tt_buf,0,(tt_sr_y1*8),sr_dc);
              DCDel(sr_dc);
              break;

            case 'T':
              StrPrint(sr_buf, ansi_buf);
              StrFirstOcc(sr_buf,"S")[0]=0;
              sr_dc=DCNew(term_width,(tt_sr_y2*8)-(tt_sr_y1*8));
              GrBlot(sr_dc,0,-((tt_sr_y1-Str2I64(sr_buf+1))*8),tt_buf);
              GrBlot(tt_buf,0,(tt_sr_y1*8),sr_dc);
              DCDel(sr_dc);
              break;

            case 'm':           

              if (StrFind(";7m",ansi_buf)) 
                { tt_cur_fg=rv; tt_cur_fg=tt_cur_bg; tt_cur_bg=rv; 
                  if (tt_cur_bg>7) { tt_cur_bg-=8; };
                };
              if (StrFind("[7m",ansi_buf)) 
                { tt_cur_fg=rv; tt_cur_fg=tt_cur_bg; tt_cur_bg=rv;
                  if (tt_cur_bg>7) { tt_cur_bg-=8; };
                };
              if (StrFind("[7;",ansi_buf)) 
                { tt_cur_fg=rv; tt_cur_fg=tt_cur_bg; tt_cur_bg=rv;
                  if (tt_cur_bg>7) { tt_cur_bg-=8; };
                };
              if (StrFind(";7;",ansi_buf)) 
                { tt_cur_fg=rv; tt_cur_fg=tt_cur_bg; tt_cur_bg=rv;
                  if (tt_cur_bg>7) { tt_cur_bg-=8; };
                };

              if (StrFind(";1m",ansi_buf)) { bold=8; };
              if (StrFind("[1m",ansi_buf)) { bold=8; };
              if (StrFind("[1;",ansi_buf)) { bold=8; };
              if (StrFind(";1;",ansi_buf)) { bold=8; };

              if (StrFind(";01m",ansi_buf)) { bold=8; };
              if (StrFind("[01;",ansi_buf)) { bold=8; };
              if (StrFind(";01;",ansi_buf)) { bold=8; };

              if (StrFind("[0m",ansi_buf)) { bold=0; };
              if (StrFind(";0m",ansi_buf)) { bold=0; };
              if (StrFind("[0;",ansi_buf)) { bold=0; };
              if (StrFind(";0;",ansi_buf)) { bold=0; };

              if (StrFind(";00m",ansi_buf)) { bold=0; };
              if (StrFind("[00;",ansi_buf)) { bold=0; };
              if (StrFind(";00;",ansi_buf)) { bold=0; };

              if (StrFind("30",ansi_buf)) { tt_cur_fg=bold+0; };
              if (StrFind("31",ansi_buf)) { tt_cur_fg=bold+4; };
              if (StrFind("32",ansi_buf)) { tt_cur_fg=bold+2; };
              if (StrFind("33",ansi_buf)) { tt_cur_fg=bold+6; };
              if (StrFind("34",ansi_buf)) { tt_cur_fg=bold+1; };
              if (StrFind("35",ansi_buf)) { tt_cur_fg=bold+5; };
              if (StrFind("36",ansi_buf)) { tt_cur_fg=bold+3; };
              if (StrFind("37",ansi_buf)) { tt_cur_fg=bold+7; };


              if (StrFind("39",ansi_buf)) { tt_cur_fg=WHITE; };


              if (StrFind("40",ansi_buf)) { tt_cur_bg=0; };
              if (StrFind("41",ansi_buf)) { tt_cur_bg=4; };
              if (StrFind("42",ansi_buf)) { tt_cur_bg=2; };
              if (StrFind("43",ansi_buf)) { tt_cur_bg=6; };
              if (StrFind("44",ansi_buf)) { tt_cur_bg=1; };
              if (StrFind("45",ansi_buf)) { tt_cur_bg=5; };
              if (StrFind("46",ansi_buf)) { tt_cur_bg=3; };
              if (StrFind("47",ansi_buf)) { tt_cur_bg=7; };
              if (StrFind("49",ansi_buf)) { tt_cur_bg=BLACK; };

/*
              if (StrFind("90",ansi_buf)) { tt_cur_fg=bold+0; };
              if (StrFind("91",ansi_buf)) { tt_cur_fg=bold+4; };
              if (StrFind("92",ansi_buf)) { tt_cur_fg=bold+2; };
              if (StrFind("93",ansi_buf)) { tt_cur_fg=bold+6; };
              if (StrFind("94",ansi_buf)) { tt_cur_fg=bold+1; };
              if (StrFind("95",ansi_buf)) { tt_cur_fg=bold+5; };
              if (StrFind("96",ansi_buf)) { tt_cur_fg=bold+3; };
              if (StrFind("97",ansi_buf)) { tt_cur_fg=bold+7; };

              if (StrFind("100",ansi_buf)) { tt_cur_bg=bold+0; };
              if (StrFind("101",ansi_buf)) { tt_cur_bg=bold+4; };
              if (StrFind("102",ansi_buf)) { tt_cur_bg=bold+2; };
              if (StrFind("103",ansi_buf)) { tt_cur_bg=bold+6; };
              if (StrFind("104",ansi_buf)) { tt_cur_bg=bold+1; };
              if (StrFind("105",ansi_buf)) { tt_cur_bg=bold+5; };
              if (StrFind("106",ansi_buf)) { tt_cur_bg=bold+3; };
              if (StrFind("107",ansi_buf)) { tt_cur_bg=bold+7; };
*/
              if (StrFind("90",ansi_buf)) { tt_cur_fg=8+0; };
              if (StrFind("91",ansi_buf)) { tt_cur_fg=8+4; };
              if (StrFind("92",ansi_buf)) { tt_cur_fg=8+2; };
              if (StrFind("93",ansi_buf)) { tt_cur_fg=8+6; };
              if (StrFind("94",ansi_buf)) { tt_cur_fg=8+1; };
              if (StrFind("95",ansi_buf)) { tt_cur_fg=8+5; };
              if (StrFind("96",ansi_buf)) { tt_cur_fg=8+3; };
              if (StrFind("97",ansi_buf)) { tt_cur_fg=8+7; };

              if (StrFind("100",ansi_buf)) { tt_cur_bg=8+0; };
              if (StrFind("101",ansi_buf)) { tt_cur_bg=8+4; };
              if (StrFind("102",ansi_buf)) { tt_cur_bg=8+2; };
              if (StrFind("103",ansi_buf)) { tt_cur_bg=8+6; };
              if (StrFind("104",ansi_buf)) { tt_cur_bg=8+1; };
              if (StrFind("105",ansi_buf)) { tt_cur_bg=8+5; };
              if (StrFind("106",ansi_buf)) { tt_cur_bg=8+3; };
              if (StrFind("107",ansi_buf)) { tt_cur_bg=8+7; };



              if (StrFind("[38;5;8m",ansi_buf)) { tt_cur_fg=8+0; };
              if (StrFind("[38;5;9m",ansi_buf)) { tt_cur_fg=8+4; };
              if (StrFind("[38;5;10m",ansi_buf)) { tt_cur_fg=8+2; };
              if (StrFind("[38;5;11m",ansi_buf)) { tt_cur_fg=8+6; };
              if (StrFind("[38;5;12m",ansi_buf)) { tt_cur_fg=8+1; };
              if (StrFind("[38;5;13m",ansi_buf)) { tt_cur_fg=8+5; };
              if (StrFind("[38;5;14m",ansi_buf)) { tt_cur_fg=8+3; };
              if (StrFind("[38;5;15m",ansi_buf)) { tt_cur_fg=8+7; };



              if (StrFind("[48;5;8m",ansi_buf)) { tt_cur_bg=8+0; };
              if (StrFind("[48;5;9m",ansi_buf)) { tt_cur_bg=8+4; };
              if (StrFind("[48;5;10m",ansi_buf)) { tt_cur_bg=8+2; };
              if (StrFind("[48;5;11m",ansi_buf)) { tt_cur_bg=8+6; };
              if (StrFind("[48;5;12m",ansi_buf)) { tt_cur_bg=8+1; };
              if (StrFind("[48;5;13m",ansi_buf)) { tt_cur_bg=8+5; };
              if (StrFind("[48;5;14m",ansi_buf)) { tt_cur_bg=8+3; };
              if (StrFind("[48;5;15m",ansi_buf)) { tt_cur_bg=8+7; };



//TODO check
              if (StrFind("[0;10;1m",ansi_buf)) { tt_cur_bg=BLACK; tt_cur_fg=WHITE; bold=8;};
              if (StrFind("[0;10m",ansi_buf)) { tt_cur_bg=BLACK; tt_cur_fg=WHITE; };
              if (StrFind("[0m",ansi_buf)) { tt_cur_bg=BLACK; tt_cur_fg=WHITE; };
              if (StrFind("[m",ansi_buf)) { tt_cur_bg=BLACK; tt_cur_fg=WHITE; };

  // if (StrFind("[0m",ansi_buf)) { bold=0; };

              if (StrFind("[7m",ansi_buf)) 
                { tt_cur_fg=rv; tt_cur_fg=tt_cur_bg; tt_cur_bg=rv; 
                  if (tt_cur_bg>7) { tt_cur_bg-=8; };
                };

              break;

            case '@':
              ansi_buf[ansi_pos-1]=0;
              l=Str2I64(ansi_buf+1);
              if (l==0 && ansi_buf[1]==0) l=1;
              DocPrint(dbgput,"TODO Case @ insert %d blanks\n",l);
              break;
            case 'A':
              ansi_buf[ansi_pos-1]=0;
              l=Str2I64(ansi_buf+1);
              if (l==0 && ansi_buf[1]==0) l=1;
              tt_cur_y-=l;
              if (tt_cur_y<0) { tt_cur_y=0; };
              break;

            case 'B':
              ansi_buf[ansi_pos-1]=0;
              l=Str2I64(ansi_buf+1);
              if (l==0 && ansi_buf[1]==0) l=1;
              tt_cur_y+=l;
              if (tt_cur_y>=(Fs->parent_task->win_height-1)) { 
                tt_cur_y=Fs->parent_task->win_height-1;
              };
              break;

            case 'C':
              ansi_buf[ansi_pos-1]=0;
              l=Str2I64(ansi_buf+1);
              if (l==0 && ansi_buf[1]==0) l=1;
              tt_cur_x+=l;
              if (tt_cur_x>=(Fs->parent_task->win_width-1)) { 
                tt_cur_x=Fs->parent_task->win_width-1;
              };
              break;

            case 'D':
              ansi_buf[ansi_pos-1]=0;
              l=Str2I64(ansi_buf+1);
              if (l==0 && ansi_buf[1]==0) l=1;
              tt_cur_x-=l;
              if (tt_cur_x<0) { tt_cur_x=0; };
              break;
            //TODO cases F/G, 6n, others?          
            // 74 64 (64=d, 74=t)




            case 'd':
              ansi_buf[ansi_pos-1]=0;
              l=Str2I64(ansi_buf+1);
              if (l==0 && ansi_buf[1]==0) {
              DocPrint(dbgput,"Here ansi esc[d expected but did not get row?\n");
              }
              else {
              tt_cur_y=l;
              }
              break;

            case 'G':
              ansi_buf[ansi_pos-1]=0;
              l=Str2I64(ansi_buf+1);
              if (l==0 && ansi_buf[1]==0) {
              DocPrint(dbgput,"Here ansi esc[G expected but did not get col?\n");
              }
              else {
              tt_cur_x=l;
              }
              if (tt_cur_x<0) { tt_cur_x=0; };
              break;


            case 'H':
            case 'f':
              j=1;k=0;
              while (j<64)
              {
                if (ansi_buf[j]==';') { ansi_buf[j]=0; k=j+1; j=64; }; 
                j++;
              };
              if (k>0)
              {
                ansi_buf[ansi_pos-1]=0;
                tt_cur_x=Str2I64(ansi_buf+k);
                tt_cur_y=Str2I64(ansi_buf+1);
/*
                tt_cur_fg=WHITE;
                tt_cur_bg=BLACK;
*/
              };        
              break;
            
            case 'J':
              if (ansi_buf[1]=='0' || ansi_buf[1]=='J')
              {
                tt_buf->color=tt_cur_bg;
                GrRect(tt_buf,0,tt_cur_y*(8+TERM_ROW_SPACING),term_width,term_height);
                tt_buf->color=tt_cur_fg;
              };
              if (ansi_buf[1]=='1')
              {
                tt_buf->color=tt_cur_bg;
                GrRect(tt_buf,0,-term_height+(tt_cur_y*(8+TERM_ROW_SPACING)),term_width,term_height);
                tt_buf->color=tt_cur_fg;
              };
              if (ansi_buf[1]=='2')
              {
                DCFill(tt_buf,tt_cur_bg);
                tt_cur_x=0;
                tt_cur_y=0;
              };
              if (ansi_buf[1]=='3')
              {
                DCFill(tt_buf,tt_cur_bg);
                tt_cur_x=0;
                tt_cur_y=0;
              };
              break;

            case 's':
              sp_x=tt_cur_x;
              sp_y=tt_cur_y;
              sp_bg=tt_cur_bg;
              sp_fg=tt_cur_fg;
              break;

            case 'u':
              tt_cur_x=sp_x;
              tt_cur_y=sp_y;
              tt_cur_bg=sp_bg;
              tt_cur_fg=sp_fg;
              break;

            case 'K':
              if(ansi_buf[1]=='0' || ansi_buf[1]=='K')
              {
                tt_buf->color=tt_cur_bg;
                GrRect(tt_buf,tt_cur_x*8,tt_cur_y*(8+TERM_ROW_SPACING),term_width,8+TERM_ROW_SPACING);
                tt_buf->color=tt_cur_fg;
              };
              if(ansi_buf[1]=='1')
              {
                tt_buf->color=tt_cur_bg;
                GrRect(tt_buf,-term_width+(tt_cur_x*8),tt_cur_y*(8+TERM_ROW_SPACING),term_width,8+TERM_ROW_SPACING);
                tt_buf->color=tt_cur_fg;
              };
              if(ansi_buf[1]=='2')
              {
                tt_buf->color=tt_cur_bg;
                GrRect(tt_buf,0,tt_cur_y*(8+TERM_ROW_SPACING),term_width,8+TERM_ROW_SPACING);
                tt_buf->color=tt_cur_fg;
              };
              break;

            // line wrapping doesn't seem to matter...
            case 'h':
              break;
            case 'l':
              break;

            default:
              StrPrint(sr_buf, "Missing Code: %02X\n", ansi_buf[ansi_pos-1]);
              AdamLog(sr_buf);
              DocPrint(dbgput,sr_buf);
              DocPrint(dbgput,rx_hex_buf);
              break;
          };

          in_esc=0;
        };

        if (in_esc==1)
        {
          ansi_buf[ansi_pos]=rx_buf[pos];
          switch (rx_buf[pos])
          {
            case 'a'...'z':
            case 'A'...'Z':
              in_esc++;
              break;
            case 0x27:
              DocPrint(dbgput,"got another esc? ansi_buf start =%c%c\n",ansi_buf[ansi_pos],ansi_buf[ansi_pos-1]);
            default:
              break;
          };
          ansi_pos++;
        }


        if (pos==0 && rx_buf[0]==255)
        {
           TelnetNeg(tcp,rx_buf,got);
           break;
        }

        if (in_esc==0)
        {      
          switch (rx_buf[pos])
          {
            case 7:
              Snd(62);
              Sleep(120);
              SndRst;
              break;
            case 8:
              tt_cur_x--;
              if(tt_cur_x<0) { tt_cur_x=0; };
              break;
            case 10:

              // BUG, do not change back!
              // change back to default attrs when we line feed?
/*
              tt_cur_bg=BLACK;
              tt_cur_fg=WHITE;
*/

              tt_cur_y++;
              break;
            case 13:
              tt_cur_x=0;
              break;
            case 27:
              ansi_pos=0;
              in_esc++;
              break;
            case 31...255:
              rx_u8[0]=rx_buf[pos];
              tt_buf->color=tt_cur_bg;
              GrRect(tt_buf,tt_cur_x*8,tt_cur_y*(8+TERM_ROW_SPACING),8,8);

              tt_buf->color=tt_cur_fg;
              GrPrint(tt_buf,tt_cur_x*8,tt_cur_y*(8+TERM_ROW_SPACING),rx_u8);
              tt_cur_x++;
              if(tt_cur_x==Fs->parent_task->win_width)
              {
                tt_cur_x-=Fs->parent_task->win_width;
                tt_cur_bg=BLACK;
                tt_cur_fg=WHITE;

                tt_cur_y++;
              };            
              break;
            default:
              break;
          };

        };


        // Y-scroll the frame buffer
        //if (tt_cur_y==Fs->parent_task->win_height)
// TODO 24 lines
if (tt_cur_y==24)
        {
          DCFill(tt_buf2,TRANSPARENT);
          GrBlot(tt_buf2,0,-8-TERM_ROW_SPACING,tt_buf);
          DCFill(tt_buf,tt_cur_bg);
          GrBlot(tt_buf,0,0,tt_buf2);
          tt_cur_y--;          
        };
        
      
      pos++;

      };       
      Sleep(2);
    };

    Sleep(2);
  };
  Free(ad_seq);
  Free(sr_buf);
  PostMsg(Fs->parent_task,MSG_KEY_DOWN_UP,REMOTE_Q,0);
}

I64 TempleTermConnect(U8 *host, I64 port=23)
{


  tt_cur_x=0;
  tt_cur_y=0;
  tt_cur_bg=BLACK;
  tt_cur_fg=WHITE;
  tt_cur_int=0;
  DCFill(tt_buf,tt_cur_bg);

  U8 se_u8[4];
  U8 sx_u8[2];

  I64 key;


  se_u8[0]=27;
  se_u8[1]='[';
  se_u8[3]=0;
  sx_u8[1]=0;

  if(StrCmp(host,"")==0)
    {
    "Must specify hostname or IP address.\n";
    return -1;
  };

  //I64 sock = create_connection(host, port);
  while (PresToNet(AF_INET, host, &ip_addr) == -1)
    {
    "\nERROR: Bad IP entered. Retry.\n";
    return -1;
  }


  sock_addr.port          = EndianU16(port);
  sock_addr.family            = AF_INET;
  sock_addr.addr.addr   = ip_addr.addr;
  tcp->timeout = TCP_TIMEOUT;


  if (TCPSockConnect(tcp, &sock_addr) != 0)
    {
    "\nFailed to connect to server.\n";
    TCPSockClose(tcp);
    return -1;
  }

  //TODO  
  if (1)
    {
    MenuPush("File{"
	  "  Disconnect(,PROMPT_Q);"
	  "}");

    Fs->draw_it=&TDrawIt;
    CTask *session = Spawn(&TempleTermSession,tcp,"TempleTermSession",,Fs);
    while (TRUE)
      {
      sx_u8[0]=0;
      key=GetChar2(,FALSE);

      //TODO
      if (1)
        {  

        /*
if ((kbd.scan_code & 0xFFFF) == 2070)
{
sendStr(sock, conn_ents[res].user, 0);
key=0;
};

// Send password
if ((kbd.scan_code & 0xFFFF) == 2073)
{
sendStr(sock, conn_ents[res].pass, 0);
key=0;
};

*/

        // Support for default shortcut keys
        // toggle border (alt-b)
        if ((kbd.scan_code & 0xFFFF) == 2096)
	  {
	  WinBorder(!WinBorder);
	  key=0;
        };

        // maximize, no border (alt-m)
        if ((kbd.scan_code & 0xFFFF) == 2098)
	  {
	  WinBorder;
	  WinMax;
	  key=0;
        };

        // win tile horz (alt-h)
        if ((kbd.scan_code & 0xFFFF) == 2083)
	  {
	  WinTileHorz;
	  key=0;
        };

        // win tile vert (alt-v)
        if ((kbd.scan_code & 0xFFFF) == 2095)
	  {
	  WinTileVert;
	  key=0;
        };


        // change task (alt-q)
        if ((kbd.scan_code & 0xFFFF) == 2064)
        {
           break;
        }


        // change task
        if ((kbd.scan_code & 0xFFFF) == 2063)
	  {
	  LBts(sys_ctrl_alt_flags,CTRL_ALT_TAB);
	  key=0;
        };

        if (key==PROMPT_Q)
	  {
	  ProgressBarsRst;
	  if (PopUpCancelOk("OK to disconnect?")==1)
	    {
	    break;
	  };
        };

        if (key==REMOTE_Q) { break; };
        if (key==10) { key=13; };

        if (key==0)
	  {
	  key=kbd.scan_code & 0xFF;

	  if (key==SC_F12) { 
	    ProgressBarsRst;
	    if (PopUpCancelOk("OK to disconnect?")==1)
	      {
	      break;
	    };
	  };
//TODO
      //    DocPrint(dbgput,"Here send key2 %02x\n",key);


	  if (key==72)
	    {
	    se_u8[2]='A';
	    TCPSockSendAll(tcp, se_u8, 3);
	  };

	  if (key==80)
	    {
	    se_u8[2]='B';
	    TCPSockSendAll(tcp, se_u8, 3);
	  };

	  if (key==77)
	    {
	    se_u8[2]='C';
	    TCPSockSendAll(tcp, se_u8, 3);
	  };

	  if (key==75)
	    {
	    se_u8[2]='D';
	    TCPSockSendAll(tcp, se_u8, 3);
	  };
	  key=0;
        };

        if (key>0) { sx_u8[0]=key; };

        if (sx_u8[0]>0)
	  {    
 //TODO
       //   DocPrint(dbgput,"Here send key1 %02x\n",sx_u8[0]);

	  TCPSockSendAll(tcp, sx_u8, 1);
        };       
      };
      last_sc=kbd.scan_code;

    };

    Kill(session);
    TCPSockClose(tcp);
    Fs->draw_it=NULL;
    DCFill;
    SndRst;
    MenuPop;
    return 0;
  }
  else
    {
    SndRst;
    PopUpOk("Connection timed out.");
  };    
}

U0 Telnet(I64 width=GR_WIDTH, I64 height=GR_HEIGHT)
{
  term_width=width - 2*FONT_WIDTH;
  term_height=height;

  term_rows=term_height/(FONT_HEIGHT+TERM_ROW_SPACING);
  term_cols=term_width/FONT_WIDTH - 2;

  WinHorz(1,width/FONT_WIDTH-1);
  WinVert(Fs->win_top,Fs->win_top+24*2-1);

  res=0;
  tt_buf=DCNew(term_width,term_height);

  if (FileFind(TT_CFG_PATH "/" TT_CFG_FILE))
  {
    conn_ents=FileRead(TT_CFG_PATH "/" TT_CFG_FILE);
  }
  else
  {
    conn_ents=CAlloc(sizeof(TTConnEnt)*TT_MAX_ENTS);
  };

  conn_rc_ents=CAlloc(sizeof(TTConnEnt)*TT_MAX_ENTS);

  add_form=CAlloc(sizeof(TTConnEntForm));
  edit_form=CAlloc(sizeof(TTConnEntForm));

  conn_list=CAlloc(sizeof(TTConnEnt)*TT_MAX_ENTS);
  conn_edlist=CAlloc(sizeof(TTConnEnt)*TT_MAX_ENTS);

  I64 idx=0;
  I64 dres=0;
  I64 eres=0;

  ConnEntsRecalc;
  while (res!=-1)
  {      
    res = PopUpBookmarkLst(conn_list);
    if (res!=-1 && res<(conn_idx))
    {
      TempleTermConnect(conn_ents[res].host, conn_ents[res].port);
      break;
    };

    if (res==(conn_idx))
    {
      idx = res;
      StrPrint(add_form->name,"");
      StrPrint(add_form->host,"");
      add_form->port=23;
      StrPrint(add_form->user,"");
      StrPrint(add_form->pass,"");
      if(DocForm(add_form))
      {
        // add new entry

        if(StrLen(add_form->name)>0)
        {
          StrPrint(conn_ents[idx].name, add_form->name);
          StrPrint(conn_ents[idx].host, add_form->host);
          conn_ents[idx].port=add_form->port;
          StrPrint(conn_ents[idx].user, add_form->user);
          StrPrint(conn_ents[idx].pass, add_form->pass);
          ConnEntsRecalc;
        };     
      };
    };

    if (res==(conn_idx+1))
    {
      idx = res;
      dres = PopUpDelLst(conn_edlist);
      if (dres!=-1)
      {
        if(PopUpCancelOk("Ok to DELETE this entry?"))
        {
          StrPrint(conn_ents[dres].name, "");
          StrPrint(conn_ents[dres].host, "");
          conn_ents[dres].port=0;
          StrPrint(conn_ents[dres].user, "");
          StrPrint(conn_ents[dres].pass, "");
        };
      };
      ConnEntsRecalc;
    };

    if (res==(conn_idx+2))
    {
      idx = res;
      eres = PopUpEditLst(conn_edlist);
      if (eres!=-1)
      {
        StrPrint(edit_form->name,conn_ents[eres].name);
        StrPrint(edit_form->host,conn_ents[eres].host);
        edit_form->port=conn_ents[eres].port;
        StrPrint(edit_form->user,conn_ents[eres].user);
        StrPrint(edit_form->pass,conn_ents[eres].pass);

        if(DocForm(edit_form))
        {
          if(StrLen(edit_form->name)>0)
          {
            StrPrint(conn_ents[eres].name, edit_form->name);
            StrPrint(conn_ents[eres].host, edit_form->host);
            conn_ents[eres].port=edit_form->port;
            StrPrint(conn_ents[eres].user, edit_form->user);
            StrPrint(conn_ents[eres].pass, edit_form->pass);
          };     
        };
      };
      ConnEntsRecalc;
    };

  };
  Bool old_silent=Silent;
  DirMks(TT_CFG_PATH);
  Silent(old_silent);
  FileWrite(TT_CFG_PATH "/" TT_CFG_FILE,conn_ents,(sizeof(TTConnEnt)*TT_MAX_ENTS));
  DCDel(tt_buf);
  Free(conn_ents);
  Free(conn_rc_ents);
  Free(add_form);
  Free(edit_form);
  Free(conn_list);
  Free(conn_edlist);  

if (TERM_DBG) {
  "Last sc & 0xffff was: %d\n",last_sc&0xffff;
  "Last hex buf %s\n",last_rx_hex_buf;
}
}
