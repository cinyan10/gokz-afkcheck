#include <sourcemod>
#include <sdktools>
#include <gokz>
#include <gokz/core>
#include <GlobalAPI>
#include <autoexecconfig>

#pragma newdecls required
#pragma semicolon 1

char gC_CurrentMap[64];
int gI_MapTier;

ConVar gokz_afk_kick_time_spec_bool;
ConVar gokz_afk_kick_time_spec;
ConVar gokz_afk_kick_time_bool;
ConVar gokz_afk_kick_time;
ConVar gokz_afk_kick_time_start_bool;
ConVar gokz_afk_kick_time_start;
ConVar gokz_afk_kick_pause_is_afk;
ConVar gokz_afk_kick_tier_level_max;
ConVar gokz_afk_check_eyeangle;
ConVar gokz_afk_kick_admins;

enum struct PlayerAfkData
{
    float last_loc[3];
    float last_angle[3];
    int afk_time;

    void Reset()
    {
        this.last_loc = NULL_VECTOR;
        this.last_angle = NULL_VECTOR;
        this.afk_time = 0;
    }
}

PlayerAfkData pdata[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "GOKZ Afk Check Plugin",
    author = "LynchMus && Cinyan10)",
    description = "AFK Check Plugin via GlobalAPI",
    version = "1.1",
    url = "https://github.com/cinyan10/gokz-afkcheck"
};

public void OnPluginStart()
{
    if (FloatAbs(1.0 / GetTickInterval() - 128.0) > EPSILON)
    {
        SetFailState("gokz-afkcheck currently only supports 128 tickrate servers.");
    }
    if (FindCommandLineParam("-insecure") || FindCommandLineParam("-tools"))
    {
        SetFailState("gokz-afkcheck currently only supports VAC-secured servers.");
    }
    LoadTranslations("gokz-common.phrases");

    gI_MapTier = -1;

    CreateConVars();

    HookEventEx("player_team", EventPlayerTeam, EventHookMode_Pre);
}

public void OnAllPluginsLoaded()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            OnClientPutInServer(client);
        }
    }
}

public void OnClientPutInServer(int client)
{
    pdata[client].Reset();
}

public void OnClientDisconnect(int client)
{
    pdata[client].Reset();
}

public void GlobalAPI_OnInitialized()
{
    SetupAPI();
}

public Action EventPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    pdata[client].Reset();
    return Plugin_Continue;
}

public void OnMapStart()
{
    ServerCommand("mp_autokick 0");

    for (int client = 1; client <= MaxClients; client++)
    {
        pdata[client].Reset();
    }

    GetCurrentMapDisplayName(gC_CurrentMap, sizeof(gC_CurrentMap));

    if (GlobalAPI_IsInit())
    {
        GlobalAPI_OnInitialized();
    }

    CreateTimer(1.0, PlayerChecks, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action PlayerChecks(Handle timer)
{

    for (int client = 1; client <= MaxClients; client++)
    {        
        if (IsValidClient(client) && !IsFakeClient(client))
        {
            if (IsClientAdmin(client) && !gokz_afk_kick_admins.BoolValue)
                continue;
            
            // re check here
            if (gI_MapTier >= gokz_afk_kick_tier_level_max.IntValue && GOKZ_GetTimerRunning(client) && GOKZ_GetTime(client) > gokz_afk_kick_time_start.FloatValue)
                continue;

            if ((GetClientTeam(client) == CS_TEAM_NONE || GetClientTeam(client) == CS_TEAM_SPECTATOR) && gokz_afk_kick_time_spec_bool.BoolValue)
            {
                pdata[client].afk_time++;
                int timeLeft = gokz_afk_kick_time_spec.IntValue - pdata[client].afk_time;

                if (timeLeft == 300 || timeLeft == 60 || timeLeft == 15)
                {
                    GOKZ_PrintToChat(client, true, "{default}You will be kicked in {darkred}%ds {default}due to being AFK.", timeLeft);
                    GOKZ_PlayErrorSound(client);
                }
                else if (pdata[client].afk_time >= gokz_afk_kick_time_spec.IntValue)
                {
                    KickClient(client, "Kicked for being AFK too long.");
                    continue;
                }
            }

            if (IsPlayerAlive(client) && !(GetEntityFlags(client) & FL_FROZEN) && (GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(client) == CS_TEAM_T))
            {
                if (!gokz_afk_kick_pause_is_afk.BoolValue && GOKZ_GetPaused(client))
                {
                    pdata[client].afk_time = 0;
                    continue;
                }

                float origin[3];
                GetClientAbsOrigin(client, origin);
                float eyeAngles[3];
                GetClientEyeAngles(client, eyeAngles);

                if (origin[0] == pdata[client].last_loc[0] && origin[1] == pdata[client].last_loc[1] && (!gokz_afk_check_eyeangle.BoolValue || (eyeAngles[0] == pdata[client].last_angle[0] && eyeAngles[1] == pdata[client].last_angle[1])))
                {
                    pdata[client].afk_time++;
                }
                else
                {
                    pdata[client].afk_time = 0;
                }

                pdata[client].last_loc = origin;
                pdata[client].last_angle = eyeAngles;

                if (gokz_afk_kick_time_bool.BoolValue)
                {
                    if (!GOKZ_GetTimerRunning(client) || (gokz_afk_kick_time_start_bool.BoolValue && GOKZ_GetTime(client) < gokz_afk_kick_time_start.FloatValue))
                    {
                        int timeLeft = gokz_afk_kick_time.IntValue - pdata[client].afk_time;

                        if (timeLeft == 300 || timeLeft == 60 || timeLeft == 15)
                        {
                            GOKZ_PrintToChat(client, true, "{default}You will be kicked in {darkred}%ds {default}due to being AFK.", timeLeft);
                            GOKZ_PlayErrorSound(client);
                        }
                        else if (pdata[client].afk_time > gokz_afk_kick_time.IntValue)
                        {
                            KickClient(client, "Kicked for being AFK too long.");
                            continue;
                        }
                    }
                }
            }
        }
    }

    return Plugin_Continue;
}

public void OnMapEnd()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        pdata[client].Reset();
    }
}

