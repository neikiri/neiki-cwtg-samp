/*
 *  Neikiri's SA-MP CW/TG Gamemode
 *  Author: neikiri | Discord: neikiri69 | Email: neikiri@neikiri.dev
 *  Type: CW / TG Skinshot
 *  GitHub Repository: https://github.com/neikiri/neiki-cwtg-samp/
 *  Version: 1.0.0
 */

#include <a_samp>
#pragma tabsize 4
#pragma warning disable 239
#pragma warning disable 214
#undef MAX_PLAYERS
#define MAX_PLAYERS 20

#define MODE_NAME           "Neikiri's CW/TG Mode"
#define DEFAULT_GREEN_NAME  "Green"
#define DEFAULT_BLUE_NAME   "Blue"
#define DEFAULT_ROUNDS      3
#define DEFAULT_ROUND_SCORE 30
#define DEFAULT_WEAPON      26
#define MAX_CARS            50
#define MAX_MAPS            4
#define OWNED_STREAK        5

#define TEAM_GREEN  0
#define TEAM_BLUE   1
#define TEAM_SPEC   2
#define TEAM_NONE  -1

#define COL_RED     0xFF0000FF
#define COL_GREEN   0x33AA33FF
#define COL_BLUE    0x2F2FE2FF
#define COL_WHITE   0xFFFFFFFF
#define COL_YELLOW  0xFFFF00FF
#define COL_INFO    0xFAFA33FF

#define DIALOG_TEAM     1
#define DIALOG_PASSWORD 2
#define DIALOG_INFO     3

#define NCMD:%1() \
    forward cmd_%1(playerid,params[],bool:help); \
    public cmd_%1(playerid,params[],bool:help)

#define isnull(%1) ((!(%1[0])) || (((%1[0]) == '\1') && (!(%1[1]))))
#define ForPlayers(%0) for(new %0; %0 <= g_MaxId; %0++) if(IsPlayerConnected(%0))

new bool:FALSE=false;
#define SCMF(%0,%1,%2,%3) do{new _s[144];format(_s,sizeof(_s),%2,%3);SendClientMessage(%0,%1,_s);}while(FALSE)
#define SCMTAF(%0,%1,%2) do{new _s[144];format(_s,sizeof(_s),%1,%2);SendClientMessageToAll(%0,_s);}while(FALSE)
#define SCM SendClientMessage
#define SCMTA SendClientMessageToAll

// Banned speed skins
new g_BannedSkins[] = {0,1,2,265,266,267,268,269,270,271,272,293};

// Class skins
new g_ClassSkins[] = {
    102,103,104,105,106,107,108,150,109,110,
    114,115,116,117,121,122,123,173,174,175,
    18,23,29,45,49,97,137,144,154,195,
    209,230,171,261,294,305,308,217,85,91,
    93,192,193,194,251
};

new g_MapNames[MAX_MAPS][20] = {"Airport","Hangars","Baseball","Driving School"};

new Float:g_Spawns[MAX_MAPS][3][4] = {
    {{-1341.9940,-26.4392,14.1484,225.0088},{-1186.4745,-182.0161,14.1484,44.5505},{-1221.5259,-72.7803,27.3481,131.6112}},
    {{1586.5869,745.4418,10.8203,179.2617},{1746.8711,695.1851,10.8203,0.9733},{1663.3925,747.8785,19.9141,182.0584}},
    {{1330.1001,2212.9092,12.0156,178.8035},{1411.2450,2124.0459,12.0156,88.8759},{1368.8029,2196.1875,14.2495,177.3583}},
    {{-2047.4285,-117.2283,35.2487,178.9484},{-2051.0955,-267.9533,35.3203,358.7801},{-2076.3069,-106.9902,40.2293,194.5918}}
};

new Float:g_ObjPos[9][4] = {
    {1337.74,2094.88,20.58,180.0},{1292.11,2143.55,20.14,90.0},{1663.00,8293.00,734.00,0.0},
    {1664.21,734.22,13.11,0.0},{1663.94,706.63,13.11,180.04},{-1234.09,-84.41,16.39,-44.94},
    {-1195.23,-131.88,16.39,-44.94},{-2096.01,-188.82,37.45,90.04},{-2011.62,-189.27,37.45,-90.04}
};

// Global state
new g_MaxId, g_Map, g_Weapon, g_MaxRounds, g_MaxRoundScore;
new g_TeamName[2][50], g_TeamScore[2], g_TeamRounds[2], g_TotalScore[2], g_Owned[2];
new g_Countdown=-1, g_Stopped, g_IsCW, g_LockTeams, g_ServerPass[50], g_LagCompMode = 1;
new g_ScoreObj[9], g_Cars[MAX_CARS], g_CarCount;
new DB:g_dbAdmin, DB:g_dbUsers, DB:g_dbBans;
new Text:td_Skinshot[MAX_PLAYERS];
new Text:td_Info[MAX_PLAYERS], Text:td_World[MAX_PLAYERS];
new Text:td_Clock;

forward UpdateClock();

// NPC manager
#define MAX_MANAGED_NPCS 20
#define NPC_NAME_LENGTH   24
#define NPC_SCRIPT_LENGTH 32
enum E_NPC_DATA{
    bool:npcUsed,
    npcName[NPC_NAME_LENGTH],
    npcScript[NPC_SCRIPT_LENGTH],
    npcSkin,
    Float:npcX,
    Float:npcY,
    Float:npcZ,
    Float:npcAngle,
    npcWorld,
    npcInterior,
    npcPlayerId
};
new NpcData[MAX_MANAGED_NPCS][E_NPC_DATA];

// Per-player
new g_Team[MAX_PLAYERS], g_Kills[MAX_PLAYERS], g_Deaths[MAX_PLAYERS], g_TK[MAX_PLAYERS];
new g_Admin[MAX_PLAYERS], g_Skin[MAX_PLAYERS], g_Time[MAX_PLAYERS];
new g_Spec[MAX_PLAYERS], g_LastPM[MAX_PLAYERS], g_DrunkLast[MAX_PLAYERS], g_FPS[MAX_PLAYERS], g_HitSound[MAX_PLAYERS];

// TextDraws
new Text:td_Bar, Text:td_Score[MAX_PLAYERS];
new Text:td_WBG, Text:td_WTitle, Text:td_WG, Text:td_WB, Text:td_WGH, Text:td_WBH, Text:td_WInfo;
new Text:td_GN, Text:td_GK, Text:td_GD, Text:td_GR, Text:td_BN, Text:td_BK, Text:td_BD, Text:td_BR;

forward CountdownTick();
forward HideResults();
forward PassKick(playerid);
forward AntiCheat();
forward SpecRefresh(playerid,specid);

main()
{
    print("\n========== Neikiri's CW/TG Mode ==========");
    print("  Author: neikiri | Type: CW/TG Skinshot");
    print("==========================================\n");
}

stock PlayerName(playerid){new n[MAX_PLAYER_NAME];GetPlayerName(playerid,n,MAX_PLAYER_NAME);return n;}
stock Float:GetKD(p){if(g_Deaths[p]==0)return float(g_Kills[p]);return float(g_Kills[p])/float(g_Deaths[p]);}
stock ClearDeathList(){for(new i=0;i<6;i++)SendDeathMessage(202,202,202);}
stock bool:IsBanned(s){for(new i=0;i<sizeof(g_BannedSkins);i++)if(g_BannedSkins[i]==s)return true;return false;}

stock ShowTeamDlg(playerid){
    new s[100];format(s,100,"%s\n%s\nSpectator",g_TeamName[0],g_TeamName[1]);
    ShowPlayerDialog(playerid,DIALOG_TEAM,2,"Select Team",s,"Select","Cancel");
}

stock SpectateEx(playerid,id){
    new s[100];format(s,100,"~r~%s ~w~(%d)~n~Prev: WALK   Next: JUMP",PlayerName(id),id);
    GameTextForPlayer(playerid,s,60000,4);PlayerSpectatePlayer(playerid,id,0);
}

stock RefreshObjects(){
    new s[64];format(s,64,"{00FF00}%d{FFFFFF}:{FF0000}%d",g_TeamScore[0],g_TeamScore[1]);
    for(new i=0;i<9;i++){
        DestroyObject(g_ScoreObj[i]);
        g_ScoreObj[i]=CreateObject(7914,g_ObjPos[i][0],g_ObjPos[i][1],g_ObjPos[i][2],0.0,0.0,g_ObjPos[i][3]);
        SetObjectMaterialText(g_ScoreObj[i],s,0,OBJECT_MATERIAL_SIZE_256x128,"Arial",60,0,0xFFFF8200,0xFF000000,OBJECT_MATERIAL_TEXT_ALIGN_CENTER);
    }
}

stock UpdateScoreBar(){
    new s[256];
    ForPlayers(i){
        format(s,256,"~g~%s ~w~vs ~b~%s ~w~I Round: ~g~%02d~w~:~b~%02d ~w~I Score: ~g~%02d~w~:~b~%02d ~w~I K: ~b~%d ~w~I D: ~b~%d ~w~I K/D: ~b~%0.2f",
            g_TeamName[0],g_TeamName[1],g_TeamRounds[0],g_TeamRounds[1],g_TeamScore[0],g_TeamScore[1],g_Kills[i],g_Deaths[i],GetKD(i));
        TextDrawSetString(td_Score[i],s);
    }
    RefreshObjects();
}

stock UpdatePlayerBar(p){
    new s[256];
    format(s,256,"~g~%s ~w~vs ~b~%s ~w~I Round: ~g~%02d~w~:~b~%02d ~w~I Score: ~g~%02d~w~:~b~%02d ~w~I K: ~b~%d ~w~I D: ~b~%d ~w~I K/D: ~b~%0.2f",
        g_TeamName[0],g_TeamName[1],g_TeamRounds[0],g_TeamRounds[1],g_TeamScore[0],g_TeamScore[1],g_Kills[p],g_Deaths[p],GetKD(p));
    TextDrawSetString(td_Score[p],s);
}

