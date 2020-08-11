#include <amxmodx>
#include <amxmisc>
#include <xs>

#include <impulse/defs>
#include <impulse/core>
#include <impulse/stocks>


#define MAPSETTINGS_FILE    "/configs/impulse_mapcycle.ini"

#define VOTINGMENU_NAME     "ImpVotingMenu"

#define MAX_MAP_LENGTH      64


enum
{
    VOTESTATUS_NONE = 0,
    VOTESTATUS_VOTED,
    VOTESTATUS_ALREADY_VOTED,
    VOTESTATUS_VOTE_ENDED
};

enum _:Vote_t
{
    VOTE_USERID = 0,
    VOTE_MAP_INDEX
}

#define VOTE_SIZE       2

enum _:Nomination_t
{
    NOM_USERID = 0,
    NOM_MAP_INDEX
}

#define NOM_SIZE        2

#define MAX_MAPS_TO_VOTE    5


// CACHE
new g_iMaxPlys;

new g_nConnectedPlayers;
new g_nPlayers;


new Array:g_arrRTVs = Invalid_Array;

new Array:g_arrMapList = Invalid_Array;
new Array:g_arrNominatedMaps = Invalid_Array;

new Array:g_arrVotingMaps = Invalid_Array;
new Array:g_arrVotes = Invalid_Array;

new bool:g_bVoteInProgress = false;
new g_fVoteMenuFlags = ( 1 << 0 | 1 << 1 | 1 << 2 | 1 << 3 | 1 << 4 | 1 << 9 );

new bool:g_bChangingMap = false;
new g_szChangeMapName[MAX_MAP_LENGTH];
new g_szCurMapName[MAX_MAP_LENGTH];


public plugin_init()
{
    register_plugin( IMP_PLUGIN_NAME + " - Voting", IMP_PLUGIN_VERSION, IMP_PLUGIN_AUTHOR );


    g_iMaxPlys = get_maxplayers();
    imp_getsafemapname( g_szCurMapName, charsmax( g_szCurMapName ) );


    g_arrRTVs = ArrayCreate( 1 );
    g_arrMapList = ArrayCreate( MAX_MAP_LENGTH );
    g_arrNominatedMaps = ArrayCreate( NOM_SIZE );
    g_arrVotingMaps = ArrayCreate( MAX_MAP_LENGTH );
    g_arrVotes = ArrayCreate( VOTE_SIZE );


    new numMaps = readPossibleMaps();
    if ( !numMaps )
    {
        set_fail_state( CONSOLE_PREFIX + "No valid maps found in mapcycle file!" );
    }

    server_print( CONSOLE_PREFIX + "Read %i maps from mapcycle.", numMaps );

    // COMMANDS
    imp_registertriggers( "rtv", "cmdRTV" );
    
    new const cmdSay[] = "cmdSay";
    register_clcmd( "say", cmdSay );
    register_clcmd( "say_team", cmdSay );


    //
    register_menucmd( register_menuid( VOTINGMENU_NAME ), g_fVoteMenuFlags, "menuVote" );
}

public plugin_natives()
{
    //register_library( "impulse_voting" );
}

public plugin_cfg()
{
}

public client_connect( ply )
{
    if ( !is_user_bot( ply ) )
    {
        ++g_nConnectedPlayers;
    }
}

public client_putinserver( ply )
{
    if ( is_user_bot( ply ) ) return;

    
    ++g_nPlayers;
}

public client_disconnected( ply, bool:drop, message[], maxlen )
{
    if ( is_user_bot( ply ) ) return;

    
    --g_nConnectedPlayers;
    --g_nPlayers;

    removeRTV( ply );
    removeVote( ply );
    removeNomination( ply );
}

public cmdRTV( ply )
{
    addRTV( ply );


    return PLUGIN_HANDLED;
}

