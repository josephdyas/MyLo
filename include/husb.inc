;##############################################################################
;           CONSTANTS AND STRUCTURES FOR MYOS EHCI DRIVE
;==============================================================================
; CONSTANTS
FLAG_INT_ASYNCAD        = 32
FLAG_INT_HSYS_ERROR     = 16
FLAT_INT_FLIST_ROLLOVER = 8
FLAG_INT_PORT_CHANGE    = 4
FLAG_INT_USB_ERROR_INT  = 2
FLAG_INT_USB            = 1

;==============================================================================
; STRUCTURES
struct OPERACIONAL_REGISTER
        command dd ?
        status dd ?
        interrupt dd ?
        frameindex dd ?
        segment dd ?
        framelistbase dd ?
        asynclistadd dd ?
        reserved db 36 dup(?)
        configflag dd ?
        portsc dd ?
ends