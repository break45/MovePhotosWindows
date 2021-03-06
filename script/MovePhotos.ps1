# Parameters
$cameraName='Canon EOS 600D'
$allowedExtensions = @("JPG", "CR2")
$targetDir='C:\Users\Murto\Pictures\'
$tempDir='C:\Temp\'
$deleteFromCard='TRUE'
# END Parameters

# HashTable for file -> date taken
$files = @{}

$camera = Get-WmiObject win32_pnpentity -filter "Name='$cameraName'"

if ($camera -eq $null) {
  throw "Camera not connected?"
}

$wiaDeviceManager = New-Object -ComObject WIA.DeviceManager

#$wiaDeviceManager.DeviceInfos

#TODO: iteroi devicet läpi ja katso missä mätchää tuo Name String:
# $wiaDeviceManager.DeviceInfos.Item(1).Properties | Where-Object { $_.Name -eq "Name" } | Select-Object -ExpandProperty Value
# Canon EOS 600D
# connectoi sitten siihen
$wiaDevice = $wiaDeviceManager.DeviceInfos.Item(1).Connect()

"Camera " + $cameraName + " connected successfully!"

# Iterate through items on SD Card
#  and read "Date Taken" property from each picture's EXIF data
#  and copy them to tempDir for easier handling
#  and append each picture to HashTable "files"
$wiaDevice.Items | ForEach-Object {
        
    # this is not directly EXIF, but works also for Canon RAW .CR2... (not just .JPG)
    $picTimeStamp = $_.Properties | Where-Object { $_.Name -eq "Item Time Stamp" } | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty Date

    $originalFileName = $_.Properties | Where-Object { $_.Name -eq "Item Name" } | Select-Object -ExpandProperty Value
    $originalFileExt = $_.Properties | Where-Object { $_.Name -eq "Filename extension" } | Select-Object -ExpandProperty Value
    $tmpFilePath = $tempDir + $originalFileName + "." + $originalFileExt
    
    # if this file does not have an image file extension, skip this iteration of loop
    if($allowedExtensions -notcontains $originalFileExt) { return }
    
    $pic = $_.Transfer()
    $pic.SaveFile($tmpFilePath)
    
    # TODO: make date format configurable, now YYYY-MM-DD is hard coded below
    $year = $picTimeStamp.Year
    $month = "{0:d2}" -f $picTimeStamp.Month
    $day = "{0:d2}" -f $picTimeStamp.Day
    $myDateString = "$year" + "-" + "$month" + "-" + "$day"
    
    "Found Photo " + $originalFileName + "." + $originalFileExt + ", taken on " + $myDateString + ", temporarily storing to " + $tmpFilePath
    
    $files.Add($tmpFilePath, $myDateString)
        
}

# Create dirs based on unique dates based on EXIF data "Date Taken"  
$files.Values | Select-Object -unique | ForEach-Object {
    $newDir = $targetDir + $_
    $newDirExists = Test-Path $newDir
    if ($newDirExists) {
        # dir already exists, no need to create
    } else {
        New-Item -Path $newDir -ItemType directory
    }
}

# Move files from temp dir to target location under correct timestamped directory
$files.Keys | ForEach-Object {
    $destDir = $targetDir + $files.Get_Item($_)
    $sourceFile = $_
    Move-Item $sourceFile -Destination $destDir
    "Moved " + $_ + " to " + $destDir
}

#TODO: detect errors and prevent deletion from card if something went wrong...

if($deleteFromCard) {
    #TODO: delete all items from Camera SD card after transfer
}
