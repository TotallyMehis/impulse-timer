#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <sqlx>

#include <impulse/defs>
#include <impulse/core>
#include <impulse/hud>
#include <impulse/stocks>



#define MAXPLAYERS 33


#define INVALID_MAP_ID                  0

#define MAX_PRESPEED                    300.0


#define DB_NAME             "impulse"

#define DB_TABLE_USERS      "imp_users"
#define DB_TABLE_MAPS       "imp_maps"
#define DB_TABLE_TIMES      "imp_times"


#define MAX_RECORDS_PRINT   10

#define WARNING_INTERVAL    3.0

#define MAX_FPS             250.0


// FORWARDS
new g_fwdTimerStartPost;
new g_fwdTimerReset;
new g_fwdTimerEndPost;
new g_fwdPlyIdPost;
new g_fwdSendSpec;

// TIMER
new g_iMapId = INVALID_MAP_ID;
new Float:g_flMapBestTime = INVALID_TIME;
new Float:g_flPlyBestTime[IMP_MAXPLAYERS];
new Float:g_flPlyStartTime[IMP_MAXPLAYERS];
new g_iPlyId[IMP_MAXPLAYERS];
// Some idiot mappers put multiple starting/ending buttons.
new Array:g_ArrButtons_Start;
new g_iNumButtons_Start;
new Array:g_ArrButtons_End;
new g_iNumButtons_End;
new Float:g_vecStartPos[3];
//new Float:g_vecStartAng[3];



// ENTITIES
new g_iCmdCheckEnt; // fps_max check ent


// DATABASE
new Handle:g_DB_Tuple;
new g_DB_szQuery[512];


// MISC.
new const g_szSounds[][] = { "buttons/bell1.wav", "vox/woop.wav" };
new const Float:g_vecNull[] = { 0.0, 0.0, 0.0 };
new g_szCurMap[64];
new CsTeams:g_iPrefferedTeam = CS_TEAM_CT;


// SETTINGS
new Float:g_flPlyWarning[IMP_MAXPLAYERS]; // Make sure players aren't spamming anything.


// CACHE
new g_iMaxPlys;
new g_sv_airaccelerate;



#include "impulse_core/cmds.sma"
#include "impulse_core/db.sma"
#include "impulse_core/dbcb.sma"

