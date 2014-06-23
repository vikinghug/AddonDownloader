# path to nw.exe
$nodePath = "$HOME\Desktop\node-webkit-v0.10.0-rc1-win-ia32\nw.exe"

# path to the app project
$appFolder = "$PWD\app"

# nw file path
$nwFile = "$PWD\releases\app.nw"

# release file path
$releaseFile = "$PWD\releases\app.exe"


function ZipFiles( $zipfilename, $sourcedir ) {
  Add-Type -Assembly System.IO.Compression.FileSystem
  $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
  [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir,
  $zipfilename, $compressionLevel, $false)
}

function Debug() {
  if(Test-Path $nwFile){
    Remove-Item $nwFile
  }

  ZipFiles $nwFile $appFolder
  & $nodePath $nwFile
}

function TestFiles() {
  if (Test-Path $nwFile){ Remove-Item $nwFile }
  if (Test-Path $releaseFile){ Remove-Item $releaseFile }
}

echo $nodePath
echo $nwFile
echo $releaseFile
echo $appFolder
TestFiles
ZipFiles $nwFile $appFolder
cmd /c copy /b $nodePath+$nwFile $releaseFile
Remove-Item $nwFile
