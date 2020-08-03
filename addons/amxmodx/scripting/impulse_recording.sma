#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>

#include <impulse/defs>
#include <impulse/core>
#include <impulse/recording>
#include <impulse/stocks>



#define BOT_PLAYERMODEL         "models/player/gign/gign.mdl"
#define BOT_PLAYERMODEL_NAME    "gign"

#define BOT_DEFAULT_NAME        "SR: N/A | /replay"


#define MAGIC_NUMBER            0x4B1C
#define MAGIC_NUMBER_OLD        0x4B1B // No style or recording rate data
#define MAGIC_NUMBER_OLDEST     0x4B1A // Different frame structure

#define FRAMEFLAG_DUCK          ( 1 << 0 )


// How many times a second we record the player's state.
#define RECORDING_RATE          33

// Maximum recording length in minutes
#define MAX_RECORDING_LENGTH    30


// Header structure:
// MAGIC NUMBER
// SERVER TICKRATE
// RECORDING RATE
// TIME
// STYLE
// PLAYER NAME
// RECORDING LENGTH (NUM OF FRAMES)

enum _:FrameData
{
    Float:FRAME_POS[3] = 0,
    Float:FRAME_ANGLES[2],
    FRAME_FLAGS
};
#define FRAME_SIZE        6


// RECORDING
new Array:g_ArrPlyRecording[IMP_MAXPLAYERS];
new bool:g_bPlyRecording[IMP_MAXPLAYERS];
new bool:g_bPlyMimicing[IMP_MAXPLAYERS];
new g_iPlyTick[IMP_MAXPLAYERS];
new Float:g_flRecordingAccumFrametime[IMP_MAXPLAYERS];


new g_iRecordingMaxLen = MAX_RECORDING_LENGTH * 60 * RECORDING_RATE;


// REPLAY BOT
new g_iRecBot = 0;
new Array:g_ArrCurReplay = Invalid_Array;
new Float:g_flCurReplayTime = INVALID_TIME;
new g_iCurReplayTickMax = 0;
new g_szCurReplayName[MAX_NAME_LENGTH];
new g_iCurReplayStyle = INVALID_STYLE;

new Float:g_flReplayAccumFrametime = 0.0;
new Float:g_flReplayFrameInterval;


//
new Array:g_ArrBest[MAX_STYLES] = { Invalid_Array, ... };
new Float:g_flBestTimes[MAX_STYLES] = { INVALID_TIME, ... };
new g_szBestNames[MAX_STYLES][MAX_NAME_LENGTH];
new g_nBestFrameRate[MAX_STYLES];


// CACHE
new g_iMaxPlys;
new g_szCurMap[64];
new g_szRecordingPath[256];

new Float:g_vecNull[] = { 0.0, 0.0, 0.0 };


new Float:g_flRecordingFrameInterval;
new g_pServerTicRate;



public plugin_init()
{
    register_plugin( IMP_PLUGIN_NAME + " - Recording", IMP_PLUGIN_VERSION, IMP_PLUGIN_AUTHOR );


    // Forwards
    register_forward( FM_ClientUserInfoChanged, "fwdClientUserInfoChanged" );


    g_flReplayFrameInterval = 1.0 / RECORDING_RATE;
    g_flRecordingFrameInterval = 1.0 / RECORDING_RATE;


    // Misc.
    g_iMaxPlys = get_maxplayers();
    if ( !(g_pServerTicRate = get_cvar_pointer( "sys_ticrate" )) )
    {
        set_fail_state( CONSOLE_PREFIX + "Failed to get cvar 'sys_ticrate' pointer!" );
    }

    imp_getsafemapname( g_szCurMap, charsmax( g_szCurMap ) );

    setRecordingPath();
}

public bool:_impulse_isrecordbot( id, num )
{
    new ply = get_param( 1 );

    return g_iRecBot == ply;
}

public bool:_impulse_getrecordinginfo( id, num )
{
    new ply = get_param( 1 );

    set_param_byref( 2, _:g_iCurReplayStyle );
    set_param_byref( 3, _:g_flCurReplayTime );


    new len = get_param( 5 );
    set_string( 4, g_szCurReplayName, len );

    return g_iRecBot == ply;
}