// ---- TextDraw creation ----
stock CreateTextDraws(){
    td_Bar=TextDrawCreate(1.0,428.0,"~n~");
    TextDrawFont(td_Bar,1);TextDrawLetterSize(td_Bar,0.35,1.0);TextDrawUseBox(td_Bar,1);
    TextDrawBoxColor(td_Bar,255);TextDrawTextSize(td_Bar,675.0,0.0);TextDrawColor(td_Bar,-1);

    for(new i=0;i<MAX_PLAYERS;i++){
        td_Score[i]=TextDrawCreate(313.0,428.0," ");
        TextDrawAlignment(td_Score[i],2);TextDrawFont(td_Score[i],1);
        TextDrawLetterSize(td_Score[i],0.32,1.0);TextDrawColor(td_Score[i],-1);
        TextDrawSetProportional(td_Score[i],1);TextDrawSetShadow(td_Score[i],1);

        td_Skinshot[i]=TextDrawCreate(620.0,415.0,"SKINSHOT");
        TextDrawFont(td_Skinshot[i],1);TextDrawAlignment(td_Skinshot[i],2);
        TextDrawColor(td_Skinshot[i],0xFFFF00FF);TextDrawLetterSize(td_Skinshot[i],0.2,1.0);
        TextDrawBackgroundColor(td_Skinshot[i],0x000000FF);TextDrawSetOutline(td_Skinshot[i],1);
    }

    // Win screen
    td_WBG=TextDrawCreate(-10.0,110.0,"~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~");
    TextDrawFont(td_WBG,1);TextDrawLetterSize(td_WBG,0.5,1.0);TextDrawUseBox(td_WBG,1);TextDrawBoxColor(td_WBG,170);TextDrawTextSize(td_WBG,650.0,0.0);TextDrawColor(td_WBG,-1);

    td_WTitle=TextDrawCreate(202.0,108.0,"Neikiri's CW/TG Mode");
    TextDrawFont(td_WTitle,2);TextDrawLetterSize(td_WTitle,0.5,1.0);TextDrawColor(td_WTitle,255);TextDrawSetOutline(td_WTitle,1);TextDrawBackgroundColor(td_WTitle,-1);TextDrawSetProportional(td_WTitle,1);

    td_WG=TextDrawCreate(50.0,110.0,"~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~");
    TextDrawFont(td_WG,1);TextDrawLetterSize(td_WG,0.5,1.0);TextDrawUseBox(td_WG,1);TextDrawBoxColor(td_WG,136);TextDrawTextSize(td_WG,590.0,0.0);TextDrawColor(td_WG,-1);

    td_WB=TextDrawCreate(320.0,110.0,"~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~~n~");
    TextDrawAlignment(td_WB,2);TextDrawFont(td_WB,1);TextDrawLetterSize(td_WB,0.5,1.0);TextDrawUseBox(td_WB,1);TextDrawBoxColor(td_WB,-16777046);TextDrawColor(td_WB,-1);

    td_WGH=TextDrawCreate(50.0,118.0,"~g~Name                      Kills  Deaths  Ratio");
    TextDrawFont(td_WGH,1);TextDrawLetterSize(td_WGH,0.36,1.0);TextDrawColor(td_WGH,-1);TextDrawSetProportional(td_WGH,1);

    td_WBH=TextDrawCreate(323.0,118.0,"~r~Name                      Kills  Deaths  Ratio");
    TextDrawFont(td_WBH,1);TextDrawLetterSize(td_WBH,0.36,1.0);TextDrawColor(td_WBH,-1);TextDrawSetProportional(td_WBH,1);

    td_WInfo=TextDrawCreate(210.0,348.0," ");
    TextDrawFont(td_WInfo,1);TextDrawLetterSize(td_WInfo,0.5,1.0);TextDrawColor(td_WInfo,-1);TextDrawSetProportional(td_WInfo,1);
    TextDrawUseBox(td_WInfo,1);TextDrawBoxColor(td_WInfo,204);TextDrawTextSize(td_WInfo,471.0,1.0);

    td_GN=TextDrawCreate(50.0,128.0," ");TextDrawFont(td_GN,1);TextDrawLetterSize(td_GN,0.36,1.0);TextDrawColor(td_GN,-1);TextDrawSetProportional(td_GN,1);
    td_GK=TextDrawCreate(205.0,128.0," ");TextDrawFont(td_GK,1);TextDrawLetterSize(td_GK,0.36,1.0);TextDrawColor(td_GK,-1);TextDrawSetProportional(td_GK,1);
    td_GD=TextDrawCreate(246.0,128.0," ");TextDrawFont(td_GD,1);TextDrawLetterSize(td_GD,0.36,1.0);TextDrawColor(td_GD,-1);TextDrawSetProportional(td_GD,1);
    td_GR=TextDrawCreate(285.0,128.0," ");TextDrawFont(td_GR,1);TextDrawLetterSize(td_GR,0.36,1.0);TextDrawColor(td_GR,-1);TextDrawSetProportional(td_GR,1);
    td_BN=TextDrawCreate(323.0,128.0," ");TextDrawFont(td_BN,1);TextDrawLetterSize(td_BN,0.36,1.0);TextDrawColor(td_BN,-1);TextDrawSetProportional(td_BN,1);
    td_BK=TextDrawCreate(478.0,128.0," ");TextDrawFont(td_BK,1);TextDrawLetterSize(td_BK,0.36,1.0);TextDrawColor(td_BK,-1);TextDrawSetProportional(td_BK,1);
    td_BD=TextDrawCreate(518.0,128.0," ");TextDrawFont(td_BD,1);TextDrawLetterSize(td_BD,0.36,1.0);TextDrawColor(td_BD,-1);TextDrawSetProportional(td_BD,1);
    td_BR=TextDrawCreate(559.0,128.0," ");TextDrawFont(td_BR,1);TextDrawLetterSize(td_BR,0.36,1.0);TextDrawColor(td_BR,-1);TextDrawSetProportional(td_BR,1);
}

public OnGameModeInit(){
    g_dbAdmin=db_open("admins.db");
    g_dbUsers=db_open("users.db");
    g_dbBans=db_open("bans.db");
    db_query(g_dbAdmin,"CREATE TABLE IF NOT EXISTS admins(ID INTEGER PRIMARY KEY AUTOINCREMENT,Player_Name TEXT,IP TEXT UNIQUE,Admin_Level INTEGER DEFAULT 0)");
    db_query(g_dbUsers,"CREATE TABLE IF NOT EXISTS users(ID INTEGER PRIMARY KEY AUTOINCREMENT,IP TEXT UNIQUE,Names TEXT,AdminLevel INTEGER DEFAULT 0)");
    db_query(g_dbBans,"CREATE TABLE IF NOT EXISTS bans(ID INTEGER PRIMARY KEY AUTOINCREMENT,Player TEXT,IP TEXT,Reason TEXT,Admin TEXT,Permanent INTEGER DEFAULT 0,Timestamp INTEGER DEFAULT 0)");

    SetGameModeText("CW/TG Mode");
    for(new i=0;i<sizeof(g_ClassSkins);i++)
        AddPlayerClass(g_ClassSkins[i],-1247.2589,-91.8672,14.1484,203.8234,0,0,0,0,0,0);

    format(g_TeamName[0],50,DEFAULT_GREEN_NAME);
    format(g_TeamName[1],50,DEFAULT_BLUE_NAME);
    g_Weapon=DEFAULT_WEAPON;g_MaxRounds=DEFAULT_ROUNDS;g_MaxRoundScore=DEFAULT_ROUND_SCORE;

    DisableInteriorEnterExits();UsePlayerPedAnims();ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);EnableStuntBonusForAll(0);
    RefreshObjects();SetTimer("AntiCheat",1500,true);CreateTextDraws();

    // Real time clock (like clock.pwn)
    td_Clock=TextDrawCreate(609.0,23.0,"00:00");
    TextDrawUseBox(td_Clock,0);TextDrawFont(td_Clock,3);TextDrawSetShadow(td_Clock,0);
    TextDrawSetOutline(td_Clock,2);TextDrawBackgroundColor(td_Clock,0x000000FF);
    TextDrawColor(td_Clock,0xFFFF00FF);TextDrawAlignment(td_Clock,3);TextDrawLetterSize(td_Clock,0.6,2.0);
    UpdateClock();SetTimer("UpdateClock",1000*60,true);
    return 1;
}

public OnGameModeExit(){db_close(g_dbAdmin);db_close(g_dbUsers);db_close(g_dbBans);return 1;}

stock UpdateSkinshotHud(playerid){
    if(g_LagCompMode==0) TextDrawSetString(td_Skinshot[playerid],"LAGSHOT");
    else TextDrawSetString(td_Skinshot[playerid],"SKINSHOT");
    TextDrawShowForPlayer(playerid,td_Skinshot[playerid]);
    return 1;
}

public AntiCheat(){
    ForPlayers(i){
        if(g_Team[i]==TEAM_SPEC && g_Spec[i]==-1){
            new Float:z;GetPlayerPos(i,z,z,z);
            if(g_Map!=0){if(z<g_Spawns[g_Map][0][2]+1.0)SpawnPlayer(i);}
            else{if(z<12.0)SpawnPlayer(i);}
        }
    }
    return 1;
}

