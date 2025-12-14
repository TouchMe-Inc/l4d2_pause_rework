#include <sourcemod>
#include <sdktools>
#include <nativevotes_rework>
#include <colors>

#undef REQUIRE_PLUGIN
#include <readyup_rework>
#define REQUIRE_PLUGIN


public Plugin myinfo = {
    name        = "PauseRework",
    author      = "CanadaRox, TouchMe",
    description = "",
    version     = "build0002",
    url         = "https://github.com/TouchMe-Inc/l4d2_pause_rework"
};


/**
 *
 */
#define TRANSLATION             "pause_rework.phrases"

/**
 * Teams.
 */
#define TEAM_NONE               0
#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

/**
 * Libs.
 */
#define LIB_READYUP             "readyup_rework"

/**
 * Native error messages.
 */
#define ERROR_INDEX_OUT_BOUND  "Array index out bound"


enum PauseMode
{
    PauseMode_PlayerReady = 0,
    PauseMode_TeamReady
}

enum PauseState
{
    PauseState_None = 0,
    PauseState_Active,
    PauseState_Countdown
}

enum PausePanelPos
{
    PausePanelPos_Header = 0,
    PausePanelPos_Footer
}

GlobalForward g_fwdOnChangePauseState = null;
GlobalForward g_fwdOnPreparePauseItem = null;
GlobalForward g_fwdOnRemovePauseItem = null;

ConVar
    g_cvPausable = null,
    g_cvNoclipDuringPause = null,

    g_cvPauseMode = null,
    g_cvPauseDelay = null,
    g_cvPauseLimit = null,

    g_cvSpamCooldownInitial = null,
    g_cvSpamCooldownIncrement = null,
    g_cvMaxAttemptsBeforeIncrement = null
;

PauseMode g_ePauseMode = PauseMode_PlayerReady;

PauseState g_ePauseState = PauseState_None;

Handle
    g_hPanelHeader = null,
    g_hPanelFooter = null
;

int g_iPauseDelay = 0;
int g_iPauseLimit = 0;
float g_fSpamCooldownInitial = 0.0;
float g_fSpamCooldownIncrement = 0.0;
int g_iMaxAttempts = 0;

int g_iCountdownTimer = 0;

float g_fClientCommandSpamCooldown[MAXPLAYERS + 1];
int g_iClientCommandSpamAttempts[MAXPLAYERS + 1];

bool g_bClientWantUnpause[MAXPLAYERS + 1];

int g_iTeamLimit[2] = {0, ...};

bool g_bReadyUpAvailable = false;


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded() {
    g_bReadyUpAvailable = LibraryExists(LIB_READYUP);
}

/**
  * Global event. Called when a library is removed.
  *
  * @param sName     Library name
  */
public void OnLibraryRemoved(const char[] sName)
{
    if (StrEqual(sName, LIB_READYUP)) {
        g_bReadyUpAvailable = false;
    }
}

/**
  * Global event. Called when a library is added.
  *
  * @param sName     Library name
  */
public void OnLibraryAdded(const char[] sName)
{
    if (StrEqual(sName, LIB_READYUP)) {
        g_bReadyUpAvailable = true;
    }
}

/**
 * Called before OnPluginStart.
 *
 * @param myself            Handle to the plugin.
 * @param late              Whether or not the plugin was loaded "late" (after map load).
 * @param error             Error message buffer in case load failed.
 * @param err_max           Maximum number of characters for error message buffer.
 * @return                  APLRes_Success | APLRes_SilentFailure.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    /*
     * Natives.
     */
    CreateNative("GetPauseState", Native_GetPauseState);
    CreateNative("GetPauseMode", Native_GetPauseMode);
    CreateNative("PushPauseItem", Native_PushPauseItem);
    CreateNative("UpdatePauseItem", Native_UpdatePauseItem);
    CreateNative("RemovePauseItem", Native_RemovePauseItem);

    /*
     * Forwards.
     */
    g_fwdOnChangePauseState = CreateGlobalForward("OnChangePauseState", ET_Ignore, Param_Cell, Param_Cell);
    g_fwdOnPreparePauseItem = CreateGlobalForward("OnPreparePauseItem", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
    g_fwdOnRemovePauseItem  = CreateGlobalForward("OnRemovePauseItem", ET_Ignore, Param_Cell, Param_Cell);

    /*
     * Library.
     */
    RegPluginLibrary("pause_rework");

    return APLRes_Success;
}