public plugin_natives()
{
    register_library( "impulse_recording" );

    register_native( "impulse_isrecordbot", "_impulse_isrecordbot" );
    register_native( "impulse_getrecordinginfo", "_impulse_getrecordinginfo" );
}

public plugin_cfg()
{
    new numLoaded = loadRecordings();

    server_print( CONSOLE_PREFIX + "Loaded %i recordings!", numLoaded );


    createRecordBot();
    startRecordBot();
}

public plugin_end()
{
    for ( new i = 0; i < sizeof( g_ArrPlyRecording ); i++ )
    {
        if ( g_ArrPlyRecording[i] != Invalid_Array )
        {
            ArrayDestroy( g_ArrPlyRecording[i] );
        }
    }

    for ( new i = 0; i < MAX_STYLES; i++ )
    {
        if ( g_ArrBest[i] != Invalid_Array )
        {
            ArrayDestroy( g_ArrBest[i] );
        }
    }

    // Current replay should always point at best replays.
    g_ArrCurReplay = Invalid_Array;

}

public plugin_precache()
{
    if ( precache_model( BOT_PLAYERMODEL ) <= 0 )
    {
        set_fail_state( CONSOLE_PREFIX + "Failed to precache bot player model '%s'!", BOT_PLAYERMODEL );
    }
}

public client_connect( ply )
{
    g_bPlyMimicing[ply] = false;
    g_bPlyRecording[ply] = false;

    g_flRecordingAccumFrametime[ply] = 0.0;
}

public client_disconnected( ply, bool:drop, message[], maxlen )
{
    g_bPlyMimicing[ply] = false;
    g_bPlyRecording[ply] = false;

    if ( ply == g_iRecBot )
    {
        g_iRecBot = 0;
    }
}

public impulse_on_start_post( ply )
{
    initPlyRecording( ply );
    g_iPlyTick[ply] = 0;
    g_bPlyRecording[ply] = true;

    g_flRecordingAccumFrametime[ply] = 0.0;
    insertFrame( ply );
}

public impulse_on_reset_post( ply )
{
    g_bPlyRecording[ply] = false;
    g_iPlyTick[ply] = 0;
}

public impulse_on_end_post( ply, const recordData[] )
{
    new Float:time = Float:recordData[RECORDDATA_TIME];
    new Float:prevbest = Float:recordData[RECORDDATA_PREV_BEST_TIME];
    new styleid = recordData[RECORDDATA_STYLE_ID];

    new bool:bIsBest = prevbest == INVALID_TIME || time < prevbest;
    new bool:bRecordingExists = g_ArrBest[styleid] != Invalid_Array;

    // Assign the record to a bot.
    if ( g_bPlyRecording[ply] && (bIsBest || !bRecordingExists) )
    {
        server_print( CONSOLE_PREFIX + "Saving new record recording %i!", ply );

        saveRecording( ply, recordData );
        
        copyForRecordBot( ply, recordData );
    }

    g_bPlyRecording[ply] = false;
}

public impulse_on_send_spec( ply )
{
    if ( hasRecordBot() )
    {
        set_pev( ply, pev_iuser1, OBS_IN_EYE );
        set_pev( ply, pev_iuser2, g_iRecBot );
    }
}

