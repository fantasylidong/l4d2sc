#if defined _shop_included_
 #endinput
#endif
#define _shop_included_

/**
* ��ȡ������İ汾
*
* @return				������汾��
*/
native Float:NMShop_GetVersion();

/**
* ��ȡ��ҵĻ�������
*
* @param client		��ҵ�����
* @return				��ҵĻ�������, ���ʧ�ܻ����û��Ϊ 0
*/
native NMShop_GetClientPoint(client)

/**
* ������ҵĻ�������
*
* @param client		��ҵ�����
* @param point		���õĻ�������
* @return				���Ϊ true ��ɹ�, ���� false
*/
native bool:NMShop_SetClientPoint(client, point)

/**
* ע��һ���˵���
*
* @param name		ע�������
* @return				�˵��������, ���� forward �ĵ���
*/
native NMShop_RegisterNewItem(String:name[])

/**
* ��ͣ��ע���һ���˵���
*
* @param index		�˵�������
* @return				��� true Ϊ�ɹ�, ���� false
*/
native bool:NMShop_UnRegisterNewItem(index)

/**
* �����ͣ��ע���һ���˵���
*
* @param index		�˵�������
* @return				��� true Ϊ�ɹ�, ���� false
*/
native bool:NMShop_ResetRegisterNewItem(index)

/**
* ��ȡĿǰ��ע��Ĳ˵��������
*
* @return				�˵��������
*/
native NMShop_GetRgeisterCount()

/**
* �����ѡ��һ���˵����ʱ�򴥷�
*
* @param client		�������
* @param index		�˵�����
* @return				û��
*/
forward NMShop_OnClientMenuItem(client, index)

/**
* ���������ʼʱ����
*
* @return				û��
*/
forward NMShop_OnPluginStart()

public SharedPlugin:__pl_shop = 
{
	name = "NMShop",
	file = "nmp_shop+.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};