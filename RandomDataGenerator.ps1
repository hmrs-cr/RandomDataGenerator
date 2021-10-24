param (
    [int]$RandomRealPerson,
    [int]$RandomFakePerson,
    [int]$RandomPassword,
    [int]$RandomEmail
)

#$ErrorActionPreference = 'SilentlyContinue'
#$DebugPreference = "Continue"

$DataFolder = "$PSScriptRoot/Data"

$dataFileName = "padron_completo.zip"
$dataFileUrl = "https://www.tse.go.cr/zip/padron/$dataFileName"

$diselectdataFile="$DataFolder/Distelec.txt"
$emailprovidersdataFile="$DataFolder/emailproviders.txt"
$padrondataFile="$DataFolder/PADRON_COMPLETO.txt"
$userAgentsdataFile="$DataFolder/userAgents.txt"
$padronRecordSize=120

function Random-Text {
    param (
        [int]$length,
        [string]$extraChars=$null
    )
    
    $lower=(97..122)
    $upper=(65..90)

    $chars=$lower + $upper    

    if ($extraChars -ne $null) 
    {
         $chars = $chars +  ($extraChars.ToCharArray() | ForEach-Object {[int]$_})
    }
    
    return -join($chars | Get-Random -Count $length | ForEach-Object {[char]$_})
}

function Load-Emails {
    if (-not $Global:emailproviders) {
        $Global:emailproviders = $(Get-Content "$emailprovidersdataFile" )

        if (-not $Global:emailproviders) {
            Write-Debug "Failed to load email provider list, usign default."
            $Global:emailproviders = "hotmail.com,outlook.com,gmail.com,yahoo.com,gmail.com,costarricense.cr".Split(",")
        }
        else {
           Write-Debug "$emailprovidersdataFile loaded."
        }
    }
}

function Random-Email {
    param (        
        [string]$user=$null
    )
     
    Load-Emails

    if (-not $user) {
        $user=$((Random-Text -length (Get-Random -Minimum 8 -Maximum 16) -extraChars "_.").ToLower().Trim("."))
    }

    $i = $(0..$($Global:emailproviders.Length-1) | Get-Random)
    $dominio=$($Global:emailproviders[$i])
    return "$user@$dominio"
}

function Random-PseudoReal-Email {
    param (        
        [string]$user=$null,
        [int]$count=1
    )

    1..$count | ForEach-Object {
        if (-not $user) {
            $user = $(Random-Nombre 2)
            
            if ($(Get-Random -Min -1 -Max 2)) {
                if ($(Get-Random -Min -1 -Max 2)) {
                    $user = "$(Random-Apellido 1) $user"
                } else {
                    $user = "$user $(Random-Apellido 1)"
                }
            }
        }

        

        $user = $user.ToLower()
        $s = $(@(".", "_", "-", "", ".", "_", ".") | Get-Random)
        Random-Email $user.replace(" ", $s)
        $user=$null
    }
}

function EnsureDataFiles {
    $exists = $(Test-Path $padrondataFile) -and $(Test-Path $diselectdataFile)
    if ($exists) {
        return $true
    }

    if (-not $(Test-Path -Path $DataFolder)) {
        Write-Host "Data folder does not exist. Creating..."
        New-Item -Path $DataFolder -ItemType Directory
    }

    if (-not $(Test-Path -Path $DataFolder)) {
        Write-Warning "Error creating $DataFolder"
        return $false
    }
    
    $answer = Read-Host "No data files found. Download? (Y/N)"
    if ($answer.ToLower()[0] -eq 'y') {
        Write-Host "Downloading..."
        Invoke-WebRequest -Uri $dataFileUrl -OutFile "$dataFolder/$dataFileName"
        if ($(Test-Path "$dataFolder/$dataFileName")) {
            Expand-Archive -LiteralPath "$dataFolder/$dataFileName" -DestinationPath $dataFolder
            $exists = $(Test-Path $padrondataFile) -and $(Test-Path $diselectdataFile)
            if ($exists) {
                Write-Debug "Extracted"
                Remove-Item "$dataFolder/$dataFileName"
            } else {
                Write-Warning "Failed extract files."
            }
        } else {
            Write-Warning "Download failed."
        }
    }
 
    return $exists
}

