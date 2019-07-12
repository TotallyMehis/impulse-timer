#if defined _impulse_stocks_included
    #endinput
#endif
#define _impulse_stocks_included


stock imp_onroundrestart( const function[] )
{
    register_event( "HLTV", function, "a", "1=0", "2=0" );
}


static Float:_vecVel[3];
stock Float:imp_getspeed2d( ply )
{
    pev( ply, pev_velocity, _vecVel );
    return floatsqroot( _vecVel[0] * _vecVel[0] + _vecVel[1] * _vecVel[1] );
}

stock Float:imp_getspeed3d( ply )
{
    pev( ply, pev_velocity, _vecVel );
    return floatsqroot( _vecVel[0] * _vecVel[0] + _vecVel[1] * _vecVel[1] + _vecVel[2] * _vecVel[2] );
}

static _szMins[3];
static _szSecs[6];
stock imp_formatseconds( const Float:in_secs, szTarget[], nLength, bool:bIsDeci = false )
{
    new Float:secs = 0.0;
    new iMins = 0;
    
    if ( in_secs > 0.0 ) 
    {
        iMins = floatround( in_secs / 60.0, floatround_method:floatround_floor );
        secs = in_secs - iMins * 60.0;
    }

    
    formatex( _szMins, sizeof( _szMins ), ( iMins < 10 ) ? "0%i" : "%i", iMins );
    
    if ( bIsDeci )  formatex( _szSecs, sizeof( _szSecs ), ( secs < 10.0 ) ? "0%.2f" : "%.2f", secs );
    else            formatex( _szSecs, sizeof( _szSecs ), ( secs < 10.0 ) ? "0%.1f" : "%.1f", secs );
    
    formatex( szTarget, nLength, "%s:%s", _szMins, _szSecs );
}

stock imp_getsafemapname( out[], out_len )
{
    get_mapname( out, out_len );
    
    new len = strlen( out );
    for ( new i = 0; i < len; i++ ) char_to_lower( out[i] );
}

stock imp_getuserbyuserid( userid )
{
    return find_player( "k", userid );
}
