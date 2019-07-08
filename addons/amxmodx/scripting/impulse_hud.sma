#include <amxmodx>
#include <fakemeta>

#include <impulse/defs>
#include <impulse/core>
#include <impulse/hud>
#include <impulse/recording>
#include <impulse/stocks>




#define HUD_TIMER_INTERVAL  0.1



new g_fPlyHideFlags[IMP_MAXPLAYERS];



new g_msgFOV;
new Array:g_ArrWater;
new g_nWaterSize;


// CACHE
new g_iMaxPlys;
new g_iTimerEnt; // HUD print ent


new const g_fHideMenuFlags = ( 1 << 0 | 1 << 1 | 1 << 2 | 1 << 3 | 1 << 4 | 1 << 9 );


public plugin_init()
{
    register_plugin( IMP_PLUGIN_NAME + " - HUD", IMP_PLUGIN_VERSION, IMP_PLUGIN_AUTHOR );


    // Forwards
    register_forward( FM_AddToFullPack, "fwdAddToFullPackPost", true ); // To hide players and water.
    register_forward( FM_Think, "fwdThink", true ); // Used for recording.


    // Msgs
    g_msgFOV = get_user_msgid( "SetFOV" );


    // Events
    register_event( "CurWeapon", "eventCurWeapon", "b", "1=1" );
    timer_onroundrestart( "eventRoundStart" );


    // Commands
    new const szCmdChangeFOV[] = "cmdChangeFOV";
    register_clcmd( "fov", szCmdChangeFOV );
    register_clcmd( "fieldofview", szCmdChangeFOV );

    new const szCmdHideMenu[] = "cmdHideMenu";
    register_clcmd( "say /hide", szCmdHideMenu );
    register_clcmd( "say hide", szCmdHideMenu );
    register_clcmd( "say /players", szCmdHideMenu );
    register_clcmd( "say players", szCmdHideMenu );
    register_clcmd( "say /hideplayers", szCmdHideMenu );
    register_clcmd( "say hideplayers", szCmdHideMenu );
    register_clcmd( "say /water", szCmdHideMenu );
    register_clcmd( "say water", szCmdHideMenu );
    register_clcmd( "say /hidewater", szCmdHideMenu );
    register_clcmd( "say hidewater", szCmdHideMenu );
    register_clcmd( "say /viewmodel", szCmdHideMenu );
    register_clcmd( "say viewmodel", szCmdHideMenu );
    register_clcmd( "say /vm", szCmdHideMenu );
    register_clcmd( "say vm", szCmdHideMenu );
    register_clcmd( "say /hud", szCmdHideMenu );
    register_clcmd( "say hud", szCmdHideMenu );

    register_menucmd( register_menuid( "HideMenu" ), g_fHideMenuFlags, "menuHide" );



    // Misc
    g_iMaxPlys = get_maxplayers();


    // Entities
    new const class_alloc = engfunc( EngFunc_AllocString, "info_target" );

    // Create timer entity.
    g_iTimerEnt = engfunc( EngFunc_CreateNamedEntity, class_alloc );
    set_pev( g_iTimerEnt, pev_classname, "plugin_timer" );
    set_pev( g_iTimerEnt, pev_nextthink, get_gametime() + 1.5 );
}

public plugin_natives()
{
    register_library( "impulse_hud" );

    register_native( "timer_gethideflags", "_timer_gethideflags" );
}

public client_putinserver( ply )
{
    g_fPlyHideFlags[ply] = 0;
}

public fwdThink( ent )
{
    if ( g_iTimerEnt == ent )
    {
        handlePlyTimers();
        set_pev( ent, pev_nextthink, get_gametime() + HUD_TIMER_INTERVAL );
    }
}

public fwdAddToFullPackPost( es_handle, e, ent, host, hostflags, player, pSet )
{
    // Entity we're sending is a player?
    if ( player )
    {
        // if (  ent != host && is_user_bot( ent ) )
        // {
        //     set_es( es_handle, ES_Effects, 0 );
        //     return FMRES_HANDLED;
        // }

        // Do we want to hide this player?
        if ( ent != host && g_fPlyHideFlags[host] & HIDEHUD_PLAYERS )
        {
            // Only hide if we're alive or we're not spectating this player.
            if ( isPlyAlive( host ) || getSpectatorTarget( host ) != ent )
            {
                set_es( es_handle, ES_Effects, EF_NODRAW );
                return FMRES_HANDLED;
            }
        }
    }
    // Not a player, see if it's water.
    else if ( g_fPlyHideFlags[host] & HIDEHUD_WATER && isWater( ent ) )
    {
        set_es( es_handle, ES_Effects, EF_NODRAW );
        return FMRES_HANDLED;
    }

    return FMRES_IGNORED;
}

