#pragma semicolon 1

#define DEBUG_WEIGHTS 0
#define DEBUG_SPAWNQUEUE 0
#define DEBUG_TIMERS 0
#define DEBUG_POSITIONER 0

#define VANILLA_COOP_SI_LIMIT 2
#define NUM_TYPES_INFECTED 6

#include <sourcemod>
#include <sdktools>
#include <regex>
// #include <left4downtown>
#include <left4dhooks>

new Handle:hCvarReadyUpEnabled;
new Handle:hCvarConfigName;
new Handle:hCvarLineOfSightStarvationTime;
new Handle:hTimerHUD;

new bool:bShowSpawnerHUD[MAXPLAYERS];
new Float:g_fTimeLOS[100000]; // not sure what the largest possible userid is
bool g_bAlreadyStart = false;
bool g_bTweakMode = false;
bool g_bSpecialMode = false;
ConVar g_pCvarTweakSize, g_pCvarTweakInterval, g_pCvarTweakHunter, g_pCvarTweakJockey;

// Modules
#include "includes/hardcoop_util.sp"
#include "modules/SS_SpawnQuantities.sp"
#include "modules/SS_SpawnTimers.sp"
#include "modules/SS_SpawnQueue.sp"
#include "modules/SS_SpawnPositioner.sp"

/*
 * TODO:
*/

/***********************************************************************************************************************************************************************************
     					All credit for the spawn timer, quantities and queue modules goes to the developers of the 'l4d2_autoIS' plugin                            
***********************************************************************************************************************************************************************************/
  