any Native_GetPauseState(Handle hPlugin, int iParams) {
    return g_ePauseState;
}

any Native_GetPauseMode(Handle hPlugin, int iParams) {
    return g_ePauseMode;
}

any Native_PushPauseItem(Handle hPlugin, int iParams)
{
    PausePanelPos ePos = GetNativeCell(1);

    Handle hItems = (ePos == PausePanelPos_Header) ? g_hPanelHeader : g_hPanelFooter;

    char szBuffer[64]; FormatNativeString(0, 2, 3, sizeof(szBuffer), _, szBuffer);

    return PushArrayString(hItems, szBuffer);
}

any Native_UpdatePauseItem(Handle hPlugin, int iParams)
{
    PausePanelPos ePos = GetNativeCell(1);

    Handle hItems = (ePos == PausePanelPos_Header) ? g_hPanelHeader : g_hPanelFooter;

    int iTargetIndex = GetNativeCell(2);

    int iItemCount = GetArraySize(hItems);

    if (iTargetIndex >= iItemCount) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INDEX_OUT_BOUND);
    }

    char szBuffer[64]; FormatNativeString(0, 3, 4, sizeof(szBuffer), _, szBuffer);

    SetArrayString(hItems, iTargetIndex, szBuffer);

    return 0;
}

any Native_RemovePauseItem(Handle hPlugin, int iParams)
{
    PausePanelPos ePos = GetNativeCell(1);

    Handle hItems = (ePos == PausePanelPos_Header) ? g_hPanelHeader : g_hPanelFooter;

    int iTargetIndex = GetNativeCell(2);

    int iItemCount = GetArraySize(hItems);

    if (iTargetIndex >= iItemCount) {
        return ThrowNativeError(SP_ERROR_NATIVE, ERROR_INDEX_OUT_BOUND);
    }

    for (int iIndex = iTargetIndex + 1; iIndex < iItemCount; iIndex ++)
    {
        ExecuteForward_OnRemovePauseItem(ePos, iIndex, iIndex - 1);
    }

    RemoveFromArray(hItems, iTargetIndex);

    return 0;
}

public void OnPluginStart()
{
    LoadTranslations(TRANSLATION);

    /*
     * Find and Create ConVars.
     */
    g_cvPausable = FindConVar("sv_pausable");
    g_cvNoclipDuringPause = FindConVar("sv_noclipduringpause");

    g_cvPauseMode = CreateConVar("sm_pause_mode", "0", "Plugin operating mode (Values: 0 = Player ready, 1 = Team ready)", _, true, 0.0, true, 1.0);
    g_cvPauseDelay = CreateConVar("sm_pause_delay", "3", "Number of seconds to count down before the round goes live", _, true, 0.0);
    g_cvPauseLimit = CreateConVar("sm_pause_limit", "4", "Limits the amount of pauses in a single map. Set to 0 to disable.", _, true, 0.0);

    g_cvSpamCooldownInitial = CreateConVar("sm_pause_spam_cd_init", "2.0", "Initial cooldown time in seconds", _, true, 0.0);
    g_cvSpamCooldownIncrement = CreateConVar("sm_pause_spam_cd_inc", "1.0", "Cooldown increment time in seconds", _, true,  0.0);
    g_cvMaxAttemptsBeforeIncrement = CreateConVar("sm_pause_spam_attempts_before_inc", "2", "Maximum number of attempts before increasing cooldown", _, true, 10.0);


    /*
     * Register ConVar change callbacks.
     */
    HookConVarChange(g_cvPauseMode, OnPauseModeChanged);
    HookConVarChange(g_cvPauseDelay, OnPauseDelayChanged);
    HookConVarChange(g_cvPauseLimit, OnPauseLimitChanged);

    HookConVarChange(g_cvSpamCooldownInitial, OnInitialSpamCooldownChanged);
    HookConVarChange(g_cvSpamCooldownIncrement, OnSpamCooldownIncrementChanged);
    HookConVarChange(g_cvMaxAttemptsBeforeIncrement, OnMaxAttemptsBeforeIncementChanged);

    /*
     * Initialize variables with ConVar values.
     */
    g_ePauseMode = view_as<PauseMode>(GetConVarInt(g_cvPauseMode));
    g_iPauseDelay = GetConVarInt(g_cvPauseDelay);
    g_iPauseLimit = GetConVarInt(g_cvPauseLimit);

    g_fSpamCooldownInitial = GetConVarFloat(g_cvSpamCooldownInitial);
    g_fSpamCooldownIncrement = GetConVarFloat(g_cvSpamCooldownIncrement);
    g_iMaxAttempts = GetConVarInt(g_cvMaxAttemptsBeforeIncrement);

    /*
     * Player Commands.
     */
    RegConsoleCmd("sm_pause", Cmd_Pause);
    RegConsoleCmd("sm_ready", Cmd_Ready);
    RegConsoleCmd("sm_r", Cmd_Ready);
    RegConsoleCmd("sm_unready", Cmd_Unready);
    RegConsoleCmd("sm_nr", Cmd_Unready);

    AddCommandListener(Vote_Callback, "Vote"); // Hook vote <KEY_F1> or <KEY_F2>.
    AddCommandListener(ConCmd_Pause, "pause");
    AddCommandListener(ConCmd_Pause, "setpause");
    AddCommandListener(ConCmd_Pause, "unpause");

    /*
     * Init hud arrays.
     */
    g_hPanelHeader = CreateArray(ByteCountToCells(64));
    g_hPanelFooter = CreateArray(ByteCountToCells(64));
}

