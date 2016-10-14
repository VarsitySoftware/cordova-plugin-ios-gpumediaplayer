//
//  GPUVideo.m
//
//  Created by John Weaver on 10/12/2016
//
//

#import "GPUMediaPlayer.h"
#import <Accounts/Accounts.h>

#import <GPUImage/GPUImageMovieWriter.h>
#import <GPUImage/GPUImageFilter.h>
#import <GPUImage/GPUImageColorConversion.h>

@implementation GPUMediaPlayer  
@synthesize callbackId;

- (void) startVideo:(CDVInvokedUrlCommand *)command {
    
	self.callbackId = command.callbackId;

    NSDictionary *options = [command.arguments objectAtIndex: 0];
  
	NSString * strVideoURL = [options objectForKey:@"videoURL"];

	int intVideoPosX = [[options objectForKey:@"videoPosX"] integerValue];
    int intVideoPosY = [[options objectForKey:@"videoPosY"] integerValue];
    int intVideoWidth = [[options objectForKey:@"videoWidth"] integerValue];
    int intVideoHeight = [[options objectForKey:@"videoHeight"] integerValue];

	int intContainerPosX = [[options objectForKey:@"containerPosX"] integerValue];
    int intContainerPosY = [[options objectForKey:@"containerPosY"] integerValue];
    int intContainerWidth = [[options objectForKey:@"containerWidth"] integerValue];
    int intContainerHeight = [[options objectForKey:@"containerHeight"] integerValue];

	int intOrientation = [[options objectForKey:@"orientation"] integerValue];

	NSString * strCaptionText= [options objectForKey:@"captionText"];
	int intCaptionFontSize = [[options objectForKey:@"captionFontSize"] integerValue];

	NSURL* remoteURL = [NSURL URLWithString:strVideoURL];   

	self.rootView = [[[UIApplication sharedApplication] keyWindow] rootViewController].view;
		
	// HAVE TO DOWNLOAD FILE TO DEVICE IN ORDER TO PLAY!!!!
	//NSURL* localURL = [self saveLocalFileFromRemoteUrl: remoteURL extension:@"mp4"]; 
	self.localURL = [self saveLocalFileFromRemoteUrl: remoteURL extension:@"mp4"]; 

	movieFile = [[GPUVideoMovie alloc] initWithURL:self.localURL];		 
    //movieFile.runBenchmark = YES;
    movieFile.playAtActualSpeed = YES;
    movieFile.pause = NO;
	movieFile.stop = NO;
	movieFile.currentTimeInSecs = 0;

	self.viewContainer = [[UIView alloc] initWithFrame:CGRectMake(intVideoPosX, intVideoPosY, intVideoWidth, intVideoHeight)];
	[self addMovementGesturesToView:self.viewContainer];
	
	self.videoView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, intVideoWidth, intVideoHeight)];		
	[self.viewContainer addSubview:self.videoView];

	self.maskView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, intVideoWidth, intVideoHeight)];	
	self.maskView.backgroundColor = [UIColor clearColor];
	[self.viewContainer addSubview:self.maskView];

	filter = [[GPUImageBrightnessFilter alloc] init];

	////////////////////////////////////
	// CUSTOM FILTER
	////////////////////////////////////

	if (1 == 1)
	{
		[movieFile addTarget:filter];	
		[filter addTarget:self.videoView];		
	}
	
	if (1 == 1)  //FRAME
	{
		NSString *const kGPUImageColorDodgeBlendFragmentShaderString = SHADER_STRING
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

		NSError* error = nil;
		NSData* dataShape = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://192.168.1.2/shape_0.png"] options:NSDataReadingUncached error:&error];
		if (error) {
			NSLog(@"%@", [error localizedDescription]);			
		} else {
			NSLog(@"Data has loaded successfully.");
			NSLog(@"length: %i", dataShape.length); 
		}

		UIImage *shapeImage = [UIImage imageWithData:dataShape];
		//UIImage *shapeImage = [UIImage imageWithData:UIImageJPEGRepresentation(dataShape, 0)];
		NSData *jpgDataHighestCompressionQuality = UIImageJPEGRepresentation(shapeImage, 1.0);
		shapeImage = [UIImage imageWithData:jpgDataHighestCompressionQuality];

		////////////////////////////////
		// MAKE WHITE COLOR TRANSPARENT IN shape
		// THIS IS NECESSARY WHEN SAVING MASK
		//http://stackoverflow.com/questions/19443311/how-to-make-one-colour-transparent-in-uiimage
		// WTF is colorMasking var?!?
		// element #1 is R-MIN, element #2 is R-MAX, element #3 is G-MIN, element #4 is G-MAX, element #5 is B-MIN, element #6 is B-MAX
		////////////////////////////////

		shapeImage = [self changeWhiteColorTransparent: shapeImage];

		NSData* dataTheme = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://192.168.1.2/theme_0.png"] options:NSDataReadingUncached error:&error];
		if (error) {
			NSLog(@"%@", [error localizedDescription]);			
		} else {
			NSLog(@"Data has loaded successfully.");
			NSLog(@"length: %i", dataShape.length); 
		}

		UIImage *themeImage = [UIImage imageWithData:dataTheme]; 

		GPUImagePicture *shapePicture = [[GPUImagePicture alloc] initWithImage:shapeImage smoothlyScaleOutput:YES];
		GPUImagePicture *themePicture = [[GPUImagePicture alloc] initWithImage:themeImage smoothlyScaleOutput:YES];
		 
		GPUImageTwoInputFilter * filter3 = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:kGPUImageColorDodgeBlendFragmentShaderString];

		[shapePicture addTarget:filter3];	 
		[themePicture addTarget:filter3];		 

		[filter3 useNextFrameForImageCapture];
		[shapePicture processImage];
		[themePicture processImage];

		UIImage *framePicture = [filter3 imageFromCurrentFramebuffer];

		UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
		self.frameView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, intVideoWidth, intVideoHeight)]; 
		[self.frameView setImage:framePicture];		

		[self.maskView addSubview:self.frameView];
	}

	if (strCaptionText != nil)
	{	
	    //https://www.cocoanetics.com/2014/06/object-overlay-on-video/

		int intCaptionHeight = intCaptionFontSize + 10;
		self.captionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, intVideoHeight - intCaptionHeight, intVideoWidth, intCaptionHeight)];
		self.captionLabel.text = strCaptionText;		
		self.captionLabel.font = [UIFont systemFontOfSize:intCaptionFontSize];
		self.captionLabel.textColor = [UIColor whiteColor];
		self.captionLabel.tag = 1;
		self.captionLabel.hidden = NO;
		self.captionLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5f];
		self.captionLabel.textAlignment = UITextAlignmentCenter;
		[self.maskView addSubview:self.captionLabel];
	} 

	if (1 == 1)
	{	
		NSError* error = nil;
		NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://192.168.1.2/overlay.png"] options:NSDataReadingUncached error:&error];
		if (error) {
			NSLog(@"%@", [error localizedDescription]);			
		} else {
			NSLog(@"Data has loaded successfully.");
			NSLog(@"length: %i", data.length); 
		}

		UIImage *inputImage = [UIImage imageWithData:data];

		UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
		self.overlayView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, intVideoWidth, intVideoHeight)]; 
		[self.overlayView setImage:inputImage];
		[self.maskView addSubview:self.overlayView];
	}	

	if (intOrientation == 1) // PORTRAIT
	{		//[movieFile addTarget:self.videoView];
	}

	if (intOrientation == 2) // LANDSCAPE
	{
		[filter setInputRotation:kGPUImageRotateLeft atIndex:0];		
	}	
	
	self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(intContainerPosX, intContainerPosY, intContainerWidth, intContainerHeight)]; 	
	self.scrollView.backgroundColor = [UIColor blackColor]; 
	[self.scrollView addSubview:self.viewContainer];
	[self.rootView addSubview:self.scrollView];
	
	NSError *error;
	self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:self.localURL error:&error];	
    self.audioPlayer.numberOfLoops = 0;	
	[self.audioPlayer setEnableRate:YES];
	self.audioPlayer.delegate  = self;	
 
	[movieFile startProcessing];    
	[self.audioPlayer play];

	self.jsonResults = [ [NSMutableDictionary alloc]
        initWithObjectsAndKeys :
        nil, @"duration",
        nil, @"currentTime",                             
        nil
        ];

	NSTimer *playbackTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(showProgress:) userInfo:nil repeats:YES];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]  initWithTarget:self action:@selector(dismissKeyboard)];
	[self.rootView addGestureRecognizer:tap];	
}
 
 -(UIImage *)changeWhiteColorTransparent: (UIImage *)image
{
    CGImageRef rawImageRef = image.CGImage;

    const CGFloat colorMasking[6] = {228.0, 255.0, 228.0, 255.0, 228.0, 255.0};
	//const CGFloat colorMasking[6] = {0.8, 1.0, 0.8, 1.0, 0.8, 1.0}; 
	//const CGFloat colorMasking[6] = {255, 255, 255, 255, 255, 255};

    UIGraphicsBeginImageContext(image.size);
    CGImageRef maskedImageRef=CGImageCreateWithMaskingColors(rawImageRef, colorMasking);
    //{
        //if in iphone
        CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0, image.size.height);
        CGContextScaleCTM(UIGraphicsGetCurrentContext(), 1.0, -1.0);
    //}

    CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, image.size.width, image.size.height), maskedImageRef);
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    CGImageRelease(maskedImageRef);
    UIGraphicsEndImageContext();
    return result;
}

