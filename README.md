AddonDownloader
===============


## How to package for windows distribution

1. Download this: http://dl.node-webkit.org/v0.10.0-rc2/node-webkit-v0.10.0-rc2-win-ia32.zip
2. Make sure you extract the package to match the path in this file: https://github.com/vikinghug/AddonDownloader/blob/master/builder.ps1
3. Clone this repo: https://github.com/vikinghug/AddonDownloader
4. Enable script execution
-- Open PowerShell as Administrator
-- run `Set-ExecutionPolicy Unrestricted`
5. cd into the AddonDownloader repository
6. run `mkdir releases`
7. run `.\builder.ps1`
8. move the `app.exe` file in the `releases/` folder into the node webkit folder on your desktop
9. run the app
10. 
