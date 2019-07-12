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



forward impulse_on_start_post( ply );
forward impulse_on_reset( ply );
forward impulse_on_end_post( ply, Float:time );

forward impulse_on_ply_id( ply, plyid );

forward impulse_on_send_spec( ply );


native Handle:impulse_getdb();
native impulse_getplyid( ply );
native impulse_getmapid();

native Float:impulse_gettime( ply );
native Float:impulse_getpbtime( ply );

native Float:impulse_getsrtime();
