#include <sourcemod>

#include <sdkhooks>

#include <movement>

#pragma newdecls required
#pragma semicolon 1



public Plugin myinfo = 
{
	name = "MovementAPI", 
	author = "DanZay", 
	description = "Provides API focused on player movement", 
	version = "2.0.1", 
	url = "https://github.com/danzayau/MovementAPI"
};

Handle gH_GameData;
Handle gH_GetMaxSpeed;

int gI_Cmdnum[MAXPLAYERS + 1];
int gI_TickCount[MAXPLAYERS + 1];
bool gB_JustJumped[MAXPLAYERS + 1];

bool gB_Jumped[MAXPLAYERS + 1];
bool gB_HitPerf[MAXPLAYERS + 1];
float gF_LandingOrigin[MAXPLAYERS + 1][3];
float gF_LandingVelocity[MAXPLAYERS + 1][3];
int gI_LandingTick[MAXPLAYERS + 1];
int gI_LandingCmdNum[MAXPLAYERS + 1];
float gF_TakeoffOrigin[MAXPLAYERS + 1][3];
float gF_TakeoffVelocity[MAXPLAYERS + 1][3];
int gI_TakeoffTick[MAXPLAYERS + 1];
int gI_TakeoffCmdNum[MAXPLAYERS + 1];
bool gB_Turning[MAXPLAYERS + 1];
bool gB_TurningLeft[MAXPLAYERS + 1];

float gF_OldOrigin[MAXPLAYERS + 1][3];
float gF_OldVelocity[MAXPLAYERS + 1][3];
float gF_OldEyeAngles[MAXPLAYERS + 1][3];
bool gB_OldOnGround[MAXPLAYERS + 1];
bool gB_OldDucking[MAXPLAYERS + 1];
MoveType gMT_OldMovetype[MAXPLAYERS + 1];

#include "movementapi/forwards.sp"
#include "movementapi/natives.sp"



public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();
	RegPluginLibrary("movementapi");
	return APLRes_Success;
}

public void OnPluginStart()
{
	PrepSDKCalls();
	CreateGlobalForwards();
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_jump", OnPlayerJump, EventHookMode_Post);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
			if (IsPlayerAlive(client))
			{
				ResetClientData(client);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetClientData(client);
}

public void OnPlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	gB_JustJumped[client] = true;
	bool jumpbug = !gB_OldOnGround[client];
	Call_OnPlayerJump(client, jumpbug);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	gI_Cmdnum[client] = cmdnum;
	gI_TickCount[client] = tickcount;
}

public void OnPlayerPostThinkPost(int client)
{
	if (!IsPlayerAlive(client))
	{
		return;
	}
	
	float origin[3];
	Movement_GetOriginEx(client, origin);
	float velocity[3];
	Movement_GetVelocity(client, velocity);
	float eyeAngles[3];
	Movement_GetEyeAngles(client, eyeAngles);
	bool onGround = Movement_GetOnGround(client);
	bool ducking = Movement_GetDucking(client);
	MoveType movetype = Movement_GetMovetype(client);
	
	UpdateTurning(client, gF_OldEyeAngles[client], eyeAngles);
	UpdateDucking(client, gB_OldDucking[client], ducking);
	UpdateOnGround(client, gI_Cmdnum[client], gI_TickCount[client], gB_OldOnGround[client], onGround, gF_OldOrigin[client], origin, gF_OldVelocity[client], velocity);
	UpdateMovetype(client, gI_Cmdnum[client], gI_TickCount[client], gMT_OldMovetype[client], movetype, gF_OldOrigin[client], origin, gF_OldVelocity[client], velocity);
	
	gB_JustJumped[client] = false;
	gF_OldOrigin[client] = origin;
	gF_OldVelocity[client] = velocity;
	gF_OldEyeAngles[client] = eyeAngles;
	gB_OldOnGround[client] = onGround;
	gB_OldDucking[client] = ducking;
	gMT_OldMovetype[client] = movetype;
}

float GetMaxSpeed(int client)
{
	return SDKCall(gH_GetMaxSpeed, client);
}

static void PrepSDKCalls()
{
	gH_GameData = LoadGameConfigFile("movementapi.games");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gH_GameData, SDKConf_Virtual, "GetPlayerMaxSpeed");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_ByValue);
	gH_GetMaxSpeed = EndPrepSDKCall();
}

