#if defined _impulse_hud_included
    #endinput
#endif
#define _impulse_hud_included


#pragma reqlib impulse_hud
#if !defined AMXMODX_NOAUTOLOAD
    #pragma loadlib impulse_hud
#endif


#define HIDEHUD_VM      ( 1 << 0 )
#define HIDEHUD_PLAYERS ( 1 << 1 )
#define HIDEHUD_WATER   ( 1 << 2 )
#define HIDEHUD_PB      ( 1 << 3 )
#define HIDEHUD_TIME    ( 1 << 4 )



native timer_gethideflags( ply );
