if SERVER then return end

UtilityMenu = UtilityMenu or {}
UtilityMenu.Settings = UtilityMenu.Settings or {}

UtilityMenu.State = UtilityMenu.State or {
	ScriptRan = false, FreecamEnabled = false, FreecamPosition = Vector(0, 0, 0), FreecamAngle = Angle(0, 0, 0), FrozenViewAngle = Angle(0, 0, 0), EntityCache = {Players = {},
	NPCs = {}, Props = {}}, LastPropKeyState = {}, FreecamReleaseKeysState = false, LastAttackTime = 0, wallPointsLastUpdate = 0, wallPoints = {}, proptransparencyActive = false,
	proptransparencyOriginals = {}, lastCacheUpdate = 0, EntitySignature = ""
}

UtilityMenu.Config = UtilityMenu.Config or {
	Colors = {
		White = Color(255, 255, 255), Cyan = Color(0, 255, 255), Yellow = Color(255, 255, 0), Green = Color(0, 255, 0),
		Black = Color(0, 0, 0), Purple = Color(180, 0, 180), Red = Color(255, 0, 0), Blue = Color(0, 0, 255)
	},
	EntityColors = {Prop = Color(0, 0, 255), NPC = Color(255, 0, 0), Player = Color(255, 255, 255)},
	MapSizes = {150, 200, 250, 300, 400},
	MapScales = {25, 50, 75, 100, 125},
	Gestures = {"agree", "becon", "bow", "cheer", "dance", "disagree", "forward", "group", "halt", "laugh", "muscle", "pers", "robot", "salute", "wave", "zombie"},
	PropKillProps = {
		[KEY_C] = "models/props_phx/construct/metal_plate4x4.mdl", [KEY_G] = "models/XQM/CoasterTrack/slope_225_3.mdl", [KEY_Q] = "models/props/cs_militia/refrigerator01.mdl",
		[KEY_R] = "models/props_canal/canal_bars004.mdl", [KEY_V] = "models/props/de_tides/gate_large.mdl", [KEY_X] = "models/props_phx/wheels/moped_tire.mdl"
	},
	PkAllowedBinds = {
		"+attack", "+attack2", "+back", "+duck", "+forward", "+jump", "+moveleft", "+moveright", "+showscores", "+speed", "+use", "+walk", "gmod_undo", "gm_showteam",
		"impulse 100", "impulse 201", "kill", "messagemode", "open_utility_menu", "slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "toggle_freecam", "+voicerecord"
	},
	FreecamAllowedBinds = {"+showscores", "messagemode", "open_utility_menu", "toggle_freecam", "+voicerecord"},
	FreecamReleaseKeys = {"-forward", "-back", "-moveleft", "-moveright", "-jump", "-duck", "-attack", "-attack2", "-reload"}
}

function UtilityMenu.IsEntityVisible(ent)
    if not IsValid(ent) then return false end
    if (ent:IsPlayer() or ent:IsNPC()) then return true end
    local screenPos = ent:GetPos():ToScreen()
    return screenPos.visible and screenPos.x >= 0 and screenPos.x <= ScrW() and screenPos.y >= 0 and screenPos.y <= ScrH()
end

function UtilityMenu.GetSignature()
    local ply = LocalPlayer()
    if not IsValid(ply) then return "" end
    local propCount = 0
    local npcCount = 0
    local playerCount = 0
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
		if not UtilityMenu.IsEntityVisible(ent) then continue end
        if ent:GetClass():StartWith("prop_") and not ent:IsWeapon() then
            propCount = propCount + 1
        elseif ent:IsNPC() and ent:Alive() then
            npcCount = npcCount + 1
        elseif ent:IsPlayer() and ent ~= ply and ent:Alive() then
            playerCount = playerCount + 1
        end
    end
    return propCount .. "|" .. npcCount .. "|" .. playerCount
end

function UtilityMenu.UpdateEntityCache()
    local newSig = UtilityMenu.GetSignature()
    if newSig == UtilityMenu.State.EntitySignature then return end
    UtilityMenu.State.EntitySignature = newSig
    for _, cache in pairs(UtilityMenu.State.EntityCache) do table.Empty(cache) end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local cacheProps = UtilityMenu.Settings.propbox or UtilityMenu.Settings.prophighlight or UtilityMenu.Settings.propinfo
    local cacheNPCs = UtilityMenu.Settings.npcbox or UtilityMenu.Settings.npchighlight or UtilityMenu.Settings.npcinfo or UtilityMenu.Settings.npcline
    local cachePlayers = UtilityMenu.Settings.playerbox or UtilityMenu.Settings.playerhighlight or UtilityMenu.Settings.playerinfo or UtilityMenu.Settings.playerline
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        if not UtilityMenu.IsEntityVisible(ent) then continue end
        if cacheProps and (ent:GetClass():StartWith("prop_") or ent:GetClass():StartWith("gmod_")) and not (ent:IsWeapon() or ent:GetClass():StartWith("gmod_hands") or ent:GetClass():StartWith("prop_door")) then
            table.insert(UtilityMenu.State.EntityCache.Props, ent)
        elseif cacheNPCs and (ent:IsNPC() or ent:IsNextBot()) and ent:Alive() then
            table.insert(UtilityMenu.State.EntityCache.NPCs, ent)
        elseif cachePlayers and ent:IsPlayer() and ent ~= ply and ent:Alive() and (ent:GetParent() and ent:GetParent():IsVehicle() or not ent:GetNoDraw()) then
            table.insert(UtilityMenu.State.EntityCache.Players, ent)
        end
    end
    UtilityMenu.State.lastCacheUpdate = CurTime()
