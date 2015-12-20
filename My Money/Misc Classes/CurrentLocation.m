//
//  Location.m
//  Easy Spend Log iOS
//
//  Created by Aaron Bratcher on 08/17/2012.
//  Copyright (c) 2012 Aaron Bratcher. All rights reserved.
//

#import "CurrentLocation.h"

static CurrentLocation* _locationInstance;

@interface CurrentLocation()<CLLocationManagerDelegate>

@property (readwrite) NSArray* addressParts;
@property (readwrite) double lat;
@property (readwrite) double lon;
@property (nonatomic) BOOL trackingLocation;
@property BOOL usingLocationManager;

@property (strong) NSMutableArray* locationBlockQueue;
@property (strong) CLLocationManager* locationManager;
@property int locationAttempts;
@property (strong) NSObject* locationBlockQueueSynchronizer;

@end

@implementation CurrentLocation {
	CLGeocoder* coder;
}

#pragma mark - Class methods
+(void)currentLocation:(void (^)(CurrentLocation *))locationBlock {
    if (!_locationInstance) {
        _locationInstance = [[CurrentLocation alloc] init];
    }
    
    if (!_locationInstance.usingLocationManager) {
        if (locationBlock) {
            locationBlock(_locationInstance);
        }
        return;
    }
    
    if (_locationInstance.lat) {
        if (locationBlock) {
            locationBlock(_locationInstance);
        }
    } else {
        @synchronized(_locationInstance.locationBlockQueueSynchronizer) {
            if (locationBlock) {
                [_locationInstance.locationBlockQueue addObject:locationBlock];
            }
        }
        
        if (!_locationInstance.trackingLocation) {
            _locationInstance.trackingLocation = YES;
        }
    }
}

#pragma mark - Internal

-(id) init {
    self = [super init];
    _locationInstance = self;
    self.locationBlockQueueSynchronizer = [[NSObject alloc] init];
    self.locationBlockQueue = [NSMutableArray array];
    coder = [[CLGeocoder alloc] init];
    
    if ([CLLocationManager locationServicesEnabled]) {
        _usingLocationManager = YES;
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.locationManager.distanceFilter = 100;
        self.trackingLocation = YES;
    }
    
    return self;
}

- (void) setTrackingLocation:(BOOL)trackingLocation {
	if (trackingLocation == _trackingLocation) {
		return;
	}
	
	_trackingLocation = trackingLocation && _usingLocationManager;
	if(_trackingLocation) {
		self.lat = 0;
		self.lon = 0;
		self.locationAttempts = 0;
        if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
            [self.locationManager requestWhenInUseAuthorization];
        }
        
		[self.locationManager startUpdatingLocation];
	}
	else {
		_trackingLocation = NO;
		[self.locationManager stopUpdatingLocation];
	}
}

#pragma mark - LocationManager Notifications
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    // return if inaccurate
    if (newLocation.horizontalAccuracy < 0) {
        return;
    }
    
    // return if old
    NSTimeInterval locationAge = -[newLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 5.0) {
        return;
    }
    
	self.locationAttempts += 1;
	BOOL locationChanged;
	
	if((newLocation.coordinate.latitude != oldLocation.coordinate.latitude) && (newLocation.coordinate.longitude != oldLocation.coordinate.longitude))
		locationChanged = YES;
	else
		locationChanged = NO;
	
    if (newLocation.horizontalAccuracy < 50.0
        || (newLocation.horizontalAccuracy <= 150.0 && locationChanged)
        || self.locationAttempts >= 2
        )
    {
		self.locationAttempts = 0;
		self.horizontalAccuracy = newLocation.horizontalAccuracy;
		
		self.lat = newLocation.coordinate.latitude;
		self.lon = newLocation.coordinate.longitude;
		[coder reverseGeocodeLocation:newLocation
						completionHandler:^(NSArray *placemarks, NSError *error){
							if(!error){
								self.addressParts = placemarks;
							}
							else{
								self.addressParts = nil;
							}
							
							self.trackingLocation = NO;
							
							@synchronized(self.locationBlockQueueSynchronizer) {
								for (LocationBlock locationBlock in self.locationBlockQueue) {
									locationBlock(self);
								}
								
								[self.locationBlockQueue removeAllObjects];
							}
							
							_locationInstance = nil;
						}
		 ];
	}
}

- (void)locationManager:(CLLocationManager *)manager
		 didFailWithError:(NSError *)error
{
	if ([error code] == kCLErrorDenied) {
		_usingLocationManager = NO;
		self.trackingLocation = NO;
	}
    
    @synchronized(self.locationBlockQueueSynchronizer) {
        for (LocationBlock locationBlock in self.locationBlockQueue) {
            locationBlock(nil);
        }
        
        [self.locationBlockQueue removeAllObjects];
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways)
		self.trackingLocation = YES;
	else
		self.trackingLocation = NO;
}

@end
