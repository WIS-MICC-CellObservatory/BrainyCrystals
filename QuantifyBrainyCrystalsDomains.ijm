#@ string(choices=("SelectMeasureROis", "Segment", "Update"), style="list") runMode
#@ string(choices=("singleFile", "wholeFolder", "AllSubFolders"), style="list") processMode
#@ string(choices=("EM", "AFM"), style="list") imageType
#@ string (label="File Extension",value=".tif", persist=true, description="eg .tif, .h5") fileExtension
#@ String(choices=("IgnoreExisting", "OpenExistingForEditing", "SkipExisting"), style="list", value="SkipExisting", persist=false, description="How to handle existing Measure Rois") existingMeasureRoisMode
#@ string(choices=("Threshold", "MorphologicalSegmentation"), style="list", description="Segmentation Method, relevant only for AFM Images") segModeForAFM
#@ Boolean(label="Split Objects with Watershed?",value=true, persist=true, description="Default should be true, Relevant only for AFM Images, Threshold Segmentation") WatershedFlag
#@ Boolean(label="Use Manaul Threshold?",value=true, persist=true, description="Default should be true, Relevant only for AFM Images, Threshold Segmentation") ManualThreshold
#@ Boolean(label="Batch Mode?",value=false, persist=false, description="Hide images while working. Not active in Morphological segmentation") batchModeFlag


/*
 * QuantifyBrainyCrystalsDomains.ijm
 * 
 * Measure shape features of brainy crystals from high resolution EM images, using ilastik segmentation (with optional manual correction) or manualsegmentation 
 * Measuring is limited to selected Regions-of-interest
 * 
 * Workflow
 * ========
 * - Read label image produced using ilastik boundary-based segmentation 
 * - Read ROIs for measurements file, or prompt the user to select them (FN_MeasureAreaRois.zip)
 * - Convert labels within Rois to RoiManager and save in FN_DomainRoiSet.zip
 * - Measure shape descriptors for Domain Rois
 * - write summary line 
 * - save quality control images with overlay of the Domain Segments used for measurement an the Measure Areas, overlayed on the original image
 * - Add Mean/Std/Min/Max lines for the summary table
 * 
 * Usage
 * =====
 * 
 * NOTE: Before running the macro in Segment mode, make sure to 
 * ------------------------------------------------------------
 * 
 * 1. Scale and Crop images eg using ScaleAndCropImages.ijm macro 
 * 
 * 2. If you are using EM images - Run ilastik segmentation either using RunIlastikHeadless.bat (or through batch using ilastik GUI)
 * 	  Results are expected to be in FN_Multicut Segmentation.h5 files
 * 	  
 * Once you have done scaling and optionally Ilastik segmentation: 
 * 
 *  1. Select Measure Rois: 
 * 		- Drag and drop this macro to Fiji (QuantifyBrainyCrystalsDomains.ijm), click Run
 * 		- Set runMode to be SelectMeasureROis 
 * 		- Set processMode to singleFile or wholeFolder
 * 		  select a file to process, if wholeFolder is selected: all the files in the folder of the selected file are processed
 * 		- uncheck batchModeFlag, to allow drawing Rois
 * 		
 * 	2. Quantify Crystal Domains
 * 		- Set runMode to be Segment 
 * 		- Set processMode to singleFile or wholeFolder
 * 		- select the proper imageType (EM or AFM)
 * 		  select a file to process, if wholeFolder is selected: all the files in the folder of the selected file are processed
 * 		- for AFM images there are two possible segmentation controled by segModeForAFM: 
 * 		  * Threshold based, which by default let you set the threshold for each image, and cut the objects using binary watershed  
 * 		  * Morphological Segmentation: which is based on applying Tubeness filter followed by Morphological Segmentation. 
 * 		    Both have advanced parameters that can be controled by setting parameters at the begining of the macro 
 * 		- If batchModeFlag is selected (recomended) the macro will run faster and not dispalyed temporary images
 * 	
 * 	3. Manual correction
 * 		- Careful inspection of results: I find it usefull to use one or both of the following methods: 
 * 			* Open the original image in Fiji, drag and drop the FN_DomainRoiSet.zip file into Fiji main window, and then from the RoiManager flip between Show and Hide 
 * 			* Open the original image and the overlay image, Use Analyze=>Tools=>Synchronize Windows 
 * 		- ... correct Rois ... 
 * 		- Save as FN_DomainRoiSet_Manual.zip
 * 		- Set runMode to be Update 
 * 		- Set processMode to singleFile or wholeFolder
 * 		  select a file to process, if wholeFolder is selected: all the files in the folder of the selected file are processed
 * 		
 * - NOTE: It is very important to inspect All quality control images to verify that segmentation is correct 
 * 
 * Output
 * ======
 * For each input image FN, the following output files are saved in ResultsSubFolder under the input folder
 * - FN_OrigOverlay.tif 	- the original image with overlay of the segmented Domains in DomainColor
 * - FN_DomainResults.xls - the detailed measurements for each skeleton segment in the image  
 * - FN_DomainRoiSet.zip  - the Crystal Domain segments used for measurements
 * 
 *  Overlay colors can be controled by DomainColor 
 * 
 * Summary.xls  - Table with one line for each input image files with average values of Mean and Median LocTchikness
 * QuantifyBrainyCrystalsDomains.txt - Parameters used during the latest run
 * 
 * Dependencies
 * ============
 * Fiji with ImageJ version > 1.53e (Check Help=>About ImageJ, and if needed use Help=>Update ImageJ...
 * This macro requires the following Update sites to be activate through Help=>Update=>Manage Update site
 * - CLIJ2
 * - IJPB
 * - Ilastik Fiji Plugin (add "Ilastik" to your selected Fiji Update Sites)
 * - "SCF MPI CBG" Plugin 
 * 
 * Please cite Fiji (https://imagej.net/Citing) and Ilastik (https://www.ilastik.org/about.html) 
 * 
 * By Ofra Golani, MICC Cell Observatory, Weizmann Institute of Science, November 2020
 * 
 * v2: 
 * - Handle batchmode (only after reading Ilastik segmentation which is a virtual image / morphological segmentation for AFM) 
 * - add color-coded images
 * - accumulate all per-file results into "AllDetailedTable" table
 */