public OnPlayerConnect(playerid){
    if(IsPlayerNPC(playerid)){
        new nName[MAX_PLAYER_NAME];
        GetPlayerName(playerid, nName, sizeof(nName));
        new npcIndex = FindNpcByName(nName);
        if(npcIndex == -1){
            Kick(playerid);
            return 1;
        }
        NpcData[npcIndex][npcPlayerId] = playerid;
        ApplyNpcSettings(npcIndex);
        return 1;
    }
    TogglePlayerClock(playerid,0);
    g_Team[playerid]=TEAM_NONE;g_Kills[playerid]=0;g_Deaths[playerid]=0;g_TK[playerid]=0;
    g_Admin[playerid]=0;g_Skin[playerid]=102;g_Time[playerid]=12;
    g_Spec[playerid]=-1;g_LastPM[playerid]=INVALID_PLAYER_ID;
    g_DrunkLast[playerid]=0;g_FPS[playerid]=0;g_HitSound[playerid]=0;
    if(playerid>g_MaxId)g_MaxId=playerid;

    new q[256],ip[16],name[MAX_PLAYER_NAME],reason[128],admin[32],perma,timestamp;
    GetPlayerName(playerid,name,MAX_PLAYER_NAME);GetPlayerIp(playerid,ip,16);

    format(q,256,"SELECT * FROM bans WHERE Player='%q' COLLATE NOCASE LIMIT 1",name);
    new DBResult:banResult=db_query(g_dbBans,q);
    if(db_num_rows(banResult)>0){
        db_get_field_assoc(banResult,"Reason",reason,128);db_get_field_assoc(banResult,"Admin",admin,32);
        perma=db_get_field_assoc_int(banResult,"Permanent");timestamp=db_get_field_assoc_int(banResult,"Timestamp");
        if(perma==1||gettime()<timestamp){
            if(perma==1)SCMF(playerid,COL_RED,"{FF0000}You are banned permanently by {00FFFF}%s\n{FF0000}Reason: {00FFFF}%s",admin,reason);
            else SCMF(playerid,COL_RED,"{FF0000}You are banned until {00FFFF}%d\n{FF0000}Reason: {00FFFF}%s",timestamp,reason);
            db_free_result(banResult);Kick(playerid);return 1;
        }
        format(q,256,"DELETE FROM bans WHERE Player='%q' COLLATE NOCASE",name);db_free_result(banResult);new DBResult:banDelete=db_query(g_dbBans,q);db_free_result(banDelete);
    }else db_free_result(banResult);

    format(q,256,"SELECT * FROM bans WHERE IP='%s' LIMIT 1",ip);
    banResult=db_query(g_dbBans,q);
    if(db_num_rows(banResult)>0){
        db_get_field_assoc(banResult,"Reason",reason,128);db_get_field_assoc(banResult,"Admin",admin,32);
        perma=db_get_field_assoc_int(banResult,"Permanent");timestamp=db_get_field_assoc_int(banResult,"Timestamp");
        if(perma==1||gettime()<timestamp){
            if(perma==1)SCMF(playerid,COL_RED,"{FF0000}Your IP is banned permanently by {00FFFF}%s\n{FF0000}Reason: {00FFFF}%s",admin,reason);
            else SCMF(playerid,COL_RED,"{FF0000}Your IP is banned until {00FFFF}%d\n{FF0000}Reason: {00FFFF}%s",timestamp,reason);
            db_free_result(banResult);Kick(playerid);return 1;
        }
        format(q,256,"DELETE FROM bans WHERE IP='%s'",ip);db_free_result(banResult);new DBResult:banDeleteIp=db_query(g_dbBans,q);db_free_result(banDeleteIp);
    }else db_free_result(banResult);

    SCMTAF(0x32CD32FF,"{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}connected",PlayerName(playerid));
    SCM(playerid,COL_INFO,"{FAFA33}============= Neikiri's CW/TG Mode =============");
    SCM(playerid,0x32CD32FF,"{32CD32}Commands: {00FFFF}/help {32CD32}| Admin: {00FFFF}/ahelp");
    SCM(playerid,0x32CD32FF,"{32CD32}Author: {00FFFF}neikiri {32CD32}| Discord: {00FFFF}neikiri69");
    SCM(playerid,COL_INFO,"{FAFA33}============= Neikiri's CW/TG Mode =============");

    GetPlayerIp(playerid,ip,16);
    format(q,256,"SELECT Admin_Level FROM admins WHERE IP='%s' LIMIT 1",ip);
    new DBResult:adminResult=db_query(g_dbAdmin,q);
    if(db_num_rows(adminResult)>0){new l=db_get_field_int(adminResult,0);if(l>0){SetPVarInt(playerid,"Logged",1);g_Admin[playerid]=l;SCMF(playerid,-1,"{FAFA33}INFO: {32CD32}Auto-login - Admin level {00FFFF}%d",l);}}
    db_free_result(adminResult);

    format(q,256,"SELECT Names FROM users WHERE IP='%s'",ip);
    new DBResult:ur=db_query(g_dbUsers,q);
    if(db_num_rows(ur)>0){new c[256];db_get_field(ur,0,c,256);format(q,256,"UPDATE users SET Names='%s,%s' WHERE IP='%s'",c,name,ip);}
    else format(q,256,"INSERT INTO users(IP,Names,AdminLevel)VALUES('%s','%s',0)",ip,name);
    db_free_result(ur);new DBResult:qr=db_query(g_dbUsers,q);db_free_result(qr);

    if(!g_ServerPass[1]) ShowTeamDlg(playerid);
    else{
        ShowPlayerDialog(playerid,DIALOG_PASSWORD,1,"Server Locked","{FFFFFF}Match in progress. Enter password or get kicked in {FF0000}10s{FFFFFF}.","Enter","Leave");
        SetTimerEx("PassKick",10000,false,"i",playerid);
    }

    RemoveBuildingForPlayer(playerid,8087,1667.7422,723.2266,21.0938,0.25);
    RemoveBuildingForPlayer(playerid,712,1555.4844,710.5000,19.3359,0.25);
    RemoveBuildingForPlayer(playerid,3459,1577.1953,725.0156,17.2188,0.25);
    RemoveBuildingForPlayer(playerid,674,1756.0234,723.0078,9.7656,0.25);
    RemoveBuildingForPlayer(playerid,674,1756.0234,719.5781,9.7656,0.25);
    RemoveBuildingForPlayer(playerid,3459,1758.2344,725.6641,17.1641,0.25);
    RemoveBuildingForPlayer(playerid,7617,1333.3828,2075.9297,22.8359,0.25);
    RemoveBuildingForPlayer(playerid,645,1323.4766,2094.1797,10.8750,0.25);
    RemoveBuildingForPlayer(playerid,1278,1349.7031,2103.8516,24.0078,0.25);
    RemoveBuildingForPlayer(playerid,1278,1302.8984,2105.6953,24.0078,0.25);
    RemoveBuildingForPlayer(playerid,1278,1396.5625,2103.8516,24.0078,0.25);
    RemoveBuildingForPlayer(playerid,1278,1301.8906,2154.2344,24.0078,0.25);
    RemoveBuildingForPlayer(playerid,1278,1301.8906,2197.9688,24.0078,0.25);
    RemoveBuildingForPlayer(playerid,1278,1351.7891,2197.9688,24.0078,0.25);
    RemoveBuildingForPlayer(playerid,1278,1396.5625,2154.2422,24.0078,0.25);
    TextDrawShowForPlayer(playerid,td_Skinshot[playerid]);
    UpdateSkinshotHud(playerid);

    // HUD: FPS / Ping / PacketLoss
    td_Info[playerid]=TextDrawCreate(563.0,11.0,"FPS: 000\nPing: 0\nPacketLoss: 0.0%");
    TextDrawAlignment(td_Info[playerid],2);TextDrawFont(td_Info[playerid],1);
    TextDrawLetterSize(td_Info[playerid],0.2,1.0);TextDrawColor(td_Info[playerid],0xFFFF00FF);
    TextDrawSetOutline(td_Info[playerid],1);TextDrawBackgroundColor(td_Info[playerid],0x000000FF);
    TextDrawShowForPlayer(playerid,td_Info[playerid]);

    // HUD: World ID
    td_World[playerid]=TextDrawCreate(582.0,100.0,"World ID: 000");
    TextDrawAlignment(td_World[playerid],2);TextDrawFont(td_World[playerid],1);
    TextDrawLetterSize(td_World[playerid],0.2,1.0);TextDrawColor(td_World[playerid],0xFFFF00FF);
    TextDrawSetOutline(td_World[playerid],1);TextDrawBackgroundColor(td_World[playerid],255);
    TextDrawShowForPlayer(playerid,td_World[playerid]);

    TextDrawShowForPlayer(playerid,td_Clock);
    return 1;
}

public OnPlayerDisconnect(playerid,reason){
    if(IsPlayerNPC(playerid)){
        for(new npcIndex = 0; npcIndex < MAX_MANAGED_NPCS; npcIndex++){
            if(NpcData[npcIndex][npcUsed] && NpcData[npcIndex][npcPlayerId] == playerid){
                NpcData[npcIndex][npcPlayerId] = INVALID_PLAYER_ID;
                break;
            }
        }
        return 1;
    }
    if(playerid==g_MaxId){g_MaxId--;while(g_MaxId>0&&!IsPlayerConnected(g_MaxId))g_MaxId--;}
    if(td_Skinshot[playerid]!=Text:INVALID_TEXT_DRAW){TextDrawHideForPlayer(playerid,td_Skinshot[playerid]);TextDrawDestroy(td_Skinshot[playerid]);td_Skinshot[playerid]=Text:INVALID_TEXT_DRAW;}
    if(td_Info[playerid]!=Text:INVALID_TEXT_DRAW){TextDrawHideForPlayer(playerid,td_Info[playerid]);TextDrawDestroy(td_Info[playerid]);td_Info[playerid]=Text:INVALID_TEXT_DRAW;}
    if(td_World[playerid]!=Text:INVALID_TEXT_DRAW){TextDrawHideForPlayer(playerid,td_World[playerid]);TextDrawDestroy(td_World[playerid]);td_World[playerid]=Text:INVALID_TEXT_DRAW;}
    new r[20];switch(reason){case 0:format(r,20,"crashed");case 1:format(r,20,"left");default:format(r,20,"kicked");}
    SCMTAF(COL_INFO,"{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}disconnected ({FF0000}%s{32CD32})",PlayerName(playerid),r);
    return 1;
}

public OnPlayerRequestClass(playerid,classid){
    SetPlayerPos(playerid,2030.4219,1007.3387,13.2771);
    SetPlayerCameraPos(playerid,2038.6110,1007.1172,13.2771);
    SetPlayerCameraLookAt(playerid,2030.4219,1007.3387,13.2771);
    if(classid>=0&&classid<sizeof(g_ClassSkins)){SetPlayerSkin(playerid,g_ClassSkins[classid]);g_Skin[playerid]=g_ClassSkins[classid];}
    return 1;
}

public OnPlayerSpawn(playerid){
    if(IsPlayerNPC(playerid)){
        new nName[MAX_PLAYER_NAME];
        GetPlayerName(playerid, nName, sizeof(nName));
        new npcIndex = FindNpcByName(nName);
        if(npcIndex != -1) ApplyNpcSettings(npcIndex);
        return 1;
    }
    if(g_Team[playerid]==TEAM_NONE)return 1;
    TogglePlayerClock(playerid,0);SetPlayerHealth(playerid,100.0);ResetPlayerWeapons(playerid);
    SetPlayerSkin(playerid,g_Skin[playerid]);SetPlayerTime(playerid,g_Time[playerid],0);
    new t=g_Team[playerid];if(t==TEAM_SPEC)t=2;
    SetPlayerPos(playerid,g_Spawns[g_Map][t][0],g_Spawns[g_Map][t][1],g_Spawns[g_Map][t][2]);
    SetPlayerFacingAngle(playerid,g_Spawns[g_Map][t][3]);
    if(g_Team[playerid]!=TEAM_SPEC)GivePlayerWeapon(playerid,g_Weapon,9999);
    if(g_Admin[playerid]>0){
        new q[256],ip[16],nm[MAX_PLAYER_NAME];GetPlayerName(playerid,nm,MAX_PLAYER_NAME);GetPlayerIp(playerid,ip,16);
        format(q,256,"INSERT OR REPLACE INTO admins(Player_Name,IP,Admin_Level)VALUES('%s','%s',%d)",nm,ip,g_Admin[playerid]);
        new DBResult:rr=db_query(g_dbAdmin,q);db_free_result(rr);
    }
    TextDrawShowForPlayer(playerid,td_Clock);
    return 1;
}

public UpdateClock(){
    new hh,mm;
    gettime(hh,mm);
    new ts[8];
    format(ts,8,"%02d:%02d",hh,mm);
    TextDrawSetString(td_Clock,ts);
    return 1;
}

public OnPlayerUpdate(playerid){
    new d = GetPlayerDrunkLevel(playerid);
    if(d < 100) {
        SetPlayerDrunkLevel(playerid, 2000);
    } else if(g_DrunkLast[playerid] != d) {
        new f = g_DrunkLast[playerid] - d;
        if(f > 0 && f < 200) {
            g_FPS[playerid] = f;
        }
        g_DrunkLast[playerid] = d;
    }

    new Float:pl = NetStats_PacketLossPercent(playerid);
    new s[144];
    format(s, 144, "FPS: %03d\nPing: %d\nPacketLoss: %.1f%%", g_FPS[playerid], GetPlayerPing(playerid), pl);
    TextDrawSetString(td_Info[playerid], s);

    new w[16];
    format(w, 16, "World ID: %03d", GetPlayerVirtualWorld(playerid));
    TextDrawSetString(td_World[playerid], w);
    return 1;
}

public OnPlayerText(playerid, text[]){
    if(GetPVarInt(playerid, "Muted") == 1) {
        SCM(playerid, COL_RED, "{FF0000}ERROR: {32CD32}You are muted!");
        return 0;
    }
    new pN[MAX_PLAYER_NAME];
    GetPlayerName(playerid, pN, sizeof(pN));
    if(text[0] == '!') {
        ForPlayers(i) {
            if(g_Team[playerid] == g_Team[i]) {
                SCMF(i, 0xB88A00FF, "{B5FF4A}(Team) %s (%d): %s", pN, playerid, text[1]);
            }
        }
        return 0;
    }
    ForPlayers(i) {
        if(g_Team[playerid] == TEAM_GREEN) {
            SCMF(i, COL_WHITE, "{00FF00}%s {00FFFF}(%d){FFFFFF}: %s", pN, playerid, text);
        } else if(g_Team[playerid] == TEAM_BLUE) {
            SCMF(i, COL_WHITE, "{2F2FE2}%s {00FFFF}(%d){FFFFFF}: %s", pN, playerid, text);
        } else {
            SCMF(i, COL_WHITE, "{FFFF00}%s {00FFFF}(%d){FFFFFF}: %s", pN, playerid, text);
        }
    }
    return 0;
}

