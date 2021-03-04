persistence.config = {
    ["REPORT_FILENAME"] = "units.csv",
    -- ["PERSIST_CTLD_UNITS"] = true,
    -- ["IGNORED_TYPE_NAMES"] = {},
}

persistence.init()

-- timer.scheduleFunction(ctldCallback, { action="unpack", spawnedGroup=Group.getByName("ctld_group") }, timer.getTime() + 5)

ctld.logisticUnits = {
    "CTLD Post"
}

ctld.transportPilotNames = {
    "Huey",
}

ctld.hoverPickup = false

ctld.enableCrates = true

ctld.slingLoad = false

ctld.maximumDistanceLogistic = 1000

ctld.JTAC_jtacStatusF10 = false

ctld.addCallback(function(_args)

    trigger.action.outText(_args.action,10)

end)