// ============ Parameters =======================================
var macroVersion = "v2";
//var fileExtension = ".tif";

// Parameters for AFM Threshold Segmentation
var ThresholdMethod = "Yen"; // "Percentile"
var WatershedFlag = true; //false;
var ManualThreshold = true;

// Parameters for AFM Mophological Segmentation
var TubenessSigma = 10; //10; // nm 
var Tolerance = 1.0; // 0.5; // Increase this value if you get over-segmentation
var Connectivity = 4;
var WaitTime = 1000;
var MinSize = 2000; // nm^2  20; // Pixels
var Radius = 2.0;	

var RoiSelectionTool = "ellipse"; // "ellipse" , "polygon",  "rectangle"

var MeasureRoisSuffix = "_MeasureAreaRois"; // either .zip or .roi 
var DomainRoisSuffix = "_DomainRoiSet"; 
var DefaultNumberOfRoi = 1;

var DomainColor = "yellow";
var MeasureAreaColor = "green";

// parameters for color-coded images
var Circ_MinVal = 0;
var Circ_MaxVal = 1;
var Circ_DecimalVal = 2;
var Circ_LUTName = "Fire";
var Solidity_MinVal = 0;
var Solidity_MaxVal = 1;
var Solidity_DecimalVal = 2;
var Solidity_LUTName = "Fire";
var Area_MinVal = 0;
var Area_MaxVal = 200000; // nm^2
var Area_DecimalVal = 2;
var Area_LUTName = "Fire";
var ZoomFactorForCalibrationBar = 0.5; //1;

var ResultsSubFolder = "Results";
//var ResultsSubFolder = "Results_MorphoSeg";
var cleanupFlag = 1; 
var debugFlag = 0; //1; //0;

// Global Parameters
var SummaryTable = "SummaryResults.xls";
var AllDetailedTable = "DeatiledResults.xls";
var SuffixStr = "";
var SegTypeStr = "";
var TimeString;

// get the Threshold values set by the user 
var lowerThreshold;
var upperThreshold;
// ================= Main Code ====================================

Initialization();

// Choose image file or folder
if (matches(processMode, "singleFile")) {
	file_name=File.openDialog("Please select an image file to analyze");
	directory = File.getParent(file_name);
	}
else if (matches(processMode, "wholeFolder")) {
	directory = getDirectory("Please select a folder of images to analyze"); }

else if (matches(processMode, "AllSubFolders")) {
	parentDirectory = getDirectory("Please select a Parent Folder of subfolders to analyze"); }

// keep it to 0 - Morphological Segmentation does not work with BatchMode
/*if (batchModeFlag && !(matches(imageType, "AFM") && matches(segModeForAFM, "MorphologicalSegmentation")))
{
	print("Working in Batch Mode, processing without opening images");
	setBatchMode(true);
}*/

// Analysis 
if (matches(processMode, "wholeFolder") || matches(processMode, "singleFile")) {
	resFolder = directory + File.separator + ResultsSubFolder + File.separator; 
	File.makeDirectory(resFolder);
	print("inDir=",directory," outDir=",resFolder);
	SavePrms(resFolder);
	
	if (matches(processMode, "singleFile")) {
		ProcessFile(directory, resFolder, file_name); }
	else if (matches(processMode, "wholeFolder")) {
		ProcessFiles(directory, resFolder); }
}

else if (matches(processMode, "AllSubFolders")) {
	list = getFileList(parentDirectory);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(parentDirectory + list[i])) {
			subFolderName = list[i];
			//print(subFolderName);
			subFolderName = substring(subFolderName, 0,lengthOf(subFolderName)-1);
			//print(subFolderName);

			//directory = parentDirectory + list[i];
			directory = parentDirectory + subFolderName + File.separator;
			resFolder = directory + ResultsSubFolder + File.separator; 
			//print(parentDirectory, directory, resFolder);
			File.makeDirectory(resFolder);
			print("inDir=",directory," outDir=",resFolder);
			SavePrms(resFolder);
			//if (isOpen("SummaryResults.xls"))
			if (isOpen(SummaryTable))
			{
				//selectWindow("SummaryResults.xls");
				selectWindow(SummaryTable);
				selectWindow(AllDetailedTable);
				run("Close");  // To close non-image window
			}
			ProcessFiles(directory, resFolder);
			print("Processing ",subFolderName, " Done");
		}
	}
}

if (cleanupFlag==true) 
{
	CloseTable(SummaryTable);	
	CloseTable(AllDetailedTable);	
}
setBatchMode(false);
print("=================== Done ! ===================");

// ================= Helper Functions ====================================

//===============================================================================================================
// Loop on all files in the folder and Run analysis on each of them
function ProcessFiles(directory, resFolder) 
{
	dir1=substring(directory, 0,lengthOf(directory)-1);
	idx=lastIndexOf(dir1,File.separator);
	subdir=substring(dir1, idx+1,lengthOf(dir1));

	// Get the files in the folder 
	fileListArray = getFileList(directory);
	
	// Loop over files
	for (fileIndex = 0; fileIndex < lengthOf(fileListArray); fileIndex++) {
		if (endsWith(fileListArray[fileIndex], fileExtension) ) {
			file_name = directory+File.separator+fileListArray[fileIndex];
			//open(file_name);	
			//print("\nProcessing:",fileListArray[fileIndex]);
			showProgress(fileIndex/lengthOf(fileListArray));
			ProcessFile(directory, resFolder, file_name);
		} // end of if 
	} // end of for loop

	// Save Results
	if (isOpen(SummaryTable))
	{
		GenerateSummaryLines(SummaryTable);
		selectWindow(SummaryTable);
		SummaryTable1 = replace(SummaryTable, ".xls", "");
		print("SummaryTable=",SummaryTable,"SummaryTable1=",SummaryTable1,"subdir=",subdir);
		saveAs("Results", resFolder+SummaryTable1+"_"+subdir+".xls");
		run("Close");  // To close non-image window

		GenerateSummaryLines(AllDetailedTable);
		selectWindow(AllDetailedTable);
		AllDetailedTable1 = replace(AllDetailedTable, ".xls", "");
		print("AllDetailedTable=",AllDetailedTable,"AllDetailedTable1=",AllDetailedTable1,"subdir=",subdir);
		saveAs("Results", resFolder+AllDetailedTable1+"_"+subdir+".xls");
		run("Close");  // To close non-image window
	}
	
	// Cleanup
	if (cleanupFlag==true) 
	{
		CloseTable(SummaryTable);	
		CloseTable(AllDetailedTable);	
	}
} // end of ProcessFiles