public cmdSay( ply )
{
    // say /nominate mapname
    if ( read_argc() < 3 )
    {
        return PLUGIN_CONTINUE;
    }


    new szCmd[64];
    read_argv( 1, szCmd, charsmax( szCmd ) );

    new index = 0;

    if ( szCmd[0] == '/' )
    {
        ++index;    
    }


    // Nominate
    if ( equali( szCmd[index], "nominate" ) )
    {
        new szMapName[MAX_MAP_LENGTH];
        read_argv( 2, szMapName, charsmax( szMapName ) );

        remove_quotes( szMapName );
        trim( szMapName );

        nominateMap( szMapName, ply );

        return PLUGIN_HANDLED;
    }
    
    return PLUGIN_CONTINUE;
}

stock clearVoting()
{
    ArrayClear( g_arrRTVs );
    ArrayClear( g_arrVotes );

    ArrayClear( g_arrVotingMaps );
    ArrayClear( g_arrNominatedMaps );

    g_bVoteInProgress = false;
}

stock findPlyVoteIndex( ply )
{
    new userid = get_user_userid( ply );

    new len = ArraySize( g_arrVotes );
    for ( new i = 0; i < len; i++ )
    {
        if ( ArrayGetCell( g_arrVotes, i, VOTE_USERID ) == userid )
        {
            return i;
        }
    }

    return -1;
}

stock numVoted( index = -1 )
{
    new count = 0;

    new len = ArraySize( g_arrVotes );
    for ( new i = 0; i < len; i++ )
    {
        if ( imp_getuserbyuserid( ArrayGetCell( g_arrVotes, i, VOTE_USERID ) ) != 0 )
        {
            if ( index != -1 && ArrayGetCell( g_arrVotes, i, VOTE_MAP_INDEX ) != index )
                continue;

                
            ++count;
        }
    }

    return count;
}

stock votesNeeded()
{
    return g_nPlayers;
}

stock addVote( ply, index )
{
    if ( !g_bVoteInProgress )
    {
        return;
    }


    if ( index < 0 || index >= ArraySize( g_arrVotingMaps ) )
    {
        return;
    }

    new vote[VOTE_SIZE];

    vote[VOTE_USERID] = get_user_userid( ply );
    vote[VOTE_MAP_INDEX] = index;

    ArrayPushArray( g_arrVotes, vote );


    new mapname[MAX_MAP_LENGTH];
    ArrayGetString( g_arrVotingMaps, index, mapname, charsmax( mapname ) );

    client_print_color( ply, ply, CHAT_PREFIX + "You voted for map ^x03%s^x01!", mapname );


    new count = numVoted();
    new needed = votesNeeded();

    if ( count >= needed )
    {
        finishVote();
    }
}

stock getVoteMapIndex( ply )
{
    new userid = get_user_userid( ply );
    new len = ArraySize( g_arrVotes );
    for ( new i = 0; i < len; i++ )
    {
        if ( ArrayGetCell( g_arrVotes, i, VOTE_USERID ) == userid )
        {
            return ArrayGetCell( g_arrVotes, i, VOTE_MAP_INDEX );
        }
    }

    return -1;
}

stock removeVote( ply )
{
    new index;
    while ( (index = findPlyVoteIndex( ply )) != -1 )
    {
        ArrayDeleteItem( g_arrVotes, index );
    }
}

stock removeRTV( ply )
{
    new index;
    while ( (index = findPlyRTVIndex( ply )) != -1 )
    {
        ArrayDeleteItem( g_arrRTVs, index );
    }
}

stock removeNomination( ply )
{
    new index;
    while ( (index = findPlyNominationIndex( ply )) != -1 )
    {
        new mapindex = ArrayGetCell( g_arrNominatedMaps, index, NOM_MAP_INDEX );

        ArrayDeleteItem( g_arrNominatedMaps, index );


        new szPrevName[MAX_MAP_LENGTH];
        ArrayGetString( g_arrMapList, mapindex, szPrevName, charsmax( szPrevName ) );

        client_print_color( 0, 0, CHAT_PREFIX + "^x03%s^x01 is no longer nominated." );
    }
}

