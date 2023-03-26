// zStack 3D Density
// Version: 3.3.0
// Authors: Augustin WALTER
//
// ChangeLogs:
//			* v3.3:
//				- Add ICS file support using BioFormat reader
//
//			* v3.2:
//				- Correction of the SOI volume formula.
//
//			* v3.1.0:
//				- Support ".merge" files
//				- Add an option to export comments and zStack recrop values

				


// Changelog v3.3.1:
//					- Fixing a bug when measuring density with binary mask created after ROI selection.
// 


requires("1.52r");
run("Bio-Formats Macro Extensions");

var ver = "3.3";
var name = "zStack 3D Density";

var startTime = getTime();

var devMode = false; // Use this option to debug the script




// Clear ROI Manager and close all opened windows
//clearROIMan();
//run("Close All");

// Clear log
print("\\Clear");
print("\n\r\n\r================================================================================\nRunning macro '" + name + "' v." + ver +
	  "\n\r                                                                                                                    by Augustin Walter." +
	      "\n\r================================================================================" );
print("\n\r\n\r");

if ( isOpen( "Log" ) ) { selectWindow("Log"); }

var inDir;

var settingFilePath = getDirectory("macros") + "zStack_Fluorescence_Quantification_v2_Settings.ini";
print("> Setting file path: " + settingFilePath);

// Define gloab vars
var operationToPerform; operationToPerform = settingRead(settingFilePath, "operationToPerform", "Create/Modify ROIs set");
var selectImgs; selectImgs = settingRead(settingFilePath, "selectImgs", "No, process all files");
var selectSeries; selectSeries = settingRead(settingFilePath, "selectSeries", "No, process all series"); 

var analysisFilesDir; var setROIFiles;
var listOfImg 		= newArray( );
var selectedImages 	= newArray( );
var selectedSeries	= newArray( );

var selectedAnalysisSet = ""; selectedAnalysisSet = settingRead(settingFilePath, "selectedAnalysisSet", "Create a new set of ROIs" );

var totalImages = 0; var totalSeries = 0; var totalSeriesOfAllFiles = 0;

//var selectImgs;
//var selectSeries;
//var setROIsFound;

var filterList = newArray(  "Gaussian Blur",
							"Median",
							"Mean",
							"Minimum",
							"Maximum",
							"Variance" );

var filter3DList = newArray( "Gaussian Blur 3D",
							 "Median 3D",
							 "Mean 3D",
							 "Minimum 3D",
							 "Maximum 3D",
							 "Variance 3D" );

var thresholdsList = getList("threshold.methods");

var outDir	 			 ; outDir 				 = settingRead( settingFilePath, "outDir", "3D Density Analysis" );
var signalCh 			 ; signalCh 			 = parseInt( 	settingRead( settingFilePath, "signalCh", 1 ) );
var soiChannelName 		 ; soiChannelName 		 = settingRead( settingFilePath, "soiChannelName", "Signal Of Interest" );
var subBk 				 ; subBk 				 = parseInt( 	settingRead( settingFilePath, "subBk", 1 ) );
var subBkSize 			 ; subBkSize 			 = parseInt( 	settingRead( settingFilePath, "subBkSize", 50 ) );
var filterType			 ; filterType 			 = settingRead( settingFilePath, "filterType", "Use 3D Filter" );
var filter3D 			 ; filter3D 			 = settingRead( settingFilePath, "filter3D", "Median 3D" );
var filter2D 			 ; filter2D 			 = settingRead( settingFilePath, "filter2D", "Median" );
var Xsigma				 ; Xsigma 				 = parseInt( 	settingRead( settingFilePath, "Xsigma", 2 ) );
var filterRadius		 ; filterRadius 		 = parseInt( 	settingRead( settingFilePath, "filterRadius", 2 ) );
var Ysigma 				 ; Ysigma 				 = parseInt( 	settingRead( settingFilePath, "Ysigma", 2 ) );
var Zsigma				 ; Zsigma 				 = parseInt( 	settingRead( settingFilePath, "Zsigma", 2 ) );
var signalThresholdMethod; signalThresholdMethod = settingRead( settingFilePath, "signalThresholdMethod", "Default" );
var forceSpatialCalib	 ; forceSpatialCalib 	 = parseInt( 	settingRead( settingFilePath, "forceSpatialCalib",  0 ) );
var customX				 ; customX 				 = parseFloat( 	settingRead( settingFilePath, "customX", 1 ) );
var customY				 ; customY 				 = parseFloat( 	settingRead( settingFilePath, "customY", 1 ) );
var customZ				 ; customZ 				 = parseFloat( 	settingRead( settingFilePath, "customZ", 1 ) );
var csvResultSeparators	 ; csvResultSeparators	 = settingRead( settingFilePath, "csvResultSeparators", ";" );
var thresholdBeforeROI	 ; thresholdBeforeROI	 = parseInt( 	settingRead( settingFilePath, "thresholdBeforeROI", 0 ) );	
var thresholdEachSlice	 ; thresholdEachSlice	 = parseInt( 	settingRead( settingFilePath, "thresholdEachSlice", 0) ) ;
var saveIntermediateFiles; saveIntermediateFiles = parseInt( 	settingRead( settingFilePath, "saveIntermediateFiles", 1 ) );
var bleachCorrection	 ; bleachCorrection	 	 = settingRead( settingFilePath, "bleachCorrection", "Do Not Use" ) ;
var enhanceImg			 ; enhanceImg			 = parseInt( 	settingRead( settingFilePath, "enhanceImg", 1 ) );

// MAIN SCRIPT ==================================================================================================

// Ask user for the operation to perform
promptOperationToPerform( "" );


// List the image files (ND and LIF files only)
listOfImg = listImgFilesInDir( "", inDir );
print( "> Nb of image files found (ND and LIF files): " + listOfImg.length );


// Ask user to select files to process
if ( selectImgs == "Yes" ) {
	tempSelectedImages = selectImages( listOfImg, "Select images", "Select image files to process:", analysisFilesDir + selectedAnalysisSet + File.separator, true, selectedAnalysisSet );
	img2 = 0;

	// Create a list that contains the name of selected images
	for ( img = 0; img < listOfImg.length; img++ ) {
		if ( tempSelectedImages[img] == "1" ) {
			selectedImages = Array.concat( selectedImages, listOfImg[img] );
			img2++;
			
		}
		
	}

} else {
	selectedImages = listOfImg;
	

}


// Update the nb of files to process
totalImages = selectedImages.length;


// Ask user to select series (only for LIF files)
if ( selectSeries == "Yes" ) {
	selectedSeries = selectFileSeries( "", selectedImages, inDir, false, selectedAnalysisSet );
	
} else {
	selectedSeries = selectFileSeries( "", selectedImages, inDir, true, "" );
	
}
print("> Total nb. of series to process: " + totalSeriesOfAllFiles);
print( "> Images selected: " ); Array.print(selectedImages);
print( "> Series selected: " ); Array.print(selectedSeries);


// Define the start time
startTime = getTime();
// print("   @ time " + returnTime( getTime() - startTime ) );

// Create Modify ROIs Set if operation selected
if ( operationToPerform == "Create/Modify ROIs set" ) {
	print( " " ); 
	if ( selectedAnalysisSet == "Create a new set of ROIs" ) {
		print( "> Create ROIs set" );

	} else {
		print( "> Modify the ROIs set '" + selectedAnalysisSet + "'" );
		
	}

	// Call the function that allow the user to create the ROIs Set
	createModifyROIset( "     ", selectedAnalysisSet, inDir, selectedImages, selectedSeries );

	showStatus("END of the macro");
	print( " " ); print( "END of the macro " + name );

} else if ( operationToPerform == "Export comments" ) {
	exportComments();
	exit();
	
// Perform the analysis
} else {
    // Ask user for the parameters
    setAnalysisParameters( "" ); 

     // Perform the analysis
     performAnalysis( "     ", selectedAnalysisSet, inDir, inDir + outDir, selectedImages, selectedSeries );

     print( "> Analysis finished" );

}


// ==============================================================================================================
// MAIN FUNCTIONS ===============================================================================================
// ==============================================================================================================


function exportComments() {
	// Export coments and recrop values
	print("\n\r>Starting comments export:");

	// List file in AW folder
	awFilesList = getFileList( analysisFilesDir + selectedAnalysisSet + File.separator );

	// Filter "*.stack" files
	stackFilesList = newArray();
	for ( i = 0; i < awFilesList.length; i ++ ) {
		if ( endsWith( awFilesList[i], ".stack" ) ) {
			stackFilesList = Array.concat( stackFilesList, awFilesList[i] );
		
		}
		
	}
	Array.print( stackFilesList );

	// Prepare the table
	Table.create( "Images comments and recrop from folder " + inDir );
	Table.setLocationAndSize("", "", 750, 650)
	
	// Create columns
	Table.set( "Fichier", 0, "" ); Table.set( "Serie", 0, "" ); Table.set( "zStack Recrop", 0, "" );	Table.set( "Comment", 0, "");
	
	// Parse selected image files
	for ( img = 0; img < stackFilesList.length; img++ ) {
		fileName = File.getNameWithoutExtension( stackFilesList[img] );
		//print( "   - Processing file '" + stackFilesList[img] + "' (" + (img+1) + "/" + stackFilesList.length + ")" );
		
		// Process only LIF files (that can contain multiple series)
		if ( endsWith( toLowerCase( stackFilesList[img] ), ".lif" ) ) { 
			// Prepare file
			file = inDir + stackFilesList[img];
			Ext.setId( file );
			Ext.getSeriesCount( seriesCount );		
		
			// Parse series
			for ( ser = 0; ser < seriesCount; ser++ ) {
				// Get info about the current serie
				Ext.setSeries(ser);
				
				if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack" ) ) {
					Table.set( "Fichier", img, fileName ); 
					Table.set( "Serie", img, (ser+1) ); 
					tempVal = settingRead(analysisFilesDir + selectedAnalysisSet + File.separator + File.getNameWithoutExtension(stackFilesList[img]) + ".stack", "series_" + (ser+1), 0 );
					Table.set( "zStack Recrop", img, tempVal ); 
					tempVal = settingRead(analysisFilesDir + selectedAnalysisSet + File.separator + File.getNameWithoutExtension(stackFilesList[img]) + ".stack", "comment_" + (ser+1), 0 );
					Table.set( "Comment", img, tempVal );

				}

			}			
			
		} else {

			if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack" ) ) {
				Table.set( "Fichier", img, fileName ); 
				Table.set( "Serie", img, 1); 
				tempVal = settingRead(analysisFilesDir + selectedAnalysisSet + File.separator + File.getNameWithoutExtension(stackFilesList[img]) + ".stack", "series_1", 0 );
				Table.set( "zStack Recrop", img, tempVal ); 
				tempVal = settingRead(analysisFilesDir + selectedAnalysisSet + File.separator + File.getNameWithoutExtension(stackFilesList[img]) + ".stack", "comment_1", 0 );
				Table.set( "Comment", img, tempVal );

			} else {
				// Indicate blank values if image has no comments
				Table.set( "Fichier", 0, fileName ); Table.set( "zStack Recrop", 0, "---" );	Table.set( "Comment", 0, 0 );

			}
			
		}
		
	}
	
	
}



