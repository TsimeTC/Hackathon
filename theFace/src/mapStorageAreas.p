/*------------------------------------------------------------------------
  File: mapStorageAreas.p

  Purpose:
    Read a full human-readable OpenEdge DBANALYS report and produce a
    five-column storage-area mapping CSV for the user's DF update workflow.

  Parameters (preserves the existing 11-parameter RUN call):
    1. pcReportFolderOrFile : folder containing one report, or report filename
    2. piSmallMax           : maximum records for SMALL (inclusive)
    3. piMediumMax          : maximum records for MEDIUM (inclusive)
    4. piLargeMax           : optional review threshold; 0 means unlimited
    5. pcSmallDataArea
    6. pcSmallIndexArea
    7. pcMedDataArea
    8. pcMedIndexArea
    9. pcLargeDataArea
   10. pcLargeIndexArea
   11. pcOutputFile         : full CSV output path

  Mapping output columns:
    Table,OrigTblArea,OrigIdxArea,NewTblArea,NewIdxArea

  Parsing strategy for the full human-readable DBANALYS report:
    - CHAIN ANALYSIS FOR AREA sections identify object placement:
        Object Type = Table -> original data area
        Object Type = Index -> original index area
    - RECORD BLOCK SUMMARY FOR AREA sections provide record counts.
    - Partitioned tables appear as PUB.Table.PartitionName. Their row counts
      are summed against the base table (PUB.Table), not overwritten.
    - Multiple original areas are preserved in one CSV field, separated by
      semicolons. The recommended destination areas are still populated.
    - A .review.txt sidecar lists conditions that deserve DBA attention.

  Notes:
    - Folder input must contain exactly one matching report.
    - The parent folder for pcOutputFile must already exist.
    - The procedure does not run PROUTIL/DBANALYS; it reads its report.
------------------------------------------------------------------------*/

ROUTINE-LEVEL ON ERROR UNDO, THROW.

DEFINE INPUT PARAMETER pcReportFolderOrFile AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER piSmallMax           AS INT64     NO-UNDO.
DEFINE INPUT PARAMETER piMediumMax          AS INT64     NO-UNDO.
DEFINE INPUT PARAMETER piLargeMax           AS INT64     NO-UNDO.
DEFINE INPUT PARAMETER pcSmallDataArea      AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pcSmallIndexArea     AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pcMedDataArea        AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pcMedIndexArea       AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pcLargeDataArea      AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pcLargeIndexArea     AS CHARACTER NO-UNDO.
DEFINE INPUT PARAMETER pcOutputFile         AS CHARACTER NO-UNDO.

DEFINE VARIABLE lSkipSysTables AS LOGICAL NO-UNDO INITIAL TRUE.

DEFINE STREAM sIn.
DEFINE STREAM sOut.
DEFINE STREAM sReview.
DEFINE STREAM sDir.
DEFINE STREAM sProbe.

DEFINE TEMP-TABLE ttMap NO-UNDO
    FIELD cOwner           AS CHARACTER INITIAL ""
    FIELD cTableName       AS CHARACTER INITIAL ""
    FIELD cFullTableName   AS CHARACTER INITIAL ""
    FIELD iRecords         AS INT64     INITIAL 0
    FIELD lHasRecordCount  AS LOGICAL   INITIAL FALSE
    FIELD cOrigDataArea    AS CHARACTER INITIAL ""
    FIELD cOrigIdxArea     AS CHARACTER INITIAL ""
    FIELD cNewDataArea     AS CHARACTER INITIAL ""
    FIELD cNewIdxArea      AS CHARACTER INITIAL ""
    FIELD cReview          AS CHARACTER INITIAL ""
    INDEX idxFullName IS UNIQUE PRIMARY cFullTableName.

DEFINE BUFFER bOther FOR ttMap.