stock findPlyRTVIndex( ply )
{
    new len = ArraySize( g_arrRTVs );
    for ( new i = 0; i < len; i++ )
    {
        if ( imp_getuserbyuserid( ArrayGetCell( g_arrRTVs, i ) ) == ply )
        {
            return i;
        }
    }

    return -1;
}

stock numRTVs()
{
    new votes = 0;

    new len = ArraySize( g_arrRTVs );
    for ( new i = 0; i < len; i++ )
    {
        if ( imp_getuserbyuserid( ArrayGetCell( g_arrRTVs, i ) ) != 0 )
        {
            ++votes;
        }
    }

    return votes;
}

stock rtvsNeeded()
{
    if ( g_nConnectedPlayers <= 2 )
        return g_nConnectedPlayers;

    return floatround( g_nConnectedPlayers * 0.75 );
}

stock bool:addRTV( ply )
{
    if ( g_bVoteInProgress )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "Vote is already in progress!" );
        return false;
    }

    if ( g_bChangingMap )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "Too late." );
        return false;
    }

    if ( findPlyRTVIndex( ply ) != -1 )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "You've already voted!" );
        return false;
    }


    ArrayPushCell( g_arrRTVs, get_user_userid( ply ) );


    new needed = rtvsNeeded();
    new count = numRTVs();

    new szName[MAX_NAME_LENGTH];
    get_user_name( ply, szName, charsmax( szName ) );

    if ( count >= needed )
    {
        startVote();

        client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 has rocked the vote and voting has started!", szName );
    }
    else
    {
        client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 has rocked the vote! (^x03%i^x01/^x03%i^x01)", szName, count, needed );
    }
    

    return true;
}

stock showVotingMenu( ply )
{
    static szOption[][] = { "\d", "\w" };
    static szMenu[256];
    static szMapName[MAX_MAP_LENGTH];

    new voteIndex = getVoteMapIndex( ply );

    new bool:voted = voteIndex != -1;

    new len = 0;

    new numMaps = ArraySize( g_arrVotingMaps );
    
    for ( new i = 0; i < numMaps; i++ )
    {
        ArrayGetString( g_arrVotingMaps, i, szMapName, charsmax( szMapName ) );

        new clrIndex = ( voteIndex == i || !voted ) ? 1 : 0;

        len += format( szMenu[len], charsmax( szMenu ) - len, "\r%i. %s%s^n",
            i + 1,
            szOption[clrIndex],
            szMapName );
    }

    show_menu( ply, g_fVoteMenuFlags, szMenu, -1, VOTINGMENU_NAME );
    
}

stock populateVoteMaps()
{
    new Array:mapindices = ArrayCreate( 1 );

    new szMapName[MAX_MAP_LENGTH];

    new numnominated = ArraySize( g_arrNominatedMaps );

    for ( new i = 0; i < numnominated; i++ )
    {
        if ( imp_getuserbyuserid( ArrayGetCell( g_arrNominatedMaps, i, NOM_USERID ) ) == 0 )
        {
            continue;
        }

        ArrayPushCell( mapindices, ArrayGetCell( g_arrNominatedMaps, i, NOM_MAP_INDEX ) );
    }

    new numpossiblemaps = ArraySize( g_arrMapList );
    new maxvotemaps = min( numpossiblemaps, MAX_MAPS_TO_VOTE );

    while ( ArraySize( mapindices ) < maxvotemaps )
    {
        new randomindex = random_num( 0, numpossiblemaps );

        // Already in the list.
        if ( ArrayFindValue( mapindices, randomindex ) != -1 )
        {
            continue;
        }


        ArrayGetString( g_arrMapList, randomindex, szMapName, charsmax( szMapName ) );

        // Can't vote for current map...
        if ( equali( g_szCurMapName, szMapName ) )
        {
            continue;
        }


        ArrayPushCell( mapindices, randomindex );
    }


    
    for ( new i = 0; i < ArraySize( mapindices ); i++ )
    {
        ArrayGetString( g_arrMapList, ArrayGetCell( mapindices, i ), szMapName, charsmax( szMapName ) );

        ArrayPushString( g_arrVotingMaps, szMapName );
    }

    ArrayDestroy( mapindices );
}

