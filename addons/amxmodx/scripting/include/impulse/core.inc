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


//
// Timer
//
enum
{
    RECORDDATA_STYLE_ID = 0,

    RECORDDATA_TIME,
    RECORDDATA_PREV_PB_TIME,
    RECORDDATA_PREV_BEST_TIME,

    RECORDDATA_SIZE
};


forward impulse_on_start( ply );
forward impulse_on_start_post( ply );
forward impulse_on_reset_post( ply );
forward impulse_on_end_post( ply, const recordData[] );

forward impulse_on_ply_id( ply, plyid );

forward impulse_on_send_spec( ply );

native Float:impulse_getplytime( ply );
native Float:impulse_getplypbtime( ply, styleid );

native bool:impulse_isplyrunning( ply );

native Float:impulse_getsrtime( styleid );

//
// Database
//
native Handle:impulse_getdb();

native impulse_getplyid( ply );
native impulse_getmapid();


//
// Style data
//
#define STYLE_SAFENAME_LENGTH       32
#define STYLE_NAME_LENGTH           32

#define MAX_STYLES                  8

#define INVALID_STYLE               -1

enum
{
    STYLE_SAFENAME[STYLE_SAFENAME_LENGTH] = 0,
    STYLE_NAME[STYLE_NAME_LENGTH],

    STYLE_ID,

    STYLE_ISDEFAULT,

    STYLE_MAXFPS,
    STYLE_NOSTAMINA,
    STYLE_AIRACCEL,
    STYLE_ACCEL,
    STYLE_STOPSPD,
    STYLE_MAXSPD, // Max ground speed
    STYLE_MAXJUMPSPEEDFACTOR, // BUNNYJUMP_MAX_SPEED_FACTOR
    STYLE_AUTOBHOP,
    STYLE_FOLLOWKZRULES,
    STYLE_MAXPRESPEED,

    STYLE_SIZE
};



// Return stop to disable said style from being set.
forward impulse_on_style( ply, styleid );

forward impulse_on_style_post( ply, styleid );

native bool:impulse_getstylename( styleid, name[], len );
native impulse_getdefaultstyleid();
native impulse_getplystyleid( ply );
native bool:impulse_setplystyle( ply, styleid );

native bool:impulse_getstyledata( styleid, data[], size );
