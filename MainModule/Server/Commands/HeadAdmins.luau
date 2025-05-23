return function(Vargs, env)
	local server = Vargs.Server;
	local service = Vargs.Service;
	local Settings = server.Settings
	local Functions, Commands, Admin, Anti, Core, HTTP, Logs, Remote, Process, Variables, Deps =
		server.Functions, server.Commands, server.Admin, server.Anti, server.Core, server.HTTP, server.Logs, server.Remote, server.Process, server.Variables, server.Deps

	if env then setfenv(1, env) end

	return {
		TimeBan = {
			Prefix = Settings.Prefix;
			Commands = {"timeban", "tempban", "tban", "temporaryban"};
			Args = {"player", "number<s/m/h/d>", "reason"};
			Description = `Bans the target player(s) from the game for the supplied amount of time; data-persistent; undo using {Settings.Prefix}untimeban`;
			Filter = true;
			AdminLevel = "HeadAdmins";
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: {})
				assert(args[1], "Missing target user (argument #1)")

				local duration, valid = assert(args[2], "Missing duration (argument #2)"):gsub("^(%d+)([smhd])$", function(val, unit)
					return if unit == "s" then val
						elseif unit == "m" then val * 60
						elseif unit == "h" then val * 60 * 60
						else val * 60 * 60 * 24
				end)
				assert(valid > 0, "Invalid duration value (argument #2)")

				local reason = args[3] or "No reason provided"

				for _, v in service.GetPlayers(plr, args[1], {
					IsKicking = true;
					NoFakePlayer = false;
					})
				do
					if Admin.CheckAuthority(plr, v, "time-ban", false) then
						Admin.AddTimeBan(v, duration, reason, plr)
						Functions.LogAdminAction(plr, "Time Ban", v.Name, `Duration: {args[2]}, Reason: {reason}`)
						Functions.Hint(`Time-banned {service.FormatPlayer(v, true)} for {args[2]}`, {plr})
					end
				end
			end
		};

		DirectTimeBan = {
			Prefix = Settings.Prefix;
			Commands = {"directtimeban", "directtimedban", "directtempban", "directtban", "directtemporaryban"};
			Args = {"username(s)", "number<s/m/h/d>", "reason"};
			Description = `Bans the target user(s) from the game for the supplied amount of time; data-persistent; undo using {Settings.Prefix}untimeban`;
			Filter = true;
			AdminLevel = "HeadAdmins";
			Hidden = true;
			Function = function(plr: Player, args: {string}, data: {})
				assert(args[1], "Missing target user (argument #1)")

				local duration, valid = assert(args[2], "Missing duration (argument #2)"):gsub("^(%d+)([smhd])$", function(val, unit)
					return if unit == "s" then val
						elseif unit == "m" then val * 60
						elseif unit == "h" then val * 60 * 60
						else val * 60 * 60 * 24
				end)
				assert(valid > 0, "Invalid duration value (argument #2)")

				local reason = args[3] or "No reason provided"

				for i in string.gmatch(args[1], "[^,]+") do
					local UserId = Functions.GetUserIdFromNameAsync(i)
					if UserId then
						if UserId == plr.UserId then
							Functions.Hint("You cannot ban yourself", {plr})
							continue
						end

						local getNameSuccess, actualName = pcall(service.Players.GetNameFromUserIdAsync, service.Players, UserId)

						Admin.AddTimeBan({UserId = UserId, Name = if getNameSuccess then actualName else i}, duration, reason, plr)
						Functions.LogAdminAction(plr, "Direct Time Ban", actualName or i, `Duration: {args[2]}, Reason: {reason}`)
						Functions.Hint(
							`Time-banned {if getNameSuccess then `@{actualName}` else `'{i}'`} for {args[2]}`,
							{plr}
						)
					else
						Functions.Hint(`No user named '{i}' exists (Please try again if you think this is an internal error)`, {plr})
					end
				end
			end
		};

		UnTimeBan = {
			Prefix = Settings.Prefix;
			Commands = {"untimeban", "untimedban", "untban", "untempban", "untemporaryban"};
			Args = {"user"};
			Description = "Removes the target user(s) from the timebans list";
			AdminLevel = "HeadAdmins";
			Dangerous = true;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target user (argument #1)"), {
					UseFakePlayer = true;
					AllowUnknownUsers = true;
					})
				do
					Functions.LogAdminAction(plr, "Un-Time Ban", v.Name, "Removed from timeban list")
					Functions.Hint(
						if Admin.RemoveTimeBan(v)
							then `{service.FormatPlayer(v, true)} has been un-time-banned`
							else `{service.FormatPlayer(v, true)} is not currently time-banned`,
						{plr}
					)
				end
			end
		};

		PermanentBan = {
			Prefix = Settings.Prefix;
			Commands = {"globalban", "permban", "permanentban", "pban", "gameban", "gban"};
			Args = {"player/user", "reason"};
			Description = "Bans the target player(s) from the game permanently; if they join a different server they will be banned there too";
			AdminLevel = "HeadAdmins";
			Dangerous = true;
			Filter = true;
			Function = function(plr: Player, args: {string}, data: {})
				local reason = args[2] or "No reason provided"

				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target user (argument #1)"), {
					IsKicking = true;
					NoFakePlayer = false;
					})
				do
					if Admin.CheckAuthority(plr, v, "game-ban", false) then
						Admin.AddBan(v, reason, true, plr, "Global")
						Functions.LogAdminAction(plr, "Permanent Ban", v.Name, reason)
						Functions.Hint(`Game-banned {service.FormatPlayer(v, true)}`, {plr})
					else
						Functions.Hint(`Unable to game-ban {service.FormatPlayer(v, true)} (insufficient permission level)`, {plr})
					end
				end
			end
		};

		UnGameBan = {
			Prefix = Settings.Prefix;
			Commands = {"unglobalban", "unpermban", "unpermanentban", "unpban", "ungameban", "ungban"};
			Args = {"user"};
			Description = "Unbans the target user(s) from the game; saves";
			AdminLevel = "HeadAdmins";
			Dangerous = true;
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target user (argument #1)"), {
					UseFakePlayer = true;
					AllowUnknownUsers = true;
					})
				do
					Functions.LogAdminAction(plr, "Unbanned", v.Name, "N/A")
					Functions.Hint(
						if Admin.RemoveBan(v, true)
							then `{service.FormatPlayer(v, true)} has been unbanned from the game`
							else `{service.FormatPlayer(v, true)} is not currently banned`,
						{plr}
					)
				end
			end
		};

		TempAdmin = {
			Prefix = Settings.Prefix;
			Commands = {"tempadmin", "tadmin"};
			Args = {"player"};
			Description = "Makes the target player(s) a temporary admin; does not save";
			AdminLevel = "HeadAdmins";
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: any)
				local senderLevel = data.PlayerData.Level

				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target player (argument #1)")) do
					if senderLevel > Admin.GetLevel(v) then
						Admin.AddAdmin(v, "Admins", true)
						Functions.LogAdminAction(plr, "Temporary Admin", v.Name, "Temporary admin granted.")
						Functions.Notification("Notification", "You are a temp administrator. Click to view commands.", {v}, 10, "MatIcon://Admin panel settings", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v, true)} is now a temporary admin`, {plr})
					else
						Functions.Hint(`{service.FormatPlayer(v, true)} is already the same admin level as you or higher`, {plr})
					end
				end
			end
		};

		Admin = {
			Prefix = Settings.Prefix;
			Commands = {"permadmin", "padmin", "admin"};
			Args = {"player/user"};
			Description = "Makes the target player(s) an admin; saves";
			AdminLevel = "HeadAdmins";
			Dangerous = true;
			Function = function(plr: Player, args: {string}, data: any)
				local senderLevel = data.PlayerData.Level

				for _, v in service.GetPlayers(plr, assert(args[1], "Missing target user (argument #1)"), {
					UseFakePlayer = true;
					})
				do
					if senderLevel > Admin.GetLevel(v) then
						Admin.AddAdmin(v, "Admins")
						Functions.LogAdminAction(plr, "Permanent Admin", v.Name, "Granted permanent admin rights.")
						Functions.Notification("Notification", "You are an administrator. Click to view commands.", {v}, 10, "MatIcon://Admin panel settings", Core.Bytecode(`client.Remote.Send('ProcessCommand','{Settings.Prefix}cmds')`))
						Functions.Hint(`{service.FormatPlayer(v, true)} is now a permanent admin`, {plr})
					else
						Functions.Hint(`{service.FormatPlayer(v, true)} is already the same admin level as you or higher`, {plr})
					end
				end
			end
		};

		GlobalMessage = {
			Prefix = Settings.Prefix;
			Commands = {"globalmessage", "gm", "globalannounce"};
			Args = {"message"};
			Description = "Sends a global message to all servers";
			AdminLevel = "HeadAdmins";
			Filter = true;
			IsCrossServer = true;
			CrossServerDenied = true;
			Function = function(plr: Player, args: {string})
				if not Core.CrossServer("Message", plr.Name, assert(args[1], "Missing message")) then
					error("CrossServer handler not ready; please try again later")
				end
			end;
		};

		GlobalTimeMessage = {
			Prefix = Settings.Prefix;
			Commands = {"gtm", "globaltimedmessage", "globaltimemessage", "globaltimem"};
			Args = {"time", "message"};
			Description = "Sends a global message to all servers and makes it stay on the screen for the amount of time (in seconds) you supply";
			AdminLevel = "HeadAdmins";
			Filter = true;
			IsCrossServer = true;
			CrossServerDenied = true;
			Function = function(plr: Player, args: {string})
				if not Core.CrossServer("Message", plr.Name, assert(args[2], "Missing message"), assert(args[1], "Missing time amount")) then
					error("CrossServer handler not ready; please try again later")
				end
			end;
		};

		FullClear = {
			Prefix = Settings.Prefix;
			Commands = {"fullclear", "clearinstances", "fullclr"};
			Args = {};
			Description = "Removes any instance created server-side by Adonis; May break things";
			AdminLevel = "HeadAdmins";
			Function = function(plr: Player, args: {string})
				local objects = service.GetAdonisObjects()
				for i, v in objects do
					v:Destroy()
				end
				table.clear(objects)

				--for i, v in Functions.GetPlayers() do
				--	Remote.Send(v, "Function", "ClearAllInstances")
				--end
			end
		};

		BackupMap = {
			Prefix = Settings.Prefix;
			Commands = {"backupmap", "mapbackup", "bmap"};
			Args = {};
			Description = "Changes the backup for the restore map command to the map's current state";
			AdminLevel = "HeadAdmins";
			Function = function(plr: Player, args: {string})
				local plr_name = if plr then service.FormatPlayer(plr) else "%SYSTEM%"

				if plr then
					Functions.Hint("Updating Map Backup...", {plr})
				end

				if Variables.BackingupMap then
					error("Backup Map is in progress. Please try again later!")
					return
				end
				if Variables.RestoringMap then
					error("Cannot backup map while map is being restored!")
					return
				end

				Variables.BackingupMap = true
				Variables.OriginalGravity = workspace.Gravity

				local Lighting = service.Lighting
				local atmosphere = Lighting:FindFirstChildWhichIsA("Atmosphere")

				Variables.OriginalLightingSettings = {
					Ambient = Lighting.Ambient,
					OutdoorAmbient = Lighting.OutdoorAmbient,
					Brightness = Lighting.Brightness,
					TimeOfDay = Lighting.TimeOfDay,
					FogColor = Lighting.FogColor,
					FogEnd = Lighting.FogEnd,
					FogStart = Lighting.FogStart,
					GlobalShadows = Lighting.GlobalShadows,
					Outlines = Lighting.Outlines,
					ShadowColor = Lighting.ShadowColor,
					ColorShift_Bottom = Lighting.ColorShift_Bottom,
					ColorShift_Top = Lighting.ColorShift_Top,
					GeographicLatitude = Lighting.GeographicLatitude,
					Name = Lighting.Name,
					Sky = Lighting:FindFirstChildOfClass("Sky") and Lighting:FindFirstChildOfClass("Sky"):Clone(),
				}
				Variables.OriginalAtmosphereSettings = {
					Name = atmosphere and atmosphere.Name,
					Density = atmosphere and atmosphere.Density,
					Offset = atmosphere and atmosphere.Offset,
					Color = atmosphere and atmosphere.Color,
					Decay = atmosphere and atmosphere.Decay,
					Glare = atmosphere and atmosphere.Glare,
					Haze = atmosphere and atmosphere.Haze,
				}

				local tempmodel = service.New("Model", {
					Name = "BACKUP_MAP_MODEL"
				})
				for _, v in workspace:GetChildren() do
					if v.ClassName ~= "Terrain" and not service.Players:GetPlayerFromCharacter(v) then
						local archive = v.Archivable
						v.Archivable = true
						v:Clone().Parent = tempmodel
						v.Archivable = archive
					end
				end
				Variables.MapBackup = tempmodel:Clone()
				tempmodel:Destroy()

				local Terrain = workspace.Terrain or workspace:FindFirstChildOfClass("Terrain")
				if Terrain then
					Variables.TerrainMapBackup = Terrain:CopyRegion(Terrain.MaxExtents)
				end

				if plr then
					Functions.Hint('Backup Complete', {plr})
				end

				Variables.BackingupMap = false

				Logs.AddLog(Logs.Script, {
					Text = "Backup Complete";
					Desc = `{plr_name} has successfully backed up the map.`;
				})
			end
		};

		Explore = {
			Prefix = Settings.Prefix;
			Commands = {"explore", "explorer"};
			Args = {};
			Description = `Lets you explore the game, kinda like a file browser (alternative to {Settings.Prefix}dex)`;
			AdminLevel = "HeadAdmins";
			Function = function(plr: Player, args: {string})
				Remote.MakeGui(plr, "Explorer")
			end
		};

		PromptInvite = {
			Prefix = Settings.Prefix;
			Commands = {"promptinvite", "inviteprompt", "forceinvite"};
			Args = {"player"};
			Description = "Opens the friend invitation popup for the target player(s), same as them running !invite";
			AdminLevel = "HeadAdmins";
			Function = function(plr: Player, args: {string})
				for _, v in service.GetPlayers(plr, args[1]) do
					service.SocialService:PromptGameInvite(v)
				end
			end
		};

		ForceRejoin = {
			Prefix = Settings.Prefix;
			Commands = {"forcerejoin"};
			Args = {"player"};
			Description = `Forces target player(s) to rejoin the server; same as them running {Settings.PlayerPrefix}rejoin`;
			NoStudio = true;
			AdminLevel = "HeadAdmins";
			Function = function(plr: Player, args: {string})
				local players = service.GetPlayers(plr, args[1])
				local teleportOptions = service.New("TeleportOptions", {
					ServerInstanceId = game.JobId
				})
				service.TeleportService:TeleportAsync(game.PlaceId, players, teleportOptions)
			end
		};

		FullShutdown = {
			Prefix = Settings.Prefix;
			Commands = {"fullshutdown", "globalshutdown"};
			Args = {"reason"};
			Description = "Initiates a shutdown for every running game server";
			AdminLevel = "HeadAdmins";
			Filter = true;
			IsCrossServer = true;
			Function = function(plr: Player, args: {string})
				assert(args[1], "Reason (argument #1) must be supplied for this command!")

				if
					Remote.GetGui(plr, "YesNoPrompt", {
						Question = `Shutdown all running servers for the reason '{args[1]}'?`;
						Title = "Global Shutdown";
					}) == "Yes"
				then
					assert(
						Core.CrossServer(
							"NewRunCommand",
							{
								Name = plr.Name,
								UserId = plr.UserId,
								AdminLevel = Admin.GetLevel(plr)
							},
							`{Settings.Prefix}shutdown {args[1]}\n\n\n[GLOBAL SHUTDOWN]`
						),
						"An error has occured"
					)
				end
			end;
		};

		Incognito = {
			Prefix = Settings.Prefix;
			Commands = {"incognito"};
			Args = {"player", "hideFromNonAdmins(default true)", "hideCharacter(default true)"};
			Description = "Removes the target player from other clients' perspectives (persists until rejoin). Allows to set whether to hide only from nonadmins or from everyone.";
			AdminLevel = "HeadAdmins";
			Function = function(plr: Player, args: {string})
				local hidefromEveryone = false
				local hideCharacter = true
				if args[2] then
					if string.lower(args[2])=="false" or string.lower(args[2])=="no" then
						hidefromEveryone = true
					end
				end
				if args[3] then
					if string.lower(args[3])=="false" or string.lower(args[3])=="no" then
						hideCharacter = false
					end
				end

				for _, v: Player in service.GetPlayers(plr, args[1]) do
					if Variables.IncognitoPlayers[v] then
						Functions.Hint(`{service.FormatPlayer(v)} is already incognito.`, {plr})
						continue
					end
					Variables.IncognitoPlayers[v] = {
						time=os.time(),
						hide_from_everyone=hidefromEveryone,
						hide_character=hideCharacter
					}
					if hideCharacter then
						v.CharacterAdded:Connect(function(character: Model)
							for _, otherPlr: Player in service.Players:GetPlayers(v, if hidefromEveryone then "others" else "nonadmins") do
								if otherPlr == v then continue end
								Remote.LoadCode(otherPlr, [[
									local plrName = service.Players:GetNameFromUserIdAsync(]] .. v.UserId .. [[)
									local character = service.Workspace:FindFirstChild(plrName)
									if character:FindFirstChildWhichIsA("Humanoid") == nil then
										for _, v in service.Workspace:GetChildren() do
											if v.Name == plrName and v:IsA("Model") and v:FindFirstChildWhichIsA("Humanoid") ~= nil then
												character = v
												break
											end
										end
									end
									character:Destroy()
								]])
							end
						end)
					end

					local n = 0
					for _, otherPlr: Player in service.Players:GetPlayers(v, if hidefromEveryone then "others" else "nonadmins") do
						if otherPlr == v then continue end
						if hideCharacter then
							Remote.LoadCode(otherPlr, [[
							local plr = service.Players:GetPlayerByUserId(]] .. v.UserId .. [[)
								if plr then
									if not table.find(service.IncognitoPlayers, plr) then
										table.insert(service.IncognitoPlayers, plr)
									end
									if plr.Character then
										plr.Character:Destroy()
									end
									plr:Destroy()
								end
							]])
						else
							Remote.LoadCode(otherPlr, [[
								local plr = service.Players:GetPlayerByUserId(]] .. v.UserId .. [[)
								if plr then
									if not table.find(service.IncognitoPlayers, plr) then
										table.insert(service.IncognitoPlayers, plr)
									end
									plr:Destroy()
								end
							]])
						n += 1
						end
					end

					if n == 0 then
						Functions.Hint(string.format("Placed %s on the incognito list.", service.FormatPlayer(v)), {plr})
					else
						Functions.Hint(string.format("Hidden %s from %d other player%s.", service.FormatPlayer(v), n, n == 1 and "" or "s"), {plr})
					end

					Functions.Notification("Incognito Mode", "You will cease to appear on the player list, on other players' screens.", {v}, 15, "MatIcon://Privacy tip")
				end
			end
		};

		AwardBadge = {
			Prefix = Settings.Prefix;
			Commands = {"awardbadge", "badge", "givebadge"};
			Args = {"player", "badgeId"};
			Description = "Awards the badge of the specified ID to the target player(s)";
			AdminLevel = "HeadAdmins";
			Function = function(plr: Player, args: {string})
				if not Variables.BadgeInfoCache then
					Variables.BadgeInfoCache = {}
				end

				local badgeId = assert(tonumber(args[2]), "Invalid badge ID specified!")
				local badgeInfo = Variables.BadgeInfoCache[tostring(badgeId)]
				if not badgeInfo then
					local success
					badgeInfo = nil
					local tries = 0
					repeat
						tries += 1
						success, badgeInfo = pcall(service.BadgeService.GetBadgeInfoAsync, service.BadgeService, badgeId)
					until success or tries > 2
					Variables.BadgeInfoCache[tostring(badgeId)] = assert(success and badgeInfo, "Unable to retrieve badge information; please try again")
				end

				for _, v: Player in service.GetPlayers(plr, args[1]) do
					local success, hasBadge = nil, nil
					local tries = 0
					repeat
						tries += 1
						success, hasBadge = pcall(service.BadgeService.UserHasBadgeAsync, service.BadgeService, v.UserId, badgeId)
					until success or tries > 2
					if not success then
						Functions.Hint(string.format("ERROR: Unable to get badge ownership status for %s; skipped", service.FormatPlayer(v)))
						continue
					end
					if hasBadge then
						Functions.Hint(string.format("%s already has the badge '%s'", service.FormatPlayer(v), badgeInfo.Name), {plr})
					elseif service.BadgeService:AwardBadge(v.UserId, badgeId) then
						Functions.Hint(string.format("Successfully awarded badge '%s' for %s", badgeInfo.Name, service.FormatPlayer(v)), {plr})
					else
						Functions.Hint(string.format("ERROR: Failed to award badge '%s' for %s due to an unexpected internal error", badgeInfo.Name, service.FormatPlayer(v)), {plr})
					end
				end
			end
		};

	}
end
