        FUNCTION BREAK_PATH, PATHS, NOCURRENT=NOCURRENT
;+
; NAME: 
;    BREAK_PATH()
;
; PURPOSE: 
;     Breaks up a path string into its component directories.
;
; CALLING SEQUENCE: 
;     Result = BREAK_PATH( PATHS [ /NoCurrent])
;
; INPUTS: 
;     PATHS   = A string containing one or more directory paths.  The
;               individual paths are separated by commas, although in UNIX, 
;               colons can also be used.  In other words, PATHS has the same 
;               format as !PATH, except that commas can be used as a separator 
;               regardless of operating system.
;
;               A leading $ can be used in any path to signal that what follows 
;               is an environmental variable, but the $ is not necessary.  (In 
;               VMS the $ can either be part of the path, or can signal logical
;               names for compatibility with Unix.)  Environmental variables
;               can themselves contain multiple paths.
;
; OUTPUT: 
;      The result of the function is a string array of directories.
;      Unless the NOCURRENT keyword is set, the first element of the array is 
;      always the null string, representing the current directory.  All the 
;      other directories will end in the correct separator character for the 
;      current operating system.
;
; OPTIONAL INPUT KEYWORD:
;      /NOCURRENT = If set, then the current directory (represented by
;               the null string) will not automatically be prepended to the
;               output.
;
; PROCEDURE CALLS:
;      Functions:  STR_SEP()
;
; REVISION HISTORY:
;       Version 1, William Thompson, GSFC, 6 May 1993.
;               Added IDL for Windows compatibility.
;       Version 2, William Thompson, GSFC, 16 May 1995
;               Added keyword NOCURRENT
;       Version 3, William Thompson, GSFC, 29 August 1995
;               Modified to use OS_FAMILY
;       Version 4, Zarro, GSFC, 4 August 1997
;               Added trim to input
;       Converted to IDL V5.0   W. Landsman 25-Nov-1997
;       Fix directory character on Macintosh system   A. Ferro   February 2000
;-
;
        ON_ERROR, 2
;
;  Check the number of parameters:
;
        IF SIZE(PATHS,/TNAME) NE 'STRING' THEN MESSAGE,       $
                'Syntax:  Result = BREAK_PATH( PATHS )'
        PATHS=STRTRIM(PATHS,2)
;
;  Reformat PATHS into an array.  The first element is the null string.  In
;  Unix, both the comma and colon character can be separators, so two passes
;  are needed to extract everything.  The same is true for Microsoft Windows
;  and semi-colons.
;
        CASE !VERSION.OS_FAMILY OF
                'vms':  SEP = ','
                'Windows':  SEP = ';'
                'MacOS': SEP = ','
                ELSE:  SEP = ':'
        ENDCASE
        PATH = ''
        TEMP = STR_SEP(PATHS,SEP)
        FOR I = 0,N_ELEMENTS(TEMP)-1 DO         $       ;Second pass.
                PATH = [PATH, STR_SEP(TEMP[I],',')]
;
;  For each path, see if it is really an environment variable.  If so, then
;  decompose the environmental variable into its constituent paths.
;
        I = 0
        WHILE I LT N_ELEMENTS(PATH) DO BEGIN
;
;  First, try the path by itself.  Remove any trailing "/", "\", or ":"
;  characters.  In VMS, GETENV requires an uppercase argument.
;
                CHAR = STRMID(PATH[I],STRLEN(PATH[I])-1,1)
                IF (CHAR EQ '/') OR (CHAR EQ '\') OR (CHAR EQ ':') THEN $
                        PATH[I] = STRMID(PATH[I],0,STRLEN(PATH[I])-1)
                TEMP = PATH[I]
                IF !VERSION.OS EQ 'vms' THEN TEMP = STRUPCASE(TEMP)
                TEST = GETENV(TEMP)
;
;  If that doesn't yield anything, and the path begins with the $ prompt, then
;  try what follows after the $.
;
                IF TEST EQ '' THEN IF STRMID(PATH[I],0,1) EQ '$' THEN BEGIN
                        FOLLOWING = STRMID(TEMP,1,STRLEN(TEMP)-1)
                        TEST = GETENV(FOLLOWING)
;
;  In VMS, don't decompose logical names, because of the possibility that a
;  logical name may have more than one translation.  Simply substitute the true
;  logical name for the one preceeded by the $, if necessary.
;
                        IF (TEST NE '') AND (!VERSION.OS EQ 'vms') THEN $
                                PATH[I] = FOLLOWING
                ENDIF
;
;  On the other hand, if the value of the logical name contains any commas,
;  then assume that this will itself be a series of paths.
;
                IF (!VERSION.OS EQ 'vms') AND (STRPOS(TEST,',') LT 0) THEN $
                        TEST = ''
;
;  If something was found, then decompose this into whatever paths it may
;  contain.
;
                IF TEST NE '' THEN BEGIN
                        PTH = ''
                        TEMP = STR_SEP(TEST,SEP)
                        FOR J = 0,N_ELEMENTS(TEMP)-1 DO         $
                                PTH = [PTH, STR_SEP(TEMP[J],',')]
                        PTH = PTH[1:*]
;
;  Insert this sublist into the main path list.
;
                        IF N_ELEMENTS(PATH) EQ 1 THEN BEGIN
                                PATH = PTH
                        END ELSE IF I EQ 0 THEN BEGIN
                                PATH = [PTH,PATH[1:*]]
                        END ELSE IF I EQ N_ELEMENTS(PATH)-1 THEN BEGIN
                                PATH = [PATH[0:I-1],PTH]
                        END ELSE BEGIN
                                PATH = [PATH[0:I-1],PTH,PATH[I+1:*]]
                        ENDELSE
;
;  Otherwise, check whether or not the path ends in the correct character.  In
;  VMS, if the path does not end in "]" or ":", then append the ":" character.
;  In Unix, if the path does not end in "/" then append it.  Do the same with
;  the "\" character in Microsoft Windows.  This step is only taken once the
;  routine has completely decomposed this part of the path list.
;
                END ELSE BEGIN
                        IF PATH[I] NE '' THEN BEGIN
                            LAST = STRMID(PATH[I], STRLEN(PATH[I])-1, 1)
                            CASE !VERSION.OS_FAMILY OF
                                'vms':  IF (LAST NE ']') AND (LAST NE ':') $
                                                THEN PATH[I] = PATH[I] + ':'
                                'Windows':  IF LAST NE '\' THEN $
                                                PATH[I] = PATH[I] + '\'
                                'MacOS': IF LAST NE ':' THEN $
                                 			PATH[I] = PATH[I] + ':'
                                ELSE:  IF LAST NE '/' THEN      $
                                                PATH[I] = PATH[I] + '/'
                            ENDCASE
                        ENDIF
;
;  Advance to the next path, and continue.
;
                        I = I + 1
                ENDELSE
        ENDWHILE
;
;  If the NOCURRENT keyword was set, then remove the first element which
;  represents the current directory
;
        IF KEYWORD_SET(NOCURRENT) AND (N_ELEMENTS(PATH) GT 1) THEN      $
                PATH = PATH[1:*]
;
        RETURN, PATH
        END
