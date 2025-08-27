from dataclasses import dataclass

from forastero import BaseTransaction

@dataclass(kw_only=True)
class SpiTransaction(BaseTransaction):
    data: int = 0
    