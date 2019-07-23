#if defined _impulse_stocks_included
    #endinput
#endif
#define _impulse_stocks_included


#define SAYTRIGGER_FILE             "/configs/impulse_saytriggers.ini"


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

stock bool:imp_db_failstate( failstate, const error[], errnum, const additional[] = "N/A" )
{
    if ( failstate != TQUERY_SUCCESS )
    {
        server_print( CONSOLE_PREFIX + "SQL Query error %i (%s): %s", errnum, error, additional );
        return true;
    }

    return false;
}

// Register say triggers (ie. 'say /spawn') from file per section name.
stock imp_registertriggers( const section[], const function[] )
{
    new szFile[256];
    
    get_basedir( szFile, sizeof( szFile ) );
    add( szFile, sizeof( szFile ), SAYTRIGGER_FILE );
    if ( !file_exists( szFile ) )
    {
        return -1;
    }


    new Array:arr = ArrayCreate( 64 );
    ArrayPushString( arr, section );

    new INIParser:parser = INI_CreateParser();

    INI_SetReaders( parser, "_imp_registertriggers_kv", "_imp_registertriggers_ns" );
    INI_ParseFile( parser, szFile, .data = arr );

    INI_DestroyParser( parser );


    new szTrigger[128];
    new szOut[128];


    new len = ArraySize( arr );
    for ( new i = 2; i < len; i++ )
    {
        ArrayGetString( arr, i, szTrigger, sizeof( szTrigger ) );

        formatex( szOut, sizeof( szOut ), "say %s", szTrigger );

        register_clcmd( szOut, function );
    }


    ArrayDestroy( arr );

    return len - 1;
}

public bool:_imp_registertriggers_ns( INIParser:handle, const section[], bool:invalid_tokens, bool:close_bracket, bool:extra_tokens, curtok, Array:arr )
{
    // We wrote to this array, which means we found the right section.
    // New section, so break this.
    if ( ArraySize( arr ) > 1 ) return false;


    new mysection[32];
    ArrayGetString( arr, 0, mysection, sizeof( mysection ) );

    if ( equali( mysection, section ) )
    {
        // Length > 1 means we're in the correct section.
        ArrayPushString( arr, "" );
    }

    return true;
}

public bool:_imp_registertriggers_kv( INIParser:handle, const key[], const value[], bool:invalid_tokens, bool:equal_token, bool:quotes, curtok, Array:arr )
{
    if ( ArraySize( arr ) > 1 )
    {
        ArrayPushString( arr, key );
    }

    return true;
}
