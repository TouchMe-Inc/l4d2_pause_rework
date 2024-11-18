# About l4d2_pause_rework

## Commands
* `!pause` - Pause the game.
* `!ready` or `!r` - Mark your status as Ready.
* `!unready` or `!nr` - Mark your status as Not Ready.

## ConVars
| ConVar               | Value         | Description                                                                                     |
| -------------------- | ------------- | ----------------------------------------------------------------------------------------------- |
| sm_pause_mode      | 0             | Plugin operating mode (Values: 0 = Player ready, 1 = Team ready)                                |
| sm_pause_delay     | 3             | Number of seconds to count down before the round goes live                                      |
| sm_pause_spam_cd_init | 2.0        | Initial cooldown time in seconds                                                                |
| sm_pause_spam_cd_inc  | 1.0        | Cooldown increment time in seconds                                                              |
| sm_pause_spam_attempts_before_inc | 1 | Maximum number of attempts before increasing cooldown                                                               |

## Require
* Colors
* [NativeVotesRework](https://github.com/TouchMe-Inc/l4d2_nativevotes_rework)
* [ReadyupRework](https://github.com/TouchMe-Inc/l4d2_readyup_rework)
