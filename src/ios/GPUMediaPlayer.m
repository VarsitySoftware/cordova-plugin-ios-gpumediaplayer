//
//  GPUMediaPlayer.m
//
//  Created by John Weaver on 10/12/2016 
//
//

#import "GPUMediaPlayer.h"
#import <Accounts/Accounts.h>

#import <GPUImage/GPUImageMovieWriter.h>
#import <GPUImage/GPUImageFilter.h>
#import <GPUImage/GPUImageColorConversion.h>

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>

#import <Photos/Photos.h>  

@implementation GPUMediaPlayer  
@synthesize callbackId;

- (void) start:(CDVInvokedUrlCommand *)command {
    
	///////////////////////////////////////// 
	// SET VARS
	/////////////////////////////////////////

	self.callbackId = command.callbackId;

    NSDictionary *options = [command.arguments objectAtIndex: 0];
  
	NSString * strMediaURL = [options objectForKey:@"mediaURL"];
	int intOrientation = [[options objectForKey:@"mediaOrientation"] integerValue];
	int intMediaType = [[options objectForKey:@"mediaType"] integerValue];

	int intFramesPerSecond = [[options objectForKey:@"framesPerSecond"] integerValue];

	int intMediaPosX = [[options objectForKey:@"mediaPosX"] integerValue];
    int intMediaPosY = [[options objectForKey:@"mediaPosY"] integerValue];
    int intMediaWidth = [[options objectForKey:@"mediaWidth"] integerValue];
    int intMediaHeight = [[options objectForKey:@"mediaHeight"] integerValue];

	int intPlayerPosX = [[options objectForKey:@"playerPosX"] integerValue];
    int intPlayerPosY = [[options objectForKey:@"playerPosY"] integerValue];
    int intPlayerWidth = [[options objectForKey:@"playerWidth"] integerValue];
    int intPlayerHeight = [[options objectForKey:@"playerHeight"] integerValue];

	int intFrameEnabled = [[options objectForKey:@"frameEnabled"] integerValue];
	NSString * strFrameShapeURL = [options objectForKey:@"frameShapeURL"];
	NSString * strFrameThemeURL = [options objectForKey:@"frameThemeURL"];

	int intOverlayEnabled = [[options objectForKey:@"overlayEnabled"] integerValue];
	NSString * strOverlayURL = [options objectForKey:@"overlayURL"];

	int intCaptionEnabled = [[options objectForKey:@"captionEnabled"] integerValue];
	NSString * strCaptionText= [options objectForKey:@"captionText"];
	int intCaptionFontSize = [[options objectForKey:@"captionFontSize"] integerValue];

	NSURL* mediaRemoteURL = [NSURL URLWithString:strMediaURL];   
	
	NSString * strMediaFileExtension;
	NSError* error = nil;

	self.jsonResults = [ [NSMutableDictionary alloc]
        initWithObjectsAndKeys :
        nil, @"duration",
        nil, @"currentTime",                             
        nil
    ]; 

	/////////////////////////////////////////
	// SET ROOT VIEW
	/////////////////////////////////////////

	self.rootView = [[[UIApplication sharedApplication] keyWindow] rootViewController].view;
		
	////////////////////////////////////
	// ADD TAP RECOGNIZER TO ROOT VIEW SO KEYBOARD GETS DISMISSED IF ADDING LABELS
	////////////////////////////////////

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]  initWithTarget:self action:@selector(dismissKeyboard)];
	[self.rootView addGestureRecognizer:tap];	

	////////////////////////////////////////
	// SET MEDIA TYPE
	/////////////////////////////////////////

	self.mediaType = intMediaType;

	////////////////////////////////////////
	// SET MEDIA FILE EXTENSION
	/////////////////////////////////////////

	strMediaFileExtension = @"mp4";

	//if (intMediaType == 1) // 1 = video
	//{		
		//strMediaFileExtension = @"mp4";
	//}
	//else if (intMediaType == 2) // 2 = GIF
	//{
		//strMediaFileExtension = @"gif";
	//}

	///////////////////////////////////////// 
	// DOWNLOAD MEDIA FILE TO DEVICE IN ORDER TO PLAY  
	/////////////////////////////////////////

	self.mediaLocalURL = [self saveLocalFileFromRemoteUrl: mediaRemoteURL extension:strMediaFileExtension]; 

	/////////////////////////////////////////
	// CREATE MEDIA FILE INSTANCE FROM LOCAL FILE
	// THIS IS BASED ON GPUImageMovie from Brad Larson
	/////////////////////////////////////////  
	
	mediaFile = [[GPUImageMoviePlus alloc] initWithURL:self.mediaLocalURL];		     
    mediaFile.playAtActualSpeed = YES;
    mediaFile.pause = NO;
	mediaFile.stop = NO;
	mediaFile.currentTimeInSecs = 0;
	mediaFile.frameSkipper = 1;
	mediaFile.framesPerSecond = intFramesPerSecond;	
	mediaFile.skipRate = 30 / mediaFile.framesPerSecond;

	//mediaFile.runBenchmark = YES; 

	///////////////////////////////////////// 
	// CREATE MEDIA CONTAINER
	/////////////////////////////////////////

	self.mediaContainer = [[UIView alloc] initWithFrame:CGRectMake(intMediaPosX, intMediaPosY, intMediaWidth, intMediaHeight)];
	[self addMovementGesturesToView:self.mediaContainer];
	
	///////////////////////////////////////// 
	// CREATE MEDIA VIEW
	/////////////////////////////////////////

	self.mediaView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, intMediaWidth, intMediaHeight)];		
	[self.mediaContainer addSubview:self.mediaView];

	///////////////////////////////////////// 
	// CREATE MEDIA MASK
	/////////////////////////////////////////

	self.mediaMask = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, intMediaWidth, intMediaHeight)];	
	self.mediaMask.backgroundColor = [UIColor clearColor];
	self.mediaMask.opaque = NO;

	[self.mediaContainer addSubview:self.mediaMask];

	///////////////////////////////////////// 
	// CREATE MEDIA FILTER IN ORDER TO USE GPU PROCESSING
	// START WITH A SIMPLE BRIGHTNESS FILTER WITH NO ADJUSTMENTS
	/////////////////////////////////////////

	if (mediaFilter == nil)
	{
		mediaFilter = [[GPUImageBrightnessFilter alloc] init];
	}

	///////////////////////////////////////// 
	// CREATE DEFAULT SAVE FILTER
	/////////////////////////////////////////

	saveFilter = [[GPUImageBrightnessFilter alloc] init];	 

	///////////////////////////////////////// 
	// ADD MEDIA FILTER TO MEDIA FILE
	/////////////////////////////////////////

	[mediaFile addTarget:mediaFilter];	
	[mediaFilter addTarget:self.mediaView];		

	////////////////////////////////////
	// USE FRAME?
	////////////////////////////////////
	
	if (intFrameEnabled == 1 || self.mediaFrameEnabled == YES)  //FRAME
	{
		self.mediaFrameEnabled = YES;

		if (self.frameView != nil)
		{
			////////////////////////////////////
			// ADD FRAME VIEW TO MASK
			////////////////////////////////////
		
			[self.mediaMask addSubview:self.frameView];
			self.mediaMaskEnabled = YES;
		}		
		else
		{
			////////////////////////////////////
			// CREATE CUSTOM SHADER STRING
			////////////////////////////////////

			NSString *const kShaderString = SHADER_STRING
			(	
				 precision mediump float;
 
				 varying highp vec2 textureCoordinate;
				 varying highp vec2 textureCoordinate2;
 
				 uniform sampler2D inputImageTexture;
				 uniform sampler2D inputImageTexture2; 
 
				 void main() 
				 { 
					vec4 shape = texture2D(inputImageTexture, textureCoordinate);
					vec4 theme = texture2D(inputImageTexture2, textureCoordinate2);

					gl_FragColor = shape;		
		
					if (shape.a <= 0.2) 
					{ 					
						gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
					}
					else if (shape.x <= 0.2) 
					{ 					
						gl_FragColor = theme; 
					}
					else if (shape.x >= 0.8) 
					{
						gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);		
					}   
				 }
			);  

			////////////////////////////////////
			// CREATE A TWO INPUT FILTER USING THE CUSTOM SHADER STRING
			////////////////////////////////////

			GPUImageTwoInputFilter * frameFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:kShaderString];

			////////////////////////////////////
			// GET SHAPE FILE FROM URL as NSDATA
			////////////////////////////////////
		
			NSData* dataShape = [NSData dataWithContentsOfURL:[NSURL URLWithString:strFrameShapeURL] options:NSDataReadingUncached error:&error];
			if (error) {
				NSLog(@"%@", [error localizedDescription]);			
			} else {
				NSLog(@"Shape of size %i has loaded successfully!", dataShape.length);
				//NSLog(@"length: %i", dataShape.length); 
			}

			////////////////////////////////////
			// CONVERT NSDATA TO UIImage
			////////////////////////////////////

			UIImage *shapeImage = [UIImage imageWithData:dataShape];
		
			////////////////////////////////////
			// CONVERT UIImage to JPEG
			////////////////////////////////////

			NSData *jpgDataHighestCompressionQuality = UIImageJPEGRepresentation(shapeImage, 1.0);
			shapeImage = [UIImage imageWithData:jpgDataHighestCompressionQuality];

			////////////////////////////////////
			// MAKE WHITE COLOR TRANSPARENT IN SHAPE
			// THIS IS NECESSARY WHEN SAVING MASK
			//http://stackoverflow.com/questions/19443311/how-to-make-one-colour-transparent-in-uiimage
			// WTF is colorMasking var?!?
			// element #1 is R-MIN, element #2 is R-MAX, element #3 is G-MIN, element #4 is G-MAX, element #5 is B-MIN, element #6 is B-MAX
			////////////////////////////////////

			shapeImage = [self changeWhiteColorTransparent: shapeImage];

			////////////////////////////////////
			// GET THEME FILE FROM URL as NSDATA
			////////////////////////////////////

			NSData* dataTheme = [NSData dataWithContentsOfURL:[NSURL URLWithString:strFrameThemeURL] options:NSDataReadingUncached error:&error];
			if (error) {
				NSLog(@"%@", [error localizedDescription]);			
			} else {
				NSLog(@"Theme of size %i has loaded successfully!", dataTheme.length);			
			}

			////////////////////////////////////
			// CONVERT NSDATA TO UIImage
			////////////////////////////////////

			UIImage *themeImage = [UIImage imageWithData:dataTheme]; 

			////////////////////////////////////
			// CREATE GPUImagePictures from SHAPE & THEME
			////////////////////////////////////

			GPUImagePicture *shapePicture = [[GPUImagePicture alloc] initWithImage:shapeImage smoothlyScaleOutput:YES];
			GPUImagePicture *themePicture = [[GPUImagePicture alloc] initWithImage:themeImage smoothlyScaleOutput:YES];
		 
			////////////////////////////////////
			// ADD SHAPE & THEME TO FRAME FILTER & PROCESS
			////////////////////////////////////

			[shapePicture addTarget:frameFilter];	 
			[themePicture addTarget:frameFilter];		 

			[frameFilter useNextFrameForImageCapture];

			[shapePicture processImage];
			[themePicture processImage]; 

			////////////////////////////////////
			// GET COMBINED SHAPE & THEME IMAGE
			////////////////////////////////////

			UIImage *frameImage = [frameFilter imageFromCurrentFramebuffer];

			////////////////////////////////////
			// CREATE FRAME VIEW
			////////////////////////////////////

			self.frameView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, intMediaWidth, intMediaHeight)]; 
		
			////////////////////////////////////
			// ADD IMAGE TO FRAME VIEW
			////////////////////////////////////
		 
			[self.frameView setImage:frameImage];		

			////////////////////////////////////
			// ADD FRAME VIEW TO MASK
			////////////////////////////////////
		
			[self.mediaMask addSubview:self.frameView];
			self.mediaMaskEnabled = YES;
		}
	}

	////////////////////////////////////
	// ADD CAPTION?
	////////////////////////////////////

	if (intCaptionEnabled == 1)
	{	
	    //https://www.cocoanetics.com/2014/06/object-overlay-on-video/

		int intCaptionHeight = intCaptionFontSize + 10;

		self.captionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, intMediaHeight - intCaptionHeight, intMediaWidth, intCaptionHeight)];
		self.captionLabel.text = strCaptionText;		
		self.captionLabel.font = [UIFont systemFontOfSize:intCaptionFontSize];
		self.captionLabel.textColor = [UIColor whiteColor];
		self.captionLabel.tag = 1;
		self.captionLabel.hidden = NO;
		self.captionLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5f];
		self.captionLabel.textAlignment = UITextAlignmentCenter;

		[self.mediaMask addSubview:self.captionLabel];
		self.mediaMaskEnabled = YES;
	} 

	////////////////////////////////////
	// ADD OVERLAY?
	////////////////////////////////////

	if (intOverlayEnabled == 1)
	{	
		NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:strOverlayURL] options:NSDataReadingUncached error:&error];
		if (error) {
			NSLog(@"%@", [error localizedDescription]);			
		} else {
			NSLog(@"Overlay of size %i has loaded successfully!", data.length);			
		}

		////////////////////////////////////
		// CREATE IMAGE from NSDATA
		////////////////////////////////////

		UIImage *overlayImage = [UIImage imageWithData:data];

		////////////////////////////////////
		// CREATE OVERLAY VIEW
		////////////////////////////////////
		
		self.overlayView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, intMediaWidth, intMediaHeight)]; 

		////////////////////////////////////
		// ADD IMAGE TO VIEW
		////////////////////////////////////		
		
		[self.overlayView setImage:overlayImage];

		////////////////////////////////////
		// ADD VIEW TO MASK
		////////////////////////////////////		

		[self.mediaMask addSubview:self.overlayView];
		self.mediaMaskEnabled = YES;
	}	

	////////////////////////////////////
	// IS LANDSCAPE?
	////////////////////////////////////

	if (intOrientation == 2) // LANDSCAPE
	{
		[mediaFilter setInputRotation:kGPUImageRotateLeft atIndex:0];		
	}	
	
	////////////////////////////////////
	// CREATE SCROLL VIEW - ALLOWS PAN AND PINCH
	////////////////////////////////////

	self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(intPlayerPosX, intPlayerPosY, intPlayerWidth, intPlayerHeight)]; 	
	self.scrollView.backgroundColor = [UIColor blackColor]; 
	[self.scrollView addSubview:self.mediaContainer];
	[self.rootView addSubview:self.scrollView];
	
	////////////////////////////////////
	// USE AUDIO PLAYER?
	////////////////////////////////////

	if (intMediaType == 1) // 1 = video
	{
		self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:self.mediaLocalURL error:&error];	
		self.audioPlayer.numberOfLoops = 0;	
		[self.audioPlayer setEnableRate:YES];
		self.audioPlayer.delegate  = self;	
	}

	////////////////////////////////////
	// START PROCESSING FRAMES OF MEDIA FILE
	////////////////////////////////////

	[mediaFile startProcessing];    

	////////////////////////////////////
	// PLAY AUDIO?
	////////////////////////////////////
	 
	if (intMediaType == 1) // 1 = video
	{
		[self.audioPlayer play];
	}

	////////////////////////////////////
	// GENERATE PROGRESS INFO USING TIMER
	////////////////////////////////////

	//NSTimer *playbackTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(showProgress:) userInfo:nil repeats:YES];	
	playbackTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(showProgress:) userInfo:nil repeats:YES];	
}
  