public Plugin:myinfo = 
{
	name = "刷特感",
	author = "Tordecybombo, breezy",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "",
	url = ""
};

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax) { 
	// L4D2 check
	decl String:mod[32];
	GetGameFolderName(mod, sizeof(mod));
	if( !StrEqual(mod, "left4dead2", false) ) {
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public OnPluginStart() {	
	// Load modules
	SpawnQuantities_OnModuleStart();
	SpawnTimers_OnModuleStart();
	SpawnQueue_OnModuleStart();
	SpawnPositioner_OnModuleStart();
	// Compatibility with server_namer.smx
	hCvarReadyUpEnabled = CreateConVar("l4d_ready_enabled", "1", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	hCvarConfigName = CreateConVar("l4d_ready_cfg_name", "Hard Coop", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	SetConVarFlags( hCvarReadyUpEnabled, FCVAR_CHEAT ); SetConVarFlags( hCvarConfigName, FCVAR_CHEAT ); // get rid of 'symbol is assigned a value that is never used' compiler warnings
	
	g_pCvarTweakSize = CreateConVar("ss_tweak_size", "1", "是否允许玩家调整刷特感数量", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarTweakInterval = CreateConVar("ss_tweak_timer", "1", "是否允许玩家调整刷特感间隔", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarTweakHunter = CreateConVar("ss_tweak_hunter", "1", "是否允许玩家调整Hunter模式及数量", FCVAR_NONE, true, 0.0, true, 1.0);
	g_pCvarTweakJockey = CreateConVar("ss_tweak_jockey", "1", "是否允许玩家调整Jockey模式及数量", FCVAR_NONE, true, 0.0, true, 1.0);
	
	// Resetting at the end of rounds
	HookEvent("mission_lost", OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("map_transition", OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("round_end", OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("round_start_pre_entity", OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("round_start_post_nav", OnRoundOver, EventHookMode_PostNoCopy);
	HookEvent("survival_round_start", OnSurvivalRoundStart, EventHookMode_PostNoCopy);
	// Faster spawns
	HookEvent("player_death", OnPlayerDeath, EventHookMode_PostNoCopy);
	// LOS tracking
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_PostNoCopy);
	// HookEvent("create_panic_event", Event_PaincEventStart, EventHookMode_PostNoCopy);
	hCvarLineOfSightStarvationTime = CreateConVar( "ss_los_starvation_time", "7.5", "当SI看不见敌人多长时间处死" );
	
	// Customisation commands
	RegConsoleCmd("sm_weight", Cmd_SetWeight, "Set spawn weights for SI classes");
	RegConsoleCmd("sm_limit", Cmd_SetLimit, "Set individual, total and simultaneous SI spawn limits");
	RegConsoleCmd("sm_timer", Cmd_SetTimer, "Set a variable or constant spawn time (seconds)");
	RegConsoleCmd("sm_spawnmode", Cmd_SpawnMode, "[ 0 = vanilla spawning, 1 = radial repositioning, 2 = grid repositioning ]");
	RegConsoleCmd("sm_spawnproximity", Cmd_SpawnProximity, "Set the minimum and maximum spawn distance");
	// Admin commands
	RegAdminCmd("sm_resetspawns", Cmd_ResetSpawns, ADMFLAG_RCON, "Reset by slaying all special infected and restarting the timer");
	RegAdminCmd("sm_forcetimer", Cmd_StartSpawnTimerManually, ADMFLAG_RCON, "Manually start the spawn timer");
	
	AutoExecConfig(true, "l4d2_specialspawnner");
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

public OnPluginEnd() {
	ResetConVar( FindConVar("director_spectate_specials") );
	ResetConVar( FindConVar("director_no_specials") ); // Disable Director spawning specials naturally
	ResetConVar( FindConVar("z_safe_spawn_range") );
	ResetConVar( FindConVar("z_spawn_safety_range") );
	ResetConVar( FindConVar("z_spawn_range") );
	ResetConVar( FindConVar("z_discard_range") );
	
	CloseHandle(hTimerHUD);
	SpawnTimers_OnModuleEnd();
	SpawnPositioner_OnModuleEnd();
}

/***********************************************************************************************************************************************************************************

                                                 					PER ROUND
                                                                    
***********************************************************************************************************************************************************************************/

public OnConfigsExecuted() {	
	// Load customised cvar values to override any .cfg values
	LoadCacheSpawnLimits();
	LoadCacheSpawnWeights(); 
	hTimerHUD = CreateTimer( 0.1, Timer_DrawSpawnerHUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	EnableDirector();
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client) { 
	// Disable for PvP modes
	/*
	decl String:gameMode[16];
	GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
	if( StrContains(gameMode, "versus", false) != -1 || StrContains(gameMode, "scavenge", false) != -1 ) {
		SetFailState("Plugin does not support PvP modes");
	} else if( StrContains(gameMode, "survival", false) == -1 ) { // would otherwise cause spawns in survival before button is pressed
		g_bHasSpawnTimerStarted = false;
		StartSpawnTimer();
	}
	*/
	
	int entity = CreateEntityByName("info_gamemode");
	if(entity < MaxClients || !IsValidEntity(entity))
	{
		decl String:gameMode[16];
		GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
		if( StrContains(gameMode, "versus", false) != -1 || StrContains(gameMode, "scavenge", false) != -1 ) {
			SetFailState("Plugin does not support PvP modes");
		} else if( StrContains(gameMode, "survival", false) == -1 ) { // would otherwise cause spawns in survival before button is pressed
			g_bHasSpawnTimerStarted = false;
			StartSpawnTimer();
			g_bAlreadyStart = true;
		}
		
		return Plugin_Continue;
	}
	
	DispatchSpawn(entity);
	HookSingleEntityOutput(entity, "OnCoop", OnGamemodeCoop, true);
	HookSingleEntityOutput(entity, "OnSurvival", OnGamemodeCoop, true);
	HookSingleEntityOutput(entity, "OnVersus", OnGamemodeVersus, true);
	HookSingleEntityOutput(entity, "OnScavenge", OnGamemodeVersus, true);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "PostSpawnActivate");
	if(IsValidEntity(entity))
		RemoveEntity(entity);
	
	return Plugin_Continue;
}

public void OnGamemodeCoop(const char[] output, int caller, int activator, float delay)
{
	g_bHasSpawnTimerStarted = false;
	StartSpawnTimer();
	g_bAlreadyStart = true;
	PrintToChatAll("\x03[SS]\x01 特感数量 \x05%d\x01，刷特间隔 \x05%d\x01。", hSILimit.IntValue, hSpawnTimeMin.IntValue);
	PrintToChatAll("聊天框输入 \x04数字si\x01 设置数量，输入 \x04数字s\x01 设置间隔。例如：4si、8si、15s、30s");
	// PrintToChatAll("聊天框输入 4ht/5ht/6ht/7ht/8ht/9ht/10ht/11ht/12ht 切换为Hunter模式并设置数量。");
	// PrintToChatAll("聊天框输入 4jk/5jk/6jk/7jk/8jk/9jk/10jk/11jk/12jk 切换为Jockey模式并设置数量。");
	// PrintToChatAll("聊天框输入 4si/5si/6si/7si/8si/9si/10si/11si/12si 设置特感数量。");
	// PrintToChatAll("聊天框输入 5s/10s/15s/20s/25s/30s/35s/40s/45s 设置刷特间隔。");
	PrintToServer("SpecialSpawnner: start");
	
	if(g_bSpecialMode)
		DisableDirector();
	else
		EnableDirector();
}

public void OnGamemodeVersus(const char[] output, int caller, int activator, float delay)
{
	/*
	ResetConVar( FindConVar("director_spectate_specials") );
	ResetConVar( FindConVar("director_no_specials") ); // Disable Director spawning specials naturally
	ResetConVar( FindConVar("z_safe_spawn_range") );
	ResetConVar( FindConVar("z_spawn_safety_range") );
	ResetConVar( FindConVar("z_spawn_range") );
	ResetConVar( FindConVar("z_discard_range") );
	*/
	EnableDirector();
}

// 突变模式兼容
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if(g_bTweakMode)
		return Plugin_Continue;
	
	if(StrEqual(key, "MaxSpecials", false) || StrEqual(key, "cm_MaxSpecials", false))
	{
		hSILimit.IntValue = retVal;
		// hSILimitServerCap.IntValue = retVal * 2;
	}
	else if(StrEqual(key, "BoomerLimit", false))
		hSpawnLimits[SI_BOOMER].IntValue = retVal;
	else if(StrEqual(key, "SmokerLimit", false))
		hSpawnLimits[SI_SMOKER].IntValue = retVal;
	else if(StrEqual(key, "HunterLimit", false))
		hSpawnLimits[SI_HUNTER].IntValue = retVal;
	else if(StrEqual(key, "ChargerLimit", false))
		hSpawnLimits[SI_CHARGER].IntValue = retVal;
	else if(StrEqual(key, "SpitterLimit", false))
		hSpawnLimits[SI_SPITTER].IntValue = retVal;
	else if(StrEqual(key, "JockeyLimit", false))
		hSpawnLimits[SI_JOCKEY].IntValue = retVal;
	else if(StrEqual(key, "cm_SpecialRespawnInterval", false))
	{
		hSpawnTimeMin.IntValue = retVal;
		hSpawnTimeMax.IntValue = retVal + 5;
	}
	
	return Plugin_Continue;
}

stock void DisableDirector()
{
	SetConVarBool( FindConVar("director_no_specials"), true );
}

stock void EnableDirector()
{
	ResetConVar( FindConVar("director_no_specials") );
}

public OnSurvivalRoundStart(Event event, const char[] name, bool dontBroadcast) {
	/*
	g_bHasSpawnTimerStarted = false;
	StartSpawnTimer();
	g_bAlreadyStart = true;
	*/
	L4D_OnFirstSurvivorLeftSafeArea(-1);
}

public void OnClientDisconnect_Post(int client)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(i == client || !IsClientConnected(i) || IsFakeClient(i))
			continue;
		
		return;
	}
	
	g_bTweakMode = false;
	g_bSpecialMode = false;
	EndSpawnTimer();
	EnableDirector();
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;
	
	if(g_bAlreadyStart)
		StartSpawnTimer();
}

public void OnRoundOver(Event event, const char[] name, bool dontBroadcast) {
	EndSpawnTimer();
	g_bAlreadyStart = false;
	// PrintToChatAll("\x03[SS]\x01 刷特感停止。");
	PrintToServer("SpecialSpawnner: stop");
}

public void Event_PaincEventStart(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bAlreadyStart && HaveAnyHuman())
	{
		StartSpawnTimer();
		g_bAlreadyStart = true;
	}
}

public Action L4D_OnSpawnMob(int &amount)
{
	if(!g_bAlreadyStart && HaveAnyHuman())
	{
		StartSpawnTimer();
		g_bAlreadyStart = true;
	}
}

// Kick infected bots promptly after death to allow quicker infected respawn
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(player) ) {
		CreateTimer(1.0, Timer_KickBot, player);
	}
}

stock bool HaveAnyHuman(int ignore = -1)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(i == ignore || !IsClientConnected(i) || IsFakeClient(i))
			continue;
		
		return true;
	}
	
	return false;
}

/***********************************************************************************************************************************************************************************

                                                 					LOS STARVATION
                                                                    
***********************************************************************************************************************************************************************************/

// Slay infected if they have not had LOS to survivors for a defined (hCvarLineOfSightStarvationTime/ss_los_starvation_time) period
public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	if( IsBotInfected(client) && !IsTank(client) && userid >= 0 ) {
		g_fTimeLOS[userid] = 0.0;
		// Checking LOS
		CreateTimer( 0.5, Timer_StarvationLOS, userid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	}
}

public Action:Timer_StarvationLOS( Handle:timer, any:userid ) {
	new client = GetClientOfUserId( userid );
	// increment tracked LOS time
	if( IsBotInfected(client) && IsPlayerAlive(client) ) {
	
		if( bool:GetEntProp(client, Prop_Send, "m_hasVisibleThreats") ) {
			g_fTimeLOS[userid] = 0.0;
		} else {
			g_fTimeLOS[userid] += 0.5; 
		}
		
		if( g_fTimeLOS[userid] > GetConVarFloat(hCvarLineOfSightStarvationTime) ) {
			switch ( GetConVarInt(FindConVar("ss_spawnpositioner_mode")) ) {
				case 1: {
					RepositionRadial(userid, GetLeadSurvivor());
				}
				case 2: {
					RepositionGrid(userid);
				}
				default: {
				}
			}
			return Plugin_Stop;
		}
	} else {
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

                                                           SPAWN TIMER AND CUSTOMISATION CMDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_SetLimit(client, args) {
	if( !IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if (args == 2) {
		// Read in the SI class
		new String:sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));
		// Read in limit value 
		new String:sLimitValue[32];     
		GetCmdArg(2, sLimitValue, sizeof(sLimitValue));
		new iLimitValue = StringToInt(sLimitValue);    
		// Must be valid limit value		
		if( iLimitValue < 0 ) {
			PrintToChat(client, "[SS] Limit value must be >= 0");
		} else {
			// Apply limit value to appropriate class
			if( StrEqual(sTargetClass, "all", false) ) {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					SpawnLimitsCache[i] = iLimitValue;
				}
				Client_PrintToChatAll( true, "[SS] All SI limits have been set to {G}%d", iLimitValue );
			} else if( StrEqual(sTargetClass, "max", false) ) {  // Max specials
				SILimitCache = iLimitValue;
				Client_PrintToChatAll(true, "[SS] -> {O}Max {N}SI limit set to {G}%i", iLimitValue);		           
			} else if( StrEqual(sTargetClass, "group", false) || StrEqual(sTargetClass, "wave", false) ) {
				SpawnSizeCache = iLimitValue;
				Client_PrintToChatAll(true, "[SS] -> SI will spawn in {O}groups{N} of {G}%i", iLimitValue);
			} else {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					if( StrEqual(Spawns[i], sTargetClass, false) ) {
						SpawnLimitsCache[i] = iLimitValue;
						Client_PrintToChatAll(true, "[SS] {O}%s {N}limit set to {G}%i", sTargetClass, iLimitValue);
					}
				}
			}
		}	 
	} else {  // Invalid command syntax
		Client_PrintToChat(client, true, "{O}!limit/sm_limit {B}<class> <limit>");
		Client_PrintToChat(client, true, "{B}<class> {N}[ all | max | group/wave | smoker | boomer | hunter | spitter | jockey | charger ]");
		Client_PrintToChat(client, true, "{B}<limit> {N}[ >= 0 ]");
	}
	// Load cache into appropriate cvars
	LoadCacheSpawnLimits(); 
	return Plugin_Handled;  
}

public Action:Cmd_SetWeight(client, args) {
	if( !IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if( args == 1 ) {
		decl String:arg[16];
		GetCmdArg(1, arg, sizeof(arg));	
		if( StrEqual(arg, "reset", false) ) {
			ResetWeights();
			ReplyToCommand(client, "[SS] Spawn weights reset to default values");
		} 
	} else if( args == 2 ) {
		// Read in the SI class
		new String:sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));

		// Read in limit value 
		new String:sWeightPercent[32];     
		GetCmdArg(2, sWeightPercent, sizeof(sWeightPercent));
		new iWeightPercent = StringToInt(sWeightPercent);      
		if( iWeightPercent < 0 || iWeightPercent > 100 ) {
			PrintToChat( client, "0 <= weight value <= 100") ;
			return Plugin_Handled;
		} else { //presets for spawning special infected i only
			if( StrEqual(sTargetClass, "all", false) ) {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					SpawnWeightsCache[i] = iWeightPercent;			
				}	
				Client_PrintToChat(client, true, "[SS] -> {O}All spawn weights {N}set to {G}%d", iWeightPercent );	
			} else {
				for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					if( StrEqual(sTargetClass, Spawns[i], false) ) {
						SpawnWeightsCache[i] =  iWeightPercent;
						Client_PrintToChat(client, true, "[SS] {O}%s {N}weight set to {G}%d", Spawns[i], iWeightPercent );				
					}
				}	
			}
			
		}
	} else {
		Client_PrintToChat( client, true, "{O}!weight/sm_weight {B}<class> <value>" );
		Client_PrintToChat( client, true, "{B}<class> {N}[ reset | all | smoker | boomer | hunter | spitter | jockey | charger ] " );	
		Client_PrintToChat( client, true, "{B}value {N}[ >= 0 ] " );	
	}
	LoadCacheSpawnWeights();
	return Plugin_Handled;
}

