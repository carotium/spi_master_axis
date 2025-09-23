library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity spi_master_axis is
  generic (
    -- TDATA width in bits
    AXIS_TDATA_O_WIDTH : integer := 32;
    -- Number of SPI samples in one AXI Stream transfer
    SPI_TRANSFER_LENGTH : integer := 128;
    -- Number of bits in single spi sample
    SPI_PACKET_LENGTH : integer := 16;
    -- Sample pulse lenght for sample frequency of 44.1 kHz
    -- LENGTH        = M_CLK_FREQ / SAMPLE_FREQ
    --               = 100 MHz / 44.1 kHz = 2267.57
    -- round(LENGTH) = 2268
    SAMPLE_PULSE_COUNTER_LENGTH : integer := 2268;
    -- Width of sclk counter for master clock division
    -- sclk_freq = m_aclk_freq / 2^(SCLK_COUNTER_WIDTH)
    SCLK_COUNTER_WIDTH : integer := 4
  );
  port (
    -- Master clock
    clk_i : in    std_logic;
    -- Master reset
    rstn_i : in    std_logic;

    -- SPI ports
    -- AXI Stream packet length
    spi_packet_length_i : in    std_logic_vector(7 downto 0);
    -- cocotb stop switch
    read_spi_i : in    std_logic;
    -- Master out serial clock
    spi_sclk_o : out   std_logic;
    -- Master in miso
    spi_miso_i : in    std_logic;
    -- Master out slave select
    spi_ss_o : out   std_logic;

    -- AXIS Master ports
    -- Master valid out
    axis_tvalid_o : out   std_logic;
    -- Master ready out
    axis_tready_i : in    std_logic;
    -- Master data out
    axis_tdata_o : out   std_logic_vector(AXIS_TDATA_O_WIDTH - 1 downto 0);
    -- Master last packet out
    axis_tlast_o : out   std_logic
  );
end entity spi_master_axis;

architecture RTL of spi_master_axis is

  -- Slave select
  signal ss : std_logic;
  -- Master input miso
  signal miso : std_logic;
  -- Master output serial clock (12.5 MHz)
  signal sclk : std_logic;
  -- Serial clock counter
  signal sclk_counter      : std_logic_vector(SCLK_COUNTER_WIDTH - 1 downto 0);
  signal prev_sclk_counter : std_logic_vector(SCLK_COUNTER_WIDTH - 1 downto 0);
  -- Sclk counter conditions
  signal last_high_sclk              : std_logic;
  signal sclk_falling_edge           : std_logic;
  signal sclk_counter_less_than_half : std_logic;
  -- Sclk counter half value
  signal sclk_counter_half_value : std_logic_vector(SCLK_COUNTER_WIDTH - 1 downto 0);

  -- Sample clock (44.1 kHz)
  signal sample_pulse         : std_logic;
  signal sample_pulse_counter : integer range 0 to SAMPLE_PULSE_COUNTER_LENGTH;

  -- Begins on sample_pulse rising edge
  signal do_spi_sample : std_logic;
  -- SPI sample, we expect 4 leading 0's and 12 bits of data from PmodMIC3 ADC
  signal spi_sample : std_logic_vector(SPI_PACKET_LENGTH - 1 downto 0);
  -- Bit selector for sample storing
  signal spi_bit_counter : integer range 0 to SPI_PACKET_LENGTH - 1;

  -- We want to send an AXIS packet of SPI_TRANSFER_LENGTH SPI samples
  -- Counter for whole spi sample of 16 bits
  signal spi_whole_sample_count : integer range 0 to SPI_TRANSFER_LENGTH - 1;
  -- Spi whole sample count conditions
  signal do_increment_sample_counter : std_logic;
  signal do_reset_sample_counter     : std_logic;

  -- This tvalid for use in process
  signal this_tvalid : std_logic;
  -- Next tvalid for assignment in a process
  signal next_tvalid : std_logic;
  -- This tdata for use in process
  signal this_tdata : std_logic_vector(AXIS_TDATA_O_WIDTH - 1 downto 0);
  -- Next tdata for assignment in a process
  signal next_tdata : std_logic_vector(AXIS_TDATA_O_WIDTH - 1 downto 0);
  -- This tlast for use in process
  signal this_tlast : std_logic;

  -- SPI packet length chooser from 0 to SPI_TRANSFER_LENGTH
  signal spi_packet_mode_length : integer range 0 to SPI_TRANSFER_LENGTH;