public SpecRefresh(playerid, specid){
    SpectateEx(specid, playerid);
    return 1;
}

// ---- Round logic ----
stock ProcessKill(victim, killer){
    new scoring;
    if(g_Team[victim] == g_Team[killer]) {
        scoring = (g_Team[victim] == TEAM_GREEN) ? TEAM_BLUE : TEAM_GREEN;
        SCMTAF(-1, "{FAFA33}INFO: {32CD32}Team {00FFFF}%s{32CD32} committed a team kill!", g_TeamName[g_Team[killer]]);
    } else {
        g_Owned[g_Team[victim]] = 0;
        g_Owned[g_Team[killer]]++;
        if(g_Owned[g_Team[killer]] == OWNED_STREAK) {
            SCMTAF(-1, "{FAFA33}INFO: {32CD32}Team {00FFFF}%s {32CD32}OWNED team {00FFFF}%s{32CD32}!", g_TeamName[g_Team[killer]], g_TeamName[g_Team[victim]]);
        }
        scoring = g_Team[killer];
    }
    g_TeamScore[scoring]++;
    if(g_TeamScore[scoring] >= g_MaxRoundScore) {
        g_TeamRounds[scoring]++;
        SCMTA(COL_RED, "{FAFA33}================================");
        SCMTAF(-1, "{FAFA33}INFO: {32CD32}Team {00FFFF}%s{32CD32} won the round!", g_TeamName[scoring]);
        SCMTAF(-1, "{33AA33}%s (%d) %d{FFFFFF}:{FF0000}%d (%d) %s", g_TeamName[0], g_TeamRounds[0], g_TeamScore[0], g_TeamScore[1], g_TeamRounds[1], g_TeamName[1]);
        SCMTA(COL_RED, "{FAFA33}================================");
        g_TotalScore[0] += g_TeamScore[0];
        g_TotalScore[1] += g_TeamScore[1];
        g_TeamScore[0] = 0;
        g_TeamScore[1] = 0;
        new total = g_TeamRounds[0] + g_TeamRounds[1];
        if(g_TeamRounds[scoring] >= g_MaxRounds || total >= (g_MaxRounds * 2 - 1)) {
            FinishCW();
        } else {
            ForPlayers(i) {
                SetPlayerHealth(i, 100.0);
                SpawnPlayer(i);
            }
            StartCountdown(5);
        }
    }
    UpdateScoreBar();
}

stock StartCountdown(sec){
    new s[10];
    format(s, 10, "%d", sec);
    GameTextForAll(s, 1000, 5);
    g_Countdown = sec - 1;
    ForPlayers(i) {
        TogglePlayerControllable(i, 0);
    }
    SetTimer("CountdownTick", 1000, false);
}

public CountdownTick(){
    if(g_Stopped) return 0;
    if(g_Countdown > 0) {
        new s[10];
        format(s, 10, "%d", g_Countdown);
        GameTextForAll(s, 1000, 5);
        g_Countdown--;
        ForPlayers(i) {
            PlayerPlaySound(i, 1056, 0.0, 0.0, 0.0);
        }
        SetTimer("CountdownTick", 1000, false);
    } else {
        GameTextForAll("~g~GO GO GO!", 1500, 5);
        ForPlayers(i) {
            TogglePlayerControllable(i, 1);
            SpawnPlayer(i);
            SetPlayerHealth(i, 100.0);
        }
        RefreshObjects();
        g_Countdown = -1;
    }
    return 1;
}

stock FinishCW(){
    ForPlayers(i) {
        SetPlayerHealth(i, 100.0);
        SetPlayerPos(i, g_Spawns[g_Map][g_Team[i]][0], g_Spawns[g_Map][g_Team[i]][1], g_Spawns[g_Map][g_Team[i]][2]);
        SetPlayerFacingAngle(i, g_Spawns[g_Map][g_Team[i]][3]);
        TogglePlayerControllable(i, 0);
    }
    new w = (g_TeamRounds[0] > g_TeamRounds[1]) ? TEAM_GREEN : TEAM_BLUE;
    ShowResults(w);
    SCMTA(COL_RED, "{FAFA33}================================");
    SCMTAF(-1, "{FAFA33}INFO: {32CD32}Team {00FFFF}%s{32CD32} won the Clan War!", g_TeamName[w]);
    SCMTAF(-1, "{FAFA33}INFO: {32CD32}Total: {33AA33}%s %d{FFFFFF}:{FF0000}%d %s", g_TeamName[0], g_TotalScore[0], g_TotalScore[1], g_TeamName[1]);
    SCMTA(COL_RED, "{FAFA33}================================");
    g_TotalScore[0] = 0;
    g_TotalScore[1] = 0;
    g_TeamRounds[0] = 0;
    g_TeamRounds[1] = 0;
    SetTimer("HideResults", 30000, false);
}

stock ShowResults(winner){
    ClearDeathList();
    TextDrawShowForAll(td_WBG);
    TextDrawShowForAll(td_WTitle);
    TextDrawShowForAll(td_WG);
    TextDrawShowForAll(td_WB);
    TextDrawShowForAll(td_WGH);
    TextDrawShowForAll(td_WBH);
    new nS[2][300], kS[2][300], dS[2][300], rS[2][300];
    ForPlayers(i) {
        if(g_Team[i] != TEAM_SPEC) {
            new t = g_Team[i];
            format(nS[t], 300, "%s%s~n~", nS[t], PlayerName(i));
            format(kS[t], 300, "%s%d~n~", kS[t], g_Kills[i]);
            format(dS[t], 300, "%s%d~n~", dS[t], g_Deaths[i]);
            format(rS[t], 300, "%s%0.2f~n~", rS[t], GetKD(i));
        }
    }
    TextDrawSetString(td_GN, nS[0]);
    TextDrawSetString(td_GK, kS[0]);
    TextDrawSetString(td_GD, dS[0]);
    TextDrawSetString(td_GR, rS[0]);
    TextDrawSetString(td_BN, nS[1]);
    TextDrawSetString(td_BK, kS[1]);
    TextDrawSetString(td_BD, dS[1]);
    TextDrawSetString(td_BR, rS[1]);
    TextDrawShowForAll(td_GN);
    TextDrawShowForAll(td_GK);
    TextDrawShowForAll(td_GD);
    TextDrawShowForAll(td_GR);
    TextDrawShowForAll(td_BN);
    TextDrawShowForAll(td_BK);
    TextDrawShowForAll(td_BD);
    TextDrawShowForAll(td_BR);
    new wc[6];
    if(winner == 0) {
        format(wc, 6, "~g~");
    } else {
        format(wc, 6, "~b~");
    }
    new info[512];
    format(info, 512, "Match: ~g~%s ~w~vs ~b~%s~n~~w~Winner: %s%s~n~~w~Rounds: ~g~%02d~w~:~b~%02d~n~~w~Total: ~g~%d~w~:~b~%d~n~~w~Type: ~r~%dx%02d~n~~w~Map: ~r~%s",
        g_TeamName[0], g_TeamName[1], wc, g_TeamName[winner], g_TeamRounds[0], g_TeamRounds[1], g_TotalScore[0], g_TotalScore[1], g_MaxRounds, g_MaxRoundScore, g_MapNames[g_Map]);
    TextDrawSetString(td_WInfo, info);
    TextDrawShowForAll(td_WInfo);
}

public HideResults(){
    TextDrawHideForAll(td_WBG);
    TextDrawHideForAll(td_WTitle);
    TextDrawHideForAll(td_WG);
    TextDrawHideForAll(td_WB);
    TextDrawHideForAll(td_WGH);
    TextDrawHideForAll(td_WBH);
    TextDrawHideForAll(td_WInfo);
    TextDrawHideForAll(td_GN);
    TextDrawHideForAll(td_GK);
    TextDrawHideForAll(td_GD);
    TextDrawHideForAll(td_GR);
    TextDrawHideForAll(td_BN);
    TextDrawHideForAll(td_BK);
    TextDrawHideForAll(td_BD);
    TextDrawHideForAll(td_BR);
    ForPlayers(i) {
        TogglePlayerControllable(i, 1);
    }
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason){
    TextDrawHideForPlayer(playerid, td_Clock);
    if(killerid == INVALID_PLAYER_ID) {
        return SpawnPlayer(playerid);
    }
    if(g_Team[playerid] == TEAM_SPEC) {
        return SpawnPlayer(playerid);
    }
    GameTextForPlayer(killerid, PlayerName(playerid), 4000, 1);
    g_Kills[killerid]++;
    g_Deaths[playerid]++;
    if(g_Team[playerid] == g_Team[killerid]) {
        g_TK[killerid]++;
    }
    SetPlayerScore(killerid, g_Kills[killerid]);
    SendDeathMessage(killerid, playerid, reason);
    SpawnPlayer(playerid);
    if(g_HitSound[killerid]) {
        PlayerPlaySound(killerid, 1057, 0.0, 0.0, 0.0);
    }
    ForPlayers(i) {
        if(g_Spec[i] == playerid) {
            SetTimerEx("SpecRefresh", 50, false, "ii", playerid, i);
            break;
        }
    }
    if(g_IsCW == 1) {
        ProcessKill(playerid, killerid);
    } else {
        UpdateScoreBar();
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]){
    if(dialogid == DIALOG_TEAM) {
        if(response) {
            switch(listitem) {
                case 0: {
                    if(g_LockTeams) {
                        SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Teams locked!");
                        ShowTeamDlg(playerid);
                        return 1;
                    }
                    g_Team[playerid] = TEAM_GREEN;
                    SetPlayerColor(playerid, COL_GREEN);
                    SCMTAF(COL_WHITE, "{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}joined {33AA33}%s", PlayerName(playerid), g_TeamName[0]);
                }
                case 1: {
                    if(g_LockTeams) {
                        SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Teams locked!");
                        ShowTeamDlg(playerid);
                        return 1;
                    }
                    g_Team[playerid] = TEAM_BLUE;
                    SetPlayerColor(playerid, COL_BLUE);
                    SCMTAF(COL_WHITE, "{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}joined {2F2FE2}%s", PlayerName(playerid), g_TeamName[1]);
                }
                case 2: {
                    g_Team[playerid] = TEAM_SPEC;
                    SetPlayerColor(playerid, COL_YELLOW);
                    SCMTAF(COL_WHITE, "{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}joined {FFFF00}Spectator", PlayerName(playerid));
                }
            }
            TextDrawShowForPlayer(playerid, td_Bar);
            TextDrawShowForPlayer(playerid, td_Score[playerid]);
            UpdatePlayerBar(playerid);
            if(GetPVarInt(playerid, "ClassSelected") == 1) {
                SpawnPlayer(playerid);
            }
        } else {
            ShowTeamDlg(playerid);
        }
        return 1;
    }
    if(dialogid == DIALOG_PASSWORD) {
        if(response) {
            if(!strcmp(g_ServerPass, inputtext, false)) {
                ShowTeamDlg(playerid);
            } else {
                ShowPlayerDialog(playerid, DIALOG_PASSWORD, 1, "Server Locked", "{FF0000}Wrong password!\n{FFFFFF}Try again.", "Enter", "Leave");
            }
        } else {
            SCMTAF(-1, "{FAFA33}INFO: {00FFFF}%s {32CD32}kicked (no password)", PlayerName(playerid));
            Kick(playerid);
        }
        return 1;
    }
    return 0;
}

