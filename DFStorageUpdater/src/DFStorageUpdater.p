/*------------------------------------------------------------------------
  DFUpdMain.p

  Purpose : Rewrite AREA lines in a Progress .df file based on a CSV map.
            Streams line-by-line - safe for very large .df files.

  Params  : SESSION:PARAMETER = "input.df,output.df,map.csv,report.txt"

  CSV     : TableName,ORTableStorageArea,ORIndexStorageArea,NewTableStorageArea,NewIndexStorageArea
            (first row = header, skipped)

  Notes   : Handles ADD TABLE / ADD INDEX blocks only.
            AREA match is on the FIRST quoted token - an optional area
            description after it is preserved on output.
------------------------------------------------------------------------*/
DEFINE INPUT PARAMETER cInputDF    AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER cOutputDF   AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER cCSVMap     AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER cReportFile AS CHARACTER NO-UNDO.

DEFINE TEMP-TABLE ttMap NO-UNDO
    FIELD cTableName   AS CHARACTER
    FIELD cTableUpper  AS CHARACTER
    FIELD cOrigTblArea AS CHARACTER
    FIELD cOrigIdxArea AS CHARACTER
    FIELD cNewTblArea  AS CHARACTER
    FIELD cNewIdxArea  AS CHARACTER
    FIELD cUsed        AS LOGICAL INITIAL NO
    INDEX idxKey IS UNIQUE PRIMARY cTableUpper.

DEFINE TEMP-TABLE ttLog NO-UNDO
    FIELD cSev AS CHARACTER
    FIELD cMsg AS CHARACTER
    INDEX idxSeq cSev.

DEFINE STREAM sIn.
DEFINE STREAM sOut.
DEFINE STREAM sCsv.
DEFINE STREAM sRep.

DEFINE VARIABLE cParams        AS CHARACTER NO-UNDO.
/*DEFINE VARIABLE cInputDF       AS CHARACTER NO-UNDO.
DEFINE VARIABLE cOutputDF      AS CHARACTER NO-UNDO.
DEFINE VARIABLE cCSVMap        AS CHARACTER NO-UNDO.
DEFINE VARIABLE cReportFile    AS CHARACTER NO-UNDO.*/
DEFINE VARIABLE cLine          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cTrim          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cCurType       AS CHARACTER NO-UNDO.   /* "T"=table  "I"=index  ""=none */
DEFINE VARIABLE cCurTable      AS CHARACTER NO-UNDO.
DEFINE VARIABLE cCurTableUpper AS CHARACTER NO-UNDO.
DEFINE VARIABLE cAreaName      AS CHARACTER NO-UNDO.
DEFINE VARIABLE cNewLine       AS CHARACTER NO-UNDO.
DEFINE VARIABLE cToken         AS CHARACTER NO-UNDO.
DEFINE VARIABLE iLineNum       AS INTEGER   NO-UNDO.
DEFINE VARIABLE iCsvLine       AS INTEGER   NO-UNDO.
DEFINE VARIABLE iTblMoved      AS INTEGER   NO-UNDO.
DEFINE VARIABLE iIdxMoved      AS INTEGER   NO-UNDO.
DEFINE VARIABLE iAreaMismatch  AS INTEGER   NO-UNDO.
DEFINE VARIABLE iBlocksNoMap   AS INTEGER   NO-UNDO.

/*------------------------------------------------------------------------
  Functions
------------------------------------------------------------------------*/
FUNCTION GetFirstQuoted RETURNS CHARACTER (INPUT cLine AS CHARACTER):
    /* returns the first double-quoted token of a line, or "" */
    DEFINE VARIABLE i1 AS INTEGER NO-UNDO.
    DEFINE VARIABLE i2 AS INTEGER NO-UNDO.
    i1 = INDEX(cLine, '"').
    IF i1 = 0 THEN RETURN "".
    i2 = INDEX(cLine, '"', i1 + 1).
    IF i2 = 0 THEN RETURN "".
    RETURN SUBSTRING(cLine, i1 + 1, i2 - i1 - 1).
END FUNCTION.

FUNCTION CleanCSV RETURNS CHARACTER (INPUT pcValue AS CHARACTER):

    DEFINE VARIABLE cValue AS CHARACTER NO-UNDO.

    ASSIGN
        cValue = TRIM(pcValue)
        cValue = REPLACE(cValue,'"',"").

    RETURN TRIM(cValue).

END FUNCTION.

FUNCTION ReplaceFirstQuoted RETURNS CHARACTER
    (INPUT cLine AS CHARACTER, INPUT cNewVal AS CHARACTER):
    /* replaces ONLY the first quoted token; any text after its closing
       quote (e.g. an area description) is kept */
    DEFINE VARIABLE i1 AS INTEGER NO-UNDO.
    DEFINE VARIABLE i2 AS INTEGER NO-UNDO.
    i1 = INDEX(cLine, '"').
    IF i1 = 0 THEN RETURN cLine.
    i2 = INDEX(cLine, '"', i1 + 1).
    IF i2 = 0 THEN RETURN cLine.
    RETURN SUBSTRING(cLine, 1, i1) + cNewVal + SUBSTRING(cLine, i2).
