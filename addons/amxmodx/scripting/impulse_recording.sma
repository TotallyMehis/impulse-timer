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



#define BOT_DEFAULT_NAME        "SR: N/A | /replay"


#define MAGIC_NUMBER            0x4B1B
#define MAGIC_NUMBER_OLD        0x4B1A

#define FRAMEFLAG_DUCK          ( 1 << 0 )

// 60 * Minutes * Tickrate
// 60 * 30 * 66
#define MAX_RECORDING_LENGTH    118800


// Header structure:
// MAGIC NUMBER
// SERVER TICKRATE
// TIME
// PLAYER NAME
// RECORDING LENGTH (NUM OF FRAMES)
enum _:FrameData
{
    Float:FRAME_POS[3],
    Float:FRAME_ANGLES[2],
    FRAME_FLAGS
};
#define FRAME_SIZE        6


new g_iRecEnt; // Recording ent



new Array:g_ArrPlyRecording[IMP_MAXPLAYERS];
new bool:g_bPlyRecording[IMP_MAXPLAYERS];
new bool:g_bPlyMimicing[IMP_MAXPLAYERS];
new g_iPlyTick[IMP_MAXPLAYERS];


new g_iRecordingMaxLen;

// RECORD BOT
new g_iRecBot = 0;
new Array:g_ArrBest = Invalid_Array;
new Float:g_flRecTime = INVALID_TIME;
new g_iRecTickMax = 0;
new g_szRecName[MAX_NAME_LENGTH];


new const Float:g_flRate = 0.01515151515151515151515151515152; // Tickrate (1 / 66)
new g_pServerTicRate;

//new Float:g_flLastRecThink;


// CACHE
new g_iMaxPlys;
new g_szCurMap[64];
new g_szRecordingPath[256];



public plugin_init()
{
    register_plugin( IMP_PLUGIN_NAME + " - Recording", IMP_PLUGIN_VERSION, IMP_PLUGIN_AUTHOR );


    // Forwards
    register_forward( FM_Think, "fwdThink", true );


    // Misc.
    g_iMaxPlys = get_maxplayers();
    g_pServerTicRate = get_cvar_pointer( "sys_ticrate" );

    imp_getsafemapname( g_szCurMap, sizeof( g_szCurMap ) );


    // Entities
    new const class_alloc = engfunc( EngFunc_AllocString, "info_target" );
    
    g_iRecEnt = engfunc( EngFunc_CreateNamedEntity, class_alloc );
    set_pev( g_iRecEnt, pev_classname, "plugin_recording" );
    set_pev( g_iRecEnt, pev_nextthink, get_gametime() + 1.5 );
}

public bool:_impulse_isrecordbot( id, num )
{
    new ply = get_param( 1 );

    return g_iRecBot == ply;
}

public bool:_impulse_getrecordinginfo( id, num )
{
    new ply = get_param( 1 );

    set_param_byref( 2, _:g_flRecTime );


    new len = get_param( 4 );
    set_string( 3, g_szRecName, len );

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
    get_basedir( g_szRecordingPath, sizeof( g_szRecordingPath ) );
    add( g_szRecordingPath, sizeof( g_szRecordingPath ), "/records" );
    
    if ( !dir_exists( g_szRecordingPath ) )
    {
        mkdir( g_szRecordingPath );
        return;
    }
    
    
    g_iRecTickMax = readRecording();
    // In case our time is shorter but for some reason our tickcount is longer.
    g_iRecordingMaxLen = floatround( g_iRecTickMax * 1.1 );

    createRecordBot();
    startRecordBot();
    
    if ( g_iRecordingMaxLen <= 0 ) g_iRecordingMaxLen = MAX_RECORDING_LENGTH;
}

public client_connect( ply )
{
    g_bPlyMimicing[ply] = false;
    g_bPlyRecording[ply] = false;
}