//===============================================================================================================
// Run analysis of single file
function ProcessFile(directory, resFolder, file_name) 
{

	// ===== Open File ========================
	// later on, replace with a stack and do here Z-Project, change the message above
	print(file_name);
	if ( endsWith(file_name, "h5") )
		run("Import HDF5", "select=["+file_name+"] datasetname=[/data: (1, 1, 1024, 1024, 1) uint8] axisorder=tzyxc");
	else
		open(file_name);
	if (matches(imageType, "EM"))		
		run("Grays");

	directory = File.directory;
	origName = getTitle();
	Im = getImageID();
	origNameNoExt = File.getNameWithoutExtension(file_name);

	if (matches(runMode,"SelectMeasureROis")) {
		GetMeasureRois(resFolder, origNameNoExt, Im, MeasureRoisSuffix);
	} else if (matches(runMode,"Segment")) {
		// Generate mask of Measure ROIs into image named "MeasureAreaMask"
		GetMeasureRoisMask(resFolder, origNameNoExt, Im, MeasureRoisSuffix);

		// EM Segmentation is based on Ilastik Multicut
		if (matches(imageType, "EM"))		
			GetDomainsRoisFromIlastik(directory, resFolder, origName, origNameNoExt);

		// AFM Segmentation is based on either Manual Threshold Selection  or  Morphological Segmentation
		else if (matches(imageType, "AFM"))		
		{
			if (matches(segModeForAFM, "Threshold"))		
				SegmentDomainFromAFMImage_Threshold(directory, resFolder, origName, origNameNoExt);
						
			else if (matches(segModeForAFM, "MorphologicalSegmentation"))		
				SegmentDomainFromAFMImage_MorphoSeg(directory, resFolder, origName, origNameNoExt);

		}
		
	} else if (matches(runMode,"Update")) {
		GetMeasureRoisMask(resFolder, origNameNoExt, Im, MeasureRoisSuffix);
		GetDomainsFromRoiFile(directory, resFolder, origName, origNameNoExt);
	}

	// Quantify Domain shape (from objects in RoiManger)
	if ( matches(runMode,"Segment") || matches(runMode,"Update") ) {
		selectImage(Im);
		// Measure, Calc Stat, generate Summary line
		MeasureDomains(resFolder, origNameNoExt);

		// ============ Save Color-coded images ======================
		run("ROIs to Label image", "rm=[RoiManager[size=56, visible=true]]");
		CreateAndSaveColorCodeImage("LabelImage", "DetailedResults", resFolder, origNameNoExt, "Circ.", SuffixStr, Circ_MinVal, Circ_MaxVal, Circ_DecimalVal, ZoomFactorForCalibrationBar, Circ_LUTName);
		CreateAndSaveColorCodeImage("LabelImage", "DetailedResults", resFolder, origNameNoExt, "Solidity", SuffixStr, Solidity_MinVal, Solidity_MaxVal, Solidity_DecimalVal, ZoomFactorForCalibrationBar, Solidity_LUTName);
		CreateAndSaveColorCodeImage("LabelImage", "DetailedResults", resFolder, origNameNoExt, "Area", SuffixStr, Area_MinVal, Area_MaxVal, Area_DecimalVal, ZoomFactorForCalibrationBar, Area_LUTName);
		AppendTables(AllDetailedTable,"DetailedResults");
		
		// Save overlay image
		//SaveOverlayImage(origName, "MeasureAreaMask", origNameNoExt, "_Overlay"+SuffixStr+".tif", resFolder);
		SaveOverlayImage(Im, "MeasureAreaMask", origNameNoExt, "_Overlay"+SuffixStr+".tif", resFolder);

	}

	if (debugFlag) waitForUser;
	if(cleanupFlag) Cleanup();
} // end of ProcessFile


//===============================================================================================================
function SegmentDomainFromAFMImage_Threshold(directory, resFolder, origName, origNameNoExt)
{
	// reset Threshold values
	lowerThreshold = 0;
	upperThreshold = 0;

	roiManager("reset");
	//run("Duplicate...", "title=Orig");
	origIm = getTitle();
	run("Duplicate...", "title=Binary");
	run("8-bit");
	setAutoThreshold(ThresholdMethod+" dark");
	if (ManualThreshold)
	{
		run("Threshold...");
		waitForUser("Please set the threshold, click OK when done");
	}
	getThreshold(lowerThreshold, upperThreshold);
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Dilate");
	if (WatershedFlag)
		run("Watershed");

	// Mask with MeasureAreaMask
	selectWindow("MeasureAreaMask");
	run("Create Selection");
	selectWindow("Binary");
	run("Restore Selection");
	
	run("Analyze Particles...", "exclude clear add");
	//run("Analyze Particles...", "  show=[Count Masks] exclude clear add");
	//selectWindow(origIm);
	//roiManager("Show All without labels");	

	SaveDomainRois(resFolder+origNameNoExt+DomainRoisSuffix);
}


