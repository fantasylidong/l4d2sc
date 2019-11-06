#if defined _nmrih_included_
	#endinput
#endif
#define _nmrih_included_

// ������ϵ�Ѫ������
stock bool:GetPlayerBlood(client)
{
	return (GetEntProp(client, Prop_Send, "_bloodinessLevel") > 0);
}

stock SetPlayerBlood(client, bool:blood)
{
	SetEntProp(client, Prop_Send, "_bloodinessLevel", (blood ? 2 : 0));
}

// ������Ѫ������
stock bool:GetWeaponBlood(entity)
{
	return (GetEntProp(entity, Prop_Send, "_bloodCount") > 0);
}

stock SetWeaponBlood(entity, bool:blood)
{
	SetEntProp(entity, Prop_Send, "_bloodCount", (blood ? 2 : 0));
}

// ��ҵ�ǰ����������
stock GetPlayerWeigth(client)
{
	return GetEntProp(client, Prop_Send, "_carriedWeight");
}

stock SetPlayerWeigth(client, count)
{
	SetEntProp(client, Prop_Send, "_carriedWeight", count);
}

// ��ҵ�ǰ������ֵ
stock Float:GetPlayerStamina(client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flStamina");
}

stock SetPlayerStamina(client, Float:count)
{
	SetEntPropFloat(client, Prop_Send, "m_flStamina", count);
}

// ����Ƿ����߸�Ⱦ
stock bool:GetPlayerImmunity(client)
{
	return (GetEntProp(client, Prop_Send, "_vaccinated") > 0);
}

stock SetPlayerImmunity(client, bool:immunity)
{
	GetEntProp(client, Prop_Send, "_vaccinated", (immunity ? 1 : 0));
}

// ��Ҹ���ȴ�ʱ��
stock Float:GetPlayerRespawnTime(client)
{
	return GetEntPropFloat(client, Prop_Send, "_nextRespawnTime");
}

stock SetPlayerRespawnTime(client, Float:count)
{
	SetEntPropFloat(client, Prop_Send, "_nextRespawnTime", count);
}

// ����Ƿ�������ɱ(��ǹָ���Լ�)
stock bool:GetPlayerSuicideing(client)
{
	return (GetEntProp(client, Prop_Send, "_contemplatingSuicide") > 0);
}

stock SetPlayerSuicideing(client, bool:suicide)
{
	SetEntProp(client, Prop_Send, "_contemplatingSuicide", (suicide ? 1 : 0));
}

// ����Ƿ�����ʹ�ù���(��ǹ����/��������)
stock bool:GetPlayerToolsUseing(client)
{
	return (GetEntProp(client, Prop_Send, "_usingToolSecondary") > 0);
}

stock SetPlayerToolsUseing(client, bool:useing)
{
	SetEntProp(client, Prop_Send, "_usingToolSecondary", (useing ? 1 : 0));
}

// ��ҵĸ��������
stock GetPlayerRespawnCount(client)
{
	return GetEntProp(client, Prop_Send, "m_iTokens");
}

stock SetPlayerRespawnCount(client, count)
{
	SetEntProp(client, Prop_Send, "m_iTokens", count);
}

// �����һ���Ƶ��ӳ�
stock Float:GetPlayerShovWait(client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flLastShoveTime");
}

stock SetPlayerShovWait(client, Float:nextShov)
{
	SetEntPropFloat(client, Prop_Send, "m_flLastShoveTime", nextShov);
}

// ����Ƿ��Ѫ
stock bool:GetPlayerLeedingOut(client)
{
	return (GetEntProp(client, Prop_Send, "_bleedingOut") > 0);
}

stock SetPlayerLeedingOut(client, bool:out)
{
	SetEntProp(client, Prop_Send, "_bleedingOut", (out ? 1 : 0));
}

// ����Ƿ񱻽�ʬץס��
stock bool:GetPlayerGrabbed(client)
{
	return (GetEntProp(client, Prop_Send, "m_bGrabbed") > 0);
}

stock SetPlayerGrabbed(client, bool:hook)
{
	SetEntProp(client, Prop_Send, "m_bGrabbed", (hook ? 1 : 0));
}

// ����Ƿ���Ϊ��Ⱦ������
stock bool:GetPlayerInfectedDeath(client)
{
	return (GetEntProp(client, Prop_Send, "m_bDiedWhileInfected") > 0);
}

stock SetPlayerInfectedDeath(client, bool:infected)
{
	SetEntProp(client, Prop_Send, "m_bDiedWhileInfected", (infected ? 1 : 0));
}

// ����Ƿ�����ʹ�û�е��׼
stock bool:GetPlayerGunAiming(client)
{
	return (GetEntProp(client, Prop_Send, "m_bStickyIronsight") > 0);
}

