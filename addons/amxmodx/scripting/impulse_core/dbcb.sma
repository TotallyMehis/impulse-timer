public cbEmpty( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{

}

public cbNewPlyId( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( failState ) return;


    new ply = data[0];
    if ( !is_user_connecting( ply ) && !is_user_connected( ply ) ) return;


    dbGetPlyId( ply );
}

public cbPlyId( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( failState ) return;


    new ply = data[0];
    if ( !is_user_connecting( ply ) && !is_user_connected( ply ) ) return;

    // No player found, insert new one.
    if ( !SQL_NumResults( hQuery ) )
    {
        new szSteamId[32];
        getPlySteamId( ply, szSteamId, sizeof( szSteamId ) );


        formatex( g_DB_szQuery, sizeof( g_DB_szQuery ), "INSERT INTO " + DB_TABLE_USERS + " (steamid) VALUES ('%s')", szSteamId );
        SQL_ThreadQuery( g_DB_Tuple, "cbNewPlyId", g_DB_szQuery, data, size );

        return;
    }
    

    new plyid = SQL_ReadResult( hQuery, 0 );

    g_iPlyId[ply] = plyid;


    sendPlyIdFwd( ply );
}

public cbMapId( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( failState ) return;


    // No map found, insert new one.
    if ( !SQL_NumResults( hQuery ) )
    {
        formatex( g_DB_szQuery, sizeof( g_DB_szQuery ), "INSERT INTO " + DB_TABLE_MAPS + " (mapname) VALUES ('%s')", g_szCurMap );
        SQL_ThreadQuery( g_DB_Tuple, "cbNewMapId", g_DB_szQuery );

        return;
    }
    

    g_iMapId = SQL_ReadResult( hQuery, 0 );


    dbGetBestTime();
}

public cbNewMapId( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( failState ) return;


    dbGetMapId();
}

public cbPlyData( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( failState ) return;
    
    
    new ply = data[0];
    if ( !is_user_connecting( ply ) && !is_user_connected( ply ) ) return;
    
    if ( !SQL_NumResults( hQuery ) )
    {
        g_flPlyBestTime[ply] = INVALID_TIME;
        
        server_print( CONSOLE_PREFIX + "Player %i had no past records in the database!", ply );
        return;
    }
    
    SQL_ReadResult( hQuery, 0, g_flPlyBestTime[ply] );
    
    server_print( CONSOLE_PREFIX + "Player %i had PB of %.2fs!", ply, g_flPlyBestTime[ply] );
}

public cbBestTime( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( failState ) return;
    
    // No times found.
    if ( !SQL_NumResults( hQuery ) ) return;
    
    SQL_ReadResult( hQuery, 0, g_flMapBestTime );
}

public cbRecords( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( failState ) return;
    
    
    new ply = imp_getuserbyuserid( data[0] );
    if ( !is_user_connected( ply ) ) return;
    

    if ( !SQL_NumResults( hQuery ) )
    {
        show_motd( ply, "<head><style>body{background-color:#29293D;color:white}</style></head><body>No one has beaten the map yet :(</body>", "Records" );
        return;
    }
    
    
    static szFormatted[MAX_RECORDS_PRINT][9];
    static szNames[MAX_RECORDS_PRINT][32];
    static szSteamIds[MAX_RECORDS_PRINT][32];
    static field;
    
    new plys = 0;
    new Float:flTime;
    
    while ( SQL_MoreResults( hQuery ) )
    {
        field = SQL_FieldNameToNum( hQuery, "time" );
        SQL_ReadResult( hQuery, field, flTime );
        
        imp_formatseconds( flTime, szFormatted[plys], sizeof( szFormatted[] ), true );
        
        
        field = SQL_FieldNameToNum( hQuery, "steamid" );
        SQL_ReadResult( hQuery, field, szSteamIds[plys], sizeof( szSteamIds[] ) );
        
        field = SQL_FieldNameToNum( hQuery, "name" );
        SQL_ReadResult( hQuery, field, szNames[plys], sizeof( szNames[] ) );
        
        plys++;
        SQL_NextRow( hQuery );
    }
    
    if ( !plys ) return;
    
    static szBuffer[1600];
    static szTemp[122];
    
    copy( szBuffer, sizeof( szBuffer ), "<style>table{margin:auto auto}td{min-width:100px;text-align:center;}body{background-color:#29293D;color:white}</style><table><tr style=^"height:50px^"><td>#</td><td>Name</td><td>Time</td><td>Steam ID</td></tr>" );
    
    for ( new i = 0; i < plys; i++ )
    {
        // <tr><td>10.</td><td>NAMENAMENAMENAMENAMENAMENAMENAME</td><td>00:00.00</td><td>STEAMIDSTEAMIDSTEAMIDSTEAMIDSTEA</td></tr>
        formatex( szTemp, sizeof( szTemp ), "<tr><td>%i.</td><td>%s</td><td>%s</td><td>%s</td></tr>", i + 1, szNames[i], szFormatted[i], szSteamIds[i] );
        add( szBuffer, sizeof( szBuffer ), szTemp );
    }
    
    add( szBuffer, sizeof( szBuffer ), "</table>" ); // </body>
    
    show_motd( ply, szBuffer, "Records" );
}
