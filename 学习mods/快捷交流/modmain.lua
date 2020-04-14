local TheInput = GLOBAL.TheInput
local require = GLOBAL.require

--[[
Note to modders who want to add support for custom announcements for their character:

If you just have the normal stats, just add your strings to GLOBAL.STRINGS_STATUS_ANNOUNCEMENTS,
in the format shown in announcestrings.lua

If you have a custom stat (like Woodie has beaverness), here's what you should do:
in a postinit on statusdisplays/controls, set status._custombadge = your_custom_badge
(for example, I do status._custombadge = status.beaverness for Woodie)
This will make it show/hide the controller button prompt for you custom badge

Then, add onto PlayerHud's SetMainCharacter function to register your custom stat with StatusAnnouncer:

local PlayerHud = require("screens/playerhud")
local PlayerHud_SetMainCharacter = PlayerHud.SetMainCharacter
function PlayerHud:SetMainCharacter(maincharacter, ...)
	PlayerHud_SetMainCharacter(self, maincharacter, ...)
	self.inst:DoTaskInTime(0, function()
		if self._StatusAnnouncer then
			self._StatusAnnouncer:RegisterStat(
				"My Stat's Display Name",
				HUD.controls.status._custombadge, --you could also give it your_custom_badge
				CONTROL_ROTATE_LEFT, -- Left Bumper; keep this as-is
				{     .15,    .35,   .55,    .75      }, --you can also set custom thresholds
				{"EMPTY", "LOW", "MID", "HIGH", "FULL"}, --or custom category names, just match them with your strings table
				function(ThePlayer)
					return	something_that_gets_your_stats_current_value,
							something_that_gets_your_stats_max_value
				end,
				nil --you can give this a function if your character has multiple modes with different strings, see Woodie and StatusAnnouncer:RegisterCommonStats
			)
		end
	end)
end

]]

--Mods that are already enabled
local WHISPER_ONLY = GLOBAL.KnownModIndex:IsModEnabled("workshop-346479579")
local COMBINED_STATUS = (GLOBAL.KnownModIndex:IsModEnabled("workshop-376333686") and "workshop-376333686")	--workshop version
					 or (GLOBAL.KnownModIndex:IsModEnabled("CombinedStatus") and "CombinedStatus")			--forum version
--Mods that haven't loaded yet
for k,v in pairs(GLOBAL.KnownModIndex:GetModsToLoad()) do
	WHISPER_ONLY = WHISPER_ONLY or v == "workshop-346479579"
	COMBINED_STATUS = COMBINED_STATUS or ((v == "CombinedStatus" or v == "workshop-376333686") and v)
end
if COMBINED_STATUS then
	--We need to figure out if it's showing temperature at all
	COMBINED_STATUS = GLOBAL.GetModConfigData("SHOWTEMPERATURE", COMBINED_STATUS)
end

modimport("announcestrings.lua") --creates the ANNOUNCE_STRINGS table

for k,v in pairs(ANNOUNCE_STRINGS) do
	if k ~= "UNKNOWN" and GetModConfigData(k) == false then
		ANNOUNCE_STRINGS[k] = ANNOUNCE_STRINGS.UNKNOWN
	end
end

-- Merge the global table into ANNOUNCE_STRINGS (in case other mods run before)
if type(GLOBAL.STRINGS._STATUS_ANNOUNCEMENTS) == "table" then
	for k,v in pairs(GLOBAL.STRINGS._STATUS_ANNOUNCEMENTS) do
		ANNOUNCE_STRINGS[k] = v;
	end
end
-- Store the merged ANNOUNCE_STRINGS in the global table (so mods that run after can add to / change it)
GLOBAL.STRINGS._STATUS_ANNOUNCEMENTS = ANNOUNCE_STRINGS

local StatusAnnouncer = require("statusannouncer")()

--actually need this one locally to add the controller button hint
local OVERRIDEB = COMBINED_STATUS and GetModConfigData("OVERRIDEB")
StatusAnnouncer:SetLocalParameter("WHISPER", GetModConfigData("WHISPER"))
StatusAnnouncer:SetLocalParameter("WHISPER_ONLY", WHISPER_ONLY)
StatusAnnouncer:SetLocalParameter("EXPLICIT", GetModConfigData("EXPLICIT"))
StatusAnnouncer:SetLocalParameter("OVERRIDEB", OVERRIDEB)
StatusAnnouncer:SetLocalParameter("SHOWDURABILITY", GetModConfigData("SHOWDURABILITY"))
StatusAnnouncer:SetLocalParameter("SHOWPROTOTYPER", GetModConfigData("SHOWPROTOTYPER"))