public server_frame()
{
    static Float:frametime;
    global_get( glb_frametime, frametime );

    static i;

    static frame[FRAME_SIZE];
    static Float:vecNewPos[3];
    static Float:vecNewAngles[3];
    static Float:vecPrevPos[3];
    static Float:vecNextPos[3];
    static Float:vecOldPos[3];
    static Float:vecPrevAngles[3];
    static Float:vecNextAngles[3];



    //
    // Replay bot mimic
    //
    if ( hasRecordBot() && g_bPlyMimicing[g_iRecBot] && g_ArrCurReplay != Invalid_Array )
    {
        new curTick = ( g_iPlyTick[g_iRecBot] < 0 ) ? 0 : g_iPlyTick[g_iRecBot];
        new nextTick = ( g_iPlyTick[g_iRecBot] < 0 ) ? 0 : (g_iPlyTick[g_iRecBot] + 1);
        if ( nextTick >= g_iCurReplayTickMax )
            nextTick = g_iCurReplayTickMax - 1;


        // Copy next position.
        ArrayGetArray( g_ArrCurReplay, nextTick, frame );

        CopyArray( frame[FRAME_POS], vecNextPos, 3 );
        CopyArray( frame[FRAME_ANGLES], vecNextAngles, 2 );
        vecNextAngles[2] = 0.0;

        // Copy last position.
        ArrayGetArray( g_ArrCurReplay, curTick, frame );

        CopyArray( frame[FRAME_POS], vecPrevPos, 3 );
        CopyArray( frame[FRAME_ANGLES], vecPrevAngles, 2 );
        vecPrevAngles[2] = 0.0;


        // Interpolate the position and angles
        new Float:frac = g_flReplayAccumFrametime / g_flReplayFrameInterval;

        // Position
        for ( i = 0; i < 3; i++ )
        {
            vecNewPos[i] = vecPrevPos[i] + (vecNextPos[i] - vecPrevPos[i]) * frac;
        }
        

        // Angles

        // Pitch can be interpolated easily
        vecNewAngles[0] = vecPrevAngles[0] + (vecNextAngles[0] - vecPrevAngles[0]) * frac;
        vecNewAngles[2] = 0.0; // Roll should always be 0 anyway

        // Yaw is a different story. It goes from +180 to -180
        vecNewAngles[1] = lerpAngle( vecPrevAngles[1], vecNextAngles[1], frac );



        // Set position
        pev( g_iRecBot, pev_origin, vecOldPos );
        set_pev( g_iRecBot, pev_oldorigin, vecOldPos );
        set_pev( g_iRecBot, pev_origin, vecNewPos );

        // Set angle
        set_pev( g_iRecBot, pev_fixangle, 1 );
        set_pev( g_iRecBot, pev_v_angle, vecNewAngles );
        set_pev( g_iRecBot, pev_angles, vecNewAngles );



        g_flReplayAccumFrametime += frametime;

        if ( g_flReplayAccumFrametime >= g_flReplayFrameInterval )
        {
            g_flReplayAccumFrametime -= g_flReplayFrameInterval;
            g_iPlyTick[g_iRecBot]++;
        }


        if ( g_iPlyTick[g_iRecBot] >= g_iCurReplayTickMax )
        {
            g_bPlyMimicing[g_iRecBot] = false;
            
            new params[1];
            params[0] = get_user_userid( g_iRecBot );
            set_task( 0.5, "taskPlaybackRestart", _, params, sizeof( params ) );
        }
        

        

        set_pev( g_iRecBot, pev_basevelocity, g_vecNull );
        for ( i = 0; i < 3; i++ )
        {
            vecNewPos[i] = (vecNextPos[i] - vecPrevPos[i]) / g_flReplayFrameInterval;
        }
        
        set_pev( g_iRecBot, pev_velocity, vecNewPos );



        // Misc.
        if ( frame[FRAME_FLAGS] & FRAMEFLAG_DUCK )
        {
            set_pev( g_iRecBot, pev_flags, pev( g_iRecBot, pev_flags ) | FL_DUCKING );
            //set_pev( g_iRecBot, pev_gaitsequence, 3 );
            //set_pev( g_iRecBot, pev_frame, 0.0 );
        }
        else
        {
            //static const Float:vecViewOff[] = { 0.0, 0.0, 17.0 };
            //set_pev( ply, pev_view_ofs, vecViewOff );
            set_pev( g_iRecBot, pev_flags, pev( g_iRecBot, pev_flags ) &~ FL_DUCKING );
        }
    }


    //
    // Recording
    //
    static ply;
    for ( ply = 1; ply <= g_iMaxPlys; ply++ )
    {
        if ( g_bPlyRecording[ply] )
        {
            g_flRecordingAccumFrametime[ply] += frametime;

            if ( g_flRecordingAccumFrametime[ply] >= g_flRecordingFrameInterval )
            {
                g_flRecordingAccumFrametime[ply] -= g_flRecordingFrameInterval;


                g_iPlyTick[ply]++;

                // Check if too long.
                if ( g_iPlyTick[ply] >= g_iRecordingMaxLen )
                {
                    //client_print_color( ply, ply, CHAT_PREFIX + "Stopped recording your run. Cannot be longer than ^x03%i^x01 minutes.", MAX_RECORDING_LENGTH );

                    g_bPlyRecording[ply] = false;
                    initPlyRecording( ply );
                    
                    continue;
                }


                insertFrame( ply );
            }
        }
    }
    
    //g_flLastRecThink = flCurTime;
}

