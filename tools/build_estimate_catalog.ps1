# Builds reusable estimate/quotation datasets from samle (1).xlsx sheet exports.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$rawDir = Join-Path $root 'tmp_excel_raw'
$dataDir = Join-Path $root 'data'
$assetsDir = Join-Path $root 'assets\data'
foreach ($dir in @($dataDir, $assetsDir)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

function Collapse-Text([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return '' }
    $t = [regex]::Replace($value, '\s+', ' ').Trim()
    $t = $t -replace '""', '"'
    return $t
}

function Fix-Typos([string]$value) {
    $t = Collapse-Text $value
    $pairs = @(
        ,@('Dismentling', 'Dismantling')
        ,@('exisitng', 'existing')
        ,@('Exisinig', 'Existing')
        ,@('exisiting', 'existing')
        ,@('gypsym', 'gypsum')
        ,@('tougned', 'toughened')
        ,@('toughned', 'toughened')
        ,@('selecion', 'selection')
        ,@('prelamenated', 'prelaminated')
        ,@('lamenated', 'laminated')
        ,@('saperately', 'separately')
        ,@('chareged', 'charged')
        ,@('Decortive', 'Decorative')
        ,@('Stirips', 'Strips')
        ,@('rquired', 'required')
        ,@('lavelling', 'levelling')
        ,@('instalection', 'installation')
        ,@('installaing', 'installing')
        ,@('insulaction', 'insulation')
        ,@('Srinklers', 'Sprinklers')
        ,@('Butter Fly Value', 'Butterfly Valve')
        ,@('FURNITURES', 'Furniture')
        ,@('Furnitures', 'Furniture')
        ,@('LUMSUM', 'lumpsum')
        ,@('lumsum', 'lumpsum')
        ,@('Blindes', 'Blinds')
        ,@('takker', 'takkar')
        ,@('Pantrya', 'Pantry')
    )
    foreach ($pair in $pairs) { $t = $t.Replace($pair[0], $pair[1]) }
    return $t
}

function Get-Slug([string]$value) {
    $t = (Fix-Typos $value).ToLowerInvariant()
    $t = [regex]::Replace($t, '[^a-z0-9]+', '_')
    $t = $t.Trim('_')
    if ($t.Length -gt 48) { $t = $t.Substring(0, 48).Trim('_') }
    if ([string]::IsNullOrWhiteSpace($t)) { return 'item' }
    return $t
}

function Parse-Number([string]$value) {
    $t = Collapse-Text $value
    if ([string]::IsNullOrWhiteSpace($t)) { return $null }
    if ($t -match '(?i)^(lumsum|lumpsum|as\s*/?\s*site|as per site|_+|n/?a|nil|-)$') { return $null }
    if ($t -match '(?i)client') { return $null }
    $t = $t -replace ',', ''
    if ($t -match '^\d+(\.\d+)?$') { return [double]$t }
    if ($t -match '(?i)(\d+(?:\.\d+)?)\s*[xX]\s*(\d+(?:\.\d+)?)') {
        return $null
    }
    return $null
}

function Parse-HvacCarpetRate([string]$value) {
    $t = Collapse-Text $value
    if ($t -match '(?i)(\d+(?:\.\d+)?)\s*[xX]\s*(\d+(?:\.\d+)?)') {
        return @{ Quantity = [double]$Matches[1]; UnitRate = [double]$Matches[2] }
    }
    return $null
}

function Normalize-Unit([string]$value) {
    $t = (Collapse-Text $value).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($t)) { return '' }
    $t = $t -replace '\.', ''
    $t = $t -replace '\s+', ' '
    switch -Regex ($t) {
        '^(lumsum|lumpsum|ls|lot)$' { return 'lumpsum' }
        '^(per )?sq\s*ft|sqft|sft$' { return 'sqft' }
        '^(per )?(pcs|pc|nos|no|number|each|unit|set)$' { return 'pcs' }
        '^(per )?seat$' { return 'seat' }
        '^(run ft|rft|running feet|running ft|rft)$' { return 'rft' }
        '^(mtrs?|meter|metre)$' { return 'mtr' }
        '^(per )?step$' { return 'step' }
        default { return $t }
    }
}

function Test-SkipRow([string]$c1, [string]$c2, [string]$c4) {
    $blob = Collapse-Text "$c1 $c2 $c4"
    if ($blob -match '(?i)^(s\.?no\.?|areas|description|unit|scope of work)\b') { return $true }
    if ($blob -match '(?i)^(office:|mob:|mobile:|email:|gst:)') { return $true }
    if ($blob -match '(?i)^(total|grand total|gst\s|freight|other terms|payment needed|estimated project|18%\s*gst|note[: ])') { return $true }
    if ($c1 -match '(?i)^total') { return $true }
    return $false
}

function Test-TermsRow([string]$c1, [string]$c2, [string]$c4) {
    $blob = Collapse-Text "$c1 $c2 $c4"
    return $blob -match '(?i)(other terms|payment needed|excluding items|extra items|estimated project|gst will be|above estimate|quantit)'
}

function Test-AreaName([string]$name) {
    $n = (Fix-Typos $name).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($n)) { return $false }
    if ($n.Length -gt 70) { return $false }
    if ($n -match '(?i)^(providing|supply|p/f|supplying)') { return $false }
    return $n -match '(?i)(reception|meeting room|pantry|cafeteria|cabin|director|workstation|md cabin|lounge|toilet|server|balcony|kitchen)'
}

function Get-CanonicalArea([string]$name) {
    $n = (Fix-Typos $name)
    $nl = $n.ToLowerInvariant()
    if ($nl -match 'reception') { return 'Reception' }
    if ($nl -match 'meeting') { return 'Meeting Room' }
    if ($nl -match 'pantry') { return 'Pantry' }
    if ($nl -match 'cafeteria|caf[eé]') { return 'Cafeteria' }
    if ($nl -match 'workstation') { return 'Workstation Area' }
    if ($nl -match 'md cabin') { return 'MD Cabin' }
    if ($nl -match 'ex\.?\s*director|executive director') { return 'Executive Director Cabin' }
    if ($nl -match 'director') { return 'Director Cabin' }
    if ($nl -match 'cabin') { return 'Cabin' }
    if ($nl -match 'lounge') { return 'Lounge' }
    if ($nl -match 'toilet|bathroom') { return 'Toilet' }
    if ($nl -match 'server') { return 'Server Room' }
    if ($nl -match 'balcony') { return 'Balcony' }
    if ($nl -match 'kitchen') { return 'Kitchen' }
    return (Get-Culture).TextInfo.ToTitleCase($n.ToLowerInvariant())
}