static void CreateConVars()
{
    AutoExecConfig_SetFile("gokz-afkcheck", "sourcemod/gokz");
    AutoExecConfig_SetCreateFile(true);

    gokz_afk_kick_time_spec_bool = AutoExecConfig_CreateConVar("gokz_afk_kick_time_spec_bool", "1", "Kick spectators for being AFK.", _, true, 0.0, true, 1.0);
    gokz_afk_kick_time_spec = AutoExecConfig_CreateConVar("gokz_afk_kick_time_spec", "900", "Kick spectators after this many seconds AFK.", _, true, 60.0);
    gokz_afk_kick_time_bool = AutoExecConfig_CreateConVar("gokz_afk_kick_time_bool", "1", "Kick players for being AFK.", _, true, 0.0, true, 1.0);
    gokz_afk_kick_time = AutoExecConfig_CreateConVar("gokz_afk_kick_time", "900", "Kick players after this many seconds AFK.", _, true, 60.0);
    gokz_afk_kick_time_start_bool = AutoExecConfig_CreateConVar("gokz_afk_kick_time_start_bool", "1", "Enable kicking players shortly after timer start.", _, true, 0.0, true, 1.0);
    gokz_afk_kick_time_start = AutoExecConfig_CreateConVar("gokz_afk_kick_time_start", "900", "If timer is running and under this time, allow AFK kick.", _, true, 60.0);
    gokz_afk_kick_pause_is_afk = AutoExecConfig_CreateConVar("gokz_afk_kick_pause_is_afk", "1", "Whether paused counts as AFK.", _, true, 0.0, true, 1.0);
    gokz_afk_kick_tier_level_max = AutoExecConfig_CreateConVar("gokz_afk_kick_tier_level_max", "5", "Don’t kick on maps of this tier or higher.", _, true, 1.0, true, 7.0);
    gokz_afk_check_eyeangle = AutoExecConfig_CreateConVar("gokz_afk_check_eyeangle", "1", "Check player view angles for AFK detection.", _, true, 0.0, true, 1.0);
    gokz_afk_kick_admins = AutoExecConfig_CreateConVar("gokz_afk_kick_admins", "1", "Kick admins when AFK (0 = no, 1 = yes).", _, true, 0.0, true, 1.0);

    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

static void SetupAPI()
{
    GlobalAPI_GetMapByName(GetMapCallback, _, gC_CurrentMap);
}

public int GetMapCallback(JSON_Object map_json, GlobalAPIRequestData request)
{
    if (request.Failure || map_json == INVALID_HANDLE)
    {
        LogError("Failed to get map info.");
        return 0;
    }

    APIMap map = view_as<APIMap>(map_json);
    gI_MapTier = map.Difficulty;

    return 0;
}

stock bool IsClientAdmin(int client)
{
    return GetUserFlagBits(client) != 0;
}
