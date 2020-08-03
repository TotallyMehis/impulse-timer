#include <amxmodx>
#include <fakemeta>
#include <orpheu>
#include <orpheu_memory>
#include <orpheu_stocks>


#include <impulse/core>
#include <impulse/defs>
#include <impulse/stocks>



#define DEFAULT_MAX_SPEED                   250.0
#define DEFAULT_MAX_JUMP_SPEED_FACTOR       250.0



#define REG_CVAR(%0)            new g_%0

#define CVAR_POINTER(%0)        g_%0 = get_cvar_pointer( #%0 ); \
                                if ( !g_%0 ) { set_fail_state( "Couldn't find cvar %s!", #%0 ); }

#define CVAR_VAL_F(%0)          _:get_pcvar_float(g_%0)
#define CVAR_VAL_B(%0)          get_pcvar_bool(g_%0)


REG_CVAR(sv_gravity);
REG_CVAR(sv_stopspeed);
REG_CVAR(sv_maxspeed);
REG_CVAR(sv_spectatormaxspeed);
REG_CVAR(sv_accelerate);
REG_CVAR(sv_airaccelerate);
REG_CVAR(sv_wateraccelerate);
REG_CVAR(sv_friction);
REG_CVAR(edgefriction);
REG_CVAR(sv_waterfriction);
REG_CVAR(sv_bounce);
REG_CVAR(sv_stepsize);
REG_CVAR(sv_maxvelocity);
REG_CVAR(sv_zmax);
REG_CVAR(sv_wateramp);
REG_CVAR(mp_footsteps);
//REG_CVAR(sv_rollangle);
//REG_CVAR(sv_rollspeed);
REG_CVAR(sv_skycolor_r);
REG_CVAR(sv_skycolor_g);
REG_CVAR(sv_skycolor_b);
REG_CVAR(sv_skyvec_x);
REG_CVAR(sv_skyvec_y);
REG_CVAR(sv_skyvec_z);
REG_CVAR(sv_skyname);


new Float:g_flPlyAirAccelerate[IMP_MAXPLAYERS];
new Float:g_flPlyAccelerate[IMP_MAXPLAYERS];
new Float:g_flPlyStopSpeed[IMP_MAXPLAYERS];
new Float:g_flPlyMaxSpeed[IMP_MAXPLAYERS];
new Float:g_flPlyMaxJumpSpeedFactor[IMP_MAXPLAYERS];
new bool:g_bPlyNoStamina[IMP_MAXPLAYERS];
new bool:g_bPlyAutoBhop[IMP_MAXPLAYERS];

new bool:g_bResetBunnyhopSpeedFactor = false;


public plugin_init()
{
    register_plugin( IMP_PLUGIN_NAME + " - Test", IMP_PLUGIN_VERSION, IMP_PLUGIN_AUTHOR );


    //
    // PM_Move
    //
    new OrpheuFunction:pmmove = OrpheuGetDLLFunction( "pfnPM_Move", "PM_Move" );
    if ( !pmmove ) set_fail_state( "Couldn't find Orpheu function 'PM_Move'" );
    
    OrpheuRegisterHook( pmmove, "fwdPMMove" );


    //
    // SV_QueryMovevarsChanged
    //
    new OrpheuFunction:querymovevars = OrpheuGetFunction( "SV_QueryMovevarsChanged" );
    if ( !querymovevars ) set_fail_state( "Couldn't find Orpheu function 'SV_QueryMovevarsChanged'" );

    OrpheuRegisterHook( querymovevars, "fwdQueryMovevarsChanged" );
    //OrpheuRegisterHook( querymovevars, "", OrpheuHookPost );

    //
    // SV_SetMoveVars
    //
    new OrpheuFunction:setmovevars = OrpheuGetFunction( "SV_SetMoveVars" );
    if ( !setmovevars ) set_fail_state( "Couldn't find Orpheu function 'SV_SetMoveVars'" );

    OrpheuRegisterHook( setmovevars, "fwdSetMoveVars" );

    //
    // SV_WriteMovevarsToClient
    //
    new OrpheuFunction:writemovevars = OrpheuGetFunction( "SV_WriteMovevarsToClient" );
    if ( !writemovevars ) set_fail_state( "Couldn't find Orpheu function 'SV_WriteMovevarsToClient'" );

    OrpheuRegisterHook( writemovevars, "fwdWriteMovevarsToClient" );


    register_forward( FM_PlayerPreThink, "fwdPlayerPreThink", true );


    //register_clcmd( "hlmove", "cmdSetAA" );



    CVAR_POINTER(sv_gravity)
    CVAR_POINTER(sv_stopspeed)
    CVAR_POINTER(sv_maxspeed)
    CVAR_POINTER(sv_spectatormaxspeed)
    CVAR_POINTER(sv_accelerate)
    CVAR_POINTER(sv_airaccelerate)
    CVAR_POINTER(sv_wateraccelerate)
    CVAR_POINTER(sv_friction)
    CVAR_POINTER(edgefriction)
    CVAR_POINTER(sv_waterfriction)
    CVAR_POINTER(sv_bounce)
    CVAR_POINTER(sv_stepsize)
    CVAR_POINTER(sv_maxvelocity)
    CVAR_POINTER(sv_zmax)
    CVAR_POINTER(sv_wateramp)
    CVAR_POINTER(mp_footsteps)
    //CVAR_POINTER(sv_rollangle)
    //CVAR_POINTER(sv_rollspeed)
    CVAR_POINTER(sv_skycolor_r)
    CVAR_POINTER(sv_skycolor_g)
    CVAR_POINTER(sv_skycolor_b)
    CVAR_POINTER(sv_skyvec_x)
    CVAR_POINTER(sv_skyvec_y)
    CVAR_POINTER(sv_skyvec_z)
    CVAR_POINTER(sv_skyname)


    g_bResetBunnyhopSpeedFactor = true;
}

public plugin_end()
{
    if ( g_bResetBunnyhopSpeedFactor )
    {
        OrpheuMemorySet( "BUNNYJUMP_MAX_SPEED_FACTOR", 1, 1.2 );
    }
}

public impulse_on_style( ply, styleid )
{
    static data[STYLE_SIZE];

    if ( !impulse_getstyledata( styleid, data, sizeof( data ) ) )
    {
        server_print( CONSOLE_PREFIX + "Failed to retrieve style %i data!", styleid );
        return PLUGIN_HANDLED;
    }


    g_flPlyAirAccelerate[ply] = Float:data[STYLE_AIRACCEL];
    g_flPlyAccelerate[ply] = Float:data[STYLE_ACCEL];
    g_flPlyStopSpeed[ply] = Float:data[STYLE_STOPSPD];
    g_flPlyMaxSpeed[ply] = Float:data[STYLE_MAXSPD];
    g_flPlyMaxJumpSpeedFactor[ply] = Float:data[STYLE_MAXJUMPSPEEDFACTOR];
    g_bPlyNoStamina[ply] = data[STYLE_NOSTAMINA] != 0;
    g_bPlyAutoBhop[ply] = data[STYLE_AUTOBHOP] != 0;

    sendNewMoveVars( ply );


    return PLUGIN_CONTINUE;
}

public impulse_on_start( ply )
{
    if ( impulse_getplystyleid( ply ) == INVALID_STYLE )
    {
        client_print_color( ply, ply, CHAT_PREFIX + "No style, no physics, no run." );
        return PLUGIN_HANDLED;
    }
    
    return PLUGIN_CONTINUE;
}

public client_connect( ply )
{
    g_flPlyAirAccelerate[ply] = Float:CVAR_VAL_F(sv_airaccelerate);
    g_flPlyAccelerate[ply] = Float:CVAR_VAL_F(sv_accelerate);
    g_flPlyStopSpeed[ply] = Float:CVAR_VAL_F(sv_stopspeed);
    g_flPlyMaxSpeed[ply] = DEFAULT_MAX_SPEED;
    g_flPlyMaxJumpSpeedFactor[ply] = DEFAULT_MAX_JUMP_SPEED_FACTOR;
    g_bPlyNoStamina[ply] = false;
}

public client_putinserver( ply )
{
    // Make sure the client gets the correct move vars.
    new params[1];
    params[0] = get_user_userid( ply );
    set_task( 2.0, "taskSendMoveVars", _, params, sizeof( params ) );
}

public fwdPlayerPreThink( ply )
{
    if ( is_user_alive( ply ) )
    {
        set_pev( ply, pev_maxspeed, g_flPlyMaxSpeed[ply] );

        if ( g_bPlyNoStamina[ply] )
            set_pev( ply, pev_fuser2, 0.0 );

        if ( g_bPlyAutoBhop[ply] )
        {
            // Hold space for ever!
            set_pev( ply, pev_oldbuttons, pev( ply, pev_oldbuttons ) &~ IN_JUMP );
        }
    }
}


new OrpheuStruct:pmove = OrpheuStruct:0;
public fwdPMMove( OrpheuStruct:ppmove, const server )
{
    pmove = ppmove;

    new ply = OrpheuGetStructMember( pmove, "player_index" ) + 1;
    //server_print( CONSOLE_PREFIX + "PM_Move: %i", ply );


    new OrpheuStruct:movevars = OrpheuStruct:OrpheuGetStructMember( pmove, "movevars" );
    OrpheuSetStructMember( movevars, "airaccelerate", g_flPlyAirAccelerate[ply] );
    OrpheuSetStructMember( movevars, "accelerate", g_flPlyAccelerate[ply] );
    OrpheuSetStructMember( movevars, "stopspeed", g_flPlyStopSpeed[ply] );
    OrpheuMemorySet( "BUNNYJUMP_MAX_SPEED_FACTOR", 1, g_flPlyMaxJumpSpeedFactor[ply] );
}

public fwdQueryMovevarsChanged()
{
    if ( pmove )
    {
        //server_print( CONSOLE_PREFIX + "SV_QueryMovevarsChanged was called, resetting movevars..." );


        new OrpheuStruct:movevars = OrpheuStruct:OrpheuGetStructMember( pmove, "movevars" );
        OrpheuSetStructMember( movevars, "airaccelerate", CVAR_VAL_F(sv_airaccelerate) );
        OrpheuSetStructMember( movevars, "accelerate", CVAR_VAL_F(sv_accelerate) );
        OrpheuSetStructMember( movevars, "stopspeed", CVAR_VAL_F(sv_stopspeed) );

        pmove = OrpheuStruct:0;
    }
    
    //server_print( CONSOLE_PREFIX + "fwdQueryMovevarsChanged" );
}

//public ()
//{
//    OrpheuSetStructMember( OrpheuStruct:OrpheuGetStructMember( pmove, "movevars" ), "airaccelerate",  );
//}

public fwdSetMoveVars()
{
    server_print( CONSOLE_PREFIX + "fwdSetMoveVars" );
}

//OrpheuHookReturn:
public fwdWriteMovevarsToClient()
{
    server_print( CONSOLE_PREFIX + "fwdWriteMovevarsToClient" );
    //return OrpheuSupercede;
}

public taskSendMoveVars( params[] )
{
    new ply = imp_getuserbyuserid( params[0] );
    if ( ply != 0 && is_user_connected( ply ) )
    {
        sendNewMoveVars( ply );
    }
}

stock sendNewMoveVars( ply )
{
    server_print( CONSOLE_PREFIX + "Sending new move vars to %i...", ply );

    message_begin( MSG_ONE, SVC_NEWMOVEVARS, .player = ply );
    write_long( CVAR_VAL_F(sv_gravity) );
    write_long( _:g_flPlyStopSpeed[ply] );
    write_long( CVAR_VAL_F(sv_maxspeed) );
    write_long( CVAR_VAL_F(sv_spectatormaxspeed) );
    write_long( _:g_flPlyAccelerate[ply] );
    write_long( _:g_flPlyAirAccelerate[ply] ); // airaccelerate
    write_long( CVAR_VAL_F(sv_wateraccelerate) );
    write_long( CVAR_VAL_F(sv_friction) );
    write_long( CVAR_VAL_F(edgefriction) );
    write_long( CVAR_VAL_F(sv_waterfriction) );
    write_long( _:1.0 ); // entgravity, always 1
    write_long( CVAR_VAL_F(sv_bounce) );
    write_long( CVAR_VAL_F(sv_stepsize) );
    write_long( CVAR_VAL_F(sv_maxvelocity) );
    write_long( CVAR_VAL_F(sv_zmax) );
    write_long( CVAR_VAL_F(sv_wateramp) );
    write_byte( CVAR_VAL_B(mp_footsteps) );
    write_long( _:0.0 ); // sv_rollangle
    write_long( _:0.0 ); // sv_rollspeed
    write_long( CVAR_VAL_F(sv_skycolor_r) );
    write_long( CVAR_VAL_F(sv_skycolor_g) );
    write_long( CVAR_VAL_F(sv_skycolor_b) );
    write_long( CVAR_VAL_F(sv_skyvec_x) );
    write_long( CVAR_VAL_F(sv_skyvec_y) );
    write_long( CVAR_VAL_F(sv_skyvec_z) );
    write_string( "night" );
    message_end();
}
