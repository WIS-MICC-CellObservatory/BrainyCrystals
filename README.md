# Quantification of Brainy Crystals Domains from SEM or AFM images 

## Overview

Measure shape features of brainy crystals from high resolution EM images, using ilastik boundary-based segmentation with multicut (with optional manual correction) or manualsegmentation.
Measuring is limited to selected Regions-of-interest 


Software package: Fiji (ImageJ), Ilastik

Workflow language: ImageJ macro

<p align="center">
<img src="https://github.com/WIS-MICC-CellObservatory/BrainyCrystals/blob/main/PNG/G3New32.png" width="400" title="Original image">
<img src="https://github.com/WIS-MICC-CellObservatory/BrainyCrystals/blob/main/PNG/G3New32_Overlay_Manual.png" width="400" title="Overlay of domain borders after manual correction"> <br/> <br/>
<img src="https://github.com/WIS-MICC-CellObservatory/BrainyCrystals/blob/main/PNG/G3New32_Area_Flatten_Manual.png" width="400" title="Domains colored by area value">
<img src="https://github.com/WIS-MICC-CellObservatory/BrainyCrystals/blob/main/PNG/G3New32_Solidity_Flatten_Manual.png" width="400" title="Domains colored by solidity value"> 
	<br/> <br/> </p>

NOTE: Before running the macro make sure to: 
1. Scale and Crop images eg using ScaleAndCropImages.ijm macro 
2. If you are using EM images - Run ilastik segmentation either using RunIlastikHeadless.bat (or through batch using ilastik GUI)
   Results are expected to be in FN_Multicut Segmentation.h5 files