/**
 *
 */
void OnPauseModeChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue) {
    g_ePauseMode = view_as<PauseMode>(GetConVarInt(convar));
}

/**
 *
 */
void OnPauseDelayChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue) {
    g_iPauseDelay = GetConVarInt(convar);
}

/**
 *
 */
void OnPauseLimitChanged(ConVar convar, const char[] sOldValue, const char[] sNewValue) {
    g_iPauseLimit = GetConVarInt(convar);
}

/**
 *
 */
void OnInitialSpamCooldownChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    g_fSpamCooldownInitial = GetConVarFloat(convar);
}

/**
 *
 */
void OnSpamCooldownIncrementChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    g_fSpamCooldownIncrement = GetConVarFloat(convar);
}

/**
 *
 */
void OnMaxAttemptsBeforeIncementChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    g_iMaxAttempts = GetConVarInt(convar);
}

public OnMapStart() {
    g_iTeamLimit[0] = g_iTeamLimit[1] = 0;
}

public Action Cmd_Pause(int iClient, int args)
{
    if (!IsPauseState(PauseState_None)) {
        return Plugin_Continue;
    }

    if (IsReadyupStateInProgress()) {
        return Plugin_Continue;
    }

    if (!iClient || !IsClientInGame(iClient)) {
        return Plugin_Continue;
    }

    int iTeam = GetClientTeam(iClient);

    if (!IsValidTeam(iTeam)) {
        return Plugin_Handled;
    }

    int iSpamCommand = IsClientSpamCommand(iClient);

    if (iSpamCommand == 0)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND", iClient, GetClientCommandSpamCooldown(iClient));
        return Plugin_Handled;
    }

    else if (iSpamCommand == 1)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND_WITH_INC", iClient, GetClientCommandSpamCooldown(iClient), g_fSpamCooldownIncrement);
        return Plugin_Handled;
    }

    if (g_iPauseLimit > 0
    && ++ g_iTeamLimit[InSecondHalfOfRound() == (iTeam == TEAM_INFECTED) ? 0 : 1] > g_iPauseLimit)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "PAUSE_LIMIT", iClient, g_iPauseLimit);
        return Plugin_Handled;
    }

    char szPlayerName[32];
    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        g_bClientWantUnpause[iPlayer] = false;

        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)) {
            continue;
        }

        GetClientNameFixed(iClient, szPlayerName, sizeof(szPlayerName), 18);

        CPrintToChatEx(iPlayer, iClient, "%T%T", "TAG", iPlayer, "PAUSE", iPlayer, szPlayerName);
    }

    SetPauseState(PauseState_Active);

    SetGlobalPause(iClient, true);

    // Show panel.
    CreateTimer(1.0, Timer_UpdatePanel, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

    return Plugin_Handled;
}

/**
 *
 */