function performAnalysis( logTab, ROIset, filesPath, outputDir, listOfSelImages, listOfSelSeries ) {
	// This function performs the analysis
	//
	// Parameters: 
	//			- logTab: insert string that contains tabulations to indent print output in log file
	//			- ROIset: a string containing the name of the ROIs set to modify OR the str "Create a new set of ROIs" to create a new ROIs Set
	//			- filesPath: string that refers to the path of the directory that contains the images files
	//			- listOfSelImages: an array containing the name of the selected image files
	//			- listOfSelSeries: an array containing the selectec series as string. 
	//
	// Returns: 
	//			- A string: the name of the log file

	print( "\n\r\n\r" + logTab + "> Starting the analysis:" );
	print(logTab + "        @ time " + returnTime( getTime() - startTime ) );

	// Local vars 
	fileResultPath = "";
	logFilePath = "";

	if ( csvResultSeparators == "TAB" ) { csvResultSeparators = "\t"; }

	if ( !File.exists( outputDir ) ) {
		File.makeDirectory( outputDir );
		//if ( !File.exists( inDirsh + outputDir + File.separator ) ) { print( logTab + "          >>> ERROR >>> Cannot create the result file." ); }
		
	}
	
	// Prepare log savefile
	if ( File.exists( outputDir + File.separator + soiChannelName + "_1.csv" ) ) {
		i = 1;
		while (true) {
			i++;
			if ( !File.exists( outputDir + File.separator + soiChannelName + "_" + i + ".csv" ) ) {
				fileResultPath 	= outputDir + File.separator + soiChannelName + "_" + i + ".csv";
				logFilePath 	= outputDir + File.separator + soiChannelName + "_log_" + i +".txt"; 
				break;
			
			}
		
		}
	
	} else {
		fileResultPath 	= outputDir + File.separator + soiChannelName + "_1" + ".csv";
		logFilePath 	= outputDir + File.separator + soiChannelName + "_log_1" +".txt";
	
	}
	print( logTab + "     - Results file path: " + fileResultPath );

	// Enable Batch Mode ===================================================================================================
	setBatchMode( !devMode );
	print( logTab + "     - Batch mode enabled." );

	// Set Measurments
	run("Set Measurements...", "area limit redirect=None decimal=4");

	// Write first row of results file
	File.saveString( "Results file of macro '" + name + "'\n\r" +
					 "Image file" + csvResultSeparators +
					 "Image file Type" + csvResultSeparators +
					 "Image Bit Depth" + csvResultSeparators +
					 "Serie" + csvResultSeparators +
					 "Comment" + csvResultSeparators +
					 "ROI number" + csvResultSeparators +
					 "ROI volume (microns³)" + csvResultSeparators +
					 "SOI volume (microns³)" + csvResultSeparators +
					 "SOI density (no units)" + csvResultSeparators +
					 "" + csvResultSeparators +
					 "" + csvResultSeparators,
					 fileResultPath );
	
	// Parse selected image files
	for ( img = 0; img < listOfSelImages.length; img++ ) {
		roiFound = false;
		//run("Close All");

		currentImgName = toLowerCase( listOfSelImages[img] );
		file = filesPath + listOfSelImages[img];		
		// Get file infos
		fileType = substring( currentImgName, lastIndexOf( currentImgName, "." ) + 1 );
		fileName = File.getNameWithoutExtension( listOfSelImages[img] );
		
		if ( fileType != "merge" ) { 
			Ext.setId(file); 
		
		} else {
			Ext.setId( filesPath + settingRead(file, "channel_1", 0) );
			
		}
		
		// Get nb of series of the file
		currentSelectedSeries = split(listOfSelSeries[img], "*");
		
		//fileName = "";
		print( logTab + "     + Processing image " + (img+1) + "/" + listOfSelImages.length );
		print( logTab + "        @ time " + returnTime( getTime() - startTime ) );
		print( logTab + "       --> " + fileName + "." + fileType );
		print( logTab + "       --> " + file );
		
		for ( ser = 0; ser < currentSelectedSeries.length; ser++ ) {
			if ( currentSelectedSeries[ser] == "1" ) {
				run( "Collect Garbage" );
				
				// Get series info
				Ext.setSeries(ser); 
				Ext.getSizeZ(sizeZ); 

				if ( fileType != "merge" ) { 
					Ext.getSizeC(sizeC);

				} else {
					sizeC = parseInt( settingRead( file, "channels", 1) );
					
				}
				
				clearROIMan();

				print( logTab + "          * Processing serie " + (ser+1) + "/" + currentSelectedSeries.length );

				startSlice = 1; endSlice = sizeZ;
				// Check channels
				if ( signalCh > 0 && signalCh <= sizeC ) {
					// Get the reCrop stack size
					if ( File.exists( analysisFilesDir + ROIset + File.separator + fileName + ".stack" ) ) {
						print( logTab + "               - STACK file found" );
						sCrop = settingRead( analysisFilesDir + ROIset + File.separator + fileName + ".stack", "series_" + (ser + 1), "1-" + sizeZ );
			
						if (sCrop != -1) {
							startSlice = parseInt( substring( sCrop, 0, indexOf(sCrop, "-") ) );
							endSlice = parseInt( substring( sCrop, indexOf(sCrop, "-") + 1 ));
						
						}
						if ( startSlice < 1 ) { startSlice = 1; }
						if ( endSlice > sizeZ ) { endSlice = sizeZ; }

						print( logTab + "               - New stack size: " + startSlice + " to " + endSlice + " (size: " + ( (endSlice - startSlice) + 1 ) + ")" );

					}

					// Open the soi channel
					showStatus("Opening zStack");
					print( logTab + "               - Opening zStack..." );
					if ( fileType == "lif" ) {
						run("Bio-Formats Importer", "open=[" + file + "] autoscale color_mode=Default rois_import=[ROI manager] specify_range " +
													"view=Hyperstack stack_order=XYCZT series_" + (ser + 1) + 
													" c_begin_" + (ser + 1) + "=" + signalCh + " c_end_" + (ser + 1) + "=" + signalCh + " c_step_" + (ser + 1) + "=1" +
													" z_begin_" + (ser + 1) + "=" + startSlice + " z_end_" + (ser + 1) + "=" + endSlice + " z_step_" + (ser + 1) + "=1 " );

					} else if ( fileType == "merge" ) {
						print( logTab + "               - Merge file opening result: " + openMergeFile( file, startSlice, endSlice, (signalCh-1), 1 ) );
						
					} else {
						run("Bio-Formats Importer", "open=[" + file + "] autoscale color_mode=Default rois_import=[ROI manager] specify_range " +
													"view=Hyperstack stack_order=XYCZT" + 
													" c_begin=" + signalCh + " c_end=" + signalCh + " c_step=1" +
													" z_begin=" + startSlice + " z_end=" + endSlice + " z_step=1 " );
						
					}
					print( logTab + "               - Success" );
					soiID = getImageID();
					getDimensions( width, height, channels, newZSize, frames );

				
					// Get calibration
					getVoxelSize(pixelWidth, pixelHeight, pixelDepth, unit);
					if ( forceSpatialCalib == "Force Custom spatial calibration" ) {
						print( logTab +  "               - Forcing global calibration" );
						setVoxelSize(customX, customY, customZ, "microns");
				
					}
					getVoxelSize( pxWidth, pxHeight, pxDepth, pxUnit );
					imgBitD = bitDepth();

					// Check if ROIs file exists
					if ( File.exists( analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "]" + ".zip" ) || 
						 File.exists( analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "]" + ".roi" ) ) {
						roiFound = true;
							 	
					}

					nbOfROIs = 0;

					if ( roiFound ) {
						clearROIMan(); // Clear the ROI manager

						// Count the nb. of ROIs and load them in the ROI manager
						if ( File.exists( analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "]" + ".zip" ) ) {				
							// Load ROIs
							roiManager("Open", analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "]" + ".zip");

						} else if ( File.exists( analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "]" + ".roi" ) ) {
							// Load ROIs
							roiManager("Open", analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "]" + ".roi");
						
						}

						nbOfROIs = roiManager("count"); 
						print( logTab + "               - " + nbOfROIs + " ROIs found and loaded");
						
						
					} else {
						// No ROI files found
						nbOfROIs = 1;
						// No ROI created, an ROI corresponding to the whole image is created
						run("Select All");
						roiManager("Add");
						print( logTab + "               - No ROIs found for this image, processing the whole image field" );
					
					}

					// Bleach COrrection
					selectImage( soiID );
					if ( bleachCorrection != "Do Not Use" ) {
						// Convert image to 16-bit if bit-depth > 16
						if ( bitDepth() > 16 ) { 
							print( logTab + "               - Converting image to 16-bit..." );
							run("16-bit"); 
						
						}

						print( logTab + "               - Correcting bleaching (using " + bleachCorrection + ")..." );
						if ( bleachCorrection == "Simple Ratio" ) {
							run("Bleach Correction", "correction=[&bleachCorrection] background=0");

						} else {
							run("Bleach Correction", "correction=[&bleachCorrection]");
						
						}
					
					}

					// Subtract background on the all image
					selectImage( soiID );
					run( "Select None" ); 
					if (subBk) {
						print( logTab + "               - Subtracting background..." );
						run( "Subtract Background...", "rolling=&subBkSize stack" ); 
						
					}
				
					// Apply filter i
					if ( filterType != "Do not use Filter" ) {
						if ( filterType == "Use 2D FIlter" ) {
							tempFilter = "Applying 2D filter '" + filter2D + "'...";
							print( logTab + "               - " + tempFilter );
							run( filter2D, "radius=&filterRadius" );						
						
						} else {
							tempFilter = "Applying 3D filter '" + filter3D + "'...";
							print( logTab + "               - " + tempFilter );
							run( filter3D, "x=&Xsigma y=&Ysigma z=&Zsigma" );
						
						}
										
					}

					binaryID = 0;
					// apply threshold before or after ROI    thresholdEachSlice
					if ( thresholdBeforeROI ) {
						// Apply threshold before ROI
						print( logTab + "               - Applying threshold '" + signalThresholdMethod + "'..." );
						if ( !thresholdEachSlice ) {
							// select the midle slice of the zstack
							Stack.setSlice( parseInt( newZSize/2 ) );
							setAutoThreshold( signalThresholdMethod + " dark" );
							print( logTab + "               - Converting image to binary..." );
							run( "Convert to Mask", "method=&signalThresholdMethod background=Dark black" );
							run("Clear Outside", "stack");
							binaryID = getImageID();
						
						} else {
							setAutoThreshold( signalThresholdMethod + " dark" );
							print( logTab + "               - Converting image to binary..." );
							run("Convert to Mask", "method=&signalThresholdMethod background=Dark calculate black");
							binaryID = getImageID();
						
						}
						

						selectImage( binaryID );
						// Save intermediate file
						if ( saveIntermediateFiles ) {
							print( logTab + "               - Saving intermediate binary mask..." );
							//run("Invert", "stack");
							run("Bio-Formats Exporter", "save=[" +  outputDir + File.separator + fileName + "_" + ( ser + 1 ) + "_Mask.tif] compression=LZW"); //////////////////////////////////
				
						}
						// Close original SOI image
						selectImage( soiID );
						close();

						// Run analysis
						volumes = analyseImage( "               ", false, binaryID, pxDepth, pxUnit, inDir + outputDir + File.separator + fileName + "_" + ( ser + 1 ) );
					
					} else {
						// Threshold each roi
					
						// Run analysis
						volumes = analyseImage( "               ", true, soiID, pxDepth, pxUnit, inDir + outputDir + File.separator + fileName + "_" + ( ser + 1 ) );
						selectImage( soiID );
						close();
								
					}

					

					soiVolumes = split( volumes[1], ";" );
					roiVolumes = split( volumes[0], ";" );

					Array.print( soiVolumes );
					Array.print( roiVolumes );

				
					print( logTab + "          - Saving results to file..." );
					// Print results to file
					for ( roi = 0; roi < soiVolumes.length; roi++ ) {
						oldContent = File.openAsString( fileResultPath );
						density = ( parseInt( soiVolumes[roi] ) / parseInt( roiVolumes[roi] ) );
						File.saveString( "" + oldContent +
										 fileName + csvResultSeparators +
										 fileType + csvResultSeparators +
										 imgBitD + csvResultSeparators +
										 (ser+1) + csvResultSeparators +
										 settingRead(analysisFilesDir + ROIset + File.separator + fileName + ".stack", "comment_" + (ser+1), "" ) + csvResultSeparators +
										 (roi+1) + csvResultSeparators +
									 	 roiVolumes[roi] + csvResultSeparators +
									 	 soiVolumes[roi] + csvResultSeparators +
									 	 density + csvResultSeparators,
										 fileResultPath );

						}		
				
				
				} else {
					print( logTab + "          >>> ERROR >>> The zStack does not have enougth channels:" );
					print( logTab + "                        The SOI channel nb. (" + signalCh + ") is higher than the total nb. of channel of the zSTack (" + sizeC + ")." );
					print( logTab + "                        Skipping this image." );
				
				}

			} else {
				print( logTab + "          * Serie " + (ser+1) + "(/" + currentSelectedSeries.length + ") not selected." );
				
			}
		
		}		
		
	}

	  // Save log file 
	 print( logTab + "          * Saving log file..." );
     selectWindow( "Log" );
     saveAs( "Text", logFilePath );
     print( logTab + "          * End of the analysis." );
	
}

