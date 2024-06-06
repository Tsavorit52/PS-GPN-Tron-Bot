############Settings############
$serverAddress = "0.0.0.0" #ip
$port = "4000" #port
$Global:User = 'Username' #username
$Global:PW = ('Password') #password
$Global:strategy = 'random' #Strategy to choose next move (random or urdl)
$Global:muteChat = $true #mutes the chat output
$Global:renderPlayfiled = $false #show gameboard rendered in console outputs
$Global:showPackets = $false #sent and received packets will printed in the chat



############Initialize Variables############
[int]$global:gamesizex = 0 #game board size x direction
[int]$global:gamesizey = 0 #game board size y direction
[int]$global:myplayerid = $null #playerid of the bot
$global:players = @{} #list of all players
$global:myposition = @(0,0) #current position of the bot, will be updated after every move
$global:headpositions = @{} #current position of all the players heads

############Functions############
function get-next-move(){
    Param(
        [ValidateSet("random", "urdl")]
        [string]$strategy
    )
    #Random
    if($strategy -eq 'random'){

     #get a random direction and test if it is free
        $count = 0
        $random = Get-Random -Minimum 0 -Maximum 4

        do{
            if($random -eq 0){
                $nextmove = 'up'
            }elseif($random -eq 1){
                $nextmove = 'down'
            }elseif($random -eq 2){
                $nextmove = 'left'
            }else{
                $nextmove = 'right'
            }
            
            if($random -ge 3){
                $random = -1
            }
            $random++
            $count++
        }while((!(test-next-move -move $nextmove))-and $count -lt 5)
    }  

    #urdl (always Up then Right Down, Left)
    elseif($strategy -eq 'urdl'){
        $nextmove = 'up'
        
        if(!(test-next-move -move $nextmove)){
            $nextmove = 'right'
        }

        if(!(test-next-move -move $nextmove)){
            $nextmove = 'down'
        }

        if(!(test-next-move -move $nextmove)){
            $nextmove = 'left'
        }
    }

    return $nextmove
}