public Action:Cmd_SetTimer(client, args) {
	if( !IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if( args == 1 ) {
		new Float:time;
		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		if (time < 0.0) { 
			time = 1.0; // don't want a constant spawn time of 0s
		}
		SetConVarFloat( hSpawnTimeMin, time );
		SetConVarFloat( hSpawnTimeMax, time );
		SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
		Client_PrintToChat(client, true, "[SS] Spawn timer set to constant {G}%.3f {N}seconds", time);
	} else if( args == 2 ) {
		new Float:min, Float:max;
		decl String:arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		min = StringToFloat(arg);
		GetCmdArg( 2, arg, sizeof(arg) );
		max = StringToFloat(arg);
		if( min > 0.0 && max > 1.0 && max > min ) {
			SetConVarFloat( hSpawnTimeMin, min );
			SetConVarFloat( hSpawnTimeMax, max );
			SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
			Client_PrintToChat(client, true, "[SS] Spawn timer will be between {G}%.3f {N}and {G}%.3f {N}seconds", min, max );
		} else {
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn time must greater than min(>= 0.0) spawn time");
		}
	} else {
		ReplyToCommand(client, "[SS] timer <constant> || timer <min> <max>");
	}
	return Plugin_Handled;
}

public Action:Cmd_SpawnMode( client, args ) {
	if( !IsSurvivor(client) && !IsGenericAdmin(client) ) {
		ReplyToCommand( client, "You do not have access to this command" );	
	}
	// Switch to appropriate mode
	new bool:isValidParams = false;
	if( args == 1 ) {
		new String:arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		new mode = StringToInt(arg);
		if( mode >= 0 && mode <= 2 ) {
			SetConVarInt( hCvarSpawnPositionerMode, mode );
			new String:spawnModes[3][8] = { "Vanilla", "Radial", "Grid" };
			Client_PrintToChat( client, true, "[SS] {O}%s {N}spawn mode activated", spawnModes[mode] );
			isValidParams = true;
		}
	} 
	// Correct command usage
	if( !isValidParams ) {
		new String:spawnModes[3][8] = { "Vanilla", "Radial", "Grid" };
		Client_PrintToChat( client, true, "[SS] Current spawnmode: {O}%s", spawnModes[GetConVarInt(hCvarSpawnPositionerMode)] );
		ReplyToCommand( client, "Usage: spawnmode <mode> [ 0 = vanilla spawning, 1 = radial repositioning, 2 = grid repositioning ]" );
	}
}

public Action:Cmd_SpawnProximity(client, args) {	
	if( args == 2 ) {
		new Float:min, Float:max;
		decl String:arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		min = StringToFloat(arg);
		GetCmdArg( 2, arg, sizeof(arg) );
		max = StringToFloat(arg);
		if( min > 0.0 && max > 1.0 && max > min ) {
			SetConVarFloat( hCvarSpawnProximityMin, min );
			SetConVarFloat( hCvarSpawnProximityMax, max );
			Client_PrintToChat(client, true, "[SS] Spawn proximity set between {G}%.3f {N}and {G}%.3f {N}units", min, max );
		} else {
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn proximity must greater than min(>= 0.0) spawn proximity");
		}
	} else {
		ReplyToCommand(client, "[SS] spawnproximity <min> <max>");
	}
	return Plugin_Handled;
}

public Action Command_Say(int client, const char[] command, int argc)
{
	if(client < 1 || client >= MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	static char sayText[255];
	GetCmdArg(1, sayText, 255);
	
	if(g_pCvarTweakSize.BoolValue)
	{
		static Regex re;
		if(re == null)
			re = CompileRegex("(\\d{1,2})si", PCRE_CASELESS);
		if(re.Match(sayText) > 0)
		{
			int count = 0;
			static char matchs[8];
			if(re.GetSubString(1, matchs, 8) && matchs[0] != EOS && (1 <= (count = StringToInt(matchs)) <= 28))
			{
				int sepc = count / 3;
				hSILimit.IntValue = count;
				hSpawnLimits[SI_SMOKER].IntValue = sepc;
				hSpawnLimits[SI_BOOMER].IntValue = sepc;
				hSpawnLimits[SI_HUNTER].IntValue = sepc;
				hSpawnLimits[SI_SPITTER].IntValue = sepc;
				hSpawnLimits[SI_JOCKEY].IntValue = sepc;
				hSpawnLimits[SI_CHARGER].IntValue = sepc;
				hSpawnSize.IntValue = count - sepc;
				g_bTweakMode = true;
				g_bSpecialMode = false;
				
				char message[255];
				Format(message, 255, "\x03[SS]\x01 特感数量调整为 \x05%d\x01，每波刷 \x05%d\x01 只。", count, count - sepc);
				
				DataPack data = CreateDataPack();
				data.WriteString(message);
				RequestFrame(NotifyTweakMessage, data);
				
				return Plugin_Continue;
			}
			else
			{
				PrintToChat(client, "有效范围：1~28");
			}
		}
	}
	if(g_pCvarTweakInterval.BoolValue)
	{
		static Regex re;
		if(re == null)
			re = CompileRegex("(\\d{1,2})s", PCRE_CASELESS);
		if(re.Match(sayText) > 0)
		{
			int count = 0;
			static char matchs[8];
			if(re.GetSubString(1, matchs, 8) && matchs[0] != EOS && (0 <= (count = StringToInt(matchs)) <= 45))
			{
				hSpawnTimeMin.IntValue = count;
				hSpawnTimeMax.IntValue = count + 5;
				g_bTweakMode = true;
				
				char message[255];
				Format(message, 255, "\x03[SS]\x01 特感刷新间隔调整为 \x05%d\x01。", count);
				
				DataPack data = CreateDataPack();
				data.WriteString(message);
				RequestFrame(NotifyTweakMessage, data);
				
				return Plugin_Continue;
			}
			else
			{
				PrintToChat(client, "有效范围：0~45");
			}
		}
	}
	if(g_pCvarTweakHunter.BoolValue)
	{
		static Regex re;
		if(re == null)
			re = CompileRegex("(\\d{1,2})ht", PCRE_CASELESS);
		if(re.Match(sayText) > 0)
		{
			int count = 0;
			static char matchs[8];
			if(re.GetSubString(1, matchs, 8) && matchs[0] != EOS && (1 <= (count = StringToInt(matchs)) <= 28))
			{
				int sepc = count / 3;
				hSILimit.IntValue = count;
				hSpawnLimits[SI_SMOKER].IntValue = 0;
				hSpawnLimits[SI_BOOMER].IntValue = 0;
				hSpawnLimits[SI_HUNTER].IntValue = count;
				hSpawnLimits[SI_SPITTER].IntValue = sepc;
				hSpawnLimits[SI_JOCKEY].IntValue = 0;
				hSpawnLimits[SI_CHARGER].IntValue = 0;
				hSpawnSize.IntValue = count - sepc;
				g_bTweakMode = true;
				g_bSpecialMode = true;
				DisableDirector();
				
				char message[255];
				Format(message, 255, "\x03[SS]\x01 Hunter 数量调整为 \x05%d\x01，每波 \x05%d\x01 只。", count, count - sepc);
				
				DataPack data = CreateDataPack();
				data.WriteString(message);
				RequestFrame(NotifyTweakMessage, data);
				
				return Plugin_Continue;
			}
			else
			{
				PrintToChat(client, "有效范围：1~28");
			}
		}
	}
	if(g_pCvarTweakJockey.BoolValue)
	{
		static Regex re;
		if(re == null)
			re = CompileRegex("(\\d{1,2})jk", PCRE_CASELESS);
		if(re.Match(sayText) > 0)
		{
			int count = 0;
			static char matchs[8];
			if(re.GetSubString(1, matchs, 8) && matchs[0] != EOS && (1 <= (count = StringToInt(matchs)) <= 28))
			{
				int sepc = count / 3;
				hSILimit.IntValue = count;
				hSpawnLimits[SI_SMOKER].IntValue = 0;
				hSpawnLimits[SI_BOOMER].IntValue = 0;
				hSpawnLimits[SI_HUNTER].IntValue = 0;
				hSpawnLimits[SI_SPITTER].IntValue = sepc;
				hSpawnLimits[SI_JOCKEY].IntValue = count;
				hSpawnLimits[SI_CHARGER].IntValue = 0;
				hSpawnSize.IntValue = count - sepc;
				g_bTweakMode = true;
				g_bSpecialMode = true;
				DisableDirector();
				
				char message[255];
				Format(message, 255, "\x03[SS]\x01 Jockey 数量调整为 \x05%d\x01，每波 \x05%d\x01 只。", count, count - sepc);
				
				DataPack data = CreateDataPack();
				data.WriteString(message);
				RequestFrame(NotifyTweakMessage, data);
				
				return Plugin_Continue;
			}
			else
			{
				PrintToChat(client, "有效范围：1~28");
			}
		}
	}
	
	return Plugin_Continue;
}

public void NotifyTweakMessage(any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	
	char message[255];
	pack.ReadString(message, 255);
	PrintToChatAll(message);
}

/***********************************************************************************************************************************************************************************

                                                                         ADMIN COMMANDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action:Cmd_ResetSpawns(client, args) {	
	for( new i = 0; i < MAXPLAYERS; i++ ) {
		if( IsBotInfected(i) ) {
			ForcePlayerSuicide(i);
		}
	}	
	StartCustomSpawnTimer(SpawnTimes[0]);
	ReplyToCommand( client, "[SS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.3f seconds.", GetConVarFloat(hSpawnTimeMin) );
	return Plugin_Handled;
}

public Action:Cmd_StartSpawnTimerManually(client, args) {
	if( args < 1 ) {
		StartSpawnTimer();
		g_bAlreadyStart = true;
		ReplyToCommand(client, "[SS] Spawn timer started manually.");
	} else {
		new Float:time = 1.0;
		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		
		if (time < 0.0) {
			time = 1.0;
		}
		
		StartCustomSpawnTimer(time);
		ReplyToCommand(client, "[SS] Spawn timer started manually. Next potential spawn in %.3f seconds.", time);
	}
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                         SPAWNER HUD
                                                                    
***********************************************************************************************************************************************************************************/

public Action:OnPlayerRunCmd( client, &buttons ) {
	if( !IsFakeClient(client) && buttons & IN_USE && buttons & IN_RELOAD ) {
		bShowSpawnerHUD[client] = true;
	} else {
		bShowSpawnerHUD[client] = false;
	}
}

public Action:Timer_DrawSpawnerHUD( Handle:timer ) {
	new Handle:spawnerHUD = CreatePanel();
	FillHeaderInfo(spawnerHUD);
	FillSpecialInfectedInfo(spawnerHUD);
	FillTimerInfo(spawnerHUD);
	// Send to survivors
	for( new i = 1; i < MAXPLAYERS; i++ ) {
		if( IsValidClient(i) && !IsFakeClient(i) && bShowSpawnerHUD[i] ) {
			SendPanelToClient( spawnerHUD, i, DummySpawnerHUDHandler, 3 ); 
		}
	}
	CloseHandle(spawnerHUD);
	return Plugin_Continue;
}

FillHeaderInfo(Handle:spawnerHUD) {
	SetPanelTitle(spawnerHUD, "--------- SPAWNER HUD ---------");
	DrawPanelText(spawnerHUD, " \n");
}

FillSpecialInfectedInfo(Handle:spawnerHUD) {
	// Potential SI
	new String:SILimit[32];
	Format( SILimit, sizeof(SILimit), "SI 存活上限 -> %d / %d (队列上限: %d)", CountSpecialInfectedBots(), GetConVarInt(hSILimit), GetConVarInt(hSILimitServerCap) );
	DrawPanelText(spawnerHUD, SILimit);
	// Simultaneous spawn limit
	new String:simultaneousSpawnLimit[32];
	Format( simultaneousSpawnLimit, sizeof(simultaneousSpawnLimit), "每波数量 -> %d", GetConVarInt(hSpawnSize) );
	DrawPanelText(spawnerHUD, simultaneousSpawnLimit);
	DrawPanelText(spawnerHUD, " \n");
	// Individual class weights and limits
	new String:classCustomisationInfo[NUM_TYPES_INFECTED][64];
	for( new i = 0; i < NUM_TYPES_INFECTED; i++ ) {
		Format( 
			classCustomisationInfo[i],
			128, 
			"%s | 几率: %d | 上限: %d/%d ",
			Spawns[i], GetConVarInt(hSpawnWeights[i]), CountSIClass(i + 1), GetConVarInt(hSpawnLimits[i])
		);
		DrawPanelText(spawnerHUD, classCustomisationInfo[i]);
	}
	DrawPanelText(spawnerHUD, " \n");
}

FillTimerInfo(Handle:spawnerHUD) {
	// Section heading
	DrawPanelText(spawnerHUD, "间隔(秒):");
	// Min spawn time
	new String:timerMin[32];
	Format( timerMin, sizeof(timerMin), "最小: %f", GetConVarFloat(hSpawnTimeMin) );
	DrawPanelText(spawnerHUD, timerMin);
	// Max spawn time
	new String:timerMax[32];
	Format( timerMax, sizeof(timerMax), "最大: %f", GetConVarFloat(hSpawnTimeMax) );
	DrawPanelText(spawnerHUD, timerMax);
}

public DummySpawnerHUDHandler(Handle:hMenu, MenuAction:action, param1, param2) {}

CountSIClass( targetClass ) {
	new iClassSpawnVolume;
	for( new i = 0; i < MaxClients; i++ ) {
		if( IsBotInfected(i) && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == targetClass ) {
			iClassSpawnVolume++;
		}
	}	
	return iClassSpawnVolume;
}
