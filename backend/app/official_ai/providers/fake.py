import time

from app.official_ai.providers.base import GenerationResult


class FakeAiProvider:
    """Deterministic development provider. It never calls a paid model API."""

    name = "fake"

    def generate_questions(self, *, question_count: int, scenario: str = "success") -> GenerationResult:
        started = time.perf_counter()
        failures = {
            "timeout": "generation_timeout",
            "invalid_json": "provider_invalid_json",
            "provider_error": "provider_unavailable",
        }
        if scenario in failures:
            raise RuntimeError(failures[scenario])
        questions = [
            {
                "question_type": "choice",
                "question": f"模拟官方 AI 题目 {index + 1}",
                "options": ["A", "B", "C", "D"],
                "answer": "A",
                "explanation": "这是 FakeAIProvider 生成的测试题，不消耗真实 API 额度。",
            }
            for index in range(question_count)
        ]
        duration_ms = max(1, round((time.perf_counter() - started) * 1000))
        return GenerationResult(
            questions=questions,
            input_tokens=question_count * 35,
            output_tokens=question_count * 80,
            duration_ms=duration_ms,
        )