Action Timer_UpdatePanel(Handle timer)
{
    if (IsPauseState(PauseState_None)) {
        return Plugin_Stop;
    }

    if (NativeVotes_IsVoteInProgress()) {
        return Plugin_Continue;
    }

    for (int iClient = 1; iClient <= MaxClients; iClient ++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
            continue;
        }

        switch (GetClientMenu(iClient)) {
            case MenuSource_External, MenuSource_Normal: continue;
        }

        Panel hPanel = BuildPanel(iClient);

        SendPanelToClient(hPanel, iClient, DummyHandler, 1);

        CloseHandle(hPanel);
    }

    return Plugin_Continue;
}

/**
 *
 */
Action Cmd_Ready(int iClient, int iArgs)
{
    if (IsPauseState(PauseState_None)) {
        return Plugin_Continue;
    }

    if (IsReadyupStateInProgress()) {
        return Plugin_Continue;
    }

    if (!iClient || !IsClientInGame(iClient)) {
        return Plugin_Continue;
    }

    int iTeam = GetClientTeam(iClient);

    if (!IsValidTeam(iTeam)) {
        return Plugin_Handled;
    }

    if (IsClientWantUnpause(iClient)) {
        return Plugin_Handled;
    }

    int iSpamCommand = IsClientSpamCommand(iClient);

    if (iSpamCommand == 0)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND", iClient, GetClientCommandSpamCooldown(iClient));
        return Plugin_Handled;
    }

    else if (iSpamCommand == 1)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND_WITH_INC", iClient, GetClientCommandSpamCooldown(iClient), g_fSpamCooldownIncrement);
        return Plugin_Handled;
    }

    if (IsPauseMode(PauseMode_PlayerReady)) {
        SetTeamWantUnpause(iTeam, true);
    } else {
        SetClientWantUnpause(iClient, true);
    }

    if (IsGameReady())
    {
        SetPauseState(PauseState_Countdown);

        g_iCountdownTimer = g_iPauseDelay;
        CreateTimer(1.0, Timer_Countdown, .flags = TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    }

    return Plugin_Handled;
}

/**
 *
 */
Action Timer_Countdown(Handle timer)
{
    if (!IsPauseState(PauseState_Countdown)) {
        return Plugin_Stop;
    }

    if (g_iCountdownTimer <= 0)
    {
        SetPauseState(PauseState_None);

        SetGlobalPause(GetRandomClient(), false);

        return Plugin_Stop;
    }

    CPrintToChatAll("%t%t", "TAG", "COUNTDOWN", g_iCountdownTimer);

    g_iCountdownTimer--

    return Plugin_Continue;
}

/**
 *
 */
Action Cmd_Unready(int iClient, int iArgs)
{
    if (IsPauseState(PauseState_None)) {
        return Plugin_Continue;
    }

    if (IsReadyupStateInProgress()) {
        return Plugin_Continue;
    }

    if (!iClient || !IsClientInGame(iClient)) {
        return Plugin_Continue;
    }

    int iTeam = GetClientTeam(iClient);

    if (!IsValidTeam(iTeam)) {
        return Plugin_Handled;
    }

    if (!IsClientWantUnpause(iClient)) {
        return Plugin_Handled;
    }

    int iSpamCommand = IsClientSpamCommand(iClient);

    if (iSpamCommand == 0)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND", iClient, GetClientCommandSpamCooldown(iClient));
        return Plugin_Handled;
    }

    else if (iSpamCommand == 1)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "STOP_SPAM_COMMAND_WITH_INC", iClient, GetClientCommandSpamCooldown(iClient), g_fSpamCooldownIncrement);
        return Plugin_Handled;
    }

    if (IsPauseMode(PauseMode_PlayerReady)) {
        SetTeamWantUnpause(iTeam, false);
    } else {
        SetClientWantUnpause(iClient, false);
    }

    if (IsPauseState(PauseState_Countdown))
    {
        SetPauseState(PauseState_Active);

        char szPlayerName[MAX_NAME_LENGTH];

        for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
        {
            if (!IsClientInGame(iPlayer)
            || IsFakeClient(iPlayer)
            || !IsValidTeam(GetClientTeam(iPlayer))) {
                continue;
            }

            GetClientNameFixed(iClient, szPlayerName, sizeof(szPlayerName), 18);

            CPrintToChatEx(iPlayer, iClient, "%T%T", "TAG", iPlayer, "STOP_COUNTDOWN_PLAYER_UNREADY", iPlayer, szPlayerName);
        }
    }

    return Plugin_Handled;
}

