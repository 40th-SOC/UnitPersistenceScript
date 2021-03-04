# WeaponUsage

A DCS Lua script that will persist the state of units (dead or alive) between server restarts. Also tracks units spawned via CTLD to persist them between restarts as well.

## Usage

To enable mission scripts to write to disk, you must first comment out these lines in your <DCS install directory>\Scripts\MissionScripting.lua. \*\*Note you will need to do this after every DCS update

```lua
do
    -- sanitizeModule('os')
    -- sanitizeModule('io')
    -- sanitizeModule('lfs')
    require = nil
    loadlib = nil
end
```

To use the script, download the contents of UnitPersistenceScript.lua and add a "DO SCRIPT FILE" action to your mission. Once the script is loaded, add a "DO SCRIPT" action with the following code:

```lua
persistence.init()
```

## Configuration

Add a trigger action AFTER the script has been loaded, add a "DO SCRIPT" action. Any configuration options NOT specified will be set to their default (shown below).

These are the available configuration options:

```lua
persistence.config = {
    ["REPORT_FILENAME"] = "units.csv",
}

persistence.init()
```

## Development

To enable verbose logging, set this in your <DCS install directory>\Scripts\MissionScripting.lua

```lua
do
    __DEV_ENV = true -- <-- verbose logging
    -- sanitizeModule('os')
    -- sanitizeModule('io')
    -- sanitizeModule('lfs')
    require = nil
    loadlib = nil
end
```

Add this to a "DO SCRIPT" action in your mission to reload the scripts every time the mission starts.

dofile(lfs.writedir()..[[..\..\UnitPersistenceScript\UnitPersistenceScript.lua]])
