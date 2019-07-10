public cmdBlocked( ply ) return PLUGIN_HANDLED;

public cmdSpawn( ply )
{
    if ( cs_get_user_team( ply ) != g_iPrefferedTeam )
        cs_set_user_team( ply, g_iPrefferedTeam );
    
    
    if ( pev( ply, pev_deadflag ) != DEAD_NO )
    {
        ExecuteHam( Ham_CS_RoundRespawn, ply );
        fm_give_item( ply, "weapon_knife" );
    }
    
    //set_pev( ply, pev_angles, g_vecNull );
    set_pev( ply, pev_origin, g_vecStartPos );
    set_pev( ply, pev_velocity, g_vecNull );


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