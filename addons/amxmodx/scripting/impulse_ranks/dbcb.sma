public cbEmpty( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{

}

public cbPlyRank( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( failState ) return;
    
    
    new ply = data[0];
    if ( !is_user_connecting( ply ) && !is_user_connected( ply ) ) return;

    
    if ( !SQL_NumResults( hQuery ) )
    {
        server_print( CONSOLE_PREFIX + "Player %i had no rank points, making one for them!", ply );
        

        formatex( g_DB_szQuery, sizeof( g_DB_szQuery ), "INSERT INTO " + DB_TABLE_RANKS + " (uid) VALUES (%i)", timer_getplyid( ply ) );
        SQL_ThreadQuery( timer_getdb(), "cbEmpty", g_DB_szQuery );
        

        g_iPlyRankPoints[ply] = 0;
        g_iPlyRank[ply] = 0;
        

        return;
    }
    

    g_iPlyRankPoints[ply] = SQL_ReadResult( hQuery, 0 );
    g_iPlyRank[ply] = getPlyRank( ply );
    
    server_print( CONSOLE_PREFIX + "Player %i rank points: %i", ply, g_iPlyRankPoints[ply] );
}