/**
 *
 */
Action Vote_Callback(int iClient, const char[] sCmd, int iArgs)
{
    if (IsPauseState(PauseState_None)) {
        return Plugin_Continue;
    }

    if (IsReadyupStateInProgress()) {
        return Plugin_Continue;
    }

    if (NativeVotes_IsVoteInProgress()) {
        return Plugin_Continue;
    }

    char sArg[8]; GetCmdArg(1, sArg, sizeof(sArg));

    if (strcmp(sArg, "Yes", false) == 0) {
        Cmd_Ready(iClient, 0);
    }

    else if (strcmp(sArg, "No", false) == 0) {
        Cmd_Unready(iClient, 0);
    }

    return Plugin_Continue;
}

Action ConCmd_Pause(int iClient, const char[] szCommand, int iArgs)
{
    if (!GetConVarBool(g_cvPausable)) return Plugin_Handled;
    return Plugin_Continue;
}

void SetGlobalPause(int iClient, bool bEnable)
{
    SetConVarBool(g_cvPausable, true);
    FakeClientCommand(iClient, "pause");
    SetConVarBool(g_cvPausable, false);

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer)|| IsFakeClient(iPlayer)) {
            continue;
        }

        switch (GetClientTeam(iPlayer))
        {
            case TEAM_SPECTATOR: SendConVarValue(iPlayer, g_cvNoclipDuringPause, bEnable ? "1" : "0");

            case TEAM_INFECTED:
            {
                if (bEnable && IsClientGhost(iPlayer))
                {
                    SetEntProp(iPlayer, Prop_Send, "m_hasVisibleThreats", 1);

                    int iButtons = GetClientButtons(iPlayer);

                    if (iButtons & IN_ATTACK) {
                        SetEntProp(iPlayer, Prop_Data, "m_nButtons", iButtons &= ~IN_ATTACK);
                    }
                }
            }
        }

        iClient = iPlayer;
    }
}

/**
 *
 */
int IsClientSpamCommand(int iClient)
{
    float fCurrentTime = GetEngineTime();

    if (fCurrentTime < g_fClientCommandSpamCooldown[iClient])
    {
        g_iClientCommandSpamAttempts[iClient]++;

        if (g_iClientCommandSpamAttempts[iClient] > g_iMaxAttempts)
        {
            g_fClientCommandSpamCooldown[iClient] += g_fSpamCooldownIncrement; // Increase cooldown time
            g_iClientCommandSpamAttempts[iClient] = 0; // Reset spam attempts

            return 1;
        }

        return 0;
    }

    g_fClientCommandSpamCooldown[iClient] = fCurrentTime + g_fSpamCooldownInitial; // Set cooldown
    g_iClientCommandSpamAttempts[iClient] = 0; // Reset spam attempts

    return -1;
}

float GetClientCommandSpamCooldown(int iClient) {
    return g_fClientCommandSpamCooldown[iClient] - GetEngineTime();
}

/**
 *
 */
Panel BuildPanel(int iClient)
{
    Panel hPanel = CreatePanel();

    /*
     * Header.
     */
    int iHeaderSize = GetArraySize(g_hPanelHeader);

    if (iHeaderSize > 0)
    {
        char sHeader[64];

        for (int iIndex = 0; iIndex < iHeaderSize; iIndex ++)
        {
            if (ExecuteForward_OnPreparePauseItem(PausePanelPos_Header, iClient, iIndex) == Plugin_Continue) {
                continue;
            }

            GetArrayString(g_hPanelHeader, iIndex, sHeader, sizeof(sHeader));
            DrawPanelText(hPanel, sHeader);
        }

        DrawPanelSpace(hPanel);
    }

    switch (g_ePauseMode)
    {
        case PauseMode_PlayerReady: DrawPanelBodyForPlayerReady(hPanel, iClient);
        case PauseMode_TeamReady: DrawPanelBodyForTeamReady(hPanel, iClient);
    }

    /*
     * Footer.
     */
    int iFooterSize = GetArraySize(g_hPanelFooter);

    if (iFooterSize > 0)
    {
        DrawPanelSpace(hPanel);

        char sFooter[64];

        for (int iIndex = 0; iIndex < iFooterSize; iIndex ++)
        {
            if (ExecuteForward_OnPreparePauseItem(PausePanelPos_Footer, iClient, iIndex) == Plugin_Continue) {
                continue;
            }

            GetArrayString(g_hPanelFooter, iIndex, sFooter, sizeof(sFooter));
            DrawPanelText(hPanel, sFooter);
        }
    }

    return hPanel;
}

