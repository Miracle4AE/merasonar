' Deniz — yalnızca Windows masaüstü uygulamasını açar (flutter build çıktısı).
' API’yi küçültülmüş pencerede başlatır; ana pencere MeraSonar.exe olur.
' Kullanım: Bu dosyaya çift tıklayın (cmd penceresi açılmaz).

Option Explicit

Dim sh, fso, root, exe, exeDir, apiLine, i

Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)

If Not fso.FileExists(root & "\run_api.cmd") Then
  MsgBox "run_api.cmd bulunamadı. Bu dosyayı proje kök klasöründe tutun:" & vbCrLf & root, vbCritical, "Deniz"
  WScript.Quit 1
End If

apiLine = "cmd /c cd /d " & Chr(34) & root & Chr(34) & " && start " & Chr(34) & "Deniz-API" & Chr(34) & " /min " & Chr(34) & root & "\run_api.cmd" & Chr(34)
sh.Run apiLine, 0, False

' API hazır olana kadar bekle (en fazla ~20 sn)
For i = 1 To 20
  WScript.Sleep 1000
  If ApiHealthOk() Then Exit For
Next

exe = root & "\deniz_app\build\windows\x64\runner\Release\MeraSonar.exe"
If Not fso.FileExists(exe) Then exe = root & "\deniz_app\build\windows\x64\runner\Debug\MeraSonar.exe"

If Not fso.FileExists(exe) Then
  MsgBox "Masaüstü uygulaması (.exe) bulunamadı." & vbCrLf & vbCrLf & _
    "Önce şunu çalıştırın:" & vbCrLf & _
    "cd deniz_app" & vbCrLf & _
    "flutter build windows --release", vbExclamation, "Deniz — Masaüstü"
  WScript.Quit 1
End If

exeDir = fso.GetParentFolderName(exe)
sh.CurrentDirectory = exeDir
' 1 = normal pencere (masaüstü uygulaması)
sh.Run Chr(34) & exe & Chr(34), 1, False

Function ApiHealthOk()
  On Error Resume Next
  Dim http, url
  Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
  If http Is Nothing Then Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
  If http Is Nothing Then
    ApiHealthOk = False
    Exit Function
  End If
  http.Open "GET", "http://127.0.0.1:8000/health", False
  http.SetTimeouts 1500, 1500, 1500, 1500
  http.Send
  If Err.Number <> 0 Then
    ApiHealthOk = False
    Exit Function
  End If
  If http.Status <> 200 Then
    ApiHealthOk = False
    Exit Function
  End If
  Dim body
  body = http.responseText
  ApiHealthOk = (InStr(body, Chr(34) & "status" & Chr(34)) > 0 _
    And InStr(LCase(body), "ok") > 0 _
    And InStr(LCase(body), "merasonar") > 0)
End Function
