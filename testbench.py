from forastero.io import IORole, io_suffix_style 
from forastero import BaseBench
from spi.io import SpiIO
from spi.target import SpiTarget
from spi.sequences import spi_send_array
from axi4stream.io import AXI4StreamIO
from axi4stream.monitor import AXI4StreamMonitor
from axi4stream.transaction import AXI4StreamTransfer
from axi4stream.target import AXI4StreamTarget
from axi4stream.sequences import axi4stream_backpressure_finite

from axi4stream.sequences import axi4stream_backpressure_list

from cocotb.triggers import ClockCycles
from cocotb.log import SimLog
from forastero.monitor import MonitorEvent
from forastero.driver import DriverEvent

class Testbench(BaseBench):
    def __init__(self, dut):
        super().__init__(dut, clk=dut.clk_i, rst=dut.rstn_i, rst_active_high=False)
        spi_io = SpiIO(
            dut, "spi", IORole.INITIATOR, io_style=io_suffix_style
        )
        self.register("spi_drv", SpiTarget(
            self, spi_io, self.clk, self.rst
        ))
        axi4stream_io = AXI4StreamIO(
            dut, "axis", IORole.INITIATOR, io_style=io_suffix_style
        )
        self.register("axi4stream_mon", AXI4StreamMonitor(
            self, axi4stream_io, self.clk, self.rst
        ))
        self.register("axi4stream_target", AXI4StreamTarget(
            self, axi4stream_io, self.clk, self.rst
            ),
        )
        
        
    async def initialise(self) -> None:
        """Initialise the DUT's I/O"""
        self.rst.value = 0
        for comp in self._components.values():
            comp.io.initialise(IORole.opposite(comp.io.role))

    async def reset(self, init=True, wait_during=10, wait_after=1) -> None:
        """
        Reset the DUT.

        :param init:        Initialise the DUT's I/O
        :param wait_during: Clock cycles to hold reset active for (defaults to 20)
        :param wait_after:  Clock cycles to wait after lowering reset (defaults to 1)
        """
        # Drive reset active
        self.rst.value = 0
        # Initialise I/O
        if init:
            await self.initialise()
        # Wait before dropping reset
        if wait_during > 0:
            await ClockCycles(self.clk, wait_during)
        # Drop reset
        self.rst.value = 1
        # Wait for a bit
        if wait_after > 0:
            self.info(f"Waiting for {wait_after} cycles")
            await ClockCycles(self.clk, wait_after)


@Testbench.testcase(reset_wait_during=2, reset_wait_after=0, timeout=400000, shutdown_delay=10, shutdown_loops=1)
async def smoke(tb : Testbench, log: SimLog):
    ref_data=range(1000, 1128)
    ref_trans = []
    for ind, data in enumerate(ref_data):
        ref_trans.append(
            AXI4StreamTransfer(
                index=ind % 16,
                data=data,
                last=int((ind + 1) % 16 == 0)
            )
        )
    tb.scoreboard.channels["axi4stream_mon"].push_reference(*ref_trans)
    tb.dut.read_spi_i.value = 1
    tb.dut.axis_tready_i.value = 1
    tb.schedule(spi_send_array(driver=tb.spi_drv, data=ref_data))
    for _ in ref_data:
        await tb.axi4stream_mon.wait_for(MonitorEvent.CAPTURE)
    tb.dut.read_spi_i.value = 0

spi_packet_choose = 0b00 #16 packet length
#spi_packet_choose = 0b01 #32 packet length
#spi_packet_choose = 0b10 #64 packet length
if(spi_packet_choose == 0b10):
    spi_packet_length = 64
elif(spi_packet_choose == 0b01):
    spi_packet_length = 32
else:
    spi_packet_length = 16

@Testbench.testcase(reset_wait_during=2, reset_wait_after=0, timeout=400000, shutdown_delay=10, shutdown_loops=1)
async def backpressure(tb : Testbench, log: SimLog):
    ref_data=range(1000, 1128)
    ref_trans = []
    for ind, data in enumerate(ref_data):
        ref_trans.append(
            AXI4StreamTransfer(
                index=ind % spi_packet_length,
                data=data,
                last=int((ind + 1) % spi_packet_length == 0)
            )
        )
    tb.dut.spi_packet_mode.value = spi_packet_choose
    tb.scoreboard.channels["axi4stream_mon"].push_reference(*ref_trans)
    tb.dut.read_spi_i.value = 1
    tb.schedule(axi4stream_backpressure_finite(driver=tb.axi4stream_target, transfers = 65536))
    tb.schedule(spi_send_array(driver=tb.spi_drv, data=ref_data))
    for _ in ref_data:
        await tb.axi4stream_mon.wait_for(MonitorEvent.CAPTURE)
    tb.dut.read_spi_i.value = 0

@Testbench.testcase(reset_wait_during=2, reset_wait_after=0, timeout=400000, shutdown_delay=10, shutdown_loops=1)
async def long_not_ready(tb: Testbench, log: SimLog):
    ref_data=range(1000, 1032)
    ref_trans = []
    for ind, data in enumerate(ref_data):
        ref_trans.append(
            AXI4StreamTransfer(
                index=ind % 16,
                data=data,
                last=int((ind + 1) % 16 == 0)
            )
        )


    axi4stream_leftover_sample = AXI4StreamTransfer(
                index=0,
                data=2007,
                last=False
            )
    
    #ref_trans = [axi4stream_leftover_sample] + ref_trans

    tb.scoreboard.channels["axi4stream_mon"].push_reference(*ref_trans)
    tb.dut.read_spi_i.value = 1
    tb.dut.axis_tready_i.value = 0
    tb.schedule(spi_send_array(driver=tb.spi_drv, data=ref_data))
    tb.schedule(spi_send_array(driver=tb.spi_drv, data=range(2000, 2008)))

    for _ in range(9):
        await tb.spi_drv.wait_for(DriverEvent.POST_DRIVE)
    tb.dut.axis_tready_i.value = 1

    for _ in ref_data:
        await tb.axi4stream_mon.wait_for(MonitorEvent.CAPTURE)
    tb.dut.read_spi_i.value = 0