public PassKick(playerid){
    if(!IsPlayerConnected(playerid)) {
        return 0;
    }
    if(g_Team[playerid] == TEAM_NONE) {
        SCMTAF(-1, "{FAFA33}INFO: {00FFFF}%s {32CD32}kicked (timeout)", PlayerName(playerid));
        Kick(playerid);
    }
    return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys){
    if(g_Spec[playerid] == -1) {
        return 1;
    }
    if(newkeys == KEY_WALK) {
        new f = -1;
        for(new id = g_Spec[playerid] - 1; id >= 0; id--) {
            if(IsPlayerConnected(id) && GetPlayerState(id) != PLAYER_STATE_SPECTATING) {
                f = id;
                break;
            }
        }
        if(f == -1) {
            for(new id = g_MaxId; id > g_Spec[playerid]; id--) {
                if(IsPlayerConnected(id) && GetPlayerState(id) != PLAYER_STATE_SPECTATING) {
                    f = id;
                    break;
                }
            }
        }
        if(f != -1) {
            g_Spec[playerid] = f;
            TogglePlayerSpectating(playerid, 1);
            SpectateEx(playerid, f);
        }
    } else if(newkeys == KEY_JUMP) {
        new f = -1;
        for(new id = g_Spec[playerid] + 1; id <= g_MaxId; id++) {
            if(IsPlayerConnected(id) && GetPlayerState(id) != PLAYER_STATE_SPECTATING) {
                f = id;
                break;
            }
        }
        if(f == -1) {
            for(new id = 0; id < g_Spec[playerid]; id++) {
                if(IsPlayerConnected(id) && GetPlayerState(id) != PLAYER_STATE_SPECTATING) {
                    f = id;
                    break;
                }
            }
        }
        if(f != -1) {
            g_Spec[playerid] = f;
            TogglePlayerSpectating(playerid, 1);
            SpectateEx(playerid, f);
        }
    }
    return 1;
}

// ===========================================================================
// COMMANDS - Player
// ===========================================================================

NCMD:help(){
    new s[2048];
    strcat(s, "{FAFA33}=== Player Commands ===\n");
    strcat(s, "{FFFFFF}/team - Select team\n/class - Skin selection\n/green /blue /spectator - Quick join\n");
    strcat(s, "{FFFFFF}/skin [id] - Change skin\n/kill - Suicide\n/respawn - Respawn at position\n/return - Respawn at team base\n");
    strcat(s, "{FFFFFF}/time [0-24] - Set time\n/weather [0-100] - Set weather\n/world [id] - Virtual world\n/info [id] - Player info\n");
    strcat(s, "\n{FAFA33}=== Chat ===\n{FFFFFF}/pm [id] [text] - PM\n/r [text] - Reply\n{FFFFFF}! [text] - Team chat\n");
    strcat(s, "\n{FAFA33}=== Spectator ===\n{FFFFFF}/spec [id] - Spectate\n/specoff - Stop\n/jetpack - Jetpack\n");
    strcat(s, "\n{FAFA33}=== Other ===\n{FFFFFF}/hitsound (/hs) - Toggle hitsound\n/credits\n");
    if(g_Admin[playerid] > 0) {
        strcat(s, "\n{FF0000}/ahelp - Admin commands\n");
    }
    ShowPlayerDialog(playerid, DIALOG_INFO, 0, "Neikiri's CW/TG - Help", s, "Close", "");
    return 1;
}

NCMD:ahelp(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    new s[3000];
    strcat(s, "{FFE135}=== Level 1 ===\n");
    strcat(s, "{FF0000}/map [0-3] {FFFFFF}- Change map\n{FF0000}/weapon [1-46] {FFFFFF}- Set weapon\n");
    strcat(s, "{FF0000}/cw {FFFFFF}- CW mode (score counted)\n{FF0000}/tg {FFFFFF}- TG mode (training)\n");
    strcat(s, "{FF0000}/stop /start /count [sec] {FFFFFF}- Game control\n");
    strcat(s, "{FF0000}/freeze /unfreeze [id] {FFFFFF}- Freeze player\n");
    strcat(s, "{FF0000}/mute /unmute [id] {FFFFFF}- Mute player\n");
    strcat(s, "{FF0000}/kick [id] [reason] {FFFFFF}- Kick player\n");
    strcat(s, "{FF0000}/spawn [id] /spawnall {FFFFFF}- Respawn\n");
    strcat(s, "{FF0000}/hp [id] /hpall {FFFFFF}- Heal\n");
    strcat(s, "{FF0000}/goto [id] /get [id] {FFFFFF}- Teleport\n");
    strcat(s, "{FF0000}/movegreen /moveblue /movespec [id] {FFFFFF}- Move player\n");
    strcat(s, "{FF0000}/setpoints [0/1] [n] {FFFFFF}- Set team score\n");
    strcat(s, "{FF0000}/rounds [1-5] /roundscore [1-100] {FFFFFF}- Set format\n");
    strcat(s, "{FF0000}/reset /resetall /resetstats {FFFFFF}- Reset scores\n");
    strcat(s, "{FF0000}/lockteam [0/1] {FFFFFF}- Lock teams\n");
    strcat(s, "{FF0000}/fps [id] /fpsall {FFFFFF}- FPS check\n");
    strcat(s, "{FF0000}/ip [id] {FFFFFF}- Nickname history\n");
    if(g_Admin[playerid] >= 2) {
        strcat(s, "\n{FFE135}=== Level 2 ===\n{FF0000}/teamname [0/1] [name] {FFFFFF}- Rename team\n");
        strcat(s, "{FF0000}/npc [add|del|move|list|getpos] {FFFFFF}- Manage NPCs\n");
    }
    if(g_Admin[playerid] >= 3) {
        strcat(s, "\n{FFE135}=== Level 3 ===\n");
        strcat(s, "{FF0000}/ban [id] [reason] {FFFFFF}- Ban\n{FF0000}/car [400-611] /dcar {FFFFFF}- Vehicles\n");
        strcat(s, "{FF0000}/refreshobj {FFFFFF}- Refresh objects\n{FF0000}/lockserver [pass] /unlockserver\n");
    }
    if(g_Admin[playerid] >= 5) {
        strcat(s, "\n{FFE135}=== Level 5 ===\n{FF0000}/setadmin [id] [0-5] {FFFFFF}- Set admin\n");
    }
    ShowPlayerDialog(playerid, DIALOG_INFO, 0, "Admin Commands", s, "Close", "");
    return 1;
}

NCMD:team(){
    ShowTeamDlg(playerid);
    SetPVarInt(playerid, "ClassSelected", 1);
    return 1;
}

NCMD:class(){
    ShowTeamDlg(playerid);
    SetPVarInt(playerid, "ClassSelected", 1);
    SetPlayerPos(playerid, 2030.4219, 1007.3387, 13.2771);
    SetPlayerCameraPos(playerid, 2038.6110, 1007.1172, 13.2771);
    SetPlayerCameraLookAt(playerid, 2030.4219, 1007.3387, 13.2771);
    SetPlayerFacingAngle(playerid, 270.0);
    ForceClassSelection(playerid);
    TogglePlayerSpectating(playerid, true);
    TogglePlayerSpectating(playerid, false);
    return 1;
}

NCMD:skin(){
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/skin [0-311]");
    }
    new id = strval(params);
    if(id < 0 || id > 311) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Invalid skin ID (0-311)");
    }
    if(IsBanned(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}This skin is banned (speed skin)!");
    }
    g_Skin[playerid] = id;
    SetPlayerSkin(playerid, id);
    SCMF(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Skin changed to {00FFFF}%d", id);
    return 1;
}

NCMD:weather(){
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/weather [0-100]");
    }
    new w = strval(params);
    if(w < 0 || w > 100) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 0-100");
    }
    SetPlayerWeather(playerid, w);
    SetPVarInt(playerid, "Weather", w);
    SCMF(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Weather set to {00FFFF}%d", w);
    return 1;
}

NCMD:time(){
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/time [0-24]");
    }
    new t = strval(params);
    if(t < 0 || t > 24) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 0-24");
    }
    SetPlayerTime(playerid, t, 0);
    g_Time[playerid] = t;
    SCMF(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Time set to {00FFFF}%d:00", t);
    return 1;
}

NCMD:world(){
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/world [0-999]");
    }
    new w = strval(params);
    if(w < 0 || w > 999) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 0-999");
    }
    SetPlayerVirtualWorld(playerid, w);
    SCMF(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Virtual world: {00FFFF}%d", w);
    return 1;
}

NCMD:getworld(){
    SCMF(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Your world: {00FFFF}%d", GetPlayerVirtualWorld(playerid));
    return 1;
}

NCMD:kill(){
    SCMTAF(-1, "{FAFA33}INFO: {32CD32}Player {00FFFF}%s{32CD32} killed themselves", PlayerName(playerid));
    SetPlayerHealth(playerid, -1.0);
    return 1;
}

NCMD:respawn(){
    new Float:hp, Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerHealth(playerid, hp);
    SpawnPlayer(playerid);
    SetPlayerPos(playerid, x, y, z);
    SetPlayerHealth(playerid, hp);
    SCM(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Respawned at current position");
    return 1;
}

NCMD:return(){
    SpawnPlayer(playerid);
    SetPlayerHealth(playerid, 100.0);
    SCM(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Returned to team spawn");
    return 1;
}

NCMD:green(){
    if(g_LockTeams) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Teams are locked!");
    }
    g_Team[playerid] = TEAM_GREEN;
    SetPlayerColor(playerid, COL_GREEN);
    SpawnPlayer(playerid);
    SetPlayerHealth(playerid, 100.0);
    SCMTAF(COL_WHITE, "{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}joined {33AA33}%s", PlayerName(playerid), g_TeamName[0]);
    return 1;
}

NCMD:blue(){
    if(g_LockTeams) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Teams are locked!");
    }
    g_Team[playerid] = TEAM_BLUE;
    SetPlayerColor(playerid, COL_BLUE);
    SpawnPlayer(playerid);
    SetPlayerHealth(playerid, 100.0);
    SCMTAF(COL_WHITE, "{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}joined {2F2FE2}%s", PlayerName(playerid), g_TeamName[1]);
    return 1;
}

NCMD:spectator(){
    g_Team[playerid] = TEAM_SPEC;
    SetPlayerColor(playerid, COL_YELLOW);
    SpawnPlayer(playerid);
    SetPlayerHealth(playerid, 100.0);
    SCMTAF(COL_WHITE, "{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}joined {FFFF00}Spectator", PlayerName(playerid));
    return 1;
}

NCMD:spec(){
    if(g_Team[playerid] != TEAM_SPEC) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Must be spectator!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/spec [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    g_Spec[playerid] = id;
    TogglePlayerSpectating(playerid, 1);
    SpectateEx(playerid, id);
    return 1;
}

NCMD:specoff(){
    g_Spec[playerid] = -1;
    TogglePlayerSpectating(playerid, 0);
    return 1;
}

NCMD:jetpack(){
    if(g_Team[playerid] != TEAM_SPEC) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Must be spectator!");
    }
    SetPlayerSpecialAction(playerid, SPECIAL_ACTION_USEJETPACK);
    return 1;
}

NCMD:pm(){
    new id, msg[93];
    if(sscanf(params, "us[93]", id, msg)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/pm [id] [text]");
    }
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    if(playerid == id) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Can't PM yourself!");
    }
    SCMF(playerid, COL_INFO, "{FAFA33}PM to {00FFFF}%s (%d){FAFA33}: %s", PlayerName(id), id, msg);
    SCMF(id, COL_INFO, "{FAFA33}PM from {00FFFF}%s (%d){FAFA33}: %s", PlayerName(playerid), playerid, msg);
    g_LastPM[id] = playerid;
    return 1;
}

