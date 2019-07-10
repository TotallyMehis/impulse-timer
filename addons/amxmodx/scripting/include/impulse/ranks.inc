#if defined _impulse_ranks_included
    #endinput
#endif
#define _impulse_ranks_included


#pragma reqlib impulse_ranks
#if !defined AMXMODX_NOAUTOLOAD
    #pragma loadlib impulse_ranks
#endif


#define INVALID_RANK_POINTS         -1


native timer_getrankpoints( ply );
native timer_getrank( ply, rank[], rank_length );

