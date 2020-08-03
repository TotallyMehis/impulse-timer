public cmdSay( ply )
{
    if ( read_argc() < 2 ) return PLUGIN_HANDLED;
    
    static szMsg[128];
    
    if ( read_argv( 1, szMsg, charsmax( szMsg ) ) < 1 ) return PLUGIN_HANDLED;
    
    remove_quotes( szMsg );
    
    static szName[32];
    get_user_name( ply, szName, charsmax( szName ) );
    
    
    client_print_color( 0, ply, "^x04[^x03%s^x04] ^x03%s^x01: %s", g_szPlyRank[ply], szName, szMsg );
    
    return PLUGIN_HANDLED;
}

public cmdShowRank( ply )
{
    new szNextRank[MAX_RANK_LENGTH];

    
    new currank = g_iPlyRank[ply];
    if ( currank == -1 ) return PLUGIN_HANDLED;
    
    new nextrank = (currank+1) < ArraySize( g_arrRanks ) ? (currank+1) : -1;
    if ( nextrank == -1 ) return PLUGIN_HANDLED;


    getRankName( nextrank, szNextRank, charsmax( szNextRank ) );

    new plypoints = g_iPlyRankPoints[ply];
    new pointsleft = getRankPoints( nextrank ) - plypoints;

    client_print_color( ply, ply,
        CHAT_PREFIX + "You have ^x04%i^x01 points, '^x03%s^x01' rank in ^x04%i^x01 points!",
        plypoints,
        szNextRank,
        pointsleft );

    
    return PLUGIN_HANDLED;
}
