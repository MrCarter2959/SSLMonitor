#########################################################################
#                                                                       #
#                            URL's to Monitor                           #
#                                                                       #
#########################################################################
#Use the Format of first URL to include monitor website's to montior
$sslURL = @(
'https://url1.domain.org',
'https://url2.domain.com'
)

#########################################################################
#                                                                       #
#                             SMTP Settings                             #
#                                                                       #
#########################################################################
$sslSMTP = @{
    SMTPServer = 'SMTP_SERVER'
    To         = 'TOUSER@DOMAIN.ORG'
    From       = 'SOMEONE@DOMAIN.ORG'
    Subject    = '[ALERT] : SSL Certs Exipring Soon!'
}

#########################################################################
#                                                                       #
#                             Set Cert Age                              #
#                                                                       #
#########################################################################
$sslMinimumCertAgeDays = 30 # Enter how many days left on the certificate before considering this monitor 'down'

$sslTimeoutMilliseconds = 30000

#########################################################################
#                                                                       #
#                             Set HTML                                  #
#                                                                       #
#########################################################################
$sslHTML = @"
<style>
BODY{background-color:white;}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:thistle}
TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:white}
</style>
"@

#########################################################################
#                                                                       #
#                            Create Error Array's                       #
#                                                                       #
#########################################################################
$sslDebug = New-Object System.Collections.Generic.List[object]

#########################################################################
#                                                                       #
#                            Create Array's                             #
#                                                                       #
#########################################################################
$sslCurrent = New-Object System.Collections.Generic.List[object]
$sslExpiring = New-Object System.Collections.Generic.List[object]
#########################################################################
#                                                                       #
#                       Start the SSL Check                             #
#                                                                       #
#########################################################################
Foreach ($site in $sslURL) {

Try {
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $sslReq = [Net.HttpWebRequest]::Create($site)

    $sslReq.Timeout = $sslTimeoutMilliseconds

    $sslReq.GetResponse() | Out-Null
}
Catch {
    ##################################
    # Set Error Variable
    $sslTransferErrors = $_.Exception.Message
    $sslFullError = $_.InvocationInfo.PositionMessage
    $sslErrorInfo = $_.CategoryInfo.ToString()
    $sslFQDNError = $_.FullyQualifiedErrorId
    ##################################
    # Write To Console
    Write-Host $sslTransferErrors -BackgroundColor "Yellow" -ForegroundColor "Black"
    ##################################
    # Write To ArrayLog
    $sslDebug.Add(
        [PSCUSTOMOBJECT]@{ErrorMessage=$sslTransferErrors;FullError=$sslFullError;ErrorInfo=$sslErrorInfo;ErrorID=$sslFQDNError}
    )
}

[datetime]$sslExpiration = (Get-Date $sslReq.ServicePoint.Certificate.GetExpirationDateString())

[int]$sslCertExpiresIn = ($sslExpiration - $(get-date)).Days
#########################################################################
#                                                                       #
#                      Check for Date Range                             #
#                                                                       #
#########################################################################
if ($sslCertExpiresIn -gt $sslMinimumCertAgeDays) {
    Write-Host "Cert for site $site expires in $sslCertExpiresIn days [on $sslExpiration]" -BackgroundColor "Green" -ForegroundColor "Black"

    $sslCurrent.Add(
        [PSCUSTOMOBJECT] @{
            URL=$site;DaysToExpiration=$sslCertExpiresIn;ExpirationDate=$sslExpiration
        }
    )

    $sslCurrentBody = $sslCurrent | ConvertTo-Html -Head $sslHTML -Body "<H2>Current SSL Certificates</H2>" | Out-String
    $sslSMTP.body = $sslCurrentBody

    }
Else {
    Write-Host "Cert for site $site expires in $sslCertExpiresIn days [on $sslExpiration] Threshold is $sslMinimumCertAgeDays days." -BackgroundColor "Yellow" -ForegroundColor "Black"

    $sslExpiring.Add(
        [PSCUSTOMOBJET]@{
            URL=$site;DaysToExpiration=$sslCertExpiresIn;ExpirationDate=$sslExpiration
        }
    )
   
    $sslExpiringBody = $sslExpiring | ConvertTo-Html -Head $sslHTML -Body "<H2>Expiring SSL Certificates</H2>" | Out-String

    $sslSMTP.body = $sslExpiringBody
    }
}


#########################################################################
#                                                                       #
#                    Send SMTP Notification                             #
#                                                                       #
#########################################################################
#if ($sslCurrent.Count -ge 1){
#
#    Send-MailMessage @sslSMTP -BodyAsHtml
#
#    }
#########################################################################
#                                                                       #
#                    Send SMTP Notification                             #
#                                                                       #
#########################################################################
If ($sslExpiring.Count -ge 1) {
    
    Send-MailMessage @sslSMTP -BodyAsHtml
    
    }
