//
//  MapViewController.m
//  SimplePositioning
//
//  Created by André Hansson on 25/11/13.
//  Copyright (c) 2013 PingPal AB. All rights reserved.
//

#import "MapViewController.h"
#import <MapKit/MapKit.h>

@interface MapViewController (){
    UIActivityIndicatorView *activityView;
    UIView *loadingView;
    UILabel *loadingLabel;
    
    NSMutableArray *coords;
    
    MKPointAnnotation *point;
    
    BOOL isTracking;
}

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end

@implementation MapViewController

@synthesize mapView, currentFriend;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    coords = [[NSMutableArray alloc]init];
    
    // Create a loading view while we're getting the first position
    loadingView = [[UIView alloc] initWithFrame:CGRectMake(75, 155, 170, 170)];
    loadingView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
    loadingView.clipsToBounds = YES;
    loadingView.layer.cornerRadius = 10.0;
    
    activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityView.frame = CGRectMake(65, 40, activityView.bounds.size.width, activityView.bounds.size.height);
    [loadingView addSubview:activityView];
    
    loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 115, 130, 22)];
    loadingLabel.backgroundColor = [UIColor clearColor];
    loadingLabel.textColor = [UIColor whiteColor];
    loadingLabel.adjustsFontSizeToFitWidth = YES;
    loadingLabel.textAlignment = NSTextAlignmentCenter;
    loadingLabel.text = @"Loading...";
    [loadingView addSubview:loadingLabel];
    
    [self.view addSubview:loadingView];
    [activityView startAnimating];
}

-(void) viewWillDisappear:(BOOL)animated
{
    if ([self.navigationController.viewControllers indexOfObject:self]==NSNotFound) {
        // The back button was pressed.  We know this is true because self is no longer
        // in the navigation stack.
        
        // If we are tracking we need to send a message to stop tracking.
        if (isTracking) {
            [LocationManager stopTrackingDevicePosition:currentFriend.uid];
        }
    }
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)getDevicePosInbox:(NSDictionary*)dict
{
    NSLog(@"getDevicePosInbox: %@", dict);
    
    // Remove the loading view
    if ([activityView isAnimating]) {
        [activityView stopAnimating];
        [loadingView removeFromSuperview];
    }
    
    // We only need the information stored it the location dictionary, thats within the payload.
    // We set the dict to the dictionary thats in the key PP_KEY_USER_DATA (the payload).
    dict = dict[PP_KEY_USER_DATA];
    // Then we set dict to the dictionary that has the key location.
    dict = dict[@"location"];
    
    // Create a CLLocation object from the information within the location dictionary. This one only with latitude and longitude.
    CLLocation *location = [[CLLocation alloc]initWithLatitude:[dict[@"latitude"]doubleValue] longitude:[dict[@"longitude"]doubleValue]];
    
    // To create one with all the information a CLLocation object can have use this instead.
    //CLLocation *location = [[CLLocation alloc]initWithCoordinate:CLLocationCoordinate2DMake([dict[@"latitude"]doubleValue], [dict[@"longitude"]doubleValue]) altitude:[dict[@"altitude"]doubleValue]  horizontalAccuracy:[dict[@"horizontalAccuracy"]doubleValue] verticalAccuracy:[dict[@"verticalAccuracy"]doubleValue] course:[dict[@"course"]doubleValue] speed:[dict[@"speed"]doubleValue] timestamp:[NSDate dateWithTimeIntervalSince1970:[dict[@"timestamp"]doubleValue]]];
    
    // Set the region of the map
    [self setRegion:location.coordinate];
    
    // Create a point annotation at the location we received and add it to the map.
    point = [[MKPointAnnotation alloc]init];
    point.coordinate = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude);
    point.title = currentFriend.name;
    
    [mapView addAnnotation:point];
}

