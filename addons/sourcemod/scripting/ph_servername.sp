#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <pause_rework>
#include <colors>



public Plugin myinfo =
{
    name = "[PauseHeader] Servername",
    author = "TouchMe",
    description = "Adds the server name to the top of Pause",
    version = "build0001",
    url = "https://github.com/TouchMe-Inc/l4d2_pause_rework"
};


/*
 * Libs.
 */
#define LIB_PAUSE               "pause_rework"


ConVar
    g_cvServerNameCvar,
    g_cvServerNamer,
    g_cvMaxPlayers
;

int g_iThisIndex = -1;


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded()
{
    if (LibraryExists(LIB_PAUSE)) {
        g_iThisIndex = PushPauseItem(PausePanelPos_Header, "OnPreparePauseItem");
    }
}

public void OnPluginStart()
{
    g_cvServerNameCvar	= CreateConVar("sm_ph_servername_cvar", "", "blank = hostname");

    g_cvServerNamer = FindServerNameConVar();

    HookConVarChange(g_cvServerNameCvar, OnServerCvarChanged);

    g_cvMaxPlayers = FindConVar("sv_maxplayers");
}

/**
 *
 */
public Action OnPreparePauseItem(PausePanelPos ePos, int iClient, int iIndex)
{
    if (ePos != PausePanelPos_Header || g_iThisIndex != iIndex) {
        return Plugin_Continue;
    }

    char buffer[64]; GetConVarString(g_cvServerNamer, buffer, sizeof(buffer));

    int iMaxPlayers = GetConVarInt(g_cvMaxPlayers);

    if (iMaxPlayers != -1) {
        Format(buffer, sizeof buffer, "%s [%d/%d]", buffer, GetClientConnectedCount(), iMaxPlayers);
    }

    UpdatePauseItem(ePos, iIndex, buffer);

    return Plugin_Stop;
}

/**
 *
 */
void OnServerCvarChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue) {
    g_cvServerNamer = FindServerNameConVar();
}

/**
 *
 */
ConVar FindServerNameConVar()
{
    char buffer[64]; GetConVarString(g_cvServerNameCvar, buffer, sizeof(buffer));
    ConVar cvServerName = FindConVar(buffer);

    if (FindConVar(buffer) == null) {
        return FindConVar("hostname");
    }

    return cvServerName;
}

int GetClientConnectedCount()
{
    int iCount = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && !IsFakeClient(i)) {
            iCount++;
        }
    }

    return iCount;
}