void DrawPanelBodyForPlayerReady(Handle hPanel, int iClient)
{
    char szPanelMarkReady[16]; FormatEx(szPanelMarkReady, sizeof(szPanelMarkReady), "%T", "PANEL_MARK_READY", iClient);
    char szPanelMarkUnready[16]; FormatEx(szPanelMarkUnready, sizeof(szPanelMarkUnready), "%T", "PANEL_MARK_UNREADY", iClient);
    char sSurvivorTeam[64]; FormatEx(sSurvivorTeam, sizeof(sSurvivorTeam), "%T", "PANEL_SURVIVOR_TEAM", iClient);
    char sInfectedTeam[64]; FormatEx(sInfectedTeam, sizeof(sInfectedTeam), "%T", "PANEL_INFECTED_TEAM", iClient);

    DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
        IsTeamWantUnpause(TEAM_SURVIVOR) ? szPanelMarkReady : szPanelMarkUnready,
        sSurvivorTeam
    );

    DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
        IsTeamWantUnpause(TEAM_INFECTED) ? szPanelMarkReady : szPanelMarkUnready,
        sInfectedTeam
    );
}

void DrawPanelBodyForTeamReady(Handle hPanel, int iClient)
{
    char PANEL_BLOCK_NAME[][] = {
        "PANEL_SURVIVOR_TEAM", "PANEL_INFECTED_TEAM"
    };

    char szPanelMarkReady[16]; FormatEx(szPanelMarkReady, sizeof(szPanelMarkReady), "%T", "PANEL_MARK_READY", iClient);
    char szPanelMarkUnready[16]; FormatEx(szPanelMarkUnready, sizeof(szPanelMarkUnready), "%T", "PANEL_MARK_UNREADY", iClient);

    int iPlayers[4][MAXPLAYERS + 1];
    int iTotalPlayers[4] = {0, ...};

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)) {
            continue;
        }

        int iPlayerTeam = GetClientTeam(iPlayer);

        iPlayers[iPlayerTeam][iTotalPlayers[iPlayerTeam] ++] = iPlayer;
    }

    int iBlock = 0;
    char szBlockName[64];

    char szPlayerName[MAX_NAME_LENGTH];

    for (int iTeam = TEAM_SURVIVOR; iTeam <= TEAM_INFECTED; iTeam ++)
    {
        FormatEx(szBlockName, sizeof(szBlockName), "%T", PANEL_BLOCK_NAME[iBlock], iClient);

        DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_TEAM", iClient, iBlock + 1, szBlockName);

        for (int iPlayer = 0; iPlayer < iTotalPlayers[iTeam]; iPlayer ++)
        {
            GetClientNameFixed(iPlayers[iTeam][iPlayer], szPlayerName, sizeof(szPlayerName), 18);

            DrawPanelFormatText(hPanel, "%T", "PANEL_BLOCK_ITEM", iClient,
                IsClientWantUnpause(iPlayers[iTeam][iPlayer]) ? szPanelMarkReady : szPanelMarkUnready,
                szPlayerName
            );
        }

        if (!iBlock) {
            DrawPanelSpace(hPanel);
        }

        iBlock ++;
    }
}

/**
 *
 */
bool DrawPanelFormatText(Handle hPanel, const char[] sText, any ...)
{
    char sFormatText[128];
    VFormat(sFormatText, sizeof(sFormatText), sText, 3);
    return DrawPanelText(hPanel, sFormatText);
}

/**
 *
 */
void DrawPanelSpace(Handle hPanel) {
    DrawPanelItem(hPanel, "", ITEMDRAW_SPACER);
}

/**
 *
 */
int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { return 0; }