public plugin_init()
{
    register_plugin( IMP_PLUGIN_NAME + " - Core", IMP_PLUGIN_VERSION, IMP_PLUGIN_AUTHOR );



    // Forwards
    g_fwdTimerStartPost = CreateMultiForward( "impulse_on_start_post", ET_IGNORE, FP_CELL );
    g_fwdTimerReset = CreateMultiForward( "impulse_on_reset", ET_IGNORE, FP_CELL );
    g_fwdTimerEndPost = CreateMultiForward( "impulse_on_end_post", ET_IGNORE, FP_CELL, FP_FLOAT );

    g_fwdPlyIdPost = CreateMultiForward( "impulse_on_ply_id", ET_IGNORE, FP_CELL, FP_CELL );

    g_fwdSendSpec = CreateMultiForward( "impulse_on_send_spec", ET_IGNORE, FP_CELL );


    // Misc.
    g_iMaxPlys = get_maxplayers();

    g_sv_airaccelerate = get_cvar_pointer( "sv_airaccelerate" );
    
    if ( !g_sv_airaccelerate )
    {
        set_fail_state( CONSOLE_PREFIX + "Couldn't find pointer to sv_airaccelerate!" );
    }

    imp_getsafemapname( g_szCurMap, sizeof( g_szCurMap ) );
    



    dbConnect();
    


    // Triggers
    imp_registertriggers( "restart", "cmdSpawn" );
    imp_registertriggers( "recordsmenu", "cmdShowRecords" );
    imp_registertriggers( "commands", "cmdShowHelp" );
    imp_registertriggers( "noclip", "cmdNoclip" );
    imp_registertriggers( "spectate", "cmdSpectate" );


    // Blocked commands
    new const szCmdBlocked[] = "cmdBlocked";
    register_clcmd( "radio1", szCmdBlocked );
    register_clcmd( "radio2", szCmdBlocked );
    register_clcmd( "radio3", szCmdBlocked );
    register_clcmd( "roger", szCmdBlocked );
    register_clcmd( "negative", szCmdBlocked );
    register_clcmd( "enemyspot", szCmdBlocked );
    register_clcmd( "enemydown", szCmdBlocked );
    register_clcmd( "sectorclear", szCmdBlocked );
    register_clcmd( "getinpos", szCmdBlocked );
    register_clcmd( "takepoint", szCmdBlocked );
    register_clcmd( "holdpos", szCmdBlocked );
    register_clcmd( "inposition", szCmdBlocked );
    register_clcmd( "needbackup", szCmdBlocked );
    register_clcmd( "takingfire", szCmdBlocked );
    register_clcmd( "fallback", szCmdBlocked );
    register_clcmd( "regroup", szCmdBlocked );
    register_clcmd( "followme", szCmdBlocked );
    register_clcmd( "go", szCmdBlocked );
    register_clcmd( "sticktog", szCmdBlocked );
    register_clcmd( "stormfront", szCmdBlocked );
    register_clcmd( "getout", szCmdBlocked );
    register_clcmd( "reportingin", szCmdBlocked );
    register_clcmd( "report", szCmdBlocked );
    
    
    // Forwards
    register_forward( FM_PlayerPreThink, "fwdPlayerPreThink", true ); // Used for no stamina, autobhop and unlimited speedcap.
    register_forward( FM_PlayerPostThink, "fwdPlayerPostThink", true );
    register_forward( FM_Think, "fwdThink", true );
    RegisterHam( Ham_Use, "func_button", "fwdUse", true ); // Start/end button hooks.
    RegisterHam( Ham_Spawn, "player", "fwdPlySpawn", true );
    RegisterHam( Ham_Killed, "player", "fwdPlyDeath", true );
    //register_forward( FM_CmdStart, "fwdCmdStart" );
    register_forward( FM_GetGameDescription, "fwdGetGameDescription" );
    register_forward( FM_ClientKill, "fwdClientKill" );
    
    // Events
    register_message( get_user_msgid( "VGUIMenu" ), "eventVGUIMenu" );
    imp_onroundrestart( "eventRoundStart" );


    

    // Entities
    new const class_alloc = engfunc( EngFunc_AllocString, "info_target" );
    
    // Create cmd check entity.
    g_iCmdCheckEnt = engfunc( EngFunc_CreateNamedEntity, class_alloc );
    set_pev( g_iCmdCheckEnt, pev_classname, "plugin_cmdcheck" );
    set_pev( g_iCmdCheckEnt, pev_nextthink, get_gametime() + 1.5 );
}

public plugin_end()
{
    SQL_FreeHandle( g_DB_Tuple );
}

public impulse_on_ply_id( ply, plyid )
{
    dbUpdateDatabase( ply );

    dbGetPlyTime( ply );
}

public impulse_on_reset( ply )
{
    g_flPlyStartTime[ply] = INVALID_TIME;
}

public Handle:_impulse_getdb( id, num )
{
    return g_DB_Tuple;
}

public _impulse_getplyid( id, num )
{
    new ply = get_param( 1 );
    return g_iPlyId[ply];
}

public _impulse_getmapid( id, num )
{
    return g_iMapId;
}

public Float:_impulse_gettime( id, num )
{
    new ply = get_param( 1 );
    if ( g_flPlyStartTime[ply] == INVALID_TIME )
        return INVALID_TIME;

    return get_gametime() - g_flPlyStartTime[ply];
}

public Float:_impulse_getpbtime( id, num )
{
    new ply = get_param( 1 );
    return g_flPlyBestTime[ply];
}

public Float:_impulse_getsrtime( id, num )
{
    return g_flMapBestTime;
}

public plugin_natives()
{
    register_library( "impulse_core" );

    register_native( "impulse_getdb", "_impulse_getdb" );

    register_native( "impulse_getplyid", "_impulse_getplyid" );
    register_native( "impulse_getmapid", "_impulse_getmapid" );

    register_native( "impulse_gettime", "_impulse_gettime" );
    register_native( "impulse_getpbtime", "_impulse_getpbtime" );
    register_native( "impulse_getsrtime", "_impulse_getsrtime" );
}

