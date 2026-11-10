### FastMlx Whisper 快捷命令操作手册

本手册用于将 `batchWhisper.ps1` 配置为全局命令 `srt`，使用户在任意位置均可直接调用。

---

#### 一、适用对象

Windows 系统用户，使用 PowerShell 终端。

---

#### 二、前置条件

- 已安装 PowerShell。
- 已将 `FastMlx_whisper` 项目完整放置在本地目录中，默认路径为：

  ```text
  C:\Users\<用户名>\Github\FastMlx_whisper
  ```

- 项目中包含 `batchWhisper.ps1` 及其依赖文件，且这些文件应保持在同一目录下，不要单独移动。

---

#### 三、配置步骤

1. 打开 PowerShell。

2. 查看当前用户的配置文件路径：

   ```powershell
   echo $PROFILE
   ```

   该路径通常位于用户个人目录下，例如：

   ```text
   C:\Users\<用户名>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
   ```

3. 如果配置文件不存在，先创建：

   ```powershell
   New-Item -ItemType File -Force $PROFILE
   ```

4. 用记事本打开配置文件：

   ```powershell
   notepad $PROFILE
   ```

5. 在文件末尾添加以下内容：

   ```powershell
   function srt {
       $scriptDir = Join-Path $HOME "Github\FastMlx_whisper"
       & "$scriptDir\batchWhisper.ps1" @args
   }
   ```

   其中 `$HOME` 会自动指向当前用户的个人目录，例如：

   ```text
   C:\Users\<用户名>
   ```

6. 保存并关闭记事本。

7. 在 PowerShell 中重新加载配置：

   ```powershell
   . $PROFILE
   ```

   注意：`.` 与 `$PROFILE` 之间有一个空格。

---

#### 四、验证方法

1. 检查命令是否注册成功：

   ```powershell
   Get-Command srt
   ```

   如果返回结果中包含 `Function srt`，说明配置成功。

2. 在任意目录执行：

   ```powershell
   srt
   ```

   如果脚本需要参数，可按原脚本要求继续追加参数。

---

#### 五、常见问题

| 问题 | 处理方法 |
|---|---|
| 提示找不到 `srt` 命令 | 确认已执行 `. $PROFILE`，或重新打开 PowerShell |
| 提示脚本路径不存在 | 确认 `FastMlx_whisper` 目录确实位于用户个人目录下的 `Github` 文件夹中 |
| 修改 `$PROFILE` 后未生效 | 保存文件后执行 `. $PROFILE`，或重启 PowerShell |
| 提示执行策略限制 | 可执行 `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` |

---

#### 六、注意事项

- 不要将 `batchWhisper.ps1` 从其原始目录中移出，否则脚本可能无法找到依赖文件。
- 如果用户将项目放置在其他路径，需要相应修改 `$scriptDir` 的值。
- 本配置仅对当前用户生效，不会影响其他用户账户。

