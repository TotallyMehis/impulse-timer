stock dbConnect()
{
    SQL_SetAffinity( "sqlite" );
    
    new szType[32];
    SQL_GetAffinity( szType, charsmax( szType ) );
    
    if ( !equali( szType, "sqlite" ) )
    {
        set_fail_state( CONSOLE_PREFIX + "Invalid database affinity! (SQLite module not enabled?)" );
        return;
    }
    
    g_DB_Tuple = SQL_MakeDbTuple( "localhost", "root", "", DB_NAME );


    dbCreateTables();

    dbInitMap();
}

stock dbCreateTables()
{
    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ),
        "CREATE TABLE IF NOT EXISTS " + DB_TABLE_USERS + " (" +
        "plyid INTEGER PRIMARY KEY," +
        "steamid VARCHAR(32) NOT NULL UNIQUE," +
        "name VARCHAR(32) NOT NULL DEFAULT 'N/A'," +
        "datejoined TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP," +
        "datelastplayed TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)" );
    SQL_ThreadQuery( g_DB_Tuple, "cbEmpty", g_DB_szQuery );

    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ),
        "CREATE TABLE IF NOT EXISTS " + DB_TABLE_MAPS + " (" +
        "mapid INTEGER PRIMARY KEY," +
        "mapname VARCHAR(64) NOT NULL UNIQUE)" );
    SQL_ThreadQuery( g_DB_Tuple, "cbEmpty", g_DB_szQuery );

    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ),
        "CREATE TABLE IF NOT EXISTS " + DB_TABLE_TIMES + " (" +
        "plyid INTEGER NOT NULL," +
        "mapid INTEGER NOT NULL," +
        "styleid INTEGER NOT NULL," +
        "rectime REAL NOT NULL," +
        "datebeaten TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP," +
        "PRIMARY KEY(plyid,mapid,styleid))" );
    SQL_ThreadQuery( g_DB_Tuple, "cbEmpty", g_DB_szQuery );
}

stock dbInitMap()
{
    g_iMapId = INVALID_MAP_ID;

    dbGetMapId();
}

stock dbGetBestTime()
{
    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ), "SELECT styleid,MIN(rectime) AS besttime FROM " + DB_TABLE_TIMES + " WHERE mapid=%i GROUP BY styleid", g_iMapId );
    SQL_ThreadQuery( g_DB_Tuple, "cbBestTime", g_DB_szQuery );
}

stock dbGetPlyTime( ply )
{
    new data[2];
    data[0] = ply;

    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ),
        "SELECT styleid,rectime FROM " + DB_TABLE_TIMES + " WHERE plyid=%i AND mapid=%i",
        g_iPlyId[ply],
        g_iMapId );
    
    SQL_ThreadQuery( g_DB_Tuple, "cbPlyData", g_DB_szQuery, data, sizeof( data ) );
}

stock dbGetMapId()
{
    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ), "SELECT mapid FROM " + DB_TABLE_MAPS + " WHERE mapname='%s'", g_szCurMap );
    SQL_ThreadQuery( g_DB_Tuple, "cbMapId", g_DB_szQuery );
}

stock dbGetPlyId( ply )
{
    new data[2];
    data[0] = ply;

    new szSteamId[32];
    getPlySteamId( ply, szSteamId, charsmax( szSteamId ) );

    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ), "SELECT plyid FROM " + DB_TABLE_USERS + " WHERE steamid='%s'", szSteamId );
    SQL_ThreadQuery( g_DB_Tuple, "cbPlyId", g_DB_szQuery, data, sizeof( data ) );
}

stock dbInsertTime( ply, const recordData[] )
{
    new styleid = recordData[RECORDDATA_STYLE_ID];
    new Float:flNewTime = Float:recordData[RECORDDATA_TIME];
    new Float:flPrevTime = Float:recordData[RECORDDATA_PREV_PB_TIME];

    new bool:bIsNew = flPrevTime == INVALID_TIME;


    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ),
        "%s INTO " + DB_TABLE_TIMES + " (plyid,mapid,styleid,rectime) VALUES (%i, %i, %i, %f)",
        bIsNew ? "INSERT" : "REPLACE",
        g_iPlyId[ply],
        g_iMapId,
        styleid,
        flNewTime );
    SQL_ThreadQuery( g_DB_Tuple, "cbEmpty", g_DB_szQuery );
}

stock dbPrintRecords( ply, mapid )
{
    new data[2];
    data[0] = get_user_userid( ply );
    
    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ),
        "SELECT styleid,rectime,name,steamid FROM " + DB_TABLE_TIMES + " AS t INNER JOIN " + DB_TABLE_USERS + " AS u ON t.plyid=u.plyid WHERE mapid=%i ORDER BY rectime LIMIT %i",
        mapid,
        MAX_RECORDS_PRINT );
    SQL_ThreadQuery( g_DB_Tuple, "cbRecords", g_DB_szQuery, data, sizeof( data ) );
}

stock dbUpdateDatabase( ply )
{
    new szName[MAX_NAME_LENGTH];
    if ( !get_user_name( ply, szName, charsmax( szName ) ) )
    {
        return;
    }


    // Just remove illegal characters for now.
    replace_string( szName, charsmax( szName ), "^'", "" );
    replace_string( szName, charsmax( szName ), "`", "" );
    replace_string( szName, charsmax( szName ), "^"", "" );
    replace_string( szName, charsmax( szName ), "\", "" );


    formatex( g_DB_szQuery, charsmax( g_DB_szQuery ),
        "UPDATE " + DB_TABLE_USERS + " SET name='%s',datelastplayed=CURRENT_TIMESTAMP WHERE plyid=%i",
        szName,
        g_iPlyId[ply] );

    SQL_ThreadQuery( g_DB_Tuple, "cbEmpty", g_DB_szQuery );
}