begin

  -- Number of spi packets in one AXIS transfer
  -- spi_packet_mode_length <= to_integer(unsigned(spi_packet_length_i));
  spi_packet_mode_length <= 16;

  -- I/O assignments
  miso       <= spi_miso_i;
  spi_ss_o   <= ss when (read_spi_i = '1') else
                '0'; -- read spi is a "stop" switch
  spi_sclk_o <= sclk;

  -- Internal signal use
  axis_tdata_o  <= this_tdata;
  axis_tvalid_o <= this_tvalid;
  axis_tlast_o  <= this_tlast;

  -- Sample clock signal
  sample_pulse <= '1' when (sample_pulse_counter = 50) else
                  '0';

  -- Set TLAST when last SPI sample is assigned to TDATA
  this_tlast <= '1' when (spi_whole_sample_count = spi_packet_mode_length - 1 and this_tvalid = '1') else
                '0';

  -- Valid comes as soon as we get the whole sample from SPI
  next_tvalid <= '1' when (sclk_falling_edge = '1') else
                 '0';

  -- Send spi_sample as soon as it is sampled
  next_tdata <= x"0000" & spi_sample when (next_tvalid = '1') else
                x"DEADBEEF";

  -- Slave select goes low when sample pulse (44.1 kHz) and do_spi_sample (126 clk cycles for SPI sample)
  ss <= '0' when (do_spi_sample = '1' or sample_pulse = '1') else
        '1';

  -- Sclk counter half value is only with MSB set and others cleared
  sclk_counter_half_value(SCLK_COUNTER_WIDTH - 1)          <= '1';
  sclk_counter_half_value(SCLK_COUNTER_WIDTH - 2 downto 0) <= (others => '0');

  -- Last rising edge of master clk where sclk is '1'
  last_high_sclk <= '1' when (sclk_counter = sclk_counter_half_value
                               and prev_sclk_counter = std_logic_vector(unsigned(sclk_counter_half_value) - 1)) else
                    '0';

  -- Sclk falling edge of last bit transferred over SPI
  sclk_falling_edge <= '1' when (sclk_counter = std_logic_vector(unsigned(sclk_counter_half_value) + 1)
                                  and prev_sclk_counter = sclk_counter_half_value
                                  and do_spi_sample = '0') else
                       '0';

  -- High when sclk counter is less than half of its' max value
  sclk_counter_less_than_half <= '1' when (sclk_counter < sclk_counter_half_value) else
                                 '0';

  -- High when number of stored spi samples is less than spi_packet_mode_length
  --           and transfer is in progress (tvalid %% tready)
  do_increment_sample_counter <= '1' when (spi_whole_sample_count < spi_packet_mode_length - 1
                                            and this_tvalid = '1'
                                            and axis_tready_i = '1') else
                                 '0';

  -- High when last spi sample is stored (according to spi_packet_mode_length)
  --           and is the last transfer
  --           and DMA is ready
  do_reset_sample_counter <= '1' when (spi_whole_sample_count = spi_packet_mode_length - 1
                                        and this_tlast = '1'
                                        and axis_tready_i = '1') else
                             '0';

  -- Sample clock counter process
  sample_pulse_process : process (clk_i) is
  begin

    if (rising_edge(clk_i)) then
      if (rstn_i = '0') then
        sample_pulse_counter <= 0;
      elsif (sample_pulse_counter < SAMPLE_PULSE_COUNTER_LENGTH) then
        sample_pulse_counter <= sample_pulse_counter + 1;
      else
        sample_pulse_counter <= 0;
      end if;
    end if;

  end process sample_pulse_process;

  -- Sample clock sets do_spi_sample
  do_spi_sample_process : process (clk_i) is
  begin

    if (rising_edge(clk_i)) then
      if (rstn_i = '0') then
        do_spi_sample <= '0';
      else
        if (sample_pulse = '1') then
          do_spi_sample <= '1';
        -- add configurability for other clk
        elsif (spi_bit_counter = 0 and last_high_sclk = '1') then
          do_spi_sample <= '0';
        end if;
      end if;
    end if;

  end process do_spi_sample_process;

  -- Sample collection process
  sampling_process : process (clk_i) is
  begin

    if (rising_edge(clk_i)) then
      if (rstn_i = '0') then
        spi_sample      <= (others => '0');
        spi_bit_counter <= SPI_PACKET_LENGTH - 1;
      elsif (last_high_sclk = '1') then
        if (spi_bit_counter > 0 and do_spi_sample = '1') then
          spi_sample(spi_bit_counter) <= miso;
          spi_bit_counter             <= spi_bit_counter - 1;
        elsif (do_spi_sample = '1' or spi_bit_counter = 0) then
          -- Last bit of sample stored
          spi_sample(spi_bit_counter) <= miso;
          spi_bit_counter             <= SPI_PACKET_LENGTH - 1;
        -- One sample of 16 bits done
        end if;
      end if;
    end if;

  end process sampling_process;

  transfer_process : process (clk_i) is
  begin

    if (rising_edge(clk_i)) then
      if (rstn_i = '0') then
        spi_whole_sample_count <= 0;
      elsif (do_increment_sample_counter = '1') then
        spi_whole_sample_count <= spi_whole_sample_count + 1;
      elsif (do_reset_sample_counter = '1') then
        -- spi_packet_mode_length SPI sample transferred on AXI Stream
        spi_whole_sample_count <= 0;
      end if;
    end if;

  end process transfer_process;

  -- TVALID and TLAST assignment process
  axis_tvalid_process : process (clk_i) is
  begin

    if (rising_edge(clk_i)) then
      if (rstn_i = '0') then
        this_tvalid <= '0';
      elsif (this_tvalid = '0' or axis_tready_i = '1') then
        -- Assign next_tvalid only when not valid (not skipping transfers)
        --                              or DMA is ready (send next transfer if available)
        this_tvalid <= next_tvalid;
      end if;
    end if;

  end process axis_tvalid_process;

  -- TDATA assignment process
  axis_tdata_process : process (clk_i) is
  begin

    if (rising_edge(clk_i)) then
      if (rstn_i = '0') then
        this_tdata <= (others => '0');
      elsif (this_tvalid = '0' or axis_tready_i = '1' or next_tvalid = '1') then
        -- Assign next_tdata only when not valid (not skipping transfers)
        --                             or DMA is ready (send next transfer if available)
        --                             or next_tvalid (next transfer is available)
        this_tdata <= next_tdata;
      end if;
    end if;

  end process axis_tdata_process;

  -- Serial clock assignment
  o_sclk_process : process (clk_i) is
  begin

    if (rising_edge(clk_i)) then
      if (rstn_i = '0') then
        sclk <= '0';
      elsif (sclk_counter_less_than_half = '1' and ss = '0') then
        sclk <= '1';
      else
        sclk <= '0';
      end if;
    end if;

  end process o_sclk_process;

  -- Serial clock counter process
  sclk_counter_process : process (clk_i) is
  begin

    if (rising_edge(clk_i)) then
      if (rstn_i = '0') then
        prev_sclk_counter <= (others => '1');
        sclk_counter      <= (others => '1');
      elsif (do_spi_sample = '1' and read_spi_i = '1') then
        prev_sclk_counter <= sclk_counter;
        sclk_counter      <= std_logic_vector(unsigned(sclk_counter) + 1);
      elsif (ss = '1') then
        sclk_counter      <= (others => '1');
        prev_sclk_counter <= (others => '1');
      else
        sclk_counter      <= (others => '0');
        prev_sclk_counter <= (others => '0');
      end if;
    end if;

  end process sclk_counter_process;

end architecture RTL;
