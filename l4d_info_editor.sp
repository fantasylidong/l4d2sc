#define PLUGIN_VERSION		"1.1"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Mission and Weapons - Info Editor
*	Author	:	SilverShot
*	Descrp	:	Modify gamemodes.txt and weapons.txt values by config instead of conflicting VPK files.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=310586
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (01-Jun-2019)
	- Fixed reading incorrect data for map specific sections.
	- Added support to load map specific weapon and melee data.
	- Added commands to display mission and weapon changes applied to the current map.
	- Added a command to get and set keyname values from the mission info.
	- Added a command to reload the mission and weapons configs. Live changes can be made!
	- Added natives to read and write mission and weapon data from third party plugins.
	- Added test plugin to demonstrate natives and forwards for developers.
	- Gamedata .txt changed.

1.0 (10-Sep-2018)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA				"l4d_info_editor"
#define CONFIG_MISSION			"data/l4d_info_editor_mission.cfg"
#define CONFIG_WEAPONS			"data/l4d_info_editor_weapons.cfg"
#define MAX_STRING_LENGTH		4096
#define DEBUG_VALUES			0

Handle g_hForwardOnGetMission;
Handle g_hForwardOnGetWeapons;
Handle SDK_KV_GetString;
Handle SDK_KV_SetString;
Handle SDK_KV_FindKey;
ArrayList g_alMissionData;
ArrayList g_alWeaponsData;
int g_PointerMission;
bool g_bLeft4Dead2;
bool g_bLoadNewMap;



// ====================================================================================================
//					PLUGIN INFO / NATIVES
// ====================================================================================================
public Plugin myinfo =
{
	name = "任务和武器数据修改",
	author = "SilverShot",
	description = "Modify gamemodes.txt and weapons.txt values by config instead of conflicting VPK files.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=310586"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	// Natives
	RegPluginLibrary("info_editor");
	CreateNative("InfoEditor_GetString",		Native_GetString);
	CreateNative("InfoEditor_SetString",		Native_SetString);

	return APLRes_Success;
}

public int Native_GetString(Handle plugin, int numParams)
{
	// Validate string
	int len;
	GetNativeStringLength(2, len);
	if( len <= 0 ) return;

	// Key name to get
	char key[MAX_STRING_LENGTH];
	GetNativeString(2, key, sizeof key);

	// Pointer to keyvalue for modifying
	int pThis = GetNativeCell(1);

	// Get key value
	char value[MAX_STRING_LENGTH];
	SDKCall(SDK_KV_GetString, pThis, value, sizeof value, key, "N/A");

	// Return string
	int maxlength = GetNativeCell(4);
	SetNativeString(3, value, maxlength);
}

public int Native_SetString(Handle plugin, int numParams)
{
	// Validate string
	int len;
	GetNativeStringLength(2, len);
	if( len <= 0 ) return;
	GetNativeStringLength(3, len);
	if( len <= 0 ) return;

	// Key name and value to set
	char key[MAX_STRING_LENGTH];
	char[] value = new char[len+1];
	GetNativeString(2, key, sizeof key);
	GetNativeString(3, value, len+1);

	// Pointer to keyvalue for modifying
	int pThis = GetNativeCell(1);

	// Create
	bool bCreate = GetNativeCell(4);
	if( bCreate && SDK_KV_FindKey != null )
	{
		char sCheck[MAX_STRING_LENGTH];
		SDKCall(SDK_KV_GetString, pThis, sCheck, sizeof sCheck, key, "N/A");
		if( strcmp(sCheck, "N/A") == 0 )
		{
			SDKCall(SDK_KV_FindKey, pThis, key, true);
		}
	}

	// Set key value
	SDKCall(SDK_KV_SetString, pThis, key, value);
}



