public cmdSay( ply )
{
    if ( read_argc() < 2 ) return PLUGIN_HANDLED;
    
    static szMsg[128];
    
    if ( read_argv( 1, szMsg, sizeof( szMsg ) ) < 1 ) return PLUGIN_HANDLED;
    
    remove_quotes( szMsg );
    
    static szName[32];
    get_user_name( ply, szName, sizeof( szName ) );
    
    
    client_print_color( 0, ply, "^x04[^x03%s^x04] ^x03%s^x01: %s", g_szPlyRank[ply], szName, szMsg );
    
    return PLUGIN_HANDLED;
}
