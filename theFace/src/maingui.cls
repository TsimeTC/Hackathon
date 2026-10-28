/*------------------------------------------------------------------------
    File        : maingui.cls
    Purpose     : Main GUI for the OpenEdge Storage Area Recommendation Tool.
    Syntax      : Launch from an ABL procedure with NEW maingui():ShowDialog().
    Description : Allows the user to select a database and report folder,
                  define Small/Medium/Large record-count thresholds, and
                  enter the proposed data and index storage-area names.
    Author(s)   :
    Created     :
    Notes       : Run on Windows with a compatible OpenEdge GUI for .NET
                  installation. Run DB Analysis validates the form only;
                  it does not yet execute PROUTIL DBANALYS.
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING Progress.Windows.Form.
USING System.Windows.Forms.* FROM ASSEMBLY.
USING Progress.Util.*        FROM ASSEMBLY.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS maingui INHERITS Form:

    DEFINE PRIVATE VARIABLE components AS System.ComponentModel.IContainer NO-UNDO.

    /* Database and report locations */
    DEFINE PRIVATE VARIABLE lblDatabase AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE lblSubtitle AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE txtDatabase AS System.Windows.Forms.TextBox NO-UNDO.
    DEFINE PRIVATE VARIABLE btnBrowseDatabase AS System.Windows.Forms.Button NO-UNDO.
    DEFINE PRIVATE VARIABLE dlgDatabase AS System.Windows.Forms.OpenFileDialog NO-UNDO.

    DEFINE PRIVATE VARIABLE lblOutputFolder AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE txtOutputFolder AS System.Windows.Forms.TextBox NO-UNDO.
    DEFINE PRIVATE VARIABLE btnBrowseOutput AS System.Windows.Forms.Button NO-UNDO.
    DEFINE PRIVATE VARIABLE dlgOutputFolder AS System.Windows.Forms.FolderBrowserDialog NO-UNDO.

    /* Threshold controls */
    DEFINE PRIVATE VARIABLE lblRulesHeading AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE lblSmall AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE lblMedium AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE lblLarge AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE lblSmallMax AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE lblMediumMax AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE lblLargeInfo AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE txtSmallMax AS System.Windows.Forms.TextBox NO-UNDO.
    DEFINE PRIVATE VARIABLE txtMediumMax AS System.Windows.Forms.TextBox NO-UNDO.

    /* Target area controls */
    DEFINE PRIVATE VARIABLE lblDataArea AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE lblIndexArea AS System.Windows.Forms.Label NO-UNDO.
    DEFINE PRIVATE VARIABLE txtSmallDataArea AS System.Windows.Forms.TextBox NO-UNDO.
    DEFINE PRIVATE VARIABLE txtSmallIndexArea AS System.Windows.Forms.TextBox NO-UNDO.
    DEFINE PRIVATE VARIABLE txtMediumDataArea AS System.Windows.Forms.TextBox NO-UNDO.
    DEFINE PRIVATE VARIABLE txtMediumIndexArea AS System.Windows.Forms.TextBox NO-UNDO.
    DEFINE PRIVATE VARIABLE txtLargeDataArea AS System.Windows.Forms.TextBox NO-UNDO.
    DEFINE PRIVATE VARIABLE txtLargeIndexArea AS System.Windows.Forms.TextBox NO-UNDO.

    /* Action and status controls */
    DEFINE PRIVATE VARIABLE btnRunAnalysis AS System.Windows.Forms.Button NO-UNDO.
    DEFINE PRIVATE VARIABLE btnClose AS System.Windows.Forms.Button NO-UNDO.
    DEFINE PRIVATE VARIABLE lblStatus AS System.Windows.Forms.Label NO-UNDO.
    
    /* overused, needs to be cleaned*/
    DEFINE VARIABLE cDbName    AS CHARACTER NO-UNDO.
    DEFINE VARIABLE cDbPath    AS CHARACTER NO-UNDO.
    DEFINE VARIABLE cTargetDir AS CHARACTER NO-UNDO.
    DEFINE VARIABLE cDelim  AS CHARACTER NO-UNDO.

    /*------------------------------------------------------------------------*/

    CONSTRUCTOR PUBLIC maingui():

        InitializeComponent().
        THIS-OBJECT:ComponentsCollection:Add(THIS-OBJECT:components).
        
        CATCH e AS Progress.Lang.Error:
            UNDO, THROW e.
        END CATCH.

    END CONSTRUCTOR.

    /*------------------------------------------------------------------------*/

    METHOD PRIVATE VOID InitializeComponent():

        THIS-OBJECT:lblSubtitle = NEW System.Windows.Forms.Label().
        THIS-OBJECT:lblDatabase = NEW System.Windows.Forms.Label().
        THIS-OBJECT:txtDatabase = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:btnBrowseDatabase = NEW System.Windows.Forms.Button().
        THIS-OBJECT:dlgDatabase = NEW System.Windows.Forms.OpenFileDialog().
        THIS-OBJECT:lblOutputFolder = NEW System.Windows.Forms.Label().
        THIS-OBJECT:txtOutputFolder = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:btnBrowseOutput = NEW System.Windows.Forms.Button().
        THIS-OBJECT:dlgOutputFolder = NEW System.Windows.Forms.FolderBrowserDialog().
        THIS-OBJECT:lblRulesHeading = NEW System.Windows.Forms.Label().
        THIS-OBJECT:lblDataArea = NEW System.Windows.Forms.Label().
        THIS-OBJECT:lblIndexArea = NEW System.Windows.Forms.Label().
        THIS-OBJECT:lblSmall = NEW System.Windows.Forms.Label().
        THIS-OBJECT:lblSmallMax = NEW System.Windows.Forms.Label().
        THIS-OBJECT:txtSmallMax = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:txtSmallDataArea = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:txtSmallIndexArea = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:lblMedium = NEW System.Windows.Forms.Label().
        THIS-OBJECT:lblMediumMax = NEW System.Windows.Forms.Label().
        THIS-OBJECT:txtMediumMax = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:txtMediumDataArea = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:txtMediumIndexArea = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:lblLarge = NEW System.Windows.Forms.Label().
        THIS-OBJECT:lblLargeInfo = NEW System.Windows.Forms.Label().
        THIS-OBJECT:txtLargeDataArea = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:txtLargeIndexArea = NEW System.Windows.Forms.TextBox().
        THIS-OBJECT:lblStatus = NEW System.Windows.Forms.Label().
        THIS-OBJECT:btnRunAnalysis = NEW System.Windows.Forms.Button().
        THIS-OBJECT:btnClose = NEW System.Windows.Forms.Button().
        THIS-OBJECT:SuspendLayout().
        /*  */
        /* lblSubtitle */
        /*  */
        THIS-OBJECT:lblSubtitle:AutoSize = TRUE.
        THIS-OBJECT:lblSubtitle:Location = NEW System.Drawing.Point(20, 12).
        THIS-OBJECT:lblSubtitle:Name = "lblSubtitle".
        THIS-OBJECT:lblSubtitle:Size = NEW System.Drawing.Size(435, 20).
        THIS-OBJECT:lblSubtitle:TabIndex = 0.
        THIS-OBJECT:lblSubtitle:Text = "Select a database, define the record thresholds, and assign target areas.".
        THIS-OBJECT:lblSubtitle:UseCompatibleTextRendering = TRUE.
        /*  */
        /* lblDatabase */
        /*  */
        THIS-OBJECT:lblDatabase:AutoSize = TRUE.
        THIS-OBJECT:lblDatabase:Location = NEW System.Drawing.Point(20, 43).
        THIS-OBJECT:lblDatabase:Name = "lblDatabase".
        THIS-OBJECT:lblDatabase:Size = NEW System.Drawing.Size(118, 20).
        THIS-OBJECT:lblDatabase:TabIndex = 1.
        THIS-OBJECT:lblDatabase:Text = "Database file (.db):".
        THIS-OBJECT:lblDatabase:UseCompatibleTextRendering = TRUE.
        /*  */
        /* txtDatabase */
        /*  */
        THIS-OBJECT:txtDatabase:Location = NEW System.Drawing.Point(20, 64).
        THIS-OBJECT:txtDatabase:Name = "txtDatabase".
        THIS-OBJECT:txtDatabase:Size = NEW System.Drawing.Size(555, 22).
        THIS-OBJECT:txtDatabase:TabIndex = 2.
        /*  */
        /* btnBrowseDatabase */
        /*  */
        THIS-OBJECT:btnBrowseDatabase:Location = NEW System.Drawing.Point(585, 62).
        THIS-OBJECT:btnBrowseDatabase:Name = "btnBrowseDatabase".
        THIS-OBJECT:btnBrowseDatabase:Size = NEW System.Drawing.Size(110, 27).
        THIS-OBJECT:btnBrowseDatabase:TabIndex = 3.
        THIS-OBJECT:btnBrowseDatabase:Text = "Browse...".
        THIS-OBJECT:btnBrowseDatabase:UseCompatibleTextRendering = TRUE.
        THIS-OBJECT:btnBrowseDatabase:UseVisualStyleBackColor = TRUE.
        THIS-OBJECT:btnBrowseDatabase:Click:Subscribe(THIS-OBJECT:BrowseDatabase).
        /*  */
        /* dlgDatabase */
        /*  */
        THIS-OBJECT:dlgDatabase:Filter = "OpenEdge database files (*.db)|*.db|All files (*.*)|*.*".
        THIS-OBJECT:dlgDatabase:Title = "Select the OpenEdge database file".
        /*  */
        /* lblOutputFolder */
        /*  */
        THIS-OBJECT:lblOutputFolder:AutoSize = TRUE.
        THIS-OBJECT:lblOutputFolder:Location = NEW System.Drawing.Point(20, 101).
        THIS-OBJECT:lblOutputFolder:Name = "lblOutputFolder".
        THIS-OBJECT:lblOutputFolder:Size = NEW System.Drawing.Size(189, 20).
        THIS-OBJECT:lblOutputFolder:TabIndex = 4.
        THIS-OBJECT:lblOutputFolder:Text = "Report and Excel output folder:".
        THIS-OBJECT:lblOutputFolder:UseCompatibleTextRendering = TRUE.
        /*  */
        /* txtOutputFolder */
        /*  */
        THIS-OBJECT:txtOutputFolder:Location = NEW System.Drawing.Point(20, 122).
        THIS-OBJECT:txtOutputFolder:Name = "txtOutputFolder".
        THIS-OBJECT:txtOutputFolder:Size = NEW System.Drawing.Size(555, 22).
        THIS-OBJECT:txtOutputFolder:TabIndex = 5.
        THIS-OBJECT:txtOutputFolder:TextChanged:Subscribe(THIS-OBJECT:txtOutputFolder_TextChanged).
        /*  */
        /* btnBrowseOutput */
        /*  */
        THIS-OBJECT:btnBrowseOutput:Location = NEW System.Drawing.Point(585, 120).
        THIS-OBJECT:btnBrowseOutput:Name = "btnBrowseOutput".
        THIS-OBJECT:btnBrowseOutput:Size = NEW System.Drawing.Size(110, 27).
        THIS-OBJECT:btnBrowseOutput:TabIndex = 6.
        THIS-OBJECT:btnBrowseOutput:Text = "Browse...".
        THIS-OBJECT:btnBrowseOutput:UseCompatibleTextRendering = TRUE.
        THIS-OBJECT:btnBrowseOutput:UseVisualStyleBackColor = TRUE.
        THIS-OBJECT:btnBrowseOutput:Click:Subscribe(THIS-OBJECT:BrowseOutputFolder).
        /*  */
        /* dlgOutputFolder */
        /*  */
        THIS-OBJECT:dlgOutputFolder:Description = "Select the folder for analysis reports and the Excel mapping file.".
        /*  */
        /* lblRulesHeading */
        /*  */
        THIS-OBJECT:lblRulesHeading:AutoSize = TRUE.
        THIS-OBJECT:lblRulesHeading:Font = NEW System.Drawing.Font("Microsoft Sans Serif", Progress.Util.CastUtil:ToSingle(10), System.Drawing.FontStyle:Bold).
        THIS-OBJECT:lblRulesHeading:Location = NEW System.Drawing.Point(20, 165).
        THIS-OBJECT:lblRulesHeading:Name = "lblRulesHeading".
        THIS-OBJECT:lblRulesHeading:Size = NEW System.Drawing.Size(355, 24).
        THIS-OBJECT:lblRulesHeading:TabIndex = 7.
        THIS-OBJECT:lblRulesHeading:Text = "Record-count rules and target storage areas".
        THIS-OBJECT:lblRulesHeading:UseCompatibleTextRendering = TRUE.
        /*  */
        /* lblDataArea */
        /*  */
        THIS-OBJECT:lblDataArea:AutoSize = TRUE.
        THIS-OBJECT:lblDataArea:Location = NEW System.Drawing.Point(280, 198).
        THIS-OBJECT:lblDataArea:Name = "lblDataArea".
        THIS-OBJECT:lblDataArea:Size = NEW System.Drawing.Size(92, 20).
        THIS-OBJECT:lblDataArea:TabIndex = 8.
        THIS-OBJECT:lblDataArea:Text = "New data area".
        THIS-OBJECT:lblDataArea:UseCompatibleTextRendering = TRUE.
        /*  */
        /* lblIndexArea */
        /*  */
        THIS-OBJECT:lblIndexArea:AutoSize = TRUE.
        THIS-OBJECT:lblIndexArea:Location = NEW System.Drawing.Point(475, 198).
        THIS-OBJECT:lblIndexArea:Name = "lblIndexArea".
        THIS-OBJECT:lblIndexArea:Size = NEW System.Drawing.Size(98, 20).
        THIS-OBJECT:lblIndexArea:TabIndex = 9.
        THIS-OBJECT:lblIndexArea:Text = "New index area".
        THIS-OBJECT:lblIndexArea:UseCompatibleTextRendering = TRUE.
        /*  */
        /* lblSmall */
        /*  */
        THIS-OBJECT:lblSmall:AutoSize = TRUE.
        THIS-OBJECT:lblSmall:Location = NEW System.Drawing.Point(20, 215).
        THIS-OBJECT:lblSmall:Name = "lblSmall".
        THIS-OBJECT:lblSmall:Size = NEW System.Drawing.Size(38, 20).
        THIS-OBJECT:lblSmall:TabIndex = 10.
        THIS-OBJECT:lblSmall:Text = "Small".
        THIS-OBJECT:lblSmall:UseCompatibleTextRendering = TRUE.
        /*  */
        /* lblSmallMax */
        /*  */
        THIS-OBJECT:lblSmallMax:AutoSize = TRUE.
        THIS-OBJECT:lblSmallMax:Location = NEW System.Drawing.Point(20, 238).
        THIS-OBJECT:lblSmallMax:Name = "lblSmallMax".
        THIS-OBJECT:lblSmallMax:Size = NEW System.Drawing.Size(115, 20).
        THIS-OBJECT:lblSmallMax:TabIndex = 11.
        THIS-OBJECT:lblSmallMax:Text = "Maximum records:".
        THIS-OBJECT:lblSmallMax:UseCompatibleTextRendering = TRUE.
        /*  */
        /* txtSmallMax */
        /*  */
        THIS-OBJECT:txtSmallMax:Location = NEW System.Drawing.Point(135, 234).
        THIS-OBJECT:txtSmallMax:Name = "txtSmallMax".
        THIS-OBJECT:txtSmallMax:Size = NEW System.Drawing.Size(115, 22).
        THIS-OBJECT:txtSmallMax:TabIndex = 12.
        THIS-OBJECT:txtSmallMax:Text = "1000".
        /*  */
        /* txtSmallDataArea */
        /*  */
        THIS-OBJECT:txtSmallDataArea:Location = NEW System.Drawing.Point(280, 231).
        THIS-OBJECT:txtSmallDataArea:Name = "txtSmallDataArea".
        THIS-OBJECT:txtSmallDataArea:Size = NEW System.Drawing.Size(180, 22).
        THIS-OBJECT:txtSmallDataArea:TabIndex = 13.
        THIS-OBJECT:txtSmallDataArea:Text = "Small_Data_Area".
        /*  */
        /* txtSmallIndexArea */
        /*  */
        THIS-OBJECT:txtSmallIndexArea:Location = NEW System.Drawing.Point(475, 231).
        THIS-OBJECT:txtSmallIndexArea:Name = "txtSmallIndexArea".
        THIS-OBJECT:txtSmallIndexArea:Size = NEW System.Drawing.Size(220, 22).
        THIS-OBJECT:txtSmallIndexArea:TabIndex = 14.
        THIS-OBJECT:txtSmallIndexArea:Text = "Small_Index_Area".
        /*  */
        /* lblMedium */
        /*  */
        THIS-OBJECT:lblMedium:AutoSize = TRUE.
        THIS-OBJECT:lblMedium:Location = NEW System.Drawing.Point(20, 285).
        THIS-OBJECT:lblMedium:Name = "lblMedium".
        THIS-OBJECT:lblMedium:Size = NEW System.Drawing.Size(53, 20).
        THIS-OBJECT:lblMedium:TabIndex = 15.
        THIS-OBJECT:lblMedium:Text = "Medium".
        THIS-OBJECT:lblMedium:UseCompatibleTextRendering = TRUE.
        /*  */
        /* lblMediumMax */
        /*  */
        THIS-OBJECT:lblMediumMax:AutoSize = TRUE.
        THIS-OBJECT:lblMediumMax:Location = NEW System.Drawing.Point(20, 308).
        THIS-OBJECT:lblMediumMax:Name = "lblMediumMax".
        THIS-OBJECT:lblMediumMax:Size = NEW System.Drawing.Size(115, 20).
        THIS-OBJECT:lblMediumMax:TabIndex = 16.
        THIS-OBJECT:lblMediumMax:Text = "Maximum records:".
        THIS-OBJECT:lblMediumMax:UseCompatibleTextRendering = TRUE.
        /*  */
        /* txtMediumMax */
        /*  */
        THIS-OBJECT:txtMediumMax:Location = NEW System.Drawing.Point(135, 304).
        THIS-OBJECT:txtMediumMax:Name = "txtMediumMax".
        THIS-OBJECT:txtMediumMax:Size = NEW System.Drawing.Size(115, 22).
        THIS-OBJECT:txtMediumMax:TabIndex = 17.
        THIS-OBJECT:txtMediumMax:Text = "10000".
        /*  */
        /* txtMediumDataArea */
        /*  */
        THIS-OBJECT:txtMediumDataArea:Location = NEW System.Drawing.Point(280, 303).
        THIS-OBJECT:txtMediumDataArea:Name = "txtMediumDataArea".
        THIS-OBJECT:txtMediumDataArea:Size = NEW System.Drawing.Size(180, 22).
        THIS-OBJECT:txtMediumDataArea:TabIndex = 18.
        THIS-OBJECT:txtMediumDataArea:Text = "Medium_Data_Area".
        /*  */
        /* txtMediumIndexArea */
        /*  */
        THIS-OBJECT:txtMediumIndexArea:Location = NEW System.Drawing.Point(475, 303).
        THIS-OBJECT:txtMediumIndexArea:Name = "txtMediumIndexArea".
        THIS-OBJECT:txtMediumIndexArea:Size = NEW System.Drawing.Size(220, 22).
        THIS-OBJECT:txtMediumIndexArea:TabIndex = 19.
        THIS-OBJECT:txtMediumIndexArea:Text = "Medium_Index_Area".
        /*  */
        /* lblLarge */
        /*  */
        THIS-OBJECT:lblLarge:AutoSize = TRUE.
        THIS-OBJECT:lblLarge:Location = NEW System.Drawing.Point(20, 357).
        THIS-OBJECT:lblLarge:Name = "lblLarge".
        THIS-OBJECT:lblLarge:Size = NEW System.Drawing.Size(39, 20).
        THIS-OBJECT:lblLarge:TabIndex = 20.
        THIS-OBJECT:lblLarge:Text = "Large".
        THIS-OBJECT:lblLarge:UseCompatibleTextRendering = TRUE.
        /*  */
        /* lblLargeInfo */
        /*  */
        THIS-OBJECT:lblLargeInfo:AutoSize = TRUE.
        THIS-OBJECT:lblLargeInfo:Location = NEW System.Drawing.Point(20, 380).
        THIS-OBJECT:lblLargeInfo:Name = "lblLargeInfo".
        THIS-OBJECT:lblLargeInfo:Size = NEW System.Drawing.Size(178, 20).
        THIS-OBJECT:lblLargeInfo:TabIndex = 21.
        THIS-OBJECT:lblLargeInfo:Text = "More than Medium maximum".
        THIS-OBJECT:lblLargeInfo:UseCompatibleTextRendering = TRUE.
        /*  */
        /* txtLargeDataArea */
        /*  */
        THIS-OBJECT:txtLargeDataArea:Location = NEW System.Drawing.Point(280, 375).
        THIS-OBJECT:txtLargeDataArea:Name = "txtLargeDataArea".
        THIS-OBJECT:txtLargeDataArea:Size = NEW System.Drawing.Size(180, 22).
        THIS-OBJECT:txtLargeDataArea:TabIndex = 22.
        THIS-OBJECT:txtLargeDataArea:Text = "Large_Data_Area".
        /*  */
        /* txtLargeIndexArea */
        /*  */
        THIS-OBJECT:txtLargeIndexArea:Location = NEW System.Drawing.Point(475, 375).
        THIS-OBJECT:txtLargeIndexArea:Name = "txtLargeIndexArea".
        THIS-OBJECT:txtLargeIndexArea:Size = NEW System.Drawing.Size(220, 22).
        THIS-OBJECT:txtLargeIndexArea:TabIndex = 23.
        THIS-OBJECT:txtLargeIndexArea:Text = "Large_Index_Area".
        /*  */
        /* lblStatus */
        /*  */
        THIS-OBJECT:lblStatus:BorderStyle = System.Windows.Forms.BorderStyle:Fixed3D.
        THIS-OBJECT:lblStatus:Location = NEW System.Drawing.Point(20, 445).
        THIS-OBJECT:lblStatus:Name = "lblStatus".
        THIS-OBJECT:lblStatus:Size = NEW System.Drawing.Size(675, 58).
        THIS-OBJECT:lblStatus:TabIndex = 24.
        THIS-OBJECT:lblStatus:Text = "Ready. Choose the database and report folder, then validate the settings.".
        THIS-OBJECT:lblStatus:UseCompatibleTextRendering = TRUE.
        THIS-OBJECT:lblStatus:Click:Subscribe(THIS-OBJECT:lblStatus_Click).
        /*  */
        /* btnRunAnalysis */
        /*  */
        THIS-OBJECT:btnRunAnalysis:Location = NEW System.Drawing.Point(395, 525).
        THIS-OBJECT:btnRunAnalysis:Name = "btnRunAnalysis".
        THIS-OBJECT:btnRunAnalysis:Size = NEW System.Drawing.Size(180, 36).
        THIS-OBJECT:btnRunAnalysis:TabIndex = 25.
        THIS-OBJECT:btnRunAnalysis:Text = "Run DB Analysis".
        THIS-OBJECT:btnRunAnalysis:UseCompatibleTextRendering = TRUE.
        THIS-OBJECT:btnRunAnalysis:UseVisualStyleBackColor = TRUE.
        THIS-OBJECT:btnRunAnalysis:Click:Subscribe(THIS-OBJECT:RunAnalysis).
        /*  */
        /* btnClose */
        /*  */
        THIS-OBJECT:btnClose:DialogResult = System.Windows.Forms.DialogResult:Cancel.
        THIS-OBJECT:btnClose:Location = NEW System.Drawing.Point(585, 525).
        THIS-OBJECT:btnClose:Name = "btnClose".
        THIS-OBJECT:btnClose:Size = NEW System.Drawing.Size(110, 36).
        THIS-OBJECT:btnClose:TabIndex = 26.
        THIS-OBJECT:btnClose:Text = "Close".
        THIS-OBJECT:btnClose:UseCompatibleTextRendering = TRUE.
        THIS-OBJECT:btnClose:UseVisualStyleBackColor = TRUE.
        THIS-OBJECT:btnClose:Click:Subscribe(THIS-OBJECT:CloseForm).
        /*  */
        /* maingui */
        /*  */
        THIS-OBJECT:AcceptButton = THIS-OBJECT:btnRunAnalysis.
        THIS-OBJECT:BackColor = System.Drawing.Color:WhiteSmoke.
        THIS-OBJECT:CancelButton = THIS-OBJECT:btnClose.
        THIS-OBJECT:ClientSize = NEW System.Drawing.Size(720, 600).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblSubtitle).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblDatabase).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtDatabase).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:btnBrowseDatabase).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblOutputFolder).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtOutputFolder).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:btnBrowseOutput).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblRulesHeading).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblDataArea).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblIndexArea).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblSmall).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblSmallMax).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtSmallMax).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtSmallDataArea).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtSmallIndexArea).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblMedium).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblMediumMax).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtMediumMax).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtMediumDataArea).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtMediumIndexArea).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblLarge).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblLargeInfo).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtLargeDataArea).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:txtLargeIndexArea).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:lblStatus).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:btnRunAnalysis).
        THIS-OBJECT:Controls:Add(THIS-OBJECT:btnClose).
        THIS-OBJECT:FormBorderStyle = System.Windows.Forms.FormBorderStyle:FixedToolWindow.
        THIS-OBJECT:MaximizeBox = FALSE.
        THIS-OBJECT:Name = "maingui".
        THIS-OBJECT:ShowIcon = FALSE.
        THIS-OBJECT:StartPosition = System.Windows.Forms.FormStartPosition:CenterScreen.
        THIS-OBJECT:Text = "Storage Area Recommendation Tool".
        THIS-OBJECT:ResumeLayout(FALSE).
        THIS-OBJECT:PerformLayout().
        CATCH e AS Progress.Lang.Error:
            UNDO, THROW e.
        END CATCH.
    END METHOD.

    /*------------------------------------------------------------------------*/

    METHOD PRIVATE VOID BrowseDatabase(INPUT sender AS System.Object,INPUT e AS System.EventArgs):
        /*IF dlgDatabase:ShowDialog() = System.Windows.Forms.DialogResult:OK THEN DO:
            txtDatabase:Text = dlgDatabase:FileName.
        END.*/
        
        DEFINE VARIABLE oFileDialog AS OpenFileDialog NO-UNDO.
        DEFINE VARIABLE oResult     AS DialogResult   NO-UNDO.
    
        /* Create and configure the File Dialog */
        oFileDialog = NEW OpenFileDialog().
        oFileDialog:Title = "Select a File".
        //oFileDialog:Filter = "All Files (*.*)|*.*|Text Files (*.txt)|*.txt".
        oFileDialog:Filter = "database (*.db)|*.db".
        oFileDialog:CheckFileExists = TRUE.
    
        /* 
           FIX: Capture the return value of ShowDialog() 
           into 'oResult' using the mandatory 'SET' phrase
        */
        WAIT-FOR oFileDialog:ShowDialog() SET oResult.
    
        cDbName = oFileDialog:FILENAME.
        cDbPath = System.IO.Path:GetDirectoryName(cDbName).
        cTargetDir = cDbPath + "\dump".
        OS-CREATE-DIR VALUE(cTargetDir).

        RUN dump.p (INPUT cDbName, INPUT cDbPath, INPUT cTargetDir).
        
        /* FIX: Compare the matching types (oResult and DialogResult:OK) */
        IF EnumHelper:AreEqual(oResult, DialogResult:OK) THEN DO:
            txtDatabase:Text = oFileDialog:FILENAME.
        END.
    
        /* Clean up memory */
        oFileDialog:Dispose().

    END METHOD.

    /*------------------------------------------------------------------------*/

    METHOD PRIVATE VOID BrowseOutputFolder(INPUT sender AS System.Object,INPUT e AS System.EventArgs):
        /*IF dlgOutputFolder:ShowDialog() = System.Windows.Forms.DialogResult:OK THEN DO:
            txtOutputFolder:Text = dlgOutputFolder:SelectedPath.
        END.*/
            
        DEFINE VARIABLE oFileDialog AS OpenFileDialog NO-UNDO.
        DEFINE VARIABLE oResult     AS DialogResult   NO-UNDO.
    
        /* Create and configure the File Dialog */
        oFileDialog = NEW OpenFileDialog().
        oFileDialog:Title = "Select a File".
        //oFileDialog:Filter = "All Files (*.*)|*.*|Text Files (*.txt)|*.txt".
        oFileDialog:Filter = "Text Files (*.txt)|*.txt".
        oFileDialog:CheckFileExists = TRUE.
    
        /* 
           FIX: Capture the return value of ShowDialog() 
           into 'oResult' using the mandatory 'SET' phrase
        */
        WAIT-FOR oFileDialog:ShowDialog() SET oResult.
    
        /* FIX: Compare the matching types (oResult and DialogResult:OK) */
        IF EnumHelper:AreEqual(oResult, DialogResult:OK) THEN DO:
            //MESSAGE "DIR : " oFileDialog:FileName
            //VIEW-AS ALERT-BOX.
            txtOutputFolder:Text = oFileDialog:FileName.
        END.
    
        /* Clean up memory */
        oFileDialog:Dispose().
        
    END METHOD.

	/*------------------------------------------------------------------------------
	 Purpose:
	 Notes:
	------------------------------------------------------------------------------*/
	@VisualDesigner.
	METHOD PRIVATE VOID lblStatus_Click( INPUT sender AS System.Object, INPUT e AS System.EventArgs ):
		
		RETURN.

	END METHOD.

    /*------------------------------------------------------------------------*/

    METHOD PRIVATE VOID RunAnalysis(INPUT sender AS System.Object,INPUT e AS System.EventArgs):

        DEFINE VARIABLE iSmallMax AS INT64 NO-UNDO.
        DEFINE VARIABLE iMediumMax AS INT64 NO-UNDO.
        DEFINE VARIABLE cFolderPath AS CHARACTER NO-UNDO.
        DEFINE VARIABLE cName AS CHARACTER NO-UNDO.
        
        cFolderPath = System.IO.Path:GetDirectoryName(txtOutputFolder:Text).
        
        /* Validate required paths */
        IF TRIM(txtDatabase:Text) = "" THEN DO:
            ShowValidationError("Please select the OpenEdge database file.").
            RETURN.
        END.

        IF TRIM(txtOutputFolder:Text) = "" THEN DO:
            ShowValidationError("Please select an output folder.").
            RETURN.
        END.

        IF NOT System.IO.File:Exists(txtDatabase:Text) THEN DO:
            ShowValidationError("The selected database file could not be found. Check that the path points to the .db file.").
            RETURN.
        END.

        IF NOT System.IO.Directory:Exists(cFolderPath) THEN DO:
            
            /* Now check if that directory path actually exists */
            IF NOT System.IO.Directory:Exists(cFolderPath) THEN DO:
                MESSAGE "The selected directory does not exist!" 
                    VIEW-AS ALERT-BOX ERROR.
            END.
            
            ShowValidationError("The selected output folder does not exist.").
            RETURN.
        END.

        /* Validate thresholds */
        iSmallMax = INT64(TRIM(txtSmallMax:Text)) NO-ERROR.
        IF ERROR-STATUS:ERROR OR iSmallMax < 0 THEN DO:
            ShowValidationError("Small maximum must be a non-negative whole number.").
            RETURN.
        END.

        iMediumMax = INT64(TRIM(txtMediumMax:Text)) NO-ERROR.
        IF ERROR-STATUS:ERROR OR iMediumMax <= iSmallMax THEN DO:
            ShowValidationError("Medium maximum must be a whole number greater than Small maximum.").
            RETURN.
        END.

        /* Validate target area names */
        IF TRIM(txtSmallDataArea:Text) = "" OR
           TRIM(txtSmallIndexArea:Text) = "" OR
           TRIM(txtMediumDataArea:Text) = "" OR
           TRIM(txtMediumIndexArea:Text) = "" OR
           TRIM(txtLargeDataArea:Text) = "" OR
           TRIM(txtLargeIndexArea:Text) = "" THEN DO:
            ShowValidationError("Enter both a target data area and target index area for Small, Medium, and Large.").
            RETURN.
        END.

        /* The actual dbanalys process will be connected in the next step. */
        lblStatus:Text = "Settings validated. DBANALYS execution and report parsing exported connected.".
                                      
       RUN mapStorageAreas.p (INPUT txtOutputFolder:Text,
                              INPUT INT64(iSmallMax),
                              INPUT INT64(iMediumMax),
                              INPUT INT64(1000000),
                              INPUT txtSmallDataArea:Text,
                              INPUT txtSmallIndexArea:Text,
                              INPUT txtMediumDataArea:Text,
                              INPUT txtMediumIndexArea:Text,
                              INPUT txtLargeDataArea:Text,
                              INPUT txtLargeIndexArea:Text,
                              INPUT cTargetDir + "\map.csv"
                             ).
       
        cDelim = IF INDEX(cDbName, "\") > 0 THEN "\" ELSE "/".
        cName = ENTRY(NUM-ENTRIES(cDbName, cDelim), cDbName, cDelim).
        
        IF LC(SUBSTRING(cName, LENGTH(cName) - 2)) = ".db" THEN 
        cName = SUBSTRING(cName, 1, LENGTH(cName) - 3).

        RUN DFStorageUpdater.p (
                                    INPUT cTargetDir + "\" + cName + ".df",
                                    INPUT cTargetDir + "\Final_" + cName + ".df",
                                    INPUT cTargetDir + "\map.csv",
                                    INPUT cTargetDir + "\report2.txt"
                                ).

    END METHOD.

    /*------------------------------------------------------------------------*/

    METHOD PRIVATE VOID ShowValidationError(INPUT pcMessage AS CHARACTER):

        lblStatus:Text = pcMessage.

        System.Windows.Forms.MessageBox:Show(pcMessage,
                                             "Storage Area Recommendation Tool",
                                             System.Windows.Forms.MessageBoxButtons:OK,
                                             System.Windows.Forms.MessageBoxIcon:Warning).

    END METHOD.

    /*------------------------------------------------------------------------*/

    METHOD PRIVATE VOID CloseForm(INPUT sender AS System.Object,INPUT e AS System.EventArgs):

        THIS-OBJECT:Close().

    END METHOD.

	/*------------------------------------------------------------------------*/
	
	@VisualDesigner.
	METHOD PRIVATE VOID txtOutputFolder_TextChanged( INPUT sender AS System.Object, 
	                                                 INPUT e AS System.EventArgs ):
		
		RETURN.

	END METHOD.

    /*------------------------------------------------------------------------*/

    DESTRUCTOR PUBLIC maingui():

        IF VALID-OBJECT(dlgDatabase) THEN
            dlgDatabase:Dispose().
        IF VALID-OBJECT(dlgOutputFolder) THEN
            dlgOutputFolder:Dispose().
        IF VALID-OBJECT(components) THEN
            components:Dispose().

    END DESTRUCTOR.

END CLASS.