-(void)dismissKeyboard {
       //[aTextField resignFirstResponder];
	   //[self resizeTextField: textField];

	    UITextField* textField = [self.rootView viewWithTag:(self.currentTextFieldTag)];
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
    //NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:@"temp"] URLByAppendingPathExtension:@"mp4"];
	NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:@"temp"] URLByAppendingPathExtension:extension];
    NSLog(@"fileURL: %@", [fileURL path]);

	NSData *urlData = [NSData dataWithContentsOfURL:url];
    [urlData writeToURL:fileURL options:NSAtomicWrite error:nil];

	return fileURL;
}

-(void)showProgress:(NSTimer*)timer
{    
	//NSMutableDictionary *jsonResults = [[NSMutableDictionary alloc] init];
	
	//self.pluginResult = nil;

	int intCurrentTime = (movieFile.currentTime + 0.5);

	if (intCurrentTime > movieFile.currentTimeInSecs)
	{
		//float audioDuration = self.audioPlayer.duration;
		
		///////////////////////////////
		// ADJUST AUDIO RATE!!!!!
		///////////////////////////////

		float audioRemaining = self.audioPlayer.duration - self.audioPlayer.currentTime;
		float videoRemaining = self.audioPlayer.duration - movieFile.currentTime;

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
		 
		//[self.audioPlayer setRate:audioDelay];

		movieFile.currentTimeInSecs = intCurrentTime;
		//float roundedup = ceil(otherfloat);
		//NSLog(@"Time : %d secs, %f %f %f", movieFile.currentTimeInSecs, audioRemaining, videoRemaining, audioDiff);	

		//self.jsonResults = [ [NSDictionary alloc] initWithObjectsAndKeys :  @"true", @"success", nil];
	
		self.jsonResults[@"duration"] = [[NSNumber numberWithFloat:movieFile.duration] stringValue];
		self.jsonResults[@"currentTime"] = [[NSNumber numberWithFloat:movieFile.currentTime] stringValue];	

		self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.jsonResults];	
		[self.pluginResult setKeepCallbackAsBool:YES]; // here we tell Cordova not to cleanup the callback id after sendPluginResult()					
		[self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.callbackId];
	}
	
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    //NSLog(@"%d",flag);
	NSLog(@"FINISHED AUDIO!!!");    
}