-(void)trackDevicePosInbox:(NSDictionary*)dict
{
    NSLog(@"trackDevicePosInbox: %@", dict);
    
    // Set isTracking to YES so we know that we need to stop tracking when we leave this view.
    isTracking = YES;
    
    // Remove the loading view.
    if ([activityView isAnimating]) {
        [activityView stopAnimating];
        [loadingView removeFromSuperview];
    }
    
    // We only need the information stored it the location dictionary, thats within the payload.
    // We set the dict to the dictionary thats in the key PP_KEY_USER_DATA (the payload).
    dict = dict[PP_KEY_USER_DATA];
    // Then we set dict to the dictionary that has the key location.
    dict = dict[@"location"];
    
    // Create a CLLocation object from the information within the location dictionary. This one only with latitude and longitude.
    CLLocation *location = [[CLLocation alloc]initWithLatitude:[dict[@"latitude"]doubleValue] longitude:[dict[@"longitude"]doubleValue]];
    
    // To create one with all the information a CLLocation object can have use this instead.
    //CLLocation *location = [[CLLocation alloc]initWithCoordinate:CLLocationCoordinate2DMake([dict[@"latitude"]doubleValue], [dict[@"longitude"]doubleValue]) altitude:[dict[@"altitude"]doubleValue]  horizontalAccuracy:[dict[@"horizontalAccuracy"]doubleValue] verticalAccuracy:[dict[@"verticalAccuracy"]doubleValue] course:[dict[@"course"]doubleValue] speed:[dict[@"speed"]doubleValue] timestamp:[NSDate dateWithTimeIntervalSince1970:[dict[@"timestamp"]doubleValue]]];
    
    // Add it to the array of locations which we use to draw a line on the map.
    [coords addObject:location];
    
    // if it's the first location we set the region.
    if (coords.count == 1) {
        [self setRegion:location.coordinate];
    }
    
    // If we don't have a point annotation we create one.
    // If we already have one we just move it.
    if (!point) {
        point = [[MKPointAnnotation alloc]init];
        point.coordinate = location.coordinate;
        point.title = currentFriend.name;
        
        [mapView addAnnotation:point];
    }else{
        point.coordinate = location.coordinate;
    }
    
    NSLog(@"Coords: %d", coords.count);
    
    // Draw the line on the map that show where the one we are tracking have walked/drived.
    [self drawLine:coords];
}

-(void)setRegion:(CLLocationCoordinate2D)coordinate
{
    // Set the region with 800x800 meters for the span (visible area around the coordinates).
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 800, 800);
    [mapView setRegion:region animated:YES];
}

-(void)drawLine:(NSArray*)path
{
    // Count how many points we have
    NSInteger numberOfSteps = path.count;
    
    // We create an array with as many CLLocationCoordinate2D objects as we have locations in the array called path
    CLLocationCoordinate2D coordinates[numberOfSteps];
    for (NSInteger index = 0; index < numberOfSteps; index++) {
        // We create a new CLLocationCoordinate2D object for each location we have
        CLLocation *location = [path objectAtIndex:index];
        CLLocationCoordinate2D coordinate = location.coordinate;
        
        // Then we add it to the coordinates array
        coordinates[index] = coordinate;
    }
    
    // We create a MKPolyline with the coordinates array and add it to the map.
    MKPolyline *polyLine = [MKPolyline polylineWithCoordinates:coordinates count:numberOfSteps];
    [mapView addOverlay:polyLine];
}

-(MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    // This method renders the polyLine we created in drawLine: to the map
    // We check to see if it's an MKPolyline we have
    if ([overlay isKindOfClass:[MKPolyline class]])
    {
        // We create an MKPolylineRenderer object and set the color and width we want and then return it.
        MKPolylineRenderer *polylineRenderer = [[MKPolylineRenderer alloc]initWithPolyline:(MKPolyline*)overlay];
        polylineRenderer.fillColor = [UIColor greenColor];
        polylineRenderer.strokeColor = [UIColor greenColor];
        polylineRenderer.lineWidth = 4;
        
        return polylineRenderer;
    }
    
    return nil;
}

@end