public eventRoundStart()
{
    set_task( 0.1, "taskMapStuff" );
}

public eventCurWeapon( ply )
{
    if ( g_fPlyHideFlags[ply] & HIDEHUD_VM ) set_pev( ply, pev_viewmodel2, "" );
}

public taskMapStuff()
{
    new ent = 0;

    // Find water entities to hide from players.
    g_ArrWater = ArrayCreate( 1, 1 );
    while ( (ent = engfunc( EngFunc_FindEntityByString, ent, "classname", "func_water" )) > 0 )
        if ( pev_valid( ent ) )
            ArrayPushCell( g_ArrWater, ent );
    
    g_nWaterSize = ArraySize( g_ArrWater );
}

stock handlePlyTimers()
{
    static ply;
    static target;
    static szFormatted[12]; // "XX:XX.XX"
    static szRecName[32];
    static szRank[32];
    static hideflags;
    static Float:time;


    for ( ply = 1; ply <= g_iMaxPlys; ply++ )
    {
        if ( !is_user_connected( ply ) ) continue;
        
        
        if ( !isPlyAlive( ply ) )
        {
            if ( pev( ply, pev_iuser1 ) != OBS_IN_EYE ) continue;
            

            target = getSpectatorTarget( ply );

            if ( target == ply || !isPlyAlive( target ) ) continue;
        }
        else
        {
            target = ply;
        }


        
        
        if ( timer_isrecordbot( target ) )
        {
            timer_getrecordinginfo( target, time, szRecName, sizeof( szRecName ) );

            timer_formatSeconds( time, szFormatted, sizeof( szFormatted ) );
            set_hudmessage( 255, 255, 255, -1.0, 0.7, 0, 0.0, 0.1, 0.02, 0.02 );
            show_hudmessage( ply, "Replay Bot^n%s^n%s", szRecName, szFormatted );
            
            continue;
        }
        

        hideflags = g_fPlyHideFlags[ply];
        
        if ( !(hideflags & HIDEHUD_PB) )
        {
            time = timer_getpbtime( target );

            if ( time == INVALID_TIME )
            {
                copy( szFormatted, sizeof( szFormatted ) , "N/A" );
            }
            else
            {
                timer_formatSeconds( time, szFormatted, sizeof( szFormatted ), true );
            }


            timer_getrank( target, szRank, sizeof( szRank ) );
            

            set_hudmessage( 255, 255, 255, -1.0, 0.01, 0, 0.0, 0.1, 0.02, 0.02 );
            show_hudmessage( ply, "PB: %s^nRank: %s", szFormatted, szRank );
        }
        
        if ( !(hideflags & HIDEHUD_TIME) )
        {
            time = timer_gettime( target );
            
            set_hudmessage( 255, 255, 255, -1.0, 0.7, 0, 0.0, 0.1, 0.02, 0.02 );
            
            if ( time == INVALID_TIME )
            {
                show_hudmessage( ply, "Press Start Button^n%3.0f ups", timer_getspeed2d( target ) );
            }
            else
            {
                timer_formatSeconds( time, szFormatted, sizeof( szFormatted ) );
                show_hudmessage( ply, "%s^n%3.0f ups", szFormatted, timer_getspeed2d( target ) );
            }
        }
    }    
}