// ====================================================================================================
//					PLUGIN START / END
// ====================================================================================================
public void OnPluginStart()
{
	CreateConVar("l4d_info_editor_version", PLUGIN_VERSION, "Mission and Weapons - Info Editor plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	// ====================================================================================================
	// SDKCalls
	// ====================================================================================================
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if( hGamedata == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "KeyValues::GetString") == false )
		SetFailState("Could not load the \"KeyValues::GetString\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	SDK_KV_GetString = EndPrepSDKCall();
	if( SDK_KV_GetString == null )
		SetFailState("Could not prep the \"KeyValues::GetString\" function.");

	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "KeyValues::SetString") == false )
		SetFailState("Could not load the \"KeyValues::SetString\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	SDK_KV_SetString = EndPrepSDKCall();
	if( SDK_KV_SetString == null )
		SetFailState("Could not prep the \"KeyValues::SetString\" function.");

	// Optional, not required.
	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "KeyValues::FindKey") == false )
	{
		LogError("Could not load the \"KeyValues::FindKey\" gamedata signature.");
	} else {
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Pointer);
		SDK_KV_FindKey = EndPrepSDKCall();
		if( SDK_KV_FindKey == null )
			LogError("Could not prep the \"KeyValues::FindKey\" function.");
	}

	// ====================================================================================================
	// Detours
	// ====================================================================================================
	Handle hDetour;

	// Mission Info
	hDetour = DHookCreateFromConf(hGamedata, "CTerrorGameRules::GetMissionInfo");
	if( !hDetour )
		SetFailState("Failed to find \"CTerrorGameRules::GetMissionInfo\" signature.");
	if( !DHookEnableDetour(hDetour, true, GetMissionInfo) )
		SetFailState("Failed to detour \"CTerrorGameRules::GetMissionInfo\".");

	// Weapon Info
	hDetour = DHookCreateFromConf(hGamedata, "CTerrorWeaponInfo::Parse");
	if( !hDetour )
		SetFailState("Failed to find \"CTerrorWeaponInfo::Parse\" signature.");
	if( !DHookEnableDetour(hDetour, false, GetWeaponInfo) )
		SetFailState("Failed to detour \"CTerrorWeaponInfo::Parse\".");

	if( g_bLeft4Dead2 )
	{
		// Melee Weapons
		hDetour = DHookCreateFromConf(hGamedata, "CMeleeWeaponInfo::Parse");
		if( !hDetour )
			SetFailState("Failed to find \"CMeleeWeaponInfo::Parse\" signature.");
		if( !DHookEnableDetour(hDetour, false, GetMeleeWeaponInfo) )
			SetFailState("Failed to detour \"CMeleeWeaponInfo::Parse\".");

		// Allow all Melee weapon types
		hDetour = DHookCreateFromConf(hGamedata, "CDirectorItemManager::IsMeleeWeaponAllowedToExist");
		if( !hDetour )
			SetFailState("Failed to find \"CDirectorItemManager::IsMeleeWeaponAllowedToExist\" signature.");
		if( !DHookEnableDetour(hDetour, true, MeleeWeaponAllowedToExist) )
			SetFailState("Failed to detour \"CDirectorItemManager::IsMeleeWeaponAllowedToExist\".");
	}

	delete hGamedata;

	// Strip cheat flags here, because executing when required with a CheatCommand() function to strip/add the cheat flag denies with the error:
	// "Can't use cheat command weapon_reparse_server in multiplayer, unless the server has sv_cheats set to 1."
	// We'll also block clients from executing the commands to prevent any potential exploit or command spam.
	SetCommandFlags("sb_all_bot_game", GetCommandFlags("sb_all_bot_game") & ~FCVAR_CHEAT);
	SetCommandFlags("weapon_reparse_server", GetCommandFlags("weapon_reparse_server") & ~FCVAR_CHEAT);
	AddCommandListener(cmdListenBlock, "weapon_reparse_server");
	if( g_bLeft4Dead2 )
	{
		SetCommandFlags("melee_reload_info_server", GetCommandFlags("melee_reload_info_server") & ~FCVAR_CHEAT);
		AddCommandListener(cmdListenBlock, "melee_reload_info_server");
	}

	// Forwards
	g_hForwardOnGetMission = CreateGlobalForward("OnGetMissionInfo", ET_Ignore, Param_Cell);
	g_hForwardOnGetWeapons = CreateGlobalForward("OnGetWeaponsInfo", ET_Ignore, Param_Cell, Param_String);

	// Load config
	ResetPlugin();

	// Commands
	RegAdminCmd("sm_info_weapons_list",	CmdInfoWeaponsList,	ADMFLAG_ROOT, "Show weapons config tree of modified data for this map.");
	RegAdminCmd("sm_info_mission_list",	CmdInfoMissionList,	ADMFLAG_ROOT, "Show mission config tree of modified data for this map.");
	RegAdminCmd("sm_info_mission",		CmdInfoMission,		ADMFLAG_ROOT, "Get or set the value of a mission keyname. Usage: sm_info_mission <keyname> [value].");
	RegAdminCmd("sm_info_reload",		CmdInfoReload,		ADMFLAG_ROOT, "Reloads the mission and weapons configs. Weapons info data is re-parsed allowing changes to be made live without changing level.");
}

