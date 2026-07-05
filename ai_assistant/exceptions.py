from __future__ import annotations


class AiRateLimitExceeded(Exception):
    """İstemci dakikalık AI istek limitini aştı."""

    def __init__(self, *, remaining: int = 0) -> None:
        self.remaining = max(0, remaining)
        super().__init__("rate_limit_exceeded")
