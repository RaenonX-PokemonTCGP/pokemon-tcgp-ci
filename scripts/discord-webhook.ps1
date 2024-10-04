# Stop the script execution on any failure
$ErrorActionPreference = "Stop"

$BuildId = $(git show -s --format="%h-%cI").Trim().Replace(":", "-")
$BuildHash = $(git show -s --format="%H").Trim()
$BuildStatusColor = @{
    "Canceled" = [convert]::ToString("0x06B6D4", 10)
    "Succeeded" = [convert]::ToString("0x22C55E", 10)
    "SucceededWithIssues" = [convert]::ToString("0xF59E0B", 10)
    "Failed" = [convert]::ToString("0xF43F5E", 10)
}

function Get-Environment {
    $private:EnvVarMap = @{
        "WebhookUrl" = "AZ_DEVOPS_DISCORD_WEBHOOK"
        "Title" = "AZ_DEVOPS_TITLE"
        'Status' = "AZ_DEVOPS_STATUS"
        "Url" = "AZ_DEVOPS_BUILD_URL"
        "Requester" = "AZ_DEVOPS_REQUESTER"
        "RequesterId" = "AZ_DEVOPS_REQUESTER_ID"
        "QueuedBy" = "AZ_DEVOPS_QUEUED_BY"
        "QueuedById" = "AZ_DEVOPS_QUEUED_BY_ID"
    }

    $private:EnvVars = @{}

    foreach ($private:EnvVarEntry in $private:EnvVarMap.GetEnumerator()) {
        $private:EnvVarName = $private:EnvVarEntry.Value
        $private:EnvVars[$private:EnvVarEntry.Name] = (Get-Item -Path env:/$private:EnvVarName).Value
    }

    return $private:EnvVars
}

$Environment = $(Get-Environment)

$DiscordData = @{
    "timestamp" = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    # `503484431437398016` is the UID of `@raenonx`
    "content" = "**$($Environment.Status)** / $($Environment.Title) <@503484431437398016>"
    "embeds" = @(
        @{
            "title" = $Environment.Title
            "color" = $BuildStatusColor[$Environment.Status] ?? [convert]::ToString("0x64748B", 10)
            "url" = $Environment.Url
            "fields" = @(
                @{
                    "name" = "Status"
                    "value" = $Environment.Status
                    "inline" = "false"
                }
                @{
                    "name" = "Build"
                    "value" = $BuildId
                    "inline" = "false"
                }
                @{
                    "name" = "Commit Link"
                    "value" = "https://github.com/RaenonX-PokemonTCGP/pokemon-tcgp-ui-core/commit/$buildHash"
                    "inline" = "false"
                }
            )
        }
    )
}

Write-Host -ForegroundColor Cyan "Azure DevOps triggered at $($DiscordData.Timestamp)"
Write-Host -ForegroundColor Cyan "- Requester: $($Environment.Requester)"
Write-Host -ForegroundColor Cyan "- Requester ID: $($Environment.RequesterId)"
Write-Host -ForegroundColor Cyan "- Queued by: $($Environment.QueuedBy)"
Write-Host -ForegroundColor Cyan "- Queued by ID: $($Environment.QueuedById)"
Write-Host -ForegroundColor Cyan "- Status: $($Environment.Status)"
Write-Host -ForegroundColor Cyan "- Title: $($Environment.Title)"
Write-Host -ForegroundColor Cyan "- Content: $($DiscordData.Content)"

$DiscordMessageJson = $($DiscordData | ConvertTo-Json -Depth 10)

# Send webhook
$WebhookResult = Invoke-WebRequest `
    -Uri $Environment.WebhookUrl `
    -Method Post `
    -ContentType 'application/json' `
    -Body $DiscordMessageJson

Write-Output $WebhookResult

$StatusCode = $WebhookResult.StatusCode
switch ($StatusCode) {
    {$_ -ge 100 -and $_ -lt 400} {
        Write-Host -ForegroundColor Green "Discord responded OK status. Status: $StatusCode"
        exit 0
    }
    {$_ -ge 400 -and $_ -lt 600} {
        Write-Host -ForegroundColor Red "Discord responded error. Status: $StatusCode"
        exit 1
    }
    default {
        Write-Host "The site returned an unhandled status code. Status: $StatusCode"
        exit 1
    }
}
