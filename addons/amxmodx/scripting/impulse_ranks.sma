#include <amxmodx>
#include <amxmisc>
#include <textparse_smc> // Holy shit, thank christ this exists.
#include <sqlx>

#include <impulse/defs>
#include <impulse/core>
#include <impulse/ranks>
#include <impulse/stocks>


#define DB_TABLE_RANKS      "imp_ranks"

#define CONFIG_PATH         "/configs/impulse_ranks.cfg"


#define MAX_RANK_LENGTH         32


new g_iPlyRankPoints[IMP_MAXPLAYERS];
new g_iPlyRank[IMP_MAXPLAYERS];
new g_szPlyRank[IMP_MAXPLAYERS][MAX_RANK_LENGTH];


enum
{
    RANK_POINTS = 0,

    RANK_NAME[MAX_RANK_LENGTH],

    RANK_SIZE
};


new Array:g_arrRanks;
new g_nRanks;


// CACHE
new g_DB_szQuery[512];
new g_szNa[] = "N/A";



#include "impulse_ranks/cmds.sma"
#include "impulse_ranks/db.sma"
#include "impulse_ranks/dbcb.sma"

public plugin_init()
{
    register_plugin( IMP_PLUGIN_NAME + " - Ranks", IMP_PLUGIN_VERSION, IMP_PLUGIN_AUTHOR );


    dbCreateTables();

    
    parseRanks();


    // Commands
    imp_registertriggers( "showrank", "cmdShowRank" );
    


    set_task( 1.0, "taskRegisterSay" );
}

public _impulse_getrankpoints( id, num )
{
    new ply = get_param( 1 );

    return g_iPlyRankPoints[ply];
}

public bool:_impulse_getplyrank( id, num )
{
    new ply = get_param( 1 );


    new rank = g_iPlyRank[ply];

    new len = get_param( 3 );
    if ( rank >= 0 && rank < g_nRanks )
    {
        set_string( 2, g_szPlyRank[ply], len );
    }
    else
    {
        set_string( 2, g_szNa, len );
    }
}

public plugin_natives()
{
    register_library( "impulse_ranks" );


    register_native( "impulse_getrankpoints", "_impulse_getrankpoints" );
    register_native( "impulse_getplyrank", "_impulse_getplyrank" );
}

public client_connect( ply )
{
    g_iPlyRank[ply] = -1;
    copy( g_szPlyRank[ply], charsmax( g_szPlyRank[] ), g_szNa );

    g_iPlyRankPoints[ply] = INVALID_RANK_POINTS;
}

public impulse_on_ply_id( ply, plyid )
{
    dbGetRank(ply);
}

public impulse_on_end_post( ply, const recordData[] )
{
    if ( g_iPlyRankPoints[ply] == INVALID_RANK_POINTS )
    {
        server_print( CONSOLE_PREFIX + "Player %i finished but had no rank points cached! Can't add points!", ply );
        return;
    }

    new Float:pbtime = Float:recordData[RECORDDATA_PREV_PB_TIME];

    new bool:bFirstTime = pbtime == INVALID_TIME;


    if ( bFirstTime )
    {
        server_print( CONSOLE_PREFIX + "Incrementing player rank points!" );


        g_iPlyRankPoints[ply]++;
        
        new prevrank = g_iPlyRank[ply];
        setPlyRank( ply );
        
        if ( prevrank != g_iPlyRank[ply] )
        {
            client_print_color( ply, ply, CHAT_PREFIX + "Your rank is now ^x03%s^x01!", g_szPlyRank[ply] );
        }
        
        dbUpdateRank( ply );
    }
}

public taskRegisterSay()
{
    new const szCmdSay[] = "cmdSay";
    register_clcmd( "say", szCmdSay );
    register_clcmd( "say_team", szCmdSay );
}

stock getPlyRank( ply )
{
    for ( new i = g_nRanks - 1; i >= 0; i-- )
        if ( g_iPlyRankPoints[ply] >= getRankPoints( i ) )
            return i;
    
    return -1;
}