- (void) pauseVideo:(CDVInvokedUrlCommand *)command {
	if (movieFile.stop == NO)
	{
		NSLog(@"PAUSE VIDEO!!!");    
		[self.audioPlayer pause];
		movieFile.pause = YES;
	}		
 }

 - (void) playVideo:(CDVInvokedUrlCommand *)command {
	if (movieFile.stop == NO)
	{
		NSLog(@"PLAY VIDEO!!!");    
		[self.audioPlayer play];
		movieFile.pause = NO;
	}	
 }
- (void) stopVideo:(CDVInvokedUrlCommand *)command {
	if (movieFile.stop == NO)
	{
		NSLog(@"STOP VIDEO!!!");    
		[self.audioPlayer stop];
		movieFile.stop = YES;				
	}  

	[self.viewContainer removeFromSuperview];
 }
  
 - (void) saveVideo:(CDVInvokedUrlCommand *)command {
	//[self captureView];

	self.maskView.opaque = NO;
    CGRect rect = [self.maskView bounds];

    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.maskView.layer renderInContext:context];   

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

	NSData *imageData = UIImagePNGRepresentation(img);
	UIImage * pngImage = [UIImage imageWithData:imageData];

	int len = 10;

	static NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *strRandomFileName = [NSMutableString stringWithCapacity: len];
    for (int i=0; i<len; i++) {
        [strRandomFileName appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }

	NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    //NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:@"temp1234"] URLByAppendingPathExtension:@"mov"];
	NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:strRandomFileName] URLByAppendingPathExtension:@"mov"];
    NSLog(@"fileURL: %@", [fileURL path]);
		
	//GPUImageMovie * videoFile = [[GPUImageMovie alloc] initWithURL:self.localURL];		 
	videoFile = [[GPUImageMovie alloc] initWithURL:self.localURL];		 
    videoFile.playAtActualSpeed = NO;

	//GPUImageOutput<GPUImageInput> *currentFilter = [[GPUImagePixellateFilter alloc] init];      	
	//[(GPUImagePixellateFilter *)currentFilter setFractionalWidthOfAPixel:0.0125];			      

	[saveFilter removeAllTargets];    

	[videoFile addTarget:saveFilter];  	

	//GPUImageOutput<GPUImageInput> *currentFilter = saveFilter;       
	//[videoFile addTarget:saveFilter];  	    
	 
	/////////////////////////////  
	//GPUImagePicture *overlay = [[GPUImagePicture alloc] initWithImage:pngImage smoothlyScaleOutput:YES];	 
	//overlay = [[GPUImagePicture alloc] initWithImage:pngImage smoothlyScaleOutput:YES];	 
	//[overlay processImage];    
	  
    //GPUImageBrightnessFilter *testFilter = [[GPUImageBrightnessFilter alloc] init];		
	//[overlay addTarget:testFilter];
	//[saveFilter addTarget:saveFilter];   

	//GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
	//overlayFilter = [[GPUImageOverlayBlendFilter alloc] init]; 	
	//[overlay addTarget:overlayFilter];
	//[overlay processImage];     

	//[videoFile addTarget:overlayFilter];  	
	 //blendFilter.mix = 1.0;      

	//[videoFile addTarget:saveFilter];  	   

	//[blendFilter useNextFrameForImageCapture];  
	//[saveFilter addTarget:blendFilter];
	//[overlay addTarget:blendFilter];  

	//[videoFile addTarget:saveFilter];  	    

	//GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];

	//blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
	//[saveFilter addTarget:blendFilter];  
	//[overlay addTarget:blendFilter];    

	//[blendFilter useNextFrameForImageCapture]; 
	//[videoFile addTarget:saveFilter];  	 

	//[overlay addTarget:saveFilter];  

	///////////////////////////// 

	// http://www.sunsetlakesoftware.com/forum/audio-problems-when-filtering-movie-file
	GPUImageAlphaBlendFilter *maskFilter = [[GPUImageAlphaBlendFilter alloc] init];    
    maskFilter.mix = 1.0;

	overlay = [[GPUImagePicture alloc] initWithImage:pngImage smoothlyScaleOutput:NO];	 
	[overlay processImage];
    [overlay addTarget:maskFilter atTextureLocation:1];
    [saveFilter addTarget:maskFilter]; 

	/////////////////////////////

	//GPUImageMovieWriter *movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:fileURL size:CGSizeMake(375.0, 210.0)];
	movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:fileURL size:CGSizeMake(375.0, 210.0)];
	movieWriter.shouldPassthroughAudio = YES;  
    videoFile.audioEncodingTarget = movieWriter;
    [videoFile enableSynchronizedEncodingUsingMovieWriter:movieWriter]; 

	//[saveFilter addTarget:movieWriter];  
	//[blendFilter addTarget:movieWriter];  
	[maskFilter addTarget:movieWriter];  

	//[movieWriter addTarget:overlay]; 
	 
	//GPUImageAlphaBlendFilter *overlayFilter = [[GPUImageAlphaBlendFilter alloc] init];

	//[saveFilter addTarget:overlayFilter atTextureLocation:0];
	//[overlay addTarget:overlayFilter atTextureLocation:1];

	//[overlayFilter useNextFrameForImageCapture]; 
	

	//[overlay useNextFrameForImageCapture];		
	//[overlay processImage];

	//GPUImageAlphaBlendFilter *overlayFilter = [[GPUImageAlphaBlendFilter alloc] init];
	//[saveFilter addTarget:overlayFilter atTextureLocation:0];
	//[overlay addTarget:overlayFilter atTextureLocation:1];
	//[overlayFilter prepareForImageCapture];
	/////////////////////////////

	[movieWriter startRecording];  
    [videoFile startProcessing]; 	

	self.jsonProgress = [ [NSMutableDictionary alloc]
        initWithObjectsAndKeys :
        nil, @"progress",        
        nil
        ];

	NSLog(@"startProcessing...");
	saveTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(saveProgress:) userInfo:nil repeats:YES];

	[movieWriter setCompletionBlock:^{
        [saveFilter removeTarget:movieWriter];
        [movieWriter finishRecording];
		  
		NSNumber *fileSizeValue = nil;
		NSError *fileSizeError = nil;
		[fileURL getResourceValue:&fileSizeValue forKey:NSURLFileSizeKey error:&fileSizeError];
		if (fileSizeValue) {
			NSLog(@"value for %@ is %@", fileURL, fileSizeValue);
		}
		else {
			NSLog(@"error getting size for url %@ error was %@", fileURL, fileSizeError);
		}

		usleep(1000000);  // SLEEP FOR 1 SEC TO GIVE PHONE TIME TO SAVE

		NSLog(@"Trying to save...");
		if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileURL.relativePath))
		{	
			UISaveVideoAtPathToSavedPhotosAlbum(fileURL.relativePath, nil, nil, nil);
			NSLog(@"Saved!!!");
		}
		else
		{
			NSLog(@"Error!!!");
		}		         
    }];
}