DEFINE VARIABLE cResolvedFile       AS CHARACTER NO-UNDO.
DEFINE VARIABLE cReviewFile         AS CHARACTER NO-UNDO.
DEFINE VARIABLE cInputType          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cFolder             AS CHARACTER NO-UNDO.
DEFINE VARIABLE cEntryName          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cDirPath            AS CHARACTER NO-UNDO.
DEFINE VARIABLE cAttributes         AS CHARACTER NO-UNDO.
DEFINE VARIABLE cCandidate          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cExtension          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cProbeLine          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cProbeUpper         AS CHARACTER NO-UNDO.
DEFINE VARIABLE cOutputDir          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cLine               AS CHARACTER NO-UNDO.
DEFINE VARIABLE cUpper              AS CHARACTER NO-UNDO.
DEFINE VARIABLE cNorm               AS CHARACTER NO-UNDO.
DEFINE VARIABLE cChainArea          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cRecordArea         AS CHARACTER NO-UNDO.
DEFINE VARIABLE cObjectType         AS CHARACTER NO-UNDO.
DEFINE VARIABLE cObjectName         AS CHARACTER NO-UNDO.
DEFINE VARIABLE cQualifiedName      AS CHARACTER NO-UNDO.
DEFINE VARIABLE cOwner              AS CHARACTER NO-UNDO.
DEFINE VARIABLE cTableName          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cFullName           AS CHARACTER NO-UNDO.
DEFINE VARIABLE cCountText          AS CHARACTER NO-UNDO.
DEFINE VARIABLE cRecordText         AS CHARACTER NO-UNDO.
DEFINE VARIABLE cSep                AS CHARACTER NO-UNDO.
DEFINE VARIABLE iDot                AS INTEGER   NO-UNDO.
DEFINE VARIABLE iSlashBack          AS INTEGER   NO-UNDO.
DEFINE VARIABLE iSlashForward       AS INTEGER   NO-UNDO.
DEFINE VARIABLE iSlash              AS INTEGER   NO-UNDO.
DEFINE VARIABLE iArea               AS INTEGER   NO-UNDO.
DEFINE VARIABLE iReportMatches      AS INTEGER   NO-UNDO INITIAL 0.
DEFINE VARIABLE iTableCount         AS INTEGER   NO-UNDO INITIAL 0.
DEFINE VARIABLE iReviewCount        AS INTEGER   NO-UNDO INITIAL 0.
DEFINE VARIABLE iRowRecords         AS INT64     NO-UNDO.
DEFINE VARIABLE lProbeChain         AS LOGICAL   NO-UNDO.
DEFINE VARIABLE lProbeRecords       AS LOGICAL   NO-UNDO.
DEFINE VARIABLE lReportHasChain     AS LOGICAL   NO-UNDO INITIAL FALSE.
DEFINE VARIABLE lReportHasRecords   AS LOGICAL   NO-UNDO INITIAL FALSE.

/*----------------------- helper functions ------------------------*/

FUNCTION getQuotedArea RETURNS CHARACTER (INPUT pcLine AS CHARACTER):
    DEFINE VARIABLE iOpen  AS INTEGER NO-UNDO.
    DEFINE VARIABLE iClose AS INTEGER NO-UNDO.

    iOpen = INDEX(pcLine, '"':U).
    IF iOpen = 0 THEN RETURN '':U.

    iClose = INDEX(pcLine, '"':U, iOpen + 1).
    IF iClose = 0 THEN RETURN '':U.

    RETURN SUBSTRING(pcLine, iOpen + 1, iClose - iOpen - 1).
END FUNCTION.

FUNCTION normalizeSpaces RETURNS CHARACTER (INPUT pcLine AS CHARACTER):
    DEFINE VARIABLE cResult AS CHARACTER NO-UNDO.

    cResult = TRIM(pcLine).
    DO WHILE INDEX(cResult, '  ':U) > 0:
        cResult = REPLACE(cResult, '  ':U, ' ':U).
    END.
    RETURN cResult.
END FUNCTION.

