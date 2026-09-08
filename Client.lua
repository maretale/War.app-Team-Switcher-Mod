require('Utilities');

--Actions the player can take.  These are shared between the menu and the propose dialog.

--Every message this mod sends either hands back an Error to show the player, or succeeded.
function SendTeamMessage(game, waitingText, payload, closeOpt, successMessageFn)
	if (closeOpt ~= nil) then
		closeOpt(); --close the dialog now, since whatever it's showing is about to be out of date
	end

	game.SendGameCustomMessage(waitingText, payload, function(returnValue)
		if (returnValue == nil) then
			return;
		elseif (returnValue.Error ~= nil) then
			UI.Alert(returnValue.Error);
		else
			UI.Alert(successMessageFn(returnValue));
		end
	end);
end

--Describes how far along a proposal is, such as "Waiting on Alice and Bob"
function RequestStatus(game, request)
	return 'You will join the team when the turn advances.'
end

function HaveWeAccepted(game, request)
	return true;
end
