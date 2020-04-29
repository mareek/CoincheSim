function onLoad(save_state)

    do -- Game logic
        MasterDeckGuid = "91a70f"

        function BuildIndexOfMap(array)
            local indexOfMap = {}
            for k, v in pairs(array) do indexOfMap[v] = k end
            return indexOfMap
        end

        AtoutOrderMap = BuildIndexOfMap({
            "Jack", "9", "Ace", "10", "King", "Queen", "8", "7"
        })
        NonAtoutOrderMap = BuildIndexOfMap({
            "Ace", "10", "King", "Queen", "Jack", "9", "8", "7"
        })
        ColorList = {"Green", "Red", "Blue", "Yellow"}

        function GetCardColor(card)
            local name = card.nickName
            local ofPosition = name:find(" of ")
            return name:sub(ofPosition + 4)
        end

        function GetCardFigure(card)
            local name = card.nickName
            local ofPosition = name:find(" of ")
            return name:sub(1, ofPosition - 1)
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

        function GetTurnHighestCard(turnInfo)
            return GetTurnHighest(turnInfo).card
        end

        function GetCardValue(card, atoutColor)
            local cardColor = GetCardColor(card)
            local cardFigure = GetCardFigure(card)
            if cardColor == atoutColor and cardFigure == "Jack" then
                return 20
            elseif cardColor == atoutColor and cardFigure == "9" then
                return 14
            elseif cardFigure == "Ace" then
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
        MasterDeck.attachInvisibleHider("hide", true)
        MasterDeck.setLock(true)

        PlayerN = CreateCoinchePlayer(ColorList[1])
        PlayerE = CreateCoinchePlayer(ColorList[2])
        PlayerS = CreateCoinchePlayer(ColorList[3])
        PlayerW = CreateCoinchePlayer(ColorList[4])

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

        function GetOpponentTeam(team)
            return (team == TeamNS) and TeamEW or TeamNS
        end

        function DealToAllPlayers(deck, number, firstPlayerIndex)
            playerIndex = firstPlayerIndex
            for i = 0, 3 do
                player = PlayersInOrder[playerIndex]
                deck.deal(number, player.color)
                playerIndex = GetNextPlayerIndex(playerIndex)
                WaitFrames(10)
            end
        end

        function GameLoop()
            log("GameLoop start")
            UPD_LeaveStartup()
            TeamNS.gameScore = 0
            TeamEW.gameScore = 0

            local firstPlayerIndex = 1
            while TeamNS.gameScore < 1000 and TeamEW.gameScore < 1000 do
                local gameDeck = MasterDeck.clone()
                WaitFrames(10)
                gameDeck.setLock(false)
                gameDeck.shuffle()
                DealToAllPlayers(gameDeck, 3, firstPlayerIndex)
                DealToAllPlayers(gameDeck, 2, firstPlayerIndex)
                DealToAllPlayers(gameDeck, 3, firstPlayerIndex)
                local roundInfo = AnnonceLoop(firstPlayerIndex)
                --log(roundInfo)
                if roundInfo ~= nil then
                    RoundLoop(roundInfo, firstPlayerIndex)
                end
                firstPlayerIndex = GetNextPlayerIndex(firstPlayerIndex)
                gameDeck.destruct()
            end

            local winner = (TeamNS.gameScore >= 1000) and TeamNS or TeamEW;

            UPD_EnterStartup()
            return 1
            -- broadcast( message,  Color)
            -- https://api.tabletopsimulator.com/player/#broadcast
        end

        function AnnonceLoop(firstPlayerIndex)
            log("AnnonceLoop start")
            UPD_EnterAnnonce()
            local currentStake = nil
            local passCount = 0
            local runningTeam = nil
            local isCoinche = false;
            local currentPlayerIndex = firstPlayerIndex

            while passCount < 3 or (passCount == 3 and runningTeam == nil) do
                local currentPlayer = PlayersInOrder[currentPlayerIndex]
                local playerStake = WaitPlayerStake(currentPlayer, currentStake, runningTeam)
                if playerStake == "coinche" then
                    isCoinche = true
                    break
                elseif playerStake == nil then
                    passCount = passCount + 1
                else
                    passCount = 0
                    currentStake = playerStake
                    runningTeam = currentPlayer.team
                    UPD_DisplayCurrentStake(currentStake)
                    UPD_DisplayCoincheButton(GetOpponentTeam(runningTeam))
                end

                currentPlayerIndex = GetNextPlayerIndex(currentPlayerIndex)
            end

            log("AnnonceLoop end")
            if currentStake == nil then
                return nil
            else
                return {
                    team = runningTeam,
                    otherTeam = GetOpponentTeam(runningTeam),
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
                turnWinner.team.roundScore =
                    turnWinner.team.roundScore +
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
    end

    do -- Utils
        function WaitFrames(n) 
            for i = 1, n do
                coroutine.yield(0)
            end
        end
        function WaitCondition(condition)
            while not condition() do
                WaitFrames(50) 
            end
        end
    end

    do -- UI Variables
        stakeDone = false
        lastStake = nil
        tempStake = nil
    end

    do -- UI Await user input

        function WaitPlayerStake(player, lastStake)
            tempStake = nil

            UPD_DisplayStakeSelector(player)
            UPD_DisplayThinkingPlayer(player)
            WaitCondition(function() return stakeDone end)
            UPD_HideStakeSelector()
            UPD_HideThinkingPlayer()

            stakeDone = false
            return tempStake
        end
    end

    do -- UI Actions
        function ACT_StartGame() 
            startLuaCoroutine(Global, "GameLoop")
        end

        function ACT_Stake()
            tempStake = {atoutColor = "hearts", contract = 80}
            stakeDone = true
        end
        function ACT_Pass()
            stakeDone = true
        end
        function ACT_Coinche()
            tempStake = "coinche"
            stakeDone = true
        end
    end

    do -- UI Update
        function UPD_EnterStartup()
            UI.show("start-game-panel")
        end
        function UPD_LeaveStartup()
            UI.hide("start-game-panel")
        end

        function UPD_EnterAnnonce()
            UI.show("annonce-panel")
        end
        function UPD_LeaveAnnonce()
            UI.hide("annonce-panel")
        end

        function UPD_DisplayThinkingPlayer(player)
            UI.setAttribute("thinking-player", "color", player.color)
            playerName = player.ttsPlayer.steam_name ~= nil and player.ttsPlayer.steam_name or player.color
            UI.setValue("thinking-player", playerName .. " is thinking...")
            UI.show("thinking-player")
        end
        function UPD_HideThinkingPlayer()
            UI.hide("thinking-player")
        end

        function UPD_DisplayStakeSelector(player)
            UI.setAttribute("stake-selector", "visibility", player.color)
        end
        function UPD_HideStakeSelector()
            UI.setAttribute("stake-selector", "visibility", nil)
        end

        function UPD_DisplayCoincheButton(team)
            visibilityAttribute = team.players[1].color .. "|" .. team.players[2].color
            UI.setAttribute("coinche-button", "visibility", visibilityAttribute)
        end

        function UPD_DisplayCurrentStake(currentStake)
            UI.setValue("current-stake", currentStake.contract .. " " .. currentStake.atoutColor)
            UI.show("current-stake")
        end
    end
    
    UPD_EnterStartup()
end