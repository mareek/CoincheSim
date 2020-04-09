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

function GetNextPlayerIndex(currentPlayerIndex)
    return (currentPlayerIndex % 4) + 1
end

function GameLoop()
    gameDeck.shuffle()
    TeamNS.gameScore = 0
    TeamEW.gameScore = 0

    local firstPlayerIndex = 1
    while true do
        local roundInfo = AnnonceLoop(firstPlayerIndex)
        RoundLoop(roundInfo)

        if TeamNS.gameScore >= 1000 or TeamEW.gameScore >= 1000 then
            break
        else
            firstPlayerIndex = GetNextPlayerIndex(firstPlayerIndex)
        end
    end
    local winner = (TeamNS.gameScore >= 1000) and TeamNS or TeamEW;
end

function AnnonceLoop(firstPlayerIndex) end

function CreateRoundInfo(team, atoutColor, contract, isCoinche)
    return {
        team = team,
        otherTeam = (team == TeamNS) and TeamNS or TeamEW,
        atoutColor = atoutColor,
        contract = contract,
        isCoinche = isCoinche
    }
end

function RoundLoop(roundInfo)
    local runningTeam = roundInfo.team
    local otherTeam = roundInfo.otherTeam
    otherTeam.roundScore = 0
    runningTeam.roundScore = 0

    if runningTeam.roundScore > 81 and runningTeam.roundScore >
        roundInfo.contract then
        runningTeam.gameScore = runningTeam.gameScore + roundInfo.contract
    else
        otherTeam.gameScore = otherTeam.gameScore + 160
    end

end
