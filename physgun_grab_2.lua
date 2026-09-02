local function GetHeldPhysgunProp()
	local client = LocalPlayer()
	if not IsValid(client) then return nil end

	local wep = client:GetActiveWeapon()
	if not IsValid(wep) then return nil end
	
	local wepClass = wep:GetClass()
	if wepClass ~= "weapon_physgun" and wepClass ~= "propkill_physgun" then 
		return nil 
	end

	local heldEntity = wep:GetInternalVariable("m_hGrabbedEntity")
	if IsValid(heldEntity) then 
		return heldEntity 
	end
	
	heldEntity = wep:GetInternalVariable("m_hPhysicsEntity")
	if IsValid(heldEntity) then 
		return heldEntity 
	end

	return nil
end

local function GetClosestPlayer(originPos)
	local closestPlayer = nil
	local shortestDistance = math.huge

	for _, ply in ipairs(player.GetAll()) do
		if ply == LocalPlayer() or not ply:Alive() then continue end
		
		local dist = originPos:Distance(ply:GetPos())
		if dist < shortestDistance then
			shortestDistance = dist
			closestPlayer = ply
		end
	end

	return closestPlayer, shortestDistance
end

local function GetDistanceColor(distance, maxDist, minDist)
	maxDist = maxDist or 800
	minDist = minDist or 50
	local normalized = math.Clamp((distance - minDist) / (maxDist - minDist), 0, 1)
	return Color(255 * normalized, 255 * (1 - normalized), 0, 255)
end

local function DrawCircle(x, y, radius, segments)
	segments = segments or 16
	local vertices = {}
	for i = 0, segments do
		local theta = (i / segments) * math.pi * 2
		local vx = x + radius * math.cos(theta)
		local vy = y + radius * math.sin(theta)
		table.insert(vertices, {x = vx, y = vy})
	end
	surface.DrawPoly(vertices)
end

local function GetPropPositionStatus(propPos, playerPos, selfPos)
	local toPlayer = playerPos - selfPos
	local toPlayerDist = toPlayer:Length()
	
	local toProp = propPos - selfPos
	local toPropDist = toProp:Length()
	
	local projection = toProp:GetNormalized():Dot(toPlayer:GetNormalized())
	local projectedDist = toPropDist * projection
	
	local percentAlong = math.Clamp(projectedDist / toPlayerDist, 0, 1) * 100
	
	local status = ""
	local statusColor = Color(255, 255, 255)
	
	if projectedDist < 0 then
		status = "BEHIND YOU"
		statusColor = Color(255, 100, 100)
	elseif projectedDist > toPlayerDist then
		local overshoot = ((projectedDist - toPlayerDist) / toPlayerDist) * 100
		status = string.format("OVERSHOT +%.0f%%", overshoot)
		statusColor = Color(255, 100, 100)
	elseif percentAlong < 30 then
		status = string.format("BETWEEN (%.0f%%)", percentAlong)
		statusColor = Color(255, 200, 100)
	elseif percentAlong < 70 then
		status = string.format("GOOD (%.0f%%)", percentAlong)
		statusColor = Color(100, 255, 100)
	elseif percentAlong < 100 then
		status = string.format("NEAR (%.0f%%)", percentAlong)
		statusColor = Color(100, 200, 255)
	else
		status = "AT PLAYER"
		statusColor = Color(0, 255, 0)
	end
	
	local perpDist = math.sqrt(toPropDist^2 - projectedDist^2)
	local perpPercent = (perpDist / toPlayerDist) * 100
	
	return status, statusColor, percentAlong, perpDist, perpPercent, projectedDist, toPlayerDist
end

hook.Add("HUDPaint", "DrawPropScreenLine2D", function()
	local heldProp = GetHeldPhysgunProp()
	if not IsValid(heldProp) then return end
	
	local propPos = heldProp:WorldSpaceCenter()
	local screenPos = propPos:ToScreen()
	
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	
	local closestPlayer, playerDist = GetClosestPlayer(propPos)
	if not IsValid(closestPlayer) then return end
	
	local selfPos = ply:GetPos()
	local playerPos = closestPlayer:GetPos() + Vector(0, 0, 40)
	local playerScreenPos = playerPos:ToScreen()
	
	local status, statusColor, percentAlong, perpDist, perpPercent, projectedDist, toPlayerDist = 
		GetPropPositionStatus(propPos, playerPos, selfPos)
	
	local col = GetDistanceColor(playerDist)
	local selfScreenPos = selfPos:ToScreen()
	local selfX, selfY = selfScreenPos.x, selfScreenPos.y
	
	surface.SetDrawColor(col)
	surface.DrawLine(screenPos.x, screenPos.y, playerScreenPos.x, playerScreenPos.y)
	
	surface.SetDrawColor(Color(col.r, col.g, col.b, 60))
	for i = 1, 3 do
		surface.DrawLine(screenPos.x + i, screenPos.y + i, playerScreenPos.x + i, playerScreenPos.y + i)
		surface.DrawLine(screenPos.x - i, screenPos.y - i, playerScreenPos.x - i, playerScreenPos.y - i)
	end
	
	draw.SimpleTextOutlined(
		status,
		"DermaLarge",
		screenPos.x,
		screenPos.y - 40,
		statusColor,
		TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER,
		2,
		Color(0, 0, 0, 200)
	)
	
	local barX = screenPos.x - 50
	local barY = screenPos.y - 25
	local barWidth = 100
	local barHeight = 6
	
	surface.SetDrawColor(Color(50, 50, 50, 150))
	surface.DrawRect(barX, barY, barWidth, barHeight)
	
	local fillPercent = math.Clamp(percentAlong / 100, 0, 1)
	local fillColor
	
	if projectedDist > toPlayerDist then
		fillColor = Color(255, 100, 100)
	elseif fillPercent < 0.3 then
		fillColor = Color(255, 200, 100)
	elseif fillPercent < 0.7 then
		fillColor = Color(100, 255, 100)
	else
		fillColor = Color(100, 200, 255)
	end
	
	surface.SetDrawColor(fillColor)
	surface.DrawRect(barX, barY, barWidth * fillPercent, barHeight)
	
	draw.SimpleText("YOU", "Default", barX - 5, barY + 3, Color(255, 255, 255, 150), TEXT_ALIGN_RIGHT)
	draw.SimpleText("PLAYER", "Default", barX + barWidth + 5, barY + 3, Color(255, 255, 255, 150), TEXT_ALIGN_LEFT)
	
	local arrowX = barX + (barWidth * fillPercent)
	surface.SetDrawColor(statusColor)
	surface.DrawRect(arrowX - 1, barY - 4, 2, 14)
	
	local propPulse = 6 + math.sin(CurTime() * 2.5) * 2
	surface.SetDrawColor(col)
	DrawCircle(screenPos.x, screenPos.y, propPulse)
	
	local playerPulse = 8 + math.sin(CurTime() * 2) * 3
	surface.SetDrawColor(Color(col.r, col.g, col.b, 200))
	DrawCircle(playerScreenPos.x, playerScreenPos.y, playerPulse)
end)