from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class GenerationResult:
    questions: list[dict]
    input_tokens: int
    output_tokens: int
    duration_ms: int


class OfficialAiProvider(Protocol):
    name: str

    def generate_questions(self, *, question_count: int, scenario: str = "success") -> GenerationResult: ...