local PlayerHud = require("screens/playerhud")
local PlayerHud_SetMainCharacter = PlayerHud.SetMainCharacter
function PlayerHud:SetMainCharacter(maincharacter, ...)
	PlayerHud_SetMainCharacter(self, maincharacter, ...)
	self._StatusAnnouncer = StatusAnnouncer
	if maincharacter then
		--Note that this also clears out the stats and cooldowns, so we have to re-register them
		StatusAnnouncer:SetCharacter(maincharacter.prefab)
		StatusAnnouncer:RegisterCommonStats(self, maincharacter.prefab)
	end
end
local PlayerHud_OnMouseButton = PlayerHud.OnMouseButton
function PlayerHud:OnMouseButton(button, down, ...)
	if button == 1000 and down and TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_INSPECT) then
		if StatusAnnouncer:OnHUDMouseButton(self) then
			return true
		end
	end
	if type(PlayerHud_OnMouseButton) == "function" then
		return PlayerHud_OnMouseButton(self, button, down, ...)
	end
end
local PlayerHud_OnControl = PlayerHud.OnControl
function PlayerHud:OnControl(control, down, ...)
	if not down and self.owner ~= nil and self.shown and StatusAnnouncer:OnHUDControl(self, control) then
		return true
	end
	if not down and control == GLOBAL.CONTROL_OPEN_INVENTORY and self.controls.status._beavermode then
		if self._statuscontrollerbuttonhintsshown then
			self:HideStatusControllerButtonHints()
		else
			self:ShowStatusControllerButtonHints()
		end
	end
	return PlayerHud_OnControl(self, control, down, ...)

end

--Hook into the controller open/close inventory to display the controller button hints
local PlayerHud_OpenControllerInventory = PlayerHud.OpenControllerInventory
function PlayerHud:OpenControllerInventory(...)
	PlayerHud_OpenControllerInventory(self, ...)
	self:ShowStatusControllerButtonHints()
end
function PlayerHud:ShowStatusControllerButtonHints()
	self._statuscontrollerbuttonhintsshown = true
	if self.controls.status._beavermode then
		SetModHUDFocus("StatusAnnouncements", true)
	end
	local controller_id = TheInput:GetControllerID()
	self.controls.status.stomach.announce_text:Show()
	self.controls.status.stomach.announce_text:SetString(
		TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_INVENTORY_USEONSCENE))
	self.controls.status.brain.announce_text:Show()
	self.controls.status.brain.announce_text:SetString(
		TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_INVENTORY_EXAMINE))
	self.controls.status.heart.announce_text:Show()
	self.controls.status.heart.announce_text:SetString(
		TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_INVENTORY_USEONSELF))
	if self.controls.status._custombadge then
		self.controls.status._custombadge.announce_text:Show()
		self.controls.status._custombadge.announce_text:SetString(
			TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_ROTATE_LEFT))
	end
	self.controls.status.moisturemeter.announce_text:SetString(
		TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_ROTATE_RIGHT))
	self.controls.status.moisturemeter.controller_crafting_open = true
	if self.controls.status.moisturemeter.activated then
		self.controls.status.moisturemeter.announce_text:Show()
	end
	if OVERRIDEB then
		self.controls.status.temperature.announce_text:Show()
		self.controls.status.temperature.announce_text:SetString(
			TheInput:GetLocalizedControl(controller_id, GLOBAL.CONTROL_CANCEL))
	end
end
local PlayerHud_CloseControllerInventory = PlayerHud.CloseControllerInventory
function PlayerHud:CloseControllerInventory(...)
	PlayerHud_CloseControllerInventory(self, ...)
	self:HideStatusControllerButtonHints()