$script:WorkTypeDefs = @(
    @{ Serial = 1;  Name = 'Dismantling and Debris'; Pattern = 'dismantl|debris' }
    @{ Serial = 2;  Name = 'Civil Work'; Pattern = 'civil|granite staircase|pcc |screed|ips flooring|brick work|lintel|plaster work|raised floor|water ?proof' }
    @{ Serial = 3;  Name = 'Flooring'; Pattern = 'floor tile|flooring|carpet|vinyl floor|vitrified' }
    @{ Serial = 4;  Name = 'Partition and Glass'; Pattern = 'partition wall|gypsum partition|aluminium partition|glass partition|glass door|flush door' }
    @{ Serial = 5;  Name = 'Toilet and Wet Areas'; Pattern = 'director.?s toilet|^toilet$|bathroom' }
    @{ Serial = 6;  Name = 'Suspended Ceiling'; Pattern = 'ceiling|gypsum ceiling|grid ceiling|pop ceiling|baffle' }
    @{ Serial = 7;  Name = 'Electrical Works'; Pattern = 'electrical' }
    @{ Serial = 8;  Name = 'Paint Works'; Pattern = 'paint' }
    @{ Serial = 9;  Name = 'Furniture'; Pattern = 'furniture|furnitures' }
    @{ Serial = 10; Name = 'HVAC'; Pattern = 'hvac|ahu' }
    @{ Serial = 11; Name = 'Fire Fighting'; Pattern = 'fire fight|sprinkler' }
    @{ Serial = 12; Name = 'Alarm System'; Pattern = 'alarm system|fire alarm' }
    @{ Serial = 13; Name = 'Doors and Windows'; Pattern = 'aluminium window|wooden frame' }
    @{ Serial = 14; Name = 'Wall Finishes'; Pattern = 'wallpaper|cladding|panelling|paneling|wall panel|wpc' }
    @{ Serial = 15; Name = 'Window Treatments'; Pattern = 'blind|glass film' }
    @{ Serial = 16; Name = 'System Integration'; Pattern = 'system integeration|system integration|cctv|biometric' }
)

function Match-WorkTypeName([string]$name) {
    $n = (Fix-Typos $name).ToLowerInvariant()
    foreach ($def in $script:WorkTypeDefs) {
        if ($n -match $def.Pattern) { return $def.Name }
    }
    return $null
}

function Infer-WorkTypeFromItem([string]$name, [string]$desc) {
    $t = (Fix-Typos "$name $desc").ToLowerInvariant()
    if ($t -match 'dismantl|debris') { return 'Dismantling and Debris' }
    if ($t -match 'pcc|brick work|plaster|screed|lintel|waterproof|ips flooring|raised floor') { return 'Civil Work' }
    if ($t -match 'carpet|vinyl floor|floor tile|vitrified|skirting') { return 'Flooring' }
    if ($t -match 'partition|glass door|flush door|toughened glass') { return 'Partition and Glass' }
    if ($t -match '\bwc\b|cistern|health faucet|toilet paper|table top basin') { return 'Toilet and Wet Areas' }
    if ($t -match 'ceiling|grid ceiling|gypsum board ceiling|pop ceiling|baffle') { return 'Suspended Ceiling' }
    if ($t -match 'electrical|wiring|switch board|hanging light') { return 'Electrical Works' }
    if ($t -match 'paint|putty') { return 'Paint Works' }
    if ($t -match 'ahu|hvac|chilled water|ductwork') { return 'HVAC' }
    if ($t -match 'sprinkler|fire fight|extinguisher|fire detector|fire alarm|hose') { return 'Fire Fighting' }
    if ($t -match 'blind|glass film') { return 'Window Treatments' }
    if ($t -match 'wallpaper|cladding|panelling|paneling|wpc|charcol|charcoal') { return 'Wall Finishes' }
    if ($t -match 'aluminium window') { return 'Doors and Windows' }
    if ($t -match 'cctv|biometric|punching machine') { return 'System Integration' }
    if ($t -match 'sofa|chair|table|storage|counter|workstation|sink|granite|bean bag|book shelf|bookshelf|couch|dice') { return 'Furniture' }
    return $null
}

