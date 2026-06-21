import json
import re
import httpx
from app.config import settings


VALID_TYPES = ("choice", "multi_choice", "true_false", "fill", "subjective")


def generate_questions(
    text: str, question_type: str, question_count: int,
    target_audience: str = "通用", api_key: str | None = None,
    api_base: str | None = None, model: str | None = None,
) -> list[dict]:
    prompt = _build_prompt(text, question_type, question_count, target_audience)
    for attempt in range(2):
        try:
            result = _call_llm(prompt, api_key, api_base, model)
            questions = _parse_response(result, question_type)
            if len(questions) > 0:
                return questions[:question_count]
        except Exception as e:
            if attempt == 1:
                raise RuntimeError(f"AI 生成题目失败: {str(e)}")
    raise RuntimeError("AI 生成题目失败，请检查 API 配置或稍后重试")


def _build_prompt(text: str, qtype: str, count: int, audience: str) -> str:
    # 各题型描述 + JSON 示例
    type_specs = {
        "choice": {
            "desc": "单选题（四选一，只有一个正确答案）",
            "format": """[
  {"question":"HTTP默认端口？","options":["A. 21","B. 80","C. 443","D. 8080"],"answer":"B","explanation":"..."}
]"""
        },
        "multi_choice": {
            "desc": "多选题（有 2 个或更多正确答案，答案返回字母数组）",
            "format": """[
  {"question":"以下哪些是Python的不可变类型？（多选）","options":["A. int","B. list","C. str","D. tuple"],"answer":["A","C","D"],"explanation":"int/str/tuple不可变，list可变"}
]"""
        },
        "true_false": {
            "desc": "判断题（给出一个陈述，判断正确还是错误）",
            "format": """[
  {"question":"Python中列表是可变的序列类型。","answer":"正确","explanation":"根据资料，Python列表确实可变"}
]"""
        },
        "fill": {
            "desc": "填空题（用 ____ 表示空位，答案可以是多个）",
            "format": """[
  {"question":"HTTP默认使用 ____ 端口。","answer":["80"],"explanation":"..."}
]"""
        },
        "subjective": {
            "desc": "主观题（简答题/论述题，AI 给出参考答案和评分要点）",
            "format": """[
  {"question":"请简述Python中列表和元组的区别。","answer":"列表可变用[]，元组不可变用()；列表适合频繁修改的数据，元组适合固定数据或作为字典键","explanation":"评分要点：1)可变性 2)语法 3)使用场景"}
]"""
        },
    }
    spec = type_specs.get(qtype, type_specs["choice"])

    audience_guide = ""
    if audience and audience != "通用":
        audience_guide = f"""【重要】目标用户：{audience}
请根据该年龄段的认知水平调整语言难度：
- 小学生：简单直白，多用生活化例子
- 初中生：语言稍正式但不复杂
- 高中生/大学生：可使用规范学术表达
"""

    prompt = f"""你是专业出题老师。根据以下学习资料，生成 {count} 道{spec['desc']}。
{audience_guide}
要求：
1. 题目严格基于资料内容
2. 答案必须准确，解析通俗易懂
3. 多选题的 answer 必须是数组（如 ["A","C"]），且至少 2 个正确选项
4. 判断题 answer 只能是"正确"或"错误"
5. 主观题的 answer 要给出参考答案和评分要点
6. 只返回 JSON 数组，不要多余文字

JSON 格式示例：
{spec['format']}

学习资料：
---
{text[:8000]}
---
生成 {count} 道{spec['desc']}，只返回 JSON 数组："""
    return prompt


def _call_llm(prompt: str, api_key=None, api_base=None, model=None):
    key = api_key or settings.OPENAI_API_KEY
    base = (api_base or settings.OPENAI_API_BASE).rstrip("/")
    mdl = model or settings.AI_MODEL
    if not key or key == "sk-your-api-key-here":
        raise ValueError("请先配置 API Key")

    with httpx.Client(timeout=120) as client:
        resp = client.post(
            f"{base}/chat/completions",
            json={
                "model": mdl,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.7, "max_tokens": 4096
            },
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        )
        resp.raise_for_status()
        return resp.json()["choices"][0]["message"]["content"]


def _parse_response(content: str, qtype: str) -> list[dict]:
    m = re.search(r"```(?:json)?\s*(\[[\s\S]*?\])\s*```", content)
    if m: content = m.group(1)
    content = content.strip()
    if not content.startswith("["):
        s = content.find("["); e = content.rfind("]") + 1
        if s >= 0 and e > s: content = content[s:e]
    questions = json.loads(content)
    if not isinstance(questions, list): raise ValueError("返回不是数组")

    validated = []
    for q in questions:
        if not all(k in q for k in ("question", "answer", "explanation")): continue
        if qtype == "choice" and "options" not in q: continue
        if qtype == "multi_choice" and "options" not in q: continue
        if qtype == "multi_choice" and not isinstance(q["answer"], list): q["answer"] = [q["answer"]]
        validated.append(q)
    return validated
