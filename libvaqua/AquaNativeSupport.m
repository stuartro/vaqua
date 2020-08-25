/*
 * @(#)AquaNativeSupport.m
 *
 * Copyright (c) 2004-2007 Werner Randelshofer, Switzerland.
 * Copyright (c) 2014-2015 Alan Snyder.
 * All rights reserved.
 *
 * You may not use, copy or modify this software, except in
 * accordance with the license agreement you entered into with
 * Werner Randelshofer. For details see accompanying license terms.
 */

/**
 * Native code support for the VAqua look and feel.
 *
 * @version $Id$
 */

static int VERSION = 1;

#include <stdio.h>
#include <jni.h>
#include "org_violetlib_aqua_fc_OSXFile.h"
#include "org_violetlib_aqua_OSXSystemProperties.h"
#include "org_violetlib_aqua_AquaNativeSupport.h"

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <JavaNativeFoundation.h>

static JavaVM *vm;
static jint javaVersion;
static jobject synchronizeCallback;

@interface MyDefaultResponder : NSObject
- (void)defaultsChanged:(NSNotification *)notification;
@end
@implementation MyDefaultResponder
- (void)defaultsChanged:(NSNotification *)notification {
		//NSLog(@"Notification received: %@", [notification name]);

		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		[defaults synchronize];

    JNIEnv *env;
    jboolean attached = NO;
    int status = (*vm)->GetEnv(vm, (void **) &env, JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
    	status = (*vm)->AttachCurrentThread(vm, (void **) &env, 0);
    	if (status == JNI_OK) {
    		attached = YES;
    	} else {
    		NSLog(@"Unable to attach thread %d", status);
    	}
    }

    if (status == JNI_OK) {
    	if (synchronizeCallback != NULL) {
				jclass cl = (*env)->GetObjectClass(env, synchronizeCallback);
				jmethodID m = (*env)->GetMethodID(env, cl, "run", "()V");
				if (m != NULL) {
					(*env)->CallVoidMethod(env, synchronizeCallback, m);
				} else {
					NSLog(@"Unable to invoke callback -- run method not found");
				}
    	}
    } else {
    	NSLog(@"Unable to invoke notification callback %d", status);
    }

	if (attached) {
		(*vm)->DetachCurrentThread(vm);
	}
}
@end

/*
 * Class:     org_violetlib_aqua_OSXSystemProperties
 * Method:    nativeGetFullKeyboardAccessEnabled
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_org_violetlib_aqua_OSXSystemProperties_nativeGetFullKeyboardAccessEnabled
  (JNIEnv *env, jclass cl) {
  
	jboolean result = NO;
  
	JNF_COCOA_ENTER(env);

	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSInteger value = [userDefaults integerForKey: @"AppleKeyboardUIMode"];
	result = (value & 02) != 0;

	JNF_COCOA_EXIT(env);

	return result;
}

/*
 * Class:     org_violetlib_aqua_OSXSystemProperties
 * Method:    nativeGetShowAllFiles
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_org_violetlib_aqua_OSXSystemProperties_nativeGetShowAllFiles
  (JNIEnv *env, jclass cl) {
  
	jboolean result = NO;
  
	JNF_COCOA_ENTER(env);

	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults addSuiteNamed: @"com.apple.finder" ];
  result = [userDefaults boolForKey:@"AppleShowAllFiles"];

	//NSLog(@"Show all files: %d", result);

	JNF_COCOA_EXIT(env);

	return result;
}

/*
 * Class:     org_violetlib_aqua_OSXSystemProperties
 * Method:    nativeGetScrollToClick
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_org_violetlib_aqua_OSXSystemProperties_nativeGetScrollToClick
  (JNIEnv *env, jclass cl) {
  
	jboolean result = NO;
  
	JNF_COCOA_ENTER(env);

	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  result = [userDefaults boolForKey:@"AppleScrollerPagingBehavior"];

	JNF_COCOA_EXIT(env);

	return result;
}

/*
 * Class:     org_violetlib_aqua_OSXSystemProperties
 * Method:    nativeGetUseOverlayScrollBars
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_org_violetlib_aqua_OSXSystemProperties_nativeGetUseOverlayScrollBars
  (JNIEnv *env, jclass cl) {
  
	jboolean result = NO;
  
	JNF_COCOA_ENTER(env);

	NSScrollerStyle style = [NSScroller preferredScrollerStyle];
	result = style == NSScrollerStyleOverlay;
	//NSLog(@"Use overlay scroll bars: %ld %d", (long) style, result);

	JNF_COCOA_EXIT(env);

	return result;
}

/*
 * Class:     org_violetlib_aqua_OSXSystemProperties
 * Method:    enableCallback
 * Signature: (Ljava/lang/Runnable;)V
 */
