# Type text into a VirtualBox VM using raw US-layout scancodes (keyboardputstring is unreliable on some boots).
# Usage: . scripts\vbox-type.ps1; VmType "NovaC-test" "ls -l" -Enter
function VmType {
    param([string]$Vm, [string]$Text, [switch]$Enter)
    $vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
    $base = @{}
    $row = @{
        '1'='02';'2'='03';'3'='04';'4'='05';'5'='06';'6'='07';'7'='08';'8'='09';'9'='0a';'0'='0b';'-'='0c';'='='0d'
        'q'='10';'w'='11';'e'='12';'r'='13';'t'='14';'y'='15';'u'='16';'i'='17';'o'='18';'p'='19';'['='1a';']'='1b'
        'a'='1e';'s'='1f';'d'='20';'f'='21';'g'='22';'h'='23';'j'='24';'k'='25';'l'='26';';'='27';"'"='28';'`'='29';'\'='2b'
        'z'='2c';'x'='2d';'c'='2e';'v'='2f';'b'='30';'n'='31';'m'='32';','='33';'.'='34';'/'='35';' '='39'
    }
    $shifted = @{
        '!'='1';'@'='2';'#'='3';'$'='4';'%'='5';'^'='6';'&'='7';'*'='8';'('='9';')'='0';'_'='-';'+'='=';
        '{'='[';'}'=']';':'=';';'"'="'";'<'=',';'>'='.';'?'='/';'|'='\';'~'='`'
    }
    $codes = New-Object System.Collections.Generic.List[string]
    foreach ($ch in $Text.ToCharArray()) {
        $s = [string]$ch
        $needShift = $false
        if ($s -cmatch '[A-Z]') { $s = $s.ToLower(); $needShift = $true }
        elseif ($shifted.ContainsKey($s)) { $s = $shifted[$s]; $needShift = $true }
        if (-not $row.ContainsKey($s)) { throw "unsupported char '$ch'" }
        $make = $row[$s]
        $brk = '{0:x2}' -f ([Convert]::ToInt32($make, 16) -bor 0x80)
        if ($needShift) { $codes.Add('2a') }
        $codes.Add($make); $codes.Add($brk)
        if ($needShift) { $codes.Add('aa') }
    }
    if ($Enter) { $codes.Add('1c'); $codes.Add('9c') }
    # send in chunks so a long string is not dropped
    for ($i = 0; $i -lt $codes.Count; $i += 24) {
        $chunk = $codes.GetRange($i, [Math]::Min(24, $codes.Count - $i))
        & $vbm controlvm $Vm keyboardputscancode @chunk | Out-Null
        Start-Sleep -Milliseconds 120
    }
}