NCMD:r(){
    new msg[93];
    if(sscanf(params, "s[93]", msg)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/r [text]");
    }
    new t = g_LastPM[playerid];
    if(t == INVALID_PLAYER_ID || !IsPlayerConnected(t)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}No one to reply to!");
    }
    SCMF(playerid, COL_INFO, "{FAFA33}PM to {00FFFF}%s (%d){FAFA33}: %s", PlayerName(t), t, msg);
    SCMF(t, COL_INFO, "{FAFA33}PM from {00FFFF}%s (%d){FAFA33}: %s", PlayerName(playerid), playerid, msg);
    g_LastPM[t] = playerid;
    return 1;
}

NCMD:info(){
    new tid;
    if(sscanf(params, "u", tid)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/info [id]");
    }
    if(!IsPlayerConnected(tid)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    new s[512], n[MAX_PLAYER_NAME];
    GetPlayerName(tid, n, MAX_PLAYER_NAME);
    new tt = g_Time[tid];
    if(tt == 0) tt = 12;
    new tw = GetPVarInt(tid, "Weather");
    if(tw == 0) tw = 10;
    format(s, 512, "{FAFA33}ID: {32CD32}%d\n{FAFA33}Name: {32CD32}%s\n{FAFA33}Admin: {32CD32}%d\n{FAFA33}FPS: {32CD32}%d\n{FAFA33}Ping: {32CD32}%d\n{FAFA33}Skin: {32CD32}%d\n{FAFA33}Kills: {32CD32}%d\n{FAFA33}Deaths: {32CD32}%d\n{FAFA33}K/D: {32CD32}%0.2f\n{FAFA33}Weather: {32CD32}%d\n{FAFA33}Time: {32CD32}%02d:00",
        tid, n, g_Admin[tid], g_FPS[tid], GetPlayerPing(tid), GetPlayerSkin(tid), g_Kills[tid], g_Deaths[tid], GetKD(tid), tw, tt);
    ShowPlayerDialog(playerid, DIALOG_INFO, 0, "Player Info", s, "Close", "");
    return 1;
}

NCMD:stats(){
    return cmd_info(playerid, params, help);
}

NCMD:hitsound(){
    g_HitSound[playerid] = !g_HitSound[playerid];
    if(g_HitSound[playerid]) {
        SCM(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Hit sound {00FFFF}enabled");
    } else {
        SCM(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Hit sound {FF0000}disabled");
    }
    return 1;
}

NCMD:hs(){
    return cmd_hitsound(playerid, params, help);
}

NCMD:credits(){
    SCM(playerid, COL_INFO, "{FAFA33}============= Neikiri's CW/TG Mode =============");
    SCM(playerid, 0x32CD32FF, "{32CD32}Author:  {FFFFFF}neikiri");
    SCM(playerid, 0x32CD32FF, "{32CD32}Discord: {FFFFFF}neikiri69");
    SCM(playerid, COL_INFO, "{FAFA33}============= Neikiri's CW/TG Mode =============");
    return 1;
}

// ===========================================================================
// COMMANDS - Admin Level 1+
// ===========================================================================

NCMD:map(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/map [0-3]");
    }
    new id = strval(params);
    if(id < 0 || id >= MAX_MAPS) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 0-3");
    }
    g_Map = id;
    SCMTAF(COL_RED, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}changed map to {00FFFF}%s", PlayerName(playerid), g_MapNames[id]);
    ForPlayers(i) {
        SpawnPlayer(i);
        SetPlayerHealth(i, 100.0);
    }
    return 1;
}

NCMD:dm(){
    return cmd_map(playerid, params, help);
}

NCMD:weapon(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/weapon [1-46]");
    }
    new id = strval(params);
    if(id < 1 || id > 46) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 1-46");
    }
    g_Weapon = id;
    new wn[60];
    GetWeaponName(id, wn, 60);
    SCMTAF(COL_RED, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}set weapon to {00FFFF}%s", PlayerName(playerid), wn);
    ForPlayers(i) {
        SpawnPlayer(i);
        SetPlayerHealth(i, 100.0);
    }
    return 1;
}

NCMD:cw(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    g_IsCW = 1;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}enabled {00FFFF}CW {32CD32}mode - score counted!", PlayerName(playerid));
    return 1;
}

NCMD:tg(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    g_IsCW = 0;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}enabled {00FFFF}TG {32CD32}mode - training", PlayerName(playerid));
    return 1;
}

NCMD:stop(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    ForPlayers(i) {
        TogglePlayerControllable(i, 0);
    }
    g_Stopped = 1;
    GameTextForAll("~r~STOP", 2000, 5);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}froze all players", PlayerName(playerid));
    return 1;
}

NCMD:start(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    g_Stopped = 0;
    if(g_Countdown > -1) {
        new s[10];
        format(s, 10, "%d", g_Countdown);
        GameTextForAll(s, 1000, 5);
        ForPlayers(i) {
            TogglePlayerControllable(i, 0);
        }
        SetTimer("CountdownTick", 1000, false);
    } else {
        GameTextForAll("~g~START", 2000, 5);
        ForPlayers(i) {
            TogglePlayerControllable(i, 1);
        }
    }
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}started the game", PlayerName(playerid));
    return 1;
}

NCMD:count(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/count [1-30]");
    }
    new sec = strval(params);
    if(sec < 1 || sec > 30) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 1-30");
    }
    StartCountdown(sec);
    return 1;
}

NCMD:freeze(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/freeze [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    TogglePlayerControllable(id, 0);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}froze {00FFFF}%s", PlayerName(playerid), PlayerName(id));
    return 1;
}

NCMD:unfreeze(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/unfreeze [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    TogglePlayerControllable(id, 1);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}unfroze {00FFFF}%s", PlayerName(playerid), PlayerName(id));
    return 1;
}

NCMD:mute(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/mute [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    SetPVarInt(id, "Muted", 1);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}muted {00FFFF}%s", PlayerName(playerid), PlayerName(id));
    return 1;
}

NCMD:unmute(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/unmute [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    DeletePVar(id, "Muted");
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}unmuted {00FFFF}%s", PlayerName(playerid), PlayerName(id));
    return 1;
}

NCMD:kick(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    new id, reason[100];
    if(sscanf(params, "is", id, reason)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/kick [id] [reason]");
    }
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    SCMTAF(-1, "{FAFA33}SERVER: {FF0000}Admin {00FFFF}%s {FF0000}kicked {00FFFF}%s {FFFFFF}[%s]", PlayerName(playerid), PlayerName(id), reason);
    Kick(id);
    return 1;
}

NCMD:spawn(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/spawn [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    SpawnPlayer(id);
    SetPlayerHealth(id, 100.0);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}respawned {00FFFF}%s", PlayerName(playerid), PlayerName(id));
    return 1;
}

NCMD:spawnall(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    ForPlayers(i) {
        if(g_Team[i] != TEAM_SPEC) {
            SpawnPlayer(i);
            SetPlayerHealth(i, 100.0);
        }
    }
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}respawned all players", PlayerName(playerid));
    return 1;
}

NCMD:hp(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/hp [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    SetPlayerHealth(id, 100.0);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}healed {00FFFF}%s", PlayerName(playerid), PlayerName(id));
    return 1;
}

NCMD:hpall(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    ForPlayers(i) {
        SetPlayerHealth(i, 100.0);
    }
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}healed all players", PlayerName(playerid));
    return 1;
}

NCMD:goto(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    new id;
    if(sscanf(params, "i", id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/goto [id]");
    }
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    new Float:x, Float:y, Float:z;
    GetPlayerPos(id, x, y, z);
    SetPlayerPos(playerid, x, y, z);
    SCM(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Teleported to player");
    return 1;
}

NCMD:get(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    new id;
    if(sscanf(params, "i", id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/get [id]");
    }
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    SetPlayerPos(id, x, y, z);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}teleported {00FFFF}%s {32CD32}to themselves", PlayerName(playerid), PlayerName(id));
    return 1;
}

NCMD:movegreen(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/movegreen [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    g_Team[id] = TEAM_GREEN;
    SetPlayerColor(id, COL_GREEN);
    SpawnPlayer(id);
    SetPlayerHealth(id, 100.0);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin moved {00FFFF}%s {32CD32}to {33AA33}%s", PlayerName(id), g_TeamName[0]);
    return 1;
}

NCMD:moveblue(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/moveblue [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    g_Team[id] = TEAM_BLUE;
    SetPlayerColor(id, COL_BLUE);
    SpawnPlayer(id);
    SetPlayerHealth(id, 100.0);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin moved {00FFFF}%s {32CD32}to {2F2FE2}%s", PlayerName(id), g_TeamName[1]);
    return 1;
}

NCMD:movespec(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/movespec [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    g_Team[id] = TEAM_SPEC;
    SetPlayerColor(id, COL_YELLOW);
    SpawnPlayer(id);
    SetPlayerHealth(id, 100.0);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin moved {00FFFF}%s {32CD32}to {FFFF00}Spectator", PlayerName(id));
    return 1;
}

NCMD:setpoints(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    new team, pts;
    if(sscanf(params, "ii", team, pts)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/setpoints [0=green/1=blue] [amount]");
    }
    if(team < 0 || team > 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Team: 0=Green, 1=Blue");
    }
    if(pts < 0 || pts > 100) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 0-100");
    }
    g_TeamScore[team] = pts;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}set {00FFFF}%s {32CD32}score to {00FFFF}%d", PlayerName(playerid), g_TeamName[team], pts);
    UpdateScoreBar();
    return 1;
}

NCMD:pointsgreen(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/pointsgreen [0-100]");
    }
    new p = strval(params);
    if(p < 0 || p > 100) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 0-100");
    }
    g_TeamScore[0] = p;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}set {33AA33}%s {32CD32}score to {00FFFF}%d", PlayerName(playerid), g_TeamName[0], p);
    UpdateScoreBar();
    return 1;
}

NCMD:pointsblue(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/pointsblue [0-100]");
    }
    new p = strval(params);
    if(p < 0 || p > 100) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 0-100");
    }
    g_TeamScore[1] = p;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}set {2F2FE2}%s {32CD32}score to {00FFFF}%d", PlayerName(playerid), g_TeamName[1], p);
    UpdateScoreBar();
    return 1;
}

NCMD:rounds(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/rounds [1-5]");
    }
    new r = strval(params);
    if(r < 1 || r > 5) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 1-5");
    }
    g_MaxRounds = r;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}set rounds to {00FFFF}%d {32CD32}(%dx%d)", PlayerName(playerid), r, g_MaxRounds, g_MaxRoundScore);
    return 1;
}

NCMD:roundscore(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/roundscore [1-100]");
    }
    new r = strval(params);
    if(r < 1 || r > 100) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 1-100");
    }
    g_MaxRoundScore = r;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}set round score to {00FFFF}%d {32CD32}(%dx%d)", PlayerName(playerid), r, g_MaxRounds, g_MaxRoundScore);
    return 1;
}

