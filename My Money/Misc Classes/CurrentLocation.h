//
//  Location.h
//  Easy Spend Log iOS
//
//  Created by Aaron Bratcher on 08/17/2012.
//  Copyright (c) 2012 Aaron Bratcher. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class CurrentLocation;
typedef void(^LocationBlock)(CurrentLocation*);

@interface CurrentLocation : NSObject

/*! latitute value */
@property (readonly) double lat;

/*! longitude value */
@property (readonly) double lon;

/*! address information */
@property (readonly,strong) NSArray* addressParts;

/*! Accuracy of location */
@property CLLocationAccuracy horizontalAccuracy;


/*! Passes an instance of this class with the last known location to the block. Use the above properties to access location information. On error, this will pass a nil location.
 	@param locationBlock the block object that will receive the location instance.
 */
+(void) currentLocation:(void(^)(CurrentLocation* location))locationBlock;

@end