end

function UtilityMenu.MinimapProjection(position, yaw, scale, radius)
	local delta, angle = position - EyePos(), math.rad(-yaw - 90)
	local x, y = -(delta.x * math.cos(angle) - delta.y * math.sin(angle)), delta.x * math.sin(angle) + delta.y * math.cos(angle)
	x, y = x / scale, y / scale
	return math.Clamp(x, -radius, radius), math.Clamp(y, -radius, radius)
end

local function enableproptransparency(alpha)
	if UtilityMenu.State.proptransparencyActive then return end
	UtilityMenu.State.proptransparencyActive = true
	for _, matName in ipairs(game.GetWorld():GetMaterials()) do
		local mat = Material(matName)
		UtilityMenu.State.proptransparencyOriginals[matName] = UtilityMenu.State.proptransparencyOriginals[matName] or mat:GetFloat("$alpha")
		mat:SetFloat("$alpha", alpha or 0.4)
	end
end

local function disableproptransparency()
	if not UtilityMenu.State.proptransparencyActive then return end
	UtilityMenu.State.proptransparencyActive = false
	for _, matName in ipairs(game.GetWorld():GetMaterials()) do
		local mat = Material(matName)
		mat:SetFloat("$alpha", UtilityMenu.State.proptransparencyOriginals[matName] or 1)
	end
end

