MasterDeckGuid = ""

AtoutOrderMap = BuildIndexOfMap({
    "Jack", "9", "1", "10", "King", "Queen", "8", "7"
})
NonAtoutOrderMap = BuildIndexOfMap({
    "1", "10", "King", "Queen", "Jack", "9", "8", "7"
})

function BuildIndexOfMap(array)
    local indexOfMap = {}
    for k, v in pairs(array) do indexOfMap[v] = k end
    return indexOfMap
end

function CompareCards(firstCard, secondCard, turnInfo)
    if firstCard.color == secondCard.color then
        local function sameColorCompare(orderMap)
            if orderMap[firstCard.figure] < orderMap[secondCard.figure] then
                return 1
            else
                return -1
            end
        end
        if firstCard.color == turnInfo.atoutColor then
            return sameColorCompare(AtoutOrderMap)
        else
            return sameColorCompare(NonAtoutOrderMap)
        end
    else
        if firstCard.color == turnInfo.atoutColor then
            return 1
        elseif secondCard.color == turnInfo.atoutColor then
            return -1
        elseif firstCard.color == turnInfo.expectedColor then
            return 1
        elseif secondCard.color == turnInfo.expectedColor then
            return -1
        else
            return 0
        end
    end
end

function GetTurnHighest(turnInfo)
    local highest = nil
    for player, card in pairs(turnInfo.cardsByPlayer) do
        if highest == nil or CompareCards(card, highest.card, turnInfo) > 0 then
            highest = {card = card, player = player}
        end
    end
    return highest
end

function GetTurnHighestPlayer(turnInfo)
    return PlayersByColor[GetTurnHighest(turnInfo).player]
end

function GetTurnHighestCard(turnInfo) return GetTurnHighest(turnInfo).card end

function GetCardValue(card, atoutColor)
    if card.color == atoutColor and card.figure == "Jack" then
        return 20
    elseif card.color == atoutColor and card.figure == "9" then
        return 14
    elseif card.figure == "1" then
        return 11
    elseif card.figure == "10" then
        return 10
    elseif card.figure == "King" then
        return 4
    elseif card.figure == "Queen" then
        return 3
    elseif card.figure == "Jack" then
        return 2
    else
        return 0
    end
end

function ComputeScore(cards, atoutColor)
    local score = 0
    for _, card in pairs(cards) do
        score = score + GetCardValue(card, atoutColor)
    end
    return score
end

function CreateCoinchePlayer(color)
    return {player = Player[color], color = color, hand = {}, team = nil}
end

function CreateTeam(player1, player2)
    local team = {players = {player1, player2}}

    player1.team = team
    player2.team = team
    return team
end

MasterDeck = getObjectFromGUID(MasterDeckGuid)
MasterDeck.hide()

PlayerN = CreateCoinchePlayer("Green")
PlayerE = CreateCoinchePlayer("Red")
PlayerS = CreateCoinchePlayer("Blue")
PlayerW = CreateCoinchePlayer("Yellow")

PlayersInOrder = {PlayerN, PlayerE, PlayerS, PlayerW}

PlayersByColor = {}
for index, player in pairs(PlayersInOrder) do
    player.index = index
    PlayersByColor[player.color] = player
end

TeamNS = CreateTeam(PlayerN, PlayerS)
TeamEW = CreateTeam(PlayerE, PlayerW)

function GetNextPlayerIndex(currentPlayerIndex)
    return (currentPlayerIndex % 4) + 1
end

function GameLoop()
    TeamNS.gameScore = 0
    TeamEW.gameScore = 0

    local firstPlayerIndex = 1
    while TeamNS.gameScore < 1000 and TeamEW.gameScore < 1000 do
        local gameDeck = MasterDeck.clone();
        gameDeck.shuffle()
        gameDeck.deal(3)
        gameDeck.deal(2)
        gameDeck.deal(3)
        local roundInfo = AnnonceLoop(firstPlayerIndex)
        if roundInfo ~= nil then RoundLoop(roundInfo, firstPlayerIndex) end
        firstPlayerIndex = GetNextPlayerIndex(firstPlayerIndex)
        gameDeck.destruct()
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
    local currentPlayerIndex = firstPlayerIndex
    for i = 1, 8 do
        local turnInfo = PlayTurn(currentPlayerIndex)
        local turnWinner = GetTurnHighestPlayer(turnInfo)
        turnWinner.team.roundScore = turnWinner.team.roundScore +
                                         ComputeScore(turnInfo.cardsByPlayer)
        CleanBoard(turnInfo)
        currentPlayerIndex = turnWinner.index
    end

    if runningTeam.roundScore > 81 and runningTeam.roundScore >
        roundInfo.contract then
        local score = roundInfo.contract * (roundInfo.isCoinche and 2 or 1)
        runningTeam.gameScore = runningTeam.gameScore + score
        RoundWon(roundInfo)
    else
        local score = roundInfo.isCoinche and (roundInfo.contract * 2) or 160
        otherTeam.gameScore = otherTeam.gameScore + score
        RoundLost(roundInfo)
    end
end

function CleanBoard(turnInfo)
    for _, card in pairs(turnInfo.cardsByPlayer) do card.destruct() end
end

function PlayTurn(firstPlayerIndex, atoutColor)
    local currentPlayer = PlayersInOrder[firstPlayerIndex]
    local card = PlayCard(currentPlayer)
    local turnInfo = {
        expectedColor = card.color,
        atoutColor = atoutColor,
        cardsByPlayer = {}
    }
    turnInfo.cardsByPlayer[currentPlayer.color] = card

    local currentPlayerIndex = GetNextPlayerIndex(firstPlayerIndex)
    while currentPlayerIndex ~= firstPlayerIndex do
        currentPlayer = PlayersInOrder[currentPlayerIndex]
        card = PlayCard(currentPlayer, turnInfo)
        turnInfo.cardsByPlayer[currentPlayer.color] = card
    end

    return turnInfo
end

function PlayCard(player, turnInfo)
    local allowedCards = {}
    for _, card in pairs(player.hand) do
        if IsCardAllowed(card, player, turnInfo) then
            card.highlightOn("Yellow")
            allowedCards[#allowedCards + 1] = card
        end
    end

    local playedCard = nil -- get the card the player just played

    for _, card in allowedCards do card.highlightOff() end

    return playedCard
end

function IsCardAllowed(card, player, turnInfo)
    if turnInfo == nil then
        return true
    elseif card.color ~= turnInfo.expectedColor and
        HasColorInHand(player, turnInfo.expectedColor) then
        return false
    elseif card.color ~= turnInfo.atoutColor then
        if card.color == turnInfo.expectedColor then
            return true
        elseif GetTurnHighestPlayer(turnInfo).team == player.team then
            return true
        elseif not HasColorInHand(player, turnInfo.atoutColor) then
            return true
        else
            return false
        end
    else
        -- Atout
        local highestCard = GetTurnHighestCard(turnInfo)
        if highestCard.color ~= turnInfo.atoutColor then
            return true
        elseif CompareCards(card, highestCard, turnInfo) > 0 then
            return true
        else
            for _, handCard in pairs(player.hand) do
                if handCard.color == highestCard.color and
                    CompareCards(handCard, highestCard, turnInfo) > 0 then
                    return false
                end
            end
            return true
        end
    end
end

function HasColorInHand(player, color)
    for _, card in pairs(player.hand) do
        if card.color == color then return true end
    end

    return false
end