-(void)saveProgress:(NSTimer*)timer
{    
	float fltProgress = videoFile.progress; 	
	//NSLog(@"Progress: %f", fltProgress);	

	self.jsonProgress[@"progress"] = [[NSNumber numberWithFloat:fltProgress] stringValue];
	
	self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.jsonProgress];	
	[self.pluginResult setKeepCallbackAsBool:YES]; // here we tell Cordova not to cleanup the callback id after sendPluginResult()					
	[self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.callbackId];

	if (fltProgress >= .95)
	{
		[saveTimer invalidate];
		saveTimer = nil;
	}
}

 - (void) addSticker:(CDVInvokedUrlCommand *)command {
	
		NSDictionary *options = [command.arguments objectAtIndex: 0];
  
		int intStickerID = [[options objectForKey:@"stickerID"] integerValue];

		NSError* error = nil;
		NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://192.168.1.2/1f600.png"] options:NSDataReadingUncached error:&error];
		if (error) {
			NSLog(@"%@", [error localizedDescription]);			
		} else {
			NSLog(@"Data has loaded successfully.");
			NSLog(@"length: %i", data.length); 
		}

		UIImage *inputImage = [UIImage imageWithData:data];
		
		//UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
		UIImageView *v = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)]; 
		[v setImage:inputImage];
		v.tag = intStickerID;
		[self addLimitedPanGesturesToView:v];

		UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] init];
		[gestureRecognizer addTarget:self action:@selector(imgLongPressed:)];
		gestureRecognizer.delegate = self;
		[v addGestureRecognizer: gestureRecognizer];
		 
		//[self.videoView addSubview:v];  
		[self.maskView addSubview:v];
 }

  - (void) addLabel:(CDVInvokedUrlCommand *)command {
	
		NSLog(@"ADD LABEL!");

		NSDictionary *options = [command.arguments objectAtIndex: 0];  
  
		int intLabelID = [[options objectForKey:@"labelID"] integerValue]; 

		self.currentTextFieldTag = intLabelID;

		UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 90, 375, 30)];		
		textField.borderStyle = UITextBorderStyleNone; 
		textField.textAlignment = UITextAlignmentCenter;
		textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		[textField setBackgroundColor:[UIColor clearColor]];
		//[textField setBackgroundColor:[UIColor redColor]];
		//[textField setBackgroundColor:[UIColor greenColor]];
		[textField setTextColor:[UIColor whiteColor]];
		textField.tintColor = [UIColor whiteColor];
		textField.tag = intLabelID;
		textField.delegate = self;
		//textField.text = @"HELLO WORLD"; 

		[self addLimitedPanGesturesToView:textField];

		//[self.videoView addSubview:textField];
		[self.maskView addSubview:textField];

		UIResponder* nextResponder = [textField.superview viewWithTag:(textField.tag)];
        if (nextResponder) {
            [nextResponder becomeFirstResponder];
        }		 
		
 }

 - (void) updateLabel:(CDVInvokedUrlCommand *)command {

		NSDictionary *options = [command.arguments objectAtIndex: 0];
  
		int intLabelID = [[options objectForKey:@"labelID"] integerValue];
		int intLabelSize = [[options objectForKey:@"labelSize"] integerValue];
		NSString *strLabelColor = [options objectForKey:@"labelColor"];

		self.currentTextFieldTag = intLabelID;

		UIColor *color = [self getUIColorObjectFromHexString:strLabelColor alpha:1.0];
		
		UITextField * textField = (UITextField*)[self.videoView viewWithTag:intLabelID];
		[textField setTextColor:color];

		[textField setFont:[UIFont boldSystemFontOfSize:intLabelSize]];

		//CGRect frameRect = textField.frame;
		//frameRect.size.height = intLabelSize + 20; // <-- Specify the height you want here.
		//textField.frame = frameRect;

		[self resizeTextField: textField];		
 }

 - (void) updateSticker:(CDVInvokedUrlCommand *)command {

		NSDictionary *options = [command.arguments objectAtIndex: 0];
  
		int intStickerID = [[options objectForKey:@"stickerID"] integerValue];
		int intStickerSize = [[options objectForKey:@"stickerSize"] integerValue];
		NSString *strStickerColor = [options objectForKey:@"stickerColor"];

		UIColor *color = [self getUIColorObjectFromHexString:strStickerColor alpha:1.0];
		
		UIImageView * imageView = (UIImageView*)[self.videoView viewWithTag:intStickerID];
		imageView.backgroundColor = color;
		imageView.contentMode = UIViewContentModeScaleToFill;

		CGRect frameRect = imageView.frame;
		frameRect.size.height = intStickerSize + 20; // <-- Specify the height you want here.
		frameRect.size.width = intStickerSize + 20; // <-- Specify the height you want here.
		imageView.frame = frameRect;		
 }

 - (BOOL)textFieldDidBeginEditing:(UITextField *)textField {
		//NSLog(@"XXXXXXXXXXX");

		//CGFloat fixedWidth = textField.frame.size.width;
		//CGSize newSize = [textField sizeThatFits:CGSizeMake(fixedWidth, MAXFLOAT)];
		CGRect newFrame = textField.frame;
		//newFrame.origin.x = result1.origin.x;
		newFrame.size = CGSizeMake(375, newFrame.size.height);
		//newFrame.size = CGSizeMake(fmaxf(newSize.width, fixedWidth), newSize.height);
		textField.frame = newFrame;
		//textField.textAlignment = NSTextAlignmentLeft;
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

- (UIImage *)captureView { 
    
	self.maskView.opaque = NO;
    CGRect rect = [self.maskView bounds];

    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.maskView.layer renderInContext:context];   

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
		NSLog(@"tag: %i", view_.tag);
    }
    else if (sender.state == UIGestureRecognizerStateChanged)
    {

    }
    else if (sender.state == UIGestureRecognizerStateEnded)
    {
		 
    }
}

  - (void) changeFrame:(CDVInvokedUrlCommand *)command {

		NSDictionary *options = [command.arguments objectAtIndex: 0];
  
		//NSLog(@"XXXXXXXXX");
		NSString *const kGPUImageColorDodgeBlendFragmentShaderString = SHADER_STRING
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

		NSError* error = nil;
		NSData* dataShape = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://192.168.1.2/shape_1.png"] options:NSDataReadingUncached error:&error];
		if (error) {
			NSLog(@"%@", [error localizedDescription]);			
		} else {
			NSLog(@"Data has loaded successfully.");
			NSLog(@"length: %i", dataShape.length); 
		}

		UIImage *shapeImage = [UIImage imageWithData:dataShape];

		NSData* dataTheme = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://192.168.1.2/theme_1.png"] options:NSDataReadingUncached error:&error];
		if (error) {
			NSLog(@"%@", [error localizedDescription]);			
		} else {
			NSLog(@"Data has loaded successfully.");
			NSLog(@"length: %i", dataShape.length); 
		}

		UIImage *themeImage = [UIImage imageWithData:dataTheme]; 

		GPUImagePicture *shapePicture = [[GPUImagePicture alloc] initWithImage:shapeImage smoothlyScaleOutput:YES];
		GPUImagePicture *themePicture = [[GPUImagePicture alloc] initWithImage:themeImage smoothlyScaleOutput:YES];
		 
		//GPUImageColorDodgeBlendFilter * filter3 = [[GPUImageColorDodgeBlendFilter alloc] init];
		GPUImageTwoInputFilter * filter3 = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:kGPUImageColorDodgeBlendFragmentShaderString];

		[shapePicture addTarget:filter3];	 
		[themePicture addTarget:filter3];		 

		[filter3 useNextFrameForImageCapture];
		[shapePicture processImage];
		[themePicture processImage];

		UIImage *framePicture = [filter3 imageFromCurrentFramebuffer];
		[self.frameView setImage:framePicture];						

		//UIImageView* viewFrame = [self.rootView viewWithTag:300];

		//if (viewFrame)
		//{
			//NSLog(@"FRAME CHANGED!");
			//[viewFrame setImage:framePicture];		
		//}
		//else
		//{
			//NSLog(@"FRAME created!");
			//UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
			//UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, intWidth, intHeight)]; 
			//self.frameView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, intWidth, intHeight)]; 
			//self.frameView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 375, 210)]; 
			//self.frameView.tag = 300;
			//[self.frameView setImage:framePicture];		

			//UIImageView *iv = [[UIImageView alloc] initWithImage:framePicture];		
			//[self.videoView addSubview:self.frameView]; 	
		//}
		
 }

 - (void) changeFilter:(CDVInvokedUrlCommand *)command {

	NSLog(@"CHANGE FILTERS!!");   

	NSDictionary *options = [command.arguments objectAtIndex: 0];
  
	int intFilterID = [[options objectForKey:@"filterID"] integerValue];

	switch (intFilterID)
	{
		case 0:
			filter = [[GPUImageBrightnessFilter alloc] init];		
			saveFilter = [[GPUImageBrightnessFilter alloc] init];	
			break;		
		case 1:
			filter = [[GPUImageSepiaFilter alloc] init];         
			[(GPUImageSepiaFilter *)filter setIntensity:0.5];   			

			saveFilter = [[GPUImageSepiaFilter alloc] init];         
			[(GPUImageSepiaFilter *)saveFilter setIntensity:0.5];   			
			break;
		case 2:
			filter = [[GPUImagePixellateFilter alloc] init];            
			[(GPUImagePixellateFilter *)filter setFractionalWidthOfAPixel:0.0125];
			
			saveFilter = [[GPUImagePixellateFilter alloc] init];            
			[(GPUImagePixellateFilter *)saveFilter setFractionalWidthOfAPixel:0.0125];			
			break;
		case 3:
			filter = [[GPUImagePolkaDotFilter alloc] init];            
			[(GPUImagePolkaDotFilter *)filter setFractionalWidthOfAPixel:0.0125];			

			saveFilter = [[GPUImagePolkaDotFilter alloc] init];            
			[(GPUImagePolkaDotFilter *)saveFilter setFractionalWidthOfAPixel:0.0125];			
			break;
		case 4:
			filter = [[GPUImageHalftoneFilter alloc] init];            
			[(GPUImageHalftoneFilter *)filter setFractionalWidthOfAPixel:0.0125];			

			saveFilter = [[GPUImageHalftoneFilter alloc] init];            
			[(GPUImageHalftoneFilter *)saveFilter setFractionalWidthOfAPixel:0.0125];			
			break;
		case 5:
			filter = [[GPUImageSaturationFilter alloc] init];            
			[(GPUImageSaturationFilter *)filter setSaturation:1.25];			

			saveFilter = [[GPUImageSaturationFilter alloc] init];            
			[(GPUImageSaturationFilter *)saveFilter setSaturation:1.25];			
			break;
		case 6:
			filter = [[GPUImageContrastFilter alloc] init];            
			[(GPUImageContrastFilter  *)filter setContrast:2.0];			

			saveFilter = [[GPUImageContrastFilter alloc] init];            
			[(GPUImageContrastFilter  *)saveFilter setContrast:2.0];			
			break;
		case 7:
			filter = [[GPUImageMonochromeFilter alloc] init];            
			[(GPUImageMonochromeFilter   *)filter setIntensity:0.5];			

			saveFilter = [[GPUImageMonochromeFilter alloc] init];            
			[(GPUImageMonochromeFilter   *)saveFilter setIntensity:0.5];			
			break;
		case 8:
			filter = [[GPUImageSketchFilter  alloc] init];            
			[(GPUImageSketchFilter  *)filter setEdgeStrength:0.25];			

			saveFilter = [[GPUImageSketchFilter  alloc] init];            
			[(GPUImageSketchFilter  *)saveFilter setEdgeStrength:0.25];			
			break;
		case 9:
			filter = [[GPUImageHazeFilter alloc] init];            
			[(GPUImageHazeFilter *)filter setDistance:0.2];			

			saveFilter = [[GPUImageHazeFilter alloc] init];            
			[(GPUImageHazeFilter *)saveFilter setDistance:0.2];			
			break;
		case 10:
			filter = [[GPUImageSobelEdgeDetectionFilter alloc] init];            
			[(GPUImageSobelEdgeDetectionFilter *)filter setEdgeStrength:0.25];			

			saveFilter = [[GPUImageSobelEdgeDetectionFilter alloc] init];            
			[(GPUImageSobelEdgeDetectionFilter *)saveFilter setEdgeStrength:0.25];			
			break;
		case 11:
			filter = [[GPUImageAdaptiveThresholdFilter  alloc] init];            
			[(GPUImageAdaptiveThresholdFilter *)filter setBlurRadiusInPixels:5];			

			saveFilter = [[GPUImageAdaptiveThresholdFilter  alloc] init];            
			[(GPUImageAdaptiveThresholdFilter *)saveFilter setBlurRadiusInPixels:5];			
			break;
		case 12:
			filter = [[GPUImageAverageLuminanceThresholdFilter  alloc] init];            
			[(GPUImageAverageLuminanceThresholdFilter *)filter setThresholdMultiplier:1];			

			saveFilter = [[GPUImageAverageLuminanceThresholdFilter  alloc] init];            
			[(GPUImageAverageLuminanceThresholdFilter *)saveFilter setThresholdMultiplier:1];			
			break;
		case 13:
			filter = [[GPUImageKuwaharaFilter alloc] init];            
			[(GPUImageKuwaharaFilter *)filter setRadius:round(3)];			

			saveFilter = [[GPUImageKuwaharaFilter alloc] init];            
			[(GPUImageKuwaharaFilter *)saveFilter setRadius:round(3)];			
			break;
		case 14:
			filter = [[GPUImageEmbossFilter alloc] init];            
			[(GPUImageEmbossFilter *)filter setIntensity:2];			

			saveFilter = [[GPUImageEmbossFilter alloc] init];            
			[(GPUImageEmbossFilter *)saveFilter setIntensity:2];			
			break;		
		case 15:
			filter = [[GPUImageVignetteFilter  alloc] init];            
			[(GPUImageVignetteFilter  *)filter setVignetteEnd:0.75];			

			saveFilter = [[GPUImageVignetteFilter  alloc] init];            
			[(GPUImageVignetteFilter  *)saveFilter setVignetteEnd:0.75];			
			break;
		default:
			NSLog (@"Integer out of range");
			break;
	}

	[filter removeAllTargets];
	[movieFile removeAllTargets];

	[movieFile addTarget:filter];	
	[filter addTarget:self.videoView];		
			
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

		int intMinY = self.maskView.frame.origin.y + intItemOffset;
		int intMaxY = self.maskView.frame.origin.y + self.maskView.frame.size.height - intItemOffset;

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


@end

@interface GPUVideoMovie () <AVPlayerItemOutputPullDelegate>
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

@implementation GPUVideoMovie

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
    
    GPUVideoMovie __block *blockSelf = self;
    
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

    __unsafe_unretained GPUVideoMovie *weakSelf = self;

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

		while (self.stop == NO)
		{
			if (self.pause == NO)
			{
			    float current = processingFrameTime.value * 1.0f / processingFrameTime.timescale;
				self.currentTime = current;
				
				//NSLog(@"Current frame time : %f secs", self.currentTime);

				[weakSelf readNextVideoFrameFromOutput:readerVideoTrackOutput];

				if ( (readerAudioTrackOutput) && (!audioEncodingIsFinished) )
				{
					[weakSelf readNextAudioSampleFromOutput:readerAudioTrackOutput];
				}

				if (reader.status == AVAssetReaderStatusCompleted) {
                
					self.stop = YES;
					break;
				}
			}
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
    
    GPUVideoMovie *self = (__bridge GPUVideoMovie *)displayLinkContext;
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
        __unsafe_unretained GPUVideoMovie *weakSelf = self;
        CVPixelBufferRef pixelBuffer = [playerItemOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
        if( pixelBuffer )
            runSynchronouslyOnVideoProcessingQueue(^{
                [weakSelf processMovieFrame:pixelBuffer withSampleTime:outputItemTime];
                CFRelease(pixelBuffer);
            });
    }
}

- (BOOL)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput;
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

            __unsafe_unretained GPUVideoMovie *weakSelf = self;
            runSynchronouslyOnVideoProcessingQueue(^{
                [weakSelf processMovieFrame:sampleBufferRef];
                CMSampleBufferInvalidate(sampleBufferRef);
                CFRelease(sampleBufferRef);
            });

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
