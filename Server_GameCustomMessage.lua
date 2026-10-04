require('Utilities');
require('ServerUtilities');

function Server_GameCustomMessage(game, playerID, payload, setReturnTable)
	if (payload.Message == 'ProposeTeamChange') then
		ProposeTeamChange(game, playerID, payload, setReturnTable);
	elseif (payload.Message == 'AckAlerts') then
		AckAlerts(game, playerID, payload, setReturnTable);
	else
		error("Payload message not understood (" .. tostring(payload.Message) .. ")");
	end
end

--Asks everyone named to form a team together.  Nothing happens until they've all accepted.
function ProposeTeamChange(game, playerID, payload, setReturnTable)
	local playerIDs = payload.PlayerIDs or {};

	if (not contains(playerIDs, playerID)) then
		error("You can't propose a team that you're not a part of");
		return
	end
	--A player must list exactly one player whose team they will join
	if (count(playerIDs) ~= 2) then
		AlertPlayer(playerID, "You must choose exactly one player whose team you will join");
		return
	end
	--A player may not join another team if they currently have teammates
	if (#TeammatesOf(game, playerID, LatestStanding(game)) ~= 0) then
		AlertPlayer(playerID, "You may not leave your teammates for another team");
		return
	end

	local seen = {};
	for _,pid in pairs(playerIDs) do
		if (seen[pid]) then
			error("The same player was named twice in the proposed team");
		end
		seen[pid] = true;

		local gp = game.Game.Players[pid];
		if (gp == nil or gp.State ~= WL.GamePlayerState.Playing) then
			error("You can't form a team with a player who isn't playing");
		end
	end

	--Everyone must be free of queued-up team changes, otherwise this proposal could never be executed.
	local conflict = FindConflict(game, playerIDs);
	if (conflict ~= nil) then
		setReturnTable({ Error = conflict });
		return;
	end

	local otherPlayerID = 0;
	for _,pid in pairs(playerIDs) do
		if (pid ~= PlayerID) then
			otherPlayerID = pid;
		end
	end

	local allPlayerIDs = {};
	for pid,_ in pairs(game.Game.Players) do
		table.insert(allPlayerIDs, pid);
	end

	local teammates = TeammatesOf(game, otherPlayerID, LatestStanding(game));
	teammates[#teammates + 1] = otherPlayerID;
	teammates[#teammates + 1] = playerID;
	local request = {};
	request.ID = NewGuid();
	request.ProposerID = playerID;
	request.PlayerIDs = teammates;
	request.Accepted = {};
	request.Accepted[playerID] = true; --proposing it counts as accepting it

	--In single-player, AIs accept immediately so that the mod can be tried out.  In multi-player we never let players name an AI in the first place, since an AI would never respond.
	if (game.Settings.SinglePlayer) then
		for _,pid in pairs(playerIDs) do
			if (game.Game.Players[pid].IsAIOrHumanTurnedIntoAI) then
				request.Accepted[pid] = true;
			end
		end
	end

	SaveRequest(request);
	WriteRequestToPlayerData(request);

	AlertPlayers(allPlayerIDs, 'All players: ' .. PlayerName(game, playerID) .. ' will join ' .. PlayerName(game, otherPlayerID) ..'\'s team when the turn advances.', null);

	TeamChangeAccepted(game, request, playerID, otherPlayerID);
	setReturnTable({ ID = request.ID, Complete = true });
end

--Everyone in the request has agreed, so queue the team change up for the turn advance and tell everyone about it.
function TeamChangeAccepted(game, request, lastPlayerToActID, otherPlayerID)
	--Always move everyone onto a brand new team, even if some of them are already together on one.  Anyone who changes teams leaves their cards behind, and it'd be unfair and surprising if that depended on which team they happened to end up on.
	local standing = LatestStanding(game);
	local team = TeamOfPlayer(game, otherPlayerID, standing);
	RecordTeamChange(request.PlayerIDs, team);

	DeleteRequest(request);

	--AlertPlayers(request.PlayerIDs, 'The team of ' .. PlayerNames(game, request.PlayerIDs) .. ' has been accepted by everyone.  It takes effect when the turn advances.', lastPlayerToActID);
end

--The client shows alerts and then tells us it's done with them so we don't show them twice.
function AckAlerts(game, playerID, payload, setReturnTable)
	local playerData = Mod.PlayerGameData;

	if (playerData[playerID] ~= nil and playerData[playerID].Alerts ~= nil) then
		--Only remove the alerts the client told us it saw, since we may have added more since it read them.
		playerData[playerID].Alerts = filter(playerData[playerID].Alerts, function(alert) return not contains(payload.AlertIDs or {}, alert.ID); end);
		Mod.PlayerGameData = playerData;
	end

	setReturnTable({ Acknowledged = true });
end