FUNCTION stripObjectNumber RETURNS CHARACTER (INPUT pcObject AS CHARACTER):
    DEFINE VARIABLE iColon AS INTEGER NO-UNDO.

    iColon = INDEX(pcObject, ':':U).
    IF iColon > 0 THEN
        RETURN SUBSTRING(pcObject, 1, iColon - 1).
    RETURN pcObject.
END FUNCTION.

FUNCTION isDigits RETURNS LOGICAL (INPUT pcValue AS CHARACTER):
    IF pcValue = '':U OR pcValue = ? THEN RETURN FALSE.
    RETURN TRIM(pcValue, '0123456789':U) = '':U.
END FUNCTION.

FUNCTION addUniqueArea RETURNS CHARACTER
    (INPUT pcExisting AS CHARACTER, INPUT pcNewArea AS CHARACTER):

    DEFINE VARIABLE iEntry AS INTEGER NO-UNDO.

    IF pcNewArea = ? OR TRIM(pcNewArea) = '':U THEN RETURN pcExisting.
    IF pcExisting = ? OR TRIM(pcExisting) = '':U THEN RETURN TRIM(pcNewArea).

    DO iEntry = 1 TO NUM-ENTRIES(pcExisting, ';':U):
        IF TRIM(ENTRY(iEntry, pcExisting, ';':U)) = TRIM(pcNewArea) THEN
            RETURN pcExisting.
    END.

    RETURN pcExisting + '; ':U + TRIM(pcNewArea).
END FUNCTION.

FUNCTION addReview RETURNS CHARACTER
    (INPUT pcExisting AS CHARACTER, INPUT pcMessage AS CHARACTER):

    IF pcMessage = ? OR TRIM(pcMessage) = '':U THEN RETURN pcExisting.
    IF pcExisting = ? OR TRIM(pcExisting) = '':U THEN RETURN pcMessage.
    IF INDEX(pcExisting, pcMessage) > 0 THEN RETURN pcExisting.
    RETURN pcExisting + '; ':U + pcMessage.
END FUNCTION.

FUNCTION csvQuote RETURNS CHARACTER (INPUT pcValue AS CHARACTER):
    DEFINE VARIABLE cValue AS CHARACTER NO-UNDO.

    IF pcValue = ? THEN
        cValue = '':U.
    ELSE
        cValue = pcValue.

    cValue = REPLACE(cValue, '"':U, '""':U).
    RETURN '"':U + cValue + '"':U.
END FUNCTION.

/*--------------------------- validation --------------------------*/

IF piSmallMax < 0 OR piMediumMax < 0 OR piMediumMax < piSmallMax THEN
    UNDO, THROW NEW Progress.Lang.AppError(
        'Invalid thresholds: require 0 <= SmallMax <= MediumMax.':U, 0).

IF piLargeMax > 0 AND piLargeMax < piMediumMax THEN
    UNDO, THROW NEW Progress.Lang.AppError(
        'LargeMax must be zero (unlimited) or >= MediumMax.':U, 0).

IF TRIM(pcReportFolderOrFile) = '':U THEN
    UNDO, THROW NEW Progress.Lang.AppError(
        'Provide the DBANALYS report file or the folder containing it.':U, 0).

IF TRIM(pcOutputFile) = '':U THEN
    UNDO, THROW NEW Progress.Lang.AppError('Output CSV path is empty.':U, 0).

IF TRIM(pcSmallDataArea) = '':U OR TRIM(pcSmallIndexArea) = '':U OR
   TRIM(pcMedDataArea) = '':U OR TRIM(pcMedIndexArea) = '':U OR
   TRIM(pcLargeDataArea) = '':U OR TRIM(pcLargeIndexArea) = '':U THEN
    UNDO, THROW NEW Progress.Lang.AppError(
        'Provide all six destination data/index area names.':U, 0).