- (void) pause:(CDVInvokedUrlCommand *)command {
	if (mediaFile.stop == NO)
	{
		mediaFile.pause = YES;

		if (self.mediaType == 1) // 1 = video
		{
			[self.audioPlayer pause];
		}		
	}		
 }

 - (void) play:(CDVInvokedUrlCommand *)command {
	if (mediaFile.stop == NO)
	{
		mediaFile.pause = NO;
		
		if (self.mediaType == 1) // 1 = video
		{
			[self.audioPlayer play];
		}		
	}	
 }

- (void) stop:(CDVInvokedUrlCommand *)command {
	if (mediaFile.stop == NO)
	{
		mediaFile.stop = YES;				
		
		if (self.mediaType == 1) // 1 = video
		{
			[self.audioPlayer stop];
		}		
	}  

	//[self.mediaContainer removeFromSuperview];
	//self.mediaContainer = nil;

	[self.scrollView removeFromSuperview];
	self.scrollView = nil;
 }
 
 - (void) save:(CDVInvokedUrlCommand *)command { 
	
	////////////////////////////////////
	// SET VARS
	//////////////////////////////////// 
	
	NSDictionary *options = [command.arguments objectAtIndex: 0];
  
	int intMediaWidth = [[options objectForKey:@"mediaWidth"] integerValue];
    int intMediaHeight = [[options objectForKey:@"mediaHeight"] integerValue];
	int intAvgBitRate = [[options objectForKey:@"avgBitRate"] integerValue];

	int intGifFramesPerSecond = [[options objectForKey:@"gifFramesPerSecond"] integerValue];
	int intGifPlaybackSpeed = [[options objectForKey:@"gifPlaybackSpeed"] integerValue];
	int intGifMaxDuration = [[options objectForKey:@"gifMaxDuration"] integerValue];

	NSString * strMediaURL = [options objectForKey:@"mediaURL"];	
	int intMediaType = [[options objectForKey:@"mediaType"] integerValue];

	NSString * strMediaFileExtension;

	UIImage * maskImage;

	self.jsonProgress = [ [NSMutableDictionary alloc]
        initWithObjectsAndKeys :
        nil, @"progress",        
        nil
    ];

	////////////////////////////////////
	// CREATE RANDOM FILE NAME
	//////////////////////////////////// 

	int intFileNameLength = 15;
	static NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    NSMutableString *strRandomFileName = [NSMutableString stringWithCapacity: intFileNameLength];

    for (int i=0; i<intFileNameLength; i++) {
        [strRandomFileName appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }

	////////////////////////////////////
	// CREATE TEMP PATH
	//////////////////////////////////// 

	NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:strRandomFileName] URLByAppendingPathExtension:@"mov"];
    //NSLog(@"fileURL: %@", [fileURL path]);		

	////////////////////////////////////
	// CLEAR THE SAVE FILTER
	//////////////////////////////////// 

	[saveFilter removeAllTargets];   

	///////////////////////////////////////// 
	// HAS MEDIA ALREADY BEEN SAVED TO DEVICE?
	/////////////////////////////////////////

	if (self.mediaLocalURL == nil)
	{
		NSLog(@"DOWNLOADING FILE...");

		///////////////////////////////////////// 
		// SET CALLBACK ID
		/////////////////////////////////////////
		
		self.callbackId = command.callbackId;
		
		///////////////////////////////////////// 
		// CREATE DEFAULT SAVE FILTER
		/////////////////////////////////////////

		saveFilter = [[GPUImageBrightnessFilter alloc] init];	
		
		////////////////////////////////////////
		// SET MEDIA TYPE
		/////////////////////////////////////////

		self.mediaType = intMediaType;

		////////////////////////////////////////
		// SET MEDIA FILE EXTENSION
		/////////////////////////////////////////

		strMediaFileExtension = @"mp4";

		//if (intMediaType == 1) // 1 = video
		//{		
			//strMediaFileExtension = @"mp4";
		//}
		//else if (intMediaType == 2) // 2 = GIF
		//{
			//strMediaFileExtension = @"gif";
		//}
		
		///////////////////////////////////////// 
		// DOWNLOAD MEDIA FILE TO DEVICE IN ORDER TO SAVE
		/////////////////////////////////////////

		NSURL* mediaRemoteURL = [NSURL URLWithString:strMediaURL];   			
		self.mediaLocalURL = [self saveLocalFileFromRemoteUrl: mediaRemoteURL extension:strMediaFileExtension]; 		
	}	 
	
	////////////////////////////////////
	// CREATE SAVED FILE
	//////////////////////////////////// 

	saveFile = [[GPUImageMovie alloc] initWithURL:self.mediaLocalURL];		 
    saveFile.playAtActualSpeed = NO;

	////////////////////////////////////
	// ADD FILTER TO SAVED FILE
	//////////////////////////////////// 

	[saveFile addTarget:saveFilter];  	

	////////////////////////////////////
	// ADD FILTER TO SAVED FILE
	// http://www.sunsetlakesoftware.com/forum/audio-problems-when-filtering-movie-file
	//////////////////////////////////// 

	////////////////////////////////////
	// CONFIGURE OUTPUT SETTINGS
	////////////////////////////////////  
	
	NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
    [settings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];	         
    [settings setObject:[NSNumber numberWithInt:intMediaWidth] forKey:AVVideoWidthKey];
    [settings setObject:[NSNumber numberWithInt:intMediaHeight] forKey:AVVideoHeightKey];

	NSDictionary *videoCleanApertureSettings = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInt:intMediaWidth], AVVideoCleanApertureWidthKey,
    [NSNumber numberWithInt:intMediaHeight], AVVideoCleanApertureHeightKey,
    [NSNumber numberWithInt:0], AVVideoCleanApertureHorizontalOffsetKey,
    [NSNumber numberWithInt:0], AVVideoCleanApertureVerticalOffsetKey,
    nil]; 

	NSDictionary *videoAspectRatioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInt:3], AVVideoPixelAspectRatioHorizontalSpacingKey,
    [NSNumber numberWithInt:3], AVVideoPixelAspectRatioVerticalSpacingKey,   
    nil]; 
	  
	NSMutableDictionary * compressionProperties = [[NSMutableDictionary alloc] init];
    [compressionProperties setObject:videoCleanApertureSettings forKey:AVVideoCleanApertureKey];
    [compressionProperties setObject:videoAspectRatioSettings forKey:AVVideoPixelAspectRatioKey];
    [compressionProperties setObject:[NSNumber numberWithInt:intAvgBitRate] forKey:AVVideoAverageBitRateKey];
    [compressionProperties setObject:[NSNumber numberWithInt: 16] forKey:AVVideoMaxKeyFrameIntervalKey];
    [compressionProperties setObject:AVVideoProfileLevelH264Main31 forKey:AVVideoProfileLevelKey];
	
    [settings setObject:compressionProperties forKey:AVVideoCompressionPropertiesKey];

	////////////////////////////////////
	// CREATE A MOVIE WRITER
	//////////////////////////////////// 

	//movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:fileURL size:CGSizeMake(375.0, 210.0)];
	movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:fileURL size:CGSizeMake(intMediaWidth, intMediaHeight) fileType:@"com.apple.quicktime-movie" outputSettings:settings];
	movieWriter.shouldPassthroughAudio = YES;  

	saveFile.audioEncodingTarget = movieWriter;
    [saveFile enableSynchronizedEncodingUsingMovieWriter:movieWriter]; 

	////////////////////////////////////
	// ADD MASK?
	//////////////////////////////////// 

	if (self.mediaMaskEnabled == YES)
	{
		////////////////////////////////////
		// CREATE A RECTANGLE THE SIZE OF THE MEDIA MASK
		//////////////////////////////////// 

		CGRect rect = [self.mediaMask bounds];

		////////////////////////////////////
		// CREATE A SINGLE IMAGE FROM THE LAYERS ON THE MASK
		//////////////////////////////////// 

		UIGraphicsBeginImageContext(rect.size);
		CGContextRef context = UIGraphicsGetCurrentContext();
		[self.mediaMask.layer renderInContext:context];   

		UIImage *img = UIGraphicsGetImageFromCurrentImageContext(); 
		UIGraphicsEndImageContext();

		////////////////////////////////////
		// CREATE A PNG IMAGE FROM THE MASK IMAGE
		//////////////////////////////////// 

		NSData *imageData = UIImagePNGRepresentation(img);
		maskImage = [UIImage imageWithData:imageData];

		////////////////////////////////////
		// CREATE AN ALPHA BLEND FILTER FOR THE MASK
		//////////////////////////////////// 

		GPUImageAlphaBlendFilter *maskFilter = [[GPUImageAlphaBlendFilter alloc] init];    
		maskFilter.mix = 1.0; 

		////////////////////////////////////
		// ADD THE MASK FILTER TO THE SAVE FILTER
		//////////////////////////////////// 

		overlay = [[GPUImagePicture alloc] initWithImage:maskImage smoothlyScaleOutput:NO];	 
		[overlay processImage];
		[overlay addTarget:maskFilter atTextureLocation:1];
		[saveFilter addTarget:maskFilter]; 

		[maskFilter addTarget:movieWriter];  
	}	    
	else
	{		
		GPUImageBrightnessFilter *dummyFilter = [[GPUImageBrightnessFilter alloc] init];	
		
		[saveFilter addTarget:dummyFilter]; 
		[dummyFilter addTarget:movieWriter]; 	
	}

	////////////////////////////////////
	// START PROCESSING
	//////////////////////////////////// 
	
	[movieWriter startRecording];  
    [saveFile startProcessing]; 	

	////////////////////////////////////
	// GENERATE PROGRESS INFO USING TIMER
	////////////////////////////////////
	
	saveTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(saveFileProgress:) userInfo:nil repeats:YES];

	//////////////////////////////////// 
	// UPON COMPLETION, SAVE FILE
	////////////////////////////////////

	[movieWriter setCompletionBlock:^{ 

        [saveFilter removeTarget:movieWriter]; 
        [movieWriter finishRecording];  
		  
		NSNumber *fileSizeValue = nil;
		NSError *fileSizeError = nil; 
		NSString *strFileSize;

		NSDictionary *attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.relativePath error:&fileSizeError];
		if (attribs) {
			strFileSize = [NSByteCountFormatter stringFromByteCount:[attribs fileSize] countStyle:NSByteCountFormatterCountStyleFile];			
		}		

		usleep(1000000);  // SLEEP FOR 1 SEC TO GIVE PHONE TIME TO SAVE  
		
		//NSLog(@"FILE URL: %@", fileURL.relativePath);   
		 
		//[self createGIFfromURL:fileURL withFrameCount:30 delayTime:.010 loopCount:0 completion:^(NSURL *GifURL) {
		//[self createGIFfromURL:fileURL withFrameCount:85 delayTime:1.0 loopCount:0 completion:^(NSURL *GifURL) {
		//[self createGIFfromURL:fileURL withFrameCount:170 delayTime:0.01 loopCount:0 completion:^(NSURL *GifURL) {
		//[self createGIFfromURL:fileURL withFrameCount:340 delayTime:0.25 loopCount:0 completion:^(NSURL *GifURL) { 
		
		//[self createGIFfromURL:fileURL withFrameCount:340 delayTime:.10 loopCount:0 completion:^(NSURL *GifURL) {
		//[self createGIFfromURL:fileURL withFrameCount:170 delayTime:0.25 loopCount:0 completion:^(NSURL *GifURL) { 
		//[self createGIFfromURL:fileURL withFrameCount:340 delayTime:0.02 loopCount:0 completion:^(NSURL *GifURL) {  

		//[self createGIFfromURL:fileURL withFrameCount:340 delayTime:0.25 loopCount:0 completion:^(NSURL *GifURL) {  
		//[self createGIFfromURL:fileURL withFrameCount:340 delayTime:0.125 loopCount:0 completion:^(NSURL *GifURL) {  
		
		//[self createGIFfromURL:fileURL withFrameCount:170 delayTime:0.0625 loopCount:0 completion:^(NSURL *GifURL) {  
		//[self createGIFfromURL:fileURL withFrameCount:170 delayTime:0.125 loopCount:0 completion:^(NSURL *GifURL) {     // 2 fps at 4x speed
		//[self optimalGIFfromURL:fileURL loopCount:0 completion:^(NSURL *GifURL) { 

		//[self createGIFfromURL:fileURL withFrameCount:45 delayTime:0.10 loopCount:0 completion:^(NSURL *GifURL) {     // 2 fps at 4x speed

		//[self createGIFfromURL:fileURL framesPerSecond:5 playbackSpeed:4 loopCount:0 completion:^(NSURL *GifURL) {  // 5 fps playing back at 2x
		//[self createGIFfromURL:fileURL framesPerSecond:10 playbackSpeed:2 loopCount:0 completion:^(NSURL *GifURL) {  // 5 fps playing back at 2x

		if (intMediaType == 1) // 1 = video
		{
			//NSLog(@"Saving to photo album...");
			if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileURL.relativePath))
			{	
				UISaveVideoAtPathToSavedPhotosAlbum(fileURL.relativePath, nil, nil, nil);				
				NSLog(@"Saved video file to path: %@, file size: %@", fileURL, strFileSize);
			}
			else
			{
				NSLog(@"Error!!!");
			}		         
		}

		if (intMediaType == 2) // 2 = gif
		{
			[self createGIFfromURL:fileURL framesPerSecond:intGifFramesPerSecond playbackSpeed:intGifPlaybackSpeed maxDuration:intGifMaxDuration loopCount:0 completion:^(NSURL *GifURL) {  // loopCount = 0 means infinite loop

				NSLog(@"Finished generating GIF: %@", GifURL); 
			 
				[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
					PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:GifURL];				
				} completionHandler:^(BOOL success, NSError *error) { 
					if (success)
					{
						//NSLog(@"SAVED GIF!!!");
						NSError *gifFileSizeError = nil; 
						NSString *strGifFileSize;
						NSDictionary *gifAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:GifURL.relativePath error:&gifFileSizeError];
						if (gifAttribs) {
							strGifFileSize = [NSByteCountFormatter stringFromByteCount:[gifAttribs fileSize] countStyle:NSByteCountFormatterCountStyleFile];			
						}		

						NSLog(@"Saved gif file to path: %@, file size: %@", GifURL, strGifFileSize);
					}
					else
					{
						NSLog(@"%@", error);
					}
				}];				
			}];
		}		
    }];
}

 - (void) addSticker:(CDVInvokedUrlCommand *)command {
	
		///////////////////////////////////////// 
		// SET VARS
		/////////////////////////////////////////

		NSError* error = nil;

		NSDictionary *options = [command.arguments objectAtIndex: 0];
  
		NSString * strStickerURL = [options objectForKey:@"stickerURL"];

		int intStickerID = [[options objectForKey:@"stickerID"] integerValue];
		int intStickerWidth = [[options objectForKey:@"stickerWidth"] integerValue];
		int intStickerHeight = [[options objectForKey:@"stickerHeight"] integerValue];
		int intStickerPosX = [[options objectForKey:@"stickerPosX"] integerValue];
		int intStickerPosY = [[options objectForKey:@"stickerPosY"] integerValue];

		self.currentTag = intStickerID;

		///////////////////////////////////////// 
		// GET STICKER AS NSDATA
		/////////////////////////////////////////
		
		NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:strStickerURL] options:NSDataReadingUncached error:&error];
		if (error) {
			NSLog(@"%@", [error localizedDescription]);			
		} else {			
			NSLog(@"Sticker of size %i has loaded successfully!", data.length);			
		}

		///////////////////////////////////////// 
		// CONVERT NSDATA TO UIIMAGE
		/////////////////////////////////////////

		UIImage *stickerImage = [UIImage imageWithData:data];
		
		///////////////////////////////////////// 
		// ADD UIIMAGE TO VIEW
		/////////////////////////////////////////  

		UIImageView *stickerView = [[UIImageView alloc] initWithFrame:CGRectMake(intStickerPosX, intStickerPosY, intStickerWidth, intStickerHeight)]; 
		[stickerView setImage:stickerImage]; 
		stickerView.tag = intStickerID;

		///////////////////////////////////////// 
		// ADD PAN GESTURES TO VIEW
		/////////////////////////////////////////

		[self addLimitedPanGesturesToView:stickerView];

		///////////////////////////////////////// 
		// ADD LONG PRESS GESTURE (FOR DELETING)
		/////////////////////////////////////////
		
		UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] init];
		[gestureRecognizer addTarget:self action:@selector(imgLongPressed:)];
		gestureRecognizer.delegate = self;
		[stickerView addGestureRecognizer: gestureRecognizer];
		
		///////////////////////////////////////// 
		// ADD VIEW TO MASK
		/////////////////////////////////////////

		[self.mediaMask addSubview:stickerView];
		self.mediaMaskEnabled = YES;
 }

  - (void) addLabel:(CDVInvokedUrlCommand *)command {
	
		///////////////////////////////////////// 
		// SET VARS
		/////////////////////////////////////////
		
		NSDictionary *options = [command.arguments objectAtIndex: 0];  
  
		int intLabelID = [[options objectForKey:@"labelID"] integerValue]; 

		int intLabelWidth = [[options objectForKey:@"labelWidth"] integerValue];
		int intLabelHeight = [[options objectForKey:@"labelHeight"] integerValue];
		int intLabelPosX = [[options objectForKey:@"labelPosX"] integerValue];
		int intLabelPosY = [[options objectForKey:@"labelPosY"] integerValue];

		//self.currentTextFieldTag = intLabelID;
		self.currentTag = intLabelID;

		///////////////////////////////////////// 
		// CREATE TEXT FIELD
		/////////////////////////////////////////

		UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(intLabelPosX, intLabelPosY, intLabelWidth, intLabelHeight)];		
		textField.borderStyle = UITextBorderStyleNone; 
		textField.textAlignment = UITextAlignmentCenter;
		textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		[textField setBackgroundColor:[UIColor clearColor]];
		[textField setTextColor:[UIColor whiteColor]];
		textField.tintColor = [UIColor whiteColor];
		textField.tag = intLabelID;
		textField.delegate = self;
		
		///////////////////////////////////////// 
		// ADD PAN GESTURES TO VIEW 
		/////////////////////////////////////////

		[self addLimitedPanGesturesToView:textField];

		///////////////////////////////////////// 
		// ADD LONG PRESS GESTURE (FOR DELETING)
		/////////////////////////////////////////

		UILongPressGestureRecognizer *pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] init];
		[pressGestureRecognizer addTarget:self action:@selector(labelLongPressed:)];
		pressGestureRecognizer.delegate = self;
		[textField addGestureRecognizer: pressGestureRecognizer];
		
		///////////////////////////////////////// 
		// ADD TAP GESTURE (FOR SELECTING)
		/////////////////////////////////////////

		//UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] init];
		//[tapGestureRecognizer addTarget:self action:@selector(labelTapped:)];
		//tapGestureRecognizer.delegate = self;
		//[textField addGestureRecognizer: tapGestureRecognizer];

		///////////////////////////////////////// 
		// ADD VIEW TO MASK
		/////////////////////////////////////////

		[self.mediaMask addSubview:textField];
		self.mediaMaskEnabled = YES;

		///////////////////////////////////////// 
		// AUTOFOCUS ON TEXT FIELD
		/////////////////////////////////////////

		UIResponder* nextResponder = [textField.superview viewWithTag:(textField.tag)];
        if (nextResponder) {
            [nextResponder becomeFirstResponder];
        }		 		
 }

 - (void) updateLabel:(CDVInvokedUrlCommand *)command { 
 
		///////////////////////////////////////// 
		// SET VARS
		/////////////////////////////////////////		

		NSDictionary *options = [command.arguments objectAtIndex: 0];
  
		int intLabelSize = [[options objectForKey:@"labelSize"] integerValue];
		NSString *strLabelColor = [options objectForKey:@"labelColor"];

		//int intLabelID = self.currentTextFieldTag;
		int intLabelID = self.currentTag;

		/////////////////////////////////////////  
		// GET REFERENCE TO TEXT FIELD
		/////////////////////////////////////////

		UITextField * textField = (UITextField*)[self.mediaMask viewWithTag:intLabelID];

		///////////////////////////////////////// 
		// SET COLOR
		/////////////////////////////////////////

		UIColor *color = [self getUIColorObjectFromHexString:strLabelColor alpha:1.0];
		[textField setTextColor:color];

		///////////////////////////////////////// 
		// SET FONT SIZE
		/////////////////////////////////////////

		[textField setFont:[UIFont boldSystemFontOfSize:intLabelSize]];

		///////////////////////////////////////// 
		// RESIZE TEXT FIELD
		/////////////////////////////////////////

		[self resizeTextField: textField];		
 }

 - (void) updateSticker:(CDVInvokedUrlCommand *)command {

		///////////////////////////////////////// 
		// SET VARS
		/////////////////////////////////////////	

		NSDictionary *options = [command.arguments objectAtIndex: 0]; 
  
		//int intStickerID = [[options objectForKey:@"stickerID"] integerValue];
		int intStickerSize = [[options objectForKey:@"stickerSize"] integerValue];
		NSString *strStickerColor = [options objectForKey:@"stickerColor"];

		int intStickerID = self.currentTag;

		/////////////////////////////////////////  
		// GET REFERENCE TO TEXT FIELD
		/////////////////////////////////////////

		UIImageView * imageView = (UIImageView*)[self.mediaMask viewWithTag:intStickerID];

		///////////////////////////////////////// 
		// SET COLOR
		/////////////////////////////////////////

		UIColor *color = [self getUIColorObjectFromHexString:strStickerColor alpha:1.0];				
		imageView.backgroundColor = color;

		///////////////////////////////////////// 
		// SET SIZE
		/////////////////////////////////////////

		imageView.contentMode = UIViewContentModeScaleToFill;

		CGRect frameRect = imageView.frame;
		frameRect.size.height = intStickerSize + 20; // <-- Specify the height you want here.
		frameRect.size.width = intStickerSize + 20; // <-- Specify the height you want here.
		imageView.frame = frameRect;		
 }

