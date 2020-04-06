function CreateCoinchePlayer(color)
    return {player = Player[color], color = color, hand = {}, team = nil}
end

function CreateTeam(coninchePlayer1, coinchePlayer2)
    local team = {
        players = {coninchePlayer1, coinchePlayer2},
        gameScore = 0,
        roundScore = 0
    }

    coninchePlayer1.team = team
    coinchePlayer2.team = team
    return team
end

function CreateRoundInfo(team, atoutColor, contract, isCoinche)
    return {
        team = team,
        otherTeam = (team == TeamNS) and TeamNS or TeamEW,
        atoutColor = atoutColor,
        contract = contract,
        isCoinche = isCoinche
    }
end

function EndRound(roundInfo)
    if roundInfo.team.roundScore > 81 and roundInfo.team.roundScore >
        roundInfo.contract then
        roundInfo.team.gameScore = roundInfo.team.gameScore + roundInfo.contract
    else
        roundInfo.otherTeam.gameScore = roundInfo.otherTeam.gameScore + 160
    end

    if TeamNS.gameScore >= 1000 then
        EndGame(TeamNS)
    elseif TeamEW.gameScore >= 1000 then
        EndGame(TeamEW)
    end
end

function EndGame(winnerTeam) end

local masterDeck = getObjectFromGUID("deckGuid")
masterDeck.hide()
local gameDeck = masterDeck.clone();

PlayerN = CreateCoinchePlayer("Green")
PlayerE = CreateCoinchePlayer("Red")
PlayerS = CreateCoinchePlayer("Blue")
PlayerW = CreateCoinchePlayer("Yellow")

TeamNS = CreateTeam(PlayerN, PlayerS)
TeamEW = CreateTeam(PlayerE, PlayerW)
Teams = {TeamNS, TeamEW}

PlayersInOrder = {PlayerN, PlayerE, PlayerS, PlayerW}

function GetNextPlayer(currentPlayerIndex)
    return currentPlayerIndex
end

local firstPlayerOfRound = 1

local function initGame()
    gameDeck.shuffle()
    for i, team in pairs(Teams) do
        team.gameScore = 0
        team.roundScore = 0
    end
end

local function initRound() for i, team in pairs(Teams) do team.roundScore = 0 end end