$script:ScopeRules = @(
    @{ Id = 'dismantling_partitions'; Name = 'Dismantling existing partitions and site cleaning'; Pattern = 'dismantl.*partition' }
    @{ Id = 'dismantling_walls'; Name = 'Dismantling existing walls and site cleaning'; Pattern = 'dismantl.*wall' }
    @{ Id = 'pcc_levelling'; Name = 'PCC / screed for floor levelling'; Pattern = 'pcc for|screeding|tile levelling' }
    @{ Id = 'ips_flooring'; Name = 'IPS flooring'; Pattern = 'ips flooring' }
    @{ Id = 'brick_work'; Name = 'Brick work for toilets, pantry and cafeteria'; Pattern = 'brick work' }
    @{ Id = 'rcc_lintel'; Name = 'RCC lintel beam'; Pattern = 'lintel' }
    @{ Id = 'plaster_work'; Name = 'Cement plaster'; Pattern = 'plaster work|pop plaster|cement block wall' }
    @{ Id = 'raised_floor'; Name = 'Raised PCC floor'; Pattern = 'raised floor' }
    @{ Id = 'waterproofing'; Name = 'Waterproofing for toilet and pantry'; Pattern = 'water ?proof' }
    @{ Id = 'granite_ledge'; Name = 'Granite ledge'; Pattern = 'granite ledge' }
    @{ Id = 'granite_staircase'; Name = 'Granite staircase'; Pattern = 'granite staircase' }
    @{ Id = 'vitrified_floor_tiles'; Name = 'Vitrified floor tiles'; Pattern = 'floor tile|vitrified|tile flooring' }
    @{ Id = 'carpet_tile'; Name = 'Carpet tile'; Pattern = 'carpet' }
    @{ Id = 'vinyl_flooring'; Name = 'Vinyl flooring'; Pattern = 'vinyl floor' }
    @{ Id = 'gypsum_partition'; Name = 'Gypsum partition'; Pattern = 'gypsum partition' }
    @{ Id = 'aluminium_partition'; Name = 'Aluminium partition'; Pattern = 'aluminium partition' }
    @{ Id = 'glass_partition'; Name = 'Toughened glass partition'; Pattern = 'glass partition' }
    @{ Id = 'glass_door'; Name = 'Toughened glass door'; Pattern = 'glass door' }
    @{ Id = 'flush_door'; Name = 'Flush door with laminate finish'; Pattern = 'flush door' }
    @{ Id = 'toilet_tiles'; Name = 'Toilet floor and wall tiles'; Pattern = 'floor and wall tile' }
    @{ Id = 'toilet_fixtures'; Name = 'Toilet fixtures set'; Pattern = 'fixtures for toilet|wall mounted wc' }
    @{ Id = 'toilet_plumbing'; Name = 'Bathroom PVC plumbing installation'; Pattern = 'pvc installation|pvc pipeline' }
    @{ Id = 'gypsum_ceiling'; Name = 'Gypsum ceiling'; Pattern = 'gypsum ceiling|gypsum board ceiling' }
    @{ Id = 'grid_ceiling'; Name = 'Grid ceiling'; Pattern = 'grid ceiling' }
    @{ Id = 'pop_ceiling'; Name = 'POP ceiling'; Pattern = 'pop ceiling|plain pop' }
    @{ Id = 'baffle_ceiling'; Name = 'Baffle ceiling'; Pattern = 'baffle' }
    @{ Id = 'electrical_complete'; Name = 'Electrical works for complete area'; Pattern = 'electrical works for complete|electrical work$' }
    @{ Id = 'paint_complete'; Name = 'Paint work for walls, partitions and ceiling'; Pattern = 'paint work' }
    @{ Id = 'waiting_sofa'; Name = 'Waiting / lounge sofa'; Pattern = 'waiting area sofa|sofa set|seater sofa|sofa /couch|sofa/couch' }
    @{ Id = 'centre_table'; Name = 'Centre table'; Pattern = 'centre table|center table' }
    @{ Id = 'side_table'; Name = 'Side table'; Pattern = 'side table' }
    @{ Id = 'reception_counter'; Name = 'Reception counter / table'; Pattern = 'reception counter|reception table' }
    @{ Id = 'reception_chair'; Name = 'Reception chair'; Pattern = 'reception.?s? chair' }
    @{ Id = 'meeting_chair'; Name = 'Meeting chair'; Pattern = 'meeting table.?s? chair|meeting.?s? chairs?' }
    @{ Id = 'meeting_table'; Name = 'Meeting table'; Pattern = 'meeting.?s? table' }
    @{ Id = 'below_storage'; Name = 'Wooden storage below counter'; Pattern = 'storage below|below the pantry|below the sink' }
    @{ Id = 'overhead_storage'; Name = 'Overhead storage'; Pattern = 'over head storage|overhead storage' }
    @{ Id = 'granite_top'; Name = 'Granite counter top'; Pattern = 'granite top' }
    @{ Id = 'pantry_wall_tile'; Name = 'Pantry wall tiles'; Pattern = 'pantry wall tile' }
    @{ Id = 'sink_mixer'; Name = 'Sink, mixer and plumbing'; Pattern = 'sink \+|sink cost|mixture' }
    @{ Id = 'visitor_chair'; Name = 'Visitor chair'; Pattern = 'visitor chair' }
    @{ Id = 'cabin_chair'; Name = 'Cabin / director chair'; Pattern = 'head chair|cabin.?s? chair|director.?s? chair' }
    @{ Id = 'coffee_table'; Name = 'Coffee table'; Pattern = 'coffee table' }
    @{ Id = 'office_chair'; Name = 'Office / workstation chair'; Pattern = 'office chair|workstation.?s? chair|work chair' }
    @{ Id = 'workstation'; Name = 'Workstation'; Pattern = 'workstation' }
    @{ Id = 'executive_chair'; Name = 'Executive chair'; Pattern = 'executive chair' }
    @{ Id = 'boss_chair'; Name = 'Boss chair'; Pattern = 'boss chair' }
    @{ Id = 'director_table'; Name = 'Director / MD table'; Pattern = 'md table|director.?s? table|director table' }
    @{ Id = 'side_storage'; Name = 'Side storage'; Pattern = 'side storage|side unit' }
    @{ Id = 'back_storage'; Name = 'Back storage'; Pattern = 'back storage' }
    @{ Id = 'wall_storage'; Name = 'Wall storage'; Pattern = 'wall storage' }
    @{ Id = 'trap_door'; Name = 'Trap door for AHU'; Pattern = 'trap door' }
    @{ Id = 'window_blinds'; Name = 'Window / roller blinds'; Pattern = 'blind' }
    @{ Id = 'glass_film'; Name = 'Glass film'; Pattern = 'glass film' }
    @{ Id = 'wall_cladding'; Name = 'WPC / charcoal wall cladding'; Pattern = 'cladding|charcol|charcoal|wpc' }
    @{ Id = 'wooden_panelling'; Name = 'Wooden panelling'; Pattern = 'panelling|paneling' }
    @{ Id = 'wallpaper'; Name = 'Wallpaper'; Pattern = 'wallpaper' }
    @{ Id = 'ahu_supply'; Name = 'AHU supply and installation'; Pattern = 'air handling|ahu unit|ahu' }
    @{ Id = 'chilled_water_piping'; Name = 'Chilled water piping and ductwork'; Pattern = 'chilled water|ductwork' }
    @{ Id = 'downward_sprinkler'; Name = 'Ceiling downward flexible sprinkler'; Pattern = 'downword|downward|flexable pipe|flexible pipe' }
    @{ Id = 'upside_sprinkler'; Name = 'Upright sprinkler'; Pattern = 'upside sprinkler|pendent type|sprinkle head' }
    @{ Id = 'fire_detector'; Name = 'Fire detector with alarm panel'; Pattern = 'fire detector' }
    @{ Id = 'ms_pipe'; Name = 'MS heavy grade fire pipe'; Pattern = 'ms pipe|heavy grade ms|65 mm|50 mm|40 mm|25 mm|80 mm|100 mm|150 mm|200 mm' }
    @{ Id = 'butterfly_valve'; Name = 'Cast iron butterfly valve'; Pattern = 'butter fly|butterfly' }
    @{ Id = 'fire_extinguisher'; Name = 'Fire extinguisher'; Pattern = 'extinguisher' }
    @{ Id = 'aluminium_window'; Name = 'Aluminium window with glass'; Pattern = 'aluminium window' }
    @{ Id = 'pop_punning'; Name = 'POP punning / plaster'; Pattern = 'pop punning|pop plaster' }
)