NCMD:reset(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    g_TeamScore[0] = 0;
    g_TeamScore[1] = 0;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}reset the round score", PlayerName(playerid));
    UpdateScoreBar();
    return 1;
}

NCMD:resetall(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    g_TeamScore[0] = 0;
    g_TeamScore[1] = 0;
    g_TeamRounds[0] = 0;
    g_TeamRounds[1] = 0;
    g_TotalScore[0] = 0;
    g_TotalScore[1] = 0;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}reset all scores", PlayerName(playerid));
    UpdateScoreBar();
    return 1;
}

NCMD:resetstats(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    ForPlayers(i) {
        SetPlayerScore(i, 0);
        g_Kills[i] = 0;
        g_Deaths[i] = 0;
        g_TK[i] = 0;
    }
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}reset all player stats", PlayerName(playerid));
    UpdateScoreBar();
    return 1;
}

NCMD:resetplayer(){
    return cmd_resetstats(playerid, params, help);
}

NCMD:lockteam(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/lockteam [0/1]");
    }
    new v = strval(params);
    if(v < 0 || v > 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}0=unlock, 1=lock");
    }
    g_LockTeams = v;
    if(v) {
        SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}locked the teams", PlayerName(playerid));
    } else {
        SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}unlocked the teams", PlayerName(playerid));
    }
    return 1;
}

NCMD:fps(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/fps [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    SCMF(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}has {00FFFF}%d {32CD32}FPS", PlayerName(id), g_FPS[id]);
    return 1;
}

NCMD:fpsall(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    ForPlayers(i) {
        SCMF(playerid, COL_WHITE, "{FAFA33}INFO: {00FFFF}%s {32CD32}- {00FFFF}%d {32CD32}FPS", PlayerName(i), g_FPS[i]);
    }
    return 1;
}

NCMD:ip(){
    if(g_Admin[playerid] < 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/ip [id]");
    }
    new id = strval(params);
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    new q[256], ip[16];
    GetPlayerIp(id, ip, 16);
    format(q, 256, "SELECT Names FROM users WHERE IP='%s'", ip);
    new DBResult:rr = db_query(g_dbUsers, q);
    if(db_num_rows(rr) > 0) {
        new names[512];
        db_get_field(rr, 0, names, 512);
        SCMF(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}Player {00FFFF}%s {32CD32}nicknames: {00FFFF}%s", PlayerName(id), names);
    } else {
        SCM(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}No data found");
    }
    db_free_result(rr);
    return 1;
}

// ===========================================================================
// COMMANDS - Admin Level 2+
// ===========================================================================

NCMD:teamname(){
    if(g_Admin[playerid] < 2) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level (need 2)!");
    }
    new team, name[50];
    if(sscanf(params, "is", team, name)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/teamname [0/1] [name]");
    }
    if(team < 0 || team > 1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}0=Green, 1=Blue");
    }
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}renamed {00FFFF}%s {32CD32}to {00FFFF}%s", PlayerName(playerid), g_TeamName[team], name);
    format(g_TeamName[team], 50, "%s", name);
    UpdateScoreBar();
    return 1;
}

NCMD:npc(){
    if(g_Admin[playerid] < 2) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level (need 2)!");
    }
    new sub[16], rest[100], pos = strfind(params, " ", true);
    if(pos == -1) {
        strmid(sub, params, 0, strlen(params), sizeof(sub));
        rest[0] = 0;
    } else {
        strmid(sub, params, 0, pos, sizeof(sub));
        strmid(rest, params, pos + 1, strlen(params), sizeof(rest));
    }

    if(!strcmp(sub, "add", true))    return NpcCmdAdd(playerid, rest);
    if(!strcmp(sub, "del", true))    return NpcCmdDel(playerid, rest);
    if(!strcmp(sub, "move", true))   return NpcCmdMove(playerid, rest);
    if(!strcmp(sub, "list", true))   return NpcCmdList(playerid);
    if(!strcmp(sub, "getpos", true)) return NpcCmdGetPos(playerid);

    SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/npc [add | del | move | list | getpos]");
    return 1;
}

stock NpcCmdAdd(playerid, rest[]){
    new name[NPC_NAME_LENGTH], script[NPC_SCRIPT_LENGTH], pos = strfind(rest, " ", true);
    if(pos == -1) {
        strmid(name, rest, 0, strlen(rest), sizeof(name));
        script[0] = 0;
    } else {
        strmid(name, rest, 0, pos, sizeof(name));
        strmid(script, rest, pos + 1, strlen(rest), sizeof(script));
    }
    if(!name[0]) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/npc add [name] [npcmode]");
    }
    if(!script[0]) {
        format(script, NPC_SCRIPT_LENGTH, "idle_npc");
    }
    if(FindNpcByName(name) != -1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}An NPC with this name already exists!");
    }
    new npcIndex = FindFreeNpcSlot();
    if(npcIndex == -1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}No free NPC slots!");
    }
    NpcData[npcIndex][npcUsed] = true;
    format(NpcData[npcIndex][npcName], NPC_NAME_LENGTH, "%s", name);
    format(NpcData[npcIndex][npcScript], NPC_SCRIPT_LENGTH, "%s", script);
    NpcData[npcIndex][npcSkin] = GetPlayerSkin(playerid);
    GetPlayerPos(playerid, NpcData[npcIndex][npcX], NpcData[npcIndex][npcY], NpcData[npcIndex][npcZ]);
    GetPlayerFacingAngle(playerid, NpcData[npcIndex][npcAngle]);
    NpcData[npcIndex][npcWorld] = GetPlayerVirtualWorld(playerid);
    NpcData[npcIndex][npcInterior] = GetPlayerInterior(playerid);
    NpcData[npcIndex][npcPlayerId] = INVALID_PLAYER_ID;
    if(!ConnectNPC(name, script)) {
        NpcData[npcIndex][npcUsed] = false;
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}NPC could not connect (check npc script / samp-npc.exe)!");
    }
    SCMF(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}NPC {00FFFF}%s {32CD32}is connecting...", name);
    return 1;
}

stock NpcCmdDel(playerid, rest[]){
    if(isnull(rest)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/npc del [name]");
    }
    new npcIndex = FindNpcByName(rest);
    if(npcIndex == -1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}NPC not found! Use {00FFFF}/npc list");
    }
    if(NpcData[npcIndex][npcPlayerId] != INVALID_PLAYER_ID) {
        Kick(NpcData[npcIndex][npcPlayerId]);
    }
    NpcData[npcIndex][npcUsed] = false;
    NpcData[npcIndex][npcPlayerId] = INVALID_PLAYER_ID;
    SCM(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}NPC removed");
    return 1;
}

stock NpcCmdMove(playerid, rest[]){
    if(isnull(rest)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/npc move [name]");
    }
    new npcIndex = FindNpcByName(rest);
    if(npcIndex == -1) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}NPC not found! Use {00FFFF}/npc list");
    }
    GetPlayerPos(playerid, NpcData[npcIndex][npcX], NpcData[npcIndex][npcY], NpcData[npcIndex][npcZ]);
    GetPlayerFacingAngle(playerid, NpcData[npcIndex][npcAngle]);
    NpcData[npcIndex][npcWorld] = GetPlayerVirtualWorld(playerid);
    NpcData[npcIndex][npcInterior] = GetPlayerInterior(playerid);
    if(NpcData[npcIndex][npcPlayerId] != INVALID_PLAYER_ID) {
        ApplyNpcSettings(npcIndex);
    }
    SCM(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}NPC moved to your position");
    return 1;
}

stock NpcCmdList(playerid){
    new count;
    SCM(playerid, COL_INFO, "{FAFA33}--- Managed NPCs ---");
    for(new npcIndex = 0; npcIndex < MAX_MANAGED_NPCS; npcIndex++) {
        if(!NpcData[npcIndex][npcUsed]) continue;
        if(NpcData[npcIndex][npcPlayerId] == INVALID_PLAYER_ID) {
            SCMF(playerid, COL_WHITE, "{FAFA33}%s {32CD32}| script: {00FFFF}%s {32CD32}| {FF0000}connecting/offline", NpcData[npcIndex][npcName], NpcData[npcIndex][npcScript]);
        } else {
            SCMF(playerid, COL_WHITE, "{FAFA33}%s {32CD32}| script: {00FFFF}%s {32CD32}| {33AA33}online", NpcData[npcIndex][npcName], NpcData[npcIndex][npcScript]);
        }
        count++;
    }
    if(!count) {
        SCM(playerid, COL_WHITE, "{FAFA33}INFO: {32CD32}No NPCs have been added");
    }
    return 1;
}

stock NpcCmdGetPos(playerid){
    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);
    SCMF(playerid, COL_WHITE, "{FAFA33}X: {00FFFF}%.4f {FAFA33}| Y: {00FFFF}%.4f {FAFA33}| Z: {00FFFF}%.4f {FAFA33}| Angle: {00FFFF}%.4f {FAFA33}| World: {00FFFF}%d {FAFA33}| Interior: {00FFFF}%d", x, y, z, a, GetPlayerVirtualWorld(playerid), GetPlayerInterior(playerid));
    return 1;
}

stock ApplyNpcSettings(npcIndex){
    new npcPid = NpcData[npcIndex][npcPlayerId];
    SetSpawnInfo(npcPid, 0, NpcData[npcIndex][npcSkin], NpcData[npcIndex][npcX], NpcData[npcIndex][npcY], NpcData[npcIndex][npcZ], NpcData[npcIndex][npcAngle], 0, 0, 0, 0, 0, 0);
    SetPlayerSkin(npcPid, NpcData[npcIndex][npcSkin]);
    SetPlayerVirtualWorld(npcPid, NpcData[npcIndex][npcWorld]);
    SetPlayerInterior(npcPid, NpcData[npcIndex][npcInterior]);
    SetPlayerPos(npcPid, NpcData[npcIndex][npcX], NpcData[npcIndex][npcY], NpcData[npcIndex][npcZ]);
    SetPlayerFacingAngle(npcPid, NpcData[npcIndex][npcAngle]);
    return 1;
}

stock FindFreeNpcSlot(){
    for(new npcIndex = 0; npcIndex < MAX_MANAGED_NPCS; npcIndex++) {
        if(!NpcData[npcIndex][npcUsed]) return npcIndex;
    }
    return -1;
}

stock FindNpcByName(const name[]){
    for(new npcIndex = 0; npcIndex < MAX_MANAGED_NPCS; npcIndex++) {
        if(NpcData[npcIndex][npcUsed] && !strcmp(NpcData[npcIndex][npcName], name, true)) return npcIndex;
    }
    return -1;
}

// ===========================================================================
// COMMANDS - Admin Level 3+
// ===========================================================================

NCMD:ban(){
    if(g_Admin[playerid] < 3) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level (need 3)!");
    }
    new id, reason[100];
    if(sscanf(params, "is", id, reason)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/ban [id] [reason]");
    }
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    new query[384], ip[16];
    GetPlayerIp(id, ip, sizeof(ip));
    format(query, sizeof(query), "INSERT INTO bans (Player, IP, Reason, Admin, Permanent, Timestamp) VALUES ('%q', '%q', '%q', '%q', 1, 0)", PlayerName(id), ip, reason, PlayerName(playerid));
    new DBResult:banInsert = db_query(g_dbBans, query);
    db_free_result(banInsert);
    SCMTAF(-1, "{FAFA33}SERVER: {FF0000}Admin {00FFFF}%s {FF0000}banned {00FFFF}%s {FFFFFF}[%s]", PlayerName(playerid), PlayerName(id), reason);
    BanEx(id, reason);
    return 1;
}

