library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity sio is
   port 
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic; 
      
      linkCableOn          : in  std_logic;
      
      sio_TXD              : out std_logic := '1';
      sio_RXD              : in  std_logic;
      sio_DTR              : out std_logic := '0';
      sio_DSR              : in  std_logic;
      sio_RTS              : out std_logic := '0';
      sio_CTS              : in  std_logic;
      
      irqRequest           : out std_logic := '0';
      
      bus_addr             : in  unsigned(3 downto 0); 
      bus_reqsize          : in  unsigned(1 downto 0);
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_writeMask        : in  std_logic_vector(3 downto 0);
      bus_dataRead         : out std_logic_vector(31 downto 0);
      
      loading_savestate    : in  std_logic;
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(31 downto 0);
      SS_Adr               : in  unsigned(2 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of sio is

   -- registers
   signal SIO_MODE         : std_logic_vector( 7 downto 0) := x"00";
   signal SIO_CTRL         : std_logic_vector(15 downto 0) := x"0000";
   signal SIO_BAUD         : std_logic_vector(15 downto 0) := x"00DC";
   signal SIO_MISC         : std_logic_vector(15 downto 0) := x"0000";
   
   -- STAT flags
   signal statParityError  : std_logic; -- STAT.3
   signal statRxOverrun    : std_logic; -- STAT.4
   signal statRxBadStop    : std_logic; -- STAT.5
   signal statRxInvLevel   : std_logic; -- STAT.6
   signal statIrq          : std_logic; -- STAT.9
   
   -- CTRL aliases
   signal ctrlTXEN         : std_logic;
   signal ctrlDTR          : std_logic;
   signal ctrlRXEN         : std_logic;
   signal ctrlTXINV        : std_logic;
   signal ctrlRTS          : std_logic;
   signal ctrlRXIMODE      : std_logic_vector(1 downto 0);
   signal ctrlTXIEN        : std_logic;
   signal ctrlRXIEN        : std_logic;
   signal ctrlDSRIEN       : std_logic;
   
   -- input sync
   signal RXD_1, RXD_s     : std_logic := '1';
   signal DSR_1, DSR_s     : std_logic := '0';
   signal CTS_1, CTS_s     : std_logic := '1';
   
   -- input levels
   signal dsrLevel         : std_logic; -- effective DSR (STAT.7)
   signal ctsLevel         : std_logic; -- effective CTS (STAT.8)
   signal rxdLevel         : std_logic; -- effective RXD
   signal rxdLevel_1       : std_logic := '1'; -- previous RXD
   
   -- baud timing
   signal baudTimer        : unsigned(20 downto 0) := (others => '0'); -- STAT.11-31
   signal cyclesPerBit     : unsigned(22 downto 0) := to_unsigned(2, 23);
   signal cyclesHalfBit    : unsigned(22 downto 0) := to_unsigned(1, 23);
   
   -- TX engine
   signal txBuffer         : std_logic_vector(7 downto 0) := (others => '0');
   signal txBufferFilled   : std_logic := '0';
   signal txEnLatched      : std_logic := '0';
   signal txShift          : std_logic_vector(7 downto 0) := (others => '0');
   signal txRunning        : std_logic := '0';
   signal txStartSeen      : std_logic := '1'; -- start bit completed
   signal txBitCnt         : unsigned(3 downto 0) := (others => '0');
   signal txCycleCnt       : unsigned(22 downto 0) := (others => '0');
   signal txParityCalc     : std_logic := '0';
   type ttxstate is (TXIDLE, TXSTART, TXDATA, TXPARITY, TXSTOP);
   signal txState          : ttxstate := TXIDLE;
   
   -- RX engine
   type trxstate is (RXIDLE, RXSTART, RXDATA, RXPARITY, RXSTOP);
   signal rxState          : trxstate := RXIDLE;
   signal rxShift          : std_logic_vector(7 downto 0) := (others => '0');
   signal rxBitCnt         : unsigned(3 downto 0) := (others => '0');
   signal rxCycleCnt       : unsigned(22 downto 0) := (others => '0');
   signal rxParityCalc     : std_logic := '0';

   -- RX FIFO
   constant FIFODEPTH      : integer := 16;
   type tfifo is array(0 to FIFODEPTH-1) of std_logic_vector(7 downto 0);
   signal rxFifo           : tfifo := (others => (others => '0'));
   signal rxFifoCnt        : unsigned(5 downto 0) := (others => '0');
   
   signal charLenBits      : unsigned(3 downto 0) := to_unsigned(8, 4);
   
   -- TX/DSR/RX IRQ conditions
   signal irqCondTX        : std_logic;
   signal irqCondDSR       : std_logic;
   signal irqCondRX        : std_logic;
   
   -- internal TX status
   signal statTxNotFull    : std_logic;
   signal statTxIdle       : std_logic;

   -- CPU visible TX status
   signal statTxNotFullCPU : std_logic;
   signal statTxIdleCPU    : std_logic;
 
   signal ctrlRXEN_1       : std_logic := '0';
   signal baudReloadReq    : std_logic := '0';

   -- savestates
   type t_ssarray is array(0 to 7) of std_logic_vector(31 downto 0); 
   signal ss_out : t_ssarray := (others => (others => '0')); 
  
begin 

   -- CTRL aliases
   ctrlTXEN    <= SIO_CTRL(0);
   ctrlDTR     <= SIO_CTRL(1);
   ctrlRXEN    <= SIO_CTRL(2);
   ctrlTXINV   <= SIO_CTRL(3);
   ctrlRTS     <= SIO_CTRL(5);
   ctrlRXIMODE <= SIO_CTRL(9 downto 8);
   ctrlTXIEN   <= SIO_CTRL(10);
   ctrlRXIEN   <= SIO_CTRL(11);
   ctrlDSRIEN  <= SIO_CTRL(12);

   -- effective link inputs
   -- cable off: DSR=0, CTS/RXD=1
   dsrLevel <= DSR_s when linkCableOn = '1' else '0';
   ctsLevel <= CTS_s when linkCableOn = '1' else '1';
   rxdLevel <= RXD_s when linkCableOn = '1' else '1';
   
   -- output pins
   sio_DTR  <= ctrlDTR;
   sio_RTS  <= ctrlRTS;
   
   -- character length: 0=5, 1=6, 2=7, 3=8 bits
   charLenBits <= to_unsigned(5, 4) + resize(unsigned(SIO_MODE(3 downto 2)), 4);
   
   -- bit timing
   process (SIO_BAUD, SIO_MODE)
      variable reload : unsigned(15 downto 0);
      variable cyc    : unsigned(22 downto 0);
      variable factor : unsigned(22 downto 0);
   begin
      reload := unsigned(SIO_BAUD);
      if (reload = 0) then
         reload := to_unsigned(1, 16);
      end if;
      -- psx-spx baud formula with tuned link timing
      case (SIO_MODE(1 downto 0)) is
         when "10"   => cyc := (resize(reload, 23) sll 4) + (resize(reload, 23) sll 3)
                             + (resize(reload, 23) sll 1);
                        factor := to_unsigned( 26, 23);   -- MUL16 x1.625
         when "11"   => cyc := (resize(reload, 23) sll 6) + (resize(reload, 23) sll 5)
                             + (resize(reload, 23) sll 3);
                        factor := to_unsigned(104, 23);   -- MUL64 x1.625
         when others => cyc := (resize(reload, 23) sll 1) - (resize(reload, 23) srl 2);
                        factor := to_unsigned(  2, 23);   -- MUL1  x1.625
      end case;
      cyc(0) := '0';           -- AND NOT 1
      if (cyc < factor) then
         cyc := factor;
      end if;
      if (cyc < 2) then 
         cyc := to_unsigned(2, 23); 
      end if;
      cyclesPerBit  <= cyc;
      cyclesHalfBit <= '0' & cyc(22 downto 1);
   end process;
   
   -- Internal TX status
   statTxNotFull <= (not txBufferFilled) and txStartSeen;
   statTxIdle    <= (not txBufferFilled) and (not txRunning) and txStartSeen;

   -- CPU-visible TX status
   statTxNotFullCPU <= statTxNotFull and ctsLevel;
   statTxIdleCPU    <= statTxIdle    and ctsLevel and ctrlTXEN;
   
   -- TX IRQ condition
   irqCondTX  <= ctrlTXIEN and (statTxNotFullCPU or statTxIdleCPU);
   irqCondDSR <= ctrlDSRIEN and dsrLevel;
   -- RX IRQ threshold: 1/2/4/8 bytes
   irqCondRX  <= ctrlRXIEN when
                 (ctrlRXIMODE = "00" and rxFifoCnt >= 1) or
                 (ctrlRXIMODE = "01" and rxFifoCnt >= 2) or
                 (ctrlRXIMODE = "10" and rxFifoCnt >= 4) or
                 (ctrlRXIMODE = "11" and rxFifoCnt >= 8)
                 else '0';

   -- sticky SIO IRQ output
   irqRequest <= statIrq;
   

   ss_out(0)(3)            <= statParityError;
   ss_out(0)(4)            <= statRxOverrun;
   ss_out(0)(5)            <= statRxBadStop;
   ss_out(0)(9)            <= statIrq;
   ss_out(1)( 7 downto 0)  <= SIO_MODE;
   ss_out(2)(15 downto 0)  <= SIO_CTRL;
   ss_out(3)(15 downto 0)  <= SIO_BAUD;
   ss_out(4)(15 downto 0)  <= SIO_MISC;

   process (clk1x)
      variable pushByte  : std_logic;
      variable pushData  : std_logic_vector(7 downto 0);
      variable startTX   : std_logic;
      variable fifoCnt_v : unsigned(5 downto 0);
      variable txWrite_v : std_logic;
      variable irqAck_v  : std_logic;
      variable irqEvent  : std_logic;   -- TX event
   begin
      if rising_edge(clk1x) then
      
         -- 2-stage synchronizer
         RXD_1 <= sio_RXD; RXD_s <= RXD_1;
         rxdLevel_1 <= rxdLevel;

         DSR_1 <= sio_DSR; DSR_s <= DSR_1;
         CTS_1 <= sio_CTS; CTS_s <= CTS_1;
      
         if (reset = '1' and loading_savestate = '0') then
         
            SIO_MODE        <= x"00";
            SIO_CTRL        <= x"0000";
            SIO_BAUD        <= x"00DC";
            SIO_MISC        <= x"0000";
            statParityError <= '0';
            statRxOverrun   <= '0';
            statRxBadStop   <= '0';
            statRxInvLevel  <= '0';
            statIrq         <= '0';
            txBufferFilled  <= '0';
            txEnLatched     <= '0';
            txRunning       <= '0';
            txStartSeen     <= '1';
            txState         <= TXIDLE;
            sio_TXD         <= '1';
            rxState         <= RXIDLE;
            rxFifoCnt       <= (others => '0');
            baudTimer       <= (others => '0');
            
         elsif (SS_wren = '1') then
         
            if (to_integer(SS_Adr) = 0) then 
               statParityError <= SS_DataWrite(3);
               statRxOverrun   <= SS_DataWrite(4);
               statRxBadStop   <= SS_DataWrite(5);
               statIrq         <= SS_DataWrite(9);
            end if;
            if (to_integer(SS_Adr) = 1) then SIO_MODE <= SS_DataWrite( 7 downto 0); end if;
            if (to_integer(SS_Adr) = 2) then SIO_CTRL <= SS_DataWrite(15 downto 0); end if;
            if (to_integer(SS_Adr) = 3) then SIO_BAUD <= SS_DataWrite(15 downto 0); end if;
            if (to_integer(SS_Adr) = 4) then SIO_MISC <= SS_DataWrite(15 downto 0); end if;
            -- serial engines restart clean after loading a savestate
            txBufferFilled <= '0';
            txRunning      <= '0';
            txStartSeen    <= '1';
            txState        <= TXIDLE;
            sio_TXD        <= '1';
            rxState        <= RXIDLE;
            rxFifoCnt      <= (others => '0');
            
         else
         
            -- TX/RX use free-running clk1x; CPU bus is gated by ce
            pushByte  := '0';
            pushData  := (others => '0');
            txWrite_v := '0';
            irqAck_v  := '0';
            irqEvent  := '0';
            fifoCnt_v := rxFifoCnt;
         
            -- free-running baud timer (STAT.11-31)
            if (baudReloadReq = '1' or baudTimer = 0) then
               baudTimer     <= resize(cyclesHalfBit, 21);
               baudReloadReq <= '0';
            else
               baudTimer <= baudTimer - 1;
            end if;

            -- bus access
            if (ce = '1') then
            
            bus_dataRead <= (others => '0');
            
            -- bus read
            if (bus_read = '1') then
               case (bus_addr(3 downto 1) & '0') is
                  -- psx-spx: an 8/16bit read removes ONE entry from the RX FIFO,
                  -- a 32bit read removes FOUR
                  when x"0" => -- SIO_RX_DATA
                     bus_dataRead <= rxFifo(3) & rxFifo(2) & rxFifo(1) & rxFifo(0);
                     if (bus_reqsize = "10") then      -- 32bit read: remove four
                        rxFifo(0 to FIFODEPTH-5) <= rxFifo(4 to FIFODEPTH-1);
                        if (fifoCnt_v > 4) then
                           fifoCnt_v := fifoCnt_v - 4;
                        else
                           fifoCnt_v := (others => '0');
                        end if;
                     elsif (fifoCnt_v /= 0) then       -- 8/16bit read: remove one
                        rxFifo(0 to FIFODEPTH-2) <= rxFifo(1 to FIFODEPTH-1);
                        fifoCnt_v      := fifoCnt_v - 1;
                     end if;
                  
                  when x"2" => -- upper half of SIO_RX_DATA (16bit read at ...52)
                     bus_dataRead(15 downto 0) <= rxFifo(3) & rxFifo(2);
                     
                  when x"4" => 
                     bus_dataRead(0)  <= statTxNotFullCPU;                       -- TX FIFO not full
                     if (rxFifoCnt /= 0) then bus_dataRead(1) <= '1'; end if;    -- RX FIFO not empty
                     bus_dataRead(2)  <= statTxIdleCPU;                          -- TX idle
                     bus_dataRead(3)  <= statParityError;
                     bus_dataRead(4)  <= statRxOverrun;
                     bus_dataRead(5)  <= statRxBadStop;
                     bus_dataRead(6)  <= statRxInvLevel;
                     bus_dataRead(7)  <= dsrLevel;
                     bus_dataRead(8)  <= ctsLevel;
                     bus_dataRead(9)  <= statIrq;
                     bus_dataRead(31 downto 11) <= std_logic_vector(baudTimer);
                     
                  when x"6" => -- upper half of SIO_STAT (baudrate timer bits)
                     bus_dataRead(15 downto 0) <= std_logic_vector(baudTimer(20 downto 5));
                     
                  when x"8" => 
                     bus_dataRead <= SIO_CTRL & x"00" & SIO_MODE;
                     
                  when x"A" => 
                     bus_dataRead <= x"0000" & SIO_CTRL;   
                     
                  when x"C" => -- SIO_MISC (low) / SIO_BAUD (high)
                     if (SIO_MODE(3 downto 2) = "11") then
                        bus_dataRead <= SIO_BAUD & (((SIO_MISC(7 downto 0) & SIO_MISC(15 downto 8)) and x"1F1F") or x"C0C0");
                     else
                        bus_dataRead <= SIO_BAUD & (((SIO_MISC(7 downto 0) & SIO_MISC(15 downto 8)) and x"1F1F") or x"8080");
                     end if;
                     
                  when x"E" => 
                     bus_dataRead <= x"0000" & SIO_BAUD;  
                     
                  when others => bus_dataRead <= (others => '1');
               end case;
            end if;

            -- bus write
            if (bus_write = '1') then
               case (bus_addr(3 downto 0)) is
                  when x"0" => -- SIO_TX_DATA
                     if (bus_writeMask(0) = '1') then
                        txBuffer       <= bus_dataWrite(7 downto 0);
                        txBufferFilled <= '1';
                        txEnLatched    <= ctrlTXEN;  -- latched TXEN
                        txWrite_v      := '1';
                     end if;
                     
                  when x"8" =>
                     -- update only addressed byte lanes
                     if (bus_writeMask(0) = '1') then
                        SIO_MODE <= bus_dataWrite(7 downto 0);
                     end if;
                     if (bus_writeMask(3) = '1') then  -- SIO_CTRL bits 15..8
                        SIO_CTRL(15 downto 8) <= "000" & bus_dataWrite(28 downto 24);
                     end if;
                     if (bus_writeMask(2) = '1') then  -- SIO_CTRL bits 7..0
                        SIO_CTRL(7 downto 0) <= bus_dataWrite(23) & '0' & bus_dataWrite(21) & '0' & bus_dataWrite(19 downto 16);
                        if (bus_dataWrite(20) = '1') then -- acknowledge -> clear STAT.3,4,5,9
                           irqAck_v := '1';
                           statParityError <= '0';
                           statRxOverrun   <= '0';
                           statRxBadStop   <= '0';
                           statIrq         <= '0';
                        end if;
                        if (bus_dataWrite(22) = '1') then -- reset
                           SIO_MODE        <= x"00";
                           SIO_CTRL        <= x"0000";
                           SIO_BAUD        <= x"00DC";
                           statParityError <= '0';
                           statRxOverrun   <= '0';
                           statRxBadStop   <= '0';
                           statIrq         <= '0';
                           txBufferFilled  <= '0';
                           txEnLatched     <= '0';
                           txRunning       <= '0';
                           txStartSeen     <= '1';
                           txState         <= TXIDLE;
                           sio_TXD         <= '1';
                           rxState         <= RXIDLE;
                           rxFifoCnt       <= (others => '0');
                           -- keep local FIFO count cleared after reset
                           fifoCnt_v       := (others => '0');
                        end if; 
                     end if;
                     
                  when x"A" => -- 8/16 bit write directly to SIO_CTRL
                     if (bus_writeMask(1 downto 0) /= "00") then
                        SIO_CTRL <= "000" & bus_dataWrite(12 downto 7) & "0" & bus_dataWrite(5) & "0" & bus_dataWrite(3 downto 0);
                        if (bus_dataWrite(4) = '1') then
                           irqAck_v := '1';
                           statParityError <= '0';
                           statRxOverrun   <= '0';
                           statRxBadStop   <= '0';
                           statIrq         <= '0';
                        end if;
                        if (bus_dataWrite(6) = '1') then
                           SIO_MODE        <= x"00";
                           SIO_CTRL        <= x"0000";
                           SIO_BAUD        <= x"00DC";
                           statParityError <= '0';
                           statRxOverrun   <= '0';
                           statRxBadStop   <= '0';
                           statIrq         <= '0';
                           txBufferFilled  <= '0';
                           txEnLatched     <= '0';
                           txRunning       <= '0';
                           txStartSeen     <= '1';
                           txState         <= TXIDLE;
                           sio_TXD         <= '1';
                           rxState         <= RXIDLE;
                           rxFifoCnt       <= (others => '0');
                           -- keep local FIFO count cleared after reset
                           fifoCnt_v       := (others => '0');
                        end if;
                     end if;
                     
                  when x"C" =>
                     if (bus_writeMask(0) = '1') then SIO_MISC( 7 downto 0) <= bus_dataWrite( 7 downto  0); end if;
                     if (bus_writeMask(1) = '1') then SIO_MISC(15 downto 8) <= bus_dataWrite(15 downto  8); end if;
                     if (bus_writeMask(2) = '1') then SIO_BAUD( 7 downto 0) <= bus_dataWrite(23 downto 16); end if;
                     if (bus_writeMask(3) = '1') then SIO_BAUD(15 downto 8) <= bus_dataWrite(31 downto 24); end if;
                     if (bus_writeMask(3 downto 2) /= "00") then
                        -- reload baud timer from current bit timing
                        baudReloadReq <= '1';
                     end if;
                     
                  when x"E" => -- 16 bit write directly to SIO_BAUD
                     if (bus_writeMask(1 downto 0) /= "00") then
                        SIO_BAUD  <= bus_dataWrite(15 downto 0);
                        baudTimer <= resize(unsigned(bus_dataWrite(15 downto 0)), 21);
                     end if;
                  
                  when others => null;
               end case;
            end if;
            
            end if; -- ce (bus access)
            
            -- TX engine
            startTX := '0';
            if (txRunning = '0' and txBufferFilled = '1' and txWrite_v = '0' and (ctrlTXEN = '1' or txEnLatched = '1') and ctsLevel = '1') then
               startTX := '1';
            end if;
            
            if (startTX = '1') then
               txShift        <= txBuffer;
               txBufferFilled <= '0';
               txStartSeen    <= '0';       -- start bit active
               txRunning      <= '1';
               txState        <= TXSTART;
               txCycleCnt     <= cyclesPerBit;
               txBitCnt       <= (others => '0');
               txParityCalc   <= '0';
               sio_TXD        <= '0';       -- start bit
            elsif (txRunning = '1') then
               if (txCycleCnt <= 1) then
                  txCycleCnt <= cyclesPerBit;
                  case (txState) is
                     when TXSTART =>
                        txStartSeen <= '1';
                        txState  <= TXDATA;
                        sio_TXD  <= txShift(0);
                        txParityCalc <= txShift(0);
                        txShift  <= '0' & txShift(7 downto 1);
                        txBitCnt <= to_unsigned(1, 4);
                        
                     when TXDATA =>
                        if (txBitCnt >= charLenBits) then
                           if (SIO_MODE(4) = '1') then
                              txState <= TXPARITY;
                              -- parity type: MODE.5=0 -> even
                              sio_TXD <= txParityCalc xor SIO_MODE(5);
                           else
                              txState <= TXSTOP;
                              sio_TXD <= '1' xor ctrlTXINV; -- stop bit
                              -- stop length: 0/1=1bit, 2=1.5bit, 3=2bit
                              case (SIO_MODE(7 downto 6)) is
                                 when "10"   => txCycleCnt <= cyclesPerBit + cyclesHalfBit;
                                 when "11"   => txCycleCnt <= cyclesPerBit + cyclesPerBit;
                                 when others => txCycleCnt <= cyclesPerBit;
                              end case;
                           end if;
                        else
                           sio_TXD      <= txShift(0);
                           txParityCalc <= txParityCalc xor txShift(0);
                           txShift      <= '0' & txShift(7 downto 1);
                           txBitCnt     <= txBitCnt + 1;
                        end if;
                        
                     when TXPARITY =>
                        txState <= TXSTOP;
                        sio_TXD <= '1' xor ctrlTXINV;
                        case (SIO_MODE(7 downto 6)) is
                           when "10"   => txCycleCnt <= cyclesPerBit + cyclesHalfBit;
                           when "11"   => txCycleCnt <= cyclesPerBit + cyclesPerBit;
                           when others => txCycleCnt <= cyclesPerBit;
                        end case;
                        
                     when TXSTOP =>
                        txRunning <= '0';
                        txState   <= TXIDLE;
                        sio_TXD   <= '1' xor ctrlTXINV;
                        -- TX completion IRQ event
                        if (ctrlTXIEN = '1') then
                           irqEvent := '1';
                        end if;
                        
                     when others => 
                        txRunning <= '0';
                        txState   <= TXIDLE;
                  end case;
               else
                  txCycleCnt <= txCycleCnt - 1;
               end if;
            else
               sio_TXD <= '1' xor ctrlTXINV; -- idle level
            end if;
            
            -- RX engine
            case (rxState) is
               when RXIDLE =>
                  -- detect start bit on RXD falling edge
                  if (linkCableOn = '1' and rxdLevel_1 = '1' and rxdLevel = '0') then
                     rxState    <= RXSTART;
                     rxCycleCnt <= cyclesHalfBit;
                  end if;
                  
               when RXSTART =>
                  if (rxCycleCnt <= 1) then
                     if (rxdLevel = '0') then -- valid start bit
                        rxState      <= RXDATA;
                        rxCycleCnt   <= cyclesPerBit;
                        rxBitCnt     <= (others => '0');
                        rxShift      <= (others => '0');
                        rxParityCalc <= '0';
                     else
                        rxState         <= RXIDLE; -- false start
                     end if;
                  else
                     rxCycleCnt <= rxCycleCnt - 1;
                  end if;
                  
               when RXDATA =>
                  if (rxCycleCnt <= 1) then
                     rxCycleCnt   <= cyclesPerBit;
                     rxShift      <= rxdLevel & rxShift(7 downto 1); -- LSB first
                     rxParityCalc <= rxParityCalc xor rxdLevel;
                     if (rxBitCnt + 1 >= charLenBits) then
                        if (SIO_MODE(4) = '1') then
                           rxState <= RXPARITY;
                        else
                           rxState <= RXSTOP;
                        end if;
                     else
                        rxBitCnt <= rxBitCnt + 1;
                     end if;
                  else
                     rxCycleCnt <= rxCycleCnt - 1;
                  end if;
                  
               when RXPARITY =>
                  if (rxCycleCnt <= 1) then
                     rxCycleCnt <= cyclesPerBit;
                     if ((rxParityCalc xor SIO_MODE(5)) /= rxdLevel) then
                        statParityError <= '1';
                     end if;
                     rxState <= RXSTOP;
                  else
                     rxCycleCnt <= rxCycleCnt - 1;
                  end if;
                  
               when RXSTOP =>
                  if (rxCycleCnt <= 1) then
                     if (rxdLevel = '0' and ctrlRXEN = '1') then
                        statRxBadStop <= '1';
                     end if;
                     statRxInvLevel <= not rxdLevel;
                     -- align characters shorter than 8 bits
                     case (SIO_MODE(3 downto 2)) is
                        when "00"   => pushData := "000" & rxShift(7 downto 3);
                        when "01"   => pushData := "00"  & rxShift(7 downto 2);
                        when "10"   => pushData := "0"   & rxShift(7 downto 1);
                        when others => pushData := rxShift;
                     end case;
                     pushByte := '1';
                     -- return immediately to start-edge detection
                     rxState <= RXIDLE;
                  else
                     rxCycleCnt <= rxCycleCnt - 1;
                  end if;
                  
            end case;
            
            ctrlRXEN_1 <= ctrlRXEN;

            -- park receiver while RXEN is low
            if (ctrlRXEN = '0') then
               rxState <= RXIDLE;
            end if;

            -- clear RX FIFO on RXEN falling edge
            
            if (ctrlRXEN = '0' and ctrlRXEN_1 = '1') then
               fifoCnt_v := (others => '0');
            end if;
            
            -- RX FIFO push
            if (pushByte = '1') then
               if (fifoCnt_v < FIFODEPTH) then
                  -- mirror newest byte into unused FIFO entries
                  for i in 0 to FIFODEPTH-1 loop
                     if (i >= to_integer(fifoCnt_v)) then
                        rxFifo(i) <= pushData;
                     end if;
                  end loop;
                  fifoCnt_v := fifoCnt_v + 1;
               else
                  rxFifo(FIFODEPTH-1) <= pushData; -- overwrite last entry
                  statRxOverrun <= '1';
               end if;
            end if;
            
            rxFifoCnt <= fifoCnt_v;
            
            -- IRQ
            -- ACK clears STAT.9; active sources can reassert it            
            if (irqAck_v = '1') then
               statIrq <= '0';
            elsif (irqEvent = '1' or irqCondRX = '1' or irqCondTX = '1' or irqCondDSR = '1') then
               statIrq <= '1';
            end if;

         end if;
      end if;
   end process;

--##############################################################
--############################### savestates
--##############################################################
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
         
         if (SS_rden = '1') then
            SS_DataRead <= ss_out(to_integer(SS_Adr));
         end if;
      
      end if;
   end process;

end architecture;
