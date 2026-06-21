import json
import re
import httpx
from app.config import settings


def generate_questions(
    text: str,
    question_type: str,
    question_count: int,
    target_audience: str = "通用",
    api_key: str | None = None,
    api_base: str | None = None,
    model: str | None = None,
) -> list[dict]:
    """
    调用大模型 API 生成题目。
    支持传入自定义 api_key/api_base/model，如果不传则使用 .env 配置。
    """
    prompt = _build_prompt(text, question_type, question_count, target_audience)

    try:
        result = _call_llm(prompt, api_key, api_base, model)
        questions = _parse_response(result, question_type)
        if len(questions) > 0:
            return questions[:question_count]
    except Exception:
        pass

    # 重试一次
    try:
        result = _call_llm(prompt, api_key, api_base, model)
        questions = _parse_response(result, question_type)
        if len(questions) > 0:
            return questions[:question_count]
    except Exception as e:
        raise RuntimeError(f"AI生成题目失败，请稍后重试: {str(e)}")

    raise RuntimeError("AI生成题目失败，请检查API配置或稍后重试")


def _build_prompt(text: str, question_type: str, count: int, target_audience: str) -> str:
    type_desc = "选择题（单选题）" if question_type == "choice" else "填空题"
    format_example = (
        """
[
  {
    "question": "HTTP 协议默认使用哪个端口？",
    "options": ["A. 21", "B. 80", "C. 443", "D. 8080"],
    "answer": "B",
    "explanation": "HTTP 协议默认使用 80 端口，HTTPS 使用 443 端口。"
  }
]
"""
        if question_type == "choice"
        else """
[
  {
    "question": "HTTP 协议默认使用 ____ 端口。",
    "answer": ["80"],
    "explanation": "HTTP 协议默认使用 80 端口。"
  }
]
"""
    )

    audience_guide = ""
    if target_audience and target_audience != "通用":
        audience_guide = f"""
【重要】目标用户群体：{target_audience}
请根据该年龄段/学段的认知水平调整出题难度和语言表达：
- 如果面向小学生（1-6年级），使用简单直白的语言，选项不要太长，多用生活化的例子
- 如果面向初中生（7-9年级），语言可以稍正式但不要太复杂
- 如果面向高中生/大学生，可以使用规范的学术表达
- 题干和选项的表述必须让目标群体的学生能够理解
"""

    prompt = f"""你是一位专业的题目出题老师。请根据以下学习资料，生成 {count} 道{type_desc}。
{audience_guide}

要求：
1. 题目必须严格基于资料内容，不要出资料中没有的内容
2. 答案必须准确无误
3. 每个题目需附带详细解析，解析要通俗易懂
4. 返回严格的 JSON 数组格式，不要有多余文字

格式示例（严格遵循此 JSON 结构）：
{format_example}

学习资料内容：
---
{text}
---
请生成 {count} 道{type_desc}，只返回 JSON 数组："""
    return prompt


def _call_llm(prompt: str, api_key: str | None = None, api_base: str | None = None, model: str | None = None) -> str:
    key = api_key or settings.OPENAI_API_KEY
    base = (api_base or settings.OPENAI_API_BASE).rstrip("/")
    mdl = model or settings.AI_MODEL

    if not key or key == "sk-your-api-key-here":
        raise ValueError("请先配置 API Key（在设置页面中填入）")

    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": mdl,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.7,
        "max_tokens": 4096,
    }

    url = f"{base}/chat/completions"

    with httpx.Client(timeout=120) as client:
        resp = client.post(url, json=payload, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        return data["choices"][0]["message"]["content"]


def _parse_response(content: str, question_type: str) -> list[dict]:
    json_match = re.search(r"```(?:json)?\s*(\[[\s\S]*?\])\s*```", content)
    if json_match:
        content = json_match.group(1)

    content = content.strip()
    if content.startswith("["):
        questions = json.loads(content)
    else:
        start = content.find("[")
        end = content.rfind("]") + 1
        if start >= 0 and end > start:
            questions = json.loads(content[start:end])
        else:
            raise ValueError("无法解析 AI 返回结果")

    if not isinstance(questions, list):
        raise ValueError("AI 返回结果不是数组")

    validated = []
    for q in questions:
        if "question" not in q or "answer" not in q or "explanation" not in q:
            continue
        if question_type == "choice" and "options" not in q:
            continue
        validated.append(q)

    return validated