bool IsPauseMode(PauseMode eMode) {
    return (g_ePauseMode == eMode);
}

/**
 *
 */
void SetPauseState(PauseState ePauseState)
{
    if (g_ePauseState != ePauseState) {
        ExecuteForward_OnChangePauseState(g_ePauseState, ePauseState);
    }

    g_ePauseState = ePauseState;
}

bool IsPauseState(PauseState ePauseState) {
    return (g_ePauseState == ePauseState);
}

bool IsReadyupStateInProgress() {
    return g_bReadyUpAvailable && GetReadyState() != ReadyupState_None;
}

/**
 *
 */
bool IsTeamWantUnpause(int iTeam)
{
    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient)
        || IsFakeClient(iClient)
        || GetClientTeam(iClient) != iTeam) {
            continue;
        }

        if (!IsClientWantUnpause(iClient)) {
            return false;
        }
    }

    return true;
}

/**
 *
 */
bool IsGameReady() {
    return IsTeamWantUnpause(TEAM_INFECTED) && IsTeamWantUnpause(TEAM_SURVIVOR);
}

/**
 *
 */
void SetTeamWantUnpause(int iTeam, bool bWantUnpause)
{
    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) != iTeam) {
            continue;
        }

        SetClientWantUnpause(iClient, bWantUnpause);
    }
}

/**
 *
 */
int GetRandomClient()
{
    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient) || !IsValidTeam(GetClientTeam(iClient))) {
            continue;
        }

        return iClient;
    }

    return -1;
}

/**
 *
 */
bool SetClientWantUnpause(int iClient, bool bWantUnpause)
{
    bool bBeforeReady = g_bClientWantUnpause[iClient];

    g_bClientWantUnpause[iClient] = bWantUnpause;

    return bBeforeReady != bWantUnpause;
}

/**
 *
 */
bool IsClientWantUnpause(int iClient) {
    return g_bClientWantUnpause[iClient];
}

/**
 *
 */
void ExecuteForward_OnChangePauseState(PauseState eOldState, PauseState eNewState)
{
    if (GetForwardFunctionCount(g_fwdOnChangePauseState))
    {
        Call_StartForward(g_fwdOnChangePauseState);
        Call_PushCell(eOldState);
        Call_PushCell(eNewState);
        Call_Finish();
    }
}

/**
 *
 */
Action ExecuteForward_OnPreparePauseItem(PausePanelPos ePos, int iClient, int iIndex)
{
    Action aReturn = Plugin_Continue;

    if (GetForwardFunctionCount(g_fwdOnPreparePauseItem))
    {
        Call_StartForward(g_fwdOnPreparePauseItem);
        Call_PushCell(ePos);
        Call_PushCell(iClient);
        Call_PushCell(iIndex);
        Call_Finish(aReturn);
    }

    return aReturn;
}

/**
 *
 */
void ExecuteForward_OnRemovePauseItem(PausePanelPos ePos, int iOldIndex, int iNewIndex)
{
    if (GetForwardFunctionCount(g_fwdOnRemovePauseItem))
    {
        Call_StartForward(g_fwdOnRemovePauseItem);
        Call_PushCell(ePos);
        Call_PushCell(iOldIndex);
        Call_PushCell(iNewIndex);
        Call_Finish();
    }
}

/**
 *
 */
void GetClientNameFixed(int iClient, char[] sName, int length, int iMaxSize)
{
    GetClientName(iClient, sName, length);

    if (strlen(sName) > iMaxSize)
    {
        sName[iMaxSize - 3] = sName[iMaxSize - 2] = sName[iMaxSize - 1] = '.';
        sName[iMaxSize] = '\0';
    }
}

/**
 * Validates if is a valid team.
 *
 * @param iTeam     Team index.
 * @return          True if team is valid, false otherwise.
 */
bool IsValidTeam(int iTeam) {
    return (iTeam == TEAM_SURVIVOR || iTeam == TEAM_INFECTED);
}

/**
 * Returns if the client is in ghost state.
 *
 * @param client        Client index.
 * @return              True if client is in ghost state, false otherwise.
 */
bool IsClientGhost(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isGhost"));
}

/**
 * Checks if the current round is the second.
 *
 * @return                  Returns true if is second round, otherwise false.
 */
bool InSecondHalfOfRound() {
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}
