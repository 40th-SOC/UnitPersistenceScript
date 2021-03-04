persistence.config = {
    ["REPORT_FILENAME"] = "units.csv",
    -- ["PERSIST_CTLD_UNITS"] = true,
    -- ["IGNORED_TYPE_NAMES"] = {},
}

persistence.init()

timer.scheduleFunction(ctldCallback, { action="unpack", spawnedGroup=Group.getByName("ctld_group") }, timer.getTime() + 5)