////////////////////////////////////
// UTILITY METHODS
////////////////////////////////////

 -(UIImage *)changeWhiteColorTransparent: (UIImage *)image
{
    CGImageRef rawImageRef = image.CGImage;

    const CGFloat colorMasking[6] = {228.0, 255.0, 228.0, 255.0, 228.0, 255.0};
	
    UIGraphicsBeginImageContext(image.size);
    CGImageRef maskedImageRef=CGImageCreateWithMaskingColors(rawImageRef, colorMasking);
    {
        //if in iphone
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0, image.size.height);
        CGContextScaleCTM(UIGraphicsGetCurrentContext(), 1.0, -1.0);
    }

    CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, image.size.width, image.size.height), maskedImageRef);
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    CGImageRelease(maskedImageRef);
    UIGraphicsEndImageContext();

    return result;
}

-(void)dismissKeyboard {
       
	//UITextField* textField = [self.rootView viewWithTag:(self.currentTextFieldTag)];
	UITextField* textField = [self.rootView viewWithTag:(self.currentTag)];

	[self resizeTextField: textField];
	[self.rootView endEditing:YES];
}

- (NSURL*)saveLocalFileFromRemoteUrl:(NSURL*)url extension:(NSString *)extension
{   
    if (!NSTemporaryDirectory())
    {
       // no tmp dir for the app (need to create one)
    }

    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];    
	NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:@"mediaFile"] URLByAppendingPathExtension:extension];
	
	NSData *urlData = [NSData dataWithContentsOfURL:url];
    [urlData writeToURL:fileURL options:NSAtomicWrite error:nil];

	return fileURL;
}

