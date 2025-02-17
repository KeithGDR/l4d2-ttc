#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PREFIX "[TTC]"
#define NO_TEAM -1
#define MAX_TEAMS 16
#define MAX_PLAYERS 16

ConVar convar_Enabled;
ConVar convar_MaxTeams;
ConVar convar_MaxPlayers;

public Plugin myinfo = {
	name = "[ANY] Two Team Coop",
	author = "KeithGDR",
	description = "A gamemode for Left 4 Dead 2 where players team up in order to win.",
	version = "1.0.0",
	url = "https://github.com/KeithGDR/l4d2-ttc"
};

enum struct Gamemode {
	ArrayList teams;	//Stores the name of the team.
	ArrayList members;	//Stores the members of the team.
	ArrayList colors;	//Stores the color of the team.

	int totalteams;		//The number of teams active.

	void Init() {
		this.teams = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));
		this.members = new ArrayList(convar_MaxTeams);
		this.colors = new ArrayList(4);

		this.totalteams = 0;
	}

	void Setup() {
		int maxteams = convar_MaxTeams.IntValue;
		int maxplayers = convar_MaxPlayers.IntValue;

		if (maxteams > MAX_TEAMS) {
			maxteams = MAX_TEAMS;
		}

		if (maxplayers > MAX_PLAYERS) {
			maxplayers = MAX_PLAYERS;
		}

		int count = GetPlayerCount(2);

		if (count < 2) {
			return;
		}

		char sTeam[64];
		for (int i = 0; i < maxteams; i++) {
			//Establish the name of the team.
			FormatEx(sTeam, sizeof(sTeam), "Team %i", i+1);
			this.teams.PushString(sTeam);

			//Establish the players on the team.
			int[] players = new int[MaxClients];
			int total;
			for (int x = 0; x < maxplayers; x++) {
				players[i] = GetRandomClient(2, -1, -1);
				total++;
			}
			this.members.PushArray(players, total);

			//Establish the color of the team.
			int c[4]; c = {255, 255, 255, 255};
			c[0] = GetRandomInt(0, 255); c[1] = GetRandomInt(0, 255); c[2] = GetRandomInt(0, 255);
			this.colors.PushArray(c, sizeof(c));
		}

		this.SetupPlayers();
	}

	void SetupPlayers() {
		for (int i = 0; i < this.teams.Length; i++) {
			char name[64];
			this.teams.GetString(i, name, sizeof(name));

			int[] players = new int[MaxClients];
			this.members.GetArray(i, players, MaxClients);

			int color[3];
			this.colors.GetArray(i, color, sizeof(color));

			for (int x = 0; x < MaxClients; x++) {
				int player = players[i];

				if (player > 0) {
					L4D2_SetEntityGlow(player, L4D2Glow_Constant, 0, 0, color, false);
					PrintToChat(player, "%s You are on team: %s", PREFIX, name);
				}
			}
		}
	}

	int GetTeam(int client) {
		for (int i = 0; i < this.members.Length; i++) {
			int[] players = new int[MaxClients];
			this.members.GetArray(i, players, MaxClients);

			for (int x = 0; x < MaxClients; x++) {
				if (client == players[i]) {
					return i;
				}
			}
		}

		return NO_TEAM;
	}

	bool IsMember(int client, int team = -1) {
		for (int i = 0; i < this.members.Length; i++) {
			if (team != -1 && team != i) {
				continue;
			}

			int[] players = new int[MaxClients];
			this.members.GetArray(i, players, MaxClients);

			for (int x = 0; x < MaxClients; x++) {
				if (client == players[i]) {
					return true;
				}
			}
		}

		return false;
	}

	bool AreTeammates(int client, int client2) {
		bool first;
		for (int i = 0; i < this.members.Length; i++) {
			first = false;

			int[] players = new int[MaxClients];
			this.members.GetArray(i, players, MaxClients);

			for (int x = 0; x < MaxClients; x++) {
				if (client == players[i] || client2 == players[i]) {
					if (first) {
						return true;
					}

					first = true;
				}
			}
		}

		return false;
	}

	void Clear() {
		this.teams.Clear();
		this.members.Clear();
		this.colors.Clear();

		this.totalteams = 0;
	}
}

Gamemode g_Gamemode;

public void OnPluginStart() {
	CreateConVar("sm_l4d2_ttc_version", "1.0.0", "Version control for this plugin.", FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_l4d2_ttc_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_MaxTeams = CreateConVar("sm_l4d2_ttc_max_teams", "2", "What should the maximum number of teams be?", FCVAR_NOTIFY, true, 2.0);
	convar_MaxPlayers = CreateConVar("sm_l4d2_ttc_max_players", "2", "What should the maximum number of players per team be?", FCVAR_NOTIFY, true, 2.0);
	//AutoExecConfig();

	g_Gamemode.Init();
}

//Called at the start of each campaign and the end of each campaign when survivors are allowed to move.
public void L4D_OnReleaseSurvivorPositions() {
	//Make sure the gamemode is enabled.
	if (!convar_Enabled.BoolValue) {
		return;
	}

	//We only want to setup everything on the first map of each campaign.
	if (!L4D_IsFirstMapInScenario()) {
		return;
	}

	g_Gamemode.Setup();
}

int GetPlayerCount(int team) {
	int count;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == team) {
			count++;
		}
	}

	return count;
}

stock int FindMember(int team = -1, int alive = -1, int bots = -1)
{
	ArrayList aClients = new ArrayList();

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && (team == -1 || (team == 5 && GetClientTeam(i) > 1) || GetClientTeam(i) == team) && (alive == -1 || IsPlayerAlive(i) == view_as<bool>(alive)) && (bots == -1 || IsFakeClient(i) == view_as<bool>(bots)) )
		{
			if (!g_Gamemode.IsMember(i)) {
				aClients.Push(i);
			}
		}
	}

	int client;

	if( aClients.Length > 0 )
	{
		SetRandomSeed(GetGameTickCount());
		client = aClients.Get(GetRandomInt(0, aClients.Length - 1));
	}

	delete aClients;

	return client;
}