public startVote()
{
    g_bVoteInProgress = true;


    populateVoteMaps();


    set_task( 12.0, "taskFinishVote" );


    for ( new ply = 1; ply <= g_iMaxPlys; ply++ )
    {
        if ( !is_user_connected( ply ) ) continue;

        if ( is_user_bot( ply ) ) continue;


        showVotingMenu( ply );
    }
}

public menuVote( ply, key )
{
    new bool:bClickedMap = key >= 0 && key < ArraySize( g_arrVotingMaps );

    if ( findPlyVoteIndex( ply ) == -1 ) // Hasn't voted.
    {
        addVote( ply, key );
    }
    else
    {
        client_print_color( ply, ply, CHAT_PREFIX + "You've already voted!" );
    }


    if ( bClickedMap && g_bVoteInProgress )
    {
        showVotingMenu( ply );
    }
}

stock getHighestVotedMapIndex()
{
    new highestIndex = -1;
    new highestCount = 0;

    new len = ArraySize( g_arrVotingMaps );

    for ( new i = 0; i < len; i++ )
    {
        new voted = numVoted( i );

        if ( voted > highestCount )
        {
            highestIndex = i;
            highestCount = voted;
        }
    }
    

    return highestIndex;
}

stock finishVote()
{
    g_bVoteInProgress = false;


    new mapindex = getHighestVotedMapIndex();

    if ( mapindex == -1 )
    {
        client_print_color( 0, 0, CHAT_PREFIX + "Vote has passed. Nobody voted! :(" );

        clearVoting();
        return;
    }
    

    
    ArrayGetString( g_arrVotingMaps, mapindex, g_szChangeMapName, charsmax( g_szChangeMapName ) );

    client_print_color( 0, 0, CHAT_PREFIX + "Vote has passed. Changing map to ^x03%s^x01...", g_szChangeMapName );

    g_bChangingMap = true;
    set_task( 3.0, "taskChangeMap" );
}

public taskChangeMap()
{
    engine_changelevel( g_szChangeMapName );

    clearVoting();
}

public taskFinishVote()
{
    if ( g_bVoteInProgress )
    {
        finishVote();
    }
}

stock readPossibleMaps()
{
    new szFile[256];
    
    get_cvar_string( "mapcyclefile", szFile, charsmax( szFile ) );

    if ( !file_exists( szFile, true ) )
    {
        set_fail_state( CONSOLE_PREFIX + "Mapcycle file '%s' does not exist!", szFile );
        return -1;
    }


    new file = fopen( szFile, "r", true );

    if ( !file )
    {
        set_fail_state( CONSOLE_PREFIX + "Failed to open mapcycle file '%s' for reading!", szFile );
        return -1;
    }


    new szLine[256];
    while ( fgets( file, szLine, charsmax( szLine ) ) != 0 )
    {
        new index;

        // Remove line endings.
        index = strfind( szLine, "^r^n", false, 0 );
        if ( index != -1 )
        {
            szLine[index] = '^0';
        }

        index = xs_strchr( szLine, '^n' );
        if ( index != -1 )
        {
            szLine[index] = '^0';
        }
        

        // Remove comments.
        index = strfind( szLine, "//", false, 0 );
        if ( index != -1 )
        {
            szLine[index] = '^0';
        }


        // Finally, remove whitespaces.
        trim( szLine );


        // Nothing here.
        if ( szLine[0] == '^n' )
            continue;


        ArrayPushString( g_arrMapList, szLine );
    }


    fclose( file );

    return ArraySize( g_arrMapList );
}

// public bool:nsFunc_maps( INIParser:handle, const section[], bool:invalid_tokens, bool:close_bracket, bool:extra_tokens, curtok, Array:arr )
// {
//     //new style[STYLE_SIZE];
//     //copy( style[STYLE_NAME], STYLE_NAME_LENGTH - 1, section );