function analyseImage( logTab, makeBinary, imgID, pixelDepth, unit, intermediateName ) {
	// This function is the core function that analyse the signal of interest (SOI) on selected image
	//
	// Parameters:
	//				- logTab: insert string that contains tabulations to indent print output in log file
	//				- makeBinary: bool, if true then the binaray image will be created for each ROI loaded in the ROI manager
	//				- imgID: the ID of the zStack to process (the image is not closed at the end of the execution)
	//				- pixelDepth: the z calibration value of 1x of the selected image
	//				- unit: the unit of the size of a pixel dimension
	//				- name: name of intermediate files
	//
	//
	// Required global var:
	//				- startTime: the time in ms at the beginning of the macro
	//				- signalThresholdMethod: a string indicating the threshold method to use
	//
	// Required functions:
	//				- returnTime: function the takes time in ms and returns a formated time to print it in the log window
	//
	// Returns:
	//				- an array contaning two values:
	//												* the ROIs volumes: string separated by ';' for each ROI,
	//												* the SOIs volumes: string separated by ';' for each ROI.


	soiVolume = 0; roiVolume = 0; currentImgID = imgID;
	soiRet = "";
	roiRet = "";
	returnedArray = newArray( );

	nbROI = roiManager("count"); 
	
	// parse ROIs
	for ( roi = 0; roi < nbROI; roi++ ) {
		print( logTab + "- Processing ROI " + (roi+1) + "/" + nbROI );
		print( logTab + "        @ time " + returnTime( getTime() - startTime ) );

		temp = 0;
		
		// Load ROI from ROI manager
		selectImage( imgID );
		resetThreshold();		
		getDimensions( width, height, channels, slices, frames );
		roiManager( "Select", roi );

		// Calculate ROI volume
		run("Measure");
		roiVolume = getResult( "Area", nResults - 1 ) * slices * pixelDepth;
		print( logTab + "     . ROI volume: " + roiVolume + " " + unit + "³" );

		// Threshold image if option 'makeBinary' is set to true
		if ( makeBinary ) {
			run("Select None");
			print( logTab + "     . Applying threshold '" + signalThresholdMethod + "'..." );
			// Duplicate soiImage
			run( "Duplicate...", "duplicate" );
			currentImgID = getImageID();
			roiManager( "Select", roi );
			setBackgroundColor(0, 0, 0);
			run( "Clear Outside", "stack" );
			
			// Create binary image
			if ( !thresholdEachSlice ) {
				selectImage( currentImgID );
				// select the midle slice of the zstack
				Stack.setSlice( parseInt( newZSize/2 ) );
				setAutoThreshold( signalThresholdMethod + " dark" );
				//setOption("BlackBackground", false);
				print( logTab + "     . Converting image to binary..." );
				run( "Convert to Mask", "method=&signalThresholdMethod background=Dark black" );
						
			} else {
				selectImage( currentImgID );
				setAutoThreshold( signalThresholdMethod + " dark" );
				print( logTab + "     . Converting image to binary..." );
				run( "Convert to Mask", "method=&signalThresholdMethod background=Dark calculate black" );
						
			}			
			selectImage( currentImgID );

			// Save intermediate file
			if ( saveIntermediateFiles ) {
				print( logTab + "     . Saving intermediate binary mask..." );
				//print( logTab + "        ... as " + name + "_ROI-" + roi + "_" + "Mask.tif" );
				//run("Invert", "stack");
				run("Bio-Formats Exporter", "save=[" +  outputDir + File.separator + fileName + "_" + ( ser + 1 ) +
													"_ROI-" + roi + "_" + "Mask.tif] compression=LZW"); /////////////////////////////////
				
			}
			

		}
		//if (devMode) { waitForUser("Click ok bt to continue");}
		selectImage( currentImgID );

		// Run measurment on each slice limiting to the default threshold
		// Parse slice
		for ( slice = 1; slice <= slices; slice++ ) {
			selectImage( currentImgID );
			setSlice( slice );												// Select slice
			setAutoThreshold( "Default dark" ); 							// Apply a default threshold on binary image
			run("Measure");													// Measure area
			soiVolume += getResult( "Area", nResults - 1 );					// Calculate the value
			//if (devMode) { waitForUser("Click ok bt to continue");}
				
		}
		
		if (makeBinary) {
			selectImage( currentImgID );
			run( "Close" );
			
		}
		
				
		soiVolume *= pixelDepth; 
		print( logTab + "     . SOI volume: " + soiVolume + " " + unit + "³" );

		//if ( makeBinary ) { close(); }

		// Create the SOI returned array
		if ( roi == 0 ) {
			soiRet = "" + (soiVolume) + "";

		} else {
			soiRet += ";" + (soiVolume);
			
		}		

		// Create the ROI returned array
		if ( roi == 0 ) {
			roiRet = "" + (roiVolume) + "";

		} else {
			roiRet += ";" + (roiVolume);
			
		}		
		//roiRet += temp;
				
	}
	
	if (!makeBinary) {
		selectImage( currentImgID );
		run( "Close" );
			
	}

	// Create the returned array
	returnedArray = newArray( roiRet, soiRet ); //Array.print( returnedArray );
	return returnedArray;
	
}

