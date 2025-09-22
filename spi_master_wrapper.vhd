library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity spi_master_wrapper is
  generic (
    -- TDATA width in bits
    M_AXIS_TDATA_O_WIDTH : integer := 32;
    -- Number of SPI samples in one AXI Stream transfer
    M_SPI_TRANSFER_LENGTH : integer := 128;
    -- Number of bits in single spi sample
    M_SPI_PACKET_LENGTH : integer := 16;
    -- Sample pulse lenght for sample frequency of 44.1 kHz
    -- LENGTH        = M_CLK_FREQ / SAMPLE_FREQ
    --               = 100 MHz / 44.1 kHz = 2267.57
    -- round(LENGTH) = 2268
    M_SAMPLE_PULSE_COUNTER_LENGTH : integer := 2268;
    -- Width of sclk counter for master clock division
    -- sclk_freq = m_aclk_freq / 2^(SCLK_COUNTER_WIDTH)
    M_SCLK_COUNTER_WIDTH : integer := 3
  );
  port (
    -- Master clock input
    m_clk_i : in    std_logic;
    -- Master reset input
    m_rstn_i : in    std_logic;

    -- SPI ports
    -- AXI Stream packet length
    m_spi_packet_length_i : in    std_logic_vector(7 downto 0);
    -- cocotb stop switch
    m_read_spi_i : in    std_logic;
    -- Master serial clock
    m_spi_sclk_o : out   std_logic;
    -- Master miso input
    m_spi_miso_i : in    std_logic;
    -- Master slave select output
    m_spi_ss_o : out   std_logic;

    -- AXIS Master ports
    -- Master valid output
    m_axis_tvalid_o : out   std_logic;
    -- Master ready input
    m_axis_tready_i : in    std_logic;
    -- Master data output
    m_axis_tdata_o : out   std_logic_vector(7 downto 0);
    -- Master last packet output
    m_axis_tlast_o : out   std_logic
  );
end entity spi_master_wrapper;

architecture STRUCTURE of spi_master_wrapper is

  component spi_master_axis is
    generic (
      AXIS_TDATA_O_WIDTH          : integer;
      SPI_TRANSFER_LENGTH         : integer;
      SPI_PACKET_LENGTH           : integer;
      SAMPLE_PULSE_COUNTER_LENGTH : integer;
      SCLK_COUNTER_WIDTH          : integer
    );
    port (
      clk_i               : in    std_logic;
      rstn_i              : in    std_logic;
      spi_packet_length_i : in    std_logic_vector(7 downto 0);
      read_spi_i          : in    std_logic;
      spi_sclk_o          : out   std_logic;
      spi_miso_i          : in    std_logic;
      spi_ss_o            : out   std_logic;
      axis_tvalid_o       : out   std_logic;
      axis_tready_i       : in    std_logic;
      axis_tdata_o        : out   std_logic_vector(M_AXIS_TDATA_O_WIDTH - 1 downto 0);
      axis_tlast_o        : out   std_logic
    );
  end component spi_master_axis;

begin

  spi_component : component spi_master_axis
    generic map (
      axis_tdata_o_width          => M_AXIS_TDATA_O_WIDTH,
      spi_transfer_length         => M_SPI_TRANSFER_LENGTH,
      spi_packet_length           => M_SPI_PACKET_LENGTH,
      sample_pulse_counter_length => M_SAMPLE_PULSE_COUNTER_LENGTH,
      sclk_counter_width          => M_SCLK_COUNTER_WIDTH
    )
    port map (
      clk_i               => m_clk_i,
      rstn_i              => m_rstn_i,
      spi_packet_length_i => m_spi_packet_length_i,
      read_spi_i          => m_read_spi_i,
      spi_sclk_o          => m_spi_sclk_o,
      spi_miso_i          => m_spi_miso_i,
      spi_ss_o            => m_spi_ss_o,

      axis_tvalid_o              => m_axis_tvalid_o,
      axis_tready_i              => m_axis_tready_i,
      axis_tdata_o(31 downto 24) => m_axis_tdata_o,
      axis_tdata_o(23 downto 0)  => open,
      axis_tlast_o               => m_axis_tlast_o
    );

end architecture STRUCTURE;
