#if defined _impulse_stocks_included
    #endinput
#endif
#define _impulse_stocks_included


stock timer_onroundrestart( const function[] )
{
    register_event( "HLTV", function, "a", "1=0", "2=0" );
}


static Float:_vecVel[3];
stock Float:timer_getspeed2d( ply )
{
    pev( ply, pev_velocity, _vecVel );
    return floatsqroot( _vecVel[0] * _vecVel[0] + _vecVel[1] * _vecVel[1] );
}

stock Float:timer_getspeed3d( ply )
{
    pev( ply, pev_velocity, _vecVel );
    return floatsqroot( _vecVel[0] * _vecVel[0] + _vecVel[1] * _vecVel[1] + _vecVel[2] * _vecVel[2] );
}

static _szMins[3];
static _szSecs[6];
stock timer_formatSeconds( const Float:in_secs, szTarget[], nLength, bool:bIsDeci = false )
{
    new iMins = floatround( in_secs / 60.0, floatround_method:floatround_floor );

    new Float:secs = in_secs - iMins * 60.0;

    
    formatex( _szMins, sizeof( _szMins ), ( iMins < 10 ) ? "0%i" : "%i", iMins );
    
    if ( bIsDeci )  formatex( _szSecs, sizeof( _szSecs ), ( secs < 10.0 ) ? "0%.2f" : "%.2f", secs );
    else            formatex( _szSecs, sizeof( _szSecs ), ( secs < 10.0 ) ? "0%.1f" : "%.1f", secs );
    
    formatex( szTarget, nLength, "%s:%s", _szMins, _szSecs );
}

stock timer_getsafemapname( out[], out_len )
{
    get_mapname( out, out_len );
    
    new len = strlen( out );
    for ( new i = 0; i < len; i++ ) char_to_lower( out[i] );
}

stock timer_getuserbyuserid( userid )
{
    return find_player( "k", userid );
}