function Load-Diselec {
    if (-not $Global:dislect) {
            $Global:dislect = [ordered]@{}
            Get-Content "$diselectdataFile" | ForEach-Object {
                $linesplit=$_.Replace("�", "Ñ").Split(',')
                
                $provincia=$linesplit[1].Trim()
                $canton=$linesplit[2].Trim()
                $distrito=$linesplit[3].Trim()
                
                $Global:dislect[$provincia] ??=  [ordered]@{}
                $Global:dislect[$provincia][$canton] ??= @()
                $Global:dislect[$provincia][$canton] += $distrito
            }
            
            Write-Output "$diselectdataFile loaded."
        }
}

function Random-Provincia {    
    if (-not $(EnsureDataFiles)) {
        return
    }
    Load-Diselec    
    while ($true) {
        $prov = $($Global:dislect.keys | Get-Random -Count 1)
        if ($prov -ne "CONSULADO") {
            return $prov
        }
    }
}

function Random-Canton {
    param (        
        [string]$provincia=$null
    )

    if (-not $(EnsureDataFiles)) {
        return
    }

    Load-Diselec    

    if (-not $provincia) {
        $provincia = $(Random-Provincia)
    }

    if (-not $provincia) { 
        return ""
    }

    return $($Global:dislect[$provincia].keys | Get-Random -Count 1)
}

function Random-Distrito {
    param (        
        [string]$provincia=$null,
        [string]$canton=$null
    )

    if (-not $(EnsureDataFiles)) {
        return
    }

    Load-Diselec    

    if (-not $provincia) {
        $provincia = $(Random-Provincia)
    }

    if (-not $canton) {
        $canton = $(Random-Canton $provincia)
    }

    $provdata = $Global:dislect[$provincia]
    if (-not $provdata) {
        return ""
    }

    return $($provdata[$canton] | Get-Random -Count 1)
}

function Random-Nombre-Completo { 
    $padron = $(Random-Real-Person)
    return $padron.Name
}

function Random-Nombre {
    param (        
        [int]$count=$null
    )

    if (-not $count) {
        $count = $(Get-Random -Minimum 1 -Maximum 3)
    }

    $padron = $(Random-Real-Person $count)
    $nombres = $($padron | ForEach-Object { $_.Name.Split(' ', 2) } | Get-Random -Count $count)
        
    return $($nombres -join " ")
}

function Random-Apellido {
    param (        
        [int]$count=$null
    )

    if (-not $count) {
        $count = $(Get-Random -Minimum 1 -Maximum 3)
    }

    $padron = $(Random-Real-Person $count)
    $apellidos = $($padron | ForEach-Object { $_.LastName1, $_.LastName2 } | Get-Random -Count $count)
        
    return $($apellidos -join " ")
}

function Random-Password {
    param (
        [int]$length=0
    )
    if ($length -lt 1) {
        $length = $(Get-Random -Min 6 -Max 13)
    }
    return $(Random-Text $length -extraChars "!.$%¡?¿012345678901234567890987654321¿012345678901234567890987654321")
}

function Load-UserAgents {
    if (-not $Global:userAgents) {
        $Global:userAgents = $(Get-Content "$userAgentsdataFile" )
        if (-not $Global:userAgents) {
            Write-Debug "Failed to load $userAgentsdataFile. Using defaults"
            $Global:userAgents = @("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 Safari/537.36", 
                                   "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.81 Safari/537.36 Edg/94.0.992.50",
                                   "Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0) like Gecko",
                                   "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.81 Safari/537.36"
                                   "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15")
        } else {
            Write-Debug "$userAgentsdataFile loaded."
        }
    }
}


function Random-UserAgent {
    Load-UserAgents
    return $($Global:userAgents | Get-Random) ?? "Mosaic"
}