JNIEXPORT void JNICALL Java_org_violetlib_aqua_OSXSystemProperties_enableCallback
  (JNIEnv *env, jclass cl, jobject jrunnable) {

	JNF_COCOA_ENTER(env);

	synchronizeCallback = JNFNewGlobalRef(env, jrunnable);

	jint status = (*env)->GetJavaVM(env, &vm);
	if (status == 0) {

		NSString * const KeyboardUIModeDidChangeNotification = @"com.apple.KeyboardUIModeDidChange";

		MyDefaultResponder *r = [[MyDefaultResponder alloc] init];
		[r retain];
		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		NSDistributedNotificationCenter *dcenter = [NSDistributedNotificationCenter defaultCenter];
		[center addObserver:r
				    selector:@selector(defaultsChanged:)  
					  name:NSPreferredScrollerStyleDidChangeNotification
					  object:nil];
		[dcenter addObserver:r
				    selector:@selector(defaultsChanged:)  
					  name:KeyboardUIModeDidChangeNotification
					  object:nil];
		//NSLog(@"Observer registered");
	}

	JNF_COCOA_EXIT(env);
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    getFileType
 * Signature: (Ljava/lang/String;)I
 */
JNIEXPORT jint JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeGetFileType
  (JNIEnv *env, jclass instance, jstring pathJ) {

    // Assert arguments
    if (pathJ == NULL) return false;

    jint result = -1;

    // Allocate a memory pool
    NSAutoreleasePool* pool = [NSAutoreleasePool new];

    // Convert Java String to NS String
    const jchar *pathC = (*env)->GetStringChars(env, pathJ, NULL);
    NSString *pathNS = [NSString stringWithCharacters:(UniChar *)pathC length:(*env)->GetStringLength(env, pathJ)];
    (*env)->ReleaseStringChars(env, pathJ, pathC);

    // Do the API calls
    NSFileManager *fileManagerNS = [NSFileManager defaultManager];
    NSDictionary* d = [fileManagerNS attributesOfItemAtPath:pathNS error:nil];
    if (d != nil) {
        NSString* fileType = [d fileType];
        if (fileType != nil) {
            if ([fileType isEqualToString:NSFileTypeRegular]) {
                result = 0;
            } else if ([fileType isEqualToString:NSFileTypeDirectory]) {
                result = 1;
            } else if ([fileType isEqualToString:NSFileTypeSymbolicLink]) {
                result = 2;
            }
        }
    }

    // Release memory pool
    [pool release];

    // Return the result
    return result;
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    resolveAlias
 * Signature: (Ljava/lang/String;Z)Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeResolveAlias__Ljava_lang_String_2Z
 (JNIEnv *env, jclass instance, jstring aliasPathJ, jboolean noUI)
{
    // Assert arguments
    if (aliasPathJ == NULL) return false;

    jstring result = NULL;

    // Allocate a memory pool
    NSAutoreleasePool* pool = [NSAutoreleasePool new];

    // Convert Java String to NS String
    const jchar *pathC = (*env)->GetStringChars(env, aliasPathJ, NULL);
    NSString *pathNS = [NSString stringWithCharacters:(UniChar *)pathC length:(*env)->GetStringLength(env, aliasPathJ)];
    (*env)->ReleaseStringChars(env, aliasPathJ, pathC);

    // Do the API calls
    NSString *resultNS = [pathNS stringByResolvingSymlinksInPath];
    if (resultNS != nil) {
        // Convert NSString to jstring
        result = (*env)->NewStringUTF(env, [resultNS UTF8String]);
    }

    // Release memory pool
    [pool release];

    // Return the result
    return result;
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    jniResolveAlias
 * Signature: ([BZ)Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeResolveAlias___3BZ
  (JNIEnv *env, jclass instance, jbyteArray serializedAlias, jboolean noUI)
{
    // Assert arguments
    if (serializedAlias == NULL) return false;

    CFDataRef dataRef;
    CFDataRef bookmarkDataRef;
    UInt8* serializedAliasBytes; // bytes of serializedAlias
    int length; // length of serializedAlias
    UInt8 resolvedPathC[2048];
    jstring result = NULL;

    length = (*env)->GetArrayLength(env, serializedAlias);
    serializedAliasBytes = (UInt8 *) (*env)->GetByteArrayElements(env, serializedAlias, NULL);
    if (serializedAliasBytes != NULL) {
        dataRef = CFDataCreate(NULL, serializedAliasBytes, length);
        if (dataRef != NULL) {
            bookmarkDataRef = CFURLCreateBookmarkDataFromAliasRecord(NULL, dataRef);
            if (bookmarkDataRef != NULL) {
                CFURLBookmarkResolutionOptions opt = (noUI) ? kCFBookmarkResolutionWithoutUIMask : 0;
                Boolean isStale;
                CFErrorRef error;
                CFURLRef u = CFURLCreateByResolvingBookmarkData(NULL, bookmarkDataRef, opt, NULL, NULL, &isStale, &error);
                if (u != NULL) {
                    Boolean success = CFURLGetFileSystemRepresentation(u, true, resolvedPathC, 2048);
                    if (success) {
                        result = (*env)->NewStringUTF(env, (const char *) resolvedPathC);
                    }
                    CFRelease(u);
                }
                CFRelease(bookmarkDataRef);
            }
            CFRelease(dataRef);
        }
        (*env)->ReleaseByteArrayElements(env, serializedAlias, (jbyte *) serializedAliasBytes, JNI_ABORT);
    }
    return result;
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    getLabel
 * Signature: (Ljava/lang/String;)I
 */
JNIEXPORT jint JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeGetLabel
  (JNIEnv *env, jclass instance, jstring pathJ) {

    // Assert arguments
    if (pathJ == NULL) return -1;

    // Allocate a memory pool
    NSAutoreleasePool* pool = [NSAutoreleasePool new];

    jint result = -1;

    // Convert Java String to NS String
    const jchar *pathC = (*env)->GetStringChars(env, pathJ, NULL);
    NSString *pathNS = [NSString stringWithCharacters:(UniChar *)pathC length:(*env)->GetStringLength(env, pathJ)];
    (*env)->ReleaseStringChars(env, pathJ, pathC);

    // Do the API calls
    NSURL *u = [NSURL fileURLWithPath:pathNS];
    if (u != nil) {
        CFErrorRef error;
        CFNumberRef fileLabel;
        Boolean success = CFURLCopyResourcePropertyForKey((CFURLRef) u, kCFURLLabelNumberKey, &fileLabel, &error);
        if (success) {
            CFNumberGetValue(fileLabel, kCFNumberSInt32Type, &result);
        }
    }

    // Release memory pool
    [pool release];

    // Return the result
    return result;
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    getKindString
 * Signature: (Ljava/lang/String;)Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeGetKindString
  (JNIEnv *env, jclass instance, jstring pathJ) {

    // Assert arguments
    if (pathJ == NULL) return NULL;

    // Allocate a memory pool
    NSAutoreleasePool* pool = [NSAutoreleasePool new];

    jstring result = NULL;

    // Convert Java String to NS String
    const jchar *pathC = (*env)->GetStringChars(env, pathJ, NULL);
    NSString *pathNS = [NSString stringWithCharacters:(UniChar *)pathC length:(*env)->GetStringLength(env, pathJ)];
    (*env)->ReleaseStringChars(env, pathJ, pathC);

    // Do the API calls
    NSURL *u = [NSURL fileURLWithPath:pathNS];
    if (u != nil) {
        CFErrorRef error;
        CFStringRef kind;
        Boolean success = CFURLCopyResourcePropertyForKey((CFURLRef) u, kCFURLLocalizedTypeDescriptionKey, &kind, &error);
        if (success) {
            CFRange range;
            range.location = 0;
            // Note that CFStringGetLength returns the number of UTF-16 characters,
            // which is not necessarily the number of printed/composed characters
            range.length = CFStringGetLength(kind);
            UniChar charBuf[range.length];
            CFStringGetCharacters(kind, range, charBuf);
            result = (*env)->NewString(env, (jchar *)charBuf, (jsize)range.length);
        }
    }

    // Release memory pool
    [pool release];

    // Return the result
    return result;
}

// Render an image into a Java int array
// w and h is the desired image size
// scaleFactor is the scaleFactor of the display for which this rendering is intended
// return NULL if scaleFactor is greater than 1 and the image has only one representation

static jintArray renderImageIntoBufferForDisplay(JNIEnv *env, NSImage *image, jint w, jint h, jfloat scaleFactor) {

	if (scaleFactor > 1 && [[image representations] count] < 2) {
		return NULL;
	}

	int rw = (int) (w * scaleFactor);
	int rh = (int) (h * scaleFactor);

	jboolean isCopy = JNI_FALSE;
	jintArray jdata = (*env)->NewIntArray(env, rw * rh);
    void *data = (*env)->GetPrimitiveArrayCritical(env, jdata, &isCopy);
    if (data != nil) {
    	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
		CGContextRef cg = CGBitmapContextCreate(data, rw, rh, 8, rw * 4, colorspace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
		CGColorSpaceRelease(colorspace);

		// The following method is deprecated in OS 10.10
		// NSGraphicsContext *ng = [NSGraphicsContext graphicsContextWithGraphicsPort:cg flipped:NO];

		NSGraphicsContext *ng = [NSGraphicsContext graphicsContextWithCGContext:cg flipped:NO];

    CGContextRelease(cg);

		//NSLog(@"Rendering image into %dx%d %fx: %@", w, h, scaleFactor, image);

		NSGraphicsContext *old = [[NSGraphicsContext currentContext] retain];
		[NSGraphicsContext setCurrentContext:ng];

		NSAffineTransform *tr = [NSAffineTransform transform];
		[tr scaleBy: scaleFactor];
		NSDictionary *hints = [NSDictionary dictionaryWithObject:tr forKey:NSImageHintCTM];
		NSRect frame = NSMakeRect(0, 0, w, h);
		NSImageRep *rep = [image bestRepresentationForRect:frame context:nil hints:hints];
    NSRect toRect = NSMakeRect(0, 0, rw, rh);

		//NSLog(@"Rendering image into %dx%d %fx using rep: %@", w, h, scaleFactor, rep);

		[rep drawInRect:toRect];

		[NSGraphicsContext setCurrentContext:old];
		[old release];
		(*env)->ReleasePrimitiveArrayCritical(env, jdata, data, 0);
		return jdata;
    }
	
	return NULL;
}

// Render an image into a Java array
// rw and rh are the actual size of the raster

static jboolean renderImageIntoBuffers(JNIEnv *env, NSImage *image, jobjectArray joutput, jint w, jint h) {

	//NSLog(@"Render image into buffers: %@", image);

	jboolean result = NO;
	
	jintArray buffer1 = renderImageIntoBufferForDisplay(env, image, w, h, 1);
	jintArray buffer2 = renderImageIntoBufferForDisplay(env, image, w, h, 2);

	if (buffer1) {
		(*env)->SetObjectArrayElement(env, joutput, 0, buffer1);
		(*env)->SetObjectArrayElement(env, joutput, 1, buffer2);
		result = YES;
	}
	
	return result;
}

typedef long (*QuickLookRequest)(CFAllocatorRef, CFURLRef, CGSize, CFDictionaryRef);

static NSImage *getFileImage(NSString *path, jboolean isQuickLook, jboolean isIconMode, jint w, jint h) {

	//NSLog(@"getFileImage %d %@", isQuickLook, path);

	NSImage *result = nil;
	if (isQuickLook) {
		NSURL *fileURL = [NSURL fileURLWithPath:path];
		if (fileURL != nil) {
			// Load the QuickLook bundle
			NSURL *bundleURL = [NSURL fileURLWithPath:@"/System/Library/Frameworks/QuickLook.framework"];
			CFBundleRef cfBundle = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)bundleURL);
			// If we didn't succeed, the framework does not exist.
			if (cfBundle) {
				NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:isIconMode]
																 forKey:@"IconMode"];
				// Get the thumbnail function pointer
				QuickLookRequest functionRef = CFBundleGetFunctionPointerForName(cfBundle,
																				 CFSTR("QLThumbnailImageCreate"));
				if (functionRef) {
					CGSize size = CGSizeMake(w, h);
					CGImageRef ref = (CGImageRef) functionRef(kCFAllocatorDefault,
												 (CFURLRef)fileURL,
												 size,
												 (CFDictionaryRef)dict);

					if (ref) {
						result = [[[NSImage alloc] initWithCGImage:ref size:size] autorelease];
						CFRelease(ref);
					} else {
						//NSLog(@"No quick look image found");
					}
				}
			}
		}
	} else {
		result = [[NSWorkspace sharedWorkspace] iconForFile:path];
  }

	//NSLog(@"getFileImage result %@", result);

    return result;
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    nativeRenderFileImage
 * Signature: (Ljava/lang/String;ZZ[[III)Z
 */
JNIEXPORT jboolean JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeRenderFileImage
  (JNIEnv *env, jclass cl, jstring jpath, jboolean isQuickLook, jboolean isIconMode, jobjectArray output, jint w, jint h) {
  
	jboolean result = NO;

	JNF_COCOA_ENTER(env);

	NSString *path = JNFNormalizedNSStringForPath(env, jpath);

		NSImage *image = getFileImage(path, isQuickLook, isIconMode, w, h);
		if (image != nil) {
			result = renderImageIntoBuffers(env, image, output, w, h);
		}

	JNF_COCOA_EXIT(env);

	return result;
}

/*
 * Class:     org_violetlib_aqua_AquaImageFactory
 * Method:    nativeRenderImageFile
 * Signature: (Ljava/lang/String;[[III)Z
 */
JNIEXPORT jboolean JNICALL Java_org_violetlib_aqua_AquaImageFactory_nativeRenderImageFile
  (JNIEnv *env, jclass cl, jstring jpath, jobjectArray buffers, jint w, jint h) {

	jboolean result = NO;

	JNF_COCOA_ENTER(env);

	NSString *path = JNFNormalizedNSStringForPath(env, jpath);
	NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];

	if (image != nil) {
		result = renderImageIntoBuffers(env, image, buffers, w, h);
	}

	JNF_COCOA_EXIT(env);

  return result;
}

/*
 * Class:     org_violetlib_aqua_AquaIcon
 * Method:    nativeRenderIcon
 * Signature: (I[[II)Z
 */
JNIEXPORT jboolean JNICALL Java_org_violetlib_aqua_AquaIcon_nativeRenderIcon
  (JNIEnv *env, jclass cl, jint osType, jobjectArray buffers, jint size) {
  
	jboolean result = NO;

	JNF_COCOA_ENTER(env);

	NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(osType)];

	if (image != nil) {
		result = renderImageIntoBuffers(env, image, buffers, size, size);
	}

	JNF_COCOA_EXIT(env);

  return result;
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    getBasicItemInfoFlags
 * Signature: (Ljava/lang/String;)I
 */
JNIEXPORT jint JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeGetBasicItemInfoFlags
  (JNIEnv *env, jclass javaClass, jstring pathJ) {
    // Assert arguments
    if (pathJ == NULL) return -1;

    // Allocate a memory pool
    NSAutoreleasePool* pool = [NSAutoreleasePool new];

    jint result = 0;

    // Convert Java String to NS String
    const jchar *pathC = (*env)->GetStringChars(env, pathJ, NULL);
    NSString *pathNS = [NSString stringWithCharacters:(UniChar *)pathC length:(*env)->GetStringLength(env, pathJ)];
    (*env)->ReleaseStringChars(env, pathJ, pathC);

    // Do the API calls
    NSURL *u = [NSURL fileURLWithPath:pathNS];
    if (u != nil) {
        OSStatus err;
        LSItemInfoRecord itemInfoRecord;
        err = LSCopyItemInfoForURL((CFURLRef) u, kLSRequestBasicFlagsOnly, &itemInfoRecord);
        if (err == 0) {
            result = itemInfoRecord.flags;
        }
    }

    // Release memory pool
    [pool release];

    // Return the result
    return result;
}

JNIEXPORT jstring JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeGetDisplayName
  (JNIEnv *env, jclass javaClass, jstring pathJ) {

    // Assert arguments
    if (pathJ == NULL) return NULL;

    // Allocate a memory pool
    NSAutoreleasePool* pool = [NSAutoreleasePool new];

    // Convert Java String to NS String
    const jchar *pathC = (*env)->GetStringChars(env, pathJ, NULL);
    NSString *pathNS = [NSString stringWithCharacters:(UniChar *)pathC
        length:(*env)->GetStringLength(env, pathJ)];
    (*env)->ReleaseStringChars(env, pathJ, pathC);

    // Do the API calls
    NSFileManager *fileManagerNS = [NSFileManager defaultManager];
    NSString *displayNameNS = [fileManagerNS displayNameAtPath: pathNS];

    // Convert NSString to jstring
    jstring displayNameJ = (*env)->NewStringUTF(env, [displayNameNS UTF8String]);

    // Release memory pool
    [pool release];

    // Return the result
    return displayNameJ;
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    nativeGetLastUsedDate
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jlong JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeGetLastUsedDate
  (JNIEnv *env, jclass javaClass, jstring pathJ) {

    // Assert arguments
    if (pathJ == NULL) return 0;

    // Allocate a memory pool
    NSAutoreleasePool* pool = [NSAutoreleasePool new];

    // Convert Java String to NS String
    const jchar *pathC = (*env)->GetStringChars(env, pathJ, NULL);
    NSString *pathNS = [NSString stringWithCharacters:(UniChar *)pathC
        length:(*env)->GetStringLength(env, pathJ)];
    (*env)->ReleaseStringChars(env, pathJ, pathC);

    jlong result = 0;

    // Do the API calls
    NSURL *u = [NSURL fileURLWithPath:pathNS];
    if (u != nil) {
        MDItemRef item = MDItemCreateWithURL(NULL, CFBridgingRetain(u));
        if (item != NULL) {
            CFDateRef date = (CFDateRef) MDItemCopyAttribute(item, kMDItemLastUsedDate);
            if (date != NULL) {
                CFAbsoluteTime /* double */ at = CFDateGetAbsoluteTime(date);	/* seconds since Jan 1 2001 */
                long long jtime = (long long) at;
                jtime += (60 * 60 * 24) * (31 * 365 + 8);
                jtime *= 1000;
                result = (jlong) jtime;
            }
        }
    }

    // Release memory pool
    [pool release];

    // Return the result
    return result;
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    nativeExecuteSavedSearch
 * Signature: (Ljava/lang/String)[Ljava/lang/String
 */
JNIEXPORT jobjectArray JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeExecuteSavedSearch
(JNIEnv *env, jclass javaClass, jstring pathJ) {
    // Assert arguments
    if (pathJ == NULL) return NULL;

    // Prepare result
    jobjectArray result = NULL;

    // Allocate a memory pool
    NSAutoreleasePool* pool = [NSAutoreleasePool new];

    // Convert Java String to NS String
    const jchar *pathC = (*env)->GetStringChars(env, pathJ, NULL);
    NSString *pathNS = [NSString stringWithCharacters:(UniChar *)pathC
                                               length:(*env)->GetStringLength(env, pathJ)];
    (*env)->ReleaseStringChars(env, pathJ, pathC);

    // Read the saved search file and execute the query synchronously
    NSData *data = [NSData dataWithContentsOfFile:pathNS];
    if (data != nil) {
        NSPropertyListReadOptions readOptions = NSPropertyListImmutable;
        NSError *error;
        NSDictionary *plist = (NSDictionary *)[NSPropertyListSerialization propertyListWithData:data options:readOptions format:NULL error:&error];
        if (plist != nil) {
            NSString *queryString = (NSString *) [plist objectForKey:@"RawQuery"];
            NSDictionary *searchCriteria = (NSDictionary *) [plist objectForKey:@"SearchCriteria"];
            if (queryString != nil && searchCriteria != nil) {
                NSArray *scopeDirectories = (NSArray *) [searchCriteria objectForKey:@"FXScopeArrayOfPaths"];
                if (scopeDirectories != nil) {
                    MDQueryRef query = MDQueryCreate(NULL, CFBridgingRetain(queryString), NULL, NULL);
                    if (query != NULL) {
                        OptionBits scopeOptions = 0;
                        MDQuerySetSearchScope(query, CFBridgingRetain(scopeDirectories), scopeOptions);
                        CFOptionFlags optionFlags = kMDQuerySynchronous;
                        Boolean b = MDQueryExecute(query, optionFlags);
                        if (b) {
                            CFIndex count = MDQueryGetResultCount(query);
                            jclass stringClass = (*env)->FindClass(env, "java/lang/String");
                            result = (*env)->NewObjectArray(env, count, stringClass, NULL);
                            for (CFIndex i = 0; i < count; i++) {
                                MDItemRef item = (MDItemRef) MDQueryGetResultAtIndex(query, i);
                                CFStringRef path = (CFStringRef) MDItemCopyAttribute(item, kMDItemPath);
                                NSString *pathNS = (NSString *) path;
                                jstring pathJ = (*env)->NewStringUTF(env, [pathNS UTF8String]);
                                (*env)->SetObjectArrayElement(env, result, i, pathJ);
                            }
                        }
                    }
                }
            }
        }
    }

    // Release memory pool
    [pool release];

    return result;
}

/*
 * Class:     org_violetlib_aqua_fc_OSXFile
 * Method:    nativeGetSidebarFiles
 * Signature: (I)[Ljava/lang/String;
 */
JNIEXPORT jobjectArray JNICALL Java_org_violetlib_aqua_fc_OSXFile_nativeGetSidebarFiles
  (JNIEnv *env, jclass cl, jint which, jint iconSize, jint lastSeed)
{
	CFStringRef listID = which > 0 ? kLSSharedFileListFavoriteVolumes : kLSSharedFileListFavoriteItems;

	LSSharedFileListRef list = LSSharedFileListCreate(NULL, listID, NULL);
	if (!list) {
		NSLog(@"Failed to create shared file list for %@", listID);
		return NULL;
	}

	UInt32 seed = LSSharedFileListGetSeedValue(list);
	if (seed == lastSeed) {
		CFRelease(list);
		return NULL;
	}

	CFArrayRef items = LSSharedFileListCopySnapshot(list, &seed);
	size_t count = CFArrayGetCount(items);
	
	jclass objectClass = (*env)->FindClass(env, "java/lang/Object");
	jclass integerClass = (*env)->FindClass(env, "java/lang/Integer");
	jmethodID newIntegerMethodID = (*env)->GetMethodID(env, integerClass, "<init>", "(I)V");

	jobjectArray result = (*env)->NewObjectArray(env, 1 + count * 6, objectClass, NULL);
	size_t j = 0;
	(*env)->SetObjectArrayElement(env, result, j++, (*env)->NewObject(env, integerClass, newIntegerMethodID, seed));

	if (which >= 2) {	// testing
		NSLog(@"%ld elements for %@", count, list);
	}

	if (count > 0) {
		for (size_t i = 0; i < count; i++) {
			LSSharedFileListItemRef item = (LSSharedFileListItemRef) CFArrayGetValueAtIndex(items, i);
			if (!item) {
				continue;
			}

			// Collect six elements: display name, UID, hidden flag, resolved path, 1x rendering, 2x rendering

			CFStringRef displayName = LSSharedFileListItemCopyDisplayName(item);
			NSString *displayNameNS = (NSString *) displayName;
			jstring displayNameJ = (*env)->NewStringUTF(env, [displayNameNS UTF8String]);
			CFRelease(displayName);

      UInt32 itemId = LSSharedFileListItemGetID(item);
			jobject itemIdJ = (*env)->NewObject(env, integerClass, newIntegerMethodID, itemId);

			CFTypeRef hiddenProperty = LSSharedFileListItemCopyProperty(item, kLSSharedFileListItemHidden);
			jint hiddenFlag = hiddenProperty && hiddenProperty == kCFBooleanTrue;
			if (hiddenProperty) {
				CFRelease(hiddenProperty);
			}
			jobject flagsJ = (*env)->NewObject(env, integerClass, newIntegerMethodID, hiddenFlag);
			
			jstring pathJ = NULL;
			CFURLRef outURL = LSSharedFileListItemCopyResolvedURL(item, kLSSharedFileListNoUserInteraction|kLSSharedFileListDoNotMountVolumes, NULL);
			if (outURL) {
				CFStringRef itemPath = CFURLCopyFileSystemPath(outURL, kCFURLPOSIXPathStyle);
				if (itemPath) {
					NSString *pathNS = (NSString *) itemPath;
					pathJ = (*env)->NewStringUTF(env, [pathNS UTF8String]);
					CFRelease(itemPath);
				}
				CFRelease(outURL);
			}

			jobject icon1J = NULL;
			jobject icon2J = NULL;

			if (iconSize > 0) {
				IconRef icon = LSSharedFileListItemCopyIconRef(item);
				if (icon) {
					NSImage *iconImage = [[NSImage alloc] initWithIconRef:icon];
					icon1J = renderImageIntoBufferForDisplay(env, iconImage, iconSize, iconSize, 1);
					icon2J = renderImageIntoBufferForDisplay(env, iconImage, iconSize, iconSize, 2);
					[iconImage release];
					CFRelease(icon);
				}
			}

			(*env)->SetObjectArrayElement(env, result, j++, displayNameJ);
			(*env)->SetObjectArrayElement(env, result, j++, itemIdJ);
			(*env)->SetObjectArrayElement(env, result, j++, flagsJ);
			(*env)->SetObjectArrayElement(env, result, j++, pathJ);
			(*env)->SetObjectArrayElement(env, result, j++, icon1J);
			(*env)->SetObjectArrayElement(env, result, j++, icon2J);
		}
	}

	CFRelease(items);
	CFRelease(list);
	return result;
}

static NSColorPanel *colorPanel;
static jobject colorPanelCallback;

@interface MyColorPanelDelegate : NSObject <NSWindowDelegate> {}
- (void) colorChanged: (id) sender;
@end

@implementation MyColorPanelDelegate

- (void) windowWillClose:(NSNotification *) ns
{
	JNIEnv *env;
	jboolean attached = NO;
	int status = (*vm)->GetEnv(vm, (void **) &env, JNI_VERSION_1_6);
	if (status == JNI_EDETACHED) {
		status = (*vm)->AttachCurrentThread(vm, (void **) &env, 0);
		if (status == JNI_OK) {
			attached = YES;
		} else {
			NSLog(@"Unable to attach thread %d", status);
		}
	}

	if (status == JNI_OK) {
		// Using dynamic lookup because we do not know which class loader was used
		jclass cl = (*env)->GetObjectClass(env, colorPanelCallback);
		jmethodID m = (*env)->GetMethodID(env, cl, "disconnected", "()V");
		if (m != NULL) {
			(*env)->CallVoidMethod(env, colorPanelCallback, m);
		} else {
			NSLog(@"Unable to invoke callback -- disconnected method not found");
		}
	} else {
		NSLog(@"Unable to invoke callback %d", status);
	}

	if (attached) {
		(*vm)->DetachCurrentThread(vm);
	}
}

- (void) colorChanged: (id) sender
{
	NSColor *color = [colorPanel color];

	JNIEnv *env;
	jboolean attached = NO;
	int status = (*vm)->GetEnv(vm, (void **) &env, JNI_VERSION_1_6);
	if (status == JNI_EDETACHED) {
		status = (*vm)->AttachCurrentThread(vm, (void **) &env, 0);
		if (status == JNI_OK) {
			attached = YES;
		} else {
			NSLog(@"Unable to attach thread %d", status);
		}
	}

	if (status == JNI_OK) {
    static JNF_CLASS_CACHE(jc_Color, "java/awt/Color");
    static JNF_MEMBER_CACHE(jm_createColor, jc_Color, "<init>", "(FFFF)V");
		CGFloat r, g, b, a;
		[color getRed:&r green:&g blue:&b alpha:&a];
		jobject jColor = JNFNewObject(env, jm_createColor, r, g, b, a);
		// Using dynamic lookup because we do not know which class loader was used
		jclass cl = (*env)->GetObjectClass(env, colorPanelCallback);
		jmethodID m = (*env)->GetMethodID(env, cl, "applyColor", "(Ljava/awt/Color;)V");
		if (m != NULL) {
			(*env)->CallVoidMethod(env, colorPanelCallback, m, jColor);
		} else {
			NSLog(@"Unable to invoke callback -- applyColor method not found");
		}
	} else {
		NSLog(@"Unable to invoke callback %d", status);
	}

	if (attached) {
		(*vm)->DetachCurrentThread(vm);
	}
}

@end

static jboolean setupColorPanel()
{
	MyColorPanelDelegate *delegate = [[MyColorPanelDelegate alloc] init];
	colorPanel = [NSColorPanel sharedColorPanel];
	[colorPanel setDelegate: delegate];
	[colorPanel setAction: @selector(colorChanged:)];
	[colorPanel setTarget: delegate];
	[colorPanel setContinuous: YES];
	[colorPanel makeKeyAndOrderFront: nil];
	[colorPanel setReleasedWhenClosed: NO];
	return YES;
}

static void setColorPanelVisible(jboolean isShow)
{
	if (colorPanel) {
		if (isShow) {
    		[colorPanel makeKeyAndOrderFront: nil];
		} else {
    		[colorPanel close];
		}
	}
}

/*
 * Class:     org_violetlib_aqua_AquaNativeColorChooser
 * Method:    display
 * Signature: (Lorg/violetlib/aqua/AquaSharedColorChooser/Owner;)Z
 */
JNIEXPORT jboolean JNICALL Java_org_violetlib_aqua_AquaNativeColorChooser_create
  (JNIEnv *env, jclass cl, jobject ownerCallback)
{
	colorPanelCallback = JNFNewGlobalRef(env, ownerCallback);
	
	__block jboolean result = NO;
	
	JNF_COCOA_ENTER(env);

	if (!vm) {
		(*env)->GetJavaVM(env, &vm);
	}

	void (^block)() = ^(){
		result = setupColorPanel();
	};

	if ([NSThread isMainThread]) {
		block(); 
	} else { 
		[JNFRunLoop performOnMainThreadWaiting:YES withBlock:block]; 
	}

	JNF_COCOA_EXIT(env);

	return result;
}

static void showHideColorChooser(JNIEnv *env, jboolean isShow)
{
	if (colorPanel) {
		JNF_COCOA_ENTER(env);

		void (^block)() = ^(){
			setColorPanelVisible(isShow);
		};

		if ([NSThread isMainThread]) {
			block(); 
		} else { 
			[JNFRunLoop performOnMainThreadWaiting:YES withBlock:block]; 
		}

		JNF_COCOA_EXIT(env);
	}
}

/*
 * Class:     org_violetlib_aqua_AquaNativeColorChooser
 * Method:    show
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_org_violetlib_aqua_AquaNativeColorChooser_show
  (JNIEnv *env, jclass cl)
{
	showHideColorChooser(env, YES);
}

/*
 * Class:     org_violetlib_aqua_AquaNativeColorChooser
 * Method:    hide
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_org_violetlib_aqua_AquaNativeColorChooser_hide
  (JNIEnv *env, jclass cl)
{
	showHideColorChooser(env, NO);
}

static NSWindow *getNativeWindow(JNIEnv *env, jobject w)
{
	static JNF_CLASS_CACHE(jc_Window, "java/awt/Window");
	static JNF_MEMBER_CACHE(jm_getPeer, jc_Window, "getPeer", "()Ljava/awt/peer/ComponentPeer;");
	static JNF_CLASS_CACHE(jc_LWWindowPeer, "sun/lwawt/LWWindowPeer");
	static JNF_MEMBER_CACHE(jm_getPlatformWindow, jc_LWWindowPeer, "getPlatformWindow", "()Lsun/lwawt/PlatformWindow;");
	static JNF_CLASS_CACHE(jc_CPlatformWindow, "sun/lwawt/macosx/CPlatformWindow");
	static JNF_MEMBER_CACHE(jm_getNSWindow, jc_CPlatformWindow, "getNSWindowPtr", "()J");

	jobject peer = JNFCallObjectMethod(env, w, jm_getPeer);
	if (peer == NULL) {
		return NULL;
	}
	jobject platformWindow = JNFCallObjectMethod(env, peer, jm_getPlatformWindow);
	if (platformWindow == NULL) {
		return NULL;
	}
	NSWindow *nw = (NSWindow *) JNFCallLongMethod(env, platformWindow, jm_getNSWindow);
	return nw; 
}

static const jint TITLEBAR_NONE = 0;
static const jint TITLEBAR_ORDINARY = 1;
static const jint TITLEBAR_TRANSPARENT = 2;
static const jint TITLEBAR_HIDDEN = 3;
static const jint TITLEBAR_OVERLAY = 4;

/*
 * Class:     org_violetlib_aqua_AquaUtils
 * Method:    nativeSetTitleBarStyle
 * Signature: (Ljava/awt/Window;I)I
 */
JNIEXPORT jint JNICALL Java_org_violetlib_aqua_AquaUtils_nativeSetTitleBarStyle
  (JNIEnv *env, jclass cl, jobject window, jint style)
{
	// This method uses API introduced in Yosemite

	jint result = -1;

	JNF_COCOA_ENTER(env);

	NSWindow *nw = getNativeWindow(env, window);
	if (nw != nil && [nw respondsToSelector: @selector(setTitlebarAppearsTransparent:)]) {
		[JNFRunLoop performOnMainThreadWaiting:YES withBlock:^(){

			NSProcessInfo *pi = [NSProcessInfo processInfo];
			NSOperatingSystemVersion osv = [pi operatingSystemVersion];
			BOOL isElCapitan = osv.majorVersion >= 10 && osv.minorVersion >= 11;

			// Because this method is used by component UIs, it updates the same set of
			// properties regardless of the style. It never does a partial update.

			// On Yosemite, if the window is not Movable, mouse events over the title bar never get
			// to the Java window. If we want some control over title bar mouse events (which
			// we do when the title bar is transparent), we must make the window Movable.

			NSUInteger styleMask = [nw styleMask];
			BOOL isTextured = (styleMask & NSTexturedBackgroundWindowMask) != 0;
			BOOL isMovable = true;
			BOOL isMovableByBackground = isTextured;
			BOOL isTransparent = NO;
			BOOL isHidden = NO;
			BOOL isFixNeeded = NO;
			
			switch (style) {
				case TITLEBAR_NONE:
					styleMask &= ~(NSTitledWindowMask | NSFullSizeContentViewWindowMask);
					break;
				case TITLEBAR_ORDINARY:
				default:
					styleMask |= NSTitledWindowMask;
					styleMask &= ~NSFullSizeContentViewWindowMask;
					break;
				case TITLEBAR_TRANSPARENT:
					styleMask |= (NSTitledWindowMask | NSFullSizeContentViewWindowMask);
					isTransparent = YES;
					isMovable = !isElCapitan;
					isMovableByBackground = NO;
					isFixNeeded = YES;
					break;
				case TITLEBAR_HIDDEN:
					styleMask |= (NSTitledWindowMask | NSFullSizeContentViewWindowMask);
					isTransparent = YES;
					isHidden = YES;
					isMovable = !isElCapitan;
					isMovableByBackground = NO;
					isFixNeeded = YES;
					break;
				case TITLEBAR_OVERLAY:
					styleMask |= (NSTitledWindowMask | NSFullSizeContentViewWindowMask);
					isFixNeeded = YES;
					break;
				}
					
			[[nw standardWindowButton:NSWindowCloseButton] setHidden:isHidden];
			[[nw standardWindowButton:NSWindowMiniaturizeButton] setHidden:isHidden];
			[[nw standardWindowButton:NSWindowZoomButton] setHidden:isHidden];

			[nw setTitlebarAppearsTransparent: isTransparent];
			[nw setStyleMask: styleMask];

			[nw setMovableByWindowBackground:isMovableByBackground];
			[nw setMovable:isMovable];

			if (isFixNeeded) {
				// Workaround for a mysterious problem observed in some circumstances but not others.
				// The corner radius is not set, so painting happens outside the rounded corners.
				NSView *contentView = [ nw contentView ];
				NSView *themeFrame = [ contentView superview ];
				if ([themeFrame superview] == nil) {
					CALayer *layer = [ themeFrame layer ];
					if (layer != nil) {
						CGFloat radius = [ layer cornerRadius ];
						if (radius == 0) {
							//NSLog(@"Fixing corner radius of %@", layer);
							[ layer setCornerRadius: 6 ];
						}
					} else {
						NSLog(@"Unable to fix corner radius: no layer");
					}
				} else {
					NSLog(@"Unable to fix corner radius: did not find expected top view");
				}
			}
		}];
		result = 0;
	}

	JNF_COCOA_EXIT(env);

	return result;
}

/*
 * Class:     org_violetlib_aqua_AquaUtils
 * Method:    nativeAddToolbarToWindow
 * Signature: (Ljava/awt/Window;)I
 */
JNIEXPORT jint JNICALL Java_org_violetlib_aqua_AquaUtils_nativeAddToolbarToWindow
  (JNIEnv *env, jclass cl, jobject window)
{
	jint result = -1;

	JNF_COCOA_ENTER(env);

	NSWindow *nw = getNativeWindow(env, window);
	if (nw != nil) {
		[JNFRunLoop performOnMainThreadWaiting:YES withBlock:^(){
			NSToolbar *tb = [[NSToolbar alloc] initWithIdentifier: @"Foo"];
			[tb setShowsBaselineSeparator: NO];
			[nw setToolbar: tb];
		}];
		result = 0;
	}

	JNF_COCOA_EXIT(env);

	return result;
}

JNIEXPORT jint JNICALL Java_org_violetlib_aqua_AquaUtils_nativeDisplayAsSheet
  (JNIEnv *env, jclass cl, jobject window)
{
	static JNF_CLASS_CACHE(jc_Window, "java/awt/Window");
	static JNF_MEMBER_CACHE(jm_getOwner, jc_Window, "getOwner", "()Ljava/awt/Window;");

	jint result = -1;
	
	JNF_COCOA_ENTER(env);

	// Get the owner window
	jobject owner = JNFCallObjectMethod(env, window, jm_getOwner);
	if (owner != NULL) {
		NSWindow *nw = getNativeWindow(env, window);
		if (nw != nil) {
			NSWindow *no = getNativeWindow(env, owner);
			if (no != nil) {
				[JNFRunLoop performOnMainThreadWaiting:NO withBlock:^(){[no beginSheet:nw completionHandler:nil];}];
				result = 0;
			}
		}
	}

	JNF_COCOA_EXIT(env);

	return result;
}

/*
 * Class:     org_violetlib_aqua_AquaUtils
 * Method:    syslog
 * Signature: (Ljava/lang/String;)V
 */
JNIEXPORT void JNICALL Java_org_violetlib_aqua_AquaUtils_syslog
  (JNIEnv *env, jclass cl, jstring msg)
{
	jsize slen = (*env) -> GetStringLength(env, msg);
	const jchar *schars = (*env) -> GetStringChars(env, msg, NULL);
	CFStringRef s = CFStringCreateWithCharacters(NULL, schars, slen);
	NSLog(@"%@", s);
	CFRelease(s);
	(*env) -> ReleaseStringChars(env, msg, schars);
}

/*
 * Class:     org_violetlib_aqua_AquaNativeSupport
 * Method:    setup
 * Signature: (I)V
 */
JNIEXPORT void JNICALL Java_org_violetlib_aqua_AquaNativeSupport_setup
  (JNIEnv *env, jclass cl, jint jv)
{
	javaVersion = jv;
}

/*
 * Class:     org_violetlib_aqua_AquaNativeSupport
 * Method:    nativeGetNativeCodeVersion
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_org_violetlib_aqua_AquaNativeSupport_nativeGetNativeCodeVersion
  (JNIEnv *env, jclass javaClass)
{
	return VERSION;
}