/* Check that the output parent exists. This is the CSV destination, not input. */
iSlashBack    = R-INDEX(TRIM(pcOutputFile), '\':U).
iSlashForward = R-INDEX(TRIM(pcOutputFile), '/':U).
iSlash = iSlashBack.
IF iSlashForward > iSlash THEN iSlash = iSlashForward.

IF iSlash > 0 THEN DO:
    cOutputDir = SUBSTRING(TRIM(pcOutputFile), 1, iSlash).
    FILE-INFO:FILE-NAME = cOutputDir.
    IF FILE-INFO:FILE-TYPE = ? OR INDEX(FILE-INFO:FILE-TYPE, 'D':U) = 0 THEN
        UNDO, THROW NEW Progress.Lang.AppError(
            'The output folder does not exist or cannot be accessed: '
            + cOutputDir + '. Create the folder or correct the last RUN parameter.', 0).
END.

/* Parameter 1 may be a full report file or a directory containing one report. */
FILE-INFO:FILE-NAME = TRIM(pcReportFolderOrFile).
cInputType = FILE-INFO:FILE-TYPE.

IF cInputType <> ? AND INDEX(cInputType, 'D':U) = 0
   AND INDEX(cInputType, 'F':U) > 0 THEN DO:
    cResolvedFile = FILE-INFO:FULL-PATHNAME.
    IF cResolvedFile = ? OR cResolvedFile = '':U THEN
        cResolvedFile = TRIM(pcReportFolderOrFile).
END.
ELSE IF cInputType <> ? AND INDEX(cInputType, 'D':U) > 0 THEN DO:
    cFolder = FILE-INFO:FULL-PATHNAME.
    IF cFolder = ? OR cFolder = '':U THEN cFolder = TRIM(pcReportFolderOrFile).

    INPUT STREAM sDir FROM OS-DIR(cFolder).
    REPEAT ON ENDKEY UNDO, LEAVE:
        IMPORT STREAM sDir cEntryName cDirPath cAttributes.

        IF cEntryName = '':U OR cEntryName = '.':U OR cEntryName = '..':U THEN NEXT.
        IF INDEX(cAttributes, 'D':U) > 0 THEN NEXT.

        iDot = R-INDEX(cEntryName, '.':U).
        IF iDot <= 0 THEN NEXT.
        cExtension = CAPS(SUBSTRING(cEntryName, iDot + 1)).
        IF LOOKUP(cExtension, 'TXT,OUT,RPT,LOG,LST,PRN':U) = 0 THEN NEXT.

        /* OS-DIR returns the full pathname as its second field. */
        cCandidate = TRIM(cDirPath).
        IF cCandidate = '':U THEN cCandidate = cFolder + '\':U + cEntryName.
        ASSIGN lProbeChain = FALSE lProbeRecords = FALSE.

        INPUT STREAM sProbe FROM VALUE(cCandidate).
        REPEAT ON ENDKEY UNDO, LEAVE:
            IMPORT STREAM sProbe UNFORMATTED cProbeLine.
            cProbeUpper = CAPS(cProbeLine).
            IF INDEX(cProbeUpper, 'CHAIN ANALYSIS FOR AREA':U) > 0 THEN
                lProbeChain = TRUE.
            IF INDEX(cProbeUpper, 'RECORD BLOCK SUMMARY FOR AREA':U) > 0 THEN
                lProbeRecords = TRUE.
            IF lProbeChain AND lProbeRecords THEN LEAVE.
        END.
        INPUT STREAM sProbe CLOSE.

        IF lProbeChain AND lProbeRecords THEN DO:
            iReportMatches = iReportMatches + 1.
            cResolvedFile = cCandidate.
        END.
    END.
    INPUT STREAM sDir CLOSE.

    IF iReportMatches = 0 THEN
        UNDO, THROW NEW Progress.Lang.AppError(
            'No full human-readable DBANALYS report was found in: ' + cFolder
            + '. The report must contain CHAIN ANALYSIS FOR AREA and '
            + 'RECORD BLOCK SUMMARY FOR AREA sections.', 0).

    IF iReportMatches > 1 THEN
        UNDO, THROW NEW Progress.Lang.AppError(
            'More than one DBANALYS report was found in: ' + cFolder
            + '. Pass the exact report filename as the first parameter.', 0).
END.
ELSE
    UNDO, THROW NEW Progress.Lang.AppError(
        'The first parameter is neither an existing file nor a folder: '
        + pcReportFolderOrFile, 0).

cReviewFile = pcOutputFile + '.review.txt':U.

/*------------------------ parse the report -----------------------*/

INPUT STREAM sIn FROM VALUE(cResolvedFile).

REPEAT ON ENDKEY UNDO, LEAVE:
    IMPORT STREAM sIn UNFORMATTED cLine.
    cUpper = CAPS(cLine).

    /* CHAIN ANALYSIS area headers are the source for original Table/Index areas. */
    IF INDEX(cUpper, 'CHAIN ANALYSIS FOR AREA':U) > 0 THEN DO:
        cChainArea = getQuotedArea(cLine).
        cRecordArea = '':U.
        IF cChainArea <> '':U THEN lReportHasChain = TRUE.
        NEXT.
    END.

    /* Record-block summary rows supply record counts and a second data-area clue. */
    IF INDEX(cUpper, 'RECORD BLOCK SUMMARY FOR AREA':U) > 0 THEN DO:
        cRecordArea = getQuotedArea(cLine).
        cChainArea = '':U.
        IF cRecordArea <> '':U THEN lReportHasRecords = TRUE.
        NEXT.
    END.

    /* Index block summaries are not used for source-area inference: chain rows
       represent the explicit index objects and avoid treating the built-in
       'default' index summary as an assigned application index area. */
    IF INDEX(cUpper, 'INDEX BLOCK SUMMARY FOR AREA':U) > 0 THEN DO:
        cChainArea = '':U.
        cRecordArea = '':U.
        NEXT.
    END.

    /* Stop using area context at the per-area block analysis / summary footer. */
    IF INDEX(cUpper, ' BLOCK ANALYSIS':U) > 0 OR
       INDEX(cUpper, 'SUMMARY FOR AREA':U) > 0 OR
       INDEX(cUpper, 'DATABASE BLOCK ANALYSIS':U) > 0 THEN DO:
        cChainArea = '':U.
        cRecordArea = '':U.
        NEXT.
    END.

    cNorm = normalizeSpaces(cLine).
    IF cNorm = '':U THEN NEXT.

    /* CHAIN rows use: block-count ObjectType OWNER.Table[:object-number] ... */
    IF cChainArea <> '':U AND NUM-ENTRIES(cNorm, ' ':U) >= 3 THEN DO:
        cObjectType = CAPS(ENTRY(2, cNorm, ' ':U)).

        IF cObjectType = 'TABLE':U OR cObjectType = 'INDEX':U THEN DO:
            cObjectName = stripObjectNumber(ENTRY(3, cNorm, ' ':U)).
            iDot = NUM-ENTRIES(cObjectName, '.':U).

            IF cObjectType = 'TABLE':U AND iDot >= 2 THEN DO:
                cOwner = ENTRY(1, cObjectName, '.':U).
                cTableName = ENTRY(2, cObjectName, '.':U).

                IF NOT (lSkipSysTables AND cTableName BEGINS '_':U) THEN DO:
                    cFullName = cOwner + '.':U + cTableName.
                    FIND ttMap WHERE ttMap.cFullTableName = cFullName NO-ERROR.
                    IF NOT AVAILABLE ttMap THEN DO:
                        CREATE ttMap.
                        ASSIGN
                            ttMap.cOwner         = cOwner
                            ttMap.cTableName     = cTableName
                            ttMap.cFullTableName = cFullName.
                    END.
                    ttMap.cOrigDataArea = addUniqueArea(ttMap.cOrigDataArea, cChainArea).
                END.
            END.
            ELSE IF cObjectType = 'INDEX':U AND iDot >= 3 THEN DO:
                /* OWNER.Table.IndexName -> owner/table identify the parent table. */
                cOwner = ENTRY(1, cObjectName, '.':U).
                cTableName = ENTRY(2, cObjectName, '.':U).

                IF NOT (lSkipSysTables AND cTableName BEGINS '_':U) THEN DO:
                    cFullName = cOwner + '.':U + cTableName.
                    FIND ttMap WHERE ttMap.cFullTableName = cFullName NO-ERROR.
                    IF NOT AVAILABLE ttMap THEN DO:
                        CREATE ttMap.
                        ASSIGN
                            ttMap.cOwner         = cOwner
                            ttMap.cTableName     = cTableName
                            ttMap.cFullTableName = cFullName.
                    END.
                    ttMap.cOrigIdxArea = addUniqueArea(ttMap.cOrigIdxArea, cChainArea).
                END.
            END.
        END.
    END.

    /* Record summary rows can be either OWNER.Table or OWNER.Table.Partition.
       For partitioned tables, use the first two components as the base table
       and SUM each partition's record count instead of replacing the prior count. */
    IF cRecordArea <> '' AND NUM-ENTRIES(cNorm, ' ':U) >= 2 THEN DO:
        cQualifiedName = ENTRY(1, cNorm, ' ':U).
        cCountText = ENTRY(2, cNorm, ' ':U).
        cCountText = REPLACE(cCountText, ',':U, '':U).

        IF NUM-ENTRIES(cQualifiedName, '.':U) >= 2 AND isDigits(cCountText) THEN DO:
            cOwner = ENTRY(1, cQualifiedName, '.':U).
            cTableName = ENTRY(2, cQualifiedName, '.':U).

            IF NOT (lSkipSysTables AND cTableName BEGINS '_':U) THEN DO:
                cFullName = cOwner + '.':U + cTableName.
                FIND ttMap WHERE ttMap.cFullTableName = cFullName NO-ERROR.
                IF NOT AVAILABLE ttMap THEN DO:
                    CREATE ttMap.
                    ASSIGN
                        ttMap.cOwner         = cOwner
                        ttMap.cTableName     = cTableName
                        ttMap.cFullTableName = cFullName.
                END.

                ttMap.cOrigDataArea = addUniqueArea(ttMap.cOrigDataArea, cRecordArea).
                iRowRecords = INT64(cCountText).
                ttMap.iRecords = ttMap.iRecords + iRowRecords.
                ttMap.lHasRecordCount = TRUE.
            END.
        END.
    END.
END.
INPUT STREAM sIn CLOSE.

IF NOT lReportHasChain OR NOT lReportHasRecords THEN
    UNDO, THROW NEW Progress.Lang.AppError(
        'The selected file is not a supported full human-readable DBANALYS report: '
        + cResolvedFile + '. It must contain CHAIN ANALYSIS FOR AREA and '
        + 'RECORD BLOCK SUMMARY FOR AREA sections.', 0).

IF NOT CAN-FIND(FIRST ttMap) THEN
    UNDO, THROW NEW Progress.Lang.AppError(
        'No user tables were extracted from report: ' + cResolvedFile, 0).

/*-------------------- classify and review -----------------------*/

FOR EACH ttMap:
    IF NOT ttMap.lHasRecordCount THEN
        ttMap.cReview = addReview(ttMap.cReview, 'No record count found in record-block summary.').

    IF TRIM(ttMap.cOrigDataArea) = '':U THEN
        ttMap.cReview = addReview(ttMap.cReview, 'Original data area not found.').

    IF TRIM(ttMap.cOrigIdxArea) = '':U THEN
        ttMap.cReview = addReview(ttMap.cReview, 'Original index area not found in chain analysis.').

    IF NUM-ENTRIES(ttMap.cOrigDataArea, ';':U) > 1 THEN
        ttMap.cReview = addReview(ttMap.cReview,
            'Table/partition data appears in multiple areas: ' + ttMap.cOrigDataArea).

    IF NUM-ENTRIES(ttMap.cOrigIdxArea, ';':U) > 1 THEN
        ttMap.cReview = addReview(ttMap.cReview,
            'Indexes are in multiple original areas: ' + ttMap.cOrigIdxArea).

    IF ttMap.lHasRecordCount THEN DO:
        IF ttMap.iRecords <= piSmallMax THEN
            ASSIGN
                ttMap.cNewDataArea = pcSmallDataArea
                ttMap.cNewIdxArea  = pcSmallIndexArea.
        ELSE IF ttMap.iRecords <= piMediumMax THEN
            ASSIGN
                ttMap.cNewDataArea = pcMedDataArea
                ttMap.cNewIdxArea  = pcMedIndexArea.
        ELSE
            ASSIGN
                ttMap.cNewDataArea = pcLargeDataArea
                ttMap.cNewIdxArea  = pcLargeIndexArea.

        IF piLargeMax > 0 AND ttMap.iRecords > piLargeMax THEN
            ttMap.cReview = addReview(ttMap.cReview,
                'Record count exceeds configured LargeMax; still classified LARGE.').
    END.
    ELSE DO:
        /* Do not suggest a destination when no reliable count is available. */
        ASSIGN
            ttMap.cNewDataArea = '':U
            ttMap.cNewIdxArea  = '':U.
    END.
END.

/* The mapping schema only has an unqualified table name. Flag owner collisions. */
FOR EACH ttMap:
    FOR EACH bOther WHERE bOther.cTableName = ttMap.cTableName
                      AND bOther.cFullTableName <> ttMap.cFullTableName:
        ttMap.cReview = addReview(ttMap.cReview,
            'Duplicate table name across owners; output CSV uses table name only.').
    END.
END.

/*------------------------ write mapping CSV ----------------------*/

OUTPUT STREAM sOut TO VALUE(pcOutputFile).
PUT STREAM sOut UNFORMATTED
    '"Table","OrigTblArea","OrigIdxArea","NewTblArea","NewIdxArea"' SKIP.

FOR EACH ttMap BY ttMap.cTableName BY ttMap.cOwner:
    PUT STREAM sOut UNFORMATTED
        csvQuote(ttMap.cTableName) ","
        csvQuote(ttMap.cOrigDataArea) ","
        csvQuote(ttMap.cOrigIdxArea) ","
        csvQuote(ttMap.cNewDataArea) ","
        csvQuote(ttMap.cNewIdxArea)
        SKIP.
    iTableCount = iTableCount + 1.
END.
OUTPUT STREAM sOut CLOSE.

/* The sidecar preserves review notes without changing the updater's 5 columns. */
OUTPUT STREAM sReview TO VALUE(cReviewFile).
PUT STREAM sReview UNFORMATTED
    '"Table","Owner","RecordCount","OrigTblArea","OrigIdxArea","ReviewReason"' SKIP.

FOR EACH ttMap WHERE ttMap.cReview <> '':U BY ttMap.cTableName BY ttMap.cOwner:
    cRecordText = '':U.
    IF ttMap.lHasRecordCount THEN cRecordText = STRING(ttMap.iRecords).

    PUT STREAM sReview UNFORMATTED
        csvQuote(ttMap.cTableName) ","
        csvQuote(ttMap.cOwner) ","
        csvQuote(cRecordText) ","
        csvQuote(ttMap.cOrigDataArea) ","
        csvQuote(ttMap.cOrigIdxArea) ","
        csvQuote(ttMap.cReview)
        SKIP.
    iReviewCount = iReviewCount + 1.
END.
OUTPUT STREAM sReview CLOSE.

MESSAGE
    'Mapping file created: ' pcOutputFile SKIP
    'DBANALYS report read: ' cResolvedFile SKIP
    'Tables found: ' iTableCount SKIP
    'Tables flagged for review: ' iReviewCount SKIP
    'Review file: ' cReviewFile
    VIEW-AS ALERT-BOX INFO.
