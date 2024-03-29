persistence = {}

do

    local columns = {
        "unitName",
        "category",
        "groupName",
        "typeName",
        "coalition",
        "country",
        "dead",
        "shouldSpawn",
        "x",
        "y",
        "z",
    }

    local configDefaults = {
        ["REPORT_FILENAME"] = "units.csv",
        -- ["PERSIST_CTLD_UNITS"] = true,
        -- ["IGNORED_TYPE_NAMES"] = {},
    }

    local internalConfig = {}

    local unitDB = {}

    local function log(tmpl, ...)
        local txt = string.format("[PERS] " .. tmpl, ...)

        if __DEV_ENV == true then
            trigger.action.outText(txt, 30) 
        end

        env.info(txt)
    end

    local function buildConfig()
        local cfg = mist.utils.deepCopy(configDefaults)
        
        if persistence.config then
            for k,v in pairs(persistence.config) do
                cfg[k] = v
            end
        end

        return cfg
    end

    local function getReportFile(writeAccess)
        local fileName = string.format("%s\\%s", lfs.writedir(), internalConfig.REPORT_FILENAME)
        local file = io.open(fileName, writeAccess and 'w' or 'r')

        return file
    end

    local function writeReport()
        local fp = getReportFile(true)

        if not fp then
            log("Could not get file handle")
            return
        end

        local csv = ""
        for i,unitRecord in ipairs(unitDB) do
            local row = ""

            for i,col in ipairs(columns) do
                -- Ensure the last column does not get a comma
                local fmt = i == #columns and "%s" or "%s,"
                row = row .. string.format(fmt, unitRecord[col] or "nil")
            end
            row = row .. "\n"
            csv = csv .. row
        end

        log("Writing report file...")
        fp:write(csv)
        fp:close()
    end

    local function makeUnitRecord(unit, category, isDead, shouldSpawn)
        local record = {}
        for i,col in ipairs(columns) do
            record[col] = nil
        end

        local point = unit:getPoint()

        record.unitName = unit:getName()
        record.groupName = unit.getGroup and unit:getGroup():getName()
        record.typeName = unit:getTypeName()
        record.coalition = unit:getCoalition()
        record.country = unit:getCountry()
        record.dead = isDead and "true" or "false"
        record.shouldSpawn = shouldSpawn and "true" or "false"
        record.category = category
        record.x = point.x
        record.y = point.y
        record.z = point.z

        return record
    end

    local function handleUnitKilled(obj)
        if obj.getGroup == nil then
            log("warning: initiator:getGroup is nil")
            return
        end

        if obj:getGroup():getCategory() == Group.Category.GROUND then
            local record = makeUnitRecord(obj, obj:getCategory(), true, false)
            log("Unit dead: %s", record.unitName)
            table.insert(unitDB, record)
            writeReport()
        end
    end

    local function handleStaticKilled(obj)
        local record = makeUnitRecord(obj, obj:getCategory(), true, false)
        log("Static dead: %s", record.unitName)
        table.insert(unitDB, record)
        writeReport()
    end

    local function eventHandler(event)
        local object = event.initiator
        if object == nil then
            return
        end
    
        if event.id == world.event.S_EVENT_DEAD then
            if object:getCategory() == Object.Category.UNIT then
                handleUnitKilled(object)               
            end

            if object:getCategory() == Object.Category.STATIC then
                handleStaticKilled(object)
            end
        end
    end

    local function hydrateState(text)
        local pattern = ""
    
        for i,col in ipairs(columns) do
            local s = i == #columns and "(.*)" or "(.*),"
            pattern = pattern .. s
        end

        for row in text:gmatch("[^\r\n]+") do
            local match = {string.match(row, pattern)}
            local record = {}

            for i,col in ipairs(columns) do
                record[col] = match[i]
            end

            table.insert(unitDB, record)
        end
    end

    local function spawnGroups(groupList)
        for groupName,units in pairs(groupList) do
            local groupData = {
                ["hidden"] = false,
                ["units"] = {},
                ["name"] = groupName,
                ["communication"] = true,
                ["start_time"] = 0,
                ["frequency"] = 124, 
            }

            for i,unit in ipairs(units) do
                table.insert(groupData.units, {
                    ["skill"] = "High",
                    ["name"] = unit.unitName,
                    ["type"] = unit.typeName,
                    ["x"] = unit.x,
                    ["y"] = unit.z,
                    ["z"] = unit.y,
                })
            end

            log("Spawning group %s", groupName)

            coalition.addGroup(coalition.side.BLUE, Group.Category.GROUND, groupData)
        end
    end

    local function reconcileUnits()
        local groupsToSpawn = {}

        for i,unit in ipairs(unitDB) do
            if unit.dead == "true" then
                local u = Unit.getByName(unit.unitName)

                if u then
                    log("Removing unit: %s", unit.unitName)
                    u:destroy()
                end

                -- unit.category is a number, convert to string for comparison
                if unit.category == string.format("%s", Object.Category.STATIC) then
                    local s = StaticObject.getByName(unit.unitName)
                    log("Removing static: %s", unit.unitName)
                    if s then
                        s:destroy()
                    end
                end
            end

            if unit.shouldSpawn == "true" then
                local groupName = unit.groupName
                if not groupsToSpawn[groupName] then
                    groupsToSpawn[groupName] = {}
                end

                table.insert(groupsToSpawn[groupName], unit)
            end
        end

        spawnGroups(groupsToSpawn)
    end

    function ctldCallback(args)
        if args.action ~= "unpack" or not args.spawnedGroup then
            return
        end

        local group = args.spawnedGroup
        local groupName = group:getName()

        log("Inserting group %s into DB", groupName)

        for i,unit in ipairs(group:getUnits()) do
            local record = makeUnitRecord(unit, unit:getCategory(), false, true)
            table.insert(unitDB, record)
        end

        writeReport()
    end

    local function initCTLDTracking()
        if ctld == nil or ctld.addCallback == nil then
            log("CTLD not present, skipping CTLD tracking")
            return
        end
    
        log("Adding CTLD tracking")
        ctld.addCallback(ctldCallback)
    end

    function persistence.init()
        internalConfig = buildConfig()
        log(mist.utils.tableShow(internalConfig))

        local fp = getReportFile()

        if fp then
            local text = fp:read("*all")
            fp:close()
    
            if text == "" then
                log("Error: could not read report file")
            else
                hydrateState(text)
                reconcileUnits()
            end
        else
            log("Report file %s not found. Generating...", internalConfig.REPORT_FILENAME)
            writeReport()
        end

        initCTLDTracking()

        mist.addEventHandler(eventHandler)
    end
end