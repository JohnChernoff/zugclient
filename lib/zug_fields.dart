enum MessageScope { room, area, server } //TODO: make server and client messages the same?
enum ServMsg { none, obs, unObs, reqLogin, logOK, noLog,
  errMsg, servMsg, servUserMsg, areaUserMsg, areaMsg, roomMsg, privMsg, joinArea, partArea,
  updateUsers, updateAreas, updateArea, updateRoom, updateServ, updateUser, updateOccupant, updateOccupants, updateOptions }
enum ClientMsg { none, obs, unObs, login, loginGuest, loginLichess,
  getOptions, setOptions, newRoom, joinRoom, newArea, joinArea, partArea, startArea,
  areaMsg, roomMsg, servMsg, privMsg, updateArea, updateRoom, updateServ, updateUser, updateOccupant, setMute }

const fieldData = "data",
    fieldServ = "serv",
    fieldName = "name",
    fieldType = "type",
    fieldMsg = "msg",
    fieldToken = "token",
    fieldPwd = "pwd",
    fieldJSON = "json",
    fieldGame = "game",
    fieldTitle = "title",
    fieldPlayer = "player",
    fieldOccupant = "occupant",
    fieldOccupants = "occupants",
    fieldUser = "user",
    fieldRoom = "room",
    fieldAreas = "areas",
    fieldMuted = "muted",
    fieldOptVal = "val",
    fieldOptMin = "min",
    fieldOptMax = "max",
    fieldOptInc = "inc",
    fieldOptions = "options",
    fieldAuthSource = "source",
    fieldChatColor = "chat_color",
    fieldColor = "color";

