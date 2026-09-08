require('Utilities');
require('Client');

function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
	
	if (not WL.IsVersionOrHigher("6.05")) then
		UI.Alert("You must update your app to the latest version to use the Team Switcher mod");
		return;
	end

	Game = game; --make it globally accessible
	Close = close;

	setMaxSize(500, 500);

	local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

	ShowTeams(vert, game);
	ShowPendingRequests(vert, game);
	ShowActions(vert, game);
end

--Lists who's on a team with who right now.  Note that teams can change during the game, so we must ask the game rather than reading GamePlayer.Team, which is only the team they started on.
function ShowTeams(vert, game)

	local teams = {};
	local teamIDs = {};
	local noTeam = {};

	for _,gp in pairs(game.Game.PlayingPlayers) do
		local teamID = TeamOfPlayer(game, gp.ID, game.LatestStanding);
		if (teamID == NoTeam) then
			table.insert(noTeam, gp.ID);
		else
			if (teams[teamID] == nil) then
				teams[teamID] = {};
				table.insert(teamIDs, teamID);
			end
			table.insert(teams[teamID], gp.ID);
		end
	end

	if (count(teamIDs) == 0) then
		UI.CreateLabel(vert).SetText('Nobody is currently on a team.');
	else
		UI.CreateLabel(vert).SetText('Teams:');
		for _,teamID in ipairs(sortedCopy(teamIDs)) do
			UI.CreateLabel(vert).SetText(' - ' .. PlayerNames(game, teams[teamID]));
		end
	end

	-- if (count(noTeam) > 0) then
	-- 	UI.CreateLabel(vert).SetText('Not on a team: ' .. PlayerNames(game, noTeam));
	-- end
end

--Lists the proposals we're a part of that nobody has declined yet.
function ShowPendingRequests(vert, game)
	if (game.Us == nil) then return; end;

	local requests = Mod.PlayerGameData.PendingTeamRequests or {};
	if (true) then return; end;
end

function ShowActions(vert, game)
	if (game.Us == nil) then
		UI.CreateLabel(vert).SetText("You can't change teams since you're not in this game.");
		return;
	end
	if (game.Us.State ~= WL.GamePlayerState.Playing) then
		UI.CreateLabel(vert).SetText("You can't change teams since you're no longer playing.");
		return;
	end

	UI.CreateButton(vert).SetText('Join a team').SetOnClick(function() game.CreateDialog(CreateProposeDialog); end);
end

function CreateProposeDialog(rootParent, setMaxSize, setScrollable, game, close)
	setMaxSize(450, 400);

	ProposeRoot = rootParent;
	ProposeClose = close;
	SelectedPlayerIDs = {};

	BuildProposeUI();
end

--Rebuilt from scratch every time the player adds or removes someone from the team they're putting together.
function BuildProposeUI()
	if (ProposeVert ~= nil and not UI.IsDestroyed(ProposeVert)) then
		UI.Destroy(ProposeVert);
	end

	ProposeVert = UI.CreateVerticalLayoutGroup(ProposeRoot).SetFlexibleWidth(1);

	UI.CreateLabel(ProposeVert).SetText('Choose exactly one player whose team you would like to join. This decision cannot be undone and will take effect when the turn advances.');

	UI.CreateLabel(ProposeVert).SetText('The player whose team you will join is');

	for _,playerID in ipairs(SelectedPlayerIDs) do
		local row = UI.CreateHorizontalLayoutGroup(ProposeVert);
		UI.CreateLabel(row).SetText(' - ' .. PlayerName(Game, playerID));
		UI.CreateButton(row).SetText('Remove').SetOnClick(function()
			SelectedPlayerIDs = filter(SelectedPlayerIDs, function(selected) return selected ~= playerID; end);
			BuildProposeUI();
		end);
	end

	if (count(SelectedPlayerIDs) == 0) then
		--A team of just yourself would be the same as leaving your team, so don't let them propose one.
		UI.CreateLabel(ProposeVert).SetText('Add at least one other player before proposing.');
	end

	UI.CreateButton(ProposeVert).SetText('Add player').SetOnClick(AddPlayerClicked);
	UI.CreateButton(ProposeVert).SetText('Join team').SetInteractable(count(SelectedPlayerIDs) > 0).SetOnClick(SubmitPropose);
end

function AddPlayerClicked()
	local players = filter(Game.Game.PlayingPlayers, IsPotentialTeammate);

	if (count(players) == 0) then
		UI.Alert("There's nobody else you can add to the team.");
		return;
	end

	table.sort(players, function(a, b)
		return a.DisplayName(nil, false) < b.DisplayName(nil, false);
	end);

	UI.PromptFromList('Select a player to add to the team', map(players, PlayerButton));
end

--Determines if this is a player we can ask to join the team.
function IsPotentialTeammate(player)
	if (player.ID == Game.Us.ID) then return false; end; --we're always on the team we propose

	if (contains(SelectedPlayerIDs, player.ID)) then return false; end; --already on it

	if (player.State ~= WL.GamePlayerState.Playing) then return false; end; --skip players who aren't alive anymore, or that declined the game.

	--An AI would never respond to a proposal, so don't allow naming one in multi-player.  In single-player they accept automatically so the mod can be tried out.
	if (player.IsAIOrHumanTurnedIntoAI and not Game.Settings.SinglePlayer) then return false; end;

	return true;
end

function PlayerButton(player)
	local name = player.DisplayName(nil, false);
	local ret = {};

	if (WL.IsVersionOrHigher("5.41.0")) then
		ret["player"] = player.ID;
	else
		ret["text"] = name;
	end

	ret["selected"] = function()
		table.insert(SelectedPlayerIDs, player.ID);
		BuildProposeUI();
	end
	return ret;
end

function SubmitPropose()
	if (count(SelectedPlayerIDs) == 0) then
		UI.Alert("A team needs at least one other player on it.");
		return;
	end

	local playerIDs = { Game.Us.ID };
	for _,playerID in ipairs(SelectedPlayerIDs) do
		table.insert(playerIDs, playerID);
	end

	local payload = {};
	payload.Message = 'ProposeTeamChange';
	payload.PlayerIDs = playerIDs;

	--Close the propose dialog and the menu behind it, since what they're showing is about to be out of date.
	local closeBoth = function()
		ProposeClose();
		Close();
	end

	SendTeamMessage(Game, 'Proposing team...', payload, closeBoth, function(returnValue)
		if (returnValue.Complete) then
			return 'You will join the team when the turn advances.';
		else
			return 'Your proposal was sent.  The team takes effect once everyone named in it accepts.';
		end
	end);
end