end
function PlayerHud:HideStatusControllerButtonHints()
	self._statuscontrollerbuttonhintsshown = false
	SetModHUDFocus("StatusAnnouncements", false)
	self.controls.status.stomach.announce_text:Hide()
	self.controls.status.brain.announce_text:Hide()
	self.controls.status.heart.announce_text:Hide()
	if self.controls.status._custombadge then
		self.controls.status._custombadge.announce_text:Hide()
	end
	self.controls.status.moisturemeter.controller_crafting_open = false
	self.controls.status.moisturemeter.announce_text:Hide()
	if OVERRIDEB then
		self.controls.status.temperature.announce_text:Hide()
	end
end

--Adds the controller button hints to the stat badges
local Text = GLOBAL.require("widgets/text")
AddClassPostConstruct("widgets/statusdisplays", function(self)
	self.stomach.announce_text = self.stomach:AddChild(Text(GLOBAL.UIFONT, 30))
	self.stomach.announce_text:SetPosition(-30, 0)
	self.stomach.announce_text:Hide()
	self.brain.announce_text = self.brain:AddChild(Text(GLOBAL.UIFONT, 30))
	self.brain.announce_text:SetPosition(0, 30)
	self.brain.announce_text:Hide()
	self.heart.announce_text = self.heart:AddChild(Text(GLOBAL.UIFONT, 30))
	self.heart.announce_text:SetPosition(30, 0)
	self.heart.announce_text:Hide()
	if self.beaverness then
		self._custombadge = self.beaverness
	end
	self.inst:DoTaskInTime(0, function()
		if self._custombadge then
			self._custombadge.announce_text = self._custombadge:AddChild(Text(GLOBAL.UIFONT, 30))
			self._custombadge.announce_text:SetPosition(30*math.cos(math.pi*.6), 30*math.sin(math.pi*.6))
			self._custombadge.announce_text:Hide()
		end
	end)
	self.moisturemeter.announce_text = self.moisturemeter:AddChild(Text(GLOBAL.UIFONT, 30))
	self.moisturemeter.announce_text:SetPosition(30*math.cos(math.pi*.4), 30*math.sin(math.pi*.4))
	self.moisturemeter.announce_text:Hide()
	local _Activate = self.moisturemeter.Activate
	function self.moisturemeter:Activate(...)
		_Activate(self, ...)
		self.activated = true
		if self.controller_crafting_open then
			self.announce_text:Show()
		end
	end
	local _Deactivate = self.moisturemeter.Deactivate
	function self.moisturemeter:Deactivate(...)
		_Deactivate(self, ...)
		self.activated = false
		if self.controller_crafting_open then
			self.announce_text:Hide()
		end
	end
	self.inst:DoTaskInTime(0, function() --delay it in case Combined Status loads after
		if OVERRIDEB then
			self.temperature.announce_text = self.temperature:AddChild(Text(GLOBAL.UIFONT, 30))
			self.temperature.announce_text:SetPosition(25, -50)
			self.temperature.announce_text:Hide()
		end
	end)
	local _SetBeaverMode = self.SetBeaverMode
	function self:SetBeaverMode(beavermode, ...)
		self._beavermode = beavermode
		-- if self.isghostmode or self.beaverness == nil then return end
		_SetBeaverMode(self, beavermode, ...)
	end
end)

--Manages the controller button hints on recipe popups
local RecipePopup = require("widgets/recipepopup")
local RecipePopup_Refresh = RecipePopup.Refresh
function RecipePopup:Refresh(...)
	local ret = RecipePopup_Refresh(self, ...)
	if TheInput:ControllerAttached() then
		self.teaser:SetString(self.teaser:GetString() .. "\n"
			.. TheInput:GetLocalizedControl(TheInput:GetControllerID(), GLOBAL.CONTROL_MENU_MISC_2)
			.. " Announce")
		local x, y, z = self.teaser:GetPosition():Get()
		if self.skins_spinner then
			self.teaser:SetPosition(x, y%50 == 0 and y-15 or y, z)
			if self.skins_spinner.announce_text then
				self.skins_spinner.announce_text:SetString(TheInput:GetLocalizedControl(
					TheInput:GetControllerID(), GLOBAL.CONTROL_INVENTORY_DROP))
			end
		else
			self.teaser:SetPosition(x, y%50 == 0 and y or y+15, z)
		end
		local ing_controls = {GLOBAL.CONTROL_INVENTORY_USEONSCENE,
			GLOBAL.CONTROL_INVENTORY_EXAMINE, GLOBAL.CONTROL_INVENTORY_USEONSELF}
		for i,v in pairs(self.ing) do
			v.announce_text = v:AddChild(Text(GLOBAL.UIFONT, 30,
				TheInput:GetLocalizedControl(TheInput:GetControllerID(), ing_controls[i])))
			v.announce_text:SetPosition(-32+32*(i-1), 32)
		end
	end
	return ret