-(void)showProgress:(NSTimer*)timer
{   
	int intCurrentTime = (mediaFile.currentTime + 0.5);

	float audioRemaining = self.audioPlayer.duration - self.audioPlayer.currentTime;
	float videoRemaining = self.audioPlayer.duration - mediaFile.currentTime;

	if (intCurrentTime > mediaFile.currentTimeInSecs)
	{		
		///////////////////////////////
		// ADJUST AUDIO RATE!!!!!
		///////////////////////////////
		
		float audioDiff = videoRemaining - audioRemaining;

		//NSLog(@"Current audio time : %f %f %f %f", audioDuration, audioRemaining, videoRemaining, audioDiff);	
		
		if (audioDiff > 0.5)
		{
			[self.audioPlayer setRate:0.5f];
		}
		else if (audioDiff > 0.25 && audioDiff <= 0.5)
		{
			[self.audioPlayer setRate:0.75f];
		}
		else if (audioDiff > -0.25 && audioDiff <= 0.25)
		{
			[self.audioPlayer setRate:1.0f];
		}
		else if (audioDiff > -0.50 && audioDiff <= -0.25)
		{
			[self.audioPlayer setRate:1.25f];
		}
		else if (audioDiff < -0.5)
		{
			[self.audioPlayer setRate:1.50f];
		}
		
		mediaFile.currentTimeInSecs = intCurrentTime;
		
		self.jsonResults[@"duration"] = [[NSNumber numberWithFloat:mediaFile.duration] stringValue];
		self.jsonResults[@"currentTime"] = [[NSNumber numberWithFloat:mediaFile.currentTime] stringValue];	

		self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.jsonResults];	

		[self.pluginResult setKeepCallbackAsBool:YES]; // here we tell Cordova not to cleanup the callback id after sendPluginResult()					
		[self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.callbackId];
	}	
	else if (videoRemaining < 0.95)
	{
		[playbackTimer invalidate];
         playbackTimer = nil;

		self.jsonResults[@"duration"] = [[NSNumber numberWithFloat:mediaFile.duration] stringValue];
		self.jsonResults[@"currentTime"] = [[NSNumber numberWithFloat:mediaFile.duration] stringValue];	

		self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.jsonResults];	

		[self.pluginResult setKeepCallbackAsBool:YES]; // here we tell Cordova not to cleanup the callback id after sendPluginResult()					
		[self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.callbackId];
	}
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{    
	NSLog(@"FINISHED AUDIO!!!");    
}
  
-(void)saveFileProgress:(NSTimer*)timer
{    
	float fltProgress = saveFile.progress; 	
	//NSLog(@"Progress: %f", fltProgress);	

	self.jsonProgress[@"progress"] = [[NSNumber numberWithFloat:fltProgress] stringValue];
	
	self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.jsonProgress];	
	[self.pluginResult setKeepCallbackAsBool:YES]; // here we tell Cordova not to cleanup the callback id after sendPluginResult()					
	[self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.callbackId];

	//if (fltProgress >= .95)
	if (fltProgress >= 1.0)
	{
		[saveTimer invalidate];
		saveTimer = nil;
	}
}

 - (BOOL)textFieldDidBeginEditing:(UITextField *)textField {
		
		CGRect newFrame = textField.frame;
		newFrame.size = CGSizeMake(375, newFrame.size.height);
		textField.frame = newFrame;
		
		self.currentTag = textField.tag;
		//self.currentTextFieldTag = textField.tag;
		//NSLog(@"tag: %i", self.currentTextFieldTag);
 }

 - (BOOL)textFieldShouldReturn:(UITextField *)textField {
	
	[self resizeTextField: textField];
    [textField resignFirstResponder];
	
    return NO;
 }

 - (void) resizeTextField:(UITextField*)textField
{
	// http://stackoverflow.com/questions/50467/how-do-i-size-a-uitextview-to-its-content

	UITextPosition *Pos2 = [textField positionFromPosition: textField.endOfDocument offset: nil];
	UITextPosition *Pos1 = [textField positionFromPosition: textField.endOfDocument offset: -textField.text.length];
	UITextRange *range = [textField textRangeFromPosition:Pos1 toPosition:Pos2];
	CGRect result1 = [textField firstRectForRange:(UITextRange *)range ];
	
	textField.textAlignment = NSTextAlignmentLeft;

	CGFloat fixedWidth = textField.frame.size.width;
    CGSize newSize = [textField sizeThatFits:CGSizeMake(fixedWidth, MAXFLOAT)];
    CGRect newFrame = textField.frame;

	if (result1.origin.x > 0)
	{
		newFrame.origin.x = result1.origin.x;
	}

    newFrame.size = CGSizeMake(newSize.width, newSize.height);
	textField.frame = newFrame;
}

- (UIImage *)captureView_OLD { 
    
	self.mediaMask.opaque = NO;
    CGRect rect = [self.mediaMask bounds];

    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.mediaMask.layer renderInContext:context];   

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

	NSData *imageData = UIImagePNGRepresentation(img);
	UIImage * pngImage = [UIImage imageWithData:imageData];

	//UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
	UIImageWriteToSavedPhotosAlbum(pngImage, nil, nil, nil);
    return img;
}

 - (void) imgLongPressed:(UILongPressGestureRecognizer*)sender
{
    UIImageView *view_ =(UIImageView*) sender.view;
	
    CGPoint point = [sender locationInView:view_.superview];

    if (sender.state == UIGestureRecognizerStateBegan)
    {
		//self.currentStickerTag = view_.tag; 
		self.currentTag = view_.tag; 
		NSLog(@"tag: %i", view_.tag);
    }
    else if (sender.state == UIGestureRecognizerStateChanged)
    {
    }
    else if (sender.state == UIGestureRecognizerStateEnded)
    {		 
    }
}

- (void) labelLongPressed:(UILongPressGestureRecognizer*)sender
{
    UITextField *view_ =(UITextField*) sender.view;
	
    if (sender.state == UIGestureRecognizerStateBegan)
    {
		self.currentTag = view_.tag;
		//self.currentTextFieldTag = view_.tag;
		NSLog(@"tag: %i", view_.tag);
    }    
}

- (void) changeFrame:(CDVInvokedUrlCommand *)command {

	///////////////////////////////////////// 
	// SET VARS
	/////////////////////////////////////////	

	NSDictionary *options = [command.arguments objectAtIndex: 0];
  	NSError* error = nil;

	NSString * strFrameShapeURL = [options objectForKey:@"frameShapeURL"];
	NSString * strFrameThemeURL = [options objectForKey:@"frameThemeURL"];
	int intMediaWidth = [[options objectForKey:@"mediaWidth"] integerValue];
    int intMediaHeight = [[options objectForKey:@"mediaHeight"] integerValue];

	////////////////////////////////////
	// CREATE CUSTOM SHADER STRING
	////////////////////////////////////

	NSString *const kShaderString = SHADER_STRING
	(	
		precision mediump float;
 
		varying highp vec2 textureCoordinate;
		varying highp vec2 textureCoordinate2;
 
		uniform sampler2D inputImageTexture;
		uniform sampler2D inputImageTexture2; 
 
		void main() 
		{ 
		vec4 shape = texture2D(inputImageTexture, textureCoordinate);
		vec4 theme = texture2D(inputImageTexture2, textureCoordinate2);

		gl_FragColor = shape;		
		
		if (shape.a <= 0.2) 
		{ 					
			gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
		}
		else if (shape.x <= 0.2) 
		{ 					
			gl_FragColor = theme; 
		}
		else if (shape.x >= 0.8) 
		{
			gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);		
		}   
		}
	);  

	////////////////////////////////////
	// CREATE A TWO INPUT FILTER USING THE CUSTOM SHADER STRING
	////////////////////////////////////

	GPUImageTwoInputFilter * frameFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:kShaderString];

	////////////////////////////////////
	// GET SHAPE FILE FROM URL as NSDATA
	////////////////////////////////////
		
	NSData* dataShape = [NSData dataWithContentsOfURL:[NSURL URLWithString:strFrameShapeURL] options:NSDataReadingUncached error:&error];
	if (error) {
		NSLog(@"%@", [error localizedDescription]);			
	} else {
		NSLog(@"Shape of size %i has loaded successfully!", dataShape.length);
		//NSLog(@"length: %i", dataShape.length); 
	}

	////////////////////////////////////
	// CONVERT NSDATA TO UIImage
	////////////////////////////////////

	UIImage *shapeImage = [UIImage imageWithData:dataShape];
		
	////////////////////////////////////
	// CONVERT UIImage to JPEG
	////////////////////////////////////

	NSData *jpgDataHighestCompressionQuality = UIImageJPEGRepresentation(shapeImage, 1.0);
	shapeImage = [UIImage imageWithData:jpgDataHighestCompressionQuality];

	////////////////////////////////////
	// MAKE WHITE COLOR TRANSPARENT IN SHAPE
	// THIS IS NECESSARY WHEN SAVING MASK
	//http://stackoverflow.com/questions/19443311/how-to-make-one-colour-transparent-in-uiimage
	// WTF is colorMasking var?!?
	// element #1 is R-MIN, element #2 is R-MAX, element #3 is G-MIN, element #4 is G-MAX, element #5 is B-MIN, element #6 is B-MAX
	////////////////////////////////////

	shapeImage = [self changeWhiteColorTransparent: shapeImage];

	////////////////////////////////////
	// GET THEME FILE FROM URL as NSDATA
	////////////////////////////////////

	NSData* dataTheme = [NSData dataWithContentsOfURL:[NSURL URLWithString:strFrameThemeURL] options:NSDataReadingUncached error:&error];
	if (error) {
		NSLog(@"%@", [error localizedDescription]);			
	} else {
		NSLog(@"Theme of size %i has loaded successfully!", dataTheme.length);			
	}

	////////////////////////////////////
	// CONVERT NSDATA TO UIImage
	////////////////////////////////////

	UIImage *themeImage = [UIImage imageWithData:dataTheme]; 

	////////////////////////////////////
	// CREATE GPUImagePictures from SHAPE & THEME
	////////////////////////////////////

	GPUImagePicture *shapePicture = [[GPUImagePicture alloc] initWithImage:shapeImage smoothlyScaleOutput:YES];
	GPUImagePicture *themePicture = [[GPUImagePicture alloc] initWithImage:themeImage smoothlyScaleOutput:YES];
		 
	////////////////////////////////////
	// ADD SHAPE & THEME TO FRAME FILTER & PROCESS
	////////////////////////////////////

	[shapePicture addTarget:frameFilter];	 
	[themePicture addTarget:frameFilter];		 

	[frameFilter useNextFrameForImageCapture];

	[shapePicture processImage];
	[themePicture processImage]; 

	////////////////////////////////////
	// GET COMBINED SHAPE & THEME IMAGE
	//////////////////////////////////// 
	 
	UIImage *frameImage = [frameFilter imageFromCurrentFramebuffer];

	////////////////////////////////////
	// CREATE FRAME VIEW
	//////////////////////////////////// 
	 
	if (self.frameView == nil)
	{
		self.frameView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, intMediaWidth, intMediaHeight)]; 
	}	

	////////////////////////////////////
	// ADD IMAGE TO FRAME VIEW
	////////////////////////////////////
		 
	[self.frameView setImage:frameImage];		

	////////////////////////////////////
	// ADD VIEW TO MEDIA MASK
	////////////////////////////////////

	if (self.mediaFrameEnabled != YES)
	{
		////////////////////////////////////
		// ADD FRAME VIEW TO MASK
		////////////////////////////////////
		
		[self.mediaMask addSubview:self.frameView];
		self.mediaMaskEnabled = YES;
	}

	self.mediaFrameEnabled = YES;
}

