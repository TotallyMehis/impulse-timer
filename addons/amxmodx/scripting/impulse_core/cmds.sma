public cmdBlocked( ply )
{
    return PLUGIN_HANDLED;
}

public cmdSay( ply )
{
    // say /style
    if ( read_argc() < 2 )
    {
        return PLUGIN_CONTINUE;
    }


    new szCmd[64];
    read_argv( 1, szCmd, charsmax( szCmd ) );

    // Style command
    new styleid = INVALID_STYLE;

    if ( TrieGetCell( g_trieStyleCmds, szCmd, styleid ) )
    {
        setPlyStyle( ply, styleid, true );

        return PLUGIN_HANDLED;
    }
    
    return PLUGIN_CONTINUE;
}

public cmdSpawn( ply )
{
    server_print( CONSOLE_PREFIX + "Spawning ply: %i | time: %.1f", ply, get_gametime() );


    if ( cs_get_user_team( ply ) != g_iPrefferedTeam )
        cs_set_user_team( ply, g_iPrefferedTeam );
    
    
    if ( pev( ply, pev_deadflag ) != DEAD_NO )
    {
        ExecuteHam( Ham_CS_RoundRespawn, ply );
    }
    

    if ( g_bHasStart )
    {
        set_pev( ply, pev_origin, g_vecStartPos );
    }
    
    //set_pev( ply, pev_angles, g_vecNull );
    set_pev( ply, pev_velocity, g_vecNull );


    // Give weapons.
    new num = 0;
    new weapons[32];
    get_user_weapons( ply, weapons, num );

    if ( !num )
    {
        fm_give_item( ply, "weapon_knife" );
        fm_give_item( ply, "weapon_usp" );
    }


    sendResetFwd( ply );
    
    return PLUGIN_HANDLED;
}

public cmdShowRecords( ply )
{
    if ( g_flPlyWarning[ply] > get_gametime() ) return PLUGIN_HANDLED;
    
    g_flPlyWarning[ply] = get_gametime() + WARNING_INTERVAL;
    

    dbPrintRecords( ply, g_iMapId );
    
    return PLUGIN_HANDLED;
}

public cmdShowHelp( ply )
{
    if ( g_flPlyWarning[ply] > get_gametime() ) return PLUGIN_HANDLED;
    
    g_flPlyWarning[ply] = get_gametime() + WARNING_INTERVAL;
    
    client_print( ply, print_chat, "Chat Commands: /start, /wr, /hide - Console commands: fov <num>" );
    
    return PLUGIN_HANDLED;
}

public cmdNoclip( ply )
{
    if ( !is_user_alive( ply ) )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "You must be alive to use this command!" );
        return PLUGIN_HANDLED;
    }
    

    sendResetFwd( ply );

    
    if ( pev( ply, pev_movetype ) != MOVETYPE_WALK )
    {
        set_pev( ply, pev_movetype, MOVETYPE_WALK );
        client_print_color( ply, ply, CHAT_PREFIX + "Noclip off." );
    }
    else
    {
        set_pev( ply, pev_movetype, MOVETYPE_NOCLIP );
        client_print_color( ply, ply, CHAT_PREFIX + "Noclip on." );
    }
    
    return PLUGIN_HANDLED;
}

public cmdSpectate( ply )
{
    toSpec( ply );
    
    return PLUGIN_HANDLED;
}

public cmdSetStyle( ply )
{
    new szCmd[64];
    read_args( szCmd, charsmax( szCmd ) );
    remove_quotes( szCmd );

    // Skip over '/'
    new index = 0;

    if ( szCmd[index] == '/' )
    {
        ++index;
    }

    new cmdname[STYLE_SAFENAME_LENGTH];
    copy( cmdname, charsmax( cmdname ), szCmd[index] );
    


    new shortname[STYLE_SAFENAME_LENGTH];

    for ( new styleIndex = 0; styleIndex < g_nStyles; styleIndex++ )
    {
        getStyleSafeName( styleIndex, shortname, charsmax( shortname ) );

        if ( equali( shortname, cmdname ) )
        {
            if ( setPlyStyle( ply, getStyleId( styleIndex ), true ) )
            {
                return PLUGIN_HANDLED;
            }
        }
    }

    return PLUGIN_CONTINUE;
}

public cmdStyleMenu( ply )
{
    static szOption[][] = { "\w", "\y" };
    static szMenu[256];
    static szStyleName[64];


    new myStyleId = impulse_getplystyleid( ply );

    new len = 0;
    new fMenuFlags = MENU_KEY_0;

    new numStyles = ArraySize( g_arrStyles );


    len += format( szMenu[len], charsmax( szMenu ) - len, "\yStyles Menu^n^n" );
    
    for ( new i = 0; i < numStyles; i++ )
    {
        getStyleName( i, szStyleName, charsmax( szStyleName ) );

        new clrIndex = ( myStyleId == getStyleId( i ) ) ? 1 : 0;

        len += format( szMenu[len], charsmax( szMenu ) - len, "\w%i. %s%s^n",
            i + 1,
            szOption[clrIndex],
            szStyleName );


        fMenuFlags |= ( 1 << i );
    }


    len += format( szMenu[len], charsmax( szMenu ) - len, "^n\w0. Exit" );


    show_menu( ply, fMenuFlags, szMenu, -1, STYLEMENU_NAME );
}

public menuStyles( ply, key )
{
    new bool:bChangeStyle = key >= 0 && key < ArraySize( g_arrStyles );

    if ( bChangeStyle )
    {
        setPlyStyle( ply, getStyleId( key ), true );
    }
}