function message-handler($packet){
    $message = $null

    #this function parses the packets and return a message if required
    #messages could be packets that are sent to the server or "break" to kill the connection or "nextmessage" to listen for the next message
    
    $splitpacket = ($packet -split "\|")
    $messagetype = $splitpacket[0]

    #packet types: https://github.com/freehuntx/gpn-tron/blob/master/PROTOCOL.md


    #---------error---------
    #error types: https://github.com/freehuntx/gpn-tron/blob/master/ERRORCODES.md
    if($messagetype -eq "error"){
        write-host $splitpacket[1] -ForegroundColor Red
        $message = "break"
    }
    
    #---------motd---------
    elseif($messagetype -eq "motd"){
        $message = ('join|'+$Global:User+'|'+$Global:PW+[char]0x0A)
    }
    
    #---------game---------
    elseif($messagetype -eq "game"){
        $global:gamesizex = [int]$splitpacket[1]
        $global:gamesizey = [int]$splitpacket[2]
        $global:myplayerid = [int]$splitpacket[3]

        $global:gameboard =  New-Object 'object[,]' $global:gamesizex,$global:gamesizey

        for($x=0; $x -le  $global:gamesizex-1; $x++){
            for($y=0; $y -le  $global:gamesizey-1; $y++){
                $global:gameboard[$x,$y] = -1        
            }
        }

        $message = 'nextmessage'
    }
    
    #---------player---------
    elseif($messagetype -eq "player"){
        $global:players += @{ $splitpacket[1] = $splitpacket[2]}
        $message = 'nextmessage'

    #---------pos---------
    }elseif($messagetype -eq 'pos'){
        $global:gameboard[$splitpacket[2],$splitpacket[3]] = $splitpacket[1]

        #update list of all head positions
        $pos = @($splitpacket[2],$splitpacket[3])
        
        if($global:headpositions.ContainsKey($splitpacket[1])){
            $global:headpositions.($splitpacket[1]) = $pos
        }else{
            $global:headpositions += @{ $splitpacket[1] = $pos}
        }

        #update variable with my position
        if($splitpacket[1] -eq [int]$global:myplayerid){
            $global:myposition[0] = [int]$splitpacket[2]
            $global:myposition[1] = [int]$splitpacket[3]
        }
        $message = 'nextmessage'
    }

    #---------tick---------
    elseif($messagetype -eq 'tick'){
        #clear console
        if($Global:renderPlayfiled){
            clear
            #render new frame
            render-gameboard -fancy
        }
        
        $nextmove = get-next-move -strategy $Global:strategy
         
        $message = ('move|'+$nextmove+[char]0x0A)
    }
    

    #---------die---------
    elseif($messagetype -eq 'die'){
        Write-Host ("Player:"+$splitpacket[1]+" died.")

        #remove dead player from the board and player list
        for($x=0; $x -le  $global:gamesizex-1; $x++){
            for($y=0; $y -le  $global:gamesizey-1; $y++){
                if($global:gameboard[$x,$y] -eq [int]$splitpacket[1]){
                    $global:gameboard[$x,$y] = -1
                }        
            }
        }

        $global:headpositions.Remove($splitpacket[1])
        $Global:players.Remove($splitpacket[1])
        $message = 'nextmessage'
    }

    #---------lose---------
    elseif($messagetype -eq 'lose'){
        Write-Host "Lost :(" -ForegroundColor DarkRed
        Write-Host ("Total Wins:"+$splitpacket[1]+" Total Losses:"+$splitpacket[2])

        #reset variables
        [int]$global:gamesizex = 0
        [int]$global:gamesizey = 0
        [int]$global:myplayerid = $null
        $global:players = @{}
        $global:myposition = @(0,0)

        $message = 'nextmessage'
    }

    #---------win---------
    elseif($messagetype -eq 'win'){
        Write-Host "Won!!" -ForegroundColor Green
        Write-Host ("Total Wins:"+$splitpacket[1]+" Total Losses:"+$splitpacket[2])

        #reset variables
        [int]$global:gamesizex = 0
        [int]$global:gamesizey = 0
        [int]$global:myplayerid = $null
        $global:players = @{}
        $global:myposition = @(0,0)
        $message = 'nextmessage'

    }

    #---------message---------
    elseif($messagetype -eq 'message'){
        if(!$Global:muteChat){
            Write-Host ("["+$global:players[$splitpacket[1]]+"] "+$splitpacket[2]) -ForegroundColor Green
        }
        $message = 'nextmessage'
    }
    
    
    #---------else/unhandled---------
    else{
        write-host 'Unhandled Message'
        $packet
        $message = 'nextmessage'

    }


    #return the next message
    return $message
    
}

function render-gameboard{
    param(
        [switch]$fancy
    )

    #this function renders the currend gameboard into the console. (Very Slow!!)

    for($y=0; $y -le  $global:gamesizey-1; $y++){
        [string]$line = $null
        for($x=0; $x -le  $global:gamesizex-1; $x++){
            if($fancy){
                if($global:gameboard[$x,$y] -eq -1){
                    $line += '□ '
                }elseif($global:gameboard[$x,$y] -eq $global:myplayerid){
                    $line += '▒ '
                }else{
                    $line += '█ '
                }
            }else{
                $line += ([string]$global:gameboard[$x,$y]+' ')
            }
        }
        write-host $line
    }
}