//===============================================================================================================
function SegmentDomainFromAFMImage_MorphoSeg(directory, resFolder, origName, origNameNoExt)
{
	roiManager("reset");
	ImName=getTitle();
	getVoxelSize(width, height, depth, unit);
	run("Duplicate...", "title=Orig");
	run("8-bit");
	//run("Median...", "radius=2");
	run("Duplicate...", "title=Invert");
	run("Invert");
	run("Tubeness", "sigma="+TubenessSigma+" use");  // TubenessSigma is in nm 
	//run("Tubeness", "sigma="+TubenessSigma);
	run("Morphological Segmentation");
	wait(1000); // about 1s is usually enough
	selectWindow("Morphological Segmentation");
	call("inra.ijpb.plugins.MorphologicalSegmentation.segment", "tolerance="+Tolerance, "calculateDams=true", "connectivity="+Connectivity);
	wait(WaitTime); 
	call("inra.ijpb.plugins.MorphologicalSegmentation.setDisplayFormat", "Catchment basins");
	call("inra.ijpb.plugins.MorphologicalSegmentation.createResultImage");
	setTool("hand");
	setVoxelSize(width, height, depth, unit);

	// Can enter Batch mode only after finishing Morphological Segmentation
	if (batchModeFlag)
	{
		print("Going into Batch Mode, processing without opening further images");
		setBatchMode(true);
	} 
	
	run("Remove Border Labels", "left right top bottom");
	run("Remove Largest Label");
	// This function uses Pixel values, so we need to convert from nm to Pixel Values
	getPixelSize(unit, pixelWidth, pixelHeight);
	MinSizePixels = MinSize / (pixelWidth * pixelHeight);
	print("Filtering by MinSize (nm^2, pixels):",MinSize, MinSizePixels);
	run("Label Size Filtering", "operation=Greater_Than size="+MinSizePixels);
	run("Remap Labels");
	run("Fill Holes (Binary/Gray)");
	Im1=getTitle();
	print(Im1);
	
	// extend labels with maximum radius
	image1 = Im1;
	Ext.CLIJ2_push(image1);
	image2 = "extend_labels_with_maximum_radius";
	Ext.CLIJx_extendLabelsWithMaximumRadius(image1, image2, Radius);
	Ext.CLIJ2_pull(image2);

	rename("MorphoSegLabels");
	setVoxelSize(width, height, depth, unit);
	MaskLabels("MorphoSegLabels", "MeasureAreaMask"); 

	// Add labels to Roi Manager
	run("LabelMap to ROI Manager (2D)");
	roiManager("Deselect");

	SaveDomainRois(resFolder+origNameNoExt+DomainRoisSuffix);
}

//===============================================================================================================

//===============================================================================================================
function MeasureDomains(resFolder, origNameNoExt)
{
	run("Set Measurements...", "area perimeter fit shape feret's display redirect=None decimal=3");
	roiManager("Measure");
	if (isOpen("Results"))
	{
		selectWindow("Results");
		Table.save(resFolder+origNameNoExt+"_Results"+SuffixStr+".xls");
	
		// Calc statistics
		nDomains = nResults;
	
		Area = Table.getColumn("Area");
		//Perim = Table.getColumn("Perim.");
		Circ = Table.getColumn("Circ.");
		Round = Table.getColumn("Round");
		Solidity = Table.getColumn("Solidity");
		MaxFeret = Table.getColumn("Feret");
		MinFeret = Table.getColumn("MinFeret");
		Major = Table.getColumn("Major");
		Minor = Table.getColumn("Minor");
		AR = Table.getColumn("AR");
	
		Array.getStatistics(Area, minArea, maxArea, meanArea, stdDevArea);
		//Array.getStatistics(Perim, minPerim, maxPerim, meanPerim, stdDevPerim);
		Array.getStatistics(Circ, minCirc, maxCirc, meanCirc, stdDevCirc);
		Array.getStatistics(Round, minRound, maxRound, meanRound, stdDevRound);
		Array.getStatistics(Solidity, minSolidity, maxSolidity, meanSolidity, stdDevSolidity);
		Array.getStatistics(AR, minAR, maxAR, meanAR, stdDevAR);
		Array.getStatistics(Major, minMajor, maxMajor, meanMajor, stdDevMajor);
		Array.getStatistics(Minor, minMinor, maxMinor, meanMinor, stdDevMinor);
		Array.getStatistics(MaxFeret, minMaxFeret, maxMaxFeret, meanMaxFeret, stdDevMaxFeret);
		Array.getStatistics(MinFeret, minMinFeret, maxMinFeret, meanMinFeret, stdDevMinFeret);

		//print("meanArea=", meanArea, "meanCirc=", meanCirc, "meanSolidity=", meanSolidity);
	}
	else {
		nDomains= 0;
		meanArea = 0;
		minArea = 0;
		maxArea = 0;
		meanCirc = 0;
		meanRound = 0;
		meanSolidity = 0;
		meanMajor = 0;
		meanMinor = 0;
		meanAR = 0;
		meanMaxFeret = 0;
		meanMinFeret = 0;
	}	
	// =========== Add line in Summary Table =============
	if (isOpen("Results"))
	{
		//run("Close");
		selectWindow("Results"); // One must select the table to be renamed prior to Table.rename
		Table.rename("Results", "DetailedResults");
		Table.update("DetailedResults");
		Table.create("Results");
	}
	
	// Output the measured values into new results table
	if (isOpen(SummaryTable))
	{
		selectWindow(SummaryTable); // One must select the table to be renamed prior to Table.rename
		Table.rename(SummaryTable, "Results"); // rename to avoid table overwrite
	}	
	else
		run("Clear Results");

	selectWindow("Results");
	//print("nResults=",nResults);
	Table.set("Label", nResults, origNameNoExt); 
	Table.update;
	Table.set("SegType", nResults-1, SegTypeStr);  // Orig or Manual RoiSet
	if (matches(imageType, "AFM"))		
	{
		if (matches(segModeForAFM, "Threshold"))		
		{
			Table.set("lowerThreshold", nResults-1, lowerThreshold);  // Orig or Manual RoiSet
			Table.set("upperThreshold", nResults-1, upperThreshold);  // Orig or Manual RoiSet
			Table.set("WatershedFlag", nResults-1, WatershedFlag);  // Orig or Manual RoiSet
		}
	}				
	Table.set("nDomains", nResults-1, nDomains); 
	Table.set("meanArea", nResults-1, meanArea); 
	Table.set("minArea", nResults-1, minArea); 
	Table.set("maxArea", nResults-1, maxArea); 
	Table.set("meanCirc", nResults-1, meanCirc); 
	Table.set("meanRound", nResults-1, meanRound); 
	Table.set("meanSolidity", nResults-1, meanSolidity); 
	Table.set("meanMajor", nResults-1, meanMajor); 
	Table.set("meanMinor", nResults-1, meanMinor); 
	Table.set("meanAR", nResults-1, meanAR); 
	Table.set("meanMaxFeret", nResults-1, meanMaxFeret); 
	Table.set("meanMinFeret", nResults-1, meanMinFeret); 
	//Table.update;
	Table.update("Results");

	// Save Results - actual saving is done at the higher level function as this table include one line for each image
	selectWindow("Results"); // One must select the table to be renamed prior to Table.rename
	Table.rename("Results", SummaryTable); // rename to avoid table overwrite
	Table.update(SummaryTable);

} // end of MeasureDomains