function Get-CanonicalScope([string]$name) {
    $n = (Fix-Typos $name).ToLowerInvariant()
    foreach ($rule in $script:ScopeRules) {
        if ($n -match $rule.Pattern) { return $rule }
    }
    $clean = Fix-Typos $name
    $clean = [regex]::Replace($clean, '(?i)(tile cost.*$|as/design|as/site|as/selection|as/selecion)', '')
    $clean = Collapse-Text $clean
    if ($clean.Length -gt 80) { $clean = $clean.Substring(0, 80).Trim() }
    return @{ Id = Get-Slug $clean; Name = $clean; Pattern = $null }
}

function Get-Makes([string]$text) {
    $makes = New-Object System.Collections.Generic.List[string]
    $t = Fix-Typos $text
    $known = @('Kajaria','Somani','Varmora','Varmoura','Granicer','Saint Gobain','Modi','Gold Plus','Jaquar','Grohe','Hindware','Prince','Prakash','Finolex','Polycab','Anchor','Crompton','Philips','Asian','Gyprock','Carrier','Zeco','Waves','Tyco','TYKO','Agni','Jindal','Kartar','Zoloto','Kirloskar')
    foreach ($m in $known) {
        if ($t -match [regex]::Escape($m)) {
            $label = $m
            if ($label -eq 'Varmoura') { $label = 'Varmora' }
            if ($label -eq 'TYKO') { $label = 'Tyco' }
            if (-not $makes.Contains($label)) { $makes.Add($label) }
        }
    }
    return $makes
}

function Get-Median([double[]]$values) {
    if ($null -eq $values -or $values.Count -eq 0) { return $null }
    $sorted = $values | Sort-Object
    $n = @($sorted).Count
    if ($n -eq 1) { return [double]$sorted[0] }
    if ($n % 2 -eq 1) { return [double]$sorted[[int][math]::Floor($n / 2)] }
    return ([double]$sorted[$n / 2 - 1] + [double]$sorted[$n / 2]) / 2.0
}

function New-Record($hash) {
    $obj = New-Object PSObject
    foreach ($key in @($hash.Keys)) {
        $obj | Add-Member -NotePropertyName ([string]$key) -NotePropertyValue $hash[$key]
    }
    return $obj
}

$sheetMeta = @{
    'RINKI.json' = @{ Id = 'rinki_2023_10_07_v1'; Client = 'Ms. Rinki Singh'; Project = 'Sector-132, Greater Noida'; Date = '2023-10-07'; Kind = 'detailed_estimate' }
    'RINKI- final.json' = @{ Id = 'rinki_2023_10_07'; Client = 'Ms. Rinki Singh'; Project = 'Sector-132, Greater Noida'; Date = '2023-10-07'; Kind = 'detailed_estimate' }
    'REVISED .json' = @{ Id = 'rinki_2024_10_26'; Client = 'Ms. Rinki Singh'; Project = 'Sector-132, Greater Noida'; Date = '2024-10-26'; Kind = 'detailed_estimate' }
    'final.json' = @{ Id = 'rinki_2024_11_04'; Client = 'Ms. Rinki Singh'; Project = 'Sector-132, Greater Noida'; Date = '2024-11-04'; Kind = 'detailed_estimate' }
    'for supernova.json' = @{ Id = 'astralis_2025_05_01'; Client = 'Mrs. Rinki Singh'; Project = '1823, Astralis, Sector-94, Noida'; Date = '2025-05-01'; Kind = 'detailed_estimate' }
    'for wave one.json' = @{ Id = 'waveone_2025_12_10'; Client = 'Mr. Sanjay'; Project = 'Unit 1714, Wave One, Sector-18, Noida'; Date = '2025-12-10'; Kind = 'detailed_estimate' }
    'for wave one (2).json' = @{ Id = 'waveone_2025_12_10_lumpsum'; Client = 'Mr. Sanjay'; Project = 'Unit 1714, Wave One, Sector-18, Noida'; Date = '2025-12-10'; Kind = 'lumpsum_draft' }
    'for sachin jain.json' = @{ Id = 'iccs_lounge_2025_12_17'; Client = 'ICCS'; Project = 'Sector-2, Noida'; Date = '2025-12-17'; Kind = 'detailed_estimate' }
    'FRO ICCS.json' = @{ Id = 'iccs_office_2025_12_17'; Client = 'ICCS'; Project = 'Sector-2, Noida'; Date = '2025-12-17'; Kind = 'rate_plus_qty_estimate' }
    'for pg.json' = @{ Id = 'livzone_finishing_2026_01_30'; Client = 'Building finishing rate card'; Project = 'Greater Noida'; Date = '2026-01-30'; Kind = 'unit_rate_card' }
}

$allItems = New-Object System.Collections.Generic.List[object]
$quotations = New-Object System.Collections.Generic.List[object]
$termsByQuote = @{}

