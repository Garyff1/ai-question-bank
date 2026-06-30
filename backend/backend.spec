# -*- mode: python ; coding: utf-8 -*-

hiddenimports = [
    "app.app",
    "app.routers.auth",
    "app.routers.materials",
    "app.routers.questions",
    "app.routers.practice",
    "app.routers.stats",
    "app.routers.api_config",
    "app.services.ai_service",
    "app.services.file_service",
    "app.utils.auth",
    "uvicorn.lifespan.on",
    "uvicorn.loops.auto",
    "uvicorn.protocols.http.auto",
    "uvicorn.protocols.http.h11_impl",
    "sqlalchemy.dialects.sqlite",
    "passlib.handlers.bcrypt",
]


a = Analysis(
    ["main.py"],
    pathex=["."],
    binaries=[],
    datas=[],
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        "passlib.tests",
        "sqlalchemy.testing",
        "numpy.testing",
        "httptools",
        "uvloop",
        "watchfiles",
        "watchgod",
        "websockets",
    ],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="backend",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=True,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