both are available in the [Utils](https://github.com/WIS-MICC-CellObservatory/Utils) repository
  
## Workflow

1. Read label image produced using ilastik boundary-based segmentation 
2. Read ROIs for measurements file, or prompt the user to select them (*FN_MeasureAreaRois.zip*)
3. Convert labels within Rois to RoiManager and save in *FN_DomainRoiSet.zip*
4. Measure [shape descriptors](https://imagej.nih.gov/ij/docs/guide/146-30.html#toc-Subsection-30.7) for the Domain Rois
5. write summary line 
6. save quality control images with overlay of the Domain Segments used for measurement an the Measure Areas, overlayed on the original image
7. Add Mean/Std/Min/Max lines for the summary table

## Usage
1. Select Measure Rois: 
	- Drag and drop *QuantifyBrainyCrystalsDomains.ijm* to Fiji, click Run
	- Set *runMode* to be *SelectMeasureROis* 
	- Set *processMode* to *singleFile* or *wholeFolder*
	  select a file to process, if *wholeFolder* is selected: all the files in the folder of the selected file are processed
	- uncheck *batchModeFlag*, to allow drawing Rois
 		
2. Quantify Crystal Domains
	- Set *runMode* to be *Segment* 
	- Set *processMode* to *singleFile* or *wholeFolder*
	- select the proper *imageType* (EM or AFM)
	  select a file to process, if *wholeFolder* is selected: all the files in the folder of the selected file are processed
	- for AFM images there are two possible segmentation modes controled by *segModeForAFM*: 
	  + Threshold based, which by default let you set the threshold for each image, and cut the objects using binary watershed  
	  + Morphological Segmentation: which is based on applying Tubeness filter followed by Morphological Segmentation. 
	    Both have advanced parameters that can be controled by setting parameters at the begining of the macro 
	- If *batchModeFlag* is selected (recomended) the macro will run faster and not dispalyed temporary images
 	
3. Manual correction
	- Careful inspection of results: you may find it usefull to use one or both of the following methods: 
		+ Open the original image in Fiji, drag and drop the *FN_DomainRoiSet.zip *file into Fiji main window, and then from the RoiManager flip between Show and Hide 
		+ Open the original image and the overlay image, Use Analyze=>Tools=>Synchronize Windows 
	- ... Manually correct Rois ... 
	- Save as *FN_DomainRoiSet_Manual.zip*
	- Set *runMode* to *Update* 
	- Set *processMode* to *singleFile* or *wholeFolder*
	  select a file to process, if wholeFolder is selected: all the files in the folder of the selected file are processed

NOTE: It is very important to inspect All quality control images to verify that segmentation is correct 

  	
## Output

For each input image FN, the following output files are saved in ResultsSubFolder under the input folder
- FN_OrigOverlay.tif   - the original image with overlay of the segmented Domains in DomainColor
- FN_DomainResults.xls - the detailed measurements for each skeleton segment in the image  
- FN_DomainRoiSet.zip  - the Crystal Domain segments used for measurements
 
Overlay colors can be controled by *DomainColor* and *MeasureAreaColor*

- Summary.xls  		 - Table with one line for each input image files with average values of Mean and Median LocTchikness
- AllDetailedTable.xls - accumulate all per-file results
- QuantifyBrainyCrystalsDomains.txt - Parameters used during the latest run
  
## Dependencies
[Fiji](https://imagej.net/Citing) with ImageJ version > 1.53e (Check Help=>About ImageJ, and if needed use Help=>Update ImageJ...
This macro requires the following Update sites to be activate through Help=>Update=>Manage Update site
- [CLIJ2] https://github.com/clij/clij2)
- [IJPB](https://imagej.net/MorphoLibJ)
- [Ilastik Fiji Plugin](https://www.ilastik.org/about.html) 
- "SCF MPI CBG"  


##  Manual Correction
The above automatic process segment correctly most of the domains. 
Further manual correction is supported by switching from Segment Mode to Update Mode.   
In Update mode the macro skips the segmentation steps 1-3 above, instead it gets the segmented ROIS from a file, and calculate their updated measurements. 
The ROIs are read either from manually corrected file (*FN_DomainRoiSet_Manual.zip* if exist) or otherwise from the original file (*FN_DomainRoiSet.zip*)

### To start manual correction: 
- Open the original image (FN)
- make sure there is no RoiManager open
- drag-and-drop the *FN_DomainRoiSet.zip* into Fiji main window 
- in RoiManager: make sure that "Show All" is selected. Ususaly it is more conveinient to unselect Labels 
  
### Select A ROI
- You can select a ROI from the ROIManager or with long click inside a crypt to select its outer ROI (with the Hand-Tool selected in Fiji main window), 
  this will highlight the (outer) ROI in the RoiManager, the matching inner Roi is just above it
   
### Delete falsely detected objects
- select a ROI
- click "Delete" to delete a ROI. 
  
### Fix segmentation error 
- select a ROI
- you can update it eg by using the brush tool (deselecting Show All may be more convnient) 
- Hold the shift key down and it will be added to the existing selection. Hold down the alt key and it will be subracted from the existing selection
- click "Update"
  
- otherwise you can delete the ROI and draw another one instead 

### Merge adjacent Rois

From the Roi Manger
- Highlight the 2 adjucent Rois 
- Select More=>OR
- Click Update , the first Roi will be updated to the combined object
- Delete the second Roi
  
### Add non-detected object
- You can draw a ROI using one of the drawing tools 
- click 't' from the keyboard or "Add" from RoiManger to add it to the RoiManager 
  
### Save ROIs
When done with all corrections make sure to 
- from the RoiManager, click "Deselect" 
- from the RoiManager, click "More" and then "Save" , save the updated file into a file named as the original Roi file with suffix "_Manual":  
  "FN_DomainRoiSet_Manual.zip", using correct file name is crucial
    
### Run in Update Mode
- when done with correction run the macro again, and change "RunMode" to be "Update" (instead of "Segment")
 
## Notes Regarding Ilastik Classifier
- If your data include images with different contrast, make sure to include  representative images of all conditions When training the classifier
- It is assumed that all images have the same pixel size, identical to that used for training (here it is 0.416 um/pixel). It is not checked however. 
  up to 20% (PixelSizeCheckFactor) different from the pixel size used for training the Ilastik classifier (PixelSizeUsedForIlastik)
  
