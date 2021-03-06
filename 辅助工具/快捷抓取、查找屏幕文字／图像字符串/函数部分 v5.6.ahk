﻿
;---- 将后面的函数附加到自己的脚本中 ----


;-----------------------------------------
; 查找屏幕文字/图像字库及OCR识别
; 注意：参数中的x、y为中心点坐标，w、h为左右上下偏移
; cha1、cha0分别为0、_字符的容许误差百分比
;-----------------------------------------
查找文字(x,y,w,h,wz,c,ByRef rx="",ByRef ry="",ByRef ocr=""
  , cha1=0, cha0=0)
{
  xywh2xywh(x-w,y-h,2*w+1,2*h+1,x,y,w,h)
  if (w<1 or h<1)
    Return, 0
  bch:=A_BatchLines
  SetBatchLines, -1
  ;--------------------------------------
  GetBitsFromScreen(x,y,w,h,Scan0,Stride,bits)
  ;--------------------------------------
  ; 设定图内查找范围，注意不要越界
  sx:=0, sy:=0, sw:=w, sh:=h
  if PicOCR(Scan0,Stride,sx,sy,sw,sh,wz,c
    ,rx,ry,ocr,cha1,cha0)
  {
    rx+=x, ry+=y
    SetBatchLines, %bch%
    Return, 1
  }
  ; 容差为0的若失败则使用 5% 的容差再找一次
  if (cha1=0 and cha0=0)
    and PicOCR(Scan0,Stride,sx,sy,sw,sh,wz,c
      ,rx,ry,ocr,0.05,0.05)
  {
    rx+=x, ry+=y
    SetBatchLines, %bch%
    Return, 1
  }
  SetBatchLines, %bch%
  Return, 0
}

;-- 规范输入范围在屏幕范围内
xywh2xywh(x1,y1,w1,h1,ByRef x,ByRef y,ByRef w,ByRef h)
{
  ; 获取包含所有显示器的虚拟屏幕范围
  SysGet, zx, 76
  SysGet, zy, 77
  SysGet, zw, 78
  SysGet, zh, 79
  left:=x1, right:=x1+w1-1, up:=y1, down:=y1+h1-1
  left:=left<zx ? zx:left, right:=right>zx+zw-1 ? zx+zw-1:right
  up:=up<zy ? zy:up, down:=down>zy+zh-1 ? zy+zh-1:down
  x:=left, y:=up, w:=right-left+1, h:=down-up+1
}