public CopyArray( const any:oldArray[], any:newArray[], size )
{
    static i;
    for ( i = 0; i < size; i++ )
        newArray[i] = oldArray[i];
}

public taskPlaybackRestart( params[] )
{
    new ply = imp_getuserbyuserid( params[0] );
    if ( ply && is_user_bot( ply ) )
    {
        start_next_replay();
    }
}

stock createRecordBot()
{
    new szName[MAX_NAME_LENGTH];
    copy( szName, charsmax( szName ), BOT_DEFAULT_NAME );
    
    new bot = engfunc( EngFunc_CreateFakeClient, szName );
    
    if ( !bot )
    {
        server_print( CONSOLE_PREFIX + "Couldn't create record bot!" );
        return false;
    }
    
    dllfunc( MetaFunc_CallGameEntity, "player", bot );

    
    cs_set_user_team( bot, CS_TEAM_CT );
    ExecuteHam( Ham_CS_RoundRespawn, bot );
    fm_give_item( bot, "weapon_knife" );
    
    //if ( !is_user_alive( bot ) ) cs_user_spawn( bot );
    

    set_pev( bot, pev_takedamage, 0 ); // DAMAGE_NO
    set_pev( bot, pev_movetype, MOVETYPE_NOCLIP );
    //set_pev( bot, pev_movetype, MOVETYPE_FLY );
    set_pev( bot, pev_gravity, 0.0 );
    
    set_pev( bot, pev_solid, SOLID_NOT );

    // Bot has to be drawn or otherwise it cannot be spectated.
    // Although, it can be set to be invisible through rendering.
    fm_set_user_rendering( bot, kRenderFxNone, 255, 255, 255, kRenderNormal, 255 );
    set_pev( bot, pev_effects, pev( bot, pev_effects ) &~ EF_NODRAW );
    
    set_pev( bot, pev_frags, 1337 );
    
    set_user_info( bot, "*bot", "1" ); // For BOT-sign in scoreboard
    

    set_pev( bot, pev_iuser1, 0 );

    cs_set_user_model( bot, BOT_PLAYERMODEL, true );
    
    // Rest I don't know about
    // set_user_info( bot, "model", "gordon" );
    // set_user_info( bot, "rate", "3500" );
    // //set_user_info( bot, "cl_lw","0" );
    // //set_user_info( bot, "cl_lc","0" );
    // set_user_info( bot, "tracker", "0" );
    // set_user_info( bot, "cl_dlmax", "128" );
    // set_user_info( bot, "lefthand", "1" );
    // set_user_info( bot, "friends", "0" );
    // set_user_info( bot, "dm", "0" );
    // set_user_info( bot, "_ah", "0" );
    // set_user_info( bot, "_vgui_menus", "0" );
    
    //set_user_info( bot, "_cl_autowepswitch", "1" );
    
    set_pev( bot, pev_spawnflags, pev( bot, pev_spawnflags ) | FL_FAKECLIENT );
    set_pev( bot, pev_flags, pev( bot, pev_flags ) | FL_FAKECLIENT );
    
    
    g_iRecBot = bot;

    return true;
}

stock startRecordBot()
{
    if ( !hasRecordBot() )
        return;
    

    setRecordBotName();

    start_next_replay();
}