public eventRoundStart()
{
    set_task( 0.1, "taskMapStuff" );
}

public plugin_precache()
{
    new const iSoundsLen = sizeof( g_szSounds );
    
    for ( new i = 0; i < iSoundsLen; i++ )
        precache_sound( g_szSounds[i] );    
}

public plugin_cfg()
{
    set_task( 0.1, "taskMapStuff" );
}

public fwdGetGameDescription()
{
    static const szName[] = "Bunnyhop";
    
    forward_return( FMV_STRING, szName );
    return FMRES_SUPERCEDE;
}

public fwdPlySpawn( ply )
{
    // Still have to check whether we're alive or not.
    if ( pev( ply, pev_deadflag ) == DEAD_NO )
    {
        set_pev( ply, pev_takedamage, 0 );

        sendResetFwd( ply );
        
        //client_cmd( ply, "cl_nosmooth 1" );
    }
}

public fwdPlyDeath( ply )
{
    sendResetFwd( ply );

    if ( pev( ply, pev_deadflag ) != DEAD_NO ) 
    {
        sendResetFwd( ply );
        
        //client_cmd( ply, "cl_nosmooth 0" );
    }
}

public fwdClientKill( ply )
{
    cmdSpectate( ply );
    return FMRES_SUPERCEDE;
}

public fwdThink( ent )
{
    if ( g_iCmdCheckEnt == ent )
    {
        handleCmdCheck();
        set_pev( ent, pev_nextthink, get_gametime() + 3.0 );
    }
}

public handleCmdCheck()
{
    static ply;
    for ( ply = 1; ply <= g_iMaxPlys; ply++ )
    {
        if ( !is_user_alive( ply ) || is_user_bot( ply ) ) continue;
        
        query_client_cvar( ply, "fps_max", "queryFpsMax" );
    }
}

public client_authorized( ply )
{
    g_iPlyId[ply] = 0;


    if ( !is_user_bot( ply ) )
    {
        dbGetPlyId( ply );
    }
}

public client_connect( ply )
{
    g_flPlyBestTime[ply] = INVALID_TIME;
    g_flPlyStartTime[ply] = INVALID_TIME;
    g_iPlyId[ply] = 0;
}

public client_disconnected( ply )
{
}

public client_putinserver( ply )
{
    sendResetFwd( ply );

    
    if ( !is_user_bot( ply ) )
    {
        set_task( 3.0, "taskSetPlyCvars", get_user_userid( ply ) );

        cmdSpawn( ply );
    }
}

public taskSetPlyCvars( userid )
{
    new ply = imp_getuserbyuserid( userid );
    if ( ply && is_user_connected( ply ) )
    {
        static ping, loss;
        get_user_ping( ply, ping, loss );
        
        //client_cmd( ply, "cl_smoothtime %.2f", ping / 1000.0 + ( g_flRate + 0.01 ) );
        
        new szName[MAX_NAME_LENGTH];
        get_user_name( ply, szName, sizeof( szName ) );
        
        client_print_color( ply, ply, CHAT_PREFIX + "Welcome, ^x03%s^x01! Chat commands: ^x04/start^x01, ^x04/wr^x01, ^x04/hide^x01, ^x04/help", szName );
        client_print_color( ply, ply, CHAT_PREFIX + "Recommended settings: fps_override 1, fps_max %.0f, cl_nosmooth 0, cl_smoothtime 0.1", MAX_FPS );
        client_print_color( ply, ply, CHAT_PREFIX + "Server settings: sv_airaccelerate %i", get_pcvar_num( g_sv_airaccelerate ) );
    }
}

public queryFpsMax( ply, const szCvar[], const szValue[] )
{
    static Float:flFps;
    flFps = str_to_float( szValue );
    
    if ( flFps > MAX_FPS )
    {
        if ( g_flPlyStartTime[ply] != INVALID_TIME )
        {
            client_print_color( ply, ply, CHAT_PREFIX + "Your fps was too high (^x03%.1f^x01)! Max fps is ^x03%.1f^x01!", flFps, MAX_FPS );
            
            client_cmd( ply, "fps_max %.1f", MAX_FPS );
            
            
            sendResetFwd( ply );
        }
    }
}