function UtilityMenu.SetupHooks()
	hook.Add("HUDPaint", "UtilityMenu_EyeAngleUpdater", function()
		local _ = EyeAngles(), EyePos()
	end)
	hook.Add("Think", "UtilityMenu_UpdateCache", function()
		UtilityMenu.UpdateEntityCache()
	end)
	hook.Add("CreateMove", "UtilityMenu_Freecam", function(cmd)
		if not UtilityMenu.State.FreecamEnabled then
			UtilityMenu.State.FreecamReleaseKeysState = false
			hook.Remove("CalcView", "UtilityMenu_FreecamView")
			hook.Remove("PlayerBindPress", "UtilityMenu_FreecamBlockKeys")
			return
		end
		if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() then return end
		if not UtilityMenu.State.FreecamReleaseKeysState then
			for _, cmdStr in ipairs(UtilityMenu.Config.FreecamReleaseKeys) do
				LocalPlayer():ConCommand(cmdStr)
			end
			UtilityMenu.State.FreecamReleaseKeysState = true
		end
		local baseSpeed = cookie.GetNumber("basespeed", 1)
		local sensitivity = 0.0175
		local mouseX, mouseY = cmd:GetMouseX() * sensitivity, cmd:GetMouseY() * sensitivity
		local speed = input.IsKeyDown(KEY_LSHIFT) and baseSpeed * 10 or baseSpeed
		local ang = UtilityMenu.State.FreecamAngle
		ang.p, ang.y = math.Clamp(ang.p + mouseY, -89, 89), ang.y - mouseX
		cmd:SetViewAngles(UtilityMenu.State.FrozenViewAngle)
		local wishMove = Vector()
		if input.IsKeyDown(KEY_W) then wishMove = wishMove + ang:Forward() end
		if input.IsKeyDown(KEY_S) then wishMove = wishMove - ang:Forward() end
		if input.IsKeyDown(KEY_D) then wishMove = wishMove + ang:Right() end
		if input.IsKeyDown(KEY_A) then wishMove = wishMove - ang:Right() end
		if input.IsKeyDown(KEY_SPACE) then wishMove = wishMove + ang:Up() end
		if input.IsKeyDown(KEY_LCONTROL) then wishMove = wishMove - ang:Up() end
		if wishMove:LengthSqr() > 0 then
			wishMove:Normalize()
			UtilityMenu.State.FreecamPosition = UtilityMenu.State.FreecamPosition + wishMove * speed
		end
		hook.Add("PlayerBindPress", "UtilityMenu_FreecamBlockKeys", function(_, bind)
			for _, blocked in ipairs(UtilityMenu.Config.FreecamAllowedBinds) do
				if string.find(bind, blocked) then
					return false
				end
			end
			return true
		end)
	end)
	hook.Add("CreateMove", "UtilityMenu_AutoBhop", function(cmd)
		if not UtilityMenu.Settings.autobhop then return end
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() then return end
		if not cmd:KeyDown(IN_JUMP) then return end
		if ply:WaterLevel() <= 1 and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
			if not ply:IsOnGround() then
				cmd:RemoveKey(IN_JUMP)
			elseif not UtilityMenu.State.GroundJumpTimer or CurTime() - UtilityMenu.State.GroundJumpTimer > 0 then
				cmd:RemoveKey(IN_JUMP)
				UtilityMenu.State.GroundJumpTimer = CurTime()
			end
		end
	end)
	hook.Add("Think", "UtilityMenu_FlashlightSpam", function()
		if not UtilityMenu.Settings.flashlightspam or UtilityMenu.State.FreecamEnabled then return end
		if not input.IsKeyDown(KEY_F) or vgui.GetKeyboardFocus() or gui.IsGameUIVisible() then return end
		RunConsoleCommand("impulse", "100")
	end)
	hook.Add("Think", "UtilityMenu_PropTransparency", function()
		if not UtilityMenu.Settings.proptransparency then
			disableproptransparency()
			return
		end
		local ply = LocalPlayer()
		local transLevel = cookie.GetNumber("proptransparencylevel", 0) / 100
		if not IsValid(ply) or not ply:Alive() then 
			disableproptransparency()
			return 
		end
		local weapon = ply:GetActiveWeapon()
		if IsValid(weapon) and (weapon:GetClass() == "weapon_physgun" or weapon:GetClass() == "propkill_physgun") then
			local heldEnt = weapon:GetInternalVariable("m_hGrabbedEntity")
			if IsValid(heldEnt) and not ply:IsLineOfSightClear(heldEnt) then
				enableproptransparency(transLevel)
			else
				disableproptransparency()
			end
		else
			disableproptransparency()
		end
	end)
	hook.Add("ShutDown", "UtilityMenu_PropTransparencyCleanup", function()
		disableproptransparency()
	end)
	hook.Add("Think", "HideHandsAndPhysgun", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		if ply:Alive() and UtilityMenu.Settings.hidephysgun and not ply:ShouldDrawLocalPlayer() then
			local weapon = ply:GetActiveWeapon()
			if IsValid(weapon) and (weapon:GetClass() == "weapon_physgun" or weapon:GetClass() == "propkill_physgun") then
				local vm = ply:GetViewModel()
				if IsValid(vm) then
					vm:SetNoDraw(true)
				end
				weapon:SetNoDraw(false)
			else
				local vm = ply:GetViewModel()
				if IsValid(vm) then
					vm:SetNoDraw(false)
				end
			end
		else
			local weapons = ply:GetWeapons()
			for _, weapon in pairs(weapons) do
				if IsValid(weapon) then
					weapon:SetNoDraw(false)
				end
			end
			local vm = ply:GetViewModel()
			if IsValid(vm) then
				vm:SetNoDraw(false)
			end
		end
	end)
	hook.Add("Think", "UtilityMenu_attackspam", function()
		if not UtilityMenu.Settings.attackspam or UtilityMenu.State.FreecamEnabled then return end
		if not input.IsMouseDown(MOUSE_LEFT) or vgui.GetKeyboardFocus() or gui.IsGameUIVisible() then return end
		if not UtilityMenu.State.LastAttackTime then
			UtilityMenu.State.LastAttackTime = 0
		end
		local currentTime = CurTime()
		if currentTime - UtilityMenu.State.LastAttackTime > 0.0334 then
			RunConsoleCommand("+attack")
			timer.Simple(0, function()
				RunConsoleCommand("-attack")
			end)
			UtilityMenu.State.LastAttackTime = currentTime
		end
	end)
	hook.Add("Think", "UtilityMenu_PropKillSpawner", function()
		if not UtilityMenu.Settings.pkbinds or UtilityMenu.State.FreecamEnabled then
			hook.Remove("PlayerBindPress", "UtilityMenu_PropKillBlockKeys")
			return
		end
		if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() then return end
		for key, model in pairs(UtilityMenu.Config.PropKillProps) do
			local isDown = input.IsKeyDown(key)
			if isDown and not UtilityMenu.State.LastPropKeyState[key] then
				RunConsoleCommand("gm_spawn", model)
			end
			UtilityMenu.State.LastPropKeyState[key] = isDown
		end
		hook.Add("PlayerBindPress", "UtilityMenu_PropKillBlockKeys", function(_, bind)
			for _, blocked in ipairs(UtilityMenu.Config.PkAllowedBinds) do
				if string.find(bind, blocked) then return false end
			end
			return true
		end)
	end)
	hook.Add("PostDrawOpaqueRenderables", "UtilityMenu_DrawEntityBoxes", function()
		local drawFunctions = {
			propbox = {cache = UtilityMenu.State.EntityCache.Props, color = UtilityMenu.Config.EntityColors.Prop, UseAngle = true},
			npcbox = {cache = UtilityMenu.State.EntityCache.NPCs, color = UtilityMenu.Config.EntityColors.NPC},
			playerbox = {cache = UtilityMenu.State.EntityCache.Players, color = UtilityMenu.Config.EntityColors.Player}
		}
		for setting, data in pairs(drawFunctions) do
			if not UtilityMenu.Settings[setting] then continue end
			for _, ent in ipairs(data.cache) do
				if not IsValid(ent) then continue end
				render.DrawWireframeBox(ent:GetPos(), data.UseAngle and ent:GetAngles() or Angle(0, 0, 0), ent:OBBMins(), ent:OBBMaxs(), data.color, false)
			end
		end
	end)
	hook.Add("PostDrawTranslucentRenderables", "UtilityMenu_DrawLinesAndHighlights", function()
		local ply = LocalPlayer()
		local startPos = ply:EyePos() + ply:GetAimVector() * 50
		local lineFunctions, highlightFunctions = {
			npcline = {cache = UtilityMenu.State.EntityCache.NPCs, color = UtilityMenu.Config.EntityColors.NPC},
			playerline = {cache = UtilityMenu.State.EntityCache.Players, color = UtilityMenu.Config.EntityColors.Player}
		}, {
			prophighlight = {cache = UtilityMenu.State.EntityCache.Props, color = UtilityMenu.Config.EntityColors.Prop},
			npchighlight = {cache = UtilityMenu.State.EntityCache.NPCs, color = UtilityMenu.Config.EntityColors.NPC},
			playerhighlight = {cache = UtilityMenu.State.EntityCache.Players, color = UtilityMenu.Config.EntityColors.Player}
		}
		if ply:Alive() and not ply:ShouldDrawLocalPlayer() then
			for setting, data in pairs(lineFunctions) do
				if not UtilityMenu.Settings[setting] then continue end
				for _, ent in ipairs(data.cache) do
					if not IsValid(ent) then continue end
					local endPos = ent:GetPos() + Vector(0, 0, ent:OBBMaxs().z * 0.75)
					render.DrawLine(startPos, endPos, data.color, false)
				end
			end
		end
		for setting, data in pairs(highlightFunctions) do
			for _, ent in ipairs(data.cache) do
				if not IsValid(ent) then continue end
				if UtilityMenu.Settings[setting] then
					if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
						ent:SetRenderMode(RENDERMODE_TRANSALPHA)
						ent:SetColor(Color(255, 255, 255, 0))
					else
						ent:SetNoDraw(true)
					end
					cam.IgnoreZ(true)
					render.SuppressEngineLighting(true)
					render.MaterialOverride(Material("models/debug/debugwhite"))
					render.SetColorModulation(data.color.r / 255, data.color.g / 255, data.color.b / 255)
					render.SetBlend(0.8)
					ent:DrawModel()
					render.SetBlend(1)
					render.SetColorModulation(1, 1, 1)
					render.MaterialOverride()
					render.SuppressEngineLighting(false)
					cam.IgnoreZ(false)
				else
					if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
						ent:SetRenderMode(RENDERMODE_NORMAL)
						ent:SetColor(Color(255, 255, 255, 255))
					else
						ent:SetNoDraw(false)
					end
				end
			end
		end
	end)
	hook.Add("HUDPaint", "UtilityMenu_DrawHUD", function()
		local ply = LocalPlayer()
		local screenWidth, screenHeight = ScrW(), ScrH()
		if UtilityMenu.Settings.clientinfo and ply:Alive() then
			local fps = math.floor(1 / FrameTime()) + 1
			local infoDisplay1, infoDisplay2 = cookie.GetNumber("infodisplay1", 1), cookie.GetNumber("infodisplay2", 1)
			local offset = infoDisplay1 == 1 and 87 or 75
			if infoDisplay1 == 1 then
				draw.SimpleText(
					"Speed:" .. math.Round(ply:GetVelocity():Length()) .. "u/s", "BudgetLabel", screenWidth / 2,
					screenHeight / 2 + 75, UtilityMenu.Config.Colors.White, TEXT_ALIGN_CENTER
				)
			end
			if infoDisplay2 == 1 then
				local fpsColor = Color(255 - math.min(fps / 60, 1) * 255, math.min(fps / 60, 1) * 255, 0)
				draw.SimpleText("FPS:" .. fps, "BudgetLabel", screenWidth / 2, screenHeight / 2 + offset, fpsColor, TEXT_ALIGN_CENTER)
			end
		end
		if UtilityMenu.Settings.propinfo then
			for _, prop in ipairs(UtilityMenu.State.EntityCache.Props) do
				if not IsValid(prop) then continue end
				local pos = prop:LocalToWorld(Vector(0, 0, prop:OBBMaxs().z)):ToScreen()
				local maxHealth, health = prop:GetMaxHealth() or 100, math.max(0, prop:Health())
				local healthRatio = math.Clamp(health / maxHealth, 0, 1)
				local healthColor = Color(255 - healthRatio * 255, healthRatio * 255, 0)
				local propInfoDisplay1, propInfoDisplay2 = cookie.GetNumber("propinfodisplay1", 1), cookie.GetNumber("propinfodisplay2", 1)
				local offset = propInfoDisplay2 == 1 and 12 or 0
				if propInfoDisplay1 == 1 then
					draw.SimpleText(prop:GetClass(), "BudgetLabel", pos.x, pos.y - offset, UtilityMenu.Config.Colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				end
				if propInfoDisplay2 == 1 then
					draw.SimpleText("HP:" .. health, "BudgetLabel", pos.x, pos.y, healthColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				end
			end
		end
		if UtilityMenu.Settings.npcinfo then
			for _, npc in ipairs(UtilityMenu.State.EntityCache.NPCs) do
				if not IsValid(npc) then continue end
				local pos = npc:LocalToWorld(Vector(0, 0, npc:OBBMaxs().z)):ToScreen()
				local maxHealth, health = npc:GetMaxHealth() or 100, math.max(0, npc:Health())
				local healthRatio = math.Clamp(health / maxHealth, 0, 1)
				local healthColor = Color(255 - healthRatio * 255, healthRatio * 255, 0)
				local npcInfoDisplay1, npcInfoDisplay2 = cookie.GetNumber("npcinfodisplay1", 1), cookie.GetNumber("npcinfodisplay2", 1)
				local offset = npcInfoDisplay2 == 1 and 12 or 0
				if npcInfoDisplay1 == 1 then
					draw.SimpleText(npc:GetClass(), "BudgetLabel", pos.x, pos.y - offset, UtilityMenu.Config.Colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				end
				if npcInfoDisplay2 == 1 then
					draw.SimpleText("HP:" .. health, "BudgetLabel", pos.x, pos.y, healthColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				end
			end
		end
		if UtilityMenu.Settings.playerinfo then
			for _, player in ipairs(UtilityMenu.State.EntityCache.Players) do
				if not IsValid(player) then continue end
				local pos = player:LocalToWorld(Vector(0, 0, player:OBBMaxs().z)):ToScreen()
				local maxHealth, health = player:GetMaxHealth() or 100, math.max(0, player:Health())
				local healthRatio = health / maxHealth
				local healthColor = Color(255 - healthRatio * 255, healthRatio * 255, 0)
				local statusText = ""
				local statusColor
				local playerinfodisplay1, playerinfodisplay2, playerinfodisplay3, playerinfodisplay4, playerinfodisplay5 = 
					cookie.GetNumber("playerinfodisplay1", 1), cookie.GetNumber("playerinfodisplay2", 1), cookie.GetNumber("playerinfodisplay3", 1), 
					cookie.GetNumber("playerinfodisplay4", 1), cookie.GetNumber("playerinfodisplay5", 1)
				if player:VoiceVolume() > 0.02 then
					statusText = "*speaking*"
					statusColor = UtilityMenu.Config.Colors.Yellow
				elseif player:IsTyping() then
					statusText = "*typing*"
					statusColor = UtilityMenu.Config.Colors.Cyan
				elseif playerinfodisplay2 == 1 then
					statusColor = team.GetColor(player:Team())
				end
				local offset1 = playerinfodisplay5 == 1 and 12 or 0
				local offset2 = playerinfodisplay4 == 2 and 0 or 12
				local nameTagColor
				if playerinfodisplay1 == 2 and playerinfodisplay3 == 1 then
					nameTagColor = statusColor
				elseif playerinfodisplay2 == 1 then
					nameTagColor = team.GetColor(player:Team())
				else
					nameTagColor = UtilityMenu.Config.Colors.White
				end
				if playerinfodisplay3 == 1 and playerinfodisplay1 == 1 then
					draw.SimpleText(statusText, "BudgetLabel", pos.x, pos.y - offset2 - 12, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				end
				if playerinfodisplay4 == 1 then
					draw.SimpleText(player:Nick(), "BudgetLabel", pos.x, pos.y - offset1, nameTagColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				end
				if playerinfodisplay5 == 1 then
					local infoText = "HP:" .. health
					if player:Armor() > 0 then
						infoText = infoText .. "|AP:" .. player:Armor()
					end
					draw.SimpleText(infoText, "BudgetLabel", pos.x, pos.y, healthColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				end
			end
		end
		if UtilityMenu.Settings.minimap then
			local ply = LocalPlayer()
			if not ply:Alive() then return end
			local sizeIndex, scaleIndex, posIndex = cookie.GetNumber("mapsize", 1), cookie.GetNumber("mapscale", 1), cookie.GetNumber("mappos", 1)
			local markershow1, markershow2, markershow3 = cookie.GetNumber("markershow1", 1), cookie.GetNumber("markershow2", 1), cookie.GetNumber("markershow3", 1)
			local size, scale = UtilityMenu.Config.MapSizes[sizeIndex], UtilityMenu.Config.MapScales[scaleIndex]
			local showmarkerstatus, showheightoffset = cookie.GetNumber("showmarkerstatus", 1), cookie.GetNumber("showheightoffset", 1)
			local markerstatusstyle, showminimapwalls = cookie.GetNumber("markerstatusstyle", 1), cookie.GetNumber("showminimapwalls", 1)
			local wallquality, playermarkercolor1 = cookie.GetNumber("wallquality", 10), cookie.GetNumber("playermarkercolor1", 1)
			local radius = size / 2
			local filterEntities = {ply}
			for _, prop in ipairs(UtilityMenu.State.EntityCache.Props) do
				table.insert(filterEntities, prop)
			end
			for _, npc in ipairs(UtilityMenu.State.EntityCache.NPCs) do
				table.insert(filterEntities, npc)
			end
			for _, player in ipairs(UtilityMenu.State.EntityCache.Players) do
				table.insert(filterEntities, player)
			end
			local corners = {
				{x = 16 + radius, y = 16 + radius}, {x = screenWidth - 16 - radius, y = 16 + radius},
				{x = 16 + radius, y = screenHeight - 16 - radius}, {x = screenWidth - 16 - radius, y = screenHeight - 16 - radius}
			}
			local centerX, centerY, yaw = corners[posIndex].x, corners[posIndex].y, EyeAngles().y
			surface.SetDrawColor(0, 0, 0, 225)
			surface.DrawRect(centerX - radius, centerY - radius, radius * 2, radius * 2)
			local wallPoints = UtilityMenu.State.wallPoints
			if showminimapwalls == 1 then
				if CurTime() - UtilityMenu.State.wallPointsLastUpdate > 0.15 then
					table.Empty(wallPoints)
					for i = 0, wallquality - 1 do
						local ang = math.rad((i / wallquality) * 360)
						local dir = Vector(math.cos(ang), math.sin(ang), 0)
						local tr = util.TraceLine({start = EyePos(), endpos = EyePos() + dir * (20 * size), mask = MASK_SOLID, filter = filterEntities})
						table.insert(wallPoints, tr.HitPos)
					end
					UtilityMenu.State.wallPointsLastUpdate = CurTime()
				end
				surface.SetDrawColor(100, 100, 100)
				for i = 1, #wallPoints do
					local p1 = wallPoints[i]
					local p2 = wallPoints[i % #wallPoints + 1]
					local sx1, sy1 = UtilityMenu.MinimapProjection(p1, yaw, scale, radius)
					local sx2, sy2 = UtilityMenu.MinimapProjection(p2, yaw, scale, radius)
					surface.DrawLine(centerX + sx1, centerY + sy1, centerX + sx2, centerY + sy2)
				end
			end
			local function DrawHeightMarker(ent, color, label, textOffset)
				textOffset = textOffset or 0
				if not IsValid(ent) then return end
				local x, y = UtilityMenu.MinimapProjection(ent:GetPos(), yaw, scale, radius)
				local baseX, baseY = centerX + x, centerY + y
				local heightOffset = showheightoffset == 1 and (ent:GetPos().z - EyePos().z) / (1.5 * scale) or 0
				local markerY = baseY - heightOffset
				if math.abs(heightOffset) > 1 then
					surface.SetDrawColor(color)
					surface.DrawLine(baseX, baseY, baseX, markerY)
				end
				surface.SetDrawColor(color)
				surface.DrawRect(baseX - 1, markerY - 1, 4, 4)
				if label then
					draw.SimpleText(label, "BudgetLabel", baseX, markerY - textOffset, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				end
			end
			if markershow1 == 1 then
				for _, prop in ipairs(UtilityMenu.State.EntityCache.Props) do
					DrawHeightMarker(prop, UtilityMenu.Config.EntityColors.Prop)
				end
			end
			if markershow2 == 1 then
				for _, npc in ipairs(UtilityMenu.State.EntityCache.NPCs) do
					DrawHeightMarker(npc, UtilityMenu.Config.Colors.Red)
				end
			end
			if markershow3 == 1 then
				for _, player in ipairs(UtilityMenu.State.EntityCache.Players) do
					if not IsValid(player) then continue end
					local markerstatusText = ""
					local markerstatusColor
					local markerColor = UtilityMenu.Config.Colors.White
					if player:VoiceVolume() > 0.02 then
						markerstatusText = "*speaking*"
						markerstatusColor = UtilityMenu.Config.Colors.Yellow
					elseif player:IsTyping() then
						markerstatusText = "*typing*"
						markerstatusColor = UtilityMenu.Config.Colors.Cyan
					elseif playermarkercolor1 == 1 then
						markerstatusColor = team.GetColor(player:Team())
					else
						markerstatusColor = UtilityMenu.Config.Colors.White
					end
					if markerstatusstyle == 1 then
						if playermarkercolor1 == 1 then
							markerColor = team.GetColor(player:Team())
						end
						DrawHeightMarker(player, markerstatusColor, markerstatusText, 12)
					elseif markerstatusstyle == 2 then
						markerColor = markerstatusColor
					end
					DrawHeightMarker(player, markerColor, player:Nick())
				end
			end
			surface.SetDrawColor(UtilityMenu.Config.Colors.Green)
			surface.DrawLine(centerX, centerY - 4, centerX - 4, centerY + 4)
			surface.DrawLine(centerX, centerY - 4, centerX + 4, centerY + 4)
			surface.DrawLine(centerX - 4, centerY + 4, centerX + 4, centerY + 4)
		end
	end)
	hook.Add("CalcView", "UtilityMenu_FixedCamera", function(ply, pos, angles, fov)
		if not (UtilityMenu.Settings.noshake or UtilityMenu.Settings.norecoil) then return end
		if UtilityMenu.Settings.norecoil then
			local playerMeta = FindMetaTable("Player")
			if not playerMeta.OriginalSetEyeAngles then
				playerMeta.OriginalSetEyeAngles = playerMeta.SetEyeAngles
				playerMeta.SetEyeAngles = function(self, angle)
					local source = debug.getinfo(2).short_src or ""
					if string.find(string.lower(source), "/weapons/") then return end
					self:OriginalSetEyeAngles(angle)
				end
			end
		else
			local playerMeta = FindMetaTable("Player")
			if playerMeta.OriginalSetEyeAngles then
				playerMeta.SetEyeAngles = playerMeta.OriginalSetEyeAngles
				playerMeta.OriginalSetEyeAngles = nil
			end
		end
		if UtilityMenu.Settings.noshake then
			if not (UtilityMenu.State.FreecamEnabled or ply:ShouldDrawLocalPlayer() or ply:InVehicle() or not ply:Alive()) then
				angles.r = 0
				return {origin = pos, angles = angles, fov = cookie.GetNumber("noshakefov", 75)}
			end
		end
	end)
end

function UtilityMenu.CreateLabel(text, parent)
	local label = vgui.Create("DLabel", parent)
	label:SetText(text)
	label:SetFont("DermaDefaultBold")
	label:SetTextColor(UtilityMenu.Config.Colors.White)
	label:SizeToContents()
	label:Dock(TOP)
	label:DockMargin(10, 5, 0, 0)
	return label
end

function UtilityMenu.CreateCheckbox(text, key, parent)
	local checkbox = vgui.Create("DCheckBoxLabel", parent)
	checkbox:SetText(text)
	checkbox:SetFont("DermaDefault")
	checkbox:SetTextColor(UtilityMenu.Config.Colors.White)
	local savedValue = cookie.GetNumber(key, 0) == 1
	UtilityMenu.Settings[key] = UtilityMenu.Settings[key] ~= nil and UtilityMenu.Settings[key] or savedValue
	checkbox:SetValue(UtilityMenu.Settings[key])
	checkbox:Dock(TOP)
	checkbox:SizeToContents()
	checkbox:DockMargin(15, 5, 0, 0)
	checkbox.OnChange = function(self, value)
		UtilityMenu.Settings[key] = value
		cookie.Set(key, value and 1 or 0)
	end
	return checkbox
end

function UtilityMenu.CreateButtonGrid(items, onClick, parent)
	local grid = vgui.Create("DIconLayout", parent)
	grid:Dock(TOP)
	grid:SetSpaceX(5)
	grid:SetSpaceY(5)
	grid:CenterHorizontal()
	grid:DockMargin(15, 5, 0, 0)
	for _, item in ipairs(items) do
		local button = grid:Add("DButton")
		button:SetText(item:sub(1, 1):upper() .. item:sub(2):lower())
		button:SetSize(57.5, 30)
		button.DoClick = function()
			onClick(item)
		end
	end
	return grid
end

function UtilityMenu.CreateSlider(label, min, max, key, parent)
	local slider = vgui.Create("DNumSlider", parent)
	slider:SetText(label)
	slider.Label:SetFont("DermaDefault")
	slider.Label:SetTextColor(UtilityMenu.Config.Colors.White)
	slider:Dock(TOP)
	slider:DockMargin(15, 5, -18.3, 0)
	slider:SetTall(15)
	slider:SetMin(min)
	slider:SetMax(max)
	slider:SetDecimals(0)
	local savedValue = cookie.GetNumber(key, min)
	slider:SetValue(savedValue)
	function slider:OnValueChanged(value)
		local roundedValue = math.Round(value)
		slider:SetValue(roundedValue)
		cookie.Set(key, roundedValue)
	end
	return slider
end

function UtilityMenu.CreateMenu()
	local frame = vgui.Create("DFrame")
	local tab = vgui.Create("DPropertySheet", frame)
	frame:SetSize(300, 400)
	frame:Center()
	frame:SetTitle("Utility Menu V7")
	frame:SetDeleteOnClose(false)
	frame:SetVisible(false)
	tab:Dock(FILL)
	tab:SetFadeTime(0)
	local utilityScroll, displayScroll, settingsScroll = vgui.Create("DScrollPanel", tab), vgui.Create("DScrollPanel", tab), vgui.Create("DScrollPanel", tab)
	tab:AddSheet("Utility", utilityScroll, "icon16/wrench.png")
	tab:AddSheet("Display", displayScroll, "icon16/monitor.png")
	tab:AddSheet("Settings", settingsScroll, "icon16/cog.png")
	UtilityMenu.CreateLabel("Miscellaneous options:", utilityScroll)
	UtilityMenu.CreateCheckbox("Toggle auto bhop", "autobhop", utilityScroll)
	UtilityMenu.CreateCheckbox("Toggle Attack spam", "attackspam", utilityScroll)
	UtilityMenu.CreateCheckbox("Toggle flashlight spam", "flashlightspam", utilityScroll)
	UtilityMenu.CreateCheckbox("Toggle freecam", "freecam", utilityScroll)
	UtilityMenu.CreateCheckbox("Toggle no recoil", "norecoil", utilityScroll)
	UtilityMenu.CreateCheckbox("Toggle pk binds", "pkbinds", utilityScroll)
	UtilityMenu.CreateCheckbox("Toggle prop transparency", "proptransparency", utilityScroll)
	UtilityMenu.CreateLabel("Player gestures:", utilityScroll)
	UtilityMenu.CreateButtonGrid(UtilityMenu.Config.Gestures, function(gesture) RunConsoleCommand("act", gesture) end, utilityScroll)
	UtilityMenu.CreateLabel("Miscellaneous options:", displayScroll)
	UtilityMenu.CreateCheckbox("Draw client info", "clientinfo", displayScroll)
	UtilityMenu.CreateCheckbox("Draw minimap", "minimap", displayScroll)
	UtilityMenu.CreateCheckbox("Hide physgun", "hidephysgun", displayScroll)
	UtilityMenu.CreateCheckbox("Toggle no shake", "noshake", displayScroll)
	UtilityMenu.CreateLabel("Prop options:", displayScroll)
	UtilityMenu.CreateCheckbox("Draw prop boxes", "propbox", displayScroll)
	UtilityMenu.CreateCheckbox("Draw prop highlights", "prophighlight", displayScroll)
	UtilityMenu.CreateCheckbox("Draw prop info", "propinfo", displayScroll)
	UtilityMenu.CreateLabel("NPC options:", displayScroll)
	UtilityMenu.CreateCheckbox("Draw NPC boxes", "npcbox", displayScroll)
	UtilityMenu.CreateCheckbox("Draw NPC highlights", "npchighlight", displayScroll)
	UtilityMenu.CreateCheckbox("Draw NPC info", "npcinfo", displayScroll)
	UtilityMenu.CreateCheckbox("Draw NPC lines", "npcline", displayScroll)
	UtilityMenu.CreateLabel("Player Options:", displayScroll)
	UtilityMenu.CreateCheckbox("Draw player boxes", "playerbox", displayScroll)
	UtilityMenu.CreateCheckbox("Draw player highlights", "playerhighlight", displayScroll)
	UtilityMenu.CreateCheckbox("Draw player info", "playerinfo", displayScroll)
	UtilityMenu.CreateCheckbox("Draw player lines", "playerline", displayScroll)
	UtilityMenu.CreateLabel("Freecam:", settingsScroll)
	UtilityMenu.CreateSlider("Speed:", 1, 100, "basespeed", settingsScroll)
	UtilityMenu.CreateLabel("Prop transparency:", settingsScroll)
	UtilityMenu.CreateSlider("Transparency level:", 0, 100, "proptransparencylevel", settingsScroll)
	UtilityMenu.CreateLabel("Client info:", settingsScroll)
	UtilityMenu.CreateSlider("Show speed:", 1, 2, "infodisplay1", settingsScroll)
	UtilityMenu.CreateSlider("Show fps:", 1, 2, "infodisplay2", settingsScroll)
	UtilityMenu.CreateLabel("Map:", settingsScroll)
	UtilityMenu.CreateSlider("Pos:", 1, 4, "mappos", settingsScroll)
	UtilityMenu.CreateSlider("Scale:", 1, 5, "mapscale", settingsScroll)
	UtilityMenu.CreateSlider("Size:", 1, 5, "mapsize", settingsScroll)
	UtilityMenu.CreateSlider("show height offset:", 1, 2, "showheightoffset", settingsScroll)
	UtilityMenu.CreateSlider("show walls:", 1, 2, "showminimapwalls", settingsScroll)
	UtilityMenu.CreateSlider("Wall quality:", 10, 360, "wallquality", settingsScroll)
	UtilityMenu.CreateSlider("Show prop markers:", 1, 2, "markershow1", settingsScroll)
	UtilityMenu.CreateSlider("Show npc markers:", 1, 2, "markershow2", settingsScroll)
	UtilityMenu.CreateSlider("show player markers:", 1, 2, "markershow3", settingsScroll)
	UtilityMenu.CreateSlider("Player team color:", 1, 2, "playermarkercolor1", settingsScroll)
	UtilityMenu.CreateSlider("Status style:", 1, 2, "markerstatusstyle", settingsScroll)
	UtilityMenu.CreateSlider("Show player status:", 1, 2, "showmarkerstatus", settingsScroll)
	UtilityMenu.CreateLabel("No shake:", settingsScroll)
	UtilityMenu.CreateSlider("FOV", 75, 120, "noshakefov", settingsScroll)
	UtilityMenu.CreateLabel("Prop info:", settingsScroll)
	UtilityMenu.CreateSlider("Show name:", 1, 2, "propinfodisplay1", settingsScroll)
	UtilityMenu.CreateSlider("Show health:", 1, 2, "propinfodisplay2", settingsScroll)
	UtilityMenu.CreateLabel("NPC info:", settingsScroll)
	UtilityMenu.CreateSlider("Show name:", 1, 2, "npcinfodisplay1", settingsScroll)
	UtilityMenu.CreateSlider("Show health:", 1, 2, "npcinfodisplay2", settingsScroll)
	UtilityMenu.CreateLabel("Player info:", settingsScroll)
	UtilityMenu.CreateSlider("Status style:", 1, 2, "playerinfodisplay1", settingsScroll)
	UtilityMenu.CreateSlider("Team color:", 1, 2, "playerinfodisplay2", settingsScroll)
	UtilityMenu.CreateSlider("Show status:", 1, 2, "playerinfodisplay3", settingsScroll)
	UtilityMenu.CreateSlider("Show nametag:", 1, 2, "playerinfodisplay4", settingsScroll)
	UtilityMenu.CreateSlider("Show health:", 1, 2, "playerinfodisplay5", settingsScroll)
	return frame
end

concommand.Add("open_utility_menu", function()
	UtilityMenu.Menu:SetVisible(true)
	UtilityMenu.Menu:MakePopup()
end)

concommand.Add("toggle_freecam", function()
	local ply = LocalPlayer()
	if not UtilityMenu.Settings.freecam then return end
	if UtilityMenu.State.FreecamEnabled then
		UtilityMenu.State.FreecamEnabled = false
		hook.Remove("CalcView", "UtilityMenu_FreecamView")
		hook.Remove("PlayerBindPress", "UtilityMenu_FreecamBlockKeys")
	else
		UtilityMenu.State.FreecamEnabled = true
		UtilityMenu.State.FreecamPosition = EyePos()
		UtilityMenu.State.FreecamAngle = Angle(EyeAngles().p, EyeAngles().y, 0)
		UtilityMenu.State.FrozenViewAngle = ply:EyeAngles()
		hook.Add("CalcView", "UtilityMenu_FreecamView", function(_, _, _, fov)
			return {origin = UtilityMenu.State.FreecamPosition, angles = UtilityMenu.State.FreecamAngle, fov = fov, drawviewer = true}
		end)
	end
end)

function UtilityMenu.Init()
	UtilityMenu.State.ScriptRan = true
	UtilityMenu.SetupHooks()
	UtilityMenu.Menu = UtilityMenu.CreateMenu()
	print("\nRun 'open_utility_menu' to open the menu!\n")
end

if not UtilityMenu.State.ScriptRan then
	UtilityMenu.Init()
end