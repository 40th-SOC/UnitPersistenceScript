persistence = {}

do

    local columns = {
        "unitName",
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
                row = row .. string.format(fmt, unitRecord[col])
            end
            row = row .. "\n"
            csv = csv .. row
        end

        log("Writing report file...")
        fp:write(csv)
        fp:close()
    end

    local function makeUnitRecord(unit, isDead, shouldSpawn)
        local record = {}
        for i,col in ipairs(columns) do
            record[col] = nil
        end

        local point = unit:getPoint()

        record.unitName = unit:getName()
        record.groupName = unit:getGroup():getName()
        record.typeName = unit:getTypeName()
        record.coalition = unit:getCoalition()
        record.country = unit:getCountry()
        record.dead = isDead and "true" or "false"
        record.shouldSpawn = shouldSpawn and "true" or "false"
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
         
            local record = makeUnitRecord(obj, true, false)
            log("Unit dead: %s", record.unitName)
            table.insert(unitDB, record)
            writeReport()
        end
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

    local function reconcileUnits()
        for i,unit in ipairs(unitDB) do
            if unit.dead == "true" then
                local u = Unit.getByName(unit.unitName)

                if u then
                    u:destroy()
                end
            end
        end
    end

    function persistence.init()
        internalConfig = buildConfig()
        log(mist.utils.tableShow(internalConfig))

        local fp = getReportFile()

        if  fp then
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

        mist.addEventHandler(eventHandler)
    end
end