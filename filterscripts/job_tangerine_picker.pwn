#include <a_samp>
#include "../include/streamer"
#include "../include/mdialog"

#undef MAX_PLAYER_NAME
    #define MAX_PLAYER_NAME             24
#define SPAWN_TREE                      3 // Сколько деревьев будет заспавнено
#define TREE_MODEL                      655 // Модель дерева
#define TREE_RENDER                     150.0 // Дистанция прогрузки
#define TREE_COOLDOWN                   60 // Через сколько секунд игрок вновь сможет забрать мандарины с дерева
#define AREA_DISTANCE                   3.0 // Радиус действия зоны для подбирания предмета

#define C_F_GREEN                       0x00FF00FF
#define C_GREEN                         "{00FF00}"
#define C_F_RED                         0xFF0000FF
#define C_RED                           "{FF0000}"
#define C_F_ORANGE                      0xFFAA00FF
#define C_ORANGE                        "{FFAA00}"

new Text:Help_TextDraw;
new const Float:Tree_Position[SPAWN_TREE][6] = { // Позиции спавна
    {77.2846, -83.7600, 0.7090, 0.0, 0.0, 0.0}, // x, y, z, rx, ry, rz
    {77.8345, -72.5980, 0.6524, 0.0, 0.0, 0.0},
    {78.5406, -58.2631, 0.6094, 0.0, 0.0, 0.0}
};

enum treeinfo
{
    tObject, // Объект при создании
    tDynamicArea // Динамическая зона
}
new treeInfo[SPAWN_TREE][treeinfo];

enum playertreeinfo
{
    ptCooldown // Время до появления мандаринов (каждому игроку свой)
}
new pTreeInfo[MAX_PLAYERS][SPAWN_TREE][playertreeinfo];

enum playerinfo
{
    pSecondTimer, // Секундный таймер
    pAnimationTimer, // Таймер для анимации
    bool:pInDynamicArea, // Находится ли игрок в динамической зоне
    pDynamicArea
}
new pInfo[MAX_PLAYERS][playerinfo];

public OnFilterScriptInit()
{
    CreateTextDrawsForServer();
    for(new spawnt = 0; spawnt < SPAWN_TREE; spawnt++)
    {
        treeInfo[spawnt][tObject] = CreateDynamicObject(TREE_MODEL, Tree_Position[spawnt][0], Tree_Position[spawnt][1], Tree_Position[spawnt][2]-1.0, Tree_Position[spawnt][3], Tree_Position[spawnt][4], Tree_Position[spawnt][5], _, _, _, TREE_RENDER);
        treeInfo[spawnt][tDynamicArea] = CreateDynamicCircle(Tree_Position[spawnt][0], Tree_Position[spawnt][1], AREA_DISTANCE, _, _, _); 
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
    pInfo[playerid][pAnimationTimer] = EOS;
    pInfo[playerid][pInDynamicArea] = false;
    pInfo[playerid][pDynamicArea] = EOS;
    for(new tree = 0; tree < SPAWN_TREE; tree++)
    {
        pTreeInfo[playerid][tree][ptCooldown] = EOS;
    }
    return pInfo[playerid][pSecondTimer] = SetTimerEx("PlayerSecondTimer", 1000, true, "i", playerid);
}

public OnPlayerEnterDynamicArea(playerid, areaid)
{
    for(new id = 0; id < SPAWN_TREE; id++)
    {
        if(areaid == treeInfo[id][tDynamicArea])
        {
            if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
                return 1;
            pInfo[playerid][pInDynamicArea] = true;
            pInfo[playerid][pDynamicArea] = areaid;
            TextDrawShowForPlayer(playerid, Help_TextDraw);
            // SendClientMessage(playerid, C_F_ORANGE, "Нажмите \"ALT\" чтобы собрать мандарины.");
        }
    }
    return 1;
}

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
    for(new id = 0; id < SPAWN_TREE; id++)
    {
        if(areaid == treeInfo[id][tDynamicArea])
        {
            if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
                return 1;
            pInfo[playerid][pInDynamicArea] = false;
            pInfo[playerid][pDynamicArea] = EOS;
            TextDrawHideForPlayer(playerid, Help_TextDraw);
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
            if(pInfo[playerid][pInDynamicArea])
            {
                ApplyAnimation(playerid, "INT_HOUSE", "WASH_UP", 4.0, 1, 0, 0, 1, 0, 1);
                pInfo[playerid][pAnimationTimer] = SetTimerEx("PlayerStopAnimation", 5250, false, "i", playerid);
            }
        }
    }
    return 1;
}

forward PlayerStopAnimation(playerid);
public PlayerStopAnimation(playerid)
{
    ApplyAnimation(playerid, "PED", "FACANGER", 4.0, 0, 0, 0, 0, 0, 1);
    for(new tree = 0; tree < SPAWN_TREE; tree++)
    {
        if(treeInfo[tree][tDynamicArea] == pInfo[playerid][pDynamicArea])
        {
            if(pTreeInfo[playerid][tree][ptCooldown] > 0)
            {
                SendClientMessage(playerid, C_F_ORANGE, "Вы уже собирали мандарины с данного дерева. Попробуйте позже.");
                break;
            }
            else
            {
                new rand = random(8);
                switch(rand)
                {
                    case 0..3:
                    {
                        SendClientMessage(playerid, C_F_RED, "К сожалению не удалось ничего найти.");
                    }
                    case 4..7:
                    {
                        SendClientMessage(playerid, C_F_GREEN, "Вы собрали мандарин.");
                    }
                }
                pTreeInfo[playerid][tree][ptCooldown] = TREE_COOLDOWN;
                break;
            }
        }
    }
    pInfo[playerid][pInDynamicArea] = false;
    TextDrawHideForPlayer(playerid, Help_TextDraw);
    return KillTimer(pInfo[playerid][pAnimationTimer]);
}

forward PlayerSecondTimer(playerid);
public PlayerSecondTimer(playerid)
{
    for(new tree = 0; tree < SPAWN_TREE; tree++)
    {
        if(pTreeInfo[playerid][tree][ptCooldown] > 0)
            pTreeInfo[playerid][tree][ptCooldown]--;
    }
    return 1;
}

stock PreloadAnimLib(playerid, animlib[])
{
    return ApplyAnimation(playerid, animlib, "null", 0.0, 0, 0, 0, 0, 0);
}

stock PreloadAllAnimLibs(playerid)
{
    PreloadAnimLib(playerid, "INT_HOUSE");
    PreloadAnimLib(playerid, "PED");
    return 1;
}

stock CreateTextDrawsForServer()
{
    #include ../include/others/textdraw
}