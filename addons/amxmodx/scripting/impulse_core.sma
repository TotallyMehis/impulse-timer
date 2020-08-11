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


#define STYLE_FILE          "/configs/impulse_styles.ini"



#define MAX_RECORDS_PRINT   10

#define WARNING_INTERVAL    3.0


// FORWARDS
new g_fwdTimerStart;
new g_fwdTimerStartPost;
new g_fwdTimerReset;
new g_fwdTimerEnd;
new g_fwdTimerEndPost;
new g_fwdPlyIdPost;
new g_fwdSendSpec;
new g_fwdStyle;
new g_fwdStylePost;

// TIMER
new g_iMapId = INVALID_MAP_ID;
new Float:g_flMapBestTime[MAX_STYLES] = { INVALID_TIME, ... };
new Float:g_flPlyBestTime[IMP_MAXPLAYERS][MAX_STYLES];
new Float:g_flPlyTime[IMP_MAXPLAYERS];
new g_iPlyId[IMP_MAXPLAYERS];
new g_iPlyStyleId[IMP_MAXPLAYERS];
// Some idiot mappers put multiple starting/ending buttons.
new Array:g_ArrButtons_Start;
new g_iNumButtons_Start;
new Array:g_ArrButtons_End;
new g_iNumButtons_End;
new Float:g_vecStartPos[3];
//new Float:g_vecStartAng[3];
new bool:g_bHasStart = false;


// STYLE
new Array:g_arrStyles = Invalid_Array;
new g_nStyles = 0;
new g_iDefStyleId = INVALID_STYLE;
new Trie:g_trieStyleCmds = Invalid_Trie;


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


#include "impulse_core/cmds.sma"
#include "impulse_core/db.sma"
#include "impulse_core/dbcb.sma"

