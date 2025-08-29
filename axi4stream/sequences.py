# SPDX-License-Identifier: MIT
# Copyright (c) 2023-2024 Vypercore. All Rights Reserved

import forastero
from forastero.driver import DriverEvent
from forastero.sequence import SeqContext, SeqProxy

from .target import AXI4StreamTarget
from .transaction import AXI4StreamBackpressure


@forastero.sequence(auto_lock=True)
@forastero.requires("driver", AXI4StreamTarget)
async def axi4stream_backpressure(
    ctx: SeqContext,
    driver: SeqProxy[AXI4StreamTarget],
    min_interval: int = 1,
    max_interval: int = 10,
    backpressure: float = 0.5,
):
    while True:
        driver.enqueue(
            AXI4StreamBackpressure(
                ready=ctx.random.choices(
                    (True, False), weights=(1.0 - backpressure, backpressure), k=1
                )[0],
                cycles=ctx.random.randint(min_interval, max_interval),
            )
        )
        await driver.wait_for(DriverEvent.PRE_DRIVE)


@forastero.sequence(auto_lock=True)
@forastero.requires("driver", AXI4StreamTarget)
async def axi4stream_backpressure_finite(
    ctx: SeqContext,
    driver: SeqProxy[AXI4StreamTarget],
    transfers: int,
    min_interval: int = 1,
    max_interval: int = 10,
    backpressure: float = 0.5,
):
    for _ in range(transfers):
        driver.enqueue(
            AXI4StreamBackpressure(
                ready=ctx.random.choices(
                    (True, False), weights=(1.0 - backpressure, backpressure), k=1
                )[0],
                cycles=ctx.random.randint(min_interval, max_interval),
            )
        )
        await driver.wait_for(DriverEvent.PRE_DRIVE)

@forastero.sequence(auto_lock=True)
@forastero.requires("driver", AXI4StreamTarget)
async def axi4stream_backpressure_list(
    ctx: SeqContext,
    driver: SeqProxy[AXI4StreamTarget],
    transfers: list[bool],
    cycles: int = 1,
):
    for transfer in transfers:
        driver.enqueue(
            AXI4StreamBackpressure(
                ready=transfer,
                cycles=cycles,
            )
        )
        await driver.wait_for(DriverEvent.PRE_DRIVE)