function setAnalysisParameters( logTab ) {
	// This function prompt the user to set the parameters for the analysis.
	//
	// Parameters:
	//			- logTab: insert string that contains tabulations to indent print output in log file

	//
	// /!\ This function uses default var
	//	
	//
	//

	Dialog.create("Analysis Parameters");
	Dialog.addMessage("> Image files selected: " + totalImages + "          > Total series selected: " + totalSeriesOfAllFiles);
	Dialog.addMessage( "" );
	Dialog.addString("> Name of the output directory", outDir);
	Dialog.addChoice( "> CSV result files separators:", newArray( ";", ",", "TAB" ), csvResultSeparators );
	Dialog.addCheckbox( "Save intermediate image files", saveIntermediateFiles );
	Dialog.addMessage("--------------------------------------------------------------------------------------------------");


	// Signal Settings
	Dialog.addMessage("> Signal of Interest (SOI) settings:                     ");
	Dialog.addSlider("Channel number of the Signal of Interest (SOI)", 1, 10, signalCh);
	Dialog.addString("Name of the channel", soiChannelName);
	Dialog.addChoice( "Bleach correction", newArray( "Do Not Use", "Simple Ratio", "Exponential Fit", "Histogram Matching" ), bleachCorrection );
	Dialog.addCheckbox( "Subtract background", subBk);
	Dialog.addNumber("Subtract background Rolling Ball radius", subBkSize);
	Dialog.addMessage("--------------------------------------------------------------------------------------------------");
	
	Dialog.addRadioButtonGroup( "> Filter settings", newArray(  "Do not use Filter", 
																"Use 3D Filter                                        ", 
																"Use 2D Filter" ), 1, 3, filterType );
	Dialog.addChoice("3D filter method", filter3DList, filter3D ); Dialog.addToSameRow(); Dialog.addChoice("2D filter method", filterList, filter2D );
	Dialog.addNumber( "X sigma", Xsigma ); Dialog.addToSameRow(); Dialog.addNumber("Filter radius (px)", filterRadius);
	Dialog.addNumber( "Y sigma", Ysigma ); //Dialog.addToSameRow(); 
	Dialog.addNumber( "Z sigma", Zsigma );
	Dialog.addMessage("--------------------------------------------------------------------------------------------------");
	
	Dialog.addMessage( "> Thresholds settings                     " );
	Dialog.addChoice( "Signal threshold method", thresholdsList, signalThresholdMethod );
	Dialog.addCheckbox( "Apply threshold on all image field (not on each ROI field)", thresholdBeforeROI );
	Dialog.addCheckbox( "Apply individual threshold on each slice", thresholdEachSlice );
	Dialog.addMessage("--------------------------------------------------------------------------------------------------");

	Dialog.addCheckbox( "Force Custom spatial calibration", forceSpatialCalib );
	Dialog.addMessage( "" );
	Dialog.addNumber("X px value in µm:", parseFloat(customX));
	Dialog.addNumber("Y px value in µm:", parseFloat(customY));
	Dialog.addNumber("Z step value in µm:", parseFloat(customZ));
	Dialog.addMessage("(Use this option if you want to change the spatial calibration of all images)");

	Dialog.show();

	// Collect results
	outDir 					= Dialog.getString()	 			; settingWrite( settingFilePath, "outDir", outDir );
	csvResultSeparators		= Dialog.getChoice()				; settingWrite( settingFilePath, "csvResultSeparators", csvResultSeparators ); //saveIntermediateFiles
	saveIntermediateFiles	= Dialog.getCheckbox()				; settingWrite( settingFilePath, "saveIntermediateFiles", saveIntermediateFiles );
	signalCh 				= Dialog.getNumber()	 			; settingWrite( settingFilePath, "signalCh", signalCh );
	soiChannelName 			= Dialog.getString()	 			; settingWrite( settingFilePath, "soiChannelName", soiChannelName );
	bleachCorrection   		= Dialog.getChoice()				; settingWrite( settingFilePath, "bleachCorrection", bleachCorrection );
	subBk 					= Dialog.getCheckbox()	 			; settingWrite( settingFilePath, "subBk", subBk );
	subBkSize 				= parseInt( Dialog.getNumber() )	; settingWrite( settingFilePath, "subBkSize", subBkSize );
	filterType			 	= Dialog.getRadioButton()			; settingWrite( settingFilePath, "filterType", filterType );
	filter3D 				= Dialog.getChoice()	 			; settingWrite( settingFilePath, "filter3D", filter3D );
	filter2D 				= Dialog.getChoice()	 			; settingWrite( settingFilePath, "filter2D", filter2D );
	Xsigma					= parseInt( Dialog.getNumber() )	; settingWrite( settingFilePath, "Xsigma", Xsigma );
	filterRadius			= parseInt( Dialog.getNumber() )	; settingWrite( settingFilePath, "filterRadius", filterRadius );
	Ysigma 					= parseInt( Dialog.getNumber() )	; settingWrite( settingFilePath, "Ysigma", Ysigma );
	Zsigma					= parseInt( Dialog.getNumber() )	; settingWrite( settingFilePath, "Zsigma", Zsigma );
	signalThresholdMethod 	= Dialog.getChoice()	 			; settingWrite( settingFilePath, "signalThresholdMethod", signalThresholdMethod );
	thresholdBeforeROI		= Dialog.getCheckbox()				; settingWrite( settingFilePath, "thresholdBeforeROI", thresholdBeforeROI );
	thresholdEachSlice		= Dialog.getCheckbox()				; settingWrite( settingFilePath, "thresholdEachSlice", thresholdEachSlice );
	forceSpatialCalib		= Dialog.getCheckbox()	 			; settingWrite( settingFilePath, "forceSpatialCalib", forceSpatialCalib );
	customX					= parseFloat (Dialog.getNumber() )	; settingWrite( settingFilePath, "customX", customX );
	customY					= parseFloat (Dialog.getNumber() )	; settingWrite( settingFilePath, "customY", customY );
	customZ					= parseFloat (Dialog.getNumber() )	; settingWrite( settingFilePath, "customZ", customZ );

	tempSubBk = "No"; if ( subBk == 1 ) { tempSubBk = "Yes"; }
	tempFilter = "No"; if ( filterType != "Do not use Filter" ) { tempFilter = "Yes"; }
	tempFilter2 = ""; tempFilter3 = ""; 
	if ( filterType == "Use 2D Filter" ) { 
		tempFilter2 = "2D Filter";
		tempFilter3 = filter2D + "; filter radius: " + filterRadius; 
	
	} else if ( filterType == "Use 3D Filter                                        " ) { 
		tempFilter2 = "3D Filter";
		tempFilter3 = filter3D + "; " + "sigmas: " + Xsigma + "," + Ysigma + "," + Zsigma; 
	
	}
	tempCalib = "No"; if ( forceSpatialCalib == 1 ) { tempCalib = "Yes"; }

	tempThres = "No"; if ( thresholdBeforeROI ) { tempThres = "Yes"; }
	tempThresSlice = "No"; if ( thresholdEachSlice ) { tempThresSlice = "Yes"; }
	

	print(" ");
	print( logTab + "> Analysis Parameters:" );
	print( logTab + "      - Output directory: " + outDir );
	print( logTab + "      - CSV column separator: " + csvResultSeparators );
	print( logTab + "      - Signal Of Interest (SOI) channel number: " + signalCh );	
	print( logTab + "      - SOI channel name: " + soiChannelName );	
	print( logTab + "      - Perform Bleach COrrection: " + bleachCorrection );	
	print( logTab + "      - Use subtract background method: " + tempSubBk );	
	if ( subBk == 1 ) { print( logTab + "           * Rolling ball radius: " + subBkSize + " (px)" ); }
	print( logTab + "      - Use filter: " + tempFilter );
	if ( filterType != "Do not use Filter" ) {
		print( logTab + "           * Filter type: " + tempFilter2 );
		print( logTab + "       	    	* Filter method: " + tempFilter3 );

	}
	print( logTab + "      - SOI Threshold method: " + signalThresholdMethod );
	print( logTab + "      - Apply threshold on all image field: " + tempThres );
	print( logTab + "      - Use custom spatial calibration: " + tempCalib );
	if ( forceSpatialCalib == 1 ) {
		print( logTab + "            * Custom X pixel value: " + customX );
		print( logTab + "            * Custom Y pixel value: " + customY );
		print( logTab + "            * Custom zStep value: " + customZ );

	}
	print( " " ); print( " " );

	filter3D += "..."; filter2D += "...";
	
}