//     new szFullPath[PLATFORM_MAX_PATH];
//     copy( szFullPath, charsmax( szFullPath ), "maps/" );
//     add( szFullPath, charsmax( szFullPath ), section );
//     add( szFullPath, charsmax( szFullPath ), ".bsp" );
    
//     if ( !file_exists( szFullPath, true ) )
//     {
//         server_print( CONSOLE_PREFIX + "Map file '%s' does not exist.", szFullPath );
//         return true;
//     }

//     ArrayPushString( g_arrMapList, section );

//     return true;
// }

// public bool:kvFunc_maps( INIParser:handle, const key[], const value[], bool:invalid_tokens, bool:equal_token, bool:quotes, curtok, Array:arr )
// {
//     //new item = ArraySize( g_arrStyles ) - 1;

//     // if ( equali( key, "type" ) )
//     // {
//     //     ArraySetCell( g_arrStyles, item, iValue, STYLE_ID );
//     // }
//     // else
//     // {
//     //     server_print( CONSOLE_PREFIX + "Invalid mapcycle key '%s'!", value );
//     //     return false;
//     // }

//     return true;
// }

stock findPossibleMapIndex( const szMapName[] )
{
    new szMyMapName[MAX_MAP_LENGTH];
    new len = ArraySize( g_arrMapList );
    for ( new i = 0; i < len; i++ )
    {
        ArrayGetString( g_arrMapList, i, szMyMapName, charsmax( szMyMapName ) );

        if ( equali( szMapName, szMyMapName ) )
        {
            return i;
        }
    }

    return -1;
}

stock findPlyNominationIndex( ply )
{
    new userid = get_user_userid( ply );

    new len = ArraySize( g_arrNominatedMaps );
    for ( new i = 0; i < len; i++ )
    {
        if ( ArrayGetCell( g_arrNominatedMaps, i, NOM_USERID ) == userid )
        {
            return i;
        }
    }

    return -1;
}

stock bool:nominateMap( const szMapName[], ply )
{
    if ( equali( g_szCurMapName, szMapName ) )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "Can't nominate current map!", szMapName );
        return false;
    }

    new mapindex = findPossibleMapIndex( szMapName );

    if ( mapindex == -1 )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "^x03%s^x01 is not on the mapcycle.", szMapName );
        return false;
    }



    new nominationIndex = findPlyNominationIndex( ply );

    new bool:bAlreadyNominated = nominationIndex != -1;

    new prevmapindex = bAlreadyNominated ? ArrayGetCell( g_arrNominatedMaps, nominationIndex, NOM_MAP_INDEX ) : -1;
    if ( mapindex == prevmapindex )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "You've already nominated ^x03%s^x01!", szMapName );
        return false;
    }


    if ( !bAlreadyNominated && ArraySize( g_arrNominatedMaps ) >= MAX_MAPS_TO_VOTE )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "Can't nominate more than ^x03%i^x01 maps!", MAX_MAPS_TO_VOTE );
        return false;
    }


    if ( bAlreadyNominated )
    {
        new szPrevName[MAX_MAP_LENGTH];
        ArrayGetString( g_arrMapList, prevmapindex, szPrevName, charsmax( szPrevName ) );

        ArrayDeleteItem( g_arrNominatedMaps, nominationIndex );


        client_print_color( ply, ply, CHAT_PREFIX + "^x03%s^x01 is no longer nominated.", szPrevName );
    }


    new nomination[NOM_SIZE];
    nomination[NOM_USERID] = get_user_userid( ply );
    nomination[NOM_MAP_INDEX] = mapindex;

    ArrayPushArray( g_arrNominatedMaps, nomination );


    new szPlyName[MAX_NAME_LENGTH];
    get_user_name( ply, szPlyName, charsmax( szPlyName ) );

    client_print_color( 0, ply, CHAT_PREFIX + "^x03%s^x01 nominated ^x03%s^x01.", szPlyName, szMapName );

    return true;
}