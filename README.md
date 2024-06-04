# Powershell GPN (Gulasch Programmier Nacht) Tron bot
This is a bot for GPN-Tron written in Powershell at GPN-22

## Server
https://github.com/freehuntx/gpn-tron

## Packet Doc
https://github.com/freehuntx/gpn-tron/blob/master/PROTOCOL.md


## How to use it:
- Download File
- Set the Variables on top. (ServerAddress,Port, User, PW)
- Run in PowerShell. (Set Execution Policy if you haven't already)

## add your own strategy
- The function "get-next-move" can be used to add more strategies.
- Add a name for your strategy to the ValidationSet and write it in the next ElseIf.
- Define the variable $Global:strategy (on Top) to be your strategy name

## Strategies
### Random
- Selects a random direction
- Tests if this field is free
- If not, get next direction and test it
- Else use this direction
### urdl
- Test if UP is free
- If not, Test Right
- If not, Test Down
- If not, Test Right
- Use first direction which is free