END FUNCTION.

/*------------------------------------------------------------------------
  Parameters
------------------------------------------------------------------------*/
cParams = SESSION:PARAMETER.

/* If session parameters are provided, override the input parameters */
IF cParams > "" AND NUM-ENTRIES(cParams) >= 4 THEN DO:
    ASSIGN
        cInputDF    = ENTRY(1, cParams)
        cOutputDF   = ENTRY(2, cParams)
        cCSVMap     = ENTRY(3, cParams)
        cReportFile = ENTRY(4, cParams).
END.
ELSE IF cInputDF = "" OR cOutputDF = "" OR cCSVMap = "" OR cReportFile = "" THEN DO:
    /* Only error out if neither session parameters nor input parameters were supplied */
    MESSAGE "Usage:" SKIP
            'pro -p DFUpdMain.p -param "in.df,out.df,map.csv,report.txt"' SKIP(1)
            'Or run via RUN statement passing 4 input parameters.'
        VIEW-AS ALERT-BOX ERROR.
    RETURN.
END.
/*------------------------------------------------------------------------
  Load CSV mapping
------------------------------------------------------------------------*/
INPUT STREAM sCsv FROM VALUE(cCSVMap).
iCsvLine = 0.

blkLoad:
REPEAT ON ENDKEY UNDO, LEAVE blkLoad:
    IMPORT STREAM sCsv UNFORMATTED cLine.
    iCsvLine = iCsvLine + 1.
    IF iCsvLine = 1 THEN NEXT.                       /* header row */
    IF NUM-ENTRIES(cLine, ",") < 5 THEN DO:
        CREATE ttLog.
        ASSIGN ttLog.cSev = "WARN"
               ttLog.cMsg = "CSV line " + STRING(iCsvLine)
                          + ": fewer than 5 columns - skipped.".
        NEXT.
    END.

    cToken = UPPER(CleanCSV(ENTRY(1, cLine, ","))).

    IF cToken = "" THEN
        NEXT.

    /* duplicate table name?  refuse silently-overwriting it */
    FIND FIRST ttMap NO-LOCK WHERE ttMap.cTableUpper = cToken NO-ERROR.
    IF AVAILABLE ttMap THEN DO:
        CREATE ttLog.
        ASSIGN ttLog.cSev = "ERROR"
               ttLog.cMsg = "CSV line " + STRING(iCsvLine)
                          + ": duplicate table '" + cToken + "' - row ignored.".
        NEXT.
    END.

    CREATE ttMap.
    ASSIGN
        ttMap.cTableName   = TRIM(ENTRY(1, cLine, ","))
        ttMap.cTableUpper  = cToken
        ttMap.cOrigTblArea = CleanCSV(ENTRY(2, cLine, ","))
        ttMap.cOrigIdxArea = CleanCSV(ENTRY(3, cLine, ","))
        ttMap.cNewTblArea  = CleanCSV(ENTRY(4, cLine, ","))
        ttMap.cNewIdxArea  = CleanCSV(ENTRY(5, cLine, ",")).
END.
INPUT STREAM sCsv CLOSE.

/*------------------------------------------------------------------------
  Stream the .df : read one line, transform if needed, write one line
------------------------------------------------------------------------*/
INPUT  STREAM sIn  FROM VALUE(cInputDF).
OUTPUT STREAM sOut TO   VALUE(cOutputDF).

ASSIGN
    cCurType       = ""
    cCurTable      = ""
    cCurTableUpper = ""
    iLineNum       = 0.

