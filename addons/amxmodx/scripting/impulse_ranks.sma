#include <amxmodx>
#include <sqlx>

#include <impulse/defs>
#include <impulse/core>
#include <impulse/ranks>
#include <impulse/stocks>


#define DB_TABLE_RANKS      "imp_ranks"



new g_iPlyRankPoints[IMP_MAXPLAYERS];
new g_iPlyRank[IMP_MAXPLAYERS];

new const g_szRanks[][] = {
    "UNRANKED", "NOVICE",
    "AMATEUR", "CASUAL",
    "SKILLED", "PRO",
    "ELITE", "MASTER",
    "A-LIST"
};
new const g_iMaxRanks = sizeof( g_szRanks ); // 9
new const g_iMaxRankLength = 9;
new const g_iRankPoints[] = { -1, 1, 5, 20, 40, 80, 120, 160, 250 };


// CACHE
new g_DB_szQuery[512];



#include "impulse_ranks/cmds.sma"
#include "impulse_ranks/db.sma"
#include "impulse_ranks/dbcb.sma"

public plugin_init()
{
    register_plugin( IMP_PLUGIN_NAME + " - Ranks", IMP_PLUGIN_VERSION, IMP_PLUGIN_AUTHOR );


    dbCreateTables();


    set_task( 1.0, "taskRegisterSay" );
}

public _timer_getrankpoints( id, num )
{
    new ply = get_param( 1 );

    return g_iPlyRankPoints[ply];
}

public bool:_timer_getrank( id, num )
{
    new ply = get_param( 1 );


    new rank = g_iPlyRank[ply];

    new len = get_param( 3 );
    if ( rank >= 0 && rank < g_iMaxRanks )
    {
        set_string( 2, g_szRanks[rank], min( len, g_iMaxRankLength ) );
    }
    else
    {
        new szNa[] = "N/A";
        set_string( 2, szNa, min( len, sizeof( szNa ) ) );
    }
    
    
}

public plugin_natives()
{
    register_library( "impulse_ranks" );


    register_native( "timer_getrankpoints", "_timer_getrankpoints" );
    register_native( "timer_getrank", "_timer_getrank" );
}

public client_connect( ply )
{
    g_iPlyRank[ply] = 0;
    g_iPlyRankPoints[ply] = INVALID_RANK_POINTS;
}

public timer_on_ply_id( ply, plyid )
{
    dbGetRank(ply);
}

public timer_on_end_post( ply, Float:time )
{
    new Float: pbtime = timer_getpbtime( ply );

    new bool:bFirstTime = pbtime == INVALID_TIME;


    if ( bFirstTime )
    {
        server_print( CONSOLE_PREFIX + "Incrementing player rank points!" );


        g_iPlyRankPoints[ply]++;
        
        new prevrank = g_iPlyRank[ply];
        g_iPlyRank[ply] = getPlyRank( ply );
        
        if ( prevrank != g_iPlyRank[ply] )
        {
            client_print_color( ply, ply, CHAT_PREFIX + "Your rank is now ^x03%s^x01!", g_szRanks[ g_iPlyRank[ply] ] );
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
    for ( new i = g_iMaxRanks - 1; i >= 0; i-- )
        if ( g_iPlyRankPoints[ply] >= g_iRankPoints[i] )
            return i;
    
    return 0;
}