- (void) changeFrame_OLD:(CDVInvokedUrlCommand *)command {

	///////////////////////////////////////// 
	// SET VARS
	/////////////////////////////////////////	

	NSDictionary *options = [command.arguments objectAtIndex: 0];
  	NSError* error = nil;

	NSString * strFrameShapeURL = [options objectForKey:@"frameShapeURL"];
	NSString * strFrameThemeURL = [options objectForKey:@"frameThemeURL"];

	////////////////////////////////////
	// CREATE CUSTOM SHADER STRING
	////////////////////////////////////

	NSString *const kShaderString = SHADER_STRING
	(	
		precision mediump float;
 
		varying highp vec2 textureCoordinate;
		varying highp vec2 textureCoordinate2;
 
		uniform sampler2D inputImageTexture;
		uniform sampler2D inputImageTexture2; 
 
		void main() 
		{ 
		vec4 shape = texture2D(inputImageTexture, textureCoordinate);
		vec4 theme = texture2D(inputImageTexture2, textureCoordinate2);

		gl_FragColor = shape;		
		
		if (shape.x <= 0.2) 
		{ 					
			gl_FragColor = theme; 
		}
		else if (shape.x >= 0.8) 
		{
			gl_FragColor = vec4(0.0, 0.0, 0.0, 0.5);		
		}   
		}
	);  

	////////////////////////////////////
	// GET SHAPE FILE FROM URL as NSDATA
	////////////////////////////////////
		
	NSData* dataShape = [NSData dataWithContentsOfURL:[NSURL URLWithString:strFrameShapeURL] options:NSDataReadingUncached error:&error];
	if (error) {
		NSLog(@"%@", [error localizedDescription]);			
	} else {
		NSLog(@"Shape of size %i has loaded successfully!", dataShape.length);			
	}

	////////////////////////////////////
	// CONVERT NSDATA TO UIImage
	////////////////////////////////////

	UIImage *shapeImage = [UIImage imageWithData:dataShape];

	////////////////////////////////////
	// GET THEME FILE FROM URL as NSDATA
	////////////////////////////////////

	NSData* dataTheme = [NSData dataWithContentsOfURL:[NSURL URLWithString:strFrameThemeURL] options:NSDataReadingUncached error:&error];
	if (error) {
		NSLog(@"%@", [error localizedDescription]);			
	} else {
		NSLog(@"Theme of size %i has loaded successfully!", dataTheme.length);			
	}

	////////////////////////////////////
	// CONVERT NSDATA TO UIImage
	////////////////////////////////////

	UIImage *themeImage = [UIImage imageWithData:dataTheme]; 

	////////////////////////////////////
	// CONVERT Images to GPUImagePictures
	////////////////////////////////////

	GPUImagePicture *shapePicture = [[GPUImagePicture alloc] initWithImage:shapeImage smoothlyScaleOutput:YES];
	GPUImagePicture *themePicture = [[GPUImagePicture alloc] initWithImage:themeImage smoothlyScaleOutput:YES];
		 
	////////////////////////////////////
	// CREATE TWO INPUT FILTER
	////////////////////////////////////

	GPUImageTwoInputFilter * frameFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:kShaderString];

	////////////////////////////////////
	// ADD FILTER
	////////////////////////////////////

	[shapePicture addTarget:frameFilter];	 
	[themePicture addTarget:frameFilter];		 

	////////////////////////////////////
	// PROCESS IMAGE 
	////////////////////////////////////

	[frameFilter useNextFrameForImageCapture];
	[shapePicture processImage];
	[themePicture processImage];

	////////////////////////////////////
	// ADD TO VIEW
	////////////////////////////////////

	UIImage *framePicture = [frameFilter imageFromCurrentFramebuffer];
	[self.frameView setImage:framePicture];		
		
 }

 - (void) changeFilter:(CDVInvokedUrlCommand *)command {

 	///////////////////////////////////////// 
	// SET VARS
	/////////////////////////////////////////	

	NSDictionary *options = [command.arguments objectAtIndex: 0];
  
	int intFilterID = [[options objectForKey:@"filterID"] integerValue];

	///////////////////////////////////////// 
	// SELECT FILTER
	/////////////////////////////////////////	

	switch (intFilterID)
	{
		case 0:
			mediaFilter = [[GPUImageBrightnessFilter alloc] init];		
			saveFilter = [[GPUImageBrightnessFilter alloc] init];	
			break;		
		case 1:
			mediaFilter = [[GPUImageSepiaFilter alloc] init];         
			[(GPUImageSepiaFilter *)mediaFilter setIntensity:0.5];   			

			saveFilter = [[GPUImageSepiaFilter alloc] init];         
			[(GPUImageSepiaFilter *)saveFilter setIntensity:0.5];   			
			break;
		case 2:
			mediaFilter = [[GPUImagePixellateFilter alloc] init];            
			[(GPUImagePixellateFilter *)mediaFilter setFractionalWidthOfAPixel:0.0125];
			
			saveFilter = [[GPUImagePixellateFilter alloc] init];            
			[(GPUImagePixellateFilter *)saveFilter setFractionalWidthOfAPixel:0.0125];			
			break;
		case 3:
			mediaFilter = [[GPUImagePolkaDotFilter alloc] init];            
			[(GPUImagePolkaDotFilter *)mediaFilter setFractionalWidthOfAPixel:0.0125];			

			saveFilter = [[GPUImagePolkaDotFilter alloc] init];            
			[(GPUImagePolkaDotFilter *)saveFilter setFractionalWidthOfAPixel:0.0125];			
			break;
		case 4:
			mediaFilter = [[GPUImageHalftoneFilter alloc] init];            
			[(GPUImageHalftoneFilter *)mediaFilter setFractionalWidthOfAPixel:0.0125];			

			saveFilter = [[GPUImageHalftoneFilter alloc] init];            
			[(GPUImageHalftoneFilter *)saveFilter setFractionalWidthOfAPixel:0.0125];			
			break;
		case 5:
			mediaFilter = [[GPUImageSaturationFilter alloc] init];            
			[(GPUImageSaturationFilter *)mediaFilter setSaturation:1.25];			

			saveFilter = [[GPUImageSaturationFilter alloc] init];            
			[(GPUImageSaturationFilter *)saveFilter setSaturation:1.25];			
			break;
		case 6:
			mediaFilter = [[GPUImageContrastFilter alloc] init];            
			[(GPUImageContrastFilter  *)mediaFilter setContrast:2.0];			

			saveFilter = [[GPUImageContrastFilter alloc] init];            
			[(GPUImageContrastFilter  *)saveFilter setContrast:2.0];			
			break;
		case 7:
			mediaFilter = [[GPUImageMonochromeFilter alloc] init];            
			[(GPUImageMonochromeFilter   *)mediaFilter setIntensity:0.5];			

			saveFilter = [[GPUImageMonochromeFilter alloc] init];            
			[(GPUImageMonochromeFilter   *)saveFilter setIntensity:0.5];			
			break;
		case 8:
			mediaFilter = [[GPUImageSketchFilter  alloc] init];            
			[(GPUImageSketchFilter  *)mediaFilter setEdgeStrength:0.25];			

			saveFilter = [[GPUImageSketchFilter  alloc] init];            
			[(GPUImageSketchFilter  *)saveFilter setEdgeStrength:0.25];			
			break;
		case 9:
			mediaFilter = [[GPUImageHazeFilter alloc] init];            
			[(GPUImageHazeFilter *)mediaFilter setDistance:0.2];			

			saveFilter = [[GPUImageHazeFilter alloc] init];            
			[(GPUImageHazeFilter *)saveFilter setDistance:0.2];			
			break;
		case 10:
			mediaFilter = [[GPUImageSobelEdgeDetectionFilter alloc] init];            
			[(GPUImageSobelEdgeDetectionFilter *)mediaFilter setEdgeStrength:0.25];			

			saveFilter = [[GPUImageSobelEdgeDetectionFilter alloc] init];            
			[(GPUImageSobelEdgeDetectionFilter *)saveFilter setEdgeStrength:0.25];			
			break;
		case 11:
			mediaFilter = [[GPUImageAdaptiveThresholdFilter  alloc] init];            
			[(GPUImageAdaptiveThresholdFilter *)mediaFilter setBlurRadiusInPixels:5];			

			saveFilter = [[GPUImageAdaptiveThresholdFilter  alloc] init];            
			[(GPUImageAdaptiveThresholdFilter *)saveFilter setBlurRadiusInPixels:5];			
			break;
		case 12:
			mediaFilter = [[GPUImageAverageLuminanceThresholdFilter  alloc] init];            
			[(GPUImageAverageLuminanceThresholdFilter *)mediaFilter setThresholdMultiplier:1];			

			saveFilter = [[GPUImageAverageLuminanceThresholdFilter  alloc] init];            
			[(GPUImageAverageLuminanceThresholdFilter *)saveFilter setThresholdMultiplier:1];			
			break;
		case 13:
			mediaFilter = [[GPUImageKuwaharaFilter alloc] init];            
			[(GPUImageKuwaharaFilter *)mediaFilter setRadius:round(3)];			

			saveFilter = [[GPUImageKuwaharaFilter alloc] init];            
			[(GPUImageKuwaharaFilter *)saveFilter setRadius:round(3)];			
			break;
		case 14:
			mediaFilter = [[GPUImageEmbossFilter alloc] init];            
			[(GPUImageEmbossFilter *)mediaFilter setIntensity:2];			

			saveFilter = [[GPUImageEmbossFilter alloc] init];            
			[(GPUImageEmbossFilter *)saveFilter setIntensity:2];			
			break;		
		case 15:
			mediaFilter = [[GPUImageVignetteFilter  alloc] init];            
			[(GPUImageVignetteFilter  *)mediaFilter setVignetteEnd:0.75];			

			saveFilter = [[GPUImageVignetteFilter  alloc] init];            
			[(GPUImageVignetteFilter  *)saveFilter setVignetteEnd:0.75];			
			break;
		default:
			NSLog (@"Integer out of range");
			break; 
	}
	
	///////////////////////////////////////// 
	// ADD FILTER TO TARGET
	/////////////////////////////////////////	

	if (mediaFile != nil)
	{
		[mediaFilter removeAllTargets];
		[mediaFile removeAllTargets];
		
		[mediaFile addTarget:mediaFilter];	
		[mediaFilter addTarget:self.mediaView];		
	}			
 }

 - (UIColor *)getUIColorObjectFromHexString:(NSString *)hexStr alpha:(CGFloat)alpha
{
  // Convert hex string to an integer
  unsigned int hexint = [self intFromHexString:hexStr];

  // Create color object, specifying alpha as well
  UIColor *color =
    [UIColor colorWithRed:((CGFloat) ((hexint & 0xFF0000) >> 16))/255
    green:((CGFloat) ((hexint & 0xFF00) >> 8))/255
    blue:((CGFloat) (hexint & 0xFF))/255
    alpha:alpha];

  return color;
}

- (unsigned int)intFromHexString:(NSString *)hexStr
{
  unsigned int hexInt = 0;

  // Create scanner
  NSScanner *scanner = [NSScanner scannerWithString:hexStr];

  // Tell scanner to skip the # character
  [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"#"]];

  // Scan hex value
  [scanner scanHexInt:&hexInt];

  return hexInt;
}

- (void)addLimitedPanGesturesToView:(UIView *)view {
	
	self.currentTag = view.tag;

    view.userInteractionEnabled = YES;  // Enable user interaction
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLimitedPanGesture:)];
    panGesture.delegate = self;
    [view addGestureRecognizer:panGesture];    
  
}

- (void)addMovementGesturesToView:(UIView *)view {
    view.userInteractionEnabled = YES;  // Enable user interaction
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panGesture.delegate = self;
    [view addGestureRecognizer:panGesture];
    
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    pinchGesture.delegate = self;
    [view addGestureRecognizer:pinchGesture];
}

- (void)handleLimitedPanGesture:(UIPanGestureRecognizer *)panGesture { 
    CGPoint translation = [panGesture translationInView:panGesture.view.superview];
    
    if (UIGestureRecognizerStateBegan == panGesture.state ||UIGestureRecognizerStateChanged == panGesture.state) {

		CGPoint newCenter = CGPointMake(panGesture.view.center.x + translation.x, panGesture.view.center.y + translation.y);

		int intItemOffset = (panGesture.view.frame.size.height / 2.0);

		int intMinY = self.mediaMask.frame.origin.y + intItemOffset;
		int intMaxY = self.mediaMask.frame.origin.y + self.mediaMask.frame.size.height - intItemOffset;

		 if (newCenter.y >= intMinY && newCenter.y <= intMaxY) {
			panGesture.view.center = newCenter;
			[panGesture setTranslation:CGPointZero inView:self.rootView];
		}       
    }    
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)panGesture { 
    CGPoint translation = [panGesture translationInView:panGesture.view.superview];
    
    if (UIGestureRecognizerStateBegan == panGesture.state ||UIGestureRecognizerStateChanged == panGesture.state) {

		panGesture.view.center = CGPointMake(panGesture.view.center.x + translation.x, panGesture.view.center.y + translation.y);
		[panGesture setTranslation:CGPointZero inView:self.rootView];		
    }    
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)pinchGesture {

    if (UIGestureRecognizerStateBegan == pinchGesture.state ||
        UIGestureRecognizerStateChanged == pinchGesture.state) {

        // Use the x or y scale, they should be the same for typical zooming (non-skewing)
        float currentScale = [[pinchGesture.view.layer valueForKeyPath:@"transform.scale.x"] floatValue];

        // Variables to adjust the max/min values of zoom
        float minScale = 1.0;
        float maxScale = 4.0;
        float zoomSpeed = .5;

        float deltaScale = pinchGesture.scale;

        // You need to translate the zoom to 0 (origin) so that you
        // can multiply a speed factor and then translate back to "zoomSpace" around 1
        deltaScale = ((deltaScale - 1) * zoomSpeed) + 1;

        // Limit to min/max size (i.e maxScale = 2, current scale = 2, 2/2 = 1.0)
        //  A deltaScale is ~0.99 for decreasing or ~1.01 for increasing
        //  A deltaScale of 1.0 will maintain the zoom size
        deltaScale = MIN(deltaScale, maxScale / currentScale);
        deltaScale = MAX(deltaScale, minScale / currentScale);

        CGAffineTransform zoomTransform = CGAffineTransformScale(pinchGesture.view.transform, deltaScale, deltaScale);
        pinchGesture.view.transform = zoomTransform;

        // Reset to 1 for scale delta's
        //  Note: not 0, or we won't see a size: 0 * width = 0 
        pinchGesture.scale = 1;
    }
} 

#pragma mark - Animated GIF Base methods

/////////////////////////////////////
// https://github.com/NSRare/NSGIF
/////////////////////////////////////

#define fileName     @"NSGIF"
#define timeInterval @(600)
#define tolerance    @(0.01)

typedef NS_ENUM(NSInteger, GIFSize) {
    GIFSizeVeryLow  = 2,
    GIFSizeLow      = 3,
    GIFSizeMedium   = 5,
    GIFSizeHigh     = 7,
    GIFSizeOriginal = 10 
};

