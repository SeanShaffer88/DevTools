"""Capture only the explicit owned window handle supplied by native-smoke.ps1; no desktop capture."""
import ctypes as c
from ctypes import wintypes as w
import struct
import sys

user, gdi = c.WinDLL('user32', use_last_error=True), c.WinDLL('gdi32', use_last_error=True)
user.GetWindowDC.argtypes = [w.HWND]
user.GetWindowDC.restype = w.HDC
gdi.CreateCompatibleDC.argtypes = [w.HDC]
gdi.CreateCompatibleDC.restype = w.HDC
gdi.CreateCompatibleBitmap.argtypes = [w.HDC, c.c_int, c.c_int]
gdi.CreateCompatibleBitmap.restype = w.HBITMAP
gdi.SelectObject.argtypes = [w.HDC, w.HGDIOBJ]
gdi.SelectObject.restype = w.HGDIOBJ
gdi.GetDIBits.argtypes = [w.HDC,w.HBITMAP,w.UINT,w.UINT,c.c_void_p,c.c_void_p,w.UINT]
gdi.DeleteObject.argtypes=[w.HGDIOBJ]
gdi.DeleteDC.argtypes=[w.HDC]
user.ReleaseDC.argtypes=[w.HWND,w.HDC]
user.PrintWindow.argtypes=[w.HWND,w.HDC,w.UINT]
user.GetWindowRect.argtypes=[w.HWND,c.POINTER(w.RECT)]
hwnd=int(sys.argv[1]); rect=w.RECT()
if not hwnd or not user.GetWindowRect(hwnd,c.byref(rect)):
    raise RuntimeError('No owned window rectangle')
width,height=rect.right-rect.left,rect.bottom-rect.top
if not 1<=width<=4096 or not 1<=height<=4096: raise RuntimeError('Window bounds exceed capture budget')
dc=user.GetWindowDC(hwnd); mem=gdi.CreateCompatibleDC(dc); bmp=gdi.CreateCompatibleBitmap(dc,width,height); old=gdi.SelectObject(mem,bmp)
try:
    if not user.PrintWindow(hwnd,mem,2): raise RuntimeError('PrintWindow failed')
    header=struct.pack('<IiiHHIIiiII',40,width,height,1,32,0,width*height*4,0,0,0,0)
    info=c.create_string_buffer(header+bytes(16)); pixels=c.create_string_buffer(width*height*4)
    if not gdi.GetDIBits(mem,bmp,0,height,pixels,info,0): raise RuntimeError('GetDIBits failed')
    with open(sys.argv[2],'wb') as f: f.write(struct.pack('<2sIHHI',b'BM',54+len(pixels),0,0,54)+header+pixels.raw)
finally:
    gdi.SelectObject(mem,old);gdi.DeleteObject(bmp);gdi.DeleteDC(mem);user.ReleaseDC(hwnd,dc)
