Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Form]$form=New-Object -TypeName System.Windows.Forms.Form;
[System.Windows.Forms.TextBox] $txtbox = New-Object System.Windows.Forms.TextBox;
$txtbox.Location=New-Object -TypeName System.Drawing.Point -ArgumentList (20, 20);
$txtbox.Text='Hello';
$txtbox.Dock=[System.Windows.Forms.DockStyle]::Fill;
$txtbox.Multiline=$TRUE;
$form.Controls.Add($txtbox);
$form.Size= New-Object -TypeName System.Drawing.Size  -ArgumentList (800, 400);
$form.Text="Hello world";
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen;
$form.FormBorderStyle =[System.Windows.Forms.FormBorderStyle]::None;
$form.add_Load({
    $dir = dir 'c:\';
    $files =  $dir|sort Name|sort PSIsContainer -Descending;
    $txtbox.Text="C:\";
 
    foreach($file in $files){
        $txtbox.Text += [System.Environment]::NewLine;
        if($file.PSIsContainer -eq $false){
            $txtbox.Text += "├ ❐";
        }else{
            $txtbox.Text += "├ ";
        }
        $txtbox.Text += $file;
        $txtbox.SelectionStart=$txtbox.Text.Length-1;
        $txtbox.ScrollToCaret();
        [System.Windows.Forms.Application]::DoEvents();
    }
});
$form.GetType().GetEvents()|select Name|sort Name;
#Get-Member -InputObject $form|where name -like '*load*'
Write-Host $txtbox.Text -BackgroundColor White -ForegroundColor DarkBlue
$form.ShowDialog();
Write-Host $txtbox.Text -BackgroundColor White -ForegroundColor DarkBlue
