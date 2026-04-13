function Get-DhThemeCss {
    <#
    .SYNOPSIS  Returns the full CSS string for a named theme.
               Combines the theme's :root variable block with shared structural CSS.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DefaultDark','DefaultLight',
                     'CompanyLight','CompanyDark',
                     'AzureLight','AzureDark',
                     'VMwareLight','VMwareDark',
                     'GreyLight','GreyDark')]
        [string] $Theme
    )

    $rootCss = switch ($Theme) {
        'DefaultDark'   { Get-DhCssDefaultDark  }
        'DefaultLight'  { Get-DhCssDefaultLight }
        'CompanyLight'  { Get-DhCssCompanyLight }
        'CompanyDark'   { Get-DhCssCompanyDark  }
        'AzureLight'    { Get-DhCssAzureLight   }
        'AzureDark'     { Get-DhCssAzureDark    }
        'VMwareLight'   { Get-DhCssVMwareLight  }
        'VMwareDark'    { Get-DhCssVMwareDark   }
        'GreyLight'     { Get-DhCssGreyLight    }
        'GreyDark'      { Get-DhCssGreyDark     }
    }

    return "$rootCss`n$(Get-DhCssBase)"
}
