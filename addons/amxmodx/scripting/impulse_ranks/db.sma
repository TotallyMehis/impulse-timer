stock dbCreateTables()
{
    formatex( g_DB_szQuery, sizeof( g_DB_szQuery ),
        "CREATE TABLE IF NOT EXISTS " + DB_TABLE_RANKS + " (" +
        "plyid INTEGER PRIMARY KEY," +
        "rankpoints INTEGER NOT NULL)" );
    SQL_ThreadQuery( impulse_getdb(), "cbEmpty", g_DB_szQuery );
}

stock dbGetRank( ply )
{
    new data[2];
    data[0] = ply;

    formatex( g_DB_szQuery, sizeof( g_DB_szQuery ),
        "SELECT rankpoints FROM " + DB_TABLE_RANKS + " WHERE plyid=%i",
        impulse_getplyid( ply ) );
    SQL_ThreadQuery( impulse_getdb(), "cbPlyRank", g_DB_szQuery, data, sizeof( data ) );
}

stock dbUpdateRank( ply )
{
    formatex( g_DB_szQuery, sizeof( g_DB_szQuery ),
        "REPLACE INTO " + DB_TABLE_RANKS + " (plyid, rankpoints) VALUES (%i, '%i')",
        impulse_getplyid( ply ),
        g_iPlyRankPoints[ply] );
    SQL_ThreadQuery( impulse_getdb(), "cbEmpty", g_DB_szQuery );
}
