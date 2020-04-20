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

function GetCardColor(card)
    -- c'est moins simple que ça dans la vraie vie
    return card.color
end

function GetCardFigure(card)
    -- c'est moins simple que ça dans la vraie vie
    return card.figure
end

function CompareCards(firstCard, secondCard, turnInfo)
    local firstCardColor = GetCardColor(firstCard)
    local secondCardColor = GetCardColor(secondCard)
    if firstCardColor == secondCardColor then
        local function sameColorCompare(orderMap)
            if orderMap[GetCardFigure(firstCard)] <
                orderMap[GetCardFigure(secondCard)] then
                return 1
            else
                return -1
            end
        end
        if firstCardColor == turnInfo.atoutColor then
            return sameColorCompare(AtoutOrderMap)
        else
            return sameColorCompare(NonAtoutOrderMap)
        end
    else
        if firstCardColor == turnInfo.atoutColor then
            return 1
        elseif secondCardColor == turnInfo.atoutColor then
            return -1
        elseif firstCardColor == turnInfo.expectedColor then
            return 1
        elseif secondCardColor == turnInfo.expectedColor then
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
    local cardColor = GetCardColor(card)
    local cardFigure = GetCardFigure(card)
    if cardColor == atoutColor and cardFigure == "Jack" then
        return 20
    elseif cardColor == atoutColor and cardFigure == "9" then
        return 14
    elseif cardFigure == "1" then
        return 11
    elseif cardFigure == "10" then
        return 10
    elseif cardFigure == "King" then
        return 4
    elseif cardFigure == "Queen" then
        return 3
    elseif cardFigure == "Jack" then
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
    return {ttsPlayer = Player[color], color = color, team = nil}
end

function CreateTeam(player1, player2)
    local team = {players = {player1, player2}}

    player1.team = team
    player2.team = team
    return team
end

MasterDeck = getObjectFromGUID(MasterDeckGuid)
MasterDeck.hide()
MasterDeck.setLock(true)

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
        gameDeck.setLock(false)
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

    --broadcast( message,  Color)
    --https://api.tabletopsimulator.com/player/#broadcast
end

function AnnonceLoop(firstPlayerIndex)
    local currentStake = nil
    local passCount = 0
    local runningTeam = nil
    local isCoinche = false;
    local currentPlayerIndex = firstPlayerIndex

    while passCount < 3 or (passCount == 3 and runningTeam == nil) do
        local currentPlayer = PlayersInOrder[currentPlayerIndex]
        local playerStake = GetPlayerStake(currentPlayer, currentStake)
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
        expectedColor = GetCardColor(card),
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
    local hand = player.ttsPlayer.getHandObjects()
    for _, card in pairs(hand) do
        if IsCardAllowed(card, player, turnInfo) then
            card.highlightOn("Yellow")
        else
            card.setLock(true)
        end
    end

    local playedCard = nil
    --[[ get the card the player just played
        use this event: function onObjectDrop(obj, colorName)
        https://api.tabletopsimulator.com/event/#onobjectdrop
        --]]
    for _, card in pairs(hand) do
        card.highlightOff()
        card.setLock(false)
    end

    return playedCard
end

function IsCardAllowed(card, player, turnInfo)
    local cardColor = GetCardColor(card)
    if turnInfo == nil then
        return true
    elseif cardColor ~= turnInfo.expectedColor and
        HasColorInHand(player, turnInfo.expectedColor) then
        return false
    elseif cardColor ~= turnInfo.atoutColor then
        if cardColor == turnInfo.expectedColor then
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
        local highestCardColor = GetCardColor(highestCard)
        if highestCardColor ~= turnInfo.atoutColor then
            return true
        elseif CompareCards(card, highestCard, turnInfo) > 0 then
            return true
        else
            local hand = player.ttsPlayer.getHandObjects()
            for _, handCard in pairs(hand) do
                if GetCardColor(handCard) == highestCardColor and
                    CompareCards(handCard, highestCard, turnInfo) > 0 then
                    return false
                end
            end
            return true
        end
    end
end

function HasColorInHand(player, color)
    local hand = player.ttsPlayer.getHandObjects()
    for _, card in pairs(hand) do
        if GetCardColor(card) == color then return true end
    end

    return false
end