Get-ChildItem -Path $rawDir -Filter '*.json' | Sort-Object Name | ForEach-Object {
  try {
    $file = $_
    Write-Host "Parsing $($file.Name) ..."
    $meta = $sheetMeta[$file.Name]
    if (-not $meta) {
        $meta = @{ Id = (Get-Slug $file.BaseName); Client = $file.BaseName; Project = ''; Date = $null; Kind = 'estimate' }
    }
    $rows = Get-Content -Raw -Path $file.FullName | ConvertFrom-Json
    $brand = ''
    $title = ''
    $currentWorkType = $null
    $currentWorkTypeCode = $null
    $currentArea = $null
    $currentAreaCode = $null
    $currentGroup = $null
    $sectionIsArea = $false
    $inTerms = $false
    $terms = New-Object System.Collections.Generic.List[string]
    $quoteItems = New-Object System.Collections.Generic.List[object]
    $gstPercent = 18
    $grandTotal = $null
    $gstAmount = $null
    $totalWithGst = $null

    foreach ($row in @($rows)) {
        $c1 = Collapse-Text $row.c1
        $c2 = Collapse-Text $row.c2
        $c3 = Collapse-Text $row.c3
        $c4 = Collapse-Text $row.c4
        $c5 = Collapse-Text $row.c5
        $c6 = Collapse-Text $row.c6
        $c7 = Collapse-Text $row.c7
        $c8 = Collapse-Text $row.c8
        $blob = Collapse-Text "$c1 $c2 $c3 $c4"

        if ([string]::IsNullOrWhiteSpace($brand) -and $c1 -match 'Interiors|Architects') { $brand = $c1 }
        if ([string]::IsNullOrWhiteSpace($title) -and $c4 -match '(?i)estimate') { $title = $c4 }

        if ($blob -match '(?i)28%\s*gst') { $gstPercent = 18 }
        if ($c1 -match '(?i)^gst' -or $c2 -match '(?i)^gst 18') { $gstAmount = Parse-Number $c7; if (-not $gstAmount) { $gstAmount = Parse-Number $c2 } }
        if ($c1 -match '(?i)^grand total' -or $c1 -match '(?i)^total$' -or $c1 -match '(?i)^total \(') {
            $maybe = Parse-Number $c7
            if ($maybe) { $grandTotal = $maybe }
        }
        if ($blob -match '(?i)total (project|interior|cost) with gst' -or $c1 -match '(?i)with gst') {
            $maybe = Parse-Number $c7
            if ($maybe) { $totalWithGst = $maybe }
        }

        if ($blob -match '(?i)other terms') { $inTerms = $true }
        if ($inTerms) {
            $termText = Collapse-Text $(if ($c1) { $c1 } elseif ($c2) { $c2 } else { $c4 })
            if ($termText -and $termText -notmatch '(?i)^other terms') { $terms.Add((Fix-Typos $termText)) }
            continue
        }

        if (Test-SkipRow $c1 $c2 $c4) { continue }

        $code = $c1
        $isNumber = $code -match '^\d+$'
        $isLetter = $code -match '^[A-Za-z]$'
        $isNumberLetter = $code -match '^\d+[A-Za-z]$'
        $hasMoney = $null -ne (Parse-Number $c5) -or $null -ne (Parse-Number $c6) -or $null -ne (Parse-Number $c7) -or $c6 -match '(?i)\d+\s*[xX]\s*\d+'
        $hasUnit = -not [string]::IsNullOrWhiteSpace((Normalize-Unit $c4))
        $name = Fix-Typos $c2
        $desc = Fix-Typos $c3

        if ($isNumber -and -not $hasMoney -and -not $hasUnit -and [string]::IsNullOrWhiteSpace($desc) -and $name) {
            if (Test-AreaName $name) {
                $currentArea = Get-CanonicalArea $name
                $currentAreaCode = $code
                $currentGroup = $null
                $sectionIsArea = $true
                $mapped = Match-WorkTypeName $name
                if (-not $mapped) { $mapped = 'Furniture' }
                $currentWorkType = $mapped
                $currentWorkTypeCode = $code
            } else {
                $mapped = Match-WorkTypeName $name
                $currentWorkType = $(if ($mapped) { $mapped } else { (Get-Culture).TextInfo.ToTitleCase($name.ToLowerInvariant()) })
                $currentWorkTypeCode = $code
                $currentArea = $null
                $currentAreaCode = $null
                $currentGroup = $null
                $sectionIsArea = $false
            }
            continue
        }

        if ($isNumberLetter -and $name -and -not $hasMoney) {
            if (Test-AreaName $name) {
                $currentArea = Get-CanonicalArea $name
                $currentAreaCode = $code
                $currentGroup = $null
            } else {
                $currentGroup = $name
                if (-not $currentWorkType) {
                    $mapped = Match-WorkTypeName $name
                    $currentWorkType = $(if ($mapped) { $mapped } else { 'Miscellaneous' })
                    $currentWorkTypeCode = $code
                }
            }
            continue
        }

        $isItem = $isLetter -or ($isNumber -and ($hasMoney -or $hasUnit -or $desc)) -or ($isNumberLetter -and ($hasMoney -or $hasUnit))
        if (-not $isItem) { continue }
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        $unit = Normalize-Unit $c4
        $qty = Parse-Number $c5
        $rate = Parse-Number $c6
        $amount = Parse-Number $c7
        $hvac = Parse-HvacCarpetRate $c6
        if ($hvac) {
            $qty = $hvac.Quantity
            $rate = $hvac.UnitRate
            if (-not $unit) { $unit = 'sqft' }
        }
        if (-not $unit) {
            if ($null -eq $qty -and $null -eq $rate -and $null -ne $amount) { $unit = 'lumpsum' }
        }
        if ($null -eq $rate -and $null -ne $amount -and $null -ne $qty -and $qty -ne 0) {
            $rate = [math]::Round($amount / $qty, 2)
        }
        if ($null -eq $amount -and $null -ne $qty -and $null -ne $rate) {
            $amount = [math]::Round($qty * $rate, 2)
        }
        if ($unit -eq 'lumpsum' -and $null -eq $rate -and $null -ne $amount) {
            $rate = $amount
            if ($null -eq $qty) { $qty = 1 }
        }
        if ($unit -eq 'lumpsum' -and $null -ne $qty -and $qty -gt 1 -and $null -ne $rate -and $rate -lt 5000) {
            $unit = 'sqft'
        }

        $workType = $currentWorkType
        if ($isNumber -and -not $currentWorkType) {
            $mapped = Match-WorkTypeName $name
            $workType = $(if ($mapped) { $mapped } else { $null })
        }
        if ((-not $workType) -or ($sectionIsArea -and $workType -eq 'Furniture') -or ($workType -match '^Miscellaneous')) {
            $inferred = Infer-WorkTypeFromItem $name $desc
            if ($inferred) { $workType = $inferred }
        }
        if (-not $workType) {
            $mapped = Match-WorkTypeName $name
            $workType = $(if ($mapped) { $mapped } else { 'Miscellaneous' })
        }
        $workTypeCode = $(if ($currentWorkTypeCode) { $currentWorkTypeCode } elseif ($isNumber) { $code } else { $null })
        $area = $currentArea
        $areaFromItem = Infer-WorkTypeFromItem $name $desc
        if ((Test-AreaName $name) -and $isNumber) { $area = Get-CanonicalArea $name }

        $scopeName = $name
        if ($currentGroup -and $name -match '(?i)^\d+\s*mm') {
            $scopeName = "$currentGroup - $name"
        }
        $canon = Get-CanonicalScope $scopeName
        $makes = Get-Makes "$name $desc"
        $itemHash = @{}
        $itemHash['quotationId'] = $meta.Id
        $itemHash['sourceSheet'] = $file.BaseName.Trim()
        $itemHash['workType'] = $workType
        $itemHash['workTypeCode'] = $workTypeCode
        $itemHash['area'] = $area
        $itemHash['areaCode'] = $currentAreaCode
        $itemHash['workScopeCode'] = $(if ($isLetter -or $isNumberLetter) { $code.ToUpperInvariant() } elseif ($isNumber) { $code } else { $null })
        $itemHash['name'] = $scopeName
        $itemHash['canonicalScopeId'] = $canon.Id
        $itemHash['canonicalScope'] = $canon.Name
        $itemHash['groupName'] = $currentGroup
        $itemHash['description'] = $desc
        $itemHash['unit'] = $unit
        $itemHash['unitRaw'] = $c4
        $itemHash['quantity'] = $qty
        $itemHash['quantityRaw'] = $c5
        $itemHash['unitRate'] = $rate
        $itemHash['unitRateRaw'] = $c6
        $itemHash['amount'] = $amount
        $itemHash['amountRaw'] = $c7
        $itemHash['remark'] = $c8
        $itemHash['makes'] = @($makes)
        $itemObj = New-Record $itemHash
        $allItems.Add($itemObj) | Out-Null
        $quoteItems.Add($itemObj) | Out-Null
    }

    $termsByQuote[$meta.Id] = @($terms)
    $brandText = (($brand | ForEach-Object { "$_" }) -join ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($brandText)) { $brandText = 'Metoph Architects & Interiors' }
    $quoteRec = @{}
    $quoteRec['id'] = $meta.Id
    $quoteRec['sourceSheet'] = $file.BaseName.Trim()
    $quoteRec['kind'] = $meta.Kind
    $quoteRec['brand'] = $brandText
    $quoteRec['client'] = $meta.Client
    $quoteRec['project'] = $meta.Project
    $quoteRec['date'] = $meta.Date
    $quoteRec['title'] = (Collapse-Text $title)
    $quoteRec['gstPercent'] = $gstPercent
    $quoteRec['grandTotal'] = $grandTotal
    $quoteRec['gstAmount'] = $gstAmount
    $quoteRec['totalWithGst'] = $totalWithGst
    $quoteRec['itemCount'] = $quoteItems.Count
    $quoteRec['terms'] = @($terms)
    $quoteRec['items'] = $quoteItems.ToArray()
    $quotations.Add((New-Record $quoteRec))
  } catch {
    Write-Host ("ERROR in {0}: {1}" -f $file.Name, $_.Exception.Message)
    Write-Host $_.ScriptStackTrace
    throw
  }
}

