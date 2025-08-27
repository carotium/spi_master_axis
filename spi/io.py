from collections.abc import Callable

from cocotb.handle import HierarchyObject
from forastero.io import BaseIO, IORole


class SpiIO(BaseIO):
    def __init__(
        self,
        dut: HierarchyObject,
        name: str,
        role: IORole,
        io_style: Callable[[str | None, str, IORole, IORole], str] | None = None,
    ):
        super().__init__(
            dut,
            name,
            role,
            [
                "sclk",
                "mosi",
                "ss",
            ],
            ["miso"],
            io_style=io_style,
        )