NCMD:car(){
    if(g_Admin[playerid] < 3) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level (need 3)!");
    }
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/car [400-611]");
    }
    new id = strval(params);
    if(id < 400 || id > 611) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 400-611");
    }
    if(g_CarCount >= MAX_CARS) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Max cars reached! Use /dcar");
    }
    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);
    g_Cars[g_CarCount] = CreateVehicle(id, x + 5, y + 5, z, a + 90, random(128), random(128), -1);
    g_CarCount++;
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}spawned vehicle {00FFFF}%d {32CD32}(%d/%d)", PlayerName(playerid), id, g_CarCount, MAX_CARS);
    return 1;
}

NCMD:dcar(){
    if(g_Admin[playerid] < 3) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level (need 3)!");
    }
    for(new i = 0; i < g_CarCount; i++) {
        DestroyVehicle(g_Cars[i]);
    }
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}removed all vehicles ({00FFFF}%d{32CD32})", PlayerName(playerid), g_CarCount);
    g_CarCount = 0;
    return 1;
}

NCMD:refreshobj(){
    if(g_Admin[playerid] < 3) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level (need 3)!");
    }
    RefreshObjects();
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}refreshed score objects", PlayerName(playerid));
    return 1;
}

NCMD:refreshobject(){
    return cmd_refreshobj(playerid, params, help);
}

NCMD:lockserver(){
    if(g_Admin[playerid] < 3) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level (need 3)!");
    }
    if(isnull(params) || strlen(params) > 49) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/lockserver [password]");
    }
    format(g_ServerPass, 50, "%s", params);
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}locked the server", PlayerName(playerid));
    return 1;
}

NCMD:unlockserver(){
    if(g_Admin[playerid] < 3) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Insufficient admin level (need 3)!");
    }
    format(g_ServerPass, 50, " ");
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}unlocked the server", PlayerName(playerid));
    return 1;
}

// ===========================================================================
// COMMANDS - Admin Level 5 / RCON
// ===========================================================================

NCMD:setadmin(){
    if(!IsPlayerAdmin(playerid) && g_Admin[playerid] < 5) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Need admin level 5 or RCON!");
    }
    new id, level;
    if(sscanf(params, "ii", id, level)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/setadmin [id] [0-5]");
    }
    if(!IsPlayerConnected(id)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Player offline!");
    }
    if(level < 0 || level > 5) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Range: 0-5");
    }

    g_Admin[id] = level;
    new q[256], ip[16], nm[MAX_PLAYER_NAME];
    GetPlayerName(id, nm, MAX_PLAYER_NAME);
    GetPlayerIp(id, ip, 16);
    if(level > 0) {
        format(q, 256, "INSERT OR REPLACE INTO admins(Player_Name,IP,Admin_Level)VALUES('%s','%s',%d)", nm, ip, level);
        new DBResult:rr = db_query(g_dbAdmin, q);
        db_free_result(rr);
    } else {
        format(q, 256, "DELETE FROM admins WHERE IP='%s'", ip);
        new DBResult:rr = db_query(g_dbAdmin, q);
        db_free_result(rr);
    }
    SCMTAF(-1, "{FAFA33}SERVER: {32CD32}Admin {00FFFF}%s {32CD32}set {00FFFF}%s {32CD32}admin level to {00FFFF}%d", PlayerName(playerid), PlayerName(id), level);
    return 1;
}

// ===========================================================================
// Registration / Login (file-based, compatible with original)
// ===========================================================================

stock num_hash(buf[]){
    new length = strlen(buf), s1 = 1, s2 = 0;
    for(new n = 0; n < length; n++) {
        s1 = (s1 + buf[n]) % 65521;
        s2 = (s2 + s1) % 65521;
    }
    return (s2 << 16) + s1;
}

stock qhash(str2[]){
    new t[128];
    t[0] = 0;
    valstr(t, num_hash(str2));
    return t;
}

stock DelChar(tstring[]){
    new ln = strlen(tstring);
    if(ln >= 2 && tstring[ln - 2] == '\r') tstring[ln - 2] = '\0';
    if(ln >= 1 && tstring[ln - 1] == '\n') tstring[ln - 1] = '\0';
}

NCMD:register(){
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/register [password]");
    }
    if(strlen(params) < 4) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Password must be at least 4 characters!");
    }
    new s[128];
    format(s, 128, "%s.txt", PlayerName(playerid));
    if(fexist(s)) {
        return SCM(playerid, COL_RED, "{FAFA33}INFO: {32CD32}Already registered! Use {00FFFF}/login");
    }
    new File:f = fopen(s, io_write);
    format(s, 128, "%s\r\n0", qhash(params));
    SetPVarString(playerid, "Pass", qhash(params));
    fwrite(f, s);
    fclose(f);
    SetPVarInt(playerid, "Logged", 1);
    SCM(playerid, -1, "{FAFA33}INFO: {32CD32}Registered successfully!");
    return 1;
}

NCMD:login(){
    if(isnull(params)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {FAFA33}Usage: {00FFFF}/login [password]");
    }
    new s[128];
    format(s, 128, "%s.txt", PlayerName(playerid));
    if(!fexist(s)) {
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {32CD32}Not registered! Use {00FFFF}/register");
    }
    new File:f = fopen(s, io_read);
    fread(f, s);
    DelChar(s);
    if(strval(s) != num_hash(params)) {
        fclose(f);
        return SCM(playerid, COL_RED, "{FF0000}ERROR: {32CD32}Wrong password!");
    }
    SetPVarString(playerid, "Pass", s);
    fread(f, s);
    g_Admin[playerid] = strval(s);
    fclose(f);
    SetPVarInt(playerid, "Logged", 1);
    SCMF(playerid, -1, "{FAFA33}INFO: {32CD32}Logged in - Admin level {00FFFF}%d", g_Admin[playerid]);
    return 1;
}

// ===========================================================================
// Command processor
// ===========================================================================

public OnPlayerCommandText(playerid,cmdtext[]){
    return ProcessCommand(playerid,cmdtext);
}

stock ProcessCommand(playerid,command[]){
    new cmd[50], callback[55], params[128], size = 0, len = strlen(command);
    new start = 0;

    if(command[0] == '/') start = 1;

    for(new i = start; i < len; i++){
        if(command[i] == ' '){
            size = i;
            break;
        }
        if(command[i] >= 'A' && command[i] <= 'Z') command[i] += 32;
    }

    if(size > 0){
        strmid(cmd, command, start, size, sizeof(cmd));
        strmid(params, command, size + 1, len, sizeof(params));
    }else{
        strmid(cmd, command, start, len, sizeof(cmd));
        params = " ";
    }

    if(!params[0]) params = " ";
    new bool:h = !strcmp(params, "help");
    format(callback, sizeof(callback), "cmd_%s", cmd);
    if(CallLocalFunction(callback, "isi", playerid, params, h)) return true;
    return false;
}

// ===========================================================================
// sscanf (built-in, no plugin needed)
// ===========================================================================

stock sscanf(string[],format[],{Float,_}:...){
    #if defined isnull
        if(isnull(string))
    #else
        if(string[0]==0||(string[0]==1&&string[1]==0))
    #endif
        {return format[0];}
    #pragma tabsize 4
    new formatPos=0,stringPos=0,paramPos=2,paramCount=numargs(),delim=' ';
    while(string[stringPos]&&string[stringPos]<=' ')stringPos++;
    while(paramPos<paramCount&&string[stringPos]){
        switch(format[formatPos++]){
            case '\0':return 0;
            case 'i','d':{
                new neg=1,num=0,ch=string[stringPos];
                if(ch=='-'){neg=-1;ch=string[++stringPos];}
                do{stringPos++;if('0'<=ch<='9')num=(num*10)+(ch-'0');else return -1;}
                while((ch=string[stringPos])>' '&&ch!=delim);
                setarg(paramPos,0,num*neg);
            }
            case 'h','x':{
                new num=0,ch=string[stringPos];
                do{
                    stringPos++;
                    switch(ch){
                        case 'x','X':{num=0;continue;}
                        case '0'..'9':{num=(num<<4)|(ch-'0');}
                        case 'a'..'f':{num=(num<<4)|(ch-('a'-10));}
                        case 'A'..'F':{num=(num<<4)|(ch-('A'-10));}
                        default:return -1;
                    }
                }
                while((ch=string[stringPos])>' '&&ch!=delim);setarg(paramPos,0,num);
            }
            case 'c':setarg(paramPos,0,string[stringPos++]);
            case 'f':{new cs[16],cp=0,sp=stringPos;while(cp<16&&string[sp]&&string[sp]!=delim)cs[cp++]=string[sp++];cs[cp]='\0';setarg(paramPos,0,_:floatstr(cs));}
            case 'p':{delim=format[formatPos++];continue;}
            case '\'':{
                new end=formatPos-1,ch;while((ch=format[++end])&&ch!='\''){}if(!ch)return -1;
                format[end]='\0';if((ch=strfind(string,format[formatPos],false,stringPos))==-1){if(format[end+1])return -1;return 0;}
                format[end]='\'';stringPos=ch+(end-formatPos);formatPos=end+1;
            }
            case 'u':{
                new end=stringPos-1,id=0,bool:num=true,ch;
                while((ch=string[++end])&&ch!=delim){if(num){if('0'<=ch<='9')id=(id*10)+(ch-'0');else num=false;}}
                if(num&&IsPlayerConnected(id))setarg(paramPos,0,id);
                else{
                    #if !defined foreach
                        #define foreach(%1,%2) for(new %2=0;%2<MAX_PLAYERS;%2++)if(IsPlayerConnected(%2))
                        #define __SSCANF_FOREACH__
                    #endif
                    string[end]='\0';num=false;new name[MAX_PLAYER_NAME];id=end-stringPos;
                    foreach(Player,playerid){GetPlayerName(playerid,name,sizeof(name));if(!strcmp(name,string[stringPos],true,id)){setarg(paramPos,0,playerid);num=true;break;}}
                    if(!num)setarg(paramPos,0,INVALID_PLAYER_ID);string[end]=ch;
                    #if defined __SSCANF_FOREACH__
                        #undef foreach
                        #undef __SSCANF_FOREACH__
                    #endif
                }
                stringPos=end;
            }
            case 's','z':{
                new i=0,ch;
                if(format[formatPos]){while((ch=string[stringPos++])&&ch!=delim)setarg(paramPos,i++,ch);if(!i)return -1;}
                else{while((ch=string[stringPos++]))setarg(paramPos,i++,ch);}
                stringPos--;setarg(paramPos,i,'\0');
            }
            default:continue;
        }
        while(string[stringPos]&&string[stringPos]!=delim&&string[stringPos]>' ')stringPos++;
        while(string[stringPos]&&(string[stringPos]==delim||string[stringPos]<=' '))stringPos++;
        paramPos++;
    }
    do{if((delim=format[formatPos++])>' '){if(delim=='\''){while((delim=format[formatPos++])&&delim!='\''){}}else if(delim!='z')return delim;}}while(delim>' ');
    return 0;
}
