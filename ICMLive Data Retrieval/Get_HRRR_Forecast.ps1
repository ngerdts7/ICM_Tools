#-----------------------------------------------------------
# Run this script ~25 min after each hour of the day.
# Edited Dec 3, 2020 by Nathan.Gerdts@Innovyze.com
#-----------------------------------------------------------

#-----------------------------------------------------------
# Specify Local Inputs -
# -  Lat-Lon window, and Local file path
#-----------------------------------------------------------
$Lon_min = -80.5
$Lon_max = -78
$Lat_min = 42.5
$Lat_max = 44.5
$Local_Path = "C:\temp\HRRR\"

#-----------------------------------------------------------
# Get current UTC hour in string format
#-----------------------------------------------------------
$now = [DateTime]::Now.AddHours(-1) # minus 1 since files are 50-80 minutes late
$Hour = Get-Date $now.ToUniversalTime() -format HH
$Day  = Get-Date $now.ToUniversalTime() -format yyyMMdd
[string]$Hr_Char = "{0:D2}" -f ($Hour)  # This bit converts hour to 2 character string with zero in front if needed

#-----------------------------------------------------------
# Prepare other inputs
#-----------------------------------------------------------
$str1 = "https://nomads.ncep.noaa.gov/cgi-bin/filter_hrrr_sub.pl?file=hrrr.t"
$str2 = "z.wrfsubhf"
$str3 = ".grib2&var_PRATE=on&subregion=&leftlon="+$Lon_min+"&rightlon="+$Lon_max+`
    "&toplat="+$Lat_max+"&bottomlat="+$Lat_min+"&dir=%2Fhrrr."+$today+"%2Fconus"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

#-----------------------------------------------------------
# Loop for each forecast hour
#-----------------------------------------------------------
For ($i=1; $i -le 18; $i++) {
    if($i-lt10){$fhr="0"+$i}else{[string]$fhr=$i}
    $url = $str1+$HR_char+$str2+$fhr+$str3
    $output = $Local_Path + "HRRR_"+$today+"_"+$HR_char+"_"+$fhr+"_.grib"
    write-output $url
    write-output $output
    Invoke-WebRequest $url -WebSession $session -TimeoutSec 900 -OutFile $output
    }