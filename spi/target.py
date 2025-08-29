from cocotb.triggers import RisingEdge, FallingEdge
from forastero.driver import BaseDriver

from .transaction import SpiTransaction


class SpiTarget(BaseDriver):
    async def drive(self, transaction: SpiTransaction):
        binary_str = format(transaction.data, '>012b')
        assert len(binary_str) == 12, f"Transaction {transaction.data} exceeeds 12 bit limit."
        binary_str = "0000" + binary_str  # Add leading zeros
        while self.io.get("ss") != 0:  # Wait for slave select
            await FallingEdge(self.clk)
        for bit in binary_str: # send the data
            assert self.io.get("ss") == 0, "Slave select must not be deasserted during operation."
            while self.io.get("sclk") != 1:  # wait for clock edge
                await RisingEdge(self.clk)
            self.io.set("miso", int(bit))
            while self.io.get("sclk") != 0:  # wait for clock edge
                await RisingEdge(self.clk)
        self.io.set("miso", 0)