function Random-Fake-Person {
    param (        
        [int]$count=1
    )

    if (-not $(EnsureDataFiles)) {
        return
    }

    $textInfo = (Get-Culture).TextInfo

    1..$count | ForEach-Object {
        $Name          = $(Random-Nombre-Completo)
        $LastName1     = $(Random-Apellido 1)
        $LastName2     = $(Random-Apellido 1)
        $provincia     = $(Random-Provincia)
        $canton        = $(Random-Canton $provincia)
        $distrito      = $(Random-Distrito $provincia $canton)
        $age           = $(18..97 + 18..50 + 18..40 + 20..30 | Get-Random)
        $birthDay      = "$($(Get-Date).Year - $age)-$(1..12 | Get-Random)-$(1..28 | Get-Random)"

        $emailUser = "$name $lastname1"
        switch (Get-Random -Min 0 -Max 4) {
           1 { $emailUser = "$name $lastname1 $lastname2" } 
           2 { $emailUser = "$lastname1 $lastname2 $name" } 
           3 { $emailUser = "$lastname1 $name" } 
        }

        [PSCustomObject]@{
            Id            = $($(Random-Real-Person).Id)
            Name          = $Name
            LastName1     = $LastName1 
            LastName2     = $LastName2 
            Email         = $(Random-PseudoReal-Email $emailUser)
            Provincia     = $textInfo.ToTitleCase($provincia.ToLower())
            Canton        = $textInfo.ToTitleCase($canton.ToLower())
            Distrito      = $textInfo.ToTitleCase($distrito.ToLower())
            Age           = $age
            BirthDay      = $birthDay
            Password      = $(Random-Password)
            UserAgent     = $(Random-UserAgent)
        }
    }
}

function Open-Padron-File {
    if (-not $Global:padronStream) {
        $Global:padronStream = Get-Content -Path $padrondataFile -AsByteStream -Raw
        $Global:padronTotalRecords = $Global:padronStream.length / $padronRecordSize
    }   
}

function Random-Real-Person {
    param (        
        [int]$count=$null
    )

    if (-not $count) {
        $count = 1
    }

    Open-Padron-File
    Get-Random -Minimum 0 -Maximum $Global:padronTotalRecords  -Count $count | Read-Real-Person 
}

function Read-Real-Person
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline)]
        [int[]]$recordNumbers
    )

    Process
    {
        if (-not $(EnsureDataFiles)) {
            return
        }
    
        Load-Diselec
        Open-Padron-File
        
        if (-not $Global:padronStream)
        {
            Write-Warning "Failed to open data file."
            return
        }

        $textInfo = (Get-Culture).TextInfo
        foreach($recordNumber in $recordNumbers)
        {
            $recordNumberOffset = $recordNumber * $padronRecordSize;
            $recordString=[System.Text.Encoding]::ASCII.GetString($Global:padronStream, $recordNumberOffset, $padronRecordSize).Replace("?", "Ñ")
            
            $recordFields=$recordString.Split(',')
    
            $diselect = $recordFields[1].Trim();
            $provincia = @($Global:dislect.keys)[$([int]$diselect.Substring(0, 1)-1)]
            $canton = @($Global:dislect[$provincia].keys)[$([int]$diselect.Substring(1, 2)-1)]
            $distrito = $($Global:dislect[$provincia][$canton][[int]$diselect.Substring(3, 3)-1])
            
            [PSCustomObject]@{
                Id            = $recordFields[0].Trim()
                Name          = $textInfo.ToTitleCase($recordFields[5].Trim().ToLower())
                LastName1     = $textInfo.ToTitleCase($recordFields[6].Trim().ToLower())
                LastName2     = $textInfo.ToTitleCase($recordFields[7].Trim().ToLower())
                Date          = $recordFields[3]
                Provincia     = $provincia
                Canton        = $canton
                Distrito      = $distrito
            }
        }
    } ## end Process block
}

function Get-ValueKey {
    param (        
        [string]$content,
        [string]$keyStart,
        [string]$keyEnd
    )

    $i = $content.IndexOf($keyStart)
    if ($i -gt 0) {
        $line =  $content.Substring($i + $keyStart.Length, 128)
        return $line.Substring(0, $line.IndexOf($keyEnd))
    }
}

function Post-Data {
    param (        
        [string]$url,
        $body,
        [string]$userAgent = $null
    )

    if (-not $userAgent) {
        $userAgent = $(Random-UserAgent)
    }

    Write-Debug "Post-Data UserAgent: $userAgent"
    return Invoke-WebRequest  $url -Method 'POST' -UserAgent $userAgent  -Body $body
}

function Main() {
    if ($RandomRealPerson) {
        Random-Real-Person -count $RandomRealPerson
        return
    }

    if ($RandomFakePerson) {
        Random-Fake-Person -count $RandomFakePerson
        return
    }

    if ($RandomPassword) {
        Random-Password -length $RandomPassword
        return
    }

    if ($RandomEmail) {
        return
        Random-PseudoReal-Email -count $RandomEmail
    }

    Random-Fake-Person
}

if ($myinvocation.InvocationName -ne ".") {
    Main
}