- (void)optimalGIFfromURL:(NSURL*)videoURL loopCount:(int)loopCount completion:(void(^)(NSURL *GifURL))completionBlock {

    float delayTime = 0.02f;
    
    // Create properties dictionaries
    NSDictionary *fileProperties = [self filePropertiesWithLoopCount:loopCount];
    NSDictionary *frameProperties = [self framePropertiesWithDelayTime:delayTime];
    
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
    
    float videoWidth = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize].width;
    float videoHeight = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize].height;
    
    GIFSize optimalSize = GIFSizeMedium;
    if (videoWidth >= 1200 || videoHeight >= 1200)
        optimalSize = GIFSizeVeryLow;
    else if (videoWidth >= 800 || videoHeight >= 800)
        optimalSize = GIFSizeLow;
    else if (videoWidth >= 400 || videoHeight >= 400)
        optimalSize = GIFSizeMedium;
    else if (videoWidth < 400|| videoHeight < 400)
        optimalSize = GIFSizeHigh;
    
    // Get the length of the video in seconds
    float videoLength = (float)asset.duration.value/asset.duration.timescale;
    int framesPerSecond = 4;
    int frameCount = videoLength*framesPerSecond;
    
    // How far along the video track we want to move, in seconds.
    float increment = (float)videoLength/frameCount; 
    
    // Add frames to the buffer
    NSMutableArray *timePoints = [NSMutableArray array];
    for (int currentFrame = 0; currentFrame < frameCount; ++currentFrame) {
        float seconds = (float)increment * currentFrame;
        CMTime time = CMTimeMakeWithSeconds(seconds, [timeInterval intValue]);
        [timePoints addObject:[NSValue valueWithCMTime:time]];
    }
    
    // Prepare group for firing completion block
    dispatch_group_t gifQueue = dispatch_group_create();
    dispatch_group_enter(gifQueue);
    
    __block NSURL *gifURL;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        gifURL = [self createGIFforTimePoints:timePoints fromURL:videoURL fileProperties:fileProperties frameProperties:frameProperties frameCount:frameCount gifSize:optimalSize];
        
        dispatch_group_leave(gifQueue);
    });
    
    dispatch_group_notify(gifQueue, dispatch_get_main_queue(), ^{
        // Return GIF URL
        completionBlock(gifURL);
    });

}

- (void)createGIFfromURL:(NSURL*)videoURL framesPerSecond:(int)framesPerSecond playbackSpeed: (int)playbackSpeed maxDuration:(int)maxDuration loopCount:(int)loopCount completion:(void(^)(NSURL *GifURL))completionBlock {
    
    // Convert the video at the given URL to a GIF, and return the GIF's URL if it was created.
    // The frames are spaced evenly over the video, and each has the same duration.
    // delayTime is the amount of time for each frame in the GIF.
    // loopCount is the number of times the GIF will repeat. Defaults to 0, which means repeat infinitely.
    
	//if([[NSFileManager defaultManager] fileExistsAtPath:[videoURL path]]){

		//NSLog(@"File Exists");
	//} 

	AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
	float videoLength = (float)asset.duration.value/asset.duration.timescale;

	if (videoLength > maxDuration)
	{
		//framesPerSecond = 1.0;
		videoLength = maxDuration;
	}
   
    float fltFrameCount = videoLength * framesPerSecond; // ASSUMES SOURCE IS AT 30 fps
	int intFrameCount = (int) fltFrameCount;

    //float fltTotalFrames = videoLength * 30.0; // ASSUMES SOURCE IS AT 30 fps
	//float fltFrameCount = fltTotalFrames / framesPerSecond;
	//int intFrameCount = (int) fltFrameCount;

	float delayTime = (1.0 / framesPerSecond) / playbackSpeed; 

	//float delayTime = 1.0 / framesPerSecond / 10.0; 
    //float delayTime = 0.1; 
	
	//float delayTime = (1.0 / framesPerSecond) / 2.0; 
	//float delayTime = (1.0 / framesPerSecond) / playbackSpeed; 

    // Create properties dictionaries
    NSDictionary *fileProperties = [self filePropertiesWithLoopCount:loopCount];
    NSDictionary *frameProperties = [self framePropertiesWithDelayTime:delayTime];     
    
    // Get the length of the video in seconds    
	
	//float fltFrameCount = fltTotalFrames / framesPerSecond;
	//float fltFrameCount = framesPerSecond * videoLength;
	//int intFrameCount = (int) fltFrameCount;

    // How far along the video track we want to move, in seconds.
    float increment = (float) videoLength / intFrameCount;
	
	//NSLog(@"videoLength: %f, delayTime: %f, fltTotalFrames: %f, frameCount: %d", videoLength, delayTime, fltTotalFrames, intFrameCount);
	//NSLog(@"videoLength: %f, delayTime: %f, intFrameCount: %d", videoLength, delayTime, intFrameCount);

	// MAYBE LIMIT GIFS TO 15 SECS IN LENGTH!!!!

    // Add frames to the buffer
    NSMutableArray *timePoints = [NSMutableArray array];
    for (int currentFrame = 0; currentFrame < intFrameCount; ++currentFrame) {
        float seconds = (float)increment * currentFrame;
        CMTime time = CMTimeMakeWithSeconds(seconds, [timeInterval intValue]);
        [timePoints addObject:[NSValue valueWithCMTime:time]];
		
		//NSLog(@"Frame: %d, Time: %f", currentFrame, seconds);
    }

    // Prepare group for firing completion block
    dispatch_group_t gifQueue = dispatch_group_create();
    dispatch_group_enter(gifQueue);
    
    __block NSURL *gifURL;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        gifURL = [self createGIFforTimePoints:timePoints fromURL:videoURL fileProperties:fileProperties frameProperties:frameProperties frameCount:intFrameCount gifSize:GIFSizeMedium];

        dispatch_group_leave(gifQueue);
    });
    
    dispatch_group_notify(gifQueue, dispatch_get_main_queue(), ^{
        // Return GIF URL
        completionBlock(gifURL);
    });
    
}

- (void)createGIFfromURL_OLD:(NSURL*)videoURL withFrameCount:(int)frameCount delayTime:(float)delayTime loopCount:(int)loopCount completion:(void(^)(NSURL *GifURL))completionBlock {
    
    // Convert the video at the given URL to a GIF, and return the GIF's URL if it was created.
    // The frames are spaced evenly over the video, and each has the same duration.
    // delayTime is the amount of time for each frame in the GIF.
    // loopCount is the number of times the GIF will repeat. Defaults to 0, which means repeat infinitely.
    
	if([[NSFileManager defaultManager] fileExistsAtPath:[videoURL path]]){

		NSLog(@"File Exists");
	}

    // Create properties dictionaries
    NSDictionary *fileProperties = [self filePropertiesWithLoopCount:loopCount];
    NSDictionary *frameProperties = [self framePropertiesWithDelayTime:delayTime];
    
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];

    // Get the length of the video in seconds
    float videoLength = (float)asset.duration.value/asset.duration.timescale;
    
    // How far along the video track we want to move, in seconds.
    float increment = (float)videoLength/frameCount;
    
	//NSLog(@"Length: %f, Increment: %f", videoLength, increment);

	//NSError *error = nil;
	//AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
	//CGImageRef imageHandle = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:&error];

	//if (error) {
        //NSLog(@"Error copying image: %@", error);
    //}

    // Add frames to the buffer
    NSMutableArray *timePoints = [NSMutableArray array];
    for (int currentFrame = 0; currentFrame < frameCount; ++currentFrame) {
        float seconds = (float)increment * currentFrame;
        CMTime time = CMTimeMakeWithSeconds(seconds, [timeInterval intValue]);
        [timePoints addObject:[NSValue valueWithCMTime:time]];
		
		NSLog(@"Frame: %d, Time: %f", currentFrame, seconds);
    }

    // Prepare group for firing completion block
    dispatch_group_t gifQueue = dispatch_group_create();
    dispatch_group_enter(gifQueue);
    
    __block NSURL *gifURL;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        gifURL = [self createGIFforTimePoints:timePoints fromURL:videoURL fileProperties:fileProperties frameProperties:frameProperties frameCount:frameCount gifSize:GIFSizeMedium];

        dispatch_group_leave(gifQueue);
    });
    
    dispatch_group_notify(gifQueue, dispatch_get_main_queue(), ^{
        // Return GIF URL
        completionBlock(gifURL);
    });
    
}

- (NSURL *)createGIFforTimePoints_TEST:(NSArray *)timePoints fromURL:(NSURL *)url fileProperties:(NSDictionary *)fileProperties frameProperties:(NSDictionary *)frameProperties frameCount:(int)frameCount gifSize:(GIFSize)gifSize{

	NSString *timeEncodedFileName = [NSString stringWithFormat:@"%@-%lu.gif", fileName, (unsigned long)([[NSDate date] timeIntervalSince1970]*10.0)];
    NSString *temporaryFile = [NSTemporaryDirectory() stringByAppendingString:timeEncodedFileName];
    NSURL *fileURL = [NSURL fileURLWithPath:temporaryFile];

	NSLog(@"temporaryFile: %@", temporaryFile); 

    if (fileURL == nil)
	{
        return nil;
	}

	CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, kUTTypeGIF , frameCount, NULL);
    
	NSError *error = nil;
	AVURLAsset *asset = [AVURLAsset assetWithURL:url];
	AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];

	generator.appliesPreferredTrackTransform = YES; 
    
    //CMTime tol = CMTimeMakeWithSeconds([tolerance floatValue], [timeInterval intValue]);
    //generator.requestedTimeToleranceBefore = tol;
    //generator.requestedTimeToleranceAfter = tol;   

	CGImageRef imageHandle = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:&error];

	if (error) {
        NSLog(@"Error copying image: %@", error);
    }

	return fileURL;
}

- (NSURL *)createGIFforTimePoints:(NSArray *)timePoints fromURL:(NSURL *)url fileProperties:(NSDictionary *)fileProperties frameProperties:(NSDictionary *)frameProperties frameCount:(int)frameCount gifSize:(GIFSize)gifSize{
	
	NSString *timeEncodedFileName = [NSString stringWithFormat:@"%@-%lu.gif", fileName, (unsigned long)([[NSDate date] timeIntervalSince1970]*10.0)];
    NSString *temporaryFile = [NSTemporaryDirectory() stringByAppendingString:timeEncodedFileName];
    NSURL *fileURL = [NSURL fileURLWithPath:temporaryFile];

	//NSLog(@"temporaryFile: %@", temporaryFile); 

    if (fileURL == nil)
        return nil;

    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, kUTTypeGIF , frameCount, NULL);
    
    //AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
	//AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset]; 

	AVURLAsset *asset = [AVURLAsset assetWithURL:url];
	AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
	//CGImageRef imageHandle = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:&error];

	float videoLength = (float)asset.duration.value/asset.duration.timescale;        
    float increment = (float)videoLength/frameCount;    
	//NSLog(@"XXXX Length: %f, Increment: %f", videoLength, increment);

	//AVURLAsset *asset = [[AVURLAsset alloc] initWithURL: url options:nil];
	//AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];    
    
    generator.appliesPreferredTrackTransform = YES;
    
    //CMTime tol = CMTimeMakeWithSeconds([tolerance floatValue], [timeInterval intValue]);
    //generator.requestedTimeToleranceBefore = tol;
    //generator.requestedTimeToleranceAfter = tol; 
    
    NSError *error = nil;
    CGImageRef previousImageRefCopy = nil; 
	
	//CMTime time2 = [asset duration];
	//CMTime actualTime;

    for (NSValue *time in timePoints) {
        
		CGImageRef imageRef;
        
        //imageRef = (float)gifSize/10 != 1 ? createImageWithScale([generator copyCGImageAtTime:[time CMTimeValue] actualTime:nil error:&error], (float)gifSize/10) : [generator copyCGImageAtTime:[time CMTimeValue] actualTime:nil error:&error];
		imageRef = [generator copyCGImageAtTime:[time CMTimeValue] actualTime:nil error:&error];

		//CGImageRef imageRef = [generator copyCGImageAtTime:time2 actualTime:&actualTime error:&error];
		//CGImageRef imageRef = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:&error];

        if (error) {
            NSLog(@"Error copying image: %@", error);
        }
        if (imageRef) {
            CGImageRelease(previousImageRefCopy);
            previousImageRefCopy = CGImageCreateCopy(imageRef);
        } else if (previousImageRefCopy) {
            imageRef = CGImageCreateCopy(previousImageRefCopy);
        } else {
            NSLog(@"Error copying image and no previous frames to duplicate");
            return nil;
        }
        CGImageDestinationAddImage(destination, imageRef, (CFDictionaryRef)frameProperties);
        CGImageRelease(imageRef);
    }
    CGImageRelease(previousImageRefCopy);
    
    CGImageDestinationSetProperties(destination, (CFDictionaryRef)fileProperties);
    // Finalize the GIF
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to finalize GIF destination: %@", error);
        if (destination != nil) {
            CFRelease(destination);
        }
        return nil;
    }
    CFRelease(destination);
    
    return fileURL;
}

#pragma mark - Animated GIF Helpers

