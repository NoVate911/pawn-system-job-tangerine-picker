/*

Автор: NoVate
GitHub: https://github.com/NoVate911/pawn-system-job-tangerine-picker

Название: Tangerine Picker Job System (Сборщик мандаринов)

Описание:
- Сборщик мандаринов является уникальной подработкой/работой для сервера SA:MP/CR:MP. Добавив её на свой сервер вы можете сделать как функционал связанный с потребностями игрока, также функционал связанный с продажей и заработком валюты.
- Данный скрипт написан на FS (Filterscript) и легко добавляется в вашу сборку.

Функционал:
* Создание деревьев (можно указать модель дерева, координаты и при запуске сервера будет созданы деревья на нужных координатах)
* Сбор мандаринов (подходя к дереву высвечивается подсказка)
* Таймер на сборку мандаринов (нельзя каждый раз собирать мандарины, на них есть таймер (что-то типа роста мандаринов))
* Рандомное выпадение мандаринов (при сборе мандарины как могут выпать, так могут и не выпасть)
* Скупка мандаринов (указываете цену за мандарин и координаты пикапа)

Затрачено времени для создания: ~2 часа

Доработать/Изменить:
* Выдача денег после продажи

*/

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
#define PRICE_SELL                      25 // Цена продажи одного мандарина

#define C_F_WHITE                       0xFFFFFFFF
#define C_WHITE                         "{FFFFFF}"
#define C_F_GREEN                       0x00FF00FF
#define C_GREEN                         "{00FF00}"
#define C_F_RED                         0xFF0000FF
#define C_RED                           "{FF0000}"
#define C_F_ORANGE                      0xFFAA00FF
#define C_ORANGE                        "{FFAA00}"

#define dCreate:%0(%1)                  DialogCreate:%0(%1) // Входит в инклуд mdialog
#define dResponse:%0(%1)                DialogResponse:%0(%1, response, listitem, inputtext[]) // Входит в инклуд mdialog

new Text:Help_GTextDraw, // Серверный текстдрав, который отображает подсказку на кнопку ALT
    PlayerText:Count_PTextDraw[MAX_PLAYERS]; // Клиенсткий текстдрав, который отображает количество собранных мандаринов
new const Float:Tree_Position[SPAWN_TREE][6] = { // Позиции спавна деревьев
    {77.2846, -83.7600, 0.7090, 0.0, 0.0, 0.0}, // x, y, z, rx, ry, rz
    {77.8345, -72.5980, 0.6524, 0.0, 0.0, 0.0},
    {78.5406, -58.2631, 0.6094, 0.0, 0.0, 0.0}
};
new const Float:Pickup_Sell_Position[3] = { 92.7060, -69.0484, 0.9792 }; // Позиция спавна пикапа для продажи мандаринов

enum treeinfo // Информация о деревьях (серверная)
{
    tObject, // Объект при создании
    tDynamicArea // Динамическая зона
}
new treeInfo[SPAWN_TREE][treeinfo];

enum playertreeinfo // Информация о деревьях (клиентская)
{
    ptCooldown // Время до появления мандаринов (каждому игроку свой)
}
new pTreeInfo[MAX_PLAYERS][SPAWN_TREE][playertreeinfo];

enum playerinfo // Информация о игре (клиентская)
{
    pSecondTimer, // Секундный таймер
    pAnimationTimer, // Таймер для анимации
    bool:pInDynamicArea, // Находится ли игрок в динамической зоне
    pDynamicArea, // В какой зоне находится игрок
    pCount // Количество собранных мандаринов
}
new pInfo[MAX_PLAYERS][playerinfo];

public OnFilterScriptInit()
{
    CreateTextDrawsForServer(); // Создаём серверные текстдравы
    CreateDynamicPickup(1274, 0, Pickup_Sell_Position[0], Pickup_Sell_Position[1], Pickup_Sell_Position[2], _, _, _, 150.0); // Создаём пикап для продажи
    CreateDynamic3DTextLabel("Скупка мандаринов\n"C_WHITE"Нажмите \"ALT\" для продажи", C_F_ORANGE, Pickup_Sell_Position[0], Pickup_Sell_Position[1], Pickup_Sell_Position[2]+1.0, 5.0); // Создаём текст над пикапом продажи
    for(new spawnt = 0; spawnt < SPAWN_TREE; spawnt++)
    {
        treeInfo[spawnt][tObject] = CreateDynamicObject(TREE_MODEL, Tree_Position[spawnt][0], Tree_Position[spawnt][1], Tree_Position[spawnt][2]-1.0, Tree_Position[spawnt][3], Tree_Position[spawnt][4], Tree_Position[spawnt][5], _, _, _, TREE_RENDER); // Создаём деревья
        treeInfo[spawnt][tDynamicArea] = CreateDynamicCircle(Tree_Position[spawnt][0], Tree_Position[spawnt][1], AREA_DISTANCE, _, _, _); // Создаём динамическую зону для собирания мандаринов
    }
    return 1;
}