function Get-WorkTypeSerial([string]$name) {
    foreach ($def in $script:WorkTypeDefs) { if ($def.Name -eq $name) { return $def.Serial } }
    return 99
}

$workTypeNames = $allItems | ForEach-Object { $_.workType } | Where-Object { $_ } | Sort-Object -Unique
$workTypes = New-Object System.Collections.Generic.List[object]
foreach ($wtName in ($workTypeNames | Sort-Object { Get-WorkTypeSerial $_ }, { $_ })) {
    $wtItems = @($allItems | Where-Object { $_.workType -eq $wtName })
    $scopeMap = @{}
    foreach ($it in $wtItems) {
        $key = $it.canonicalScopeId + '|' + $it.unit
        if (-not $scopeMap.ContainsKey($key)) {
            $scopeMap[$key] = @{
                Id = $it.canonicalScopeId
                Name = $it.canonicalScope
                Unit = $it.unit
                Descriptions = New-Object System.Collections.Generic.List[string]
                Aliases = New-Object System.Collections.Generic.List[string]
                Areas = New-Object System.Collections.Generic.List[string]
                Makes = New-Object System.Collections.Generic.List[string]
                Codes = New-Object System.Collections.Generic.List[string]
                Rates = New-Object System.Collections.Generic.List[double]
                Amounts = New-Object System.Collections.Generic.List[double]
                Samples = New-Object System.Collections.Generic.List[object]
            }
        }
        $bucket = $scopeMap[$key]
        if ($it.description -and -not $bucket.Descriptions.Contains($it.description)) { $bucket.Descriptions.Add($it.description) }
        if ($it.name -and -not $bucket.Aliases.Contains($it.name)) { $bucket.Aliases.Add($it.name) }
        if ($it.area -and -not $bucket.Areas.Contains($it.area)) { $bucket.Areas.Add($it.area) }
        foreach ($m in @($it.makes)) { if ($m -and -not $bucket.Makes.Contains($m)) { $bucket.Makes.Add($m) } }
        if ($it.workScopeCode -and -not $bucket.Codes.Contains($it.workScopeCode)) { $bucket.Codes.Add($it.workScopeCode) }
        if ($null -ne $it.unitRate) { $bucket.Rates.Add([double]$it.unitRate) }
        elseif ($it.unit -eq 'lumpsum' -and $null -ne $it.amount) { $bucket.Rates.Add([double]$it.amount) }
        if ($null -ne $it.amount) { $bucket.Amounts.Add([double]$it.amount) }
        $sampleHash = @{}
        $sampleHash['quotationId'] = $it.quotationId
        $sampleHash['area'] = $it.area
        $sampleHash['quantity'] = $it.quantity
        $sampleHash['unitRate'] = $it.unitRate
        $sampleHash['amount'] = $it.amount
        $bucket.Samples.Add((New-Record $sampleHash)) | Out-Null
    }

    $scopes = New-Object System.Collections.Generic.List[object]
    foreach ($key in ($scopeMap.Keys | Sort-Object)) {
        $b = $scopeMap[$key]
        $rateArr = @($b.Rates)
        $suggested = Get-Median $rateArr
        $minR = $null
        $maxR = $null
        if ($rateArr.Count -gt 0) {
            $minR = ($rateArr | Measure-Object -Minimum).Minimum
            $maxR = ($rateArr | Measure-Object -Maximum).Maximum
        }
        $bestDesc = ($b.Descriptions | Sort-Object Length -Descending | Select-Object -First 1)
        if (-not $bestDesc) { $bestDesc = '' }
        $code = ($b.Codes | Where-Object { $_ -match '^[A-Z]$' } | Select-Object -First 1)
        $unitText = [string]$b.Unit
        $scopeHash = @{}
        $scopeHash['id'] = 'ws_' + [string]$b.Id + $(if ($unitText) { '_' + $unitText } else { '' })
        $scopeHash['workTypeId'] = 'wt_' + (Get-Slug $wtName)
        $scopeHash['workType'] = $wtName
        $scopeHash['code'] = $code
        $scopeHash['name'] = [string]$b.Name
        $scopeHash['aliases'] = @($b.Aliases)
        $scopeHash['description'] = [string]$bestDesc
        $scopeHash['unit'] = $unitText
        $scopeHash['suggestedRate'] = $suggested
        $scopeHash['minRate'] = $minR
        $scopeHash['maxRate'] = $maxR
        $scopeHash['sampleCount'] = [int]$b.Samples.Count
        $scopeHash['typicalAreas'] = $b.Areas.ToArray()
        $scopeHash['makes'] = $b.Makes.ToArray()
        $scopeHash['samples'] = $b.Samples.ToArray()
        $scopes.Add((New-Record $scopeHash)) | Out-Null
    }

    $areasForType = @($wtItems | ForEach-Object { $_.area } | Where-Object { $_ } | Sort-Object -Unique)
    $wtHash = @{}
    $wtHash['id'] = 'wt_' + (Get-Slug $wtName)
    $wtHash['serialNo'] = Get-WorkTypeSerial $wtName
    $wtHash['name'] = $wtName
    $wtHash['scopeCount'] = $scopes.Count
    $wtHash['areas'] = $areasForType
    $wtHash['scopes'] = $scopes.ToArray()
    $workTypes.Add((New-Record $wtHash)) | Out-Null
}