public cmdHideMenu( ply )
{
    static szOption[][] = { "\wON", "\dOFF" };
    static szMenu[256];

    new len = 0;
    
    len += format( szMenu[len], sizeof( szMenu ) - len, "\r1. \yViewmodel: %s^n", ( g_fPlyHideFlags[ply] & HIDEHUD_VM ) ? szOption[1] : szOption[0] );
    len += format( szMenu[len], sizeof( szMenu ) - len, "\r2. \yWater: %s^n", ( g_fPlyHideFlags[ply] & HIDEHUD_WATER ) ? szOption[1] : szOption[0] );
    len += format( szMenu[len], sizeof( szMenu ) - len, "\r3. \yPlayers: %s^n", ( g_fPlyHideFlags[ply] & HIDEHUD_PLAYERS ) ? szOption[1] : szOption[0] );
    len += format( szMenu[len], sizeof( szMenu ) - len, "\r4. \yHUD (TOP): %s^n", ( g_fPlyHideFlags[ply] & HIDEHUD_PB ) ? szOption[1] : szOption[0] );
    len += format( szMenu[len], sizeof( szMenu ) - len, "\r5. \yHUD (TIME/SPEED): %s^n^n", ( g_fPlyHideFlags[ply] & HIDEHUD_TIME ) ? szOption[1] : szOption[0] );
    
    len += format( szMenu[len], sizeof( szMenu ) - len, "\r0. \yExit" );
    
    show_menu( ply, g_fHideMenuFlags, szMenu, -1, "HideMenu" );
    
    return PLUGIN_HANDLED;
}

public cmdChangeFOV( ply )
{
    if ( read_argc() < 1 ) return PLUGIN_HANDLED;
    
    new szFOV[4];
    read_argv( 1, szFOV, sizeof( szFOV ) );
    
    new fov = str_to_num( szFOV );
    
    if ( fov > 130 )
    {
        client_print_color( ply, print_chat, CHAT_PREFIX + "Your requested FOV was too high!" );
        return PLUGIN_HANDLED;
    }
    else if ( fov < 75 )
    {
        client_print_color( ply, print_chat, CHAT_PREFIX + "Your requested FOV was too low!" );
        return PLUGIN_HANDLED;
    }
    
    message_begin( MSG_ONE_UNRELIABLE, g_msgFOV, _, ply );
    write_byte( fov );
    message_end();
    
    client_print_color( ply, print_console, CHAT_PREFIX + "Your FOV is now ^x03%i^x01!", fov );
    
    return PLUGIN_HANDLED;
}

public menuHide( ply, key )
{
    switch ( key )
    {
        case 0 :
        {
            if ( g_fPlyHideFlags[ply] & HIDEHUD_VM ) g_fPlyHideFlags[ply] &= ~HIDEHUD_VM;
            else g_fPlyHideFlags[ply] |= HIDEHUD_VM;

            eventCurWeapon( ply );
        }
        case 1 :
        {
            if ( g_fPlyHideFlags[ply] & HIDEHUD_WATER ) g_fPlyHideFlags[ply] &= ~HIDEHUD_WATER;
            else g_fPlyHideFlags[ply] |= HIDEHUD_WATER;
        }
        case 2 :
        {
            if ( g_fPlyHideFlags[ply] & HIDEHUD_PLAYERS ) g_fPlyHideFlags[ply] &= ~HIDEHUD_PLAYERS;
            else g_fPlyHideFlags[ply] |= HIDEHUD_PLAYERS;
        }
        case 3 :
        {
            if ( g_fPlyHideFlags[ply] & HIDEHUD_PB ) g_fPlyHideFlags[ply] &= ~HIDEHUD_PB;
            else g_fPlyHideFlags[ply] |= HIDEHUD_PB;
        }
        case 4 :
        {
            if ( g_fPlyHideFlags[ply] & HIDEHUD_TIME ) g_fPlyHideFlags[ply] &= ~HIDEHUD_TIME;
            else g_fPlyHideFlags[ply] |= HIDEHUD_TIME;
        }
        default :
        {
            hideHideMenu( ply );
        }
    }
}


stock bool:isWater( ent )
{
    static i;
    for ( i = 0; i < g_nWaterSize; i++ )
    {
        if ( ent == ArrayGetCell( g_ArrWater, i ) ) return true;
    }
    
    return false;
}

stock bool:isPlyAlive( ply )
{
    return pev( ply, pev_deadflag ) == DEAD_NO;
}

stock getSpectatorTarget( ply )
{
    return pev( ply, pev_iuser2 );
}

stock showHideMenu( ply )
{
    show_menu( ply, -1, "HideMenu" );
}

stock hideHideMenu( ply )
{
    show_menu( ply, 0, "HideMenu" );
}

public _timer_gethideflags(id, num)
{
	new ply = get_param( 1 );
	return g_fPlyHideFlags[ply];
}