public OnFilterScriptExit()
{
    return 1;
}

public OnPlayerConnect(playerid)
{
    if(IsPlayerNPC(playerid)) // Проверка на НПС
        return 1;
    CreateTextDrawsForPlayer(playerid); // Создаём клиентские текстдравы
    PreloadAllAnimLibs(playerid); // Подгружаем анимации

    /*      Обнуляем информацию о игроке        */
    pInfo[playerid][pSecondTimer] = EOS;
    pInfo[playerid][pAnimationTimer] = EOS;
    pInfo[playerid][pInDynamicArea] = false;
    pInfo[playerid][pDynamicArea] = EOS;

    for(new tree = 0; tree < SPAWN_TREE; tree++)
        pTreeInfo[playerid][tree][ptCooldown] = EOS; // Обнуляем информацию о деревьях (клиентская)
    return pInfo[playerid][pSecondTimer] = SetTimerEx("PlayerSecondTimer", 1000, true, "i", playerid); // Создаём ежесекундный таймер и записываем его
}

public OnPlayerSpawn(playerid)
{
    if(IsPlayerNPC(playerid))
        return 1;
    PlayerTextDrawShow(playerid, Count_PTextDraw[playerid]); // Показываем клиенсткий текстдрав о количестве собранных мандаринов
    return 1;
}

public OnPlayerEnterDynamicArea(playerid, areaid)
{
    if(IsPlayerNPC(playerid))
        return 1;
    for(new id = 0; id < SPAWN_TREE; id++)
    {
        if(areaid == treeInfo[id][tDynamicArea])
        {
            if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT) // Если игрок не стоит (находится в транспорте и так далее)
                return 1;
            pInfo[playerid][pInDynamicArea] = true; // Ставим правду то, что игрок в зоне сбора
            pInfo[playerid][pDynamicArea] = areaid; // Ставим номер зоны сбора
            TextDrawShowForPlayer(playerid, Help_GTextDraw); // Показываем серверный текстдрав игроку
        }
    }
    return 1;
}

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
    if(IsPlayerNPC(playerid))
        return 1;
    for(new id = 0; id < SPAWN_TREE; id++)
    {
        if(areaid == treeInfo[id][tDynamicArea])
        {
            if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
                return 1;
            pInfo[playerid][pInDynamicArea] = false; // Ставим ложь то, что игрок в зоне сбора
            pInfo[playerid][pDynamicArea] = EOS; // Обнуляем номер зоны сбора
            TextDrawHideForPlayer(playerid, Help_GTextDraw); // Скрываем серверный текстдрав игроку
        }
    }
    return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    switch(newkeys)
    {
        case KEY_WALK: // Если нажата клавиша ALT
        {
            if(pInfo[playerid][pInDynamicArea]) // Если игрок в зоне сбора
            {
                ApplyAnimation(playerid, "INT_HOUSE", "WASH_UP", 4.0, 1, 0, 0, 1, 0, 1); // Включаем анимацию
                pInfo[playerid][pAnimationTimer] = SetTimerEx("PlayerStopAnimation", 5250, false, "i", playerid); // Ставим таймер на 5 секунд и 250 миллисекунд
            }
            else if(IsPlayerInRangeOfPoint(playerid, 2.0, Pickup_Sell_Position[0], Pickup_Sell_Position[1], Pickup_Sell_Position[2])) // Если игрок стоит около пикапа скупки мандаринов
            {
                if(GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
                    return 1;
                if(pInfo[playerid][pCount] <= 0) // Если мандаринов меньше или они равны 0
                    return SendClientMessage(playerid, C_F_RED, "Для сдачи нужно собрать немного мандаринов.");
                Dialog_Show(playerid, Dialog:PlayerSell); // Открываем диалоговое окно
            }
        }
    }
    return 1;
}

