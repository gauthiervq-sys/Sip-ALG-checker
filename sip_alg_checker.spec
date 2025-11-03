# PyInstaller Specification File

# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis([
    'sip_alg_checker.py',
],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False)

t = Tree(a.pure, a.binaries, a.zipfiles, a.datas)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(pyz,
          a.scripts,
          exclude_binaries=True,
          name='sip_alg_checker',
          debug=False,
          bootloader_ignore_signals=False,
          strip=False,
          upx=True,
          console=True )

coll = COLLECT(exe,
               tkinter=[],
               name='sip_alg_checker')
