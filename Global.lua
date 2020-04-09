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
    while TeamNS.gameScore < 1000 and TeamEW.gameScore < 1000 do
        local roundInfo = AnnonceLoop(firstPlayerIndex)
        if roundInfo ~= nil then
            RoundLoop(roundInfo, firstPlayerIndex)
        end
        firstPlayerIndex = GetNextPlayerIndex(firstPlayerIndex)
    end

    local winner = (TeamNS.gameScore >= 1000) and TeamNS or TeamEW;
end

function AnnonceLoop(firstPlayerIndex)
    local currentStake = nil
    local passCount = 0
    local runningTeam = nil
    local isCoinche = false;
    local currentPlayerIndex = firstPlayerIndex

    while passCount < 3 or (passCount == 3 and runningTeam == nil) do
        local currentPlayer = PlayersInOrder[currentPlayerIndex]
        local playerStake = GetPlayerStake(currentPlayer)
        if playerStake == "coinche" then
            isCoinche = true
            break
        elseif playerStake == nil then
            passCount = passCount + 1
        else
            passCount = 0
            currentStake = playerStake
            runningTeam = currentPlayer.team
        end

        currentPlayerIndex = GetNextPlayerIndex(currentPlayerIndex)
    end

    if currentStake == nil then
        return nil
    else
        return {
            team = runningTeam,
            otherTeam = (runningTeam == TeamNS) and TeamNS or TeamEW,
            atoutColor = currentStake.atoutColor,
            contract = currentStake.contract,
            isCoinche = isCoinche
        }
    end
end

function RoundLoop(roundInfo, firstPlayerIndex)
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
