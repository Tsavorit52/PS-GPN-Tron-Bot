############Settings############
$routerAddress = "0.0.0.0" #ip
$port = "4000"
$Global:User = 'Username'
$Global:PW = ('Password')
$Global:muteChat = $true
$Global:renderPlayfiled = $false


############Initialize Variables############
[int]$global:gamesizew = 0
[int]$global:gamesizeh = 0
[int]$global:myplayerid = $null
$global:players = @{} #$global:players["1"]
$global:myposition = @(0,0)


############Functions############

function message-handler($packet){
    $message = $null
    #messages could be packets that are sent to the server or "break" to kill the connection or "nextmessage" to listen for the next message
    
    $splitpacket = ($packet -split "\|")
    $messagetype = $splitpacket[0]

    #---------error---------
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
        $global:gamesizew = [int]$splitpacket[1]
        $global:gamesizeh = [int]$splitpacket[2]
        $global:myplayerid = [int]$splitpacket[3]

        $global:gameboard =  New-Object 'object[,]' $global:gamesizew,$global:gamesizeh

        for($x=0; $x -le  $global:gamesizew-1; $x++){
            for($y=0; $y -le  $global:gamesizeh-1; $y++){
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
        
        #random direction
        $count = 0
        $random = Get-Random -Minimum 0 -Maximum 3
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
            $random++
            if($random -gt 3){
                $random = 0
            }
        }while((!(test-next-move -move $nextmove))-and $count -lt 4)
        
        <# 
        #always UP, then right down left 
        #define next move
        $nextmove = 'up'
        
        if(!(test-next-move -move $nextmove)){
            $nextmove = 'right'
        }

        if(!(test-next-move -move $nextmove)){
            $nextmove = 'down'
        }

        if(!(test-next-move -move $nextmove)){
            $nextmove = 'left'
        }#>
         
        $message = ('move|'+$nextmove+[char]0x0A)
    }
    

    #---------lose---------
    elseif($messagetype -eq 'lose'){
        Write-Host "Lost :("
        Write-Host ("Total Wins:"+$splitpacket[1]+" Total Losses:"+$splitpacket[2])
        $message = 'break'
    }

    #---------die---------
    elseif($messagetype -eq 'die'){
        Write-Host ("Player:"+$splitpacket[1]+" died.")

        #remove dead player from the board and player list
        for($x=0; $x -le  $global:gamesizew-1; $x++){
            for($y=0; $y -le  $global:gamesizeh-1; $y++){
                if($global:gameboard[$x,$y] -eq [int]$splitpacket[1]){
                    $global:gameboard[$x,$y] = -1
                }        
            }
        }

        $Global:players.Remove($splitpacket[1])
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

    for($y=0; $y -le  $global:gamesizeh-1; $y++){
        [string]$line = $null
        for($x=0; $x -le  $global:gamesizew-1; $x++){
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
    
    $nextStepValue = -1

    ###todo screen boarder overflow, wrap around

    #y -1
    if($move -eq 'up'){
        if(($global:myposition[1]) -eq 0){
            $nextStepValue = $global:gameboard[$global:myposition[0],($global:gamesizeh-1)]
        }else{
            $nextStepValue = $global:gameboard[$global:myposition[0],($global:myposition[1]-1)]
        }
    }
    
    #y +1
    elseif($move -eq 'down'){
        if(($global:myposition[1]) -eq ($global:gamesizeh-1)){
            $nextStepValue = $global:gameboard[$global:myposition[0],0]
        }else{
            $nextStepValue = $global:gameboard[$global:myposition[0],($global:myposition[1]+1)]
        }
    }
    #x +1
    elseif($move -eq 'right'){
        if(($global:myposition[0]) -eq ($global:gamesizew-1)){
            $nextStepValue = $global:gameboard[0,$global:myposition[1]]
        }else{
            $nextStepValue = $global:gameboard[($global:myposition[0]+1),$global:myposition[1]]
        }
    }
    
    #x -1
    elseif($move -eq 'left'){
        if(($global:myposition[0]) -eq 0){
            $nextStepValue = $global:gameboard[($global:gamesizew-1),$global:myposition[1]]
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


############Main############
$tcp = New-Object System.Net.Sockets.TcpClient($routerAddress,$Port)
$tcpstream = $tcp.GetStream()
$reader = New-Object System.IO.StreamReader($tcpStream)
$writer = New-Object System.IO.StreamWriter($tcpStream)
$writer.AutoFlush = $true

:connection while ($tcp.Connected)
{   
    #write-host "connected"
    [string]$packet = $null

    $buffertime = 0
    while(($reader.Peek() -eq -1) -and (!$tcp.Available)){
        sleep -Milliseconds 1
        $buffertime++
    }
    
    <#
    if($buffertime -ge 2){
        write-host ("Buffertime: "+$buffertime)
    }#>

    :readbuffer while(($reader.Peek() -ne -1) -or ($tcp.Available)){        
        $nextchar = [char]$reader.Read()
        if($nextchar -eq [char]0x0A){
         break readbuffer
        }else{
            $packet += $nextchar
        }
    
    }

    
    #write-host ("Received Packet: "+$packet)
    $message = message-handler -packet $packet
    if(($message -eq "break") -or ($message -eq $null)){
        break connection
    }

    if($message -ne 'nextmessage'){

        write-host ("Will send message: "+$message)

        if ($tcp.Connected)
        {
            $writer.Write($message) | Out-Null
            $message = $null
        }
    }
}

$reader.Close()
$writer.Close()
$tcp.Close()

Write-host "connection closed :("