public impulse_on_start_post( ply )
{
    initPlyRecording( ply );
    g_iPlyTick[ply] = 0;
    g_bPlyRecording[ply] = true;
}

public impulse_on_reset( ply )
{
    g_bPlyRecording[ply] = false;
    g_iPlyTick[ply] = 0;
}

public impulse_on_end_post( ply, Float:time )
{
    new Float:prevbest = impulse_getsrtime();

    new bool:bIsBest = prevbest == INVALID_TIME || time < prevbest;

    // Assign the record to a bot.
    if ( g_bPlyRecording[ply] && bIsBest )
    {
        server_print( CONSOLE_PREFIX + "Saving new record recording %i!", ply );

        saveRecording( ply, time );
        
        copyToRecordBot( ply, time );

        g_bPlyRecording[ply] = false;
    }
}

public impulse_on_send_spec( ply )
{
    if ( hasRecordBot() )
    {
        set_pev( ply, pev_iuser1, OBS_IN_EYE );
        set_pev( ply, pev_iuser2, g_iRecBot );
    }
}

public fwdThink( ent )
{
    if ( g_iRecEnt == ent )
    {
        handlePlyRecords();
        set_pev( ent, pev_nextthink, get_gametime() + g_flRate );
    }
}

stock handlePlyRecords()
{
    //static Float:flCurTime;
    //flCurTime = get_gametime();

    //static Float:flMult;
    //flMult = ( flCurTime - g_flLastRecThink );//1.0 / ( flCurTime - g_flLastRecThink );
    
    //static i;
    static ply;

    static frame[FRAME_SIZE];
    static Float:vecTemp[3];
    static Float:vecPrevPos[3];
    static Float:vecNewPos[3];


    for ( ply = 1; ply <= g_iMaxPlys; ply++ )
    {
        if ( !is_user_alive( ply ) ) continue;
        

        if ( g_bPlyMimicing[ply] && g_ArrBest != Invalid_Array )
        {
            ArrayGetArray( g_ArrBest, ( g_iPlyTick[ply] < 0 ) ? 0 : g_iPlyTick[ply], frame );
            
            
            
            pev( ply, pev_origin, vecPrevPos );
            
            // Copy new position.
            CopyArray( frame[FRAME_POS], vecNewPos, 3 );
            
            
            #define MAX_DIST        200.0
            #define MAX_DIST_SQ     MAX_DIST * MAX_DIST
            // Build velocity.
            // if ( getDistSqr( vecPrevPos, vecNewPos ) < MAX_DIST_SQ )
            // {
            //     for ( i = 0; i < 3; i++ )
            //         vecTemp[i] = ( vecNewPos[i] - vecPrevPos[i] ) * flMult;
                
            //     set_pev( ply, pev_velocity, vecTemp );
            // }
            
            {
                // Teleport to new position if we teleported, etc.
                set_pev( ply, pev_origin, vecNewPos );
            }

            //set_pev( ply, pev_oldorigin, vecPrevPos );
            //set_pev( ply, pev_endpos, vecNewPos );
            

            // Set angle
            CopyArray( frame[FRAME_ANGLES], vecTemp, 2 );
            vecTemp[2] = 0.0;

            set_pev( ply, pev_fixangle, 1 );
            //set_pev( ply, pev_v_angle, vecTemp );
            set_pev( ply, pev_angles, vecTemp );
            

            // Misc.
            if ( frame[FRAME_FLAGS] & FRAMEFLAG_DUCK )
            {
                set_pev( ply, pev_flags, pev( ply, pev_flags ) | FL_DUCKING );
                //set_pev( ply, pev_gaitsequence, 3 );
                //set_pev( ply, pev_frame, 0.0 );
            }
            else
            {
                //static const Float:vecViewOff[] = { 0.0, 0.0, 17.0 };
                //set_pev( ply, pev_view_ofs, vecViewOff );
                set_pev( ply, pev_flags, pev( ply, pev_flags ) &~ FL_DUCKING );
            }
            


            g_iPlyTick[ply]++;
            

            if ( g_iPlyTick[ply] >= g_iRecTickMax )
            {
                g_bPlyMimicing[ply] = false;
                
                set_task( 0.5, "taskPlaybackRestart", get_user_userid( ply ) );
            }
            
            // Required to only run once (?)
            // Only doing it once will make the bot's angles fucked up.
            // It will start to work after a while. I don't know why. Something to do with angles being equal?
            // We can't call it every tick or otherwise playback will be screwed.
            //engfunc( EngFunc_RunPlayerMove, ply, vecTemp, 0.0, 0.0, 0.0, 0, 0, 66 );
        }
        else if ( g_bPlyRecording[ply] )
        {
            // Check if too long.
            if ( g_iPlyTick[ply] > g_iRecordingMaxLen )
            {
                g_bPlyRecording[ply] = false;
                initPlyRecording( ply );
                
                continue;
            }
            
            
            pev( ply, pev_angles, vecTemp );
            CopyArray( vecTemp, frame[FRAME_ANGLES], 2 );
            
            pev( ply, pev_origin, vecTemp );
            CopyArray( vecTemp, frame[FRAME_POS], 3 );
            
            frame[FRAME_FLAGS] = ( pev( ply, pev_flags ) & FL_DUCKING ) ? FRAMEFLAG_DUCK : 0;
            
            
            g_iPlyTick[ply]++;
            ArrayPushArray( g_ArrPlyRecording[ply], frame );
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

public taskPlaybackRestart( userid )
{
    new ply = imp_getuserbyuserid( userid );
    if ( ply && is_user_bot( ply ) )
    {
        g_bPlyMimicing[ply] = true;
        g_iPlyTick[ply] = -100;
    }
}

stock createRecordBot()
{
    new szName[MAX_NAME_LENGTH];
    copy( szName, sizeof( szName ), BOT_DEFAULT_NAME );
    
    new bot = engfunc( EngFunc_CreateFakeClient, szName );
    
    if ( !bot )
    {
        server_print( CONSOLE_PREFIX + "Couldn't create record bot!" );
        return false;
    }
    
    dllfunc( MetaFunc_CallGameEntity, "player", bot );
    // static szRejectReason[128];
    // dllfunc(DLLFunc_ClientConnect,bot,szName,"127.0.0.1",szRejectReason);
    // if(!is_user_connected(bot)) {
    //     server_print("Connection rejected: %s",szRejectReason);
    // }

    // dllfunc(DLLFunc_ClientPutInServer,bot);

    
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
    

    cs_set_user_model( bot, "gign", true );
    
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
    g_iPlyTick[bot] = 0;
    
    g_bPlyRecording[bot] = false;
    g_bPlyMimicing[bot] = true;

    return true;
}

stock startRecordBot()
{
    if ( !hasRecordBot() )
        return;
    

    setRecordBotName();
}

stock saveRecording( ply, Float:time )
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
    formatex( szFile, sizeof( szFile ), "%s/%s.rec", g_szRecordingPath, g_szCurMap );
    
    new file = fopen( szFile, "wb" );
    
    
    // Write the header.
    fwrite( file, MAGIC_NUMBER, BLOCK_INT );
    fwrite( file, get_pcvar_num( g_pServerTicRate ), BLOCK_INT );
    fwrite( file, time, BLOCK_INT );
    
    new szName[MAX_NAME_LENGTH];
    get_user_name( ply, szName, sizeof( szName ) );
    
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

stock readRecording()
{
    static szFile[256];
    formatex( szFile, sizeof( szFile ), "%s/%s.rec", g_szRecordingPath, g_szCurMap );
    
    if ( !file_exists( szFile ) )
    {
        return -1;
    }


    new file = fopen( szFile, "rb" );
    
    new iMagic;
    fread( file, iMagic, BLOCK_INT );

    new bool:bMagicOk = iMagic == MAGIC_NUMBER;
    new bool:bOldMagic = iMagic == MAGIC_NUMBER_OLD;
    
    if ( !bMagicOk && !bOldMagic )
    {
        server_print( CONSOLE_PREFIX + "Tried to read from a record file with a different magic number!" );
        fclose( file );
        
        return 0;
    }
    
    new iTickRate;
    fread( file, iTickRate, BLOCK_INT );
    
    fread( file, g_flRecTime, BLOCK_INT );
    server_print( CONSOLE_PREFIX + "Record bot's time: %.2fsec", g_flRecTime );
    
    for ( new i = 0; i < sizeof( g_szRecName ); i++ )
        fread( file, g_szRecName[i], BLOCK_CHAR );
        
    if ( strlen( g_szRecName ) < 1 )
        formatex( g_szRecName, sizeof( g_szRecName ), "N/A" );
    
    
    new iTickCount;
    fread( file, iTickCount, BLOCK_INT );
    if ( !iTickCount ) return 0;
    
    
    new frame[FRAME_SIZE];
    initBestRecording();
    
    if ( bOldMagic )
    {
        server_print( CONSOLE_PREFIX + "Reading old recording!" );

        new temp;
        for ( new i = 0; i < iTickCount; i++ )
        {
            fread_blocks( file, frame, 5, BLOCK_INT );
            fread( file, temp, BLOCK_INT );
            fread( file, frame[FRAME_FLAGS], BLOCK_INT );
            
            ArrayPushArray( g_ArrBest, frame ); 
        }
    }
    else
    {
        for ( new i = 0; i < iTickCount; i++ )
        {
            fread_blocks( file, frame, FRAME_SIZE, BLOCK_INT );
            
            ArrayPushArray( g_ArrBest, frame ); 
        }
    }

    
    fclose( file );

    return iTickCount;
}

stock initBestRecording()
{
    if ( g_ArrBest == Invalid_Array )
    {
        g_ArrBest = ArrayCreate( _:FrameData );
    }
    else
    {
        ArrayClear( g_ArrBest );
    }
}

stock bool:hasRecordBot()
{
    return g_iRecBot > 0;
}

stock bool:copyToRecordBot( ply, Float:time )
{
    new Array:arr = g_ArrPlyRecording[ply];

    if ( arr == Invalid_Array )
    {
        return false;
    }

    if ( !hasRecordBot() && !createRecordBot() )
    {
        server_print( CONSOLE_PREFIX + "Failed to create a record bot!" );
        return false;
    }


    new bot = g_iRecBot;

    g_bPlyMimicing[bot] = false;
    
    g_ArrBest = ArrayClone( arr );
    g_iRecTickMax = ArraySize( g_ArrBest );
    
    g_iRecordingMaxLen = floatround( g_iRecTickMax * 1.2 );

    g_flRecTime = time;

    
    // Format timer HUD name.
    new szName[MAX_NAME_LENGTH];
    get_user_name( ply, szName, sizeof( szName ) );
    copy( g_szRecName, sizeof( g_szRecName ), szName );
    


    setRecordBotName();
    
    g_iPlyTick[bot] = 0;
    g_bPlyMimicing[bot] = true;

    return true;
}

stock setRecordBotName()
{
    new bot = g_iRecBot;

    new bool:bHasRecord = g_iRecTickMax > 0;

    new szName[MAX_NAME_LENGTH];
    if ( bHasRecord )
    {
        
        new szFormatted[32];
        imp_formatseconds( g_flRecTime, szFormatted, sizeof( szFormatted ) );

        
        formatex( szName, sizeof( szName ), "SR: %s | %s", szFormatted, g_szRecName );
    }
    else
    {
        copy( szName, sizeof( szName ), BOT_DEFAULT_NAME );
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