function createModifyROIset( logTab, ROIset, filesPath, listOfSelImages, listOfSelSeries ) {
	// This function parses all selected images and series and allow the user to create multiple ROIs, to reslice the zStack and to add a comment on File/serie.
	//
	// /!\ This function uses exteral global vars describe here:
	//		- analysisFilesDir: a string that point to a directory where the temp analysis files will be created
	//		- totalSeriesOfAllFiles: an int indicating the total nb of series to process
	//		-
	//		-
	//
	// Parameters:
	//				- logTab: insert string that contains tabulations to indent print output in log file
	//				- ROIset: a string containing the name of the ROIs set to modify OR the str "Create a new set of ROIs" to create a new ROIs Set
	//				- filesPath: string that refers to the path of the directory that contains the images files
	//				- listOfSelImages: an array containing the name of the selected image files
	//				- listOfSelSeries: an array containing the selectec series as string. 
	//
	// Returns: nothing

	// Check if roi set exists
	ROISetDIrExists = File.exists( analysisFilesDir + ROIset + File.separator );
	//print( logTab + " // DEV \\ ROIs Set directory exists: " + ROISetDIrExists );

	

	// If user selected "create new roi set" ask tfor the name of the new rois set
	if ( ROIset == "Create a new set of ROIs" || !ROISetDIrExists) {
		print( logTab + "+ Creating a new set of ROIs..." );
		
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		tempsSetName = ""; selectedAnalysisSet = "";
		
		while ( selectedAnalysisSet == "" ) {
			// Create the set of ROIs
			Dialog.create( "Create a set of ROIs" );
			Dialog.addMessage( "The macro allow the user toperationToPerformo create multiple sets of ROIs-reSlice to perform different analysis with the same raw data set.\n\r" +
							   "The ROIs and the STACKs files will be created and saved in the '_AW_Analysis_Files' folder inside a new subfolder." );
			Dialog.addString( "Define the name of the new set", "analysis_" + (year) + (month) + (dayOfMonth) + (hour) + (minute) + (second) ); //Dialog.setInsets(0, 10, 5)
			Dialog.addMessage(" ");
			Dialog.show();

			tempsSetName = Dialog.getString();

			if ( !File.isDirectory( analysisFilesDir + tempsSetName ) ) {
				tempsSetName = replace( tempsSetName, "/", "_" );
				File.makeDirectory( analysisFilesDir + tempsSetName);

				if ( !File.exists( analysisFilesDir + tempsSetName ) ) {
					showMessage( "An error occured when trying to create the directory:\n\r'" + analysisFilesDir + tempsSetName + "'\n\r\n\rTry again with another name." ); 
					
				} else {
					print( logTab + "     - New set of ROIs sucessfully created!" );
					print( logTab + "     - Name of the set: " + tempsSetName );
					print( logTab + "     - Directory: " + analysisFilesDir + tempsSetName );
					selectedAnalysisSet = tempsSetName;
					
				}
				
			} else {
				showMessage("The set of ROIs '" + tempsSetName + "' already exists, try another name.");
				
			}

		}
		
	}

	//currentSerie = 0;
	
	// Parse selected images
	for ( img = 0; img < listOfSelImages.length; img++ ) {
		currentImgName = toLowerCase( listOfSelImages[img] );

		file = filesPath + listOfSelImages[img];
		
		// Get file infos
		fileType = substring( currentImgName, lastIndexOf( currentImgName, "." ) + 1 );
		fileName = File.getNameWithoutExtension( listOfSelImages[img] );
		
		if ( fileType != "merge" ) {
			Ext.setId(file);

		} else {
			Ext.setId( filesPath + settingRead(file, "channel_1", 0) );
			
		}
	
		//fileName = "";

		print( logTab + "+ Processing image " + (img+1) + "/" + listOfSelImages.length );

		// Get nb of series of the file
		currentSelectedSeries = split(listOfSelSeries[img], "*");

		// Parse series
		for ( ser = 0; ser < currentSelectedSeries.length; ser++ ) {
			print( logTab + "     * Processing serie " + (ser+1) + "/" + currentSelectedSeries.length );

			loadROI = false; loadPreviousROIs = true;
			clearROIMan();

			// Open zStack
			print( logTab + "          - Opening zStack..." ); showStatus("Opening zStack...");  selectWindow("ImageJ");

			// Get serie infos
			Ext.setSeries(ser); 
			Ext.getSizeC(sizeC);
			Ext.getSizeZ(sizeZ);
			roiCount = 1;
			print( logTab + "          - Channels: " + sizeC + "; z size: " + sizeZ );

			// Open the file
			if ( sizeZ > 1 ) {
				startSlice = 1;

				// Check if the size of the stack must be changed
				if ( File.exists(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack") ) {
					print(  logTab + "          - Stack file found" );
					sCrop = settingRead(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "series_" + (ser + 1), "1-" + sizeZ);
					
					if (sCrop != -1) {
						startSlice = parseInt( substring( sCrop, 0, indexOf(sCrop, "-") ) );
						endSlice = parseInt( substring( sCrop, indexOf(sCrop, "-") + 1 ));
						
					}

					if ( startSlice < 1 ) { startSlice = 1; }
					//if ( (endSlice > stacksSize) || (endSlice == NaN) ) { endSlice = stacksSize; }

					//endSlice = (stacksSize + startSlice);


				} else {
					startSlice = 1;
					endSlice = sizeZ;
					
				}

				// Open all the sZtack for modifications
				if ( fileType == "lif" ) {
					run("Bio-Formats Importer", "open=[" + file + "] autoscale color_mode=Composite specify_range " +
									 		"view=Hyperstack stack_order=XYCZT series_" + (ser + 1) + " z_begin_" + (ser+1) + "=" + 1 + 
									 		" z_end_" + (ser+1) + "=" + sizeZ + " z_step_" + (ser+1) + "=1 ");

				} else if ( fileType == "merge"  ) {
					openMergeFile( file, 0, 0, 0, 0 );
					

				} else if ( fileType == "ics" || fileType == "tif" || fileType == "tiff"  ) {
					//print("DEV >>>>>>>>>>>> " + file);
					run("Bio-Formats Importer", "open=[" + file + "] autoscale color_mode=Composite specify_range " +
									 		"view=Hyperstack stack_order=XYCZT z_begin=1" + 
									 		" z_end=" + sizeZ + " z_step=1 ");

				
				}
				
				

				print( logTab + "          - zStack succesfully opened!" );

				showStatus("Optimizing image...");
				print( logTab + "          - Optimizing image..." );
				selectWindow("ImageJ");
				
				// Get image calibration
				getVoxelSize(width, height, depth, unit);

				// Arrange the windows
				getLocationAndSize(winX_0, winY_0, winWidth_0, winHeight_0);
				setLocation(winX_0, 25);
				getLocationAndSize(winX_1, winY_1, winWidth_1, winHeight_1);

				// Enhance image
				imageName = getTitle();
				//rename("merge");
				if (enhanceImg) {
					run("Subtract Background...", "rolling=50");
				
				}
				selectWindow("ImageJ");	
				// Apply filter
				//run("Median...", "radius=" + 2 + " stack");  //Skip filtering to save time 				
				selectWindow("ImageJ");
				enhanceBC();

				// Open previous ROIs if exist 
				if ( ( File.exists(analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].zip") || 
					File.exists(analysisFilesDir + fileName + "_[ROIs-s" + (ser+1) + "].roi") ) && File.exists(analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].tif") ) {
					print("   + ROI found for this image, loading ROIs from the 'zip' file...");
					
					// Open files with overlay
					open( analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].tif" );
					rename("zProject");

					// Load previuous ROIs
					if ( File.exists( analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].zip") ) { 
						roiManager("Open", analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].zip");

					} else {
						roiManager("Open", analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].roi");
					
					}
					roiCount = ( roiManager("count") +1 );	
					loadROI = true;
				
				} else {
	
					if ( File.exists(analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].zip") || File.exists( analysisFilesDir + ROIset + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].roi") ) {
						print("   + ROI 'zip' file found but cannot be loaded");
					
					}				
					selectWindow(imageName);

					run("Z Project...", "projection=[Max Intensity]");
					rename("zProject");

				}
				
				zProjectID = getImageID();
				enhanceBC();
				setLocation(winX_1 + winWidth_1, winY_1);

				setTool("polygon");
				// Clear ROI Manager
				if ( !loadROI ) { clearROIMan(); }

				if ( loadROI ) {
					if ( !getBoolean("Previous ROI found and loaded, do you want to add a new ROIs?") ) {
						loadPreviousROIs = false;
						
					}
					
				}

				selectImage(zProjectID);
				enhanceBC();

				if ( loadPreviousROIs ) {		
					while ( true ) {

						selectWindow("zProject");
						run("Select None");
						increaseROINb = false;
						waitForUser("Use a selection tool to draw the " + roiCount + "° ROI and click the 'Ok' button.\n \n \n" +
									"(Hold down 'Shift' key and press 'Ok' button to skip)");

						if ( !isKeyDown("shift") ) {
							increaseROINb = true;

							// Check if selection is empty, i.e. no ROI drawn
							if ( selectionType() == -1 ) {
								// Check on both windows if there is an ROI
								if ( isActive(zProjectID) ) {
									selectWindow(imageName);
											
								} else {
									selectWindow("zProject");
											
								}
								// if not then display a message to ask user to draw an ROI
								if ( selectionType() == -1 ) {							
									while ( selectionType() == -1 ) {
										selectWindow("zProject");
										waitForUser("NO SELECTION found, please use a selection tool to draw the " + roiCount + "° ROI and click the 'Ok' button.\n\r\n\r(draw on the image entitled 'zProject')");
	
									}
											
								}

							}

							if ( !isActive(zProjectID) ) {
								selectWindow("zProject");
								run("Restore Selection");

								selectWindow(imageName);
								run("Select None");
						
							}
							
							selectWindow("zProject");
							roiManager("Add");

							setColor('yellow');
							Overlay.addSelection("yellow", 4);
							getSelectionBounds(x, y, width, height);
	
							setColor("yellow");
							setFont("SansSerif", 54, " antialiased");
							Overlay.drawString(roiCount, x + width/2, y+height/2, 0.0);
							Overlay.show;

						}

						if ( !getBoolean("Draw another ROI?") ) { break; }

						if ( increaseROINb ) { roiCount ++;	}

					}

				}

				// Ask user to crop the zStack
				error = 0; comment = settingRead(analysisFilesDir + ROIset + File.separator + fileName + ".stack", "comment_" + (ser+1), "");
				
				while ( error != -1 ) {
		
					Dialog.createNonBlocking("reCrop the zStack");
					Dialog.addMessage("> Crop of the zStack");
					Dialog.addNumber("First slice", startSlice);
					Dialog.addNumber("Last slice", endSlice);
					Dialog.addMessage("-----------------------------------------------");
					Dialog.addMessage("> Add a comment to this image/serie");
					Dialog.addString("                     Comment", comment );
					Dialog.show();

					startSlice = Dialog.getNumber();
					endSlice = Dialog.getNumber();
					comment = Dialog.getString();

					// Detect errors in .stack files
					if ( startSlice > endSlice ) {
						error = "'start slice > end slice'";
								
					} else if ( startSlice == endSlice ) {
						error = "'start slice = end slice'";

					} else if ( (endSlice - startSlice) < 2 ) {
						error = "'(end slice - start slice) < 2'   ==>   the result file is not a zStack";
								
					} else {
						error = -1;
																	
					}
								
					if ( error != -1) {
						showMessage( "### ERROR ###\n\r\n\r" + "   Please check start and last slices values." + "\n\r   Details: " + error );
								
					}
							
				}

				settingWrite(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "series_" + (ser+1), "" + startSlice + "-" + endSlice);
				settingWrite(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "comment_" + (ser+1), "" + comment);

				// export rois
				if ( File.exists(analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].zip") ) { 
					File.delete( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].zip" ); 

				}
	
				selectWindow("zProject");
				exportAllRois( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (ser+1) + "]" );
				saveAs("Tiff",  analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (ser+1) + "]" + ".tif");
				run("Close All");
						
				// Remove previous .roi file if a .zip file exists
				if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].roi") && File.exists(analysisFilesDir + fileName + "_[ROIs-s" + (ser+1) + "].zip") ) {
					File.delete( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + "_[ROIs-s" + (ser+1) + "].roi");
					
				}
				
			} else {
				// File is not a zStack, file is skipped
				print( logTab + "     * This serie IS NOT A ZSTACK. Skipping the serie." );
				
			}
			
		}

		
		
	}
	
}



function selectFileSeries( logTab, fileListArray, filePath, selectAllSeries, ROISet ) { 
	// Prompt user to select files series to process

	// Parameters:
	//		- logTab: insert string that contains tabulations to indent print output in log file
	//		- fileListArray: an array containing the name of the files to process
	//		- filePath: the path to the directory that contains path
	//		- selectAllSeries: bool
	//
	// Return: 
	//		- an array contaning the series to proceed
	//				Each element of the array correspond to one file (same order as the 

	// Parse images in the array

	listOfSelectedSeries = newArray();
	
	for ( img = 0; img < fileListArray.length; img++ ) {
		seriesCount = 0; 

		// Process only LIF files (that can contain multiple series)
		if ( endsWith( toLowerCase( fileListArray[img] ), ".lif" ) ) { 
			// Prepare file
			file = filePath + fileListArray[img];
			Ext.setId( file );
			Ext.getSeriesCount( seriesCount );		
			
			listOfSeries = newArray();
			// Parse series of the file
			for ( ser = 0; ser < seriesCount; ser++ ) {
				// Get info about the current serie
				Ext.setSeries(ser);
				Ext.getSeriesName(seriesName);
				Ext.getImageCount(imageCount);
				Ext.getSizeX(sizeX);
				Ext.getSizeY(sizeY);
				Ext.getSizeZ(sizeZ);
				Ext.getSizeC(sizeC);

				comment = settingRead(analysisFilesDir + ROISet + File.separator + File.getNameWithoutExtension(fileListArray[img]) + ".stack", "comment_" + (ser+1), "" );
				if ( comment != "" ) { comment = "  ¬  '" + comment + "'"; }
					
				
				listOfSeries = Array.concat(listOfSeries,	"Series " + (ser+1) + ":    " + seriesName + "  ¬  " + imageCount + " images; Dim: " + sizeX + "x" + sizeY + 
															"x" + sizeZ + "x" + sizeC + " (XYZC)" + comment );
												
			}

			if (!selectAllSeries ) {
				tempsSelectedSeries = selectImages( listOfSeries, "Select series", "Select series to process in image file '" + fileListArray[img] + "':", 
													analysisFilesDir + selectedAnalysisSet + File.separator + fileListArray[img], false, "" );
			
				// write series to array
				tempSerieName = tempsSelectedSeries[0] + "*"; if ( tempsSelectedSeries[0] == 1 ) { totalSeriesOfAllFiles++; }
				for (ser = 1; ser < seriesCount - 1; ser++ ) {
					tempSerieName += tempsSelectedSeries[ser] + "*";
					if ( tempsSelectedSeries[ser] == 1 ) { totalSeriesOfAllFiles ++; }
				
				}
				tempSerieName += tempsSelectedSeries[seriesCount - 1]; if ( tempsSelectedSeries[seriesCount - 1] == 1 ) { totalSeriesOfAllFiles++; }
				
				listOfSelectedSeries = Array.concat(listOfSelectedSeries, tempSerieName);
			
			} else {
				totalSeriesOfAllFiles += seriesCount;
				// Fill selected series array
				tempSerieName = "1";
				for ( ser = 1; ser < seriesCount; ser++ ) {
					tempSerieName += "-1";
					
				}
				listOfSelectedSeries = Array.concat(listOfSelectedSeries, tempSerieName);
				
			}


		// Else if file is ND file, then create a value that contains "1" as str
		} else if ( endsWith( toLowerCase( fileListArray[img] ), ".nd" ) || endsWith( toLowerCase( fileListArray[img] ), ".merge" ) 
				    || endsWith( toLowerCase( fileListArray[img] ), ".ics") || endsWith( toLowerCase( fileListArray[img] ), ".ics" )
				    || endsWith( toLowerCase( fileListArray[img] ), ".tif" )) {
			listOfSelectedSeries = Array.concat( listOfSelectedSeries, "1" );
			totalSeriesOfAllFiles ++;
			
		}
		
		
		
	}

	return listOfSelectedSeries;
	

}




