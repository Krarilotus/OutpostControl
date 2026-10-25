Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class F {
  [DllImport(@"H:\steam\steamapps\common\Stronghold Crusader Extreme UCP3 new\ucp\code\vendor\fasm\fasm.dll", CallingConvention=CallingConvention.StdCall)]
  public static extern int fasm_Assemble(byte[] s, byte[] m, int size, short passes, IntPtr pipe);
}
'@
Get-ChildItem "C:\Users\Monsterfish_\AppData\Local\Temp\shcw\outpost\asm\*.asm" | ForEach-Object {
  $mem = New-Object byte[] 64000
  $src = [Text.Encoding]::ASCII.GetBytes([IO.File]::ReadAllText($_.FullName) + [char]0)
  $r = [F]::fasm_Assemble($src, $mem, 64000, 100, [IntPtr]::Zero)
  $err = [BitConverter]::ToInt32($mem, 4)
  $len = [BitConverter]::ToInt32($mem, 4)
  if ($r -eq 0) { $len = [BitConverter]::ToInt32($mem, 4) }
  "{0} result={1} code={2}" -f $_.Name, $r, $err
}
