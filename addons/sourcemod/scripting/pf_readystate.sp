#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <pause_rework>
#include <colors>


public Plugin myinfo = {
    name        = "[Pause] PauseFooter.ReadyState",
    author      = "TouchMe",
    description = "",
    version     = "build0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_pause_rework"
}


#define LIB_PAUSE               "pause_rework"

#define TRANSLATIONS            "pf_readystate.phrases"


int g_iThisIndex = -1;


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded()
{
    if (LibraryExists(LIB_PAUSE)) {
        g_iThisIndex = PushPauseItem(PausePanelPos_Footer, "OnPreparePauseItem");
    }
}

public void OnPluginStart() {
    LoadTranslations(TRANSLATIONS);
}

public Action OnPreparePauseItem(PausePanelPos ePos, int iClient, int iIndex)
{
    if (ePos != PausePanelPos_Footer || g_iThisIndex != iIndex) {
        return Plugin_Continue;
    }

    if (GetPauseMode() != PauseMode_PlayerReady && GetPauseMode() != PauseMode_TeamReady) {
        return Plugin_Continue;
    }

    if (GetPauseState() == PauseState_None) {
        return Plugin_Continue;
    }

    // TODO
    // UpdatePauseItem(ePos, iIndex, "%T", IsClientReady(iClient) ? "MARK_UNREADY" : "MARK_READY", iClient);

    return Plugin_Stop;
}