CGImageRef createImageWithScale(CGImageRef imageRef, float scale) {
    
    CGSize newSize = CGSizeMake(CGImageGetWidth(imageRef)*scale, CGImageGetHeight(imageRef)*scale);
    CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
    
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return nil;
    }
    
    // Set the quality level to use when rescaling
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, newSize.height);
    
    CGContextConcatCTM(context, flipVertical);
    // Draw into the context; this scales the image
    CGContextDrawImage(context, newRect, imageRef);
    
    //Release old image
    CFRelease(imageRef);
    // Get the resized image from the context and a UIImage
    imageRef = CGBitmapContextCreateImage(context);
    
    UIGraphicsEndImageContext();
        
    return imageRef;
}

#pragma mark - Animated GIF Properties

- (NSDictionary *)filePropertiesWithLoopCount:(int)loopCount {
    return @{(NSString *)kCGImagePropertyGIFDictionary:
                @{(NSString *)kCGImagePropertyGIFLoopCount: @(loopCount)}
             };
}

- (NSDictionary *)framePropertiesWithDelayTime:(float)delayTime {

    return @{(NSString *)kCGImagePropertyGIFDictionary:
                @{(NSString *)kCGImagePropertyGIFDelayTime: @(delayTime)},
                (NSString *)kCGImagePropertyColorModel:(NSString *)kCGImagePropertyColorModelRGB
            };
}

@end

@interface GPUImageMoviePlus () <AVPlayerItemOutputPullDelegate>
{
    BOOL audioEncodingIsFinished, videoEncodingIsFinished;
    GPUImageMovieWriter *synchronizedMovieWriter;
    AVAssetReader *reader;
    AVPlayerItemVideoOutput *playerItemOutput;

	#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
		CADisplayLink *displayLink;
	#else
		CVDisplayLinkRef displayLink;
	#endif

    CMTime previousFrameTime, processingFrameTime;
    CFAbsoluteTime previousActualFrameTime;
    BOOL keepLooping;

    GLuint luminanceTexture, chrominanceTexture;

    GLProgram *yuvConversionProgram;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    const GLfloat *_preferredConversion;
    
    BOOL isFullYUVRange;

    int imageBufferWidth, imageBufferHeight;
}

- (void)processAsset;

@end

@implementation GPUImageMoviePlus

@synthesize url = _url;
@synthesize asset = _asset;
@synthesize runBenchmark = _runBenchmark;
@synthesize playAtActualSpeed = _playAtActualSpeed;
@synthesize delegate = _delegate;
@synthesize shouldRepeat = _shouldRepeat;

@synthesize pause = _pause;
@synthesize stop = _stop;

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithURL:(NSURL *)url;
{
    if (!(self = [super init])) 
    {
        return nil;
    }

    [self yuvConversionSetup];

    self.url = url;
    self.asset = nil;

    return self;
}

- (id)initWithAsset:(AVAsset *)asset;
{
    if (!(self = [super init])) 
    {
      return nil;
    }
    
    [self yuvConversionSetup];

    self.url = nil;
    self.asset = asset;

    return self;
}

- (id)initWithPlayerItem:(AVPlayerItem *)playerItem;
{
    if (!(self = [super init]))
    {
        return nil;
    }

    [self yuvConversionSetup];

    self.url = nil;
    self.asset = nil;
    self.playerItem = playerItem;

    return self;
}

- (void)yuvConversionSetup;
{
    if ([GPUImageContext supportsFastTextureUpload])
    {
        runSynchronouslyOnVideoProcessingQueue(^{
            [GPUImageContext useImageProcessingContext];

            _preferredConversion = kColorConversion709;
            isFullYUVRange       = YES;
            yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];

            if (!yuvConversionProgram.initialized)
            {
                [yuvConversionProgram addAttribute:@"position"];
                [yuvConversionProgram addAttribute:@"inputTextureCoordinate"];

                if (![yuvConversionProgram link])
                {
                    NSString *progLog = [yuvConversionProgram programLog];
                    NSLog(@"Program link log: %@", progLog);
                    NSString *fragLog = [yuvConversionProgram fragmentShaderLog];
                    NSLog(@"Fragment shader compile log: %@", fragLog);
                    NSString *vertLog = [yuvConversionProgram vertexShaderLog];
                    NSLog(@"Vertex shader compile log: %@", vertLog);
                    yuvConversionProgram = nil;
                    NSAssert(NO, @"Filter shader link failed");
                }
            }

            yuvConversionPositionAttribute = [yuvConversionProgram attributeIndex:@"position"];
            yuvConversionTextureCoordinateAttribute = [yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
            yuvConversionLuminanceTextureUniform = [yuvConversionProgram uniformIndex:@"luminanceTexture"];
            yuvConversionChrominanceTextureUniform = [yuvConversionProgram uniformIndex:@"chrominanceTexture"];
            yuvConversionMatrixUniform = [yuvConversionProgram uniformIndex:@"colorConversionMatrix"];

            [GPUImageContext setActiveShaderProgram:yuvConversionProgram];

            glEnableVertexAttribArray(yuvConversionPositionAttribute);
            glEnableVertexAttribArray(yuvConversionTextureCoordinateAttribute);
        });
    }
}

- (void)dealloc
{
    [playerItemOutput setDelegate:nil queue:nil];
    
    // Moved into endProcessing
    //if (self.audioPlayerItem && (displayLink != nil))
    //{
    //    [displayLink invalidate]; // remove from all run loops
    //    displayLink = nil;
    //}
}

#pragma mark -
#pragma mark Movie processing

- (void)enableSynchronizedEncodingUsingMovieWriter:(GPUImageMovieWriter *)movieWriter;
{
    synchronizedMovieWriter = movieWriter;
    movieWriter.encodingLiveVideo = NO;
}

- (void)startProcessing
{
    if( self.playerItem ) {
        [self processPlayerItem];
        return;
    }
    if(self.url == nil)
    {
      [self processAsset];
      return;
    }
    
    if (_shouldRepeat) keepLooping = YES;
    
    previousFrameTime = kCMTimeZero;
    previousActualFrameTime = CFAbsoluteTimeGetCurrent();
  
    NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *inputAsset = [[AVURLAsset alloc] initWithURL:self.url options:inputOptions];
    
    GPUImageMoviePlus __block *blockSelf = self;
    
    [inputAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler: ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            AVKeyValueStatus tracksStatus = [inputAsset statusOfValueForKey:@"tracks" error:&error];
            if (tracksStatus != AVKeyValueStatusLoaded)
            {
                return;
            }
            blockSelf.asset = inputAsset;
            [blockSelf processAsset];
            blockSelf = nil;
        });
    }];
}

- (AVAssetReader*)createAssetReader
{
    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];

    NSMutableDictionary *outputSettings = [NSMutableDictionary dictionary];
    if ([GPUImageContext supportsFastTextureUpload]) {
        [outputSettings setObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        isFullYUVRange = YES;
    }
    else {
        [outputSettings setObject:@(kCVPixelFormatType_32BGRA) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        isFullYUVRange = NO;
    }
    
    // Maybe set alwaysCopiesSampleData to NO on iOS 5.0 for faster video decoding
    AVAssetReaderTrackOutput *readerVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[[self.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] outputSettings:outputSettings];
    readerVideoTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:readerVideoTrackOutput];

    NSArray *audioTracks = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    BOOL shouldRecordAudioTrack = (([audioTracks count] > 0) && (self.audioEncodingTarget != nil) );
    AVAssetReaderTrackOutput *readerAudioTrackOutput = nil;

    if (shouldRecordAudioTrack)
    {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        [self.audioEncodingTarget setShouldInvalidateAudioSampleWhenDone:YES];
#else
#warning Missing OSX implementation
#endif
        
        // This might need to be extended to handle movies with more than one audio track
        AVAssetTrack* audioTrack = [audioTracks objectAtIndex:0];
        readerAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:nil];
        readerAudioTrackOutput.alwaysCopiesSampleData = NO;
        [assetReader addOutput:readerAudioTrackOutput];
    }

    return assetReader;
}

- (void)processAsset
{
	////////////////////////////////
	//NSError *error;	
	//self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:self.url error:&error];	
    //self.audioPlayer.numberOfLoops = 0;		
	//[self.audioPlayer setEnableRate:YES];
	//[self.audioPlayer setRate:0.90f];
	//[self.audioPlayer play];

	////////////////////////////////

    reader = [self createAssetReader];

    AVAssetReaderOutput *readerVideoTrackOutput = nil;
    AVAssetReaderOutput *readerAudioTrackOutput = nil;

    audioEncodingIsFinished = YES;
    for( AVAssetReaderOutput *output in reader.outputs ) {
        if( [output.mediaType isEqualToString:AVMediaTypeAudio] ) {
            audioEncodingIsFinished = NO;
            readerAudioTrackOutput = output;
        }
        else if( [output.mediaType isEqualToString:AVMediaTypeVideo] ) {
            readerVideoTrackOutput = output;
        }
    }

    if ([reader startReading] == NO) 
    {
            NSLog(@"Error reading from file at URL: %@", self.url);
        return;
    }

    __unsafe_unretained GPUImageMoviePlus *weakSelf = self;

    if (synchronizedMovieWriter != nil)
    {
        [synchronizedMovieWriter setVideoInputReadyCallback:^{
            BOOL success = [weakSelf readNextVideoFrameFromOutput:readerVideoTrackOutput];
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
            return success;
#endif
        }];

        [synchronizedMovieWriter setAudioInputReadyCallback:^{
            BOOL success = [weakSelf readNextAudioSampleFromOutput:readerAudioTrackOutput];
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
            return success;
#endif
        }];
        
        [synchronizedMovieWriter enableSynchronizationCallbacks];

    }
    else
    {
		float duration = self.asset.duration.value * 1.0f / self.asset.duration.timescale;
		self.duration = duration;

		int intCounter = 0;

		while (self.stop == NO) 
		{
			if (self.pause == NO)
			{
			    float current = processingFrameTime.value * 1.0f / processingFrameTime.timescale;
				self.currentTime = current;
				
				//NSLog(@"Current frame time : %f secs", self.currentTime);
				//NSLog(@"Frame: %d", intCounter);

				//[weakSelf readNextVideoFrameFromOutput:readerVideoTrackOutput counter: intCounter skipFrames: self.skipFrames];
				[weakSelf readNextVideoFrameFromOutput:readerVideoTrackOutput counter: intCounter];

				if (intCounter >= 30)
				{
					intCounter = 0;	
				}

				if ( (readerAudioTrackOutput) && (!audioEncodingIsFinished) )
				{
					[weakSelf readNextAudioSampleFromOutput:readerAudioTrackOutput];
				}

				if (reader.status == AVAssetReaderStatusCompleted) {
                
					self.stop = YES;
					break;
				}
			}

			intCounter += 1;
		}

		//while (reader.status == AVAssetReaderStatusReading && self.pause == NO && self.stop == NO)
        //while (reader.status == AVAssetReaderStatusReading && (!_shouldRepeat || keepLooping))
        //{
            //[weakSelf readNextVideoFrameFromOutput:readerVideoTrackOutput];

            //if ( (readerAudioTrackOutput) && (!audioEncodingIsFinished) )
            //{
                    //[weakSelf readNextAudioSampleFromOutput:readerAudioTrackOutput];
            //}
        //}

        if (reader.status == AVAssetReaderStatusCompleted || self.stop == YES) {
                
            [reader cancelReading];

            if (keepLooping) {
                reader = nil;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self startProcessing];
                });
            } else {
                [weakSelf endProcessing];
            }

        }
    }
}