end
local RecipePopup_BuildWithSpinner = RecipePopup.BuildWithSpinner
function RecipePopup:BuildWithSpinner(...)
	RecipePopup_BuildWithSpinner(self, ...)
	if TheInput:ControllerAttached() then
		self.skins_spinner.announce_text = self.skins_spinner:AddChild(Text(GLOBAL.UIFONT, 30))
		self.skins_spinner.announce_text:SetPosition(-20,70)
	end
end

--Captures mouse clicks on recipe tiles
local CraftSlot = require("widgets/craftslot")
local CraftSlot_OnControl = CraftSlot.OnControl
function CraftSlot:OnControl(control, down, ...)
	if down and control == GLOBAL.CONTROL_ACCEPT
	and TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_INSPECT)
	and self.owner and self.recipe then
		if self.recipepopup.skins_spinner and self.recipepopup.skins_spinner.focus
		and StatusAnnouncer:AnnounceSkin(self.recipepopup) then
			return true
		else
			return StatusAnnouncer:AnnounceRecipe(self)
		end
		return true
	elseif not TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_INSPECT) then
		return CraftSlot_OnControl(self, control, down, ...)
	end
end

--Captures mouse clicks on inventory items, and prevents them from doing other stuff if we announced
for _,classname in pairs({"invslot", "equipslot"}) do
	local SlotClass = require("widgets/"..classname)
	local SlotClass_OnControl = SlotClass.OnControl
	function SlotClass:OnControl(control, down, ...)
		if down and control == GLOBAL.CONTROL_ACCEPT
			and TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_INSPECT)
			and TheInput:IsKeyDown(GLOBAL.KEY_SHIFT)
			and self.tile then --ignore empty slots
			return StatusAnnouncer:AnnounceItem(self.tile.item,
				self.tile.percent and self.tile.percent:GetString(), self.container, self.owner)
		else
			return SlotClass_OnControl(self, control, down, ...)
		end
	end
end

local InventoryBar = require("widgets/inventorybar")
--Captures controller input for inventory
local InventoryBar_OnControl = InventoryBar.OnControl
function InventoryBar:OnControl(control, down, ...)
	if InventoryBar_OnControl(self, control, down, ...) then return true end --prioritize normal controls
	--catch a few other "do nothing" scenarios
	if down or not self.open then return end
	
	local inv_item = self:GetCursorItem() --this is the active inventory tile item
	if control == GLOBAL.CONTROL_USE_ITEM_ON_ITEM and inv_item then --Y button
		--We shouldn't actually need to check if it's the other scenario for this,
		-- because it would've returned true above
		--also, GetCursorItem() returns nil if there's no active slot, so we know it exists
		return StatusAnnouncer:AnnounceItem(inv_item,
							self.active_slot.tile.percent and self.active_slot.tile.percent:GetString(),
							self.active_slot.container, self.owner)
	end
end
--Add the Announce hint text
local InventoryBar_UpdateCursorText = InventoryBar.UpdateCursorText
function InventoryBar:UpdateCursorText(...)
	InventoryBar_UpdateCursorText(self, ...)
	if TheInput:ControllerAttached() and self.open then
		if self:GetCursorItem() and not self.owner.replica.inventory:GetActiveItem() then
			self.actionstringbody:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), GLOBAL.CONTROL_USE_ITEM_ON_ITEM)
				.." Announce\n"..self.actionstringbody:GetString())
		end
	end
end

AddClassPostConstruct("widgets/giftitemtoast", function(self)
	local _OnMouseButton = self.OnMouseButton
	function self:OnMouseButton(button, down, ...)
		local ret = _OnMouseButton(self, button, down, ...)
		if button == 1000 and down and TheInput:IsControlPressed(GLOBAL.CONTROL_FORCE_INSPECT) then
			StatusAnnouncer:Announce(self.enabled
									and "我收到一个礼物包，现在需要打开它！"
									or "我需要一个科技来打开收到的礼物包!")
		end
	end
end)