function listImgFilesInDir( logTab, dir ) {
	// List the files that are inside the directory 
	// Filter files and list only the ".nd", ".lif", ".ics" and ".tif" images
	//
	// Parameters: 
	//				- logTab: insert string that contains tabulations to indent print output in log file
	//				- dir: the directory where the files are
	//				- 
	//
	// Return:
	//				- an array containing the images files in the directory 
	// 
	// NB: no subdirectory search!

	filesArray = newArray( );

	filesList = getFileList( dir );
	print( logTab + "> Processing files in the directory: '" + dir + "'" );

	// Add ND and LIF files to a new array
	for ( i = 0; i < filesList.length; i++ ) {
		showStatus( "Scanning file '" + filesList[i] + "'" );
		isImg = (endsWith(toLowerCase(filesList[i]), ".lif") || endsWith(toLowerCase(filesList[i]), ".nd") || endsWith( toLowerCase(filesList[i]), ".merge" )
					|| endsWith( toLowerCase(filesList[i]), ".ics") || endsWith( toLowerCase(filesList[i]), ".tif" ));

		if ( isImg ) {
			filesArray = Array.concat( filesArray, filesList[i] );
			
		}
		
	}

	return filesArray;
	
	
}

function promptOperationToPerform( logTabs ) {
	// Ask the user for the operation to perform
	//
	// Parameters: 
	//				- logTab: insert string that contains tabulations to indent print output in log file
	
	showStatus("Define operation to perform...");
	Dialog.create( "Select an operation to perform" );
	Dialog.addHelp(dialog1);
	Dialog.addRadioButtonGroup("> Select an operation to perform:",  newArray("Create/Modify ROIs set", "Perform Analysis", "Export comments"), 3, 1, operationToPerform);
	Dialog.show();

	operationToPerform = Dialog.getRadioButton();
	settingWrite(settingFilePath, "operationToPerform", operationToPerform);



	// Select the folder where the files are
	inDir = getDirectory("Choose directory ");
	analysisFilesDir = inDir + "_AW_Analysis_Files" + File.separator;
	if ( operationToPerform != "Export comments" ) { setROIFiles = getFileList(analysisFilesDir); } // get the files inside the analysis directory

	// Create the "analysis" folder
	if ( !File.exists(analysisFilesDir) ) { 
		File.makeDirectory(analysisFilesDir); 
		print( "> Analysis directory created. " + " (this directory contains the files used for the analysis)" );
	
	} else {
		print( "> Analysis directory already exists. " + " (this directory contains the files used for the analysis)" );
	
	}


	
	// Look for set of ROIS in the analysis folder
	setROIFiles = getFileList(analysisFilesDir); // get the files inside the analysis directory

	if ( operationToPerform == "Perform Analysis" ) {
		setROIsFound = newArray("Do not use ROIs set, performe analysis on whole image field");

	} else if ( operationToPerform == "Export comments" ) {
		setROIsFound = newArray();

	} else  {
		setROIsFound = newArray("Create a new set of ROIs");
	
	}

	print( logTabs + "> Operation to perform: " + operationToPerform );

	
	if ( operationToPerform != "Export comments" ) {
		for ( file = 0; file < setROIFiles.length; file++ ) {
			if ( File.isDirectory( analysisFilesDir + setROIFiles[file] ) ) {
				setROIsFound = Array.concat(setROIsFound, replace(setROIFiles[file], "/", "" ));
		
			}
	
		}

		// Create a dialog to select an ROIs data set and the images and series to perform
		Dialog.create("Define ROIs dataset and Images/Series to perform");

		if ( operationToPerform == "Perform Analysis" ) {
			Dialog.addHelp(dialog2b);
	
		} else {
			Dialog.addHelp(dialog2a);
	
		}

		Dialog.addChoice("> Select an existing set of ROIs or create a new one", setROIsFound, selectedAnalysisSet);
		if ( operationToPerform == "Perform Analysis" ) { Dialog.addMessage("NB: to create new ROIs sets, select the option 'Create/Modify ROIs set' at macro startup"); }
	
		Dialog.addMessage( "----------------------------------------------------------------------------------------" );
		Dialog.addMessage("> Select manually images and series to process:");
		Dialog.addRadioButtonGroup("Do you want to manually select the files to process?", newArray("Yes", "No, process all files"), 1, 2, selectImgs);
		Dialog.addRadioButtonGroup("Do you want to manually select the series to process?", newArray("Yes", "No, process all series"), 1, 2, selectSeries);
		Dialog.addMessage("(if the 'No' button is checked, all the files/series will be processed)");
		if (operationToPerform == "Create/Modify ROIs set") {
			Dialog.addMessage(" ");
			Dialog.addCheckbox("Enhance image (sub BK & meidan filter", enhanceImg);
			
		}
		Dialog.show();

		selectedAnalysisSet = Dialog.getChoice(); settingWrite(settingFilePath, "selectedAnalysisSet", selectedAnalysisSet);
	
		selectImgs = Dialog.getRadioButton(); settingWrite(settingFilePath, "selectImgs", selectImgs);
		selectSeries = Dialog.getRadioButton(); settingWrite(settingFilePath, "selectSeries", selectSeries);
		if (operationToPerform == "Create/Modify ROIs set") {
			enhanceImg = Dialog.getCheckbox();
			
		}

		// Print settings to log file
		print( logTabs + "> Set of ROIs selected: " + selectedAnalysisSet );
		print( logTabs + "> Manually select images: " + selectImgs );
		print( logTabs + "> Manually select series: " + selectSeries );

	} else {
		for ( file = 0; file < setROIFiles.length; file++ ) {
			if ( File.isDirectory( analysisFilesDir + setROIFiles[file] ) ) {
				setROIsFound = Array.concat(setROIsFound, replace(setROIFiles[file], "/", "" ));
		
			}
	
		}

		if ( setROIsFound.length < 1 ) {
			showMessage("No ROIs sets found, please select another directory.");
			exit();
			
		} else {
		
			// Create a dialog to select an ROIs data set and the images and series to perform
			Dialog.create("Select ROIs dataset");
			Dialog.addChoice("> Select the ROIs you want to export the comments", setROIsFound, selectedAnalysisSet);
			Dialog.show();

			selectedAnalysisSet = Dialog.getChoice(); settingWrite(settingFilePath, "selectedAnalysisSet", selectedAnalysisSet);
			selectImgs = 0;
			selectSeries = 0;

			print( logTabs + "> Set of ROIs selected: " + selectedAnalysisSet );

		}
		
	}
	
}



			
// Other functions =============================================================================================

function selectImages( listeOfFiles, title, message, comment, forceFirstSeries, ROISet) {
	nbOfImageFiles = listeOfFiles.length;
	selectedFiles = newArray();
	
	// Divide all files from list into sublists of 15 elements
	if ( nbOfImageFiles > 2 ) {
		nbOfDialogs = Math.ceil(nbOfImageFiles / 20);

	} else {
		nbOfDialogs = 1;
		
	}
	
	// Parse nb of dialogs
	for ( d = 0; d < nbOfDialogs; d++ ) {
		Dialog.create(title + " (" + (d+1) + "/" + nbOfDialogs + ")");
		Dialog.addMessage(message);

		fileStart = (20 * d);
		filesCount = 20 * (d+1);
		if ( filesCount > nbOfImageFiles ) { filesCount = nbOfImageFiles; }


		for (f = fileStart; f < filesCount; f ++) { // fileName + ".stack"
			comment2 = "";

			// Get file comment
			comment = ""; 
			if ( endsWith( toLowerCase( listeOfFiles[f] ), ".nd") || endsWith( toLowerCase( listeOfFiles[f] ), ".ics") || endsWith( toLowerCase( listeOfFiles[f] ), ".tif") ||
				endsWith( toLowerCase( listeOfFiles[f] ), ".lif") ) {
				comment = settingRead(analysisFilesDir + ROISet + File.separator + File.getNameWithoutExtension(listeOfFiles[f]) + ".stack", "comment_" + 1, "" );
				if ( comment != "" ) { comment = "  ¬  '" + comment + "'"; }
				
			}
			
			if ( forceFirstSeries ) { 
				s = 0; 
				comment2 = "" + comment + listeOfFiles[f];
				
			} else {
				s = f;
				
			}
			
			if ( endsWith( comment2, ".nd" ) ) {
				comment2 = replace(comment2, ".nd", ".stack");

			} else if ( endsWith( comment2, ".lif" ) ) {
				comment2 = replace(comment2, ".lif", ".stack");

			} else if ( endsWith( comment2, ".ics" ) ) {
				comment2 = replace(comment2, ".ics", ".stack");
			
			} else if ( endsWith( comment2, ".tif" ) ) {
				comment2 = replace(comment2, ".tif", ".stack");
				
			} else {
				comment2 = replace(comment2, ".merge", ".stack");
				
			}

			//print( ">>>DEV: file: " + comment2 +  "\n\r    Comm: " + settingRead(comment2, "comment_" + (s+1) , "" ) );
			
			
			if ( !endsWith(listeOfFiles[f], File.separator) ) { // filtrer les nd, lif et merge
				theComment = "";
				if ( comment2 != "" ) { 
					read = settingRead(comment2, "comment_" + (s+1) , "" );
					if ( read != "" ) {
						theComment = " | Comment: " + read; 

					}
				
				}
				
				Dialog.addCheckbox(listeOfFiles[f] + theComment + comment, true);
		
			}
	
		}
		Dialog.addMessage("");
		Dialog.addMessage("Files displayed: " + filesCount + "/" + nbOfImageFiles);
		
		Dialog.show();

		// Collect data    
		for (f = fileStart; f < filesCount; f ++) {
			selectedFiles = Array.concat( selectedFiles, Dialog.getCheckbox() );
			
		}

	}

	return selectedFiles;

}




