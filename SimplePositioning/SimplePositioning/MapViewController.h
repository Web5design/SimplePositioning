//
//  MapViewController.h
//  SimplePositioning
//
//  Created by André Hansson on 25/11/13.
//  Copyright (c) 2013 PingPal AB. All rights reserved.
//

#import "ViewController.h"
#import "Friend.h"
#import <MapKit/MapKit.h>

@interface MapViewController : ViewController <MKMapViewDelegate>

// The current friend we are tracking or getting a position from
@property Friend *currentFriend;

// The selector for getting position
-(void)getDevicePosInbox:(NSDictionary*)dict;

// The selector for tracking
-(void)trackDevicePosInbox:(NSDictionary*)dict;

@end
