enum MessageScope { room, area, server } //TODO: make server and client messages the same?

enum ServMsg { none, version, ip, ipReq, ping, obs, unObs, reqLogin, logOK, noLog, errMsg, alertMsg, servMsg, servUserMsg, areaUserMsg, areaMsg, roomMsg, privMsg, phase,
  joinArea, partArea, createArea, startArea, userList, areaList, updateAreaList, updateArea, updateRoom, updateServ, updateUser, updateOccupant, updateOccupants, updateOptions
}
enum ClientMsg { none, ip, pong, obs, unObs, login, getOptions, setOptions, listAreas,
  newRoom, joinRoom, newArea, joinArea, startArea, partArea, areaMsg, roomMsg, servMsg, privMsg, updateArea, updateRoom, updateServ, updateUser, updateOccupant, setDeaf, ban
}

enum AreaChange {created,updated,deleted}

const List<String> occupantHeaders = ["Name"];

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
    fieldOptions = "options",
    fieldOptType = "opt_type",
    fieldOptVal = "opt_val",
    fieldOptMin = "opt_min",
    fieldOptMax = "opt_max",
    fieldOptInc = "opt_inc",
    fieldOptDesc = "opt_desc",
    fieldOptLabel = "opt_label",
    fieldOptEnum = "opt_enum",
    fieldOptName = "opt_name",
    fieldAuthSource = "source",
    fieldChatColor = "chat_color",
    fieldColor = "color",
    fieldHidden = "hidden",
    fieldID = "id",
    fieldLoginType = "login_type",
    fieldPhase = "phase",
    fieldPhaseTimeRemaining = "phase_time_remaining",
    fieldAreaChange = "area_change";




