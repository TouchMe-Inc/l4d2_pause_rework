#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <pause_rework>
#include <colors>



public Plugin myinfo =
{
	name = "[Pause] HeaderServername",
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
	g_cvServerNamer
;

int g_iThisIndex = -1;

bool g_bPauseAvailable = false;


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded()
{
	g_bPauseAvailable = LibraryExists(LIB_PAUSE);

	if (g_bPauseAvailable) {
		g_iThisIndex = PushPauseItem(PausePanelPos_Header, "OnPreparePauseItem");
	}
}

/**
  * Global event. Called when a library is removed.
  *
  * @param sName     Library name
  */
public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, LIB_PAUSE)) {
		g_bPauseAvailable = false;
	}
}

/**
  * Global event. Called when a library is added.
  *
  * @param sName     Library name
  */
public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, LIB_PAUSE)) {
		g_bPauseAvailable = true;
	}
}

public void OnPluginStart()
{
	g_cvServerNameCvar	= CreateConVar("sm_ph_servername_cvar", "", "blank = hostname");

	g_cvServerNamer = FindServerNameConVar();

	HookConVarChange(g_cvServerNameCvar, OnServerCvarChanged);
}

/**
 *
 */
public Action OnPreparePauseItem(PausePanelPos ePos, int iClient, int iIndex)
{
	if (!g_bPauseAvailable || ePos != PausePanelPos_Header || g_iThisIndex != iIndex) {
		return Plugin_Continue;
	}

	char buffer[64]; GetConVarString(g_cvServerNamer, buffer, sizeof(buffer));
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