stock saveRecording( ply, const recordData[] )
{
    new Array:arr = g_ArrPlyRecording[ply];

    if ( arr == Invalid_Array )
    {
        return -1;
    }
    
    new len = ArraySize( arr );
    if ( !len )
    {
        return 0;
    }
    

    static szFile[256];
    formatex( szFile, charsmax( szFile ), "%s/style_%i.rec", g_szRecordingPath, recordData[RECORDDATA_STYLE_ID] );
    
    new file = fopen( szFile, "wb" );
    
    
    // Write the header.
    fwrite( file, MAGIC_NUMBER, BLOCK_INT );
    fwrite( file, get_pcvar_num( g_pServerTicRate ), BLOCK_INT );
    fwrite( file, RECORDING_RATE, BLOCK_INT );
    fwrite( file, Float:recordData[RECORDDATA_TIME], BLOCK_INT );
    fwrite( file, recordData[RECORDDATA_STYLE_ID], BLOCK_INT );
    
    new szName[MAX_NAME_LENGTH];
    get_user_name( ply, szName, charsmax( szName ) );
    
    for ( new i = 0; i < sizeof( szName ); i++ )
        fwrite( file, szName[i], BLOCK_CHAR );
        
    fwrite( file, len, BLOCK_INT );
    
    // Write frames.
    new frame[FRAME_SIZE];
    for ( new i = 0; i < len; i++ )
    {
        ArrayGetArray( arr, i, frame );
        
        fwrite_blocks( file, frame, FRAME_SIZE, BLOCK_INT );
    }
    
    fclose( file );

    return len;
}

stock Array:readRecording( filename[], &Float:time, &styleid, name[], &framerate )
{
    if ( !file_exists( filename ) )
    {
        return Invalid_Array;
    }


    new file = fopen( filename, "rb" );

    if ( !file )
    {
        return Invalid_Array;
    }
    

    new iMagic;
    fread( file, iMagic, BLOCK_INT );

    new bool:bLatestVersion = iMagic == MAGIC_NUMBER;
    new bool:bOldFrameStruct = iMagic == MAGIC_NUMBER_OLDEST;

    new bool:bMagicOk = bLatestVersion || bOldFrameStruct || iMagic == MAGIC_NUMBER_OLD;
    
    if ( !bMagicOk )
    {
        server_print( CONSOLE_PREFIX + "Tried to read from a record file with a different magic number!" );
        fclose( file );
        
        return Invalid_Array;
    }
    
    new iTickRate;
    fread( file, iTickRate, BLOCK_INT );

    if ( bLatestVersion )
    {
        fread( file, framerate, BLOCK_INT );
    }
    //
    // Old versions had 66 frames per second.
    //
    else
    {
        framerate = 66;
    }
    
    fread( file, time, BLOCK_INT );
    server_print( CONSOLE_PREFIX + "Record bot's time: %.2fsec", time );

    if ( bLatestVersion )
        fread( file, styleid, BLOCK_INT );
    
    for ( new i = 0; i < MAX_NAME_LENGTH; i++ )
        fread( file, name[i], BLOCK_CHAR );
        
    if ( strlen( g_szCurReplayName ) < 1 )
        formatex( g_szCurReplayName, charsmax( g_szCurReplayName ), "N/A" );
    
    
    new iTickCount;
    fread( file, iTickCount, BLOCK_INT );
    if ( iTickCount <= 0 )
    {
        fclose( file );
        return Invalid_Array;
    }
    
    new frame[FRAME_SIZE];


    new Array:hndl = ArrayCreate( _:FrameData );

    if ( bOldFrameStruct )
    {
        server_print( CONSOLE_PREFIX + "Reading old recording!" );

        new temp;
        for ( new i = 0; i < iTickCount; i++ )
        {
            fread_blocks( file, frame, 5, BLOCK_INT );
            fread( file, temp, BLOCK_INT );
            fread( file, frame[FRAME_FLAGS], BLOCK_INT );
            
            ArrayPushArray( hndl, frame ); 
        }
    }
    else
    {
        for ( new i = 0; i < iTickCount; i++ )
        {
            fread_blocks( file, frame, FRAME_SIZE, BLOCK_INT );
            
            ArrayPushArray( hndl, frame ); 
        }
    }

    
    fclose( file );

    return hndl;
}

