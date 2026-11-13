# SystemProxyGuard — 开机静默强制关闭系统代理

代理软件(如 Clash / v2rayN)会修改系统代理开关并写入端口。如果关机前没在软件里
关闭系统代理,注册表里就会残留 `ProxyEnable = 1` 和指向 `127.0.0.1:端口` 的地址;
下次开机时代理软件还没运行,所有程序却仍然往那个端口发请求,于是**整台电脑断网**。

本工具在**每次登录时静默运行**,把系统代理开关强制置为关闭:
`HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ProxyEnable = 0`。
不改动 `ProxyServer` 里保存的端口地址(代理软件下次运行时会自己重新写入)。

## 组成

| 文件 | 作用 |
| --- | --- |
| `Disable-SystemProxy.bat` | 核心批处理:把 `ProxyEnable` 强制改为 `0`,并写运行日志 |
| `Refresh-ProxySettings.ps1` | 通知 WinINET 设置已变更,让已在运行的进程重新读取(尽力而为) |
| `Disable-SystemProxy.vbs` | 无窗口启动器:用 `wscript` 隐藏方式运行 `.bat`,不闪任何窗口 |
| `Install.cmd` | **双击安装(推荐)**:纯 cmd 实现的安装器,把文件放到本机并注册开机启动 |
| `SystemProxyGuard-Setup.cmd` | **单文件安装包**:整个工具打包成这一个文件,只拷它到别的电脑双击即可 |
| `Install.ps1` | PowerShell 版安装器(与 `Install.cmd` 等价,供命令行使用) |
| `Uninstall.ps1` | 卸载:删除启动文件夹里的 `.vbs` 和脚本目录 |
| `build-single-file.ps1` | 开发者用:从三个源文件重新生成 `SystemProxyGuard-Setup.cmd` |
| `verify-silent.ps1` | 自检:模拟残留代理,验证"被关闭"且"全程无窗口" |

## 原理

Windows 的"开机自动运行 + 完全静默"不需要管理员权限,做法是:

1. 用户启动文件夹 `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\`
   里放一个 `.vbs` → 登录时自动执行;
2. `.vbs` 由 `wscript.exe` 解释,本身没有控制台窗口;
3. `.vbs` 用 `shell.Run "cmd /c ...bat", 0, False` 以**隐藏窗口**方式调用批处理;
4. 批处理只做一次注册表写入,毫秒级结束。

全程无任务栏图标、无黑窗口闪现。因为改的是 `HKCU`(当前用户)而非 `HKLM`,
所以用启动文件夹而不是计划任务,既不需要提权,也不会改错用户配置。

## 安装(本机)

在资源管理器中双击 `Install.cmd`(最简单),或者打开命令行:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File Install.ps1
```

安装完成后会打印当前 `ProxyEnable` 值(应为 0),并且:

- `%LOCALAPPDATA%\SystemProxyGuard\` 下有三个运行文件;
- 启动文件夹里出现 `Disable-SystemProxy.vbs`。

## 安装(给其他电脑)

**方式一:整个文件夹拷过去,双击 `Install.cmd`。**
透明、可审计,需要把 `Disable-SystemProxy.bat`、`Refresh-ProxySettings.ps1`、
`Disable-SystemProxy.vbs`、`Install.cmd` 四个文件一起拷贝(放同一目录)。

**方式二:只拷 `SystemProxyGuard-Setup.cmd` 这一个文件,双击。**
它是一个自包含安装包:自己解出三个运行文件、放进启动文件夹、立即执行一次。
对"别的电脑"最省事,不需要任何其他文件。

两种方式都:

- **不需要管理员权限**(只写当前用户的 `HKCU` 和用户目录);
- 双击后窗口一闪即关(安装器正常结束),之后每次开机静默运行;
- 若想无提示安装(如在脚本里),加 `/quiet` 参数可跳过结尾的"按任意键继续"。

> 单文件安装器在个别电脑上可能被 SmartScreen / 杀软提示"未知发布者"或
> "自解压脚本",这是因为 `.cmd` 里嵌了 base64 载荷。选择"仍要运行"即可;
> 若被拦截,改用方式一(普通文件复制 + 双击 `Install.cmd`)。

## 验证

- 运行日志:`%LOCALAPPDATA%\SystemProxyGuard\disable-proxy.log`,
  每次运行追加一行,例如:
  `[2026/11/11 10:25:33.66] system proxy disabled: ProxyEnable 0x1 -> 0x0`
- 打开"设置 → 网络和 Internet → 代理",确认"使用代理服务器"为关闭状态。
- 手动模拟一次:双击启动文件夹里的 `Disable-SystemProxy.vbs`,日志应当多出一行。
- 完整自检(含无窗口校验):`powershell -NoProfile -ExecutionPolicy Bypass -File verify-silent.ps1`

## 卸载

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File Uninstall.ps1
```

或直接删除启动文件夹里的 `Disable-SystemProxy.vbs`(立即失效),再删除
`%LOCALAPPDATA%\SystemProxyGuard\` 目录。

## 注意

- 脚本按需求**无条件**关闭系统代理。"设置 → 代理"里手动打开的开关,
  在下次登录时同样会被关掉;如果需要用系统代理,请通过代理软件重新开启。
- 只处理"系统代理开关"(WinINET)。不涉及 WinHTTP 代理(`netsh winhttp`)、
  PAC 自动配置(`AutoConfigURL`)或 TUN/虚拟网卡模式。
- 想要开机时先等代理软件启动再判断?本工具刻意**不延迟执行**,以保证
  清掉的是上次关机遗留的孤儿代理设置;代理软件随后自己启动并设置代理,
  网络仍会正常工作。
- 修改了三个运行文件中的任何一个之后,记得重跑
  `powershell -NoProfile -ExecutionPolicy Bypass -File build-single-file.ps1`
  重新生成单文件安装包,否则 `SystemProxyGuard-Setup.cmd` 里还是旧版本。
