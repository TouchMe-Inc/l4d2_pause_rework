#if defined  _pause_rework_included_
 #endinput
#endif
#define _pause_rework_included_

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


native PauseState GetPauseState();


native PauseMode GetPauseMode();

/**
 * Adds a new item to the pause panel.
 *
 * @param ePos Panel position (header or footer).
 * @param szFormat Translation format string (e.g., "%T").
 * @param ... Arguments for the format string.
 * @return Index of the newly added item.
 */
native int PushPauseItem(PausePanelPos ePos, const char[] szFormat, any...);

/**
 * Updates an existing item in the pause panel.
 *
 * @param ePos Panel position.
 * @param iIndex Index of the item to update.
 * @param szFormat Translation format string.
 * @param ... Arguments for the format string.
 * @return New index of the updated item.
 */
native int UpdatePauseItem(PausePanelPos ePos, int iIndex, const char[] szFormat, any...);

/**
 * Removes an item from the pause panel.
 *
 * @param ePos Panel position.
 * @param iIndex Index of the item to remove.
 * @return New index of the item that replaced the removed one, or -1 if none.
 */
native int RemovePauseItem(PausePanelPos ePos, int iIndex);

/**
 * Called when the pause state changes.
 *
 * @param eOldState Previous state.
 * @param eNewState New state.
 */
forward void OnChangePauseState(PauseState eOldState, PauseState eNewState);

/**
 * Called before rendering a ready-up item.
 * Allows modification or cancellation of the item.
 *
 * @param ePos Panel position.
 * @param iClient Client index.
 * @param iIndex Item index.
 * @return Plugin_Continue to allow, Plugin_Stop to skip rendering.
 */
forward Action OnPrepareReadyUpItem(PausePanelPos ePos, int iClient, int iIndex);

/**
 * Called when a ready-up item is removed.
 *
 * @param ePos Panel position.
 * @param iOldIndex Index of the removed item.
 * @param iNewIndex Index of the item that replaced it.
 */
forward void OnRemoveReadyUpItem(PausePanelPos ePos, int iOldIndex, int iNewIndex);


public SharedPlugin __pl_pause_rework =
{
	name = "pause_rework",
	file = "pause_rework.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_pause_rework_SetNTVOptional()
{
	MarkNativeAsOptional("GetPauseState");
	MarkNativeAsOptional("GetPauseMode");
	MarkNativeAsOptional("PushPauseItem");
	MarkNativeAsOptional("UpdatePauseItem");
	MarkNativeAsOptional("RemovePauseItem");
}
#endif