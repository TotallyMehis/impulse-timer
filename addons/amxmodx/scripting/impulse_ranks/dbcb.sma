public cbEmpty( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    imp_db_failstate( failState, szError, iError, "generic (ranks)" );
}

public cbPlyRank( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( imp_db_failstate( failState, szError, iError, "getting player rank" ) )
        return;
    
    
    new ply = data[0];
    if ( !is_user_connecting( ply ) && !is_user_connected( ply ) ) return;

    
    if ( !SQL_NumResults( hQuery ) )
    {
        server_print( CONSOLE_PREFIX + "Player %i had no rank points, making one for them!", ply );
        

        formatex( g_DB_szQuery, charsmax( g_DB_szQuery ), "INSERT INTO " + DB_TABLE_RANKS + " (plyid) VALUES (%i)", impulse_getplyid( ply ) );
        SQL_ThreadQuery( impulse_getdb(), "cbEmpty", g_DB_szQuery );
        

        g_iPlyRankPoints[ply] = 0;
        setPlyRank( ply );
        

        return;
    }
    

    g_iPlyRankPoints[ply] = SQL_ReadResult( hQuery, 0 );
    setPlyRank( ply );
    
    server_print( CONSOLE_PREFIX + "Player %i rank points: %i", ply, g_iPlyRankPoints[ply] );
}