$workScopes = New-Object System.Collections.Generic.List[object]
foreach ($wt in $workTypes) {
    foreach ($sc in $wt.scopes) { $workScopes.Add($sc) }
}

$areaMap = @{}
foreach ($it in $allItems) {
    if (-not $it.area) { continue }
    if (-not $areaMap.ContainsKey($it.area)) {
        $areaMap[$it.area] = @{
            Name = $it.area
            WorkTypes = New-Object System.Collections.Generic.List[string]
            Scopes = New-Object System.Collections.Generic.List[string]
        }
    }
    if ($it.workType -and -not $areaMap[$it.area].WorkTypes.Contains($it.workType)) { $areaMap[$it.area].WorkTypes.Add($it.workType) }
    if ($it.canonicalScope -and -not $areaMap[$it.area].Scopes.Contains($it.canonicalScope)) { $areaMap[$it.area].Scopes.Add($it.canonicalScope) }
}
$areas = @($areaMap.Keys | Sort-Object | ForEach-Object {
    $ah = @{}
    $ah['id'] = 'area_' + (Get-Slug $_)
    $ah['name'] = $_
    $ah['typicalWorkTypes'] = @($areaMap[$_].WorkTypes)
    $ah['typicalScopes'] = @($areaMap[$_].Scopes)
    New-Record $ah
})

$rateCard = @($workScopes | ForEach-Object {
    $rh = @{}
    $rh['id'] = $_.id
    $rh['workType'] = $_.workType
    $rh['workScope'] = $_.name
    $rh['description'] = $_.description
    $rh['unit'] = $_.unit
    $rh['suggestedRate'] = $_.suggestedRate
    $rh['minRate'] = $_.minRate
    $rh['maxRate'] = $_.maxRate
    $rh['sampleCount'] = $_.sampleCount
    $rh['typicalAreas'] = $_.typicalAreas
    $rh['makes'] = $_.makes
    $rh['aliases'] = $_.aliases
    New-Record $rh
})

$defaults = [ordered]@{
    gstPercent      = 18
    hvacGstPercent  = 28
    currency        = 'INR'
    amountFormula   = 'quantity * unitRate'
    paymentTerms    = @(
        '30% Advance'
        '20-30% after delivery of material on site'
        'Remaining progressively every 10-20 days'
        '5% at the time of finishing (where applicable)'
    )
    exclusions      = @(
        'TV, decor items, projector, IT server'
        'Paintings, planters, wall art, signage, logo, wall graphics'
        'Ceiling/wall fans, decorative lights, chandelier, geyser'
        'Kitchen appliances, curtains, WiFi/internet routers'
    )
    notes           = @(
        'Extra items beyond this estimate are charged separately after approval'
        'Quantities are tentative and actual measurement at site will govern billing'
        'If design, layout or quantity changes, cost will be revised'
    )
}

$units = @(
    @{ code = 'sqft'; name = 'Square Feet'; typicalUses = @('flooring','ceiling','paint','partition','blinds') }
    @{ code = 'pcs'; name = 'Piece / Number'; typicalUses = @('furniture','doors','fixtures') }
    @{ code = 'seat'; name = 'Per Seat'; typicalUses = @('sofa','chairs') }
    @{ code = 'rft'; name = 'Running Feet'; typicalUses = @('skirting','panelling','cove') }
    @{ code = 'mtr'; name = 'Meter'; typicalUses = @('piping','cabling') }
    @{ code = 'lumpsum'; name = 'Lumpsum'; typicalUses = @('dismantling','plumbing package','AHU') }
    @{ code = 'step'; name = 'Per Step'; typicalUses = @('staircase') }
)