- (void)processPlayerItem
{
    runSynchronouslyOnVideoProcessingQueue(^{
        
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
        [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [displayLink setPaused:YES];
#else
        // Suggested implementation: use CVDisplayLink http://stackoverflow.com/questions/14158743/alternative-of-cadisplaylink-for-mac-os-x
        CGDirectDisplayID   displayID = CGMainDisplayID();
        CVReturn            error = kCVReturnSuccess;
        error = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
        if (error)
        {
            NSLog(@"DisplayLink created with error:%d", error);
            displayLink = NULL;
        }
        CVDisplayLinkSetOutputCallback(displayLink, renderCallback, (__bridge void *)self);
        CVDisplayLinkStop(displayLink);
#endif

        dispatch_queue_t videoProcessingQueue = [GPUImageContext sharedContextQueue];
        NSMutableDictionary *pixBuffAttributes = [NSMutableDictionary dictionary];
        if ([GPUImageContext supportsFastTextureUpload]) {
            [pixBuffAttributes setObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        }
        else {
            [pixBuffAttributes setObject:@(kCVPixelFormatType_32BGRA) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        }
        playerItemOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
        [playerItemOutput setDelegate:self queue:videoProcessingQueue];

        [_playerItem addOutput:playerItemOutput];
        [playerItemOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:0.1];
    });
}

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
	// Restart display link.
	[displayLink setPaused:NO];
#else
    CVDisplayLinkStart(displayLink);
#endif
}

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
- (void)displayLinkCallback:(CADisplayLink *)sender
{
	/*
	 The callback gets called once every Vsync.
	 Using the display link's timestamp and duration we can compute the next time the screen will be refreshed, and copy the pixel buffer for that time
	 This pixel buffer can then be processed and later rendered on screen.
	 */
	// Calculate the nextVsync time which is when the screen will be refreshed next.
	CFTimeInterval nextVSync = ([sender timestamp] + [sender duration]);

	CMTime outputItemTime = [playerItemOutput itemTimeForHostTime:nextVSync];

    [self processPixelBufferAtTime:outputItemTime];

}
#else
static CVReturn renderCallback(CVDisplayLinkRef displayLink,
                               const CVTimeStamp *inNow,
                               const CVTimeStamp *inOutputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags *flagsOut,
                               void *displayLinkContext)
{
    // Sample code taken from here https://developer.apple.com/library/mac/samplecode/AVGreenScreenPlayer/Listings/AVGreenScreenPlayer_GSPlayerView_m.html
    
    GPUImageMoviePlus *self = (__bridge GPUImageMoviePlus *)displayLinkContext;
    AVPlayerItemVideoOutput *playerItemOutput = self->playerItemOutput;
    
    
    // The displayLink calls back at every vsync (screen refresh)
    // Compute itemTime for the next vsync
    CMTime outputItemTime = [playerItemOutput itemTimeForCVTimeStamp:*inOutputTime];
    
    [self processPixelBufferAtTime:outputItemTime];
    
    return kCVReturnSuccess;
}
#endif

- (void)processPixelBufferAtTime:(CMTime)outputItemTime {
    if ([playerItemOutput hasNewPixelBufferForItemTime:outputItemTime]) {
        __unsafe_unretained GPUImageMoviePlus *weakSelf = self;
        CVPixelBufferRef pixelBuffer = [playerItemOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
        if( pixelBuffer )
            runSynchronouslyOnVideoProcessingQueue(^{
                [weakSelf processMovieFrame:pixelBuffer withSampleTime:outputItemTime];
                CFRelease(pixelBuffer);
            });
    }
}

- (BOOL)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput counter:(int *) intCounter;
{
    if (reader.status == AVAssetReaderStatusReading && ! videoEncodingIsFinished)
    {
        CMSampleBufferRef sampleBufferRef = [readerVideoTrackOutput copyNextSampleBuffer];
        if (sampleBufferRef) 
        {
            //NSLog(@"read a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef))));
            if (_playAtActualSpeed)
            {
                // Do this outside of the video processing queue to not slow that down while waiting
                CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef);
                CMTime differenceFromLastFrame = CMTimeSubtract(currentSampleTime, previousFrameTime);
                CFAbsoluteTime currentActualTime = CFAbsoluteTimeGetCurrent();
                
                CGFloat frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame);
                CGFloat actualTimeDifference = currentActualTime - previousActualFrameTime;
                
				//NSLog(@"frameTimeDifference %f, actualTimeDifference %f", frameTimeDifference, actualTimeDifference);

                if (frameTimeDifference > actualTimeDifference)
                {					
                    usleep(1000000.0 * (frameTimeDifference - actualTimeDifference));		
					//[self.audioPlayer setRate:0.90f];		
                }
                
                previousFrameTime = currentSampleTime;
                previousActualFrameTime = CFAbsoluteTimeGetCurrent();
            }
			
			//BOOL skipFrames = NO;
			BOOL bolProcessFrame = YES;

			if (self.framesPerSecond < 30)
			{
				bolProcessFrame = NO;

				//int intSkipper = 30.0 / self.framesPerSecond;

				if (self.frameSkipper >= self.skipRate)
				{
					bolProcessFrame = YES;		
					self.frameSkipper = 1;	
				}
				else
				{
					self.frameSkipper += 1;
				}

				//if (intCounter == 5 || intCounter == 10 || intCounter == 15 || intCounter == 20 || intCounter == 25)
				//if (30 / self.framesPerSecond % intCounter == 1)
				//{
					//bolProcessFrame = YES;			
				//}
			}

			if (bolProcessFrame == YES)
			{
				__unsafe_unretained GPUImageMoviePlus *weakSelf = self;
				runSynchronouslyOnVideoProcessingQueue(^{
					[weakSelf processMovieFrame:sampleBufferRef];
					CMSampleBufferInvalidate(sampleBufferRef);
					CFRelease(sampleBufferRef); 
				});
			}			

            return YES;
        }
        else
        {
            if (!keepLooping) {
                videoEncodingIsFinished = YES;
                if( videoEncodingIsFinished && audioEncodingIsFinished )
                    [self endProcessing];
            }
        }
    }
    else if (synchronizedMovieWriter != nil)
    {
        if (reader.status == AVAssetReaderStatusCompleted)
        {
            [self endProcessing];
        }
    }
    return NO;
}

- (BOOL)readNextAudioSampleFromOutput:(AVAssetReaderOutput *)readerAudioTrackOutput;
{
    if (reader.status == AVAssetReaderStatusReading && ! audioEncodingIsFinished)
    {
        CMSampleBufferRef audioSampleBufferRef = [readerAudioTrackOutput copyNextSampleBuffer];
        if (audioSampleBufferRef)
        {
            //NSLog(@"read an audio frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, CMSampleBufferGetOutputPresentationTimeStamp(audioSampleBufferRef))));
            [self.audioEncodingTarget processAudioBuffer:audioSampleBufferRef];
            CFRelease(audioSampleBufferRef);
            return YES;
        }
        else
        {
            if (!keepLooping) {
                audioEncodingIsFinished = YES;
                if( videoEncodingIsFinished && audioEncodingIsFinished )
                    [self endProcessing];
            }
        }
    }
    else if (synchronizedMovieWriter != nil)
    {
        if (reader.status == AVAssetReaderStatusCompleted || reader.status == AVAssetReaderStatusFailed ||
            reader.status == AVAssetReaderStatusCancelled)
        {
            [self endProcessing];
        }
    }
    return NO;
}

- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer; 
{
//    CMTimeGetSeconds
//    CMTimeSubtract
    
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(movieSampleBuffer);
    CVImageBufferRef movieFrame = CMSampleBufferGetImageBuffer(movieSampleBuffer);

    processingFrameTime = currentSampleTime;
    [self processMovieFrame:movieFrame withSampleTime:currentSampleTime];
}

- (float)progress
{
    if ( AVAssetReaderStatusReading == reader.status )
    {
        float current = processingFrameTime.value * 1.0f / processingFrameTime.timescale;
        float duration = self.asset.duration.value * 1.0f / self.asset.duration.timescale;
        return current / duration;
    }
    else if ( AVAssetReaderStatusCompleted == reader.status )
    {
        return 1.f;
    }
    else
    {
        return 0.f;
    }
}

- (void)processMovieFrame:(CVPixelBufferRef)movieFrame withSampleTime:(CMTime)currentSampleTime
{
    int bufferHeight = (int) CVPixelBufferGetHeight(movieFrame);
    int bufferWidth = (int) CVPixelBufferGetWidth(movieFrame);

	//NSLog(@"Height: %d, Width: %d", bufferHeight, bufferWidth);    
	

    CFTypeRef colorAttachments = CVBufferGetAttachment(movieFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL)
    {
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo)
        {
            if (isFullYUVRange)
            {
                _preferredConversion = kColorConversion601FullRange;
            }
            else
            {
                _preferredConversion = kColorConversion601;
            }
        }
        else
        {
            _preferredConversion = kColorConversion709;
        }
    }
    else
    {
        if (isFullYUVRange)
        {
            _preferredConversion = kColorConversion601FullRange;
        }
        else
        {
            _preferredConversion = kColorConversion601;
        }

    }
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();

    // Fix issue 1580
    [GPUImageContext useImageProcessingContext];
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        CVOpenGLESTextureRef luminanceTextureRef = NULL;
        CVOpenGLESTextureRef chrominanceTextureRef = NULL;
#else
        CVOpenGLTextureRef luminanceTextureRef = NULL;
        CVOpenGLTextureRef chrominanceTextureRef = NULL;
#endif

        //        if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
        if (CVPixelBufferGetPlaneCount(movieFrame) > 0) // Check for YUV planar inputs to do RGB conversion
        {
            
            // fix issue 2221
            CVPixelBufferLockBaseAddress(movieFrame,0);
        

            if ( (imageBufferWidth != bufferWidth) && (imageBufferHeight != bufferHeight) )
            {
                imageBufferWidth = bufferWidth;
                imageBufferHeight = bufferHeight;
            }

            CVReturn err;
            // Y-plane
            glActiveTexture(GL_TEXTURE4);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
#else
                err = CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, &luminanceTextureRef);
#endif
            }
            else
            {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
#else
                err = CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, &luminanceTextureRef);
#endif
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
            luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
#else
            luminanceTexture = CVOpenGLTextureGetName(luminanceTextureRef);
#endif
            glBindTexture(GL_TEXTURE_2D, luminanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

            // UV-plane
            glActiveTexture(GL_TEXTURE5);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
#else
                err = CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, &chrominanceTextureRef);
#endif
            }
            else
            {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
#else
                err = CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, &chrominanceTextureRef);
#endif
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
            chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
#else
            chrominanceTexture = CVOpenGLTextureGetName(chrominanceTextureRef);
#endif
            glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

//            if (!allTargetsWantMonochromeData)
//            {
                [self convertYUVToRGBOutput];
//            }

            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
            }
            
            [outputFramebuffer unlock];

            for (id<GPUImageInput> currentTarget in targets)
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
            }

            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
            CFRelease(luminanceTextureRef);
            CFRelease(chrominanceTextureRef);
        }
        else
        {
            // TODO: Mesh this with the new framebuffer cache
//            CVPixelBufferLockBaseAddress(movieFrame, 0);
//
//            CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, coreVideoTextureCache, movieFrame, NULL, GL_TEXTURE_2D, GL_RGBA, bufferWidth, bufferHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &texture);
//
//            if (!texture || err) {
//                NSLog(@"Movie CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
//                NSAssert(NO, @"Camera failure");
//                return;
//            }
//
//            outputTexture = CVOpenGLESTextureGetName(texture);
//            //        glBindTexture(CVOpenGLESTextureGetTarget(texture), outputTexture);
//            glBindTexture(GL_TEXTURE_2D, outputTexture);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//
//            for (id<GPUImageInput> currentTarget in targets)
//            {
//                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
//                NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
//
//                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
//                [currentTarget setInputTexture:outputTexture atIndex:targetTextureIndex];
//
//                [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
//            }
//
//            CVPixelBufferUnlockBaseAddress(movieFrame, 0);
//            CVOpenGLESTextureCacheFlush(coreVideoTextureCache, 0);
//            CFRelease(texture);
//            
//            outputTexture = 0;
        }
    }
    else
    {
        // Upload to texture
        CVPixelBufferLockBaseAddress(movieFrame, 0);
        
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(bufferWidth, bufferHeight) textureOptions:self.outputTextureOptions onlyTexture:YES];

        glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
        // Using BGRA extension to pull in video frame data directly
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     self.outputTextureOptions.internalFormat,
                     bufferWidth,
                     bufferHeight,
                     0,
                     self.outputTextureOptions.format,
                     self.outputTextureOptions.type,
                     CVPixelBufferGetBaseAddress(movieFrame));
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
        }
        
        [outputFramebuffer unlock];
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
        }
        CVPixelBufferUnlockBaseAddress(movieFrame, 0);
    }
    
    if (_runBenchmark)
    {
        CFAbsoluteTime currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime);
        //NSLog(@"Current frame time : %f ms", 1000.0 * currentFrameTime);
		NSLog(@"YO MAMA!!!  Current frame time : %f ms", 1000.0 * currentFrameTime);
    }
}

- (void)endProcessing;
{
    keepLooping = NO;
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    [displayLink setPaused:YES];
#else
    CVDisplayLinkStop(displayLink);
#endif

    for (id<GPUImageInput> currentTarget in targets)
    {
        [currentTarget endProcessing];
    }
    
    if (synchronizedMovieWriter != nil)
    {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        [synchronizedMovieWriter setVideoInputReadyCallback:^{return NO;}];
        [synchronizedMovieWriter setAudioInputReadyCallback:^{return NO;}];
#else
        // I'm not sure about this, meybe setting a nil will be more appropriate then an empty block
        [synchronizedMovieWriter setVideoInputReadyCallback:^{}];
        [synchronizedMovieWriter setAudioInputReadyCallback:^{}];
#endif
    }
    
    if (self.playerItem && (displayLink != nil))
    {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        [displayLink invalidate]; // remove from all run loops
        displayLink = nil;
#else
        CVDisplayLinkStop(displayLink);
        displayLink = NULL;
#endif
    }

    if ([self.delegate respondsToSelector:@selector(didCompletePlayingMovie)]) {
        [self.delegate didCompletePlayingMovie];
    }
    self.delegate = nil;
}

- (void)cancelProcessing
{
    if (reader) {
        [reader cancelReading];
    }
    [self endProcessing];
}

- (void)convertYUVToRGBOutput;
{
    [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(imageBufferWidth, imageBufferHeight) onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };

    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };

	glActiveTexture(GL_TEXTURE4);
	glBindTexture(GL_TEXTURE_2D, luminanceTexture);
	glUniform1i(yuvConversionLuminanceTextureUniform, 4);

    glActiveTexture(GL_TEXTURE5);
	glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
	glUniform1i(yuvConversionChrominanceTextureUniform, 5);

    glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);

    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
	glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (AVAssetReader*)assetReader {
    return reader;
}

- (BOOL)audioEncodingIsFinished {
    return audioEncodingIsFinished;
}

- (BOOL)videoEncodingIsFinished {
    return videoEncodingIsFinished;
}

@end