stock bool:hasRecordBot()
{
    return g_iRecBot > 0;
}

public fwdClientUserInfoChanged( ply )
{
    // Hide bot name change.
    if ( ply == g_iRecBot )
    {
        new szOldName[32];
        pev( ply, pev_netname, szOldName, charsmax( szOldName ) );
        if( szOldName[0] )
        {
            new szNewName[32];
            get_user_info( ply, "name", szNewName, charsmax( szNewName ) );
            if( !equal( szOldName, szNewName ) )
            {
                set_pev( ply, pev_netname, szNewName );
                return FMRES_HANDLED;
            }
        }
    }

    return FMRES_IGNORED;
}

stock bool:copyForRecordBot( ply, const recordData[] )
{
    new Array:arr = g_ArrPlyRecording[ply];

    if ( arr == Invalid_Array )
    {
        return false;
    }

    if ( !hasRecordBot() )
    {
        return false;
    }


    new styleid = recordData[RECORDDATA_STYLE_ID];


    if ( g_ArrBest[styleid] != Invalid_Array )
    {
        ArrayDestroy( g_ArrBest[styleid] );
    }

    g_ArrBest[styleid] = ArrayClone( arr );
    g_flBestTimes[styleid] = Float:recordData[RECORDDATA_TIME];
    g_nBestFrameRate[styleid] = RECORDING_RATE;
    get_user_name( ply, g_szBestNames[styleid], charsmax( g_szBestNames[] ) );


    startReplay( styleid );

    return true;
}

stock setRecordBotName()
{
    new bot = g_iRecBot;

    new bool:bHasRecord = g_iCurReplayTickMax > 0;

    new szName[MAX_NAME_LENGTH];
    if ( bHasRecord )
    {
        new szFormatted[32];
        new szStyle[32];

        imp_formatseconds( g_flCurReplayTime, szFormatted, charsmax( szFormatted ) );
        impulse_getstylename( g_iCurReplayStyle, szStyle, charsmax( szStyle ) );
        
        formatex( szName, charsmax( szName ), "SR: %s | %s | %s", szFormatted, szStyle, g_szCurReplayName );
    }
    else
    {
        copy( szName, charsmax( szName ), BOT_DEFAULT_NAME );
    }

    set_user_info( bot, "name", szName );
}

stock initPlyRecording( ply )
{
    if ( g_ArrPlyRecording[ply] != Invalid_Array )
    {
        ArrayClear( g_ArrPlyRecording[ply] );
    }
    else
    {
        g_ArrPlyRecording[ply] = ArrayCreate( _:FrameData );
    }
}

stock Float:getDistSqr( const Float:vec1[3], const Float:vec2[3] )
{
    static Float:vec[3];
    static i;
    
    for ( i = 0; i < 3; i++ )
    {
        if ( vec1[i] > vec2[i] )
        {
            vec[i] = vec1[i] - vec2[i];
        }
        else
        {
            vec[i] = vec2[i] - vec1[i];
        }
    }
    
    return ( vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] );
}

stock setRecordingPath()
{
    g_szRecordingPath[0] = 0;

    get_basedir( g_szRecordingPath, charsmax( g_szRecordingPath ) );

    add( g_szRecordingPath, charsmax( g_szRecordingPath ), "/data" );
    if ( !dir_exists( g_szRecordingPath ) )
    {
        set_fail_state( "Failed to find directory '%s' to save recordings into!", g_szRecordingPath );
        return;
    }


    add( g_szRecordingPath, charsmax( g_szRecordingPath ), "/impulse_recordings" );
    
    if ( !dir_exists( g_szRecordingPath ) )
    {
        if ( mkdir( g_szRecordingPath ) == -1 )
        {
            set_fail_state( "Failed to create directory '%s' to save recordings into!", g_szRecordingPath );
            return;
        }
    }

    format( g_szRecordingPath, charsmax( g_szRecordingPath ), "%s/%s", g_szRecordingPath, g_szCurMap );
    
    if ( !dir_exists( g_szRecordingPath ) )
    {
        if ( mkdir( g_szRecordingPath ) == -1 )
        {
            set_fail_state( "Failed to create directory '%s' to save recordings into!", g_szRecordingPath );
            return;
        }
    }


    server_print( CONSOLE_PREFIX + "Setting recording path to '%s'", g_szRecordingPath );
}