blkDf:
REPEAT ON ENDKEY UNDO, LEAVE blkDf:
    IMPORT STREAM sIn UNFORMATTED cLine.
    iLineNum   = iLineNum + 1.
    cTrim      = TRIM(cLine).
    cNewLine   = cLine.

    /* ---- block starts ---- */
    IF cTrim BEGINS "ADD TABLE" THEN DO:
        cCurTable      = GetFirstQuoted(cTrim).
        cCurTableUpper = UPPER(cCurTable).
        cCurType       = "T".
    END.
    ELSE IF cTrim BEGINS "ADD INDEX" THEN DO:
        /* index blocks reference their table via ON "table" */
        cCurTable = (IF INDEX(cTrim, " ON ") > 0 THEN GetFirstQuoted(SUBSTRING(cTrim, INDEX(cTrim, " ON ") + 4))  ELSE "").
        cCurTableUpper = UPPER(cCurTable). 
        cCurType       = "I".
    END.

    /* ---- AREA line inside a tracked block ---- */
    ELSE IF cTrim BEGINS "AREA" AND cCurType <> "" AND cCurTableUpper <> "" THEN DO:
        cAreaName = GetFirstQuoted(cTrim).

        FIND FIRST ttMap EXCLUSIVE-LOCK
             WHERE ttMap.cTableUpper = cCurTableUpper NO-ERROR.

        IF AVAILABLE ttMap THEN DO:
            IF cCurType = "T" THEN DO:
                IF cAreaName = ttMap.cOrigTblArea THEN DO:
                    cNewLine = ReplaceFirstQuoted(cLine, ttMap.cNewTblArea).
                    ttMap.cUsed = YES.
                    iTblMoved   = iTblMoved + 1.
                    CREATE ttLog.
                    ASSIGN ttLog.cSev = "INFO"
                           ttLog.cMsg = "Table '" + cCurTable + "' data area '"
                                      + cAreaName + "' -> '" + ttMap.cNewTblArea
                                      + "' (df line " + STRING(iLineNum) + ")".
                END.
                ELSE IF cAreaName <> ttMap.cOrigTblArea THEN DO:
                    iAreaMismatch = iAreaMismatch + 1.
                    CREATE ttLog.
                    ASSIGN ttLog.cSev = "WARN"
                           ttLog.cMsg = "Table '" + cCurTable + "': df area '" + cAreaName
                                      + "' <> CSV orig area '" + ttMap.cOrigTblArea
                                      + "' - left unchanged (df line " + STRING(iLineNum) + ")".
                END.
            END.
            ELSE IF cCurType = "I" THEN DO:
                IF cAreaName = ttMap.cOrigIdxArea THEN DO:
                    cNewLine = ReplaceFirstQuoted(cLine, ttMap.cNewIdxArea).
                    ttMap.cUsed = YES.
                    iIdxMoved   = iIdxMoved + 1.
                    CREATE ttLog.
                    ASSIGN ttLog.cSev = "INFO"
                           ttLog.cMsg = "Index of table '" + cCurTable + "' index area '"
                                      + cAreaName + "' -> '" + ttMap.cNewIdxArea
                                      + "' (df line " + STRING(iLineNum) + ")".
                END.
                ELSE IF cAreaName <> ttMap.cOrigIdxArea THEN DO:
                    iAreaMismatch = iAreaMismatch + 1.
                    CREATE ttLog.
                    ASSIGN ttLog.cSev = "WARN"
                           ttLog.cMsg = "Index of table '" + cCurTable + "': df area '" + cAreaName
                                      + "' <> CSV orig area '" + ttMap.cOrigIdxArea
                                      + "' - left unchanged (df line " + STRING(iLineNum) + ")".
                END.
            END.
        END.
        ELSE
            iBlocksNoMap = iBlocksNoMap + 1.
    END.

    /* ---- block end ---- */
    IF cTrim = "." THEN
        ASSIGN cCurType       = ""
               cCurTable      = ""
               cCurTableUpper = "".

    PUT STREAM sOut UNFORMATTED cNewLine SKIP.
END.

INPUT  STREAM sIn  CLOSE.
OUTPUT STREAM sOut CLOSE.

/*------------------------------------------------------------------------
  Report
------------------------------------------------------------------------*/
OUTPUT STREAM sRep TO VALUE(cReportFile).

PUT STREAM sRep UNFORMATTED "DF Area Updater Report" SKIP
                  "=======================" SKIP(1).

PUT STREAM sRep UNFORMATTED "Tables moved     : " STRING(iTblMoved)     SKIP
                            "Indexes moved    : " STRING(iIdxMoved)     SKIP
                            "Area mismatches  : " STRING(iAreaMismatch) SKIP
                            "Blocks w/o map   : " STRING(iBlocksNoMap)  SKIP(1).

PUT STREAM sRep UNFORMATTED "--- Detail ---" SKIP.
FOR EACH ttLog:
    PUT STREAM sRep UNFORMATTED ttLog.cSev ": " ttLog.cMsg SKIP.
END.

/* CSV rows that never matched anything in the .df */
iCsvLine = 0.
PUT STREAM sRep UNFORMATTED SKIP "--- CSV rows not found in .df ---" SKIP.
FOR EACH ttMap NO-LOCK WHERE ttMap.cUsed = NO:
    iCsvLine = iCsvLine + 1.
    PUT STREAM sRep UNFORMATTED "NOT FOUND: " ttMap.cTableName SKIP.
END.
IF iCsvLine = 0 THEN
    PUT STREAM sRep UNFORMATTED "(none - all CSV rows matched)" SKIP.

OUTPUT STREAM sRep CLOSE.

MESSAGE "Done." SKIP
        "Tables moved : " iTblMoved SKIP
        "Indexes moved: " iIdxMoved SKIP
        "Report       : " cReportFile
    VIEW-AS ALERT-BOX INFORMATION.