public eventVGUIMenu( msg_id, msg_dest, msg_entity )
{
    new menuid = get_msg_arg_int( 1 );

    if (menuid == 2 // Team select
    ||  menuid == 27) // Model select
    {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public taskMapStuff()
{
    // Find start and end buttons.
    new ent;
    new szTarget[17];
    
    g_ArrButtons_Start = ArrayCreate( 1, 1 );
    g_ArrButtons_End = ArrayCreate( 1, 1 );
    
    while ( (ent = engfunc( EngFunc_FindEntityByString, ent, "classname", "func_button" )) > 0 )
    {
        if ( pev_valid( ent ) )
        {
            pev( ent, pev_target, szTarget, 16 );
            
            if ( equal( szTarget, "counter_start" )
                || equal( szTarget, "clockstartbutton" )
                || equal( szTarget, "firsttimerelay" ) )
            {
                ArrayPushCell( g_ArrButtons_Start, ent );
                
                get_brush_entity_origin( ent, g_vecStartPos );
                g_vecStartPos[2] += 74.0;
            }
            else if ( equal( szTarget, "clockstop" )
                || equal( szTarget, "counter_off" )
                || equal( szTarget, "clockstopbutton" ) )
            {
                ArrayPushCell( g_ArrButtons_End, ent );
            }
        }
    }
    
    g_iNumButtons_Start = ArraySize( g_ArrButtons_Start );
    g_iNumButtons_End = ArraySize( g_ArrButtons_End );
    
    if ( g_iNumButtons_Start == 0 || g_iNumButtons_End == 0 )
    {
        set_fail_state( CONSOLE_PREFIX + "Couldn't find start and/or ending button!!" );
        return;
    }
    
    ent = 0;
    // Remove breakables because they are useless.
    while ( (ent = engfunc( EngFunc_FindEntityByString, ent, "classname", "func_breakable" )) > 0 )
        if ( pev_valid( ent ) )
            engfunc( EngFunc_RemoveEntity, ent );
    

    ent = 0;

    new Float:vecMoveDir[3];
    new Float:vecUp[3] = { 0.0, 0.0, 1.0 };

    // Lock doors so we can bhop on them better.
    while ( (ent = engfunc( EngFunc_FindEntityByString, ent, "classname", "func_door" )) > 0 )
        if ( pev_valid( ent ) )
        {
            // Check if it's a bhop block.
            new spawnflags = pev( ent, pev_spawnflags );

            // Not even solid?
            if ( spawnflags & SF_DOOR_PASSABLE ) continue;

            // Not going back automatically?
            if ( spawnflags & SF_DOOR_NO_AUTO_RETURN ) continue;

            // Only use key activates?
            if ( spawnflags & SF_DOOR_USE_ONLY ) continue;


            // If we're going up, ignore us.
            pev( ent, pev_movedir, vecMoveDir );

            if ( xs_vec_dot( vecMoveDir, vecUp ) > 0.0 ) continue;


            DispatchKeyValue( ent, "speed", 0 );
        }
            
    
    
    
    new const szCTSpawn[] = "info_player_start";
    new const szTSpawn[] = "info_player_deathmatch";

    
    ent = 0;
    g_iPrefferedTeam = CS_TEAM_UNASSIGNED;
    new iNumSpawns;
    new Float:vecSpawnPos[3];
    
    new Float:flClosestToStart;
    new Float:flDist;
    new ent_closest_to_start;
    // Find CT spawns. If they exist, use them.
    while ( (ent = engfunc( EngFunc_FindEntityByString, ent, "classname", szCTSpawn )) > 0 )
        if ( pev_valid( ent ) )
        {
            g_iPrefferedTeam = CS_TEAM_CT;
            iNumSpawns++;
            
            
            pev( ent, pev_origin, vecSpawnPos );
            
            flDist = get_distance_f( vecSpawnPos, g_vecStartPos );
            
            if ( flClosestToStart <= 0.0 || flDist < flClosestToStart )
            {
                flClosestToStart = flDist;
                ent_closest_to_start = ent;
            }
        }
    


    
    if ( g_iPrefferedTeam == CS_TEAM_UNASSIGNED )
    {
        ent = 0;
        // Find T spawns if no CT spawn is found.
        while ( (ent = engfunc( EngFunc_FindEntityByString, ent, "classname", szTSpawn )) > 0 )
            if ( pev_valid( ent ) )
            {
                g_iPrefferedTeam = CS_TEAM_T;
                iNumSpawns++;
                
                
                pev( ent, pev_origin, vecSpawnPos );
                
                flDist = get_distance_f( vecSpawnPos, g_vecStartPos );
                
                if ( flClosestToStart <= 0.0 || flDist < flClosestToStart )
                {
                    flClosestToStart = flDist;
                    ent_closest_to_start = ent;
                }
            }
    }
    
    if ( g_iPrefferedTeam == CS_TEAM_UNASSIGNED )
    {
        set_fail_state( CONSOLE_PREFIX + "No spawnpoints found!" );
        return;
    }
    
    // We found the closest spawnpoint to the button. Make that the default start position.
    if ( ent_closest_to_start > 0 && pev_valid( ent_closest_to_start ) )
    {
        pev( ent_closest_to_start, pev_origin, vecSpawnPos );
        
        g_vecStartPos = vecSpawnPos;
        //pev( ent_closest_to_start, pev_angles, vecSpawnAng );
    }
    
    ent = 0;
    // If we have too few spawns, make them at the starting position.
    while ( iNumSpawns < g_iMaxPlys )
    {
        ent = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, ( g_iPrefferedTeam == CS_TEAM_CT ) ? szCTSpawn : szTSpawn ) );
        
        set_pev( ent, pev_origin, vecSpawnPos );
        
        iNumSpawns++;
    }
}