function test-next-move($move){
    #this function can test if the next move would be free

    $nextStepValue = -1

    ###todo screen boarder overflow, wrap around

    #y -1
    if($move -eq 'up'){
        if(($global:myposition[1]) -eq 0){
            $nextStepValue = $global:gameboard[$global:myposition[0],($global:gamesizey-1)]
        }else{
            $nextStepValue = $global:gameboard[$global:myposition[0],($global:myposition[1]-1)]
        }
    }
    
    #y +1
    elseif($move -eq 'down'){
        if(($global:myposition[1]) -eq ($global:gamesizey-1)){
            $nextStepValue = $global:gameboard[$global:myposition[0],0]
        }else{
            $nextStepValue = $global:gameboard[$global:myposition[0],($global:myposition[1]+1)]
        }
    }
    #x +1
    elseif($move -eq 'right'){
        if(($global:myposition[0]) -eq ($global:gamesizex-1)){
            $nextStepValue = $global:gameboard[0,$global:myposition[1]]
        }else{
            $nextStepValue = $global:gameboard[($global:myposition[0]+1),$global:myposition[1]]
        }
    }
    
    #x -1
    elseif($move -eq 'left'){
        if(($global:myposition[0]) -eq 0){
            $nextStepValue = $global:gameboard[($global:gamesizex-1),$global:myposition[1]]
        }else{
            $nextStepValue = $global:gameboard[($global:myposition[0]-1),$global:myposition[1]]
        }
    }

    if($nextStepValue -eq -1){
        return $true
    }else{
        return $false
    }

}

function test-diagonal-heads($move){
    #test for heads diagonaly to prevent them to move to the same spot a we do

    ##still in the making

    #these positions need to be filled + wrap around
    $straight = @(0,0)
    $leftd = @(0,0)
    $rightd = @(0,0)

    $headfound = $false

    foreach($key in $global:headpositions.Keys){
        if(($global:headpositions.($key)[0] -eq $straight[0]) -and ($global:headpositions.($key)[1] -eq $straight[1])){
            write-host straight
            $headfound = $true
        }

        if(($global:headpositions.($key)[0] -eq $leftd[0]) -and ($global:headpositions.($key)[1] -eq $leftd[1])){
            write-host leftd
            $headfound = $true
        }

        if(($global:headpositions.($key)[0] -eq $rightd[0]) -and ($global:headpositions.($key)[1] -eq $rightd[1])){
            write-host rightd
            $headfound = $true
        }

    }

    return $headfound
}


############Main############
try{
    #open tcp socket
    $tcp = New-Object System.Net.Sockets.TcpClient($serverAddress,$Port)
    $tcpstream = $tcp.GetStream()
    $reader = New-Object System.IO.StreamReader($tcpStream)
    $writer = New-Object System.IO.StreamWriter($tcpStream)
    $writer.AutoFlush = $true

    :connection while ($tcp.Connected)
    {   
        #write-host "connected"
        [string]$packet = $null

        #wait until the next packet is ready
        $buffertime = 0
        while(($reader.Peek() -eq -1) -and (!$tcp.Available)){
            sleep -Milliseconds 1
            $buffertime++
        }

        #save the buffer into a variable if the packet is finished (\n)
        :readbuffer while(($reader.Peek() -ne -1) -or ($tcp.Available)){        
            $nextchar = [char]$reader.Read()
            if($nextchar -eq [char]0x0A){
             break readbuffer
            }else{
                $packet += $nextchar
            }
    
        }

        if($Global:showPackets){
            write-host ("Received Packet: "+$packet)
        }
        #send packet to handler
        $message = message-handler -packet $packet

        #close connection if message handler send break (eg. Error or game finished)
        if(($message -eq "break") -or ($message -eq $null)){
            break connection
        }

        #skip send if nothing needs to be sent
        if($message -ne 'nextmessage'){
            
            if($Global:showPackets){
                #send message to server
                write-host ("Will send message: "+$message)
            }

            if ($tcp.Connected)
            {
                $writer.Write($message) | Out-Null
                $message = $null
            }
        }
    }
}catch{
    Write-Host "Fatal Error" -ForegroundColor Red
}
finally{
    #close connection
    $reader.Close()
    $writer.Close()
    $tcp.Close()

    Write-host "connection closed :("
}

