from pathlib import Path
p=Path('lib/QualityUiWorker.ps1');s=p.read_text()
s=s.replace(' [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();\n','').replace(' [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h,uint flags);\n','').replace(' [DllImport("user32.dll")] public static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);\n','')
start=s.index(' $root=[Windows.Automation.AutomationElement]::FromHandle')
end=s.index(' $file=Get-Item',start)
traverse=s[start:end]
traverse=traverse.replace(' while($queue.Count){',' while($queue.Count){Check-Identity;')
s=s[:start]+' Capture-Tree\n'+s[end:]
pos=s.index('try {')
s=s[:pos]+'function Capture-Tree {\n $result.truncated=$false\n'+traverse+'}\n'+s[pos:]
a=s.index('    $foreground=');b=s.index('\n   }else',a)
s=s[:a]+"    throw 'Unsupported: Tab requires an app-owned navigation adapter; global keyboard injection is disabled.'"+s[b:]
a=s.index(' Check-Identity;foreach($item in $script:items)');b=s.index('; $result.status',a) if '; $result.status' in s[a:] else s.index(';$result.status',a)
s=s[:a]+' Check-Identity;Capture-Tree;$result.nodes=@($script:items|ForEach-Object {$_.snapshot})'+s[b:]
# traversal variables must be visible to ownership checks
s=s.replace('$root=[Windows.Automation.AutomationElement]::FromHandle','$script:root=[Windows.Automation.AutomationElement]::FromHandle').replace('$walker=[Windows.Automation.TreeWalker]::ControlViewWalker','$script:walker=[Windows.Automation.TreeWalker]::ControlViewWalker')
p.write_text(s)
p=Path('Test-WindowsUi.ps1');s=p.read_text().replace('Invoke/SetFocus/SetValue/Tab workflow only.','Invoke/SetFocus/SetValue workflow only. Tab is Unsupported (exit 3).');p.write_text(s)
p=Path('Invoke-NativeMemoryTest.ps1');s=p.read_text();a=s.index(' $asan=@(');b=s.index('\n $runArgs=',a)
s=s[:a]+''' $runtimeByArchitecture=@{x64='clang_rt.asan_dynamic-x86_64.dll';x86='clang_rt.asan_dynamic-i386.dll';Arm64='clang_rt.asan_dynamic-aarch64.dll'}
 $runtimeName=$runtimeByArchitecture[$pe.image.Architecture]
 $asan=@($pe.image.Imports|Where-Object {$runtimeName -and [string]::Equals($_.Library,$runtimeName,[StringComparison]::OrdinalIgnoreCase)})
 $symbols=@($asan|ForEach-Object {$_.Symbols}|Where-Object {$_.Name -cmatch '^__asan_(init|version_mismatch_check_v[0-9]+|report_(load|store)[0-9]+|report_(load|store)_n|register_globals|unregister_globals|poison_stack_memory|unpoison_stack_memory)$'})
 $hasFlag=@($plan.compileArguments|Where-Object {[string]::Equals($_,'/fsanitize=address',[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($_,'-fsanitize=address',[StringComparison]::Ordinal)}).Count -gt 0
 $instrumented=$pe.valid -and $asan.Count -gt 0 -and $symbols.Count -gt 0 -and $hasFlag
 $r.findings+=@{id='asan.importEvidence';status=if($instrumented){'Pass'}else{'Unknown'};runtimeImports=@($asan|ForEach-Object{$_.Library});instrumentationSymbols=@($symbols|ForEach-Object{$_.Name});buildFlagPresent=$hasFlag}
 if(-not $instrumented){$r.status='Unknown';$r.error='Supported architecture-matched ASan runtime, instrumentation imports and explicit address-sanitizer build flag are required; execution was not claimed instrumented.';$code=3}else{'''+s[b:]
s=s.replace('Only recognizable dynamic ASan runtime imports are supported as instrumentation evidence.','Runtime imports and build flags are limited metadata evidence; they cannot certify instrumentation of all code.')
p.write_text(s)
