enum MessageScope { room, area, server }
enum ServMsg { none, obs, unObs, reqLogin, logOK, noLog,
  errMsg, servMsg, servUserMsg, areaUserMsg, areaMsg, roomMsg, privMsg,
  updateUsers, updateAreas, updateArea, updateRoom, updateServ, updateUser, updateOccupant, updateOccupants, updateOptions }
enum ClientMsg { none, obs, unObs, login, loginGuest, loginLichess,
  getOptions, setOptions, newRoom, joinRoom, newArea, joinArea, partArea, startArea,
  areaMsg, roomMsg, servMsg, privMsg, updateArea, updateRoom, updateServ, updateUser, updateOccupant, setMute }

const fieldData = "data",
    fieldName = "name",
    fieldType = "type",
    fieldMsg = "msg",
    fieldToken = "token",
    fieldPwd = "pwd",
    fieldJSON = "json",
    fieldGame = "game",
    fieldTitle = "title",
    fieldPlayer = "occupant",
    fieldRoom = "room",
    fieldAreas = "areas",
    fieldMuted = "muted",
    fieldOptVal = "val",
    fieldOptMin = "min",
    fieldOptMax = "max",
    fieldOptInc = "inc",
    fieldOptions = "options",
    fieldColor = "color";