public plugin_init()
{
    register_plugin( IMP_PLUGIN_NAME + " - Core", IMP_PLUGIN_VERSION, IMP_PLUGIN_AUTHOR );


    g_trieStyleCmds = TrieCreate();
    g_arrStyles = ArrayCreate( STYLE_SIZE );

    g_nStyles = parseStyles();
    if ( g_nStyles <= 0 )
    {
        set_fail_state( CONSOLE_PREFIX + "No styles were parsed from file!" );
        return;
    }

    g_iDefStyleId = getDefaultStyle();
    if ( g_iDefStyleId == INVALID_STYLE )
    {
        set_fail_state( CONSOLE_PREFIX + "No default style exists!" );
        return;
    }


    // FORWARDS
    g_fwdTimerStart = CreateMultiForward( "impulse_on_start", ET_STOP2, FP_CELL );
    g_fwdTimerStartPost = CreateMultiForward( "impulse_on_start_post", ET_IGNORE, FP_CELL );
    g_fwdTimerReset = CreateMultiForward( "impulse_on_reset_post", ET_IGNORE, FP_CELL );
    g_fwdTimerEnd = CreateMultiForward( "impulse_on_end", ET_STOP2, FP_CELL, FP_ARRAY );
    g_fwdTimerEndPost = CreateMultiForward( "impulse_on_end_post", ET_IGNORE, FP_CELL, FP_ARRAY );

    g_fwdPlyIdPost = CreateMultiForward( "impulse_on_ply_id", ET_IGNORE, FP_CELL, FP_CELL );

    g_fwdSendSpec = CreateMultiForward( "impulse_on_send_spec", ET_IGNORE, FP_CELL );

    g_fwdStyle = CreateMultiForward( "impulse_on_style", ET_STOP2, FP_CELL, FP_CELL );
    g_fwdStylePost = CreateMultiForward( "impulse_on_style_post", ET_IGNORE, FP_CELL, FP_CELL );


    // Misc.
    g_iMaxPlys = get_maxplayers();

    imp_getsafemapname( g_szCurMap, charsmax( g_szCurMap ) );
    



    dbConnect();
    


    // Triggers
    imp_registertriggers( "restart", "cmdSpawn" );
    imp_registertriggers( "recordsmenu", "cmdShowRecords" );
    imp_registertriggers( "commands", "cmdShowHelp" );
    imp_registertriggers( "noclip", "cmdNoclip" );
    imp_registertriggers( "spectate", "cmdSpectate" );
    imp_registertriggers( "styles", "cmdStyleMenu" );

    new const cmdSay[] = "cmdSay";
    register_clcmd( "say", cmdSay );
    register_clcmd( "say_team", cmdSay );

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

public impulse_on_style_post( ply, styleid )
{
    sendResetFwd( ply );
}

public impulse_on_reset_post( ply )
{
    g_flPlyTime[ply] = INVALID_TIME;
}

public impulse_on_end_post( ply, const recordData[] )
{
    //new styleid = recordData[RECORDDATA_STYLE_ID];

    new Float:flNewTime = Float:recordData[RECORDDATA_TIME];
    new Float:flPrevTime = Float:recordData[RECORDDATA_PREV_PB_TIME];
    new Float:flPrevSRTime = Float:recordData[RECORDDATA_PREV_BEST_TIME];


    new bool:bFirstTime = flPrevTime == INVALID_TIME;
    new bool:bBeatOwn = (!bFirstTime) && flNewTime < flPrevTime;
    new bool:bFirstMapBeat = flPrevSRTime == INVALID_TIME;
    new bool:bIsBest = bFirstMapBeat || flNewTime < flPrevSRTime;



    static szName[MAX_NAME_LENGTH];
    get_user_name( ply, szName, charsmax( szName ) );
    remove_quotes( szName );
    

    static szFormatted[16]; // "XX:XX.XX"
    imp_formatseconds( flNewTime, szFormatted, charsmax( szFormatted ), true );

    
    if ( bIsBest )
    {
        if ( bFirstMapBeat )
        {
            client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 was the first one to beat the map! ^x04(^x03%s^x04)", szName, szFormatted );
        }
        else
        {
            client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 beat the record! ^x04(^x03%s^x04)^x01! (^x03-%.3f^x01s) Improving by ^x03%.3f^x01s!",
                szName,
                szFormatted,
                flPrevSRTime - flNewTime,
                flPrevTime - flNewTime );
        }
    }
    else if ( bBeatOwn )
    {
        client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 beat the map! ^x04(^x03%s^x04)^x01 Improving by ^x03%.3f^x01s!",
            szName,
            szFormatted,
            flPrevTime - flNewTime );
    }
    else if ( bFirstTime )
    {
        client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 beat the map for the first time! ^x04(^x03%s^x04)", szName, szFormatted );
    }
    else
    {
        client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 beat the map! ^x04(^x03%s^x04)", szName, szFormatted );
    }
    


    emit_sound( 0, CHAN_AUTO, g_szSounds[bIsBest ? 1 : 0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM );

    
    set_pev( ply, pev_frags, pev( ply, pev_frags ) + 1 );
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

public Float:_impulse_getplytime( id, num )
{
    new ply = get_param( 1 );
    return g_flPlyTime[ply];
}

public Float:_impulse_getplypbtime( id, num )
{
    new ply = get_param( 1 );
    new styleid = get_param( 2 );
    return g_flPlyBestTime[ply][styleid];
}

public Float:_impulse_getsrtime( id, num )
{
    new styleid = get_param( 1 );
    return g_flMapBestTime[styleid];
}

public bool:_impulse_isplyrunning( id, num )
{
    new ply = get_param( 1 );
    return g_flPlyTime[ply] != INVALID_TIME;
}

public bool:_impulse_getstylename( id, num )
{
    new styleIndex = getStyleIndexById( get_param( 1 ) );

    if ( styleIndex == -1 )
        return false;


    static szStyleName[STYLE_NAME_LENGTH];
    getStyleName( styleIndex, szStyleName, charsmax( szStyleName ) );

    new len = get_param( 3 );
    set_string( 2, szStyleName, len );

    return true;
}

public _impulse_getdefaultstyleid( id, num )
{
    return g_iDefStyleId;
}

public _impulse_getplystyleid( id, num )
{
    new ply = get_param( 1 );
    return g_iPlyStyleId[ply];
}

public bool:_impulse_setplystyle( id, num )
{
    new ply = get_param( 1 );
    new styleid = get_param( 2 );

    return setPlyStyle( ply, styleid );
}

public bool:_impulse_getstyledata( id, num )
{
    new styleid = get_param( 1 );

    new styleindex = getStyleIndexById( styleid );
    if ( styleindex == -1 )
    {
        return false;
    }


    static data[STYLE_SIZE];

    ArrayGetArray( g_arrStyles, styleindex, data, sizeof( data ) );

    set_array( 2, data, get_param( 3 ) );

    return true;
}

public plugin_natives()
{
    register_library( "impulse_core" );

    register_native( "impulse_getdb", "_impulse_getdb" );

    register_native( "impulse_getplyid", "_impulse_getplyid" );
    register_native( "impulse_getmapid", "_impulse_getmapid" );

    register_native( "impulse_getplytime", "_impulse_getplytime" );
    register_native( "impulse_getplypbtime", "_impulse_getplypbtime" );
    register_native( "impulse_getsrtime", "_impulse_getsrtime" );

    register_native( "impulse_isplyrunning", "_impulse_isplyrunning" );

    register_native( "impulse_getstylename", "_impulse_getstylename" );
    register_native( "impulse_getdefaultstyleid", "_impulse_getdefaultstyleid" );
    register_native( "impulse_getplystyleid", "_impulse_getplystyleid" );
    register_native( "impulse_setplystyle", "_impulse_setplystyle" );
    register_native( "impulse_getstyledata", "_impulse_getstyledata" );
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

public server_frame()
{
    new Float:frametime;
    global_get( glb_frametime, frametime );

    for ( new ply = 1; ply <= g_iMaxPlys; ply++ )
    {
        if ( !is_user_connected( ply ) ) continue;

        if ( !impulse_isplyrunning( ply ) ) continue;

        g_flPlyTime[ply] += frametime;
    }
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
        query_client_cvar( ply, "fps_override", "queryFpsOverride" );
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
    for ( new i = 0; i < sizeof( g_flPlyBestTime[] ); i++ )
    {
        g_flPlyBestTime[ply][i] = INVALID_TIME;
    }
    
    g_flPlyTime[ply] = INVALID_TIME;
    g_iPlyId[ply] = 0;
    g_iPlyStyleId[ply] = INVALID_STYLE;


    g_flPlyWarning[ply] = 0.0;
}

public client_disconnected( ply )
{
}

public client_putinserver( ply )
{
    setPlyStyle( ply, g_iDefStyleId );

    
    if ( !is_user_bot( ply ) )
    {
        new params[1];
        params[0] = get_user_userid( ply );

        set_task( 3.0, "taskSetPlyCvars", _, params, sizeof( params ) );

        set_task( 1.0, "taskSpawnPly", _, params, sizeof( params ) );
    }
}

public taskSpawnPly( params[] )
{
    new ply = imp_getuserbyuserid( params[0] );
    if ( ply )
    {
        if ( is_user_connected( ply ) )
        {
            set_pdata_int( ply, 121, _:CS_STATE_GET_INTO_GAME );
            set_task( 0.1, "taskSpawnPly2", _, params, 1 );
        }
        else
        {
            // Wait until they're fully connected.
            set_task( 0.1, "taskSpawnPly", _, params, 1 );
        }
    }
}

public taskSpawnPly2( params[] )
{
    new ply = imp_getuserbyuserid( params[0] );
    if ( ply )
    {
        cmdSpawn( ply );
    }
}

public taskSetPlyCvars( params[] )
{
    new ply = imp_getuserbyuserid( params[0] );
    if ( ply && is_user_connected( ply ) )
    {
        static ping, loss;
        get_user_ping( ply, ping, loss );
        
        //client_cmd( ply, "cl_smoothtime %.2f", ping / 1000.0 + ( g_flRate + 0.01 ) );
        
        new szName[MAX_NAME_LENGTH];
        get_user_name( ply, szName, charsmax( szName ) );
        
        client_print_color( ply, ply, CHAT_PREFIX + "Welcome, ^x03%s^x01! Chat commands: ^x04/start^x01, ^x04/wr^x01, ^x04/hide^x01, ^x04/help", szName );
    }
}

public queryFpsMax( ply, const szCvar[], const szValue[] )
{
    static Float:flFps;
    flFps = str_to_float( szValue );


    new Float:maxfps = -1.0;

    static styledata[STYLE_SIZE];
    if ( impulse_getstyledata( impulse_getplystyleid( ply ), styledata, sizeof( styledata ) ) )
    {
        maxfps = Float:styledata[STYLE_MAXFPS];
    }
    
    if ( maxfps > 0.0 && flFps > maxfps )
    {
        if ( impulse_isplyrunning( ply ) )
        {
            client_print_color( ply, ply, CHAT_PREFIX + "Your fps was too high (^x03%.1f^x01)! Max fps is ^x03%.1f^x01!", flFps, maxfps );
            
            client_cmd( ply, "fps_max %.1f", maxfps );
            
            
            sendResetFwd( ply );
        }
    }
}

public queryFpsOverride( ply, const szCvar[], const szValue[] )
{
    new bool:bOverride = str_to_num( szValue ) != 0;


    if ( bOverride )
    {
        // If the style's max fps is 99.5
        // make sure they have fps_override 0
        new Float:maxfps = -1.0;

        static styledata[STYLE_SIZE];
        if ( impulse_getstyledata( impulse_getplystyleid( ply ), styledata, sizeof( styledata ) ) )
        {
            maxfps = Float:styledata[STYLE_MAXFPS];
        }

        new bool:bNoOverride = floatabs( maxfps - 99.5 ) < 0.01;
        
        if ( bNoOverride )
        {
            if ( impulse_isplyrunning( ply ) )
            {
                client_print_color( ply, ply, CHAT_PREFIX + "Your^x03 fps_override^x01 value should be^x03 0^x01! Was %s!", szValue );
                
                client_cmd( ply, "fps_override 0" );
                
                
                sendResetFwd( ply );
            }
        }
    }

}

public eventVGUIMenu( msg_id, msg_dest, msg_entity )
{
    new menuid = get_msg_arg_int( 1 );


    server_print( CONSOLE_PREFIX + "eventVGUIMenu ply: %i | msg_id: %i | menu id: %i | time: %.1f", msg_dest, msg_id, menuid, get_gametime() );

    if (menuid == 2 // Team select
    ||  menuid == 27) // Model select
    {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public taskMapStuff()
{
    g_bHasStart = false;


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

                g_bHasStart = true;
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
        server_print( CONSOLE_PREFIX + "Couldn't find start and/or ending button for map '%s'!", g_szCurMap );
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
    {
        if ( !pev_valid( ent ) )
        {
            continue;
        }

        //
        // Check if it's a bhop block.
        //

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

        // If we have a name, we are probably activated by a button.
        // TODO: Check for button.
        new szName[32];
        szName[0] = 0;
        pev( ent, pev_targetname, szName, charsmax( szName ) );
        if ( szName[0] != '^0' )
        {
            continue;
        }


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
    {
        if ( !pev_valid( ent ) )
        {
            continue;
        }

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
        {
            if ( !pev_valid( ent ) )
            {
                continue;
            }

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
    }
}

public fwdPlayerPostThink( ply )
{
    if ( is_user_alive( ply ) )
    {
        set_pev( ply, pev_solid, SOLID_NOT ); // Not solid to players.
    }
}

stock on_press_start( ply )
{
    new styleid = g_iPlyStyleId[ply];

    if ( styleid == INVALID_STYLE )
    {
        server_print( CONSOLE_PREFIX + "Player %i had no style to start the timer!", ply );
        return;
    }


    //
    // Cap prespeed
    //
    static styledata[STYLE_SIZE];
    new Float:vel[3];
    pev( ply, pev_velocity, vel );
    new Float:spd = floatsqroot( vel[0] * vel[0] + vel[1] * vel[1] + vel[2] * vel[2] );
    new Float:maxspd = -1.0;
    
    if ( impulse_getstyledata( styleid, styledata, sizeof( styledata ) ) )
    {
        maxspd = Float:styledata[STYLE_MAXSPD];
    }

    if ( spd > 0.0 && maxspd >= 0.0 && spd > maxspd )
    {
        for ( new i = 0; i < 3; i++ )
        {
            vel[i] = vel[i] / spd * maxspd;
        }

        set_pev( ply, pev_velocity, vel );
    }

    set_pev( ply, pev_basevelocity, g_vecNull );



    new ret;

    
    ret = PLUGIN_CONTINUE;
    ExecuteForward( g_fwdTimerStart, ret, ply );
    
    if ( ret != PLUGIN_CONTINUE )
    {
        return;
    }
    
    new Float:frametime;
    global_get( glb_frametime, frametime );
    
    g_flPlyTime[ply] = frametime;


    ret = PLUGIN_CONTINUE;
    ExecuteForward( g_fwdTimerStartPost, ret, ply );

    
    client_print_color( ply, ply, CHAT_PREFIX + "Your timer has started! Go fast!" );
}

stock on_press_end( ply )
{
    if ( !impulse_isplyrunning( ply ) )
    {
        return;
    }


    new Float:flNewTime = g_flPlyTime[ply];
    new styleid = g_iPlyStyleId[ply];
    if ( styleid == INVALID_STYLE )
    {
        server_print( CONSOLE_PREFIX + "Finished a run but player had no style!" );
        return;
    }

    new Float:flPrevTime = g_flPlyBestTime[ply][styleid];
    new Float:flPrevSRTime = g_flMapBestTime[styleid];
    
    new ret;

    static recordData[RECORDDATA_SIZE];

    recordData[RECORDDATA_STYLE_ID] = styleid;
    recordData[RECORDDATA_TIME] = _:flNewTime;
    recordData[RECORDDATA_PREV_PB_TIME] = _:flPrevTime;
    recordData[RECORDDATA_PREV_BEST_TIME] = _:flPrevSRTime;


    g_flPlyTime[ply] = INVALID_TIME;


    ret = PLUGIN_CONTINUE;
    ExecuteForward( g_fwdTimerEnd, ret, ply, PrepareArray( recordData, sizeof( recordData ), 0 ) );

    if ( ret != PLUGIN_CONTINUE )
    {
        return;
    }


    new bool:bFirstTime = flPrevTime == INVALID_TIME;
    new bool:bBeatOwn = (!bFirstTime) && flNewTime < flPrevTime;
    new bool:bFirstMapBeat = flPrevSRTime == INVALID_TIME;
    new bool:bIsBest = bFirstMapBeat || flNewTime < flPrevSRTime;


    if ( bIsBest )
    {
        g_flMapBestTime[styleid] = flNewTime;
    }


    // Finally, update SQL!
    if ( bFirstTime || bBeatOwn )
    {
        dbInsertTime( ply, recordData );

        
        g_flPlyBestTime[ply][styleid] = flNewTime;
    }


    // Send forward
    ret = PLUGIN_CONTINUE;
    ExecuteForward( g_fwdTimerEndPost, ret, ply, PrepareArray( recordData, sizeof( recordData ), 0 ) );
}

public fwdUse( button, ply, activator, type, Float:flValue )
{
#define PRESSED_NONE    0
#define PRESSED_START    1
#define PRESSED_END    2


    if ( !pev_valid( ply ) || ply > g_iMaxPlys ) return;
    
    new iPressed = PRESSED_NONE;
    
    new i;
    for ( i = 0; i < g_iNumButtons_Start; i++ )
    {
        if ( ArrayGetCell( g_ArrButtons_Start, i ) == button )
        {
            iPressed = PRESSED_START;
            break;
        }
    }

    if ( iPressed == PRESSED_NONE )
    {
        for ( i = 0; i < g_iNumButtons_End; i++ )
        {
            if ( ArrayGetCell( g_ArrButtons_End, i ) == button )
            {
                iPressed = PRESSED_END;
                break;
            }
        }
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

stock parseStyles()
{
    new szFile[256];
    
    get_basedir( szFile, charsmax( szFile ) );
    add( szFile, charsmax( szFile ), STYLE_FILE );
    if ( !file_exists( szFile ) )
    {
        set_fail_state( CONSOLE_PREFIX + "Style file '%s' does not exist!", szFile );
        return -1;
    }


    new INIParser:parser = INI_CreateParser();

    INI_SetReaders( parser, "kvFunc_styles", "nsFunc_styles" );
    INI_ParseFile( parser, szFile );

    INI_DestroyParser( parser );

    return ArraySize( g_arrStyles );
}

public bool:nsFunc_styles( INIParser:handle, const section[], bool:invalid_tokens, bool:close_bracket, bool:extra_tokens, curtok, Array:arr )
{
    new style[STYLE_SIZE];

    copy( style[STYLE_NAME], STYLE_NAME_LENGTH - 1, section );

    ArrayPushArray( g_arrStyles, style );

    return true;
}

public bool:kvFunc_styles( INIParser:handle, const key[], const value[], bool:invalid_tokens, bool:equal_token, bool:quotes, curtok, Array:arr )
{
    new item = ArraySize( g_arrStyles ) - 1;

    new iValue = strtol( value, .base = 10 );
    new Float:flValue = strtof( value );

    if ( equali( key, "id" ) )
    {
        if ( iValue < 0 || iValue >= MAX_STYLES )
        {
            set_fail_state( CONSOLE_PREFIX + "Style id cannot be less than 0 or greater than %i! (was %i)", MAX_STYLES - 1, iValue );
            return false;
        }

        ArraySetCell( g_arrStyles, item, iValue, STYLE_ID );
    }
    else if ( equali( key, "default" ) )
    {
        ArraySetCell( g_arrStyles, item, iValue != 0 ? 1 : 0, STYLE_ISDEFAULT );
    }
    else if ( equali( key, "safename" ) )
    {
        new szName[STYLE_SAFENAME_LENGTH];
        copy( szName, charsmax( szName ), value );

        for ( new i = 0; i < STYLE_SAFENAME_LENGTH - 1; i++ )
        {
            ArraySetCell( g_arrStyles, item, szName[i], STYLE_SAFENAME + i );
        }
    }
    else if ( equali( key, "maxfps" ) )
    {
        ArraySetCell( g_arrStyles, item, flValue, STYLE_MAXFPS );
    }
    else if ( equali( key, "nostamina" ) )
    {
        ArraySetCell( g_arrStyles, item, iValue != 0, STYLE_NOSTAMINA );
    }
    else if ( equali( key, "airaccelerate" ) )
    {
        ArraySetCell( g_arrStyles, item, flValue, STYLE_AIRACCEL );
    }
    else if ( equali( key, "accelerate" ) )
    {
        ArraySetCell( g_arrStyles, item, flValue, STYLE_ACCEL );
    }
    else if ( equali( key, "stopspeed" ) )
    {
        ArraySetCell( g_arrStyles, item, flValue, STYLE_STOPSPD );
    }
    else if ( equali( key, "maxspeed" ) )
    {
        ArraySetCell( g_arrStyles, item, flValue, STYLE_MAXSPD );
    }
    else if ( equali( key, "maxjumpspeedfactor" ) )
    {
        ArraySetCell( g_arrStyles, item, flValue, STYLE_MAXJUMPSPEEDFACTOR );
    }
    else if ( equali( key, "autobhop" ) )
    {
        ArraySetCell( g_arrStyles, item, iValue != 0, STYLE_AUTOBHOP );
    }
    else if ( equali( key, "commands" ) )
    {
        if ( value[0] != 0 )
        {
            new styleid = getStyleId( item );

            new split[32];
            new i = 0;
            new j = 0;
            while ( (j = split_string( value[i], ",", split, charsmax( split ) )) != -1 )
            {
                i += j;
                TrieSetCell( g_trieStyleCmds, split, styleid );
            }

            // Add last.
            if ( value[i] != '^0' )
            {
                TrieSetCell( g_trieStyleCmds, value[i], styleid );
            }
        }
    }
    else if ( equali( key, "followkzrules" ) )
    {
        ArraySetCell( g_arrStyles, item, iValue != 0, STYLE_FOLLOWKZRULES );
    }
    else
    {
        server_print( CONSOLE_PREFIX + "Invalid style key '%s'!", value );
        return false;
    }

    return true;
}

stock bool:setPlyStyle( ply, styleid, print = false )
{
    new styleindex = getStyleIndexById( styleid );
    if ( styleindex == -1 ) // That style doesn't exist!
        return false;

    new result = sendStyleChange( ply, styleid );
    if ( result != PLUGIN_CONTINUE )
    {
        return false;
    }

    g_iPlyStyleId[ply] = styleid;


    if ( print )
    {
        new name[STYLE_NAME_LENGTH];
        getStyleName( styleindex, name, charsmax( name ) );
        client_print_color( ply, ply, CHAT_PREFIX + "Your style is now ^x03%s^x01!", name );
    }

    sendStyleChangePost( ply, styleid );

    return true;
}

stock sendStyleChange( ply, styleid )
{
    new ret = PLUGIN_CONTINUE;
    ExecuteForward( g_fwdStyle, ret, ply, styleid );

    return ret;
}

stock sendStyleChangePost( ply, styleid )
{
    new ret = PLUGIN_CONTINUE;
    ExecuteForward( g_fwdStylePost, ret, ply, styleid );
}

stock getStyleSafeName( item, out[], out_len )
{
    return ArrayGetString( g_arrStyles, item, out, out_len );
}

stock getStyleName( item, out[], out_len )
{
    static temp[STYLE_NAME_LENGTH];
    for ( new i = 0; i < STYLE_NAME_LENGTH - 1; i++ )
    {
        temp[i] = ArrayGetCell( g_arrStyles, item, STYLE_NAME + i );
    }

    copy( out, out_len, temp );
}

stock getStyleId( item )
{
    return ArrayGetCell( g_arrStyles, item, STYLE_ID );
}

stock bool:getStyleIsDefault( item )
{
    return ArrayGetCell( g_arrStyles, item, STYLE_ISDEFAULT ) != 0;
}

stock bool:getStyleNoStamina( item )
{
    return ArrayGetCell( g_arrStyles, item, STYLE_NOSTAMINA );
}

stock getStyleAirAccel( item )
{
    return ArrayGetCell( g_arrStyles, item, STYLE_AIRACCEL );
}

stock getStyleAccel( item )
{
    return ArrayGetCell( g_arrStyles, item, STYLE_ACCEL );
}

stock getStyleStopSpeed( item )
{
    return ArrayGetCell( g_arrStyles, item, STYLE_STOPSPD );
}

stock getStyleMaxSpeed( item )
{
    return ArrayGetCell( g_arrStyles, item, STYLE_MAXSPD );
}

stock getStyleMaxFps( item )
{
    return ArrayGetCell( g_arrStyles, item, STYLE_MAXFPS );
}

stock getStyleIndexById( styleid )
{
    for ( new i = 0; i < g_nStyles; i++ )
    {
        if ( styleid == getStyleId( i ) )
            return i;
    }

    return -1;
}

stock bool:styleExists( styleid )
{
    return getStyleIndexById( styleid ) != -1;
}

stock getDefaultStyle()
{
    for ( new i = 0; i < g_nStyles; i++ )
    {
        if ( getStyleIsDefault( i ) )
            return getStyleId( i );
    }

    return INVALID_STYLE;
}