stock getRankPoints( item )
{
    return ArrayGetCell( g_arrRanks, item, RANK_POINTS );
}

stock getRankName( item, name[], in_len )
{
    static rank[MAX_RANK_LENGTH];

    for ( new i = 0; i < MAX_RANK_LENGTH - 1; i++ )
    {
        rank[i] = ArrayGetCell( g_arrRanks, item, RANK_NAME + i );
    }
    
    copy( name, in_len, rank );
}

new g_ParseRank_nSectionCount;
new g_ParseRank_szRank[MAX_RANK_LENGTH];
new g_ParseRank_nPoints;

stock parseRanks()
{
    g_arrRanks = ArrayCreate( RANK_SIZE );


    new szFile[512];
    get_basedir( szFile, charsmax( szFile ) );
    add( szFile, charsmax( szFile ), CONFIG_PATH );

    if ( !file_exists( szFile ) )
    {
        server_print( CONSOLE_PREFIX + "Rank config '%s' doesn't exist!", CONFIG_PATH );
        return -1;
    }


    new SMCParser:parser = SMC_CreateParser();

    SMC_SetReaders( parser, "smcOnKeyValue_rank", "smcOnNewSection_rank", "smcOnEndSection_rank" );
    SMC_ParseFile( parser, szFile );

    ArraySort( g_arrRanks, "sortRanks" );
    g_nRanks = ArraySize( g_arrRanks );

    if ( g_nRanks > 0 )
    {
        server_print( CONSOLE_PREFIX + "Sorted %i ranks! First points: %i | Last points: %i",
            g_nRanks,
            getRankPoints( 0 ),
            getRankPoints( ArraySize( g_arrRanks ) - 1 ) );
    }
    else
    {
        server_print( CONSOLE_PREFIX + "No ranks were parsed from config!" );
    }


    SMC_DestroyParser( parser );

    return g_nRanks;
}

public SMCResult:smcOnNewSection_rank( SMCParser:handle, const name[], any:data )
{
    if ( g_ParseRank_nSectionCount++ > 0 )
    {
        copy( g_ParseRank_szRank, charsmax( g_ParseRank_szRank ), name );
    }
}

public SMCResult:smcOnKeyValue_rank( SMCParser:handle, const key[], const value[], any:data )
{
    if ( equali( key, "points" ) )
    {
        g_ParseRank_nPoints = strtol( value, .base = 10 );
    }
}

public SMCResult:smcOnEndSection_rank( SMCParser:handle, any:data )
{
    if ( g_ParseRank_szRank[0] != 0 )
    {
        addRank( g_ParseRank_szRank, g_ParseRank_nPoints );

        g_ParseRank_szRank[0] = 0;
        g_ParseRank_nPoints = 0;
    }
}

public sortRanks( Array:array, item1, item2, const data[], data_size )
{
    new points1 = ArrayGetCell( array, item1, RANK_POINTS );
    new points2 = ArrayGetCell( array, item2, RANK_POINTS );

    if ( points1 == points2 ) return 0;

    return points1 > points2 ? 1 : -1;
}

stock addRank( const name[], points )
{
    new data[RANK_SIZE];

    data[RANK_POINTS] = points;
    copy( data[RANK_NAME], MAX_RANK_LENGTH - 1, name );
    

    ArrayPushArray( g_arrRanks, data );
}

stock setPlyRank( ply )
{
    new prevrank = g_iPlyRank[ply];

    g_iPlyRank[ply] = getPlyRank( ply );

    new rank = g_iPlyRank[ply];

    if ( rank != -1 )
    {
        getRankName( rank, g_szPlyRank[ply], charsmax( g_szPlyRank[] ) );
    }
    else
    {
        copy( g_szPlyRank[ply], charsmax( g_szPlyRank[] ), g_szNa );
    }


    if ( prevrank != rank )
    {
        server_print( CONSOLE_PREFIX + "Set player %i rank to '%s'", ply, g_szPlyRank[ply] );
    }
}
