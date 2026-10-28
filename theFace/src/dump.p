/* Define input parameters */
DEFINE INPUT PARAMETER cDbName    AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER cDbPath    AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER cTargetDir AS CHARACTER NO-UNDO.

/* Define remaining local variables */
DEFINE VARIABLE cCmd       AS CHARACTER NO-UNDO.
DEFINE VARIABLE cName      AS CHARACTER NO-UNDO.
DEFINE VARIABLE cDelim     AS CHARACTER NO-UNDO.
DEFINE VARIABLE cConnStr   AS CHARACTER NO-UNDO.
DEFINE VARIABLE cDlcPath   AS CHARACTER NO-UNDO.
DEFINE VARIABLE cProutil   AS CHARACTER NO-UNDO.
DEFINE VARIABLE cCleanDb   AS CHARACTER NO-UNDO.

SESSION:SUPPRESS-WARNINGS = TRUE.

/* Extract the clean database logical name */
cDelim = IF INDEX(cDbName, "\") > 0 THEN "\" ELSE "/".
cName = ENTRY(NUM-ENTRIES(cDbName, cDelim), cDbName, cDelim).

/* Strip .db extension for logical name use if present */
IF LC(SUBSTRING(cName, LENGTH(cName) - 2)) = ".db" THEN 
    cName = SUBSTRING(cName, 1, LENGTH(cName) - 3).
    
IF cDbName = "" OR cDbName = ? OR cDbPath = "" OR cDbPath = ? OR cTargetDir = "" OR cTargetDir = ? THEN DO:
    MESSAGE "Missing parameters ERROR: All parameters must be provided." VIEW-AS ALERT-BOX ERROR.
    RETURN.
END.

/* Ensure the target directory path ends with a proper trailing slash */
IF OPSYS = "WIN32" AND SUBSTRING(cTargetDir, LENGTH(cTargetDir), 1) <> "\" THEN 
    cTargetDir = cTargetDir + "\".
ELSE IF OPSYS <> "WIN32" AND SUBSTRING(cTargetDir, LENGTH(cTargetDir), 1) <> "/" THEN 
    cTargetDir = cTargetDir + "/".

/* 1. Dynamically connect to the database if it isn't already connected */
IF NOT CONNECTED(cName) THEN DO:
    cConnStr = "-db " + cDbName + " -ld " + cName + " -1 -RO".
    CONNECT VALUE(cConnStr). 
END.

/* 2. Create the required Data Dictionary ALIAS */
CREATE ALIAS DICTDB FOR DATABASE VALUE(cName).

/* 3. Run the Data Definitions (.df) dump to the target directory */
RUN prodict/dump_df.p (
    INPUT "ALL",
    INPUT cTargetDir + cName + ".df",
    INPUT ""
).

/* 4. Run the Data (.d) dump to the target directory 
RUN prodict/dump_d.p (
    INPUT "ALL",
    INPUT cTargetDir,
    INPUT ""
).*/

DELETE ALIAS DICTDB.

IF CONNECTED(cName) THEN 
    DISCONNECT VALUE(cName). 

OS-COMMAND SILENT VALUE("C:\Backup\DBAnalysis.bat " + cDbName + " " + cTargetDir + "Report.txt").


















