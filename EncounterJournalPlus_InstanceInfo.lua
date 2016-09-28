local function GetTableSize(tb)
  local size = 0;

  if type(tb) == "table" then
    for i, val in pairs(tb) do
      size = size + 1;
    end
  end

  return size;
end

local function GetSavedInstances()
  local db = {
    ["dungeons"] = {},
    ["raids"] = {},
  };

  for i = 1, GetNumSavedInstances() do
    local name, id, _, difficulty, locked, extended, _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i);
    local instances = isRaid and db.raids or db.dungeons;

    if instances[name] == nil then
      instances[name] = {};
    end

    if locked or extended then
      table.insert(instances[name], {
        ["name"] = name,
        ["difficulty"] = difficulty,
        ["locked"] = locked,
        ["extended"] = extended,
        ["isRaid"] = isRaid,
        ["maxPlayers"] = maxPlayers,
        ["difficultyName"] = difficultyName,
        ["numEncounters"] = numEncounters,
        ["encounterProgress"] = encounterProgress,
      });

      table.sort(instances[name], function(a, b)
        return a.difficulty < b.difficulty;
      end);
    end
  end

  return db;
end

local function GetNumSavedDBInstances(db, type)
  local size = 0;

  for instanceName, instances in pairs(db[type]) do
    for difficulty, instance in pairs(instances) do
      if instance.locked or instance.extended then
        size = size + 1;
      end
    end
  end

  return size;
end

local function GetEncounterJournalInstanceTabs()
  if EncounterJournal ~= nil then
    return EncounterJournal.instanceSelect.dungeonsTab, EncounterJournal.instanceSelect.raidsTab;
  end

  return nil, nil;
end

local function HandleEncounterJournalScrollInstances(func)
  if EncounterJournal then
    table.foreach(EncounterJournal.instanceSelect.scroll.child, function(instanceButtonKey, instanceButton)
      if string.match(instanceButtonKey, "instance%d+") and type(instanceButton) == "table" then
        func(instanceButton);
      end
    end);
  end
end

local function ResetEncounterJournalScrollInstancesInfo()
  HandleEncounterJournalScrollInstances(function(instanceButton)
    if instanceButton.instanceInfoDifficulty == nil then
      instanceButton.instanceInfoDifficulty = instanceButton:CreateFontString(
        instanceButton:GetName() .. "InstanceInfoDifficulty",
        "OVERLAY",
        "QuestTitleFontBlackShadow"
      );
    end

    if instanceButton.instanceInfoEncounterProgress == nil then
      instanceButton.instanceInfoEncounterProgress = instanceButton:CreateFontString(
        instanceButton:GetName() .. "InstanceInfoEncounterProgress",
        "OVERLAY",
        "QuestTitleFontBlackShadow"
      );
    end

    local difficultyText = instanceButton.instanceInfoDifficulty;
    local encounterProgressText = instanceButton.instanceInfoEncounterProgress;
    local font = difficultyText:GetFont();

    difficultyText:SetPoint("BOTTOMLEFT", 9, 7);
    difficultyText:SetJustifyH("LEFT");
    difficultyText:SetFont(font, 12);
    difficultyText:Hide();

    encounterProgressText:SetPoint("BOTTOMRIGHT", -7, 7);
    encounterProgressText:SetJustifyH("RIGHT");
    encounterProgressText:SetFont(font, 12);
    encounterProgressText:Hide();
  end);
end

local function RenderSavedInstancesOverview(savedDB)
  if EncounterJournal ~= nil then
    local scroll = EncounterJournal.instanceSelect.scroll.child;

    if scroll.savedInstancesOverview == nil then
      scroll.savedInstancesOverview = scroll:CreateFontString(
        scroll:GetName() .. "SavedInstancesOverview",
        "OVERLAY",
        "QuestTitleFontBlackShadow"
      );
    end

    local dungeonsTab, raidsTab = GetEncounterJournalInstanceTabs();
    local currentInstanceType = (raidsTab ~= nil and not raidsTab:IsEnabled()) and "raids" or "dungeons";

    local overview = scroll.savedInstancesOverview;
    local font = overview:GetFont();

    overview:SetPoint("BOTTOMRIGHT", -35, 7);
    overview:SetJustifyH("RIGHT");
    overview:SetFont(font, 12);
    overview:SetText(string.format(
      EJPlus_InstanceInfo_TXT.SAVED_INSTANCES_OVERVIEW,
      _G[string.upper(currentInstanceType)],
      GetNumSavedDBInstances(savedDB, currentInstanceType)
    ));
  end
end

local function RenderInstanceInfo(instanceButton, savedInstance)
  local difficultyButton = instanceButton.instanceInfoDifficulty;
  local encounterProgressButton = instanceButton.instanceInfoEncounterProgress;
  local difficulty = "";
  local encounterProgress = "";

  table.foreach(savedInstance, function(index, instance)
    difficulty = difficulty .. "\n" .. instance.difficultyName;
    encounterProgress = encounterProgress .. "\n" .. string.format("%s/%s", instance.encounterProgress, instance.numEncounters);
  end);

  difficultyButton:SetText(difficulty);
  difficultyButton:SetWidth(difficultyButton:GetStringWidth() * 1.25);
  difficultyButton:Show();

  encounterProgressButton:SetText(encounterProgress);
  encounterProgressButton:SetWidth(encounterProgressButton:GetStringWidth() * 1.25);
  encounterProgressButton:Show();
end

local function RenderEncounterJournalInstances()
  local savedDB = GetSavedInstances();
  local dungeonsTab, raidsTab = GetEncounterJournalInstanceTabs();
  local savedInstances = savedDB[(raidsTab ~= nil and not raidsTab:IsEnabled()) and "raids" or "dungeons"];

  RenderSavedInstancesOverview(savedDB);

  HandleEncounterJournalScrollInstances(function(instanceButton)
    local instanceName = EJ_GetInstanceInfo(instanceButton.instanceID);
    local savedInstance = savedInstances[instanceName];

    if savedInstance ~= nil then
      RenderInstanceInfo(instanceButton, savedInstance);
    end
  end);
end

local function EncounterJournalInstanceTab_OnClick()
  for _, tab in ipairs({ "dungeonsTab", "raidsTab" }) do
    EncounterJournal.instanceSelect[tab]:HookScript("OnClick", function(self, button, down)
      ResetEncounterJournalScrollInstancesInfo();
      RequestRaidInfo();
    end);
  end
end

local function EncounterJournalTierDropdown_OnSelect()
  hooksecurefunc("EJ_SelectTier", function()
    ResetEncounterJournalScrollInstancesInfo();
    RequestRaidInfo();
  end);
end

function EncounterJournalPlus_InstanceInfo_OnLoad(self)
  self:RegisterEvent("ADDON_LOADED");
  self:RegisterEvent("UPDATE_INSTANCE_INFO");
end

function EncounterJournalPlus_InstanceInfo_OnEvent(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "Blizzard_EncounterJournal" then
    hooksecurefunc(EncounterJournal, "Show", function()
      local dungeonsTab, raidsTab = GetEncounterJournalInstanceTabs();

      if not dungeonsTab:IsEnabled() or not raidsTab:IsEnabled() then
        ResetEncounterJournalScrollInstancesInfo();
        RequestRaidInfo();
      end
    end);

    EncounterJournalTierDropdown_OnSelect();
    EncounterJournalInstanceTab_OnClick();
  elseif event == "UPDATE_INSTANCE_INFO" then
    RenderEncounterJournalInstances();
  end
end
