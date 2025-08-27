import forastero
from forastero.driver import DriverEvent
from forastero.sequence import SeqContext, SeqProxy

from .target import SpiTarget
from .transaction import SpiTransaction

@forastero.sequence(auto_lock=True)
@forastero.requires("driver", SpiTarget)
async def spi_send_array(
    ctx: SeqContext,
    driver: SeqProxy[SpiTarget],
    data: list[int]
):
    for d in data:
        driver.enqueue(
            SpiTransaction(
                data=d
            )
        )
        await driver.wait_for(DriverEvent.PRE_DRIVE)