stock insertFrame( ply )
{
    static frame[FRAME_SIZE];
    static Float:vec[3];

    pev( ply, pev_angles, vec );
    CopyArray( vec, frame[FRAME_ANGLES], 2 );
    
    pev( ply, pev_origin, vec );
    CopyArray( vec, frame[FRAME_POS], 3 );
    
    frame[FRAME_FLAGS] = ( pev( ply, pev_flags ) & FL_DUCKING ) ? FRAMEFLAG_DUCK : 0;

    ArrayPushArray( g_ArrPlyRecording[ply], frame );
}

stock loadRecordings()
{
    new szFile[256];
    new FileType:type;
    
    new dir = open_dir( g_szRecordingPath, szFile, charsmax( szFile ), type );
    if ( !dir )
    {
        return 0;
    }


    new count = 0;


    new defaultstyleid = impulse_getdefaultstyleid();

    if ( defaultstyleid == INVALID_STYLE )
    {
        server_print( CONSOLE_PREFIX + "Failed to retrieve default style id!" );
    }


    do
    {
        if ( type != FileType_File )
            continue;


        new fullpath[256];
        formatex( fullpath, charsmax( fullpath ), "%s/%s", g_szRecordingPath, szFile );


        new Float:flTime = INVALID_TIME;
        new styleid = defaultstyleid;
        new name[MAX_NAME_LENGTH];
        new framerate;

        new Array:recording = readRecording( fullpath, flTime, styleid, name, framerate );

        if ( recording == Invalid_Array )
        {
            continue;
        }


        g_ArrBest[styleid] = recording;
        g_flBestTimes[styleid] = flTime;
        
        copy( g_szBestNames[styleid], charsmax( g_szBestNames[] ), name );
        g_flBestTimes[styleid] = flTime;
        g_nBestFrameRate[styleid] = framerate;

        ++count;
    }
    while ( next_file( dir, szFile, charsmax( szFile ), type ) == 1 );

    return count;
}

stock bool:start_next_replay()
{
    new end = g_iCurReplayStyle;
    if ( end < 0 || end >= MAX_STYLES )
        end = 0;


    new styleid = end;
        
    do
    {
        ++styleid;

        if ( styleid < 0 || styleid >= MAX_STYLES )
            styleid = 0;

        if ( replayExists( styleid ) )
        {
            break;
        }
    }
    while ( styleid != end );



    if ( replayExists( styleid ) )
    {
        startReplay( styleid );
        return true;
    }

    return false;
}

stock replayExists( styleid )
{
    return g_ArrBest[styleid] != Invalid_Array;
}

stock startReplay( styleid )
{
    g_ArrCurReplay = g_ArrBest[styleid];
    g_iCurReplayTickMax = ArraySize( g_ArrCurReplay );

    g_flCurReplayTime = g_flBestTimes[styleid];

    g_flReplayFrameInterval = 1.0 / g_nBestFrameRate[styleid];

    copy( g_szCurReplayName, charsmax( g_szCurReplayName ), g_szBestNames[styleid] );
    

    g_iCurReplayStyle = styleid;


    setRecordBotName();

    g_bPlyMimicing[g_iRecBot] = true;

    g_iPlyTick[g_iRecBot] = floatround( -1.0 / g_flReplayFrameInterval );


    remove_task( 0, 0 ); // Remove the replay restart task.
}

stock Float:fmod( Float:value, Float:mod )
{
    return value - float(floatround( value / mod, floatround_floor )) * mod;
}

stock Float:lerpAngle( Float:from, Float:to, Float:frac )
{
    static Float:max = 360.0;

    new Float:d = fmod( (to - from), max );

    new Float:val = from + ((fmod( 2.0 * d, max )) - d) * frac;

    if ( val < -180.0 )
        val += 360.0;
    else if ( val > 180.0 )
        val -= 360.0;

    return val;
}