//===============================================================================================================
// append the content of additonalTable to bigTable
// if bigTable does not exist - create it 
// if additonalTable is empty or dont exist - do nothing
function AppendTables(bigTable, additonalTable)
{

	// if additonalTable is empty or don't exist - do nothing
	if (!isOpen(additonalTable)) return;
	selectWindow(additonalTable);
	nAdditionalRows = Table.size;
	if (nAdditionalRows == 0) return;
	Headings = Table.headings;
	headingArr = split(Headings);

	if (!isOpen(bigTable))
	{
		Table.create(bigTable);
	}
	selectWindow(bigTable);
	nRows = Table.size;

	// loop over columns of additional Table and add them to bigTable
	for (i = 0; i < headingArr.length; i++)
	{
		selectWindow(additonalTable);
		ColName = headingArr[i];
		valArr = Table.getColumn(ColName);
		if (valArr.length == 0) continue;
		
		selectWindow(bigTable);
		for (j = 0; j < nAdditionalRows; j++)
		{
			//print(i, ColName, j, valArr[j]);
			Table.set(ColName, nRows+j, valArr[j]); 
		}
	}

	selectWindow(bigTable);
	Table.showRowNumbers(true);
	Table.update;
} // end of AppendTables


//===============================================================================================================
function GenerateSummaryLines(tableName)
{
	if (isOpen(tableName))
	{
		//Table.rename(tableName, "Results");
		selectWindow(tableName);
		nRows = Table.size;
		Headings = Table.headings;
		headingArr = split(Headings);

		selectWindow(tableName);
		Table.set("Label", nRows, "MeanValues"); 
		Table.set("Label", nRows+1, "StdValues"); 
		Table.set("Label", nRows+2, "MinValues"); 
		Table.set("Label", nRows+3, "MaxValues"); 
		for (i = 0; i < headingArr.length; i++)
		{
			ColName = headingArr[i];
			if (matches(ColName, "Label")) continue;

			valArr = Table.getColumn(ColName);
			valArr = Array.trim(valArr, nRows);
			Array.getStatistics(valArr, minVal, maxVal, meanVal, stdVal);
			if (!isNaN(meanVal))
			{
				Table.set(ColName, nRows,   meanVal); 
				Table.set(ColName, nRows+1, stdVal); 
				Table.set(ColName, nRows+2, minVal); 
				Table.set(ColName, nRows+3, maxVal); 
			}
		}
		Table.update;
	}
} // end of GenerateSummaryLines

//===============================================================================================================
function GenerateSummaryLines_OLD(SummaryTable)
{
	if (isOpen(SummaryTable))
	{
		Table.rename(SummaryTable, "Results");

		Area = Table.getColumn("meanArea");
		Circ = Table.getColumn("meanCirc");
		Round = Table.getColumn("meanRound");
		Solidity = Table.getColumn("meanSolidity");
		MaxFeret = Table.getColumn("meanMaxFeret");
		MinFeret = Table.getColumn("meanMinFeret");
		Major = Table.getColumn("meanMajor");
		Minor = Table.getColumn("meanMinor");
		AR = Table.getColumn("meanAR");
	
		Array.getStatistics(Area, minArea, maxArea, meanArea, stdDevArea);
		Array.getStatistics(Circ, minCirc, maxCirc, meanCirc, stdDevCirc);
		Array.getStatistics(Round, minRound, maxRound, meanRound, stdDevRound);
		Array.getStatistics(Solidity, minSolidity, maxSolidity, meanSolidity, stdDevSolidity);
		Array.getStatistics(AR, minAR, maxAR, meanAR, stdDevAR);
		Array.getStatistics(Major, minMajor, maxMajor, meanMajor, stdDevMajor);
		Array.getStatistics(Minor, minMinor, maxMinor, meanMinor, stdDevMinor);
		Array.getStatistics(MaxFeret, minMaxFeret, maxMaxFeret, meanMaxFeret, stdDevMaxFeret);
		Array.getStatistics(MinFeret, minMinFeret, maxMinFeret, meanMinFeret, stdDevMinFeret);
	
		setResult("Label", nResults, "MeanValues"); 
		setResult("meanArea", nResults-1, meanArea); 
		setResult("meanCirc", nResults-1, meanCirc); 
		setResult("meanRound", nResults-1, meanRound); 
		setResult("meanSolidity", nResults-1, meanSolidity); 
		setResult("meanMajor", nResults-1, meanMajor); 
		setResult("meanMinor", nResults-1, meanMinor); 
		setResult("meanAR", nResults-1, meanAR); 
		setResult("meanMaxFeret", nResults-1, meanMaxFeret); 
		setResult("meanMinFeret", nResults-1, meanMinFeret); 
		
		setResult("Label", nResults, "StdValues"); 
		setResult("meanArea", nResults-1, stdDevArea); 
		setResult("meanCirc", nResults-1, stdDevCirc); 
		setResult("meanRound", nResults-1, stdDevRound); 
		setResult("meanSolidity", nResults-1, stdDevSolidity); 
		setResult("meanMajor", nResults-1, stdDevMajor); 
		setResult("meanMinor", nResults-1, stdDevMinor); 
		setResult("meanAR", nResults-1, stdDevAR); 
		setResult("meanMaxFeret", nResults-1, stdDevMaxFeret); 
		setResult("meanMinFeret", nResults-1, stdDevMinFeret); 

		setResult("Label", nResults, "MinValues"); 
		setResult("meanArea", nResults-1, minArea); 
		setResult("meanCirc", nResults-1, minCirc); 
		setResult("meanRound", nResults-1, minRound); 
		setResult("meanSolidity", nResults-1, minSolidity); 
		setResult("meanMajor", nResults-1, minMajor); 
		setResult("meanMinor", nResults-1, minMinor); 
		setResult("meanAR", nResults-1, minAR); 
		setResult("meanMaxFeret", nResults-1, minMaxFeret); 
		setResult("meanMinFeret", nResults-1, minMinFeret); 

		setResult("Label", nResults, "MaxValues"); 
		setResult("meanArea", nResults-1, maxArea); 
		setResult("meanCirc", nResults-1, maxCirc); 
		setResult("meanRound", nResults-1, maxRound); 
		setResult("meanSolidity", nResults-1, maxSolidity); 
		setResult("meanMajor", nResults-1, maxMajor); 
		setResult("meanMinor", nResults-1, maxMinor); 
		setResult("meanAR", nResults-1, maxAR); 
		setResult("meanMaxFeret", nResults-1, maxMaxFeret); 
		setResult("meanMinFeret", nResults-1, maxMinFeret); 

		// Save Results - actual saving is done at the higher level function as this table include one line for each image
		IJ.renameResults("Results", SummaryTable); // rename to avoid table overwrite
				
	}
} // end of GenerateSummaryLines



