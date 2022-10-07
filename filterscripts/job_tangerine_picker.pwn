#include <a_samp>
#include "../include/streamer"
#include "../include/mdialog"

#undef MAX_PLAYER_NAME
    #define MAX_PLAYER_NAME             24
#define SPAWN_TREE                      3 // Сколько деревьев будет заспавнено
#define TREE_MODEL                      655 // Модель дерева
#define TREE_RENDER                     150.0 // Дистанция прогрузки
#define AREA_DISTANCE                   3.0 // Радиус действия зоны для подбирания предмета

new const Float:Tree_Position[SPAWN_TREE][6] = { // Позиции спавна
    {77.2846, -83.7600, 0.7090, 0.0, 0.0, 0.0}, // x, y, z, rx, ry, rz
    {77.8345, -72.5980, 0.6524, 0.0, 0.0, 0.0},
    {78.5406, -58.2631, 0.6094, 0.0, 0.0, 0.0}
};

enum treeinfo
{
    object, // Объект при создании
    dynamicArea // Динамическая зона
}
new treeInfo[SPAWN_TREE][treeinfo];

enum playertreeinfo
{
    bool:inDynamicArea // Находится ли игрок в динамической зоне
}
new pTreeInfo[MAX_PLAYERS][playertreeinfo];

public OnFilterScriptInit()
{
    for(new spawnt = 0; spawnt < SPAWN_TREE; spawnt++)
    {
        treeInfo[spawnt][object] = CreateDynamicObject(TREE_MODEL, Tree_Position[spawnt][0], Tree_Position[spawnt][1], Tree_Position[spawnt][2]-1.0, Tree_Position[spawnt][3], Tree_Position[spawnt][4], Tree_Position[spawnt][5], _, _, _, TREE_RENDER);
        treeInfo[spawnt][dynamicArea] = CreateDynamicCircle(Tree_Position[spawnt][0], Tree_Position[spawnt][1], AREA_DISTANCE, _, _, _); 
    }
    return 1;
}

public OnFilterScriptExit()
{
    return 1;
}

public OnPlayerConnect(playerid)
{
    PreloadAllAnimLibs(playerid);
    return 1;
}

public OnPlayerEnterDynamicArea(playerid, areaid)
{
    new string[40+(-2+1)+(-2+1)];
    for(new id = 0; id < SPAWN_TREE; id++)
    {
        if(areaid == treeInfo[id][dynamicArea])
        {
            if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
                return 1;
            pTreeInfo[playerid][inDynamicArea] = true;
            SendClientMessage(playerid, 0xFFFFFFFF, "Нажмите \"ALT\" чтобы собрать мандарины.");
            format(string, sizeof(string), "Вы зашли в зону действия #%d дерева #%d.", treeInfo[id][dynamicArea], treeInfo[id][object]);
            SendClientMessage(playerid, 0xFFFFFFFF, string);
        }
    }
    return 1;
}

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
    new string[40+(-2+1)+(-2+1)];
    for(new id = 0; id < SPAWN_TREE; id++)
    {
        if(areaid == treeInfo[id][dynamicArea])
        {
            if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
                return 1;
            pTreeInfo[playerid][inDynamicArea] = false;
            format(string, sizeof(string), "Вы вышли с зоны действия #%d дерева #%d.", treeInfo[id][dynamicArea], treeInfo[id][object]);
            SendClientMessage(playerid, 0xFFFFFFFF, string);
        }
    }
    return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    switch(newkeys)
    {
        case KEY_WALK:
        {
            if(pTreeInfo[playerid][inDynamicArea])
            {
                new rand = random(8);
                switch(rand)
                {
                    case 0..3:
                    {
                        SendClientMessage(playerid, 0xFFFFFFFF, "К сожалению не удалось ничего найти.");
                    }
                    case 4..7:
                    {
                        SendClientMessage(playerid, 0x00FF00FF, "Вы собрали 1 мандарин.");
                    }
                }
                pTreeInfo[playerid][inDynamicArea] = false;
            }
        }
    }
    return 1;
}

stock PreloadAnimLib(playerid, animlib[])
{
    return ApplyAnimation(playerid, animlib, "null", 0.0, 0, 0, 0, 0, 0);
}

stock PreloadAllAnimLibs(playerid)
{
    PreloadAnimLib(playerid, "ATTRACTORS");
    return 1;
}