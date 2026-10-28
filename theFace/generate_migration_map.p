/*---------------------------------------------------------------------------------------
    File        : generate_migration_map.p
    Purpose     : Parses 'myReport.txt' (dbanalys) and exports an Excel-compatible
                  migration mapping file with thresholds.
    Inputs      : pcNewDataArea, pcNewIndexArea, pcThresholdArea1, pdMaxThresh1, 
                  pcThresholdArea2, pdMaxThresh2, pcThresholdArea3, pdMaxThresh3
------------------------------------------------------------------------------------------*/

DEFINE INPUT PARAMETER pcNewDataArea   AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pcNewIndexArea  AS CHARACTER NO-UNDO.

/* Maximum threshold inputs for up to 3 storage areas */
DEFINE INPUT PARAMETER pcThresholdArea1 AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pdMaxThresh1    AS DECIMAL   NO-UNDO.
DEFINE INPUT PARAMETER pcThresholdArea2 AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pdMaxThresh2    AS DECIMAL   NO-UNDO.
DEFINE INPUT PARAMETER pcThresholdArea3 AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pdMaxThresh3    AS DECIMAL   NO-UNDO.

/* Local Work Variables */
DEFINE VARIABLE cLine         AS CHARACTER NO-UNDO.
DEFINE VARIABLE lTableSection AS LOGICAL   NO-UNDO INITIAL FALSE.
DEFINE VARIABLE cTableName    AS CHARACTER NO-UNDO.
DEFINE VARIABLE cOrigDataArea AS CHARACTER NO-UNDO.
DEFINE VARIABLE cOrigIdxArea  AS CHARACTER NO-UNDO.
DEFINE VARIABLE iWordCount    AS INTEGER   NO-UNDO.

/* Define Temp-Table to hold mapped entries */
DEFINE TEMP-TABLE ttMigrationMap NO-UNDO
    FIELD tTableName    AS CHARACTER
    FIELD tOrigDataArea AS CHARACTER
    FIELD tOrigIdxArea  AS CHARACTER
    FIELD tNewDataArea  AS CHARACTER
    FIELD tNewIdxArea   AS CHARACTER.

/* -------------------------------------------------------------------------
   1. Parse the dbanalys file ('myReport.txt')
   ------------------------------------------------------------------------- */
INPUT FROM "myReport.txt".

REPEAT:
    IMPORT UNFORMATTED cLine.
    cLine = TRIM(cLine).
    
    /* Detect Section Transitions */
    IF cLine BEGINS "RECORD BLOCK SUMMARY" OR cLine BEGINS "TABLE SUMMARY" THEN DO:
        lTableSection = TRUE.
        NEXT.
    END.
    
    IF lTableSection AND (cLine BEGINS "INDEX SUMMARY" OR cLine BEGINS "INDEX BLOCK SUMMARY") THEN DO:
        lTableSection = FALSE.
        LEAVE. /* Stop processing once table definitions are collected */
    END.
    
    /* Process rows inside the Table block */
    IF lTableSection THEN DO:
        /* Skip header lines, separators, and empty lines */
        IF cLine = "" OR cLine BEGINS "-" OR cLine BEGINS "Table" OR cLine BEGINS "Area" THEN 
            NEXT.
            
        /* Extract structural tokens based on multiple spaces */
        /* OpenEdge dbanalys separates columns using layout-adjusted spaces */
        iWordCount = NUM-ENTRIES(cLine, " ").
        
        IF iWordCount >= 2 THEN DO:
            /* Clean up schema prefix if explicitly present (e.g., PUB.Customer -> Customer) */
            cTableName = ENTRY(1, cLine, " ").
            IF cTableName BEGINS "PUB." THEN 
                cTableName = SUBSTRING(cTableName, 5).
                
            cOrigDataArea = ENTRY(2, cLine, " ").
            
            /* Workaround: Since indexes are evaluated in a different section of the 
               report, a common migration baseline assigns matching or layout-grouped IDX areas */
            cOrigIdxArea  = cOrigDataArea + "_IDX". 
            
            /* Store matched definition into data set */
            CREATE ttMigrationMap.
            ASSIGN 
                ttMigrationMap.tTableName    = cTableName
                ttMigrationMap.tOrigDataArea = cOrigDataArea
                ttMigrationMap.tOrigIdxArea  = cOrigIdxArea
                ttMigrationMap.tNewDataArea  = pcNewDataArea
                ttMigrationMap.tNewIdxArea   = pcNewIndexArea.
        END.
    END.
END.

INPUT CLOSE.

/* -------------------------------------------------------------------------
   2. Output Excel-compatible Data Mapping (.csv)
   ------------------------------------------------------------------------- */
OUTPUT TO "Storage_Migration_Report.csv".

/* Write main section header */
PUT UNFORMATTED "Table Name,OrDataArea,OrIndexArea,NewDataArea,NewIndexArea" SKIP.

FOR EACH ttMigrationMap BY ttMigrationMap.tTableName:
    PUT UNFORMATTED 
        '"' ttMigrationMap.tTableName    '",'
        '"' ttMigrationMap.tOrigDataArea '",'
        '"' ttMigrationMap.tOrigIdxArea  '",'
        '"' ttMigrationMap.tNewDataArea  '",'
        '"' ttMigrationMap.tNewIdxArea   '"' SKIP.
END.

/* Space spacer separator */
PUT UNFORMATTED SKIP(2).

/* Write Threshold Allocation Block */
PUT UNFORMATTED "--- STORAGE AREA MAX THRESHOLDS ---" SKIP.
PUT UNFORMATTED "Storage Area Name,Max Allowed Threshold" SKIP.

IF pcThresholdArea1 <> "" THEN 
    PUT UNFORMATTED '"' pcThresholdArea1 '",' pdMaxThresh1 SKIP.
    
IF pcThresholdArea2 <> "" THEN 
    PUT UNFORMATTED '"' pcThresholdArea2 '",' pdMaxThresh2 SKIP.
    
IF pcThresholdArea3 <> "" THEN 
    PUT UNFORMATTED '"' pcThresholdArea3 '",' pdMaxThresh3 SKIP.

OUTPUT CLOSE.

MESSAGE "Migration report generated as 'Storage_Migration_Report.csv' successfully." 
    VIEW-AS ALERT-BOX INFORMATION BUTTONS OK.