public fwdPlayerPreThink( ply )
{
    if ( is_user_alive( ply ) )
    {
        // Solid to triggers. Only set in prethink and postthink.
        set_pev( ply, pev_solid, SOLID_SLIDEBOX );
        
        // No stamina
        set_pev( ply, pev_fuser2, 0.0 );
        
        // Hold space for ever!
        set_pev( ply, pev_oldbuttons, pev( ply, pev_oldbuttons ) &~ IN_JUMP );
        
        
        // No speedcap
        static const Float:flMaxSpeed = 250.0;
        
        if ( pev( ply, pev_flags ) & FL_ONGROUND )
        {
            if ( pev( ply, pev_button ) & IN_JUMP ) set_pev( ply, pev_maxspeed, 0.0 );
            else
            {
                set_pev( ply, pev_maxspeed, flMaxSpeed );
            }
        }
        else if ( pev( ply, pev_waterlevel ) > 1 ) set_pev( ply, pev_maxspeed, flMaxSpeed );
    }
}

public fwdPlayerPostThink( ply )
{
    if ( is_user_alive( ply ) ) set_pev( ply, pev_solid, SOLID_NOT ); // Not solid to players.
}

stock on_press_start( ply )
{
    // Get true speed
    new Float:spd = imp_getspeed3d( ply );
    new Float:maxspd = MAX_PRESPEED;

    if ( spd > maxspd )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "No prespeeding allowed! (Max ^x03%i ups^x01!)", floatround( maxspd ) );
        
        g_flPlyStartTime[ply] = INVALID_TIME;
        
        set_pev( ply, pev_velocity, g_vecNull );
        return;
    }
    
    
    g_flPlyStartTime[ply] = get_gametime();


    new ret;
    ExecuteForward( g_fwdTimerStartPost, ret, ply );

    
    client_print_color( ply, ply, CHAT_PREFIX + "Your timer has started! Go fast!" );
}

