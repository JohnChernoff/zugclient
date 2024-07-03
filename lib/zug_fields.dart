enum MessageScope { room, area, server } //TODO: make server and client messages the same?

enum ServMsg { none, version, ip, ipReq, ping, obs, unObs, reqLogin, logOK, noLog, errMsg, alertMsg, servMsg, servUserMsg, areaUserMsg, areaMsg, roomMsg, privMsg, phase,
  joinArea, partArea, createArea, startArea, userList, areaList, updateAreaList, updateArea, updateRoom, updateServ, updateUser, updateOccupant, updateOccupants, updateOptions
}
enum ClientMsg { none, ip, pong, obs, unObs, login, getOptions, setOptions, listAreas,
  newRoom, joinRoom, newArea, joinArea, startArea, partArea, areaMsg, roomMsg, servMsg, privMsg, updateArea, updateRoom, updateServ, updateUser, updateOccupant, setDeaf, ban
}

enum AreaChange {created,updated,deleted}

const fieldData = "data",
    fieldAddress = "address",
    fieldServ = "serv",
    fieldUniqueName = "uname",
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
    fieldArea = "area",
    fieldAreas = "areas",
    fieldDeafened = "deafened",
    fieldOptVal = "val",
    fieldOptMin = "min",
    fieldOptMax = "max",
    fieldOptInc = "inc",
    fieldOptions = "options",
    fieldAuthSource = "source",
    fieldChatColor = "chat_color",
    fieldColor = "color",
    fieldHidden = "hidden",
    fieldID = "id",
    fieldLoginType = "login_type",
    fieldAreaChange = "area_change";


