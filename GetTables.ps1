
#パラメタを指定する
param (
    [string]$strServer   =  $( Read-Host "SQL Server        "), #DBサーバーIP Address を指定
    [string]$strDatabase =  $( Read-Host "Database Name     "), #データベース名を指定
    [string]$UserId =  $( Read-Host "User Id           "), #User Idを指定
    [string]$Psw =     $( Read-Host "Password          "), #Passwordを指定
    [int]$Days =     0,     #$( Read-Host "N日前のオブジェクトを取得する（N=?）"),     #更新日数
    [bool]$onefile =   0,   #[bool][int]$(Read-host "一つファイルにまとめるか?(1=Yes,0=No)"),
    [bool]$useUI =     0, #[bool][int]$(Read-host "USE GUI?(1=Yes,0=No)"),
    [string]$filter =    $(Read-host "object name pattern")
 );

function getcolumns([string]$tablename){
[string] getcolumnSql = @"
select 
a.name,
a.system_type_name as type,
B.is_hidden,
B.is_identity,
B.is_nullable,
C.definition,
CASE WHEN E.column_id is not null then 1 else 0 end as Is_Primary,
D.name as primarykey
from 
sys.dm_exec_describe_first_result_set('Select * from $tablename',null,null) A
inner join sys.columns B ON( B.object_id=object_id('$tablename') AND A.name=b.name )
left outer join sys.computed_columns C ON(A.name=C.name and C.object_id = object_id('$tablename') and A.is_computed_column=1)
left outer join sys.indexes D ON(B.object_id=D.object_id and D.is_primary_key=1)
left outer join sys.index_columns E ON(D.object_id=E.object_id and B.column_id=E.column_id and d.index_id=e.index_id)
"@;
}
function getIndexs([string]$tablename){
[string] $sql = @"declare @Table as nvarchar(200)='$tablename'
declare @indexTable as table(
	index_name nvarchar(128),
	index_desc nvarchar(max),
	index_keys nvarchar(max)
)
insert into @indexTable exec sp_helpindex @table
select 
A.index_keys,b.name,
b.is_primary_key,
'CREATE ' + CAST(B.type_desc COLLATE Japanese_CI_AS  AS nvarchar(200) )  + ' INDEX [' + B.name +'] ON [' +@Table +'] (' + REPLACE(A.index_keys,'(-)',' DESC ') + ')
with  (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
',
b.is_unique,
b.is_padded,
b.is_primary_key
from 
@indexTable A inner join sys.indexes  B 
ON(A.index_name=b.name AND B.object_id = OBJECT_ID(@Table))
"@;

}

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

#フォーム内容を取得する
$cmd = $conn.CreateCommand();
$cmd.CommandText=@"
SELECT 
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