//===============================================================================================================
// used in Update mode
function GetDomainsFromRoiFile(directory, resFolder, origName, origNameNoExt)
{
	baseRoiName = resFolder+origNameNoExt+DomainRoisSuffix;
	manualROIFound = OpenExistingROIFile(baseRoiName);
	if (manualROIFound) 
	{
		SuffixStr = "_Manual";
		SegTypeStr = "Manual";
	}
	else 
	{	
		SuffixStr = "";
		SegTypeStr = "Auto";
	}
	print(origName, SuffixStr, SegTypeStr);
}

//===============================================================================================================
// output is Rois in RoiManager and masked label image named  "DomainLabels"
function GetDomainsRoisFromIlastik(directory, resFolder, origName, origNameNoExt)
{
	ilastikSegmentationFileName = origNameNoExt + "_Multicut Segmentation.h5";
	found = false;
	roiManager("reset");
	selectImage(origName);
	getDimensions(width, height, channels, slices, frames);
	if (File.exists(resFolder+ilastikSegmentationFileName))
	{
		found = true;		
		fileName=resFolder+ilastikSegmentationFileName;
		run("Import HDF5", "select=["+fileName+"] datasetname=/exported_data axisorder=tzyxc");

		if (batchModeFlag)
		{
			run("Duplicate...", "title=IlastikLabels");
			print("Going into Batch Mode, processing without opening further images");
			setBatchMode(true);
		} else
			rename("IlastikLabels");
		
		MaskLabels("IlastikLabels", "MeasureAreaMask"); 
		// Add labels to Roi Manager
		run("LabelMap to ROI Manager (2D)");
		roiManager("Deselect");
		
		SaveDomainRois(resFolder+origNameNoExt+DomainRoisSuffix);
	} else {
		print(ilastikSegmentationFileName," Not found");
		exit("You need to Run the macro in *Segment* mode before running again in *Update* mode");		
	}
}


//===============================================================================================================
// Output is a label image named "DomainLabels"
function MaskLabels(LabelsIm, MaskIm) 
{
	//selectWindow("MeasureAreaMask");
	selectWindow(MaskIm);
	run("Duplicate...", "title=MeasureAreaMask01");
	run("Divide...", "value=255");
	imageCalculator("Multiply create", LabelsIm,"MeasureAreaMask01");
	//selectWindow("Result of IlastikLabels");
	//rename("MaskedIlastikLabels");
	rename("MaskedLabels");

	// remove labels that touch the border of the mask
	fgColor = getValue("color.foreground");
	//selectWindow("MeasureAreaMask");
	selectWindow(MaskIm);
	run("Duplicate...", "title=MaskBorder");
	run("Create Selection");
	run("Enlarge...", "enlarge=-1 pixel");
	setForegroundColor(0, 0, 0);
	run("Fill", "slice");
	run("Select None");
	//setForegroundColor(255, 255, 255);
	setForegroundColor(fgColor);
	selectWindow("MaskBorder");
	run("Divide...", "value=255");
	//imageCalculator("Multiply create", "MaskedIlastikLabels","MaskBorder");			
	imageCalculator("Multiply create", "MaskedLabels","MaskBorder");			
	//selectWindow("Result of MaskedIlastikLabels");
	rename("BorderLabels");

	if (0)
		getRawStatistics(nPixels, mean, min, max, std, histogram);
	if (1)
	{
		run("Label analyser (2D, 3D)", "label=BorderLabels image=BorderLabels area_volume n_=5 d_=100 table");	
		selectWindow("Label properties");
		//print("nLines=", getValue("results.count"));
		nLabels = getValue("results.count");
		if (nLabels > 0) 
		{
			label=Table.getColumn("Label");
			volume=Table.getColumn("volume");
			
		}
	}
	//selectWindow("MaskedIlastikLabels");
	selectWindow("MaskedLabels");
	//run("Duplicate...", "title=MaskedIlastikLabels-KillCloseToBorder");
	run("Duplicate...", "title=MaskedLabels-KillCloseToBorder");

	//selectWindow("MaskedIlastikLabels-KillCloseToBorder");
	selectWindow("MaskedLabels-KillCloseToBorder");
	if (0) Table.showArrays("Border label Histogram", histogram);
	if (0)
	{
		for (n=1; n < histogram.length; n++)
		{
			if (histogram[n] > 0){
				changeValues(n, n, 0);
				print("Removing label ",n);
			}
		}
	}
	if (1) 
	{
		for (n=0; n < nLabels; n++)
		{
			if (volume[n] > 0){
				changeValues(label[n], label[n], 0);
				//print("Removing label ",label[n]);
			}
		}		
		CloseTable("Label properties");
	}
	rename("DomainLabels");
	
}

		
//===============================================================================================================
function SaveDomainRois(FullRoiNameNoExt)
{
	nRois = roiManager("count");
	if (nRois > 1)
		roiManager("Save", resFolder+origNameNoExt+DomainRoisSuffix+".zip");
	if (nRois == 1)
		roiManager("Save", resFolder+origNameNoExt+DomainRoisSuffix+".roi");
}

//===============================================================================================================
// Generate mask of Measure ROIs into image named "MeasureAreaMask"
// open Rois file, if Roi File dos not exist create a mask of the whole image
function GetMeasureRoisMask(resFolder, origNameNoExt, Im, MeasureRoisSuffix)
{
	roi_name = origNameNoExt + MeasureRoisSuffix + ".zip";
	roi_name1 = origNameNoExt + MeasureRoisSuffix + ".roi";

	found = false;
	roiManager("reset");
	if (File.exists(resFolder+roi_name))
	{
		found = true;		
		roiManager("Open", resFolder+roi_name);
		print("GetMeasureRois: Open existing Roi File: ", resFolder+roi_name);
	} else if (File.exists(resFolder+roi_name1))
	{
		found = true;		
		roiManager("Open", resFolder+roi_name1);
		print("GetMeasureRois: Open existing Roi File: ", resFolder+roi_name1);
	}	
	nRois = roiManager("count");
	if (nRois >= 1)
		roiManager("Combine");
	else 
	{
		getDimensions(width, height, channels, slices, frames);
		run("Specify...", "width="+width+" height="+height+" x=0 y=0");
	}
	run("Create Mask");
	selectWindow("Mask");
	rename("MeasureAreaMask");
	selectImage(Im);
	run("Select None");
//setBatchMode("show");
}

