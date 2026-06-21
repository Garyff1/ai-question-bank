import io
import os

def parse_file(filename: str, content: bytes) -> str:
    ext = os.path.splitext(filename)[1].lower()

    if ext == ".txt":
        return content.decode("utf-8", errors="ignore")

    elif ext == ".pdf":
        return _parse_pdf(content)

    elif ext == ".docx":
        return _parse_docx(content)

    else:
        raise ValueError(f"不支持的文件格式: {ext}")


def _parse_pdf(content: bytes) -> str:
    try:
        import fitz  # PyMuPDF
    except ImportError:
        raise ImportError("请安装 PyMuPDF: pip install PyMuPDF")

    doc = fitz.open(stream=content, filetype="pdf")
    texts = []
    for page in doc:
        texts.append(page.get_text())
    doc.close()
    return "\n".join(texts)


def _parse_docx(content: bytes) -> str:
    try:
        from docx import Document
    except ImportError:
        raise ImportError("请安装 python-docx: pip install python-docx")

    doc = Document(io.BytesIO(content))
    texts = [p.text for p in doc.paragraphs if p.text.strip()]
    return "\n".join(texts)