static void ResetClientData(int client)
{
	gB_Jumped[client] = false;
	gB_HitPerf[client] = false;
	gF_TakeoffOrigin[client] = view_as<float>( { 0.0, 0.0, 0.0 } );
	gF_TakeoffVelocity[client] = view_as<float>( { 0.0, 0.0, 0.0 } );
	gI_TakeoffTick[client] = 0;
	gF_LandingOrigin[client] = view_as<float>( { 0.0, 0.0, 0.0 } );
	gF_LandingVelocity[client] = view_as<float>( { 0.0, 0.0, 0.0 } );
	gI_LandingTick[client] = 0;
	gB_Turning[client] = false;
	gB_TurningLeft[client] = false;
	
	gF_OldOrigin[client] = view_as<float>( { 0.0, 0.0, 0.0 } );
	gF_OldVelocity[client] = view_as<float>( { 0.0, 0.0, 0.0 } );
	gF_OldEyeAngles[client] = view_as<float>( { 0.0, 0.0, 0.0 } );
	gB_OldOnGround[client] = false;
	gB_OldDucking[client] = false;
	gMT_OldMovetype[client] = MOVETYPE_WALK;
}

static void UpdateDucking(int client, bool oldDucking, bool ducking)
{
	if (ducking && !oldDucking)
	{
		Call_OnStartDucking(client);
	}
	else if (!ducking && oldDucking)
	{
		Call_OnStopDucking(client);
	}
}

static void UpdateOnGround(
	int client, 
	int cmdnum, 
	int tickcount, 
	bool oldOnGround, 
	bool onGround, 
	const float oldOrigin[3], 
	const float origin[3], 
	const float oldVelocity[3], 
	const float velocity[3])
{
	if (onGround && !oldOnGround)
	{
		gF_LandingOrigin[client] = origin;
		gF_LandingVelocity[client] = velocity;
		gI_LandingTick[client] = tickcount;
		gI_LandingCmdNum[client] = cmdnum;
		Call_OnStartTouchGround(client);
	}
	else if (!onGround && oldOnGround)
	{
		gF_TakeoffOrigin[client] = oldOrigin;
		gF_TakeoffVelocity[client] = oldVelocity;
		gI_TakeoffTick[client] = tickcount;
		gI_TakeoffCmdNum[client] = cmdnum;
		gB_HitPerf[client] = (gI_TakeoffTick[client] - gI_LandingTick[client]) == 1;
		gB_Jumped[client] = gB_JustJumped[client];
		Call_OnStopTouchGround(client, gB_JustJumped[client]);
	}
}

static void UpdateMovetype(
	int client, 
	int cmdnum, 
	int tickcount, 
	MoveType oldMovetype, 
	MoveType movetype, 
	const float oldOrigin[3], 
	const float origin[3], 
	const float oldVelocity[3], 
	const float velocity[3])
{
	if (movetype != oldMovetype)
	{
		switch (movetype)
		{
			case MOVETYPE_WALK:
			{
				gF_TakeoffOrigin[client] = oldOrigin;
				// New velocity because game will adjust the velocity
				// of the player in some cases (jumping off ladder).
				gF_TakeoffVelocity[client] = velocity;
				gI_TakeoffTick[client] = tickcount;
				gI_TakeoffCmdNum[client] = cmdnum;
				gB_HitPerf[client] = false;
				gB_Jumped[client] = false;
			}
			case MOVETYPE_LADDER:
			{
				gF_LandingOrigin[client] = origin;
				// Old velocity because player loses speed before
				// their movetype has changed to MOVETYPE_LADDER.
				gF_LandingVelocity[client] = oldVelocity;
				gI_LandingTick[client] = tickcount;
				gI_LandingCmdNum[client] = cmdnum;
			}
			case MOVETYPE_NOCLIP:
			{
				gF_LandingOrigin[client] = origin;
				gF_LandingVelocity[client] = velocity;
				gI_LandingTick[client] = tickcount;
				gI_LandingCmdNum[client] = cmdnum;
			}
		}
		Call_OnChangeMovetype(client, gMT_OldMovetype[client], movetype);
	}
}

static void UpdateTurning(int client, const float oldEyeAngles[3], const float eyeAngles[3])
{
	gB_Turning[client] = eyeAngles[1] != oldEyeAngles[1];
	gB_TurningLeft[client] = eyeAngles[1] < oldEyeAngles[1] - 180
	 || eyeAngles[1] > oldEyeAngles[1] && eyeAngles[1] < oldEyeAngles[1] + 180;
} 