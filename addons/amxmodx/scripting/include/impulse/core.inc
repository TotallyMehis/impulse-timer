#if defined _impulse_core_included
    #endinput
#endif
#define _impulse_core_included


#pragma reqlib impulse_core
#if !defined AMXMODX_NOAUTOLOAD
    #pragma loadlib impulse_core
#endif



#define CHAT_PREFIX                     "^x04[^x03TIMER^x04]^x01 "
#define CONSOLE_PREFIX                  "[TIMER] "



forward timer_on_start_post( ply );
forward timer_on_reset( ply );
forward timer_on_end_post( ply, Float:time );

forward timer_on_send_spec( ply );


native Float:timer_gettime( ply );
native Float:timer_getpbtime( ply );

native Float:timer_getsrtime();


native timer_getrank( ply, rank[], rank_length );