;-- 获取屏幕图像的内存数据，图像包括透明窗口
GetBitsFromScreen(x,y,w,h,ByRef Scan0,ByRef Stride,ByRef bits)
{
  VarSetCapacity(bits, w*h*4, 0)
  Ptr:=A_PtrSize ? "Ptr" : "UInt"
  ; 桌面窗口对应包含所有显示器的虚拟屏幕
  win:=DllCall("GetDesktopWindow", Ptr)
  hDC:=DllCall("GetWindowDC", Ptr,win, Ptr)
  mDC:=DllCall("CreateCompatibleDC", Ptr,hDC, Ptr)
  hBM:=DllCall("CreateCompatibleBitmap", Ptr,hDC
    , "int",w, "int",h, Ptr)
  oBM:=DllCall("SelectObject", Ptr,mDC, Ptr,hBM, Ptr)
  DllCall("BitBlt", Ptr,mDC, "int",0, "int",0, "int",w, "int",h
    , Ptr,hDC, "int",x, "int",y, "uint",0x00CC0020|0x40000000)
  ;--------------------------
  VarSetCapacity(bi, 40, 0)
  NumPut(40, bi, 0, "int"), NumPut(w, bi, 4, "int")
  NumPut(-h, bi, 8, "int"), NumPut(1, bi, 12, "short")
  NumPut(bpp:=32, bi, 14, "short"), NumPut(0, bi, 16, "int")
  ;--------------------------
  DllCall("GetDIBits", Ptr,mDC, Ptr,hBM
    , "int",0, "int",h, Ptr,&bits, Ptr,&bi, "int",0)
  DllCall("SelectObject", Ptr,mDC, Ptr,oBM)
  DllCall("DeleteObject", Ptr,hBM)
  DllCall("DeleteDC", Ptr,mDC)
  DllCall("ReleaseDC", Ptr,win, Ptr,hDC)
  Scan0:=&bits, Stride:=((w*bpp+31)//32)*4
}

;-----------------------------------------
; 图像内查找文字/图像字符串及OCR函数
;-----------------------------------------
PicOCR(Scan0, Stride, sx, sy, sw, sh, wenzi, c
  , ByRef rx, ByRef ry, ByRef ocr, cha1, cha0)
{
  static MyFunc
  if !MyFunc
  {
    x32:="5589E55383C4808B45240FAF451C8B5520C1E20201D0894"
    . "5F08B5528B80000000029D0C1E00289C28B451C01D08945ECC"
    . "745E800000000C745D400000000C745D0000000008B4528894"
    . "5CC8B452C8945C8C745C400000000837D08000F85660100008"
    . "B450CC1E81025FF0000008945C08B450CC1E80825FF0000008"
    . "945BC8B450C25FF0000008945B88B4510C1E81025FF0000008"
    . "945B48B4510C1E80825FF0000008945B08B451025FF0000008"
    . "945AC8B45C02B45B48945A88B45BC2B45B08945A48B45B82B4"
    . "5AC8945A08B55C08B45B401D089459C8B55BC8B45B001D0894"
    . "5988B55B88B45AC01D0894594C745F400000000E9BF000000C"
    . "745F800000000E99D0000008B45F083C00289C28B451801D00"
    . "FB6000FB6C03B45A87C798B45F083C00289C28B451801D00FB"
    . "6000FB6C03B459C7F618B45F083C00189C28B451801D00FB60"
    . "00FB6C03B45A47C498B45F083C00189C28B451801D00FB6000"
    . "FB6C03B45987F318B55F08B451801D00FB6000FB6C03B45A07"
    . "C1E8B55F08B451801D00FB6000FB6C03B45947F0B8B55E88B4"
    . "53401D0C600318345F8018345F0048345E8018B45F83B45280"
    . "F8C57FFFFFF8345F4018B45EC0145F08B45F43B452C0F8C35F"
    . "FFFFFE917020000837D08010F85A30000008B450C83C001C1E"
    . "00789450CC745F400000000EB7DC745F800000000EB628B45F"
    . "083C00289C28B451801D00FB6000FB6C06BD0268B45F083C00"
    . "189C18B451801C80FB6000FB6C06BC04B8D0C028B55F08B451"
    . "801D00FB6000FB6D089D0C1E00429D001C83B450C730B8B55E"
    . "88B453401D0C600318345F8018345F0048345E8018B45F83B4"
    . "5287C968345F4018B45EC0145F08B45F43B452C0F8C77FFFFF"
    . "FE96A010000C745F400000000EB7BC745F800000000EB608B5"
    . "5E88B45308D0C028B45F083C00289C28B451801D00FB6000FB"
    . "6C06BD0268B45F083C00189C38B451801D80FB6000FB6C06BC"
    . "04B8D1C028B55F08B451801D00FB6000FB6D089D0C1E00429D"
    . "001D8C1F80788018345F8018345F0048345E8018B45F83B452"
    . "87C988345F4018B45EC0145F08B45F43B452C0F8C79FFFFFF8"
    . "B452883E8018945908B452C83E80189458CC745F401000000E"
    . "9B0000000C745F801000000E9940000008B45F40FAF452889C"
    . "28B45F801D08945E88B55E88B453001D00FB6000FB6D08B450"
    . "C01D08945EC8B45E88D50FF8B453001D00FB6000FB6C03B45E"
    . "C7F488B45E88D50018B453001D00FB6000FB6C03B45EC7F328"
    . "B45E82B452889C28B453001D00FB6000FB6C03B45EC7F1A8B5"
    . "5E88B452801D089C28B453001D00FB6000FB6C03B45EC7E0B8"
    . "B55E88B453401D0C600318345F8018B45F83B45900F8C60FFF"
    . "FFF8345F4018B45F43B458C0F8C44FFFFFFC745E800000000E"
    . "9E30000008B45E88D1485000000008B454401D08B008945E08"
    . "B45E08945E48B45E48945F08B45E883C0018D1485000000008"
    . "B454401D08B008945908B45E883C0028D1485000000008B454"
    . "401D08B0089458CC745F400000000EB7CC745F800000000EB6"
    . "78B45F08D50018955F089C28B453801D00FB6003C3175278B4"
    . "5E48D50018955E48D1485000000008B453C01C28B45F40FAF4"
    . "52889C18B45F801C88902EB258B45E08D50018955E08D14850"
    . "00000008B454001C28B45F40FAF452889C18B45F801C889028"
    . "345F8018B45F83B45907C918345F4018B45F43B458C0F8C78F"
    . "FFFFF8345E8078B45E83B45480F8C11FFFFFF8B45D00FAF452"
    . "889C28B45D401D08945E4C745F800000000E909030000C745F"
    . "400000000E9ED0200008B45F40FAF452889C28B45F801C28B4"
    . "5E401D08945F0C745E800000000E9BB0200008B45E883C0018"
    . "D1485000000008B454401D08B008945908B45E883C0028D148"
    . "5000000008B454401D08B0089458C8B55F88B459001D03B45C"
    . "C0F8F770200008B55F48B458C01D03B45C80F8F660200008B4"
    . "5E88D1485000000008B454401D08B008945E08B45E883C0038"
    . "D1485000000008B454401D08B008945888B45E883C0048D148"
    . "5000000008B454401D08B008945848B45E883C0058D1485000"
    . "000008B454401D08B008945DC8B45E883C0068D14850000000"
    . "08B454401D08B008945D88B45883945840F4D4584894580C74"
    . "5EC00000000E9820000008B45EC3B45887D378B55E08B45EC0"
    . "1D08D1485000000008B453C01D08B108B45F001D089C28B453"
    . "401D00FB6003C31740E836DDC01837DDC000F88980100008B4"
    . "5EC3B45847D378B55E08B45EC01D08D1485000000008B45400"
    . "1D08B108B45F001D089C28B453401D00FB6003C30740E836DD"
    . "801837DD8000F885C0100008345EC018B45EC3B45800F8C72F"
    . "FFFFF837DC4000F85840000008B55208B45F801C28B454C891"
    . "08B454C83C0048B4D248B55F401CA89108B454C8D50088B459"
    . "089028B454C8D500C8B458C8902C745C4040000008B45F42B4"
    . "58C8945D08B558C89D001C001D08945C88B558C89D0C1E0020"
    . "1D001C083C0648945CC837DD0007907C745D0000000008B452"
    . "C2B45D03B45C87D338B452C2B45D08945C8EB288B55088B451"
    . "401D03B45F87D1B8B45C48D50018955C48D1485000000008B4"
    . "54C01D0C700FFFFFFFF8B459083E8018945088B45C48D50018"
    . "955C48D1485000000008B454C01D08B55E883C2078910817DC"
    . "4FD0300000F8FA4000000C745EC00000000EB298B55E08B45E"
    . "C01D08D1485000000008B453C01D08B108B45F001D089C28B4"
    . "53401D0C600308345EC018B45EC3B45887CCF8B45F883C0010"
    . "145D48B45282B45D43B45CC0F8D13FDFFFF8B45282B45D4894"
    . "5CCE905FDFFFF90EB0490EB01908345E8078B45E83B45480F8"
    . "C39FDFFFF8345F4018B45F43B45C80F8C07FDFFFF8345F8018"
    . "B45F83B45CC0F8CEBFCFFFF837DC4007508B800000000EB1B9"
    . "08B45C48D1485000000008B454C01D0C70000000000B801000"
    . "00083EC805B5DC24800"
    x64:="554889E54883C480894D108955184489452044894D288B4"
    . "5480FAF45388B5540C1E20201D08945F48B5550B8000000002"
    . "9D0C1E00289C28B453801D08945F0C745EC00000000C745D80"
    . "0000000C745D4000000008B45508945D08B45588945CCC745C"
    . "800000000837D10000F85850100008B4518C1E81025FF00000"
    . "08945C48B4518C1E80825FF0000008945C08B451825FF00000"
    . "08945BC8B4520C1E81025FF0000008945B88B4520C1E80825F"
    . "F0000008945B48B452025FF0000008945B08B45C42B45B8894"
    . "5AC8B45C02B45B48945A88B45BC2B45B08945A48B55C48B45B"
    . "801D08945A08B55C08B45B401D089459C8B55BC8B45B001D08"
    . "94598C745F800000000E9DE000000C745FC00000000E9BC000"
    . "0008B45F483C0024863D0488B45304801D00FB6000FB6C03B4"
    . "5AC0F8C910000008B45F483C0024863D0488B45304801D00FB"
    . "6000FB6C03B45A07F768B45F483C0014863D0488B45304801D"
    . "00FB6000FB6C03B45A87C5B8B45F483C0014863D0488B45304"
    . "801D00FB6000FB6C03B459C7F408B45F44863D0488B4530480"
    . "1D00FB6000FB6C03B45A47C288B45F44863D0488B45304801D"
    . "00FB6000FB6C03B45987F108B45EC4863D0488B45684801D0C"
    . "600318345FC018345F4048345EC018B45FC3B45500F8C38FFF"
    . "FFF8345F8018B45F00145F48B45F83B45580F8C16FFFFFFE95"
    . "9020000837D10010F85B60000008B451883C001C1E00789451"
    . "8C745F800000000E98D000000C745FC00000000EB728B45F48"
    . "3C0024863D0488B45304801D00FB6000FB6C06BD0268B45F48"
    . "3C0014863C8488B45304801C80FB6000FB6C06BC04B8D0C028"
    . "B45F44863D0488B45304801D00FB6000FB6D089D0C1E00429D"
    . "001C83B451873108B45EC4863D0488B45684801D0C60031834"
    . "5FC018345F4048345EC018B45FC3B45507C868345F8018B45F"
    . "00145F48B45F83B45580F8C67FFFFFFE999010000C745F8000"
    . "00000E98D000000C745FC00000000EB728B45EC4863D0488B4"
    . "560488D0C028B45F483C0024863D0488B45304801D00FB6000"
    . "FB6C06BD0268B45F483C0014C63C0488B45304C01C00FB6000"
    . "FB6C06BC04B448D04028B45F44863D0488B45304801D00FB60"
    . "00FB6D089D0C1E00429D04401C0C1F80788018345FC018345F"
    . "4048345EC018B45FC3B45507C868345F8018B45F00145F48B4"
    . "5F83B45580F8C67FFFFFF8B455083E8018945948B455883E80"
    . "1894590C745F801000000E9CA000000C745FC01000000E9AE0"
    . "000008B45F80FAF455089C28B45FC01D08945EC8B45EC4863D"
    . "0488B45604801D00FB6000FB6D08B451801D08945F08B45EC4"
    . "898488D50FF488B45604801D00FB6000FB6C03B45F07F538B4"
    . "5EC4898488D5001488B45604801D00FB6000FB6C03B45F07F3"
    . "88B45EC2B45504863D0488B45604801D00FB6000FB6C03B45F"
    . "07F1D8B55EC8B455001D04863D0488B45604801D00FB6000FB"
    . "6C03B45F07E108B45EC4863D0488B45684801D0C600318345F"
    . "C018B45FC3B45940F8C46FFFFFF8345F8018B45F83B45900F8"
    . "C2AFFFFFFC745EC00000000E9100100008B45EC4898488D148"
    . "500000000488B85880000004801D08B008945E48B45E48945E"
    . "88B45E88945F48B45EC48984883C001488D148500000000488"
    . "B85880000004801D08B008945948B45EC48984883C002488D1"
    . "48500000000488B85880000004801D08B00894590C745F8000"
    . "00000E98C000000C745FC00000000EB778B45F48D50018955F"
    . "44863D0488B45704801D00FB6003C31752C8B45E88D5001895"
    . "5E84898488D148500000000488B45784801C28B45F80FAF455"
    . "089C18B45FC01C88902EB2D8B45E48D50018955E44898488D1"
    . "48500000000488B85800000004801C28B45F80FAF455089C18"
    . "B45FC01C889028345FC018B45FC3B45947C818345F8018B45F"
    . "83B45900F8C68FFFFFF8345EC078B45EC3B85900000000F8CE"
    . "1FEFFFF8B45D40FAF455089C28B45D801D08945E8C745FC000"
    . "00000E988030000C745F800000000E96C0300008B45F80FAF4"
    . "55089C28B45FC01C28B45E801D08945F4C745EC00000000E93"
    . "70300008B45EC48984883C001488D148500000000488B85880"
    . "000004801D08B008945948B45EC48984883C002488D1485000"
    . "00000488B85880000004801D08B008945908B55FC8B459401D"
    . "03B45D00F8FE10200008B55F88B459001D03B45CC0F8FD0020"
    . "0008B45EC4898488D148500000000488B85880000004801D08"
    . "B008945E48B45EC48984883C003488D148500000000488B858"
    . "80000004801D08B0089458C8B45EC48984883C004488D14850"
    . "0000000488B85880000004801D08B008945888B45EC4898488"
    . "3C005488D148500000000488B85880000004801D08B008945E"
    . "08B45EC48984883C006488D148500000000488B85880000004"
    . "801D08B008945DC8B458C3945880F4D4588894584C745F0000"
    . "00000E9950000008B45F03B458C7D3F8B55E48B45F001D0489"
    . "8488D148500000000488B45784801D08B108B45F401D04863D"
    . "0488B45684801D00FB6003C31740E836DE001837DE0000F88C"
    . "E0100008B45F03B45887D428B55E48B45F001D04898488D148"
    . "500000000488B85800000004801D08B108B45F401D04863D04"
    . "88B45684801D00FB6003C30740E836DDC01837DDC000F88870"
    . "100008345F0018B45F03B45840F8C5FFFFFFF837DC8000F859"
    . "70000008B55408B45FC01C2488B85980000008910488B85980"
    . "000004883C0048B4D488B55F801CA8910488B8598000000488"
    . "D50088B45948902488B8598000000488D500C8B45908902C74"
    . "5C8040000008B45F82B45908945D48B559089D001C001D0894"
    . "5CC8B559089D0C1E00201D001C083C0648945D0837DD400790"
    . "7C745D4000000008B45582B45D43B45CC7D3B8B45582B45D48"
    . "945CCEB308B55108B452801D03B45FC7D238B45C88D5001895"
    . "5C84898488D148500000000488B85980000004801D0C700FFF"
    . "FFFFF8B459483E8018945108B45C88D50018955C84898488D1"
    . "48500000000488B85980000004801D08B55EC83C2078910817"
    . "DC8FD0300000F8FAF000000C745F000000000EB318B55E48B4"
    . "5F001D04898488D148500000000488B45784801D08B108B45F"
    . "401D04863D0488B45684801D0C600308345F0018B45F03B458"
    . "C7CC78B45FC83C0010145D88B45502B45D83B45D00F8D97FCF"
    . "FFF8B45502B45D88945D0E989FCFFFF90EB0490EB01908345E"
    . "C078B45EC3B85900000000F8CBAFCFFFF8345F8018B45F83B4"
    . "5CC0F8C88FCFFFF8345FC018B45FC3B45D00F8C6CFCFFFF837"
    . "DC8007508B800000000EB23908B45C84898488D14850000000"
    . "0488B85980000004801D0C70000000000B8010000004883EC8"
    . "05DC3909090909090909090909090909090"
    MCode(MyFunc, A_PtrSize=8 ? x64:x32)
  }
  ;--------------------------------------
  ; 统计字库文字的个数和宽高，将解释文字存入数组并删除<>
  ;--------------------------------------
  wenzitab:=[], num:=0, wz:="", j:=""
  Loop, Parse, wenzi, |
  {
    v:=A_LoopField, txt:="", e1:=cha1, e0:=cha0
    ; 用角括号输入每个字库字符串的识别结果文字
    if RegExMatch(v,"<([^>]*)>",r)
      v:=StrReplace(v,r), txt:=r1
    ; 可以用中括号输入每个文字的两个容差，以逗号分隔
    if RegExMatch(v,"\[([^\]]*)]",r)
    {
      v:=StrReplace(v,r), r2:=""
      StringSplit, r, r1, `,
      e1:=r1, e0:=r2
    }
    ; 记录每个文字的起始位置、宽、高、10字符的数量和容差
    StringSplit, r, v, .
    w:=r1, v:=base64tobit(r2), h:=StrLen(v)//w
    if (r0<2 or w>sw or h>sh or StrLen(v)!=w*h)
      Continue
    len1:=StrLen(StrReplace(v,"0"))
    len0:=StrLen(StrReplace(v,"1"))
    e1:=Round(len1*e1), e0:=Round(len0*e0)
    j.=StrLen(wz) "|" w "|" h
      . "|" len1 "|" len0 "|" e1 "|" e0 "|"
    wz.=v, wenzitab[++num]:=Trim(txt)
  }
  IfEqual, wz,, Return, 0
  ;--------------------------------------
  ; wz 使用Astr参数类型可以自动转为ANSI版字符串
  ; in 输入各文字的起始位置等信息，out 返回结果
  ; ss 等为临时内存，jiange 超过间隔就会加入*号
  ;--------------------------------------
  mode:=InStr(c,"**") ? 2 : InStr(c,"*") ? 1 : 0
  c:=StrReplace(c,"*"), jiange:=5, num*=7
  if mode=0
  {
    c:=StrReplace(c,"0x") . "-0"
    StringSplit, r, c, -
    c:=Round("0x" r1), dc:=Round("0x" r2)
  }
  VarSetCapacity(in,num*4,0), i:=-4
  Loop, Parse, j, |
    if (A_Index<=num)
      NumPut(A_LoopField, in, i+=4, "int")
  VarSetCapacity(gs, sw*sh)
  VarSetCapacity(ss, sw*sh, Asc("0"))
  k:=StrLen(wz)*4
  VarSetCapacity(s1, k, 0), VarSetCapacity(s0, k, 0)
  VarSetCapacity(out, 1024*4, 0)
  if DllCall(&MyFunc, "int",mode, "uint",c, "uint",dc
    , "int",jiange, "ptr",Scan0, "int",Stride
    , "int",sx, "int",sy, "int",sw, "int",sh
    , "ptr",&gs, "ptr",&ss
    , "Astr",wz, "ptr",&s1, "ptr",&s0
    , "ptr",&in, "int",num, "ptr",&out)
  {
    ocr:="", i:=-4  ; 返回第一个文字的中心位置
    x:=NumGet(out,i+=4,"int"), y:=NumGet(out,i+=4,"int")
    w:=NumGet(out,i+=4,"int"), h:=NumGet(out,i+=4,"int")
    rx:=x+w//2, ry:=y+h//2
    While (k:=NumGet(out,i+=4,"int"))
      v:=wenzitab[k//7], ocr.=v="" ? "*" : v
    Return, 1
  }
  Return, 0
}

MCode(ByRef code, hex)
{
  ListLines, Off
  bch:=A_BatchLines
  SetBatchLines, -1
  VarSetCapacity(code, StrLen(hex)//2)
  Loop, % StrLen(hex)//2
    NumPut("0x" . SubStr(hex,2*A_Index-1,2)
      , code, A_Index-1, "char")
  Ptr:=A_PtrSize ? "Ptr" : "UInt"
  DllCall("VirtualProtect", Ptr,&code, Ptr
    ,VarSetCapacity(code), "uint",0x40, Ptr . "*",0)
  SetBatchLines, %bch%
  ListLines, On
}

base64tobit(s) {
  ListLines, Off
  s:=RegExReplace(s,"\s+")
  Chars:="0123456789+/ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    . "abcdefghijklmnopqrstuvwxyz"
  SetFormat, IntegerFast, d
  StringCaseSense, On
  Loop, Parse, Chars
  {
    i:=A_Index-1, v:=(i>>5&1) . (i>>4&1)
      . (i>>3&1) . (i>>2&1) . (i>>1&1) . (i&1)
    s:=StrReplace(s,A_LoopField,v)
  }
  StringCaseSense, Off
  s:=SubStr(s,1,InStr(s,"1",0,0)-1)
  ListLines, On
  Return, s
}

bit2base64(s) {
  ListLines, Off
  s:=RegExReplace(s,"\s+")
  s.=SubStr("100000",1,6-Mod(StrLen(s),6))
  s:=RegExReplace(s,".{6}","|$0")
  Chars:="0123456789+/ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    . "abcdefghijklmnopqrstuvwxyz"
  SetFormat, IntegerFast, d
  Loop, Parse, Chars
  {
    i:=A_Index-1, v:="|" . (i>>5&1) . (i>>4&1)
      . (i>>3&1) . (i>>2&1) . (i>>1&1) . (i&1)
    s:=StrReplace(s,v,A_LoopField)
  }
  ListLines, On
  Return, s
}


/************  机器码的C源码 ************

int __attribute__((__stdcall__)) OCR( int mode
  , unsigned int c, unsigned int dc
  , int jiange, unsigned char * Bmp, int Stride
  , int sx, int sy, int sw, int sh
  , unsigned char * gs, char * ss
  , char * wz, int * s1, int * s0
  , int * in, int num, int * out )
{
  int x, y, o=sy*Stride+sx*4, j=Stride-4*sw, i=0;
  int o1, o2, w, h, max, len1, len0, e1, e0;
  int sx1=0, sy1=0, sw1=sw, sh1=sh, Ptr=0;

  //准备工作一：先将图像各点在ss中转化为01字符
  if (mode==0)    //颜色模式
  {
    int R=(c>>16)&0xFF, G=(c>>8)&0xFF, B=c&0xFF;
    int dR=(dc>>16)&0xFF, dG=(dc>>8)&0xFF, dB=dc&0xFF;
    int R1=R-dR, G1=G-dG, B1=B-dB;
    int R2=R+dR, G2=G+dG, B2=B+dB;
    for (y=0; y<sh; y++, o+=j)
      for (x=0; x<sw; x++, o+=4, i++)
      {
        if ( Bmp[2+o]>=R1 && Bmp[2+o]<=R2
          && Bmp[1+o]>=G1 && Bmp[1+o]<=G2
          && Bmp[o]  >=B1 && Bmp[o]  <=B2 )
            ss[i]='1';
      }
  }
  else if (mode==1)    //灰度阀值模式
  {
    c=(c+1)*128;
    for (y=0; y<sh; y++, o+=j)
      for (x=0; x<sw; x++, o+=4, i++)
        if (Bmp[2+o]*38+Bmp[1+o]*75+Bmp[o]*15<c)
          ss[i]='1';
  }
  else    //mode==2，边缘灰差模式
  {
    for (y=0; y<sh; y++, o+=j)
    {
      for (x=0; x<sw; x++, o+=4, i++)
        gs[i]=(Bmp[2+o]*38+Bmp[1+o]*75+Bmp[o]*15)>>7;
    }
    w=sw-1; h=sh-1;
    for (y=1; y<h; y++)
    {
      for (x=1; x<w; x++)
      {
        i=y*sw+x; j=gs[i]+c;
        if (gs[i-1]>j || gs[i+1]>j
          || gs[i-sw]>j || gs[i+sw]>j)
            ss[i]='1';
      }
    }
  }

  //准备工作二：生成s1、s0查表数组
  for (i=0; i<num; i+=7)
  {
    o=o1=o2=in[i]; w=in[i+1]; h=in[i+2];
    for (y=0; y<h; y++)
    {
      for (x=0; x<w; x++)
      {
        if (wz[o++]=='1')
          s1[o1++]=y*sw+x;
        else
          s0[o2++]=y*sw+x;
      }
    }
  }

  //正式工作：ss中每一点都进行一次全字库匹配
  NextWenzi:
  o1=sy1*sw+sx1;
  for (x=0; x<sw1; x++)
  {
    for (y=0; y<sh1; y++)
    {
      o=y*sw+x+o1;
      for (i=0; i<num; i+=7)
      {
        w=in[i+1]; h=in[i+2];
        if (x+w>sw1 || y+h>sh1)
          continue;
        o2=in[i]; len1=in[i+3]; len0=in[i+4];
        e1=in[i+5]; e0=in[i+6];
        max=len1>len0 ? len1 : len0;
        for (j=0; j<max; j++)
        {
          if (j<len1 && ss[o+s1[o2+j]]!='1' && (--e1)<0)
            goto NoMatch;
          if (j<len0 && ss[o+s0[o2+j]]!='0' && (--e0)<0)
            goto NoMatch;
        }
        //成功找到文字或图像
        if (Ptr==0)
        {
          out[0]=sx+x; out[1]=sy+y;
          out[2]=w; out[3]=h; Ptr=4;
          //找到第一个字就确定后续查找的上下范围和右边范围
          sy1=y-h; sh1=h*3; sw1=h*10+100;
          if (sy1<0)
            sy1=0;
          if (sh1>sh-sy1)
            sh1=sh-sy1;
        }
        else if (x>mode+jiange)  //与前一字间隔较远就添加*号
          out[Ptr++]=-1;
        mode=w-1; out[Ptr++]=i+7;
        if (Ptr>1021)    //返回的int数组中元素个数不超过1024
          goto ReturnOK;
        //清除找到文字，后续查找的左边范围为找到位置的X坐标+1
        for (j=0; j<len1; j++)
          ss[o+s1[o2+j]]='0';
        sx1+=x+1;
        if (sw1>sw-sx1)
          sw1=sw-sx1;
        goto NextWenzi;
        //------------
        NoMatch:
        continue;
      }
    }
  }
  if (Ptr==0)
    return 0;
  ReturnOK:
  out[Ptr]=0;
  return 1;
}

*/


;============ 脚本结束 =================

;