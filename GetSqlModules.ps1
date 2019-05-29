
#パラメタを指定する
param (
    [string]$strServer   =  $( Read-Host "SQL Server        "), #DBサーバーIP Address を指定
    [string]$strDatabase =  $( Read-Host "Database Name     "), #データベース名を指定
    [string]$UserId =  $( Read-Host "User Id           "), #User Idを指定
    [string]$Psw =     $( Read-Host "Password          "), #Passwordを指定
    [int]$Days =       0, #$( Read-Host "N日前のオブジェクトを取得する（N=?）"),     #更新日数
    [bool]$onefile =   0, #[bool][int]$(Read-host "一つファイルにまとめるか?(1=Yes,0=No)"),
    [bool]$useUI =     0, #[bool][int]$(Read-host "USE GUI?(1=Yes,0=No)"),
    [string]$filter = $(Read-host "object name pattern")
 );
#出力フォルダ指定
[string]$dir=[System.IO.Path]::GetDirectoryName($PSCommandPath);
[string]$scriptName="$strDatabase_SCRIPT_" + [System.DateTime]::Today.ToString("yyyyMMdd") + ".sql";
if($useUI){
    if(!$onefile)
    {
        [System.Windows.Forms.FolderBrowserDialog] $dlg = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog;
        $dlg.Description="スクリプトの出力フォルダを指定する";
        if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            $dir=$dlg.SelectedPath;
        }
    }
    else{
        [System.Windows.Forms.SaveFileDialog] $fdlg = New-Object -TypeName System.Windows.Forms.SaveFileDialog;
        $fdlg.Title="スクリプトのファイル名を指定してください";
        $fdlg.DefaultExt=".sql";
        if($fdlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            $scriptName=$fdlg.FileName
        }else{
            return
        }
    }
}else{
    if(!$onefile)
    {
        [string]$value =  $( Read-Host "出力フォルダ( ENTER = $dir)")
        if($value -ne ""){
            $dir =$value;
        }
    }
    else{
        [string]$value =  $( Read-Host "出力ファイル名( ENTER = $scriptName)")
        if($value -ne ""){
            $scriptName =$value;
        }
    }
}
#データベース接続する
[System.Data.SqlClient.SqlConnection]$conn = New-Object -TypeName System.Data.SqlClient.SqlConnection;
[System.Data.DataTable] $dtt= New-Object -TypeName System.Data.DataTable;

$conn.ConnectionString=@"
Data Source=$strServer;
Initial Catalog=$strDatabase;
User ID=$UserId;Password=$Psw;
"@;
$conn.Open();

#SQLモジュール内容を取得する
$cmd = $conn.CreateCommand();
$cmd.CommandText=@"
DECLARE @Days int = $days
DECLARE @filter nvarchar(max) = '$filter'
SELECT 
OBJECT_NAME(A.OBJECT_ID) AS NAME,
DEFINITION,
CASE WHEN B.TYPE IN('FN','IF','TF') THEN 'FUNCTION' 
WHEN B.TYPE IN('P') THEN 'PROCEDURE'
END AS CATEGORY,
B.TYPE,
B.TYPE_DESC, 
B.CREATE_DATE,
B.MODIFY_DATE
FROM SYS.SQL_MODULES A INNER JOIN SYS.OBJECTS B ON(A.OBJECT_ID=B.OBJECT_ID)
WHERE 
    (@Days=0 OR B.MODIFY_DATE > DATEADD(DAY,-@Days,GETDATE()))
AND IS_MS_SHIPPED=0
AND TYPE IN('FN','IF','TF','P')
AND (@filter='' OR OBJECT_NAME(A.OBJECT_ID) like @filter) 
ORDER BY
TYPE,MODIFY_DATE DESC,B.NAME
"@


$adp = New-Object -TypeName System.Data.SqlClient.SqlDataAdapter $cmd;
$adp.Fill($dtt);
$cmd.Dispose();
$adp.Dispose();
[System.Data.DataRow] $row;
[System.Text.StringBuilder] $sb= New-Object -TypeName System.Text.StringBuilder;
$sql="";
foreach($row in $dtt.Rows){
    [string]$name = $row.NAME;
    [string]$def  = $row.DEFINITION;
    [string]$cate = $row.CATEGORY;
    [string]$type = $row.TYPE;
    [string]$type_desc =$row.TYPE_DESC;
    [datetime]$modify = [datetime]$row.MODIFY_DATE;
    [string]$strmodify = $modify.ToString("yyyy/MM/dd HH:mm:ss");
    Write-Host "$cate : $name  Modify:$strmodify" -ForegroundColor Green
    $def = $def.replace("[dbo].","");
    $null=$sb.AppendLine("/****** DROP :  $type_desc : [$name]     ******/");
    $null=$sb.AppendLine("DROP $cate IF EXISTS [$name]");
    $null=$sb.AppendLine("GO");
    $null=$sb.AppendLine();
    $null=$sb.AppendLine("/****** CREATE :  $type_desc : [$name]    ******/");
    $null=$sb.AppendLine($def);
    $null=$sb.AppendLine();
    $null=$sb.AppendLine("GO");
    if(!$onefile){
        [string]$subfolder=[System.IO.Path]::Combine( $dir , $cate);
        [string]$filename="$name.sql";
        if(![System.IO.Directory]::Exists($subfolder)){
            mkdir -Path $subfolder -Force|Out-Null
        }
        $psfile= [System.IO.Path]::Combine( $subfolder , $filename);
        Set-Content -Path $psfile -Value $sb.ToString() -Encoding UTF8 -Force;
        $null=$sb.Clear();
    }
} 
if($onefile)
{
    #Scriptファイルを出力
     Set-Content -Path $scriptName -Value $sb.ToString();
}

#結果出力
Write-Host "スクリプトの出力完了しました!" -ForegroundColor Gray;
Read-Host "続けるにはENTERキーを押して下さい";