//===============================================================================================================
// look for existing ROIs in the results folder, 
// if it does not exist, then ask the user to select foreground and background ROIs, and save them for later runs
function GetMeasureRois(resFolder, origNameNoExt, Im, MeasureRoisSuffix)
{
	// clear RoiManager
	roiManager("Reset");

	roi_name = origNameNoExt + MeasureRoisSuffix + ".zip";
	roi_name1 = origNameNoExt + MeasureRoisSuffix + ".roi";

	found = false;
	roiManager("reset");
	if ( matches(existingMeasureRoisMode, "OpenExistingForEditing") || matches(existingMeasureRoisMode, "SkipExisting") )
	{
		// Check for existing ROIs, in Editing mode open Existing Rois
		if (File.exists(resFolder+roi_name))
		{
			found = true;		
			if ( matches(existingMeasureRoisMode, "OpenExistingForEditing")) 
			{
				roiManager("Open", resFolder+roi_name);
				print("GetMeasureRois: Open existing Roi File: ", resFolder+roi_name);
			}
			else 
				print("GetMeasureRois: Skipping existing Roi File: ", resFolder+roi_name);
		} else if (File.exists(resFolder+roi_name1))
		{
			found = true;		
			if ( matches(existingMeasureRoisMode, "OpenExistingForEditing")) 
			{
				roiManager("Open", resFolder+roi_name1);
				print("GetMeasureRois: Open existing Roi File: ", resFolder+roi_name1);
			}
			else 
				print("GetMeasureRois: Skipping existing Roi File: ", resFolder+roi_name1);
		}	
		/*
		nROIs = roiManager("Count");
		NumberOfFgRoi = 0;
		NumberOfBgRoi = 0;
		for (i=0; i< nROIs; i++)
		{
			roiManager("Select", i);
			roiName=call("ij.plugin.frame.RoiManager.getName", i);
			if (startsWith(roiName, ForgroundText)) NumberOfFgRoi++;
			if (startsWith(roiName, BackgroundText)) NumberOfBgRoi++;
		}
		print(origNameNoExt, ": Use existing ROIs, NumberOfFgRoi=",NumberOfFgRoi, ", NumberOfBgRoi=",NumberOfBgRoi);
		*/
		if ( matches(existingMeasureRoisMode, "OpenExistingForEditing") && found)
		{
			roiManager("Show All with labels");
			waitForUser("Check Existing Rois and Edit if needed, \nClick OK when Done");			
		}
	}
	//else // Get New Rois
	if ( !found )
	{
		print(origNameNoExt, ": select New ROIs");
		
		// get User ROIs
		roiTypeText = "Measurment Areas ROIs";
		RoiNamePrefix = "Roi_";
		NumberOfRoi = GetUserRois(Im, roiTypeText, DefaultNumberOfRoi, RoiNamePrefix);
	}
	// Save the Rois
	nRois = roiManager("count");
	if (nRois == 1)
		roiManager("Save", resFolder+roi_name1);	
	if (nRois > 1)
		roiManager("Save", resFolder+roi_name);	
}



//===============================================================================================================
//function numRoi = GetUserRois(Im, roiTypeText, DefaultNumbOfRoi, PrefixText)
function GetUserRois(Im, roiTypeText, DefaultNumbOfRoi, PrefixText)
{
	title = "how many "+ roiTypeText + " do you want?";

	Dialog.create("input dialog");
	Dialog.addMessage(title);
	Dialog.addNumber("ROI:",DefaultNumbOfRoi);
	Dialog.show;
	numRoi= Dialog.getNumber();

	// Loop on number of Rois
	for (r=1; r<=numRoi; r++) {
		selectImage(Im);
		
		run("Select None");
		setTool(RoiSelectionTool);
		waitForUser("Please select  "+roiTypeText + " "+ r + ", Click OK when done");
		roiManager("Add");
		roiManager("Select", roiManager("Count")-1);
		roiManager("Rename", PrefixText+r);
		roiManager("Set Color", DomainColor);
	}	// for numRoi

	run("Select None");
	setTool("hand");		

	return numRoi;
}



//===============================================================================================================
function Initialization()
{
	requires("1.53c");
	run("Check Required Update Sites");

	if (matches(imageType, "AFM"))		
	{
		if (matches(segModeForAFM, "MorphologicalSegmentation"))		
		{
			run("CLIJ2 Macro Extensions", "cl_device=");
			Ext.CLIJ2_clear();
		}
	}	
	
	setBatchMode(false);
	run("Close All");
	print("\\Clear");
	run("Options...", "iterations=1 count=1 black");
	run("Set Measurements...", "area redirect=None decimal=3");
	roiManager("Reset");

	// Name Settings, Set output Suffixes based on SegMode
	if (matches(runMode, "Segment")) 
	{
		SummaryTable = "SummaryResults.xls";
		AllDetailedTable = "AllDetailedResults.xls";
	} else  // (SegMode=="Update") 
	{
		SummaryTable = "SummaryResults_Manual.xls";
		AllDetailedTable = "AllDetailedResults_Manual.xls";
	}	
	CloseTable("Results");
	CloseTable("DetailedResults");
	CloseTable(SummaryTable);
	CloseTable(AllDetailedTable);

	run("Collect Garbage");

	// keep it to 0 - Morphological Segmentation does not work with BatchMode
	// Enter batch mode at this stage only for AFM / segmentation, for EM enter batch mode only after getting Ilastik labels
	// for AFM / morphological segmentation get into batch mode only after Morphological segmentation 
	//if (batchModeFlag && !(matches(imageType, "AFM") && matches(segModeForAFM, "MorphologicalSegmentation")))
	if (batchModeFlag && (matches(imageType, "AFM") && matches(segModeForAFM, "Threshold")))
	{
		print("Working in Batch Mode, processing without opening images");
		setBatchMode(true);
	}	
	//print("Initialization Done");
	print("Initialization Done, nImages=",nImages);
}

