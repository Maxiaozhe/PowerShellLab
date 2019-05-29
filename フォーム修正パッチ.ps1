#パラメタを指定する
param (
    [string]$strServer   = $( Read-Host "SQL Server        "), #DBサーバーIP Address を指定
    [string]$strDatabase = $( Read-Host "Database Name     "), #データベース名を指定
    [string]$UserId =      $( Read-Host "User Id           "), #User Idを指定
    [string]$Psw =         $( Read-Host "Password          "), #Passwordを指定
    [int]$IDFRM =          $( Read-Host "Form ID           ")  #FormIDを指定
 );

#データベース接続する
[System.Data.SqlClient.SqlConnection]$conn = New-Object -TypeName System.Data.SqlClient.SqlConnection;
[System.Data.DataTable] $dtt= New-Object -TypeName System.Data.DataTable;
$conn.ConnectionString=@"
Data Source=$strServer;
Initial Catalog=$strDatabase;
User ID=$UserId;Password=$Psw;
"@;
$conn.Open();

#フォーム内容を取得する
$cmd = $conn.CreateCommand();
$cmd.CommandText="Select * from FRMF1000 where IDFRM=@IDFRM";
$cmd.Parameters.AddWithValue("@IDFRM",$IDFRM);

$adp = New-Object -TypeName System.Data.SqlClient.SqlDataAdapter $cmd;
$adp.Fill($dtt);
$cmd.Dispose();
$adp.Dispose();
[string]$form = $dtt.Rows[0].STFRMPG;

#バックアップファイルを出力
$bakfile="C:\FRM00$IDFRM.bak";
Set-Content -Path $bakfile -Value $form;

#不要なHTML Attributeを削除する
[string] $pattern="(?<=\<TD\s[^\>]*)((bgcolor|borderColor|borderColorLight|borderColorDark)\s*\=\s*#[0-9A-F]+)(?=\s*)";
[System.Text.RegularExpressions.RegexOptions]$opt= [System.Text.RegularExpressions.RegexOptions]::IgnoreCase;
[System.Text.RegularExpressions.Regex] $regex = New-Object -TypeName System.Text.RegularExpressions.Regex $pattern, $opt
$form = $regex.Replace($form,"");

#フォーム内容を更新する
$cmd = $conn.CreateCommand();
$cmd.CommandText="UPDATE FRMF1000 SET STFRMPG =@STFRMPG where IDFRM=@IDFRM";
$cmd.Parameters.AddWithValue("@IDFRM",$IDFRM);
$cmd.Parameters.AddWithValue("@STFRMPG",$form);
$cmd.ExecuteNonQuery();
$cmd.Dispose();
$conn.Close();
$conn.Dispose();

#結果出力
$formName = $dtt.Rows[0].NMFRM;
Write-Host @"
フォーム[$formName]の修正完了しました!                                     
下記の場所に変更前のフォームソースをバックアップしています
=====>$bakfile
"@ -ForegroundColor Green;
 $( Read-Host "続けるにはENTERキーを押して下さい");