public Action cmdListenBlock(int client, const char[] command, int argc)
{
	if( client )
		return Plugin_Handled;
	return Plugin_Continue;
}

public void OnMapEnd()
{
	g_bLoadNewMap = true;
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action CmdInfoReload(int client, int args)
{
	// Weapons Info is re-parsed via command in this function.
	ResetPlugin();

	// Mission Info has no command, but we can manually set changes with ease.
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	for( int i = 0; i < g_alMissionData.Length; i += 2 )
	{
		g_alMissionData.GetString(i, key, sizeof(key));
		g_alMissionData.GetString(i + 1, value, sizeof(value));

		#if DEBUG_VALUES
		char check[MAX_STRING_LENGTH];
		SDKCall(SDK_KV_GetString, g_PointerMission, check, sizeof check, key, "N/A");

		if( strcmp(check, value) )
		{
			if( strcmp(check, "N/A") == 0 )
			{
				PrintToServer("MissionInfo: \"%s\" not found.", key);
			} else {
				PrintToServer("MissionInfo: Set \"%s\" to \"%s\". Was \"%s\".", key, value, check);
			}
		}
		#endif

		SDKCall(SDK_KV_SetString, g_PointerMission, key, value);
	}

	return Plugin_Handled;
}

public Action CmdInfoMission(int client, int args)
{
	if( args == 1 )
	{
		char key[MAX_STRING_LENGTH];
		char value[MAX_STRING_LENGTH];
		GetCmdArg(1, key, sizeof key);

		SDKCall(SDK_KV_GetString, g_PointerMission, value, sizeof value, key, "N/A");
		ReplyToCommand(client, "[Info] Key \"%s\" = \"%s\".", key, value);
	}

	else if( args == 2 )
	{
		char key[MAX_STRING_LENGTH];
		char value[MAX_STRING_LENGTH];
		char check[MAX_STRING_LENGTH];
		GetCmdArg(1, key, sizeof key);
		GetCmdArg(2, value, sizeof value);

		// Check value
		SDKCall(SDK_KV_GetString, g_PointerMission, check, sizeof check, key, "N/A");

		// Create if not found.
		bool existed = true;
		if( SDK_KV_FindKey != null && strcmp(check, "N/A") == 0 )
		{
			SDKCall(SDK_KV_FindKey, g_PointerMission, key, true);
			existed = false;
		}

		SDKCall(SDK_KV_SetString, g_PointerMission, key, value);

		if( existed )
			ReplyToCommand(client, "[Info] Set \"%s\" to \"%s\".", key, value);
		else
			ReplyToCommand(client, "[Info] Created \"%s\" set \"%s\".", key, value);
	}

	else
	{
		ReplyToCommand(client, "Usage: sm_info_mission <keyname> [value]");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action CmdInfoMissionList(int client, int args)
{
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];

	ReplyToCommand(client, "=============================");
	ReplyToCommand(client, "===== MISSION INFO DATA =====");
	ReplyToCommand(client, "=============================");

	for( int i = 0; i < g_alMissionData.Length; i += 2 )
	{
		g_alMissionData.GetString(i, key, sizeof(key));
		g_alMissionData.GetString(i + 1, value, sizeof(value));

		ReplyToCommand(client, "%s %s", key, value);
	}

	ReplyToCommand(client, "=============================");
	return Plugin_Handled;
}

public Action CmdInfoWeaponsList(int client, int args)
{
	ArrayList aHand;
	int size;
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	char check[MAX_STRING_LENGTH];

	ReplyToCommand(client, "=============================");
	ReplyToCommand(client, "===== WEAPONS INFO DATA =====");
	ReplyToCommand(client, "=============================");

	for( int x = 0; x < g_alWeaponsData.Length; x++ )
	{
		// Weapon classname
		aHand = g_alWeaponsData.Get(x);
		aHand.GetString(0, check, sizeof check);

		ReplyToCommand(client, "%s", check);

		// Weapon keys and values
		size = aHand.Length;
		for( int i = 1; i < size; i+=2 )
		{
			aHand.GetString(i, key, sizeof key);
			aHand.GetString(i+1, value, sizeof value);
			ReplyToCommand(client, "... %s %s", key, value);
		}

		ReplyToCommand(client, "");
	}

	ReplyToCommand(client, "=============================");
	return Plugin_Handled;
}



// ====================================================================================================
//					DETOURS
// ====================================================================================================
public MRESReturn GetMissionInfo(Handle hReturn, Handle hParams)
{
	// Load new map data
	if( g_bLoadNewMap ) ResetPlugin();

	// Pointer
	int pThis = DHookGetReturn(hReturn);
	g_PointerMission = pThis;

	// Set data
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	char check[MAX_STRING_LENGTH];

	for( int i = 0; i < g_alMissionData.Length; i += 2 )
	{
		g_alMissionData.GetString(i, key, sizeof(key));
		g_alMissionData.GetString(i + 1, value, sizeof(value));

		SDKCall(SDK_KV_GetString, pThis, check, sizeof check, key, "N/A");

		if( strcmp(check, value) )
		{
			#if DEBUG_VALUES
			if( strcmp(check, "N/A") == 0 )
			{
				PrintToServer("MissionInfo: \"%s\" not found.", key);
			} else {
				PrintToServer("MissionInfo: Set \"%s\" to \"%s\". Was \"%s\".", key, value, check);
			}
			#endif

			SDKCall(SDK_KV_SetString, pThis, key, value);
		}
	}

	// Forward
	Call_StartForward(g_hForwardOnGetMission);
	Call_PushCell(pThis);
	Call_Finish();

	return MRES_Ignored;
}

public MRESReturn MeleeWeaponAllowedToExist(Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, true);
	return MRES_Override;
}

public MRESReturn GetMeleeWeaponInfo(Handle hReturn, Handle hParams)
{
	WeaponInfoFunction(1, hParams);
	return MRES_Ignored;
}

public MRESReturn GetWeaponInfo(Handle hReturn, Handle hParams)
{
	WeaponInfoFunction(0, hParams);
	return MRES_Ignored;
}

void WeaponInfoFunction(int funk, Handle hParams)
{
	// Load new map data
	if( g_bLoadNewMap ) ResetPlugin();

	// Pointer
	int pThis = DHookGetParam(hParams, 1 + funk);

	// Weapon name
	char class[64];
	DHookGetParamString(hParams, 2 - funk, class, sizeof class);

	// Set data
	ArrayList aHand;
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	char check[MAX_STRING_LENGTH];

	// Loop editor_weapons classnames
	for( int x = 0; x < g_alWeaponsData.Length; x++ )
	{
		aHand = g_alWeaponsData.Get(x);
		aHand.GetString(0, key, sizeof key);

		// Matches weapon from detour
		if( strcmp(class, key) == 0 )
		{
			// Loop editor_weapons properties
			for( int i = 1; i < aHand.Length; i += 2 )
			{
				aHand.GetString(i, key, sizeof key);
				aHand.GetString(i + 1, value, sizeof value);

				SDKCall(SDK_KV_GetString, pThis, check, sizeof check, key, "N/A");

				if( strcmp(check, value) )
				{
					#if DEBUG_VALUES
					if( strcmp(check, "N/A") == 0 )
					{
						PrintToServer("WeaponInfo: \"%s/%s\" not found.", class, key);
					} else {
						PrintToServer("WeaponInfo: Set \"%s/%s\" to \"%s\". Was \"%s\".", class, key, value, check);
					}
					#endif

					SDKCall(SDK_KV_SetString, pThis, key, value);
				}
			}
		}
	}

	// Forward
	Call_StartForward(g_hForwardOnGetWeapons);
	Call_PushCell(pThis);
	Call_PushString(class);
	// Call_PushString("a");
	Call_Finish();
}



// ====================================================================================================
//					LOAD CONFIG
// ====================================================================================================
bool g_bAllowSection;
int g_iSectionMission; // 0 = weapons cfg. 1 = mission cfg.
int g_iSectionLevel;
int g_iValueIndex;

void ResetPlugin()
{
	g_bLoadNewMap = false;

	// Clear strings
	if( g_alMissionData != null )
	{
		g_alMissionData.Clear();
		delete g_alMissionData;
	}

	// Delete handles
	if( g_alWeaponsData != null )
	{
		ArrayList aHand;
		int size = g_alWeaponsData.Length;
		for( int i = 0; i < size; i++ )
		{
			aHand = g_alWeaponsData.Get(i);
			delete aHand;
		}
		g_alWeaponsData.Clear();
		delete g_alWeaponsData;
	}

	// Load again
	LoadConfig();

	// Reparse weapon and melee configs each map
	ServerCommand("weapon_reparse_server; %s", g_bLeft4Dead2 ? "melee_reload_info_server" : "");
}

void LoadConfig()
{
	g_alMissionData = new ArrayList(ByteCountToCells(MAX_STRING_LENGTH));
	g_alWeaponsData = new ArrayList(ByteCountToCells(MAX_STRING_LENGTH));

	char sPath[PLATFORM_MAX_PATH];

	g_iSectionMission = 1;
	BuildPath(Path_SM, sPath, sizeof sPath, CONFIG_MISSION);
	if( FileExists(sPath) )
		ParseConfigFile(sPath);

	g_iSectionMission = 0;
	BuildPath(Path_SM, sPath, sizeof sPath, CONFIG_WEAPONS);
	if( FileExists(sPath) )
		ParseConfigFile(sPath);
}

bool ParseConfigFile(const char[] file)
{
	// Load parser and set hook functions
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	parser.OnEnd = Config_End;

	// Log errors detected in config
	char error[128];
	int line, col;
	SMCError result = parser.ParseFile(file, line, col);
	delete parser;

	if( result != SMCError_Okay )
	{
		if( parser.GetErrorString(result, error, sizeof error) )
		{
			SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
		}
		else
		{
			SetFailState("Unable to load config. Bad format? Check for missing { } etc.");
		}
	}

	return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	g_iSectionLevel++;

	if( g_iSectionLevel == 2 )
	{
		g_bAllowSection = false;

		if( strcmp(section, "all") == 0 )
		{
			g_bAllowSection = true;
		} else {
			char sMap[PLATFORM_MAX_PATH];
			GetCurrentMap(sMap, sizeof sMap);

			if( StrContains(sMap, section) != -1 )
			{
				g_bAllowSection = true;
			}
		}
	}

	if( g_bAllowSection && g_iSectionMission == 0 && g_iSectionLevel == 3 )
	{
		int lens = g_alWeaponsData.Length;

		bool pushData = true;
		ArrayList aHand;
		char value[64];

		g_iValueIndex = 1;

		// Loop through sections
		for( int x = 0; x < lens; x++ )
		{
			aHand = g_alWeaponsData.Get(x);
			aHand.GetString(0, value, sizeof value);

			// Already exists
			if( strcmp(value, section) == 0 )
			{
				pushData = false;
				break;
			}

			g_iValueIndex++;
		}

		// Doesn't exist, push into weapons array
		if( pushData )
		{
			aHand = new ArrayList(ByteCountToCells(MAX_STRING_LENGTH));
			aHand.PushString(section);
			g_alWeaponsData.Push(aHand);
		}
	}

	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	// 2 = Mission
	// 3 = Weapons
	if( g_bAllowSection )
	{
		if( (g_iSectionMission && g_iSectionLevel == 2) || g_iSectionLevel == 3 )
		{
			ArrayList aHand;

			// Mission Data
			if( g_iSectionMission )
			{
				aHand = g_alMissionData;

				// Remove duplicates (map specific overriding 'all' section)
				int index = aHand.FindString(key);
				if( index != -1 )
				{
					RemoveFromArray(aHand, index);
					RemoveFromArray(aHand, index);
				}

				aHand.PushString(key);
				aHand.PushString(value);

			// Weapon Data
			} else {
				aHand = g_alWeaponsData.Get(g_iValueIndex - 1);

				char sec[64];
				aHand.GetString(0, sec, sizeof sec);

				int index = aHand.FindString(key);
				if( index == -1 )
				{
					aHand.PushString(key);
					aHand.PushString(value);
				} else {
					aHand.SetString(index + 1, value);
				}
			}
		}
	}
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle parser)
{
	g_iSectionLevel--;
	return SMCParse_Continue;
}

public void Config_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the Info Editor config.");
}