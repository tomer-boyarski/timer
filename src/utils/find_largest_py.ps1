Get-ChildItem -Path .\src -Recurse -Filter *.py |
Where-Object {
    ($_.Name -ne '__init__.py')
} |
ForEach-Object {
    $lineCount = [System.IO.File]::ReadAllLines($_.FullName).Count
    [PSCustomObject]@{
        Path  = $_.FullName
        Lines = $lineCount
    }
} | Sort-Object Lines -Descending | Select-Object -First 1 | Format-List