function findSmallerStack( listOfFiles, excludedFiles ) {
	// Find smaller stack
	selectWindow("ImageJ");
	currentImg = 0;
	theArray = newArray();
	error = -1;

	stacksSize = 1000000; nameOfSmallerStack = "";

	// Switch between files array and images array
	if ( !excludedFiles ) {
		theArray = listOfFiles;
		
	} else {
		theArray = listOfImages;
		
	}

	for (i = 0; i < theArray.length; i++) {
	
		roi = false;
		seriesFileType = ( endsWith(toLowerCase(theArray[i]), ".lif") || endsWith(toLowerCase(theArray[i]), ".nd") 
							|| endsWith(toLowerCase(theArray[i]), ".ics" || endsWith(toLowerCase(theArray[i]), ".tif") ); // add MERGE file suport

		showStatus("Scan: " + theArray[i] );
	
		// for all lif or nd files 
		if ( seriesFileType  ) {
			if ( !excludedFiles ) { listOfImages = Array.concat(listOfImages, theArray[i]); }
		
			seriesCount = 0;
			file = inDir + theArray[i];

			if ( seriesFileType ) {
				Ext.setId(file);
				Ext.getSeriesCount(seriesCount);	// get number of series

			} else {
				seriesCount = 1;
			
			}

			startSlice = 0; endSlice = 0;

			if ( excludedFiles ) { currentSelectedSeries = split(listOfSelectedSeries[i], "*"); }
		

			// open all series
			for ( s = 0; s < seriesCount; s++ ) {
				if ( seriesFileType ) { 
					Ext.setSeries(s); 
					Ext.getSizeZ(sizeZ);
					Ext.getSeriesName(seriesName);
				
				}

				//if ( excludedFiles ) { print(">>DEV>> current series selected (findSmaStack): " + currentSelectedSeries[s]); }

				
				fileName = File.getNameWithoutExtension(theArray[i]);

				if (endsWith(toLowerCase(theArray[i]), ".lif")) {
					fileName = substring(theArray[i],0,indexOf(theArray[i],".lif")); // get file name without extension
					
				} else if (endsWith(toLowerCase(theArray[i]), ".nd")) {
					wavesName = ndInfo(file);
					fileName = substring(theArray[i],0,indexOf(theArray[i],".nd")); // get file name without extension
					nd = true;
				} else if (endsWith(toLowerCase(theArray[i]), ".ics")) {
					fileName = substring(theArray[i],0,indexOf(theArray[i],".ics")); // get file name without extension
				
				} else if (endsWith(toLowerCase(theArray[i]), ".tif")) {
					fileName = substring(theArray[i],0,indexOf(theArray[i],".tif")); // get file name without extension
					
				} else {
					fileName = substring(theArray[i],0,indexOf(theArray[i],".merge"));
							
				}

				if ( sizeZ > 1 ) { 

					// Check if the size of stack must be modified
					if ( File.exists( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack") ) {
						sCrop = settingRead( analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack", "series_" + (s + 1), "1-" + sizeZ);
						if (sCrop != -1) {
							startSlice = parseInt( substring( sCrop, 0, indexOf(sCrop, "-") ));
							endSlice = parseInt( substring( sCrop, indexOf(sCrop, "-") + 1 ));

							if ( startSlice < 0 ) { startSlice = 1; }
							if ( (endSlice > sizeZ) || (endSlice == NaN) ) { endSlice = sizeZ; }
							
							// Detect errors in .stack files
							if ( startSlice > endSlice ) {
								error = "'start slice > end slice'";
								
							} else if ( startSlice == endSlice ) {
								error = "'start slice = end slice'";

							} else if ( (endSlice - startSlice) < 2 ) {
								error = "'(end slice - start slice) < 2'   ==>   the result file is not a zStack";
								
							}								
								
							if ( error != -1) {
								print("\n\r\n\r");
								print("### ERROR ###");
								print("An error occured while reading the STACK file '" + analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack" + "'");
								print("   in series No: " + (s+1) + "\n\r   Details: " + error);

								exit( "### ERROR ###\n\r\n\r" + "An error occured while reading the STACK file '" + analysisFilesDir + selectedAnalysisSet + File.separator + fileName + ".stack" + "'\n\r" + "   in series No: " + (s+1) + "\n\r   Details: " + error );
								
							}

							sizeZ = (endSlice - startSlice);
						
						} else {
							endSlice = sizeZ;
							startSlice = 1;
							
						}

					} else {
						endSlice = sizeZ;
						startSlice = 1;
						
					}

					if ( excludedFiles ) { 
						if ( parseInt( listOfSelectedImages[i] ) == 1 ) {
							if ( parseInt( currentSelectedSeries[s] ) == 1 ) { 
								if ( ( sizeZ < stacksSize ) ) {
									stacksSize = (endSlice - startSlice) + 1;
									nameOfSmallerStack = theArray[i] + "  (series " + (s+1) + ", " + seriesName +")";

								}
								
							}
							
						}
						
					} else {
						if ( ( sizeZ < stacksSize ) ) {
							stacksSize = ( endSlice - startSlice ) + 1;
							nameOfSmallerStack = theArray[i] + "  (series " + (s+1) + ")";

						}
						
					}
				
				}

			}

		}

		currentImg++;

	}
	return stacksSize;

} 

function exportAllRois( filePath ) { 
	totalROI = roiManager("count"); 
	selection = newArray(0);
	
	for ( roi = 1; roi < totalROI; roi++ ) { selection = Array.concat(selection, roi); }

	roiManager("Select", selection);
	roiManager("Save", filePath + ".zip");
	
}

function clearROIMan() {
	/*
	if (isOpen("ROI Manager")) {
    	selectWindow("ROI Manager");
    	
  	} else {
  		run("ROI Manager...");
  		
  	}
  	*/

	totalROI = roiManager("count");  
	
  	for ( roi = 0; roi < totalROI; roi++ ) {	
		roiManager("Select", 0 );
		roiManager("Delete");

	}
	
}


function enhanceBC() {

	Stack.getDimensions(width, height, channels, slices, frames)

	if (is("composite")) {
		for (ch = 1; ch <= channels; ch++) {
			if ( slices > 1 ) {
				Stack.setPosition(ch, slices/2, 1);
				run("Enhance Contrast", "saturated=0.35");
				Stack.setSlice(1);
			} else {
				run("Enhance Contrast", "saturated=0.35");
				
			}
			
		}
		
	} else {
		if ( slices > 1 ) {
			Stack.setPosition(0, slices/2, 1);
			run("Enhance Contrast", "saturated=0.35");
			Stack.setSlice(1);

		} else {
			run("Enhance Contrast", "saturated=0.35");
			
		}
		
	}

}

// Settings functions
function settingWrite(filePath, parameterName, parameterValue) {
	// Write a setting file to save macro parameters
	// v.1.0
	// by Augustin Walter

	heading = ""; // heading for softs
	parameterItemExists = false; newFileCOntent = "";

	if ( !File.exists(filePath) ) {

		File.saveString(heading + "\n", filePath);
		
	}


	fileContent = File.openAsString(filePath);
	fileContent = split(fileContent, "\n");

	for (i = 0; i < lengthOf(fileContent); i++) {

		indexOfEqual = indexOf(fileContent[i], "=");
		splitString = split(fileContent[i], "=");
			
		if (indexOfEqual != -1) {
	
			if (splitString[0] == parameterName) {

				if ( lengthOf(splitString) == 1 ) { splitString = newArray(splitString[0], ""); }
				fileContent[i] = replace(fileContent[i], splitString[0] + "=" + splitString[1], splitString[0] + "=" + parameterValue);
				parameterItemExists = true;
					
			}
				
		}
			
	}
	newFileCOntent += fileContent[0];
	for (i = 1; i < lengthOf(fileContent); i++) {

		newFileCOntent = newFileCOntent + "\n" + fileContent[i];
		
	}

	if (parameterItemExists == false) {
		newFileCOntent += "\n" + parameterName + "=" + parameterValue;
		
	}
	
	//File.delete(filePath);
	File.saveString(newFileCOntent, filePath);
	
}

function settingRead(filePath, parameterName, defaultValue) {
	// Read a setting file to load macro parameters
	// v.1.0
	// by Augustin Walter
		
	if ( File.exists(filePath) ) {

		fileContent = File.openAsString(filePath);
		fileContent = split(fileContent, "\n");

		for (i = 0; i < lengthOf(fileContent); i++) {

			indexOfEqual = indexOf(fileContent[i], "=");
			splitString = split(fileContent[i], "=");
			
			if (indexOfEqual != -1) {

				if (splitString[0] == parameterName) {

					if ( lengthOf(splitString) == 1 ) { splitString = newArray(splitString[0], ""); }
					return splitString[1];
					
				}
				
			}
			
		}

		return defaultValue;
		
	} else {

		return defaultValue;
		
	}

}

function openMergeFile( pathToTheFile, sliceStart, sliceEnd, channelStart, channelCount ) {
	// This function opens files '.merge"
	// Parameters :
	//				- pathToTheFile: the path to the ".merge" file
	//				- sliceStart: the index of the first slice of the z-stack
	//				- sliceEnd: the number of slice to open (from the first slice)
	//				- channelStart: the index of the first channel to open
	//				- channelCount: thenumber of channel to open
	//   NB: for the 4 previous parameters, set value to 0,0 if you want to open all the stack/channels
	// Returns:
	//			- (0): the file is not an ".merge" file type
	//			- (-1): channelStart or channelCount exceed the real nb of channels
	//			- (-2): error in channels name or channel(s) file(s) not found
	//			- (1): succes!
	//
	// Important: if you open more than one channel, a merge will be created!
	
	nbOfChannels = 0; nbOfSlices = 0; channelsAreNotSplitted = false;
	chCommandID = newArray("c1", "c2", "c3", "c4", "c5", "c6", "c7");

	print("\n\r*** Function 'openMergeFile' by A. Walter ***");

	parentDir = File.getParent(pathToTheFile);

	if ( !endsWith(pathToTheFile, ".merge") ) { 
		return 0; 
	
	} else {

		nbOfChannels = parseInt( settingRead(pathToTheFile, "channels", 1) );
		
		
		tempName = settingRead(pathToTheFile, "channel_1", "NO NAME");

		// Check abnormalities in function parameters
		if ( ( channelStart > nbOfChannels ) || ( (channelStart + channelCount -1) > nbOfChannels ) ) { return -1; }
		
		chNames = newArray( tempName );

		for (i = 2; i <= nbOfChannels; i++) {
			tempName = settingRead(pathToTheFile, "channel_" + (i), "NO NAME");
			chNames = Array.concat( chNames, tempName );
		
		}

		//Array.print(chNames);

		print("   - Nb of channels: " + nbOfChannels);
		print("   - Channels names:");

		oldName = chNames[0]; tempName = 0;
		for (i = 1; i < chNames.length; i++) {
			if ( chNames[i] == oldName ) {
				tempName++;
				
			}
			oldName = chNames[i];
		
		}

		if ( tempName == (nbOfChannels - 1) ) {
			channelsAreNotSplitted = true;
			
		} else if ( tempName != 0 ) {
			return -2;
			
		}

		nbOfSlices = settingRead(pathToTheFile, "slices", 0);

		firstSlice = 0; lastSlice = 0;

		if ( nbOfSlices != 0 ) {
			firstSlice = parseInt( substring( nbOfSlices, 0, indexOf(nbOfSlices, "-") ) );
			lastSlice = parseInt( substring( nbOfSlices, indexOf(nbOfSlices, "-") + 1 ) );

			if ( firstSlice < sliceStart ) { firstSlice = sliceStart; }
			if ( lastSlice > sliceEnd ) { lastSlice =  sliceEnd; }
			
			openParameters = " z_begin=" + firstSlice + " z_end=" + lastSlice + " z-step=1";

			print("    - Opening image from slide " + firstSlice + " to slide " + lastSlice);
		
		} else {
			if ( sliceEnd != 0 && sliceStart != 0) {
				openParameters = " z_begin=" + sliceStart + " z_end=" + ( sliceEnd ) + " z-step=1";

			} else {
				openParameters = "";
				
			}
			
		}
		print(openParameters);

		mergeCommand = "";

		// Open files with bioformat plugin
		if ( (channelStart + channelCount) == 0 ) { 
			firstCh = 0; lastCh = nbOfChannels;
			
		} else {
			firstCh = channelStart; lastCh = ( channelStart + channelCount);
			
		}

		print( "   - Opening channels " + (firstCh +1 ) + " to " + (lastCh -1) );

		if ( channelsAreNotSplitted ) {
			colorMode = "Default";
			if ( nbOfChannels > 1 ) {
				colorMode = "Composite";
			}
			print("colormode= " + colorMode);
			
			// Set channel range
			openParameters += " c_begin=" + (firstCh + 1) + " c_end=" + (lastCh) + " c=step=1";	
			
			tempName = parentDir + File.separator + chNames[0];
			print("   - Opening img: " + tempName);
			run("Bio-Formats Importer", "open=[&tempName] autoscale color_mode=&colorMode specify_range view=Hyperstack stack_order=XYCZT " + openParameters);
				
		} else {
			ch = 0;
			for ( i = firstCh; i < lastCh; i++ ) {
				print( "   - Channel " + (i+1) );
				tempName = parentDir + File.separator + chNames[i];
				print("   - Opening img: " + tempName);
				run("Bio-Formats Importer", "open=[&tempName] autoscale color_mode=Default specify_range split_channels view=Hyperstack stack_order=XYCZT " + openParameters);
				tempName = getTitle();

				mergeCommand += chCommandID[ch] + "=[" + tempName + "] ";
				ch++;

			}

			if ( (lastCh - firstCh) > 1 ) {
				print("   - " + mergeCommand + " create");
				run("Merge Channels...", mergeCommand + "create");

			}

		}

		return 1;

	}
		
}


function returnTime( timeInMs ) {
	// This function returns the time in the most appropriate unit.

	if ( timeInMs < 1000 ) {
		return  "" + (timeInMs) + " ms";
		
	} else {
		timeInMs = round(timeInMs / 1000);
		
	}

	if ( timeInMs < 60 ) {
		return "" + (timeInMs) + "s"; // return time in seconds
		
	} else if ( (timeInMs > 59) && (timeInMs < 3600) ) {
		 return "" + ( floor( timeInMs / 60) % 60) + "m:" + ( timeInMs % 60 ) + "s"; // return time in minutes
		 
	} else if ( timeInMs > 3599 ) {
		return "" + floor(timeInMs / 3600) + "h:" + ( floor( timeInMs / 60) % 60) + "m:" + ( timeInMs % 60 ) + "s"; // return time in hours
		
	}
	
}


// ++++++++ HELP vars ==========================================================

var dialog1 = 	'<html>' +
				'<h2><span style="color: #4890ff;"><strong><span style="text-decoration: ;">About the Macro' + "'zStack Fluorescence Quantification'" + ':</span></strong></span></h2>' +
				'<p><span style="color: #102e3f;"><span style="caret-color: #4890ff;">version ' + ver + '<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">author: Augustin Walter<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">mail: <a href="mailto:augustin.walter@outlook.fr">augustin.walter@outlook.fr<br /></a></span></span><br /><span style="text-decoration: underline; color: #102e3f;">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;<br /><br /></span></p>' +
				'<p><span style="color: #000000;">The macro uses <strong>sets of Region Of Interest</strong> (ROIs Sets) to perform the analysis. The sets are defined by the user prior to the analysis. Each set can contains as many ROIs as the user wishes and during the analysis, the fluorescent signal will be measured in each ROIs of each sets. The ROIs set also allow the user to recrop zStacks by defining a new first and last slice index.</span></p>' +
				'<p><span style="color: #000000;">In the current dialog box, the 3 following options are proposed:<br /></span></p>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #000000;"><em><strong>Create/Modify ROIs set</strong></em>: create a new roi set or modify an existing one (i.e. define ROIs for each image of the analysis),</span></li>' +
				'<li><span style="color: #000000;"><em><strong>Perform Analysis</strong></em>: do the analysis using a previously created ROIs set or without using ROIs set,</span></li>' +
				'<li>The<strong> last option</strong> allow the user to directly run the analysis after defining/modifying an ROIs set.</li>' +
				'</ul>' +
				'<p>&nbsp;</p>' +
				'<p>NB: to perform the best analysis, all the zStacks must have the same number of slices, that is why it is better to define data set for all images of the experiment and then relaunch the macro to perform the analysis especially if images are in different directories.&nbsp;</p>';

var dialog2a = 	'<html>' +
				'<h2><span style="color: #4890ff;"><strong><span style="text-decoration: ;">About the Macro' + "'zStack Fluorescence Quantification'" + ':</span></strong></span></h2>' +
				'<p><span style="color: #102e3f;"><span style="caret-color: #4890ff;">version ' + ver + '<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">author: Augustin Walter<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">mail: <a href="mailto:augustin.walter@outlook.fr">augustin.walter@outlook.fr<br /></a></span></span><br /><span style="text-decoration: underline; color: #102e3f;">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;<br /><br /></span></p>' +
				'<h3><span style="text-decoration: underline; color: #102e3f;">Select ROIs set and Files Series:</span></h3>' +
				'<h4><span style="color: #102e3f;">Select set of ROIs or create a new one:</span></h4>' +
				'<p><span style="color: #102e3f;">The first option lists the previously created ROIs sets. Select <strong>one of these sets</strong> to modify the ROIs and the z-Reslice of images. To create a new ROIs set, select ' + "'<em><strong>Create a new set of ROIs</strong></em>'" + '.</span></p>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Manually select files to process:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Yes:</strong></em> select each image file to process inside the selected directory,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>No, process all files</strong></em>: process all files in the selected directory.</span></li>' +
				'</ul>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Manually select series to process:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Yes:</strong></em> some image files contains multiple images called '+ "'series'" + ', select this option to list each series of each selected files and select series to process,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>No,</strong></em> process all series: process all series of the selected image files.</span></li>' +
				'</ul>';

var dialog2b = '<html>' +
				'<h2><span style="color: #4890ff;"><strong><span style="text-decoration: ;">About the Macro ' + "'zStack Fluorescence Quantification'" + ':</span></strong></span></h2>' +
				'<p><span style="color: #102e3f;"><span style="caret-color: #4890ff;">version ' + ver + '<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">author: Augustin Walter<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">mail: <a href="mailto:augustin.walter@outlook.fr">augustin.walter@outlook.fr<br /></a></span></span><br /><span style="text-decoration: underline; color: #102e3f;">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;<br /><br /></span></p>' +
				'<h3><span style="text-decoration: underline; color: #102e3f;">Select ROIs set and Files Series:</span></h3>' +
				'<h4><span style="color: #102e3f;">Select set of ROIs or create a new one:</span></h4>' +
				'<p><span style="color: #102e3f;">The first option lists the previously created ROIs sets. Select <strong>one of these sets</strong> to perform the analysis using this set of ROIs. Select the option ' +"'<em><strong>Do not use ROIs set...</strong></em>' " + ' to perform the analysis without using set of ROIs (i.e. perform the analysis on entires images). Before using this option, be sure that <span style="text-decoration: underline;"><strong>all the zStacks have the same number of slices</strong></span>.</span></p>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Manually select files to process:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Yes:</strong></em> select each image file to process inside the selected directory,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>No, process all files</strong></em>: process all files in the selected directory.</span></li>' +
				'</ul>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Manually select series to process:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Yes:</strong></em> some image files contains multiple images called ' + "'series'" + ', select this option to list each series of each selected files and select series to process,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>No,</strong></em> process all series: process all series of the selected image files.</span></li>' +
				'</ul>';

var dialog3a = '<html>';

var dialog3b = '<html>' +
				'<h2><span style="color: #4890ff;"><strong><span style="text-decoration: underline;">About the Macro ' + "'zStack Fluorescence Quantification'" + ':</span></strong></span></h2>' +
				'<p><span style="color: #102e3f;"><span style="caret-color: #4890ff;">version ' + ver + '<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">author: Augustin Walter<br /></span></span><span style="color: #102e3f;"><span style="caret-color: #4890ff;">mail: <a href="mailto:augustin.walter@outlook.fr">augustin.walter@outlook.fr<br /></a></span></span><br /><span style="text-decoration: underline; color: #102e3f;">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;<br /><br /></span></p>' +
				'<h3><span style="text-decoration: underline; color: #102e3f;">General Settings:</span></h3>' +
				'<h4><span style="color: #102e3f;">Name of the output directory:</span></h4>' +
				'<p><span style="color: #102e3f;">The result files and the log are saved in the result directory. This directory is created inside the directory that contains image files. The name of the result directory can be specified in the text field.</span></p>' +
				'<p>&nbsp;</p>' +
				'<h4><span style="color: #102e3f;">Spatial Calibration:</span></h4>' +
				'<ul style="list-style-type: circle;">' +
				'<li><span style="color: #102e3f;"><em><strong>Use images spatial calibration</strong></em>: use the default spatial calibration of each image to perform the analysis,</span></li>' +
				'<li><span style="color: #102e3f;"><em><strong>Force Custom spatial calibration</strong></em>: specify a global spatial calibration to use in the analysis. <strong>/‼\</strong> The spatial calibration is applyed to all images.<br /></span><span style="color: #102e3f;">The value of 1 pixel in &micro;m along the X and Y axis must be specified in the two text fields.</span></li>' +
				'</ul>';