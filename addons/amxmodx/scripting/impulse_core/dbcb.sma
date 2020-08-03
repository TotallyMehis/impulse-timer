public cbEmpty( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    imp_db_failstate( failState, szError, iError, "generic (core)" );
}

public cbNewPlyId( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( imp_db_failstate( failState, szError, iError, "new player id" ) )
        return;


    new ply = data[0];
    if ( !is_user_connecting( ply ) && !is_user_connected( ply ) ) return;


    dbGetPlyId( ply );
}

public cbPlyId( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( imp_db_failstate( failState, szError, iError, "getting player id" ) )
        return;


    new ply = data[0];
    if ( !is_user_connecting( ply ) && !is_user_connected( ply ) ) return;

    // No player found, insert new one.
    if ( !SQL_NumResults( hQuery ) )
    {
        new szSteamId[32];
        getPlySteamId( ply, szSteamId, charsmax( szSteamId ) );


        formatex( g_DB_szQuery, charsmax( g_DB_szQuery ), "INSERT INTO " + DB_TABLE_USERS + " (steamid) VALUES ('%s')", szSteamId );
        SQL_ThreadQuery( g_DB_Tuple, "cbNewPlyId", g_DB_szQuery, data, size );

        return;
    }
    

    new plyid = SQL_ReadResult( hQuery, 0 );

    g_iPlyId[ply] = plyid;


    sendPlyIdFwd( ply );
}

public cbMapId( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( imp_db_failstate( failState, szError, iError, "getting map id" ) )
        return;


    // No map found, insert new one.
    if ( !SQL_NumResults( hQuery ) )
    {
        formatex( g_DB_szQuery, charsmax( g_DB_szQuery ), "INSERT INTO " + DB_TABLE_MAPS + " (mapname) VALUES ('%s')", g_szCurMap );
        SQL_ThreadQuery( g_DB_Tuple, "cbNewMapId", g_DB_szQuery );

        return;
    }
    

    g_iMapId = SQL_ReadResult( hQuery, 0 );


    dbGetBestTime();
}

public cbNewMapId( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( imp_db_failstate( failState, szError, iError, "new map id" ) )
        return;


    dbGetMapId();
}

public cbPlyData( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( imp_db_failstate( failState, szError, iError, "player records" ) )
        return;
    
    
    new ply = data[0];
    if ( !is_user_connecting( ply ) && !is_user_connected( ply ) ) return;
    
    if ( !SQL_NumResults( hQuery ) )
    {
        server_print( CONSOLE_PREFIX + "Player %i had no past records in the database!", ply );
        return;
    }
    

    new Float:flTime;
    new styleid;

    while ( SQL_MoreResults( hQuery ) )
    {
        styleid = SQL_ReadResult( hQuery, 0 );
        SQL_ReadResult( hQuery, 1, flTime );
        
        
        g_flPlyBestTime[ply][styleid] = flTime;


        server_print( CONSOLE_PREFIX + "Player %i had PB of %.2fs for style %i!", ply, flTime, styleid );

        SQL_NextRow( hQuery );
    }
}

public cbBestTime( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( imp_db_failstate( failState, szError, iError, "server best" ) )
        return;
    

    if ( !SQL_NumResults( hQuery ) )
    {
        server_print( CONSOLE_PREFIX + "Map had no records in the database!" );
        return;
    }


    new Float:flTime;
    new styleid;

    while ( SQL_MoreResults( hQuery ) )
    {
        styleid = SQL_ReadResult( hQuery, 0 );
        SQL_ReadResult( hQuery, 1, flTime );


        server_print( CONSOLE_PREFIX + "Server best for style %i: %.2f", styleid, flTime );

        g_flMapBestTime[styleid] = flTime;

        SQL_NextRow( hQuery );
    }
}

public cbRecords( failState, Handle:hQuery, szError[], iError, data[], size, Float:queueTime )
{
    if ( imp_db_failstate( failState, szError, iError, "showing records" ) )
        return;
    
    
    new ply = imp_getuserbyuserid( data[0] );
    if ( !is_user_connected( ply ) ) return;
    

    static szBody[2048];
    static szHeader[128];

    static const szHTMLHead[] = "<head><style>body{background-color:#29293D;color:white;padding:0 40px 15px 0px}table{margin:auto 0}td{padding:2px 10px 2px 10px}</style></head>";

    formatex( szHeader, charsmax( szHeader ), "Top %i records", MAX_RECORDS_PRINT );

    if ( !SQL_NumResults( hQuery ) )
    {
        copy( szBody, charsmax( szBody ), szHTMLHead );
        add( szBody, charsmax( szBody ), "<body>No one has beaten the map yet :(</body>" );


        show_motd( ply, szBody, szHeader );
        return;
    }
    
    
    static Float:flTimes[MAX_RECORDS_PRINT];
    static szNames[MAX_RECORDS_PRINT][MAX_NAME_LENGTH];
    static szSteamIds[MAX_RECORDS_PRINT][32];
    static iStyleIds[MAX_RECORDS_PRINT];

    new plys = 0;
    
    while ( SQL_MoreResults( hQuery ) )
    {
        iStyleIds[plys] = SQL_ReadResult( hQuery, 0 );

        SQL_ReadResult( hQuery, 1, flTimes[plys] );
        
        SQL_ReadResult( hQuery, 2, szNames[plys], charsmax( szNames[] ) );

        SQL_ReadResult( hQuery, 3, szSteamIds[plys], charsmax( szSteamIds[] ) );
    
        
        plys++;
        SQL_NextRow( hQuery );
    }
    

    static szTemp[256];
    static szFormatted[32];
    static szStyleName[STYLE_NAME_LENGTH];
    
    // Start with head
    copy( szBody, charsmax( szBody ), szHTMLHead );

    // Start body and add table header
    add( szBody, charsmax( szBody ), "<body><table><tr><th>#</th><th>Name</th><th>Time</th><th>Style</th><th>Steam Id</th></tr>" );

    // Table content
    for ( new i = 0; i < plys; i++ )
    {
        imp_formatseconds( flTimes[i], szFormatted, charsmax( szFormatted ), true );

        impulse_getstylename( iStyleIds[i], szStyleName, charsmax( szStyleName ) );

        formatex( szTemp, charsmax( szTemp ), "<tr><th>%i.</th><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
            i + 1,
            szNames[i],
            szFormatted,
            szStyleName,
            szSteamIds[i] );

        add( szBody, charsmax( szBody ), szTemp );
    }
    
    // end it all.
    add( szBody, charsmax( szBody ), "</table></body>" );
    
    show_motd( ply, szBody, szHeader );
}
