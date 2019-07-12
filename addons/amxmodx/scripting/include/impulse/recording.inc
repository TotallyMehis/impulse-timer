#if defined _impulse_recording_included
    #endinput
#endif
#define _impulse_recording_included


#pragma reqlib impulse_recording
#if !defined AMXMODX_NOAUTOLOAD
    #pragma loadlib impulse_recording
#endif


native bool:impulse_isrecordbot( ply );
native bool:impulse_getrecordinginfo( ply, &Float:rectime, recname[], recname_length );