//===============================================================================================================
function CreateAndSaveColorCodeImage(labeledImName, TableName, resFolder, saveName, FtrName, SuffixStr, MinVal, MaxVal, decimalVal, calibrationZoom, LUTName)
{
	selectImage(labeledImName);
	run("Assign Measure to Label", "results="+TableName+" column="+FtrName+" min="+MinVal+" max="+MaxVal);
	run(LUTName);
	run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal="+decimalVal+" font=12 zoom="+calibrationZoom+" overlay");
	run("Flatten");
	saveAs("Tiff", resFolder+saveName+"_"+FtrName+"_Flatten"+SuffixStr+".tif");
}


//===============================================================================================================
function Cleanup()
{
	run("Select None");
	run("Close All");
	run("Clear Results");
	roiManager("reset");
	if (isOpen("Morphological Segmentation"))
	{
		selectWindow("Morphological Segmentation");
		run("Close");
		//print("Morphological Segmentation Closed");
	}	
	run("Collect Garbage");

	if (matches(imageType, "AFM"))		
		if (matches(segModeForAFM, "MorphologicalSegmentation"))		
			Ext.CLIJ2_clear();
			
	if (batchModeFlag && !(matches(imageType, "AFM") && matches(segModeForAFM, "Threshold")))
	{
		setBatchMode(false);
	}	
	CloseTable("DetailedResults");
}


//===============================================================================================================
function CloseTable(TableName)
{
	if (isOpen(TableName))
	{
		selectWindow(TableName);
		run("Close");
	}
}

//===============================================================================================================
//function SaveOverlayImage(imageName, MaskImage, baseSaveName, Suffix, resDir)
function SaveOverlayImage(imageID, MaskImage, baseSaveName, Suffix, resDir)
{
	// Overlay Domain
	//selectImage(imageName);
	selectImage(imageID);
	//selectWindow(imageName);
	roiManager("Deselect");
	//roiManager("Show None");
	roiManager("Set Color", DomainColor);
	roiManager("Set Line Width", 0);
	//roiManager("Show All with labels");
	roiManager("Show All without labels");

	// Overlay Mask Area
	run("Flatten");
	im = getImageID();
	//selectWindow(MaskImage);
	selectImage(MaskImage);
	run("Create Selection");
	selectImage(im);
	run("Restore Selection");
	run("Properties... ", "  stroke="+MeasureAreaColor);

	run("Flatten");
	saveAs("Tiff", resDir+baseSaveName+Suffix);
}


//===============================================================================================================
function CreateAndSaveColorCodeImage(labeledImName, TableName, resFolder, saveName, FtrName, SuffixStr, MinVal, MaxVal, decimalVal, calibrationZoom, LUTName)
{
	selectImage(labeledImName);
	run("Assign Measure to Label", "results="+TableName+" column="+FtrName+" min="+MinVal+" max="+MaxVal);
	run(LUTName);
	run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal="+decimalVal+" font=12 zoom="+calibrationZoom+" overlay");
	run("Flatten");
	saveAs("Tiff", resFolder+saveName+"_"+FtrName+"_Flatten"+SuffixStr+".tif");
}


//===============================================================================================================
// Open File_Manual.zip ROI file  if it exist, otherwise open  File.zip
// returns 1 if Manual file exist , otherwise returns 0
function OpenExistingROIFile(baseRoiName)
{
	roiManager("Reset");
	manaulROI = baseRoiName+"_Manual.zip";
	manaulROI1 = baseRoiName+"_Manual.roi";
	origROI = baseRoiName+".zip";
	origROI1 = baseRoiName+".roi";
	
	if (File.exists(manaulROI))
	{
		print("opening:",manaulROI);
		roiManager("Open", manaulROI);
		manualROIFound = 1;
	} else if (File.exists(manaulROI1))
	{
		print("opening:",manaulROI1);
		roiManager("Open", manaulROI1);
		manualROIFound = 1;
	} else // Manual file not found, open original ROI file 
	{
		if (File.exists(origROI))
		{
			print("opening:",origROI);
			roiManager("Open", origROI);
			manualROIFound = 0;
		} else if (File.exists(origROI1))
		{
			print("opening:",origROI1);
			roiManager("Open", origROI1);
			manualROIFound = 0;
		} else {
			print(origROI," Not found");
			exit("You need to Run the macro in *Segment* mode before running again in *Update* mode");
		}
	}
	return manualROIFound;
}


//===============================================================================================================
function SavePrms(resFolder)
{
	// print parameters to Prm file for documentation
	PrmFile = resFolder+"QuantifyBrainyCrystalsDomainsParameters.txt";
	File.saveString("macroVersion="+macroVersion, PrmFile);
	File.append("", PrmFile); 
	setTimeString();
	File.append("RunTime="+TimeString, PrmFile)
	File.append("runMode="+runMode, PrmFile); 
	File.append("processMode="+processMode, PrmFile); 
	File.append("imageType="+imageType, PrmFile); 
	File.append("fileExtension="+fileExtension, PrmFile); 
	File.append("existingMeasureRoisMode="+existingMeasureRoisMode, PrmFile); 
	File.append("segModeForAFM="+segModeForAFM, PrmFile); 
	File.append("WatershedFlag="+WatershedFlag, PrmFile); 
	File.append("ManualThreshold="+ManualThreshold, PrmFile); 
	File.append("ThresholdMethod="+ThresholdMethod, PrmFile); 
	File.append("TubenessSigma="+TubenessSigma, PrmFile); 
	File.append("Tolerance="+Tolerance, PrmFile); 
	File.append("Connectivity="+Connectivity, PrmFile); 
	File.append("WaitTime="+WaitTime, PrmFile); 
	File.append("MinSize="+MinSize, PrmFile); 
	File.append("Radius="+Radius, PrmFile); 
}


//===============================================================================================================
function setTimeString()
{
	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString ="Date: "+DayNames[dayOfWeek]+" ";
	if (dayOfMonth<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+", Time: ";
	if (hour<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+hour+":";
	if (minute<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+minute+":";
	if (second<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+second;
}