stock on_press_end( ply )
{
    if ( g_flPlyStartTime[ply] == INVALID_TIME )
    {
        return;
    }


    new Float:flNewTime = get_gametime() - g_flPlyStartTime[ply];


    new ret;
    ExecuteForward( g_fwdTimerEndPost, ret, ply, flNewTime );


    new bool:bFirstTime = g_flPlyBestTime[ply] == INVALID_TIME;
    new bool:bBeatOwn = (!bFirstTime) && flNewTime < g_flPlyBestTime[ply];
    new bool:bFirstMapBeat = g_flMapBestTime == INVALID_TIME;
    new bool:bIsBest = bFirstMapBeat || flNewTime < g_flMapBestTime;
    
    
    static szName[MAX_NAME_LENGTH];
    get_user_name( ply, szName, sizeof( szName ) );
    remove_quotes( szName );
    

    static szFormatted[9]; // "XX:XX.XX"
    imp_formatseconds( flNewTime, szFormatted, sizeof( szFormatted ), true );

    
    if ( bIsBest )
    {
        if ( bFirstMapBeat )
        {
            client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 was the first one to beat the map! ^x04(^x03%s^x04)", szName, szFormatted );
        }
        else
        {
            client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 beat the record! ^x04(^x03%s^x04)^x01 Improving ^x03%.2f^x01s!", szName, szFormatted, g_flMapBestTime - flNewTime );
        }
        

        g_flMapBestTime = flNewTime;
    }
    else if ( bBeatOwn )
    {
        client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 beat the map! ^x04(^x03%s^x04)^x01 Improving ^x03%.2f^x01s!", szName, szFormatted, g_flPlyBestTime[ply] - flNewTime );
    }
    else if ( bFirstTime )
    {
        client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 beat the map for the first time! ^x04(^x03%s^x04)", szName, szFormatted );
    }
    else
    {
        client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 beat the map! ^x04(^x03%s^x04)", szName, szFormatted );
    }

    
    g_flPlyStartTime[ply] = INVALID_TIME;
    


    emit_sound( 0, CHAN_AUTO, g_szSounds[bIsBest], VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
    

    // Finally, update SQL!
    if ( bFirstTime || bBeatOwn )
    {
        dbInsertTime( ply, flNewTime, bBeatOwn );

        g_flPlyBestTime[ply] = flNewTime;
    }
    
    set_pev( ply, pev_frags, pev( ply, pev_frags ) + 1 );
}

#define PRESSED_NONE    0
#define PRESSED_START    1
#define PRESSED_END    2

public fwdUse( button, ply, activator, type, Float:flValue )
{
    if ( !pev_valid( ply ) || ply > g_iMaxPlys ) return;
    
    new iPressed = PRESSED_NONE;
    
    new i;
    for ( i = 0; i < g_iNumButtons_Start; i++ )
        if ( ArrayGetCell( g_ArrButtons_Start, i ) == button )
        {
            iPressed = PRESSED_START;
            break;
        }
    
    if ( iPressed == PRESSED_NONE && g_flPlyStartTime[ply] != INVALID_TIME )
        for ( i = 0; i < g_iNumButtons_End; i++ )
            if ( ArrayGetCell( g_ArrButtons_End, i ) == button )
            {
                iPressed = PRESSED_END;
                break;
            }
    
    switch ( iPressed )
    {
        case PRESSED_START :
        {
            on_press_start( ply );
        }
        case PRESSED_END :
        {
            on_press_end( ply );
        }

    }
}

// public fwdCmdStart( ply, uc_handle, seed )
// {
//     if ( is_user_alive( ply ) && g_bPlyJump[ply] )
//     {
//         set_uc( uc_handle, UC_Buttons, get_uc( uc_handle, UC_Buttons ) | IN_JUMP );
//         return FMRES_HANDLED;
//     }
    
//     return FMRES_IGNORED;
// }

stock bool:isPlyAuthorized( ply )
{
    return g_iPlyId[ply] != 0;
}

stock getPlySteamId( ply, out[], len )
{
    get_user_authid( ply, out, len );
}

stock sendResetFwd( ply )
{
    new ret;
    return ExecuteForward( g_fwdTimerReset, ret, ply );
}

stock sendPlyIdFwd( ply )
{
    new ret;
    return ExecuteForward( g_fwdPlyIdPost, ret, ply, g_iPlyId[ply] );
}

stock toSpec( ply )
{
    cs_set_user_team( ply, CS_TEAM_SPECTATOR );
    set_pev( ply, pev_deadflag, DEAD_DEAD );
    set_pev( ply, pev_flags, pev( ply, pev_flags ) | FL_SPECTATOR );


    sendResetFwd( ply );


    new ret;
    ExecuteForward( g_fwdSendSpec, ret, ply );
}
