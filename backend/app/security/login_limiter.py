from collections import defaultdict, deque
from threading import Lock
from time import monotonic


class LoginAttemptLimiter:
    def __init__(self, *, limit: int = 8, window_seconds: int = 300):
        self.limit = limit
        self.window_seconds = window_seconds
        self._attempts: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    def _prune(self, attempts: deque[float], now: float) -> None:
        cutoff = now - self.window_seconds
        while attempts and attempts[0] <= cutoff:
            attempts.popleft()

    def is_blocked(self, key: str) -> bool:
        now = monotonic()
        with self._lock:
            attempts = self._attempts[key]
            self._prune(attempts, now)
            return len(attempts) >= self.limit

    def record_failure(self, key: str) -> None:
        now = monotonic()
        with self._lock:
            attempts = self._attempts[key]
            self._prune(attempts, now)
            attempts.append(now)

    def clear(self, key: str) -> None:
        with self._lock:
            self._attempts.pop(key, None)