/*      Остановка анимации после того, как игрок собрал мандарин        */
forward PlayerStopAnimation(playerid);
public PlayerStopAnimation(playerid)
{
    ApplyAnimation(playerid, "PED", "FACANGER", 4.0, 0, 0, 0, 0, 0, 1); // Ставим "стандартную" анимацию
    new string[11+(-2+6)];
    for(new tree = 0; tree < SPAWN_TREE; tree++)
    {
        if(treeInfo[tree][tDynamicArea] == pInfo[playerid][pDynamicArea]) // Проверяем находится ли игрок в зоне дерева по данным игрока
        {
            if(pTreeInfo[playerid][tree][ptCooldown] > 0) // Если таймер больше 0
                SendClientMessage(playerid, C_F_ORANGE, "Вы уже собирали мандарины с данного дерева. Попробуйте позже.");
            else // Если таймер меньше или равен 0
            {
                new rand = random(8); // Выпадает рандомное число
                switch(rand)
                {
                    case 0..2: SendClientMessage(playerid, C_F_RED, "К сожалению не удалось ничего найти.");
                    case 3..7:
                    {
                        SendClientMessage(playerid, C_F_GREEN, "Вы нашли мандарин.");
                        pInfo[playerid][pCount]++; // Плюсуем игроку собранные мандарины
                        format(string, sizeof(string), "COЂPAHO: %d", pInfo[playerid][pCount]);
                        PlayerReloadTextDraw(playerid, Count_PTextDraw[playerid], string); // Перезагружаем текстдрав
                    }
                }
                pTreeInfo[playerid][tree][ptCooldown] = TREE_COOLDOWN; // Ставим таймер на дерево, которое было собрано или не собрано
            }
            break; // Выходим с цикла
        }
    }
    pInfo[playerid][pInDynamicArea] = false; // Ставим то, что игрок не находится в зоне (дабы устранить авто-клик)
    TextDrawHideForPlayer(playerid, Help_GTextDraw);
    return KillTimer(pInfo[playerid][pAnimationTimer]); // Удаляем таймер анимации
}

dCreate:PlayerSell(playerid)
{
    new price = pInfo[playerid][pCount] * PRICE_SELL; // Высчитываем цену за все мандарины
    static const message[] = "\
    \\c"C_WHITE"В данный момент у вас "C_ORANGE"%d "C_WHITE"мандаринов.\n\
    \\cЦена одного мандарина: "C_ORANGE"%d$"C_WHITE".\n\n\
    \\cСтоимость продажи всех мандаринов составит: "C_ORANGE"%d$"C_WHITE".\n";
    new string[sizeof(message)+(-2+6)+(-2+3)+(-2+11)];
    format(string, sizeof(string), message, pInfo[playerid][pCount], PRICE_SELL, price);
    return Dialog_Open(playerid, Dialog:PlayerSell, DIALOG_STYLE_MSGBOX, "Скупка мандаринов", string, "Продать", "Закрыть");
}

dResponse:PlayerSell(playerid)
{
    if(response)
    {
        new price = pInfo[playerid][pCount] * PRICE_SELL;
        new string[40+(-2+6)+(-2+11)];
        format(string, sizeof(string), "Вы продали %d мандаринов и получили %d$.", pInfo[playerid][pCount], price);
        pInfo[playerid][pCount] = EOS; // Ставим то, что кол-во собранных мандаринов равно 0
        GivePlayerMoney(playerid, price); // Прибавляем деньги игроку
        PlayerReloadTextDraw(playerid, Count_PTextDraw[playerid], "COЂPAHO: 0");
    }
    return 1;
}

/*      Ежесекундный таймер для высчитывания времени        */
forward PlayerSecondTimer(playerid);
public PlayerSecondTimer(playerid)
{
    for(new tree = 0; tree < SPAWN_TREE; tree++)
    {
        if(pTreeInfo[playerid][tree][ptCooldown] > 0) // Если таймер больше 0
            pTreeInfo[playerid][tree][ptCooldown]--; // Делаем минус 1 к таймеру
    }
    return 1;
}

/*      Список анимаций, которые будут подгружены       */
stock PreloadAllAnimLibs(playerid)
{
    PreloadAnimLib(playerid, "INT_HOUSE");
    PreloadAnimLib(playerid, "PED");
    return 1;
}

stock PreloadAnimLib(playerid, animlib[])
{
    return ApplyAnimation(playerid, animlib, "null", 0.0, 0, 0, 0, 0, 0);
}

/*      Перезагрузка текстдрава (для более удобной работы + меньшее кол-во строк кода)      */
stock PlayerReloadTextDraw(playerid, PlayerText:textdraw, text[])
{
    PlayerTextDrawHide(playerid, textdraw);
    PlayerTextDrawSetString(playerid, textdraw, text);
    return PlayerTextDrawShow(playerid, textdraw);
}

/*      Выбираем серверные текстдравы       */
stock CreateTextDrawsForServer()
{
    #include ../include/others/global_textdraw
}

/*      Выбираем клиентские текстдравы      */
stock CreateTextDrawsForPlayer(playerid)
{
    #include ../include/others/player_textdraw
}