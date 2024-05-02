--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


entity top_basys3 is
    port(   clk     :   in std_logic; -- native 100MHz FPGA clock
            btnU    :   in std_logic;
            btnC    :   in std_logic;
            sw      :   in std_logic_vector(10 downto 0);
            
            led     :   out std_logic_vector(15 downto 0);
            seg     :   out std_logic_vector(6 downto 0);
            an  :   out std_logic_vector(3 downto 0)   
        );
end top_basys3;

architecture top_basys3_arch of top_basys3 is 
  
	-- declare components and signals
    component sevenSegDecoder is
          Port (
            i_D     :    in  std_logic_vector(3 downto 0); 
            o_S     :   out std_logic_vector(6 downto 0)
            );
    end component sevenSegDecoder; 
    
    component clock_divider is
        generic ( constant k_DIV : natural := 2    ); -- How many clk cycles until slow clock toggles
                                                       -- Effectively, you divide the clk double this 
                                                       -- number (e.g., k_DIV := 2 --> clock divider of 4)
        port (  i_clk    : in std_logic;
                i_reset  : in std_logic;           -- asynchronous
                o_clk    : out std_logic           -- divided (slow) clock
            );
    end component clock_divider; 
    
    component TDM4 is
        generic ( constant k_WIDTH : natural  := 4); -- bits in input and output
            Port ( i_clk        : in  STD_LOGIC;
                   i_reset      : in  STD_LOGIC; -- asynchronous
                   i_D3         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                   i_D2         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                   i_D1         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                   i_D0         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                   o_data       : out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                   o_sel        : out STD_LOGIC_VECTOR (3 downto 0)    -- selected data line (one-cold)
                );
    end component TDM4;                                    
    
    component twoscomp_decimal is
        port (
            i_binary: in std_logic_vector(7 downto 0);
            o_negative: out std_logic_vector(3 downto 0);
            o_hundreds: out std_logic_vector(3 downto 0);
            o_tens: out std_logic_vector(3 downto 0);
            o_ones: out std_logic_vector(3 downto 0)
        );
    end component twoscomp_decimal;
    
    constant k_IO_WIDTH : natural := 4;
    
    component controller_fsm is
        port(
        i_clk   :   in std_logic;
        i_reset :   in std_logic;
        i_adv   :   in std_logic;
        o_cycle :   out std_logic_vector(3 downto 0)
        );
    end component controller_fsm;
    
    component ALU is
        port(   i_A         :   in std_logic_vector(8 downto 0);
                i_B         :   in std_logic_vector(8 downto 0);
                i_op        :   in std_logic_vector(2 downto 0);
                o_flags     :   out std_logic_vector(2 downto 0);
                o_result    :   out std_logic_vector(7 downto 0)
        );
    end component ALU;
    signal s_cycle, s_sign, s_hund, s_tens, s_ones, s_data : std_logic_vector(3 downto 0);
    signal s_result, s_mux : std_logic_vector(7 downto 0);
    signal s_A, s_B : std_logic_vector(8 downto 0);
    signal  w_clk1, w_clk2 : std_logic;
    signal w_opcode, w_flags : std_logic_vector(2 downto 0);
begin
	-- PORT MAPS ----------------------------------------
    controller_fsm_inst : controller_fsm
            port map(
            i_clk   => w_clk1,
            i_reset => btnU,
            i_adv   => btnC,
            o_cycle => s_cycle
            );
        
	ALU_inst : ALU
        port map(   i_A         => s_A,
                    i_B         => s_B,
                    i_op        => w_opcode,
                    o_flags     => led(15 downto 13),
                    o_result    => s_result
                    );
	
	clock_divider_inst1 : clock_divider
        generic map ( k_DIV => 25000000)
        port map (
            i_clk => clk,
            i_reset => btnU,
            o_clk => w_clk1
            );
     
     clock_divider_inst2 : clock_divider
        generic map ( k_DIV => 280000)
        port map (
            i_clk => clk,
            i_reset => btnU,
            o_clk => w_clk2
            ); 
        
     --twoscomp_decimal_inst : twoscomp_decimal
       -- port map (  i_binary    => s_mux,
                    --o_negative  => s_sign,
                   -- o_hundreds  => s_hund,
                   -- o_tens      => s_tens,
                    --o_ones      => s_ones
                   -- );   
    
    TDM4_inst : TDM4
        generic map ( k_WIDTH => k_IO_WIDTH ) 
        Port map ( i_clk    => w_clk2,
               i_reset      => btnU,
               i_D3         => "0000",
               i_D2         => "0000",
               i_D1         => s_mux(7 downto 4),
               i_D0         => s_mux(3 downto 0),
               o_data       => s_data,
               o_sel        => an
               );
    
    sevenSegDecoder_inst : sevenSegDecoder
        port map(
                i_D => s_data,
                o_S => seg
                );  
                                               
	-- CONCURRENT STATEMENTS ----------------------------
	s_A(7 downto 0) <= sw(10 downto 3) when (s_cycle(0) = '1');
	s_B(7 downto 0) <= sw(10 downto 3) when (s_cycle(1) = '1');
	s_A(8) <= '0';
	s_B(8) <= '0';
	s_mux  <=  s_A(7 downto 0) when (s_cycle = "0001") else 
	           s_B(7 downto 0) when (s_cycle = "0010") else 
	           s_result when (s_cycle = "0100") else
	           "00000000" when (s_cycle ="1000") else
	           "00000000";
	            
    w_opcode <= sw(2 downto 0);  
	led(3 downto 0) <= s_cycle;
	led(12) <= '0';
	led(11) <= '0';
	led(10) <= '0';
	led(9) <= '0';
	led(8) <= '0';
	led(7) <= '0';
	led(6) <= '0';
	led(5) <= '0';
	led(4) <= '0';
	
	
	
	
end top_basys3_arch;