$pricedCount = @($rateCard | Where-Object { $null -ne $_.suggestedRate }).Count
$catalog = New-Object PSObject
$catalog | Add-Member generatedAt ((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'))
$catalog | Add-Member sourceFile 'samle (1).xlsx'
$catalog | Add-Member purpose 'Reference catalog for generating interior estimates and quotations'
$schema = New-Object PSObject
$schema | Add-Member workType 'Numbered S.No. groups such as Civil Work, Flooring, Furniture'
$schema | Add-Member workScope 'Lettered items (A, B, C...) under a work type'
$schema | Add-Member area 'Named spaces such as Reception, Meeting Room, Cabin (e.g. 9A, 9B)'
$schema | Add-Member amount 'Quantity x Unit Rate'
$catalog | Add-Member schema $schema
$catalog | Add-Member defaults ([pscustomobject]$defaults)
$catalog | Add-Member units $units
$summary = New-Object PSObject
$summary | Add-Member quotationCount ([int]$quotations.Count)
$summary | Add-Member lineItemCount ([int]$allItems.Count)
$summary | Add-Member workTypeCount ([int]$workTypes.Count)
$summary | Add-Member workScopeCount ([int]$workScopes.Count)
$summary | Add-Member areaCount ([int]@($areas).Count)
$summary | Add-Member pricedScopeCount ([int]$pricedCount)
$catalog | Add-Member summary $summary
$catalog | Add-Member workTypes $workTypes.ToArray()
$catalog | Add-Member areas @($areas)
$catalog | Add-Member rateCard @($rateCard)
$quoteSummaries = New-Object System.Collections.Generic.List[object]
foreach ($q in $quotations) {
    $qh = @{}
    $qh['id'] = $q.id
    $qh['sourceSheet'] = $q.sourceSheet
    $qh['kind'] = $q.kind
    $qh['brand'] = $q.brand
    $qh['client'] = $q.client
    $qh['project'] = $q.project
    $qh['date'] = $q.date
    $qh['gstPercent'] = $q.gstPercent
    $qh['grandTotal'] = $q.grandTotal
    $qh['gstAmount'] = $q.gstAmount
    $qh['totalWithGst'] = $q.totalWithGst
    $qh['itemCount'] = $q.itemCount
    $quoteSummaries.Add((New-Record $qh)) | Out-Null
}
$catalog | Add-Member quotations $quoteSummaries.ToArray()

$termA = @{}
$termA['id'] = 'standard_interior'
$termA['name'] = 'Standard interior estimate'
$termA['paymentTerms'] = @($defaults.paymentTerms)
$termA['exclusions'] = @($defaults.exclusions)
$termA['notes'] = @($defaults.notes)
$termA['gstPercent'] = 18
$termA['hvacGstPercent'] = 28
$termB = @{}
$termB['id'] = 'short_finishing'
$termB['name'] = 'Short finishing / 30-day project'
$termB['paymentTerms'] = @('30% Advance','30% after delivery of material on site (within 10 days)','Remaining 20% + 20% every 10 days')
$termB['exclusions'] = @()
$termB['notes'] = @('Estimated project completion time 30 days','18% GST will be extra on bill')
$termB['gstPercent'] = 18
$termB['hvacGstPercent'] = 18
$termsTemplates = @((New-Record $termA), (New-Record $termB))

function Write-Json($obj, $path) {
    $json = ConvertTo-Json -InputObject $obj -Depth 12
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote $path"
}

Write-Json $catalog (Join-Path $dataDir 'estimate_catalog.json')
Write-Json $workTypes.ToArray() (Join-Path $dataDir 'work_types.json')
Write-Json $workScopes.ToArray() (Join-Path $dataDir 'work_scopes.json')
Write-Json @($areas) (Join-Path $dataDir 'areas.json')
Write-Json @($rateCard) (Join-Path $dataDir 'rate_card.json')
Write-Json $quotations.ToArray() (Join-Path $dataDir 'quotations.json')
Write-Json ([pscustomobject]$defaults) (Join-Path $dataDir 'estimate_defaults.json')
Write-Json $termsTemplates (Join-Path $dataDir 'terms_templates.json')

$allItems | Select-Object quotationId, sourceSheet, workType, workTypeCode, area, areaCode, workScopeCode, name, canonicalScopeId, canonicalScope, groupName, description, unit, quantity, unitRate, amount, remark, @{ Name = 'makes'; Expression = { @($_.makes) -join '; ' } } | Export-Csv -Path (Join-Path $dataDir 'quotation_line_items.csv') -NoTypeInformation -Encoding UTF8
$rateCard | Select-Object id, workType, workScope, unit, suggestedRate, minRate, maxRate, sampleCount, description | Export-Csv -Path (Join-Path $dataDir 'rate_card.csv') -NoTypeInformation -Encoding UTF8

foreach ($name in @('estimate_catalog.json','work_types.json','work_scopes.json','areas.json','rate_card.json','estimate_defaults.json','terms_templates.json')) {
    Copy-Item (Join-Path $dataDir $name) (Join-Path $assetsDir $name) -Force
}

Write-Output ('Quotations: {0}' -f [int]$quotations.Count)
Write-Output ('Line items: {0}' -f [int]$allItems.Count)
Write-Output ('Work types: {0}' -f [int]$workTypes.Count)
Write-Output ('Work scopes: {0}' -f [int]$workScopes.Count)
Write-Output ('Areas: {0}' -f [int]@($areas).Count)
Write-Output ('Priced scopes: {0}' -f [int]$pricedCount)
Write-Output '--- work types ---'
foreach ($wt in $workTypes) {
    $areaText = ''
    if ($wt.areas) { $areaText = ($wt.areas -join ', ') }
    Write-Output ('{0,2} {1,-28} scopes={2,3}  {3}' -f [int]$wt.serialNo, [string]$wt.name, [int]$wt.scopeCount, $areaText)
}