stock SetPlayerGunAiming(client, bool:aiming)
{
	SetEntProp(client, Prop_Send, "m_bStickyIronsight", (aiming ? 1 : 0));
}

// ����Ƿ���Ա���(����������û��Ѫ)
stock bool:GetPlayerAllowRun(client)
{
	return (GetEntProp(client, Prop_Send, "m_bSprintEnabled") > 0);
}

stock SetPlayerAllowRun(client, bool:allow)
{
	SetEntProp(client, Prop_Send, "m_bSprintEnabled", (allow ? 1 : 0));
}

// ����Ƿ�����ʹ�öԽ���˵��
stock bool:GetPlayerWalkieing(client)
{
	return (GetEntProp(client, Prop_Send, "m_bHasWalkieTalkie") > 0);
}

stock SetPlayerWalkieing(client, bool:walking)
{
	SetEntProp(client, Prop_Send, "m_bHasWalkieTalkie", (walking ? 1 : 0));
}

// ����Ƿ����ڱ���
stock bool:GetPlayerRunning(client)
{
	return (GetEntProp(client, Prop_Send, "m_bIsSprinting") > 0);
}

stock SetPlayerRunning(client, bool:runing)
{
	SetEntProp(client, Prop_Send, "m_bIsSprinting", (runing ? 1 : 0));
}

// ����Ƿ��ж���(����Ⱦ��)
stock bool:GetPlayerPoisoned(client)
{
	return (GetEntProp(client, Prop_Send, "m_bPoisoned") > 0);
}

stock SetPlayerPoisoned(client, bool:durg)
{
	SetEntProp(client, Prop_Send, "m_bPoisoned", (durg ? 1 : 0));
}

// ��Ҹ�Ⱦ�����������ʣ��ʱ��
stock Float:GetPlayerInfectedDeathTime(client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flInfectionDeathTime");
}

stock SetPlayerInfectedDeathTime(client, Float:time)
{
	SetEntPropFloat(client, Prop_Send, "m_flInfectionDeathTime", time);
}

// ��ұ���Ⱦ�˶೤ʱ��
stock Float:GetPlayerInfectedTime(client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flInfectionTime");
}

stock SetPlayerInfectedTime(client, Float:time)
{
	SetEntPropFloat(client, Prop_Send, "m_flInfectionTime", time);
}

// ��ҩ��
stock GetAmmoboxAmmo(entity)
{
	return GetEntProp(entity, Prop_Data, "m_iAmmoCount");
}

stock SetAmmoboxAmmo(client, count)
{
	SetEntProp(entity, Prop_Data, "m_iAmmoCount", count);
}

stock GetAmmoboxType(entity, String:type[], len)
{
	GetEntPropString(entity, Prop_Data, "m_szAmmoName", type, len);
}

stock SetAmmoboxType(entity, String:type[])
{
	SetEntPropString(entity, Prop_Data, "m_szAmmoName", type);
}

// ����
stock GetActiveWeapon(client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

// �������
stock RespawnPlayer(client, Float:pos[3] = NULL_VECTOR, Float:ang[3] = NULL_VECTOR)
{
	int ent = CreateEntityByName("info_player_nmrih");
	
	if(pos[0] != NULL_VECTOR[0] || pos[1] != NULL_VECTOR[1] || pos[2] != NULL_VECTOR[2])
		DispatchKeyValueVector(ent, "origin", pos);
	
	if(ang[0] != NULL_VECTOR[0] || ang[1] != NULL_VECTOR[1] || ang[2] != NULL_VECTOR[2])
		DispatchKeyValueVector(ent, "angles", ang);
	
	DispatchSpawn(ent);
	SetVariantString("OnUser1 !self:Kill::3:1");
	AcceptEntityInput(ent, "AddOutput");
	AcceptEntityInput(ent, "FireUser1");
	
	DispatchSpawn(client);
	SetEntProp(client, Prop_Send, "m_iPlayerState", 0);
	SetEntProp(client, Prop_Send, "m_iHideHUD", 2050);
	TeleportEntity(client, pos, ang, NULL_VECTOR);
}

/*
stock GetPlayerWeapon(client, const char[] weapon)
{
	static offs;
	if(offs <= 0)
		offs = FindSendPropOffs("CNMRiH_Player", "m_hMyWeapons");
	if(offs <= 0)
		return -1;
	
	new entity = -1, String:classname[128] = "";
	for(new i = 0; i <= 192; i += 4)
	{
		entity = GetEntDataEnt2(client, offs + i);
		if(!IsValidEntity(entity))
			continue;
		
		GetEntityClassname(entity, classname, 128);
		if(strcmp(classname, weapon, false) == 0)
			return entity;
	}
	
	return 0;
}
*/