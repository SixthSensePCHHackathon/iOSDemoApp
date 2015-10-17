//
//  RouteMapViewController.m
//  SixthSense
//
//  Created by Samuel Parkinson on 17/10/2015.
//  Copyright © 2015 mettle-studio. All rights reserved.
//

#import "RouteMapViewController.h"
#import "HFCommander.h"

@interface RouteMapViewController () <MKMapViewDelegate> {
    MKPolyline *_routeOverlay;
    MKRouteStep *step;
    CLLocationCoordinate2D *stepCoordinates;
    CLLocation *nextWaypoint;
    CLLocation *lastWaypoint;
    int iWaypoint;
    double speed;
    double refresh_interval;
    NSTimer *updateTimer;
    BOOL sentCommand;
    __weak IBOutlet UIImageView *currentLocationImage;
    __weak IBOutlet UIButton *playButton;
}
@end


@implementation RouteMapViewController

@synthesize mStartPlacemark;
@synthesize mEndPlacemark;
MKPlacemark *currentPlacemark;
@synthesize _currentRoute;
UIColor *darkBlue;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self plotRouteOnMap];
    
    speed = 20.0;
    refresh_interval = 0.1;
}

- (void)viewDidAppear:(BOOL)animated {
    [[HFCommander sharedCommander] unsetOnRoute];
}

- (void)plotRouteOnMap
{
    darkBlue = [UIColor colorWithRed:0.04313 green:0.2392 blue:0.3725 alpha:1.0];
    self.mapView.delegate = self;
    
    [self.mapView addAnnotation:mEndPlacemark];
    [self.mapView addAnnotation:mStartPlacemark];
    [self.mapView setUserInteractionEnabled:NO];
    
    if(_routeOverlay) {
        [self.mapView removeOverlay:_routeOverlay];
    }
    
    // Update the ivar
    _routeOverlay = self._currentRoute.polyline;
    
    // Add it to the map
    [self.mapView addOverlay:_routeOverlay];
    [self.mapView setVisibleMapRect:[_currentRoute.polyline boundingMapRect] edgePadding:UIEdgeInsetsMake(100.0, 100.0, 100.0, 100.0) animated:NO];
    
    currentPlacemark = [[MKPlacemark alloc] initWithPlacemark:mStartPlacemark];
//    [self.mapView addAnnotation:currentPlacemark];
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:overlay];
    renderer.strokeColor = darkBlue;
    renderer.lineWidth = 4.0;
    return  renderer;
}

- (IBAction)simulateRoute:(id)sender {
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(currentPlacemark.coordinate, 300, 300);
    MKCoordinateRegion adjustedRegion = [self.mapView regionThatFits:viewRegion];
    [self.mapView setRegion:adjustedRegion animated:YES];
    
    [playButton setHidden:YES];
    
    [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(startRoute) userInfo:nil repeats:NO];
}

- (void)startRoute {
    [currentLocationImage setImage:[UIImage imageNamed:@"pin"]];
    [[HFCommander sharedCommander] setOnRoute];
    [self startNextStep];
}

- (void)startNextStep {
    NSLog(@"triggered next step");
    sentCommand = NO;
    
    // get the next step
    if (step == nil) {
        [[HFCommander sharedCommander] setOnRoute];
        step = _currentRoute.steps[0];
    }
    else {
        if ([_currentRoute.steps indexOfObject:step]+1 < _currentRoute.steps.count) {
            [[HFCommander sharedCommander] setOnRoute];
            step = _currentRoute.steps[[_currentRoute.steps indexOfObject:step]+1];
        }
        else {
            [[HFCommander sharedCommander] unsetOnRoute];
            return;
        }
    }
    
    stepCoordinates = nil;
    stepCoordinates = malloc(step.polyline.pointCount * sizeof(CLLocationCoordinate2D));
    [step.polyline getCoordinates:stepCoordinates range:NSMakeRange(0, step.polyline.pointCount)];
    
    lastWaypoint = [[CLLocation alloc] initWithLatitude:stepCoordinates[step.polyline.pointCount-1].latitude
                                              longitude:stepCoordinates[step.polyline.pointCount-1].longitude];
    iWaypoint = 0;
    [self moveToNextWaypoint];
}

- (void)moveToNextWaypoint {
    nextWaypoint = [[CLLocation alloc] initWithLatitude:stepCoordinates[iWaypoint].latitude longitude:stepCoordinates[iWaypoint].longitude];
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:refresh_interval target:self selector:@selector(nextFrame) userInfo:nil repeats:YES];
    iWaypoint++;
}

- (void)nextFrame {
    CLLocation *currentLocation = [[CLLocation alloc] initWithLatitude:currentPlacemark.coordinate.latitude longitude:currentPlacemark.coordinate.longitude];
    CGFloat distanceToNext = [nextWaypoint distanceFromLocation:currentLocation];
    CGFloat distanceToEnd = [lastWaypoint distanceFromLocation:currentLocation];
    
    double bearing = [self bearingFromCoordinate:currentPlacemark.coordinate toCoordinate:nextWaypoint.coordinate];
    double distance = speed*refresh_interval;
    
//    NSLog(@"d to next:%f, d to end:%f, distance:%f",distanceToNext, distanceToEnd, distance);
    
    if (distanceToEnd == 0) {
        [updateTimer invalidate];
        updateTimer = nil;
        
        if ([step.instructions containsString:@"left"] || [step.instructions containsString:@"right"]) {
            NSLog(@"ready to trigger next step");
            [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(startNextStep) userInfo:nil repeats:NO];
        }
        else {
            NSLog(@"immediately triggering next step");
            [self startNextStep];
        }
        return;
    }
    
    if (distanceToEnd < 1.5*speed) {
        if (!sentCommand) {
            sentCommand = YES;
            if ([step.instructions containsString:@"left"]) {
                [[HFCommander sharedCommander] unsetOnRoute];
                [[HFCommander sharedCommander] sendTurnLeft];
            }
            if ([step.instructions containsString:@"right"]) {
                [[HFCommander sharedCommander] unsetOnRoute];
                [[HFCommander sharedCommander] sendTurnRight];
            }
            NSLog(@"%@",step.instructions);
        }
    }
    
    if (distanceToNext == 0) {
        [updateTimer invalidate];
        updateTimer = nil;
        [self moveToNextWaypoint];
        return;
    }
    
    CLLocationCoordinate2D newCoordinate;
    if (distance < distanceToNext)
        newCoordinate = [self coordinateFromCoord:currentPlacemark.coordinate atDistanceKm:distance/1000. atBearingDegrees:bearing];
    else
        newCoordinate = nextWaypoint.coordinate;
    
//    NSLog(@"next: %f %f",nextWaypoint.coordinate.latitude, nextWaypoint.coordinate.longitude);
//    NSLog(@"current: %f %f",newCoordinate.latitude, newCoordinate.longitude);
    
//    [self.mapView removeAnnotation:currentPlacemark];
    currentPlacemark = [[MKPlacemark alloc] initWithCoordinate:newCoordinate addressDictionary:nil];
//    [self.mapView addAnnotation:currentPlacemark];
    
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(currentPlacemark.coordinate, 300, 300);
    MKCoordinateRegion adjustedRegion = [self.mapView regionThatFits:viewRegion];
    [self.mapView setRegion:adjustedRegion animated:YES];
}

#define degreesToRadians(x) (M_PI * x / 180.0)
#define radiandsToDegrees(x) (x * 180.0 / M_PI)
- (float)bearingFromCoordinate:(CLLocationCoordinate2D)fromLoc toCoordinate:(CLLocationCoordinate2D)toLoc
{
    float fLat = degreesToRadians(fromLoc.latitude);
    float fLng = degreesToRadians(fromLoc.longitude);
    float tLat = degreesToRadians(toLoc.latitude);
    float tLng = degreesToRadians(toLoc.longitude);
    
    float degree = radiandsToDegrees(atan2(sin(tLng-fLng)*cos(tLat), cos(fLat)*sin(tLat)-sin(fLat)*cos(tLat)*cos(tLng-fLng)));
    
    if (degree >= 0) {
        return degree;
    } else {
        return 360+degree;
    }
}

- (CLLocationCoordinate2D)coordinateFromCoord:(CLLocationCoordinate2D)fromCoord
                                 atDistanceKm:(double)distanceKm
                             atBearingDegrees:(double)bearingDegrees
{
    double distanceRadians = distanceKm / 6371.0;
    //6,371 = Earth's radius in km
    double bearingRadians = degreesToRadians(bearingDegrees);
    double fromLatRadians = degreesToRadians(fromCoord.latitude);
    double fromLonRadians = degreesToRadians(fromCoord.longitude);
    
    double toLatRadians = asin( sin(fromLatRadians) * cos(distanceRadians)
                               + cos(fromLatRadians) * sin(distanceRadians) * cos(bearingRadians) );
    
    double toLonRadians = fromLonRadians + atan2(sin(bearingRadians)
                                                 * sin(distanceRadians) * cos(fromLatRadians), cos(distanceRadians)
                                                 - sin(fromLatRadians) * sin(toLatRadians));
    
    // adjust toLonRadians to be in the range -180 to +180...
    toLonRadians = fmod((toLonRadians + 3*M_PI), (2*M_PI)) - M_PI;
    
    CLLocationCoordinate2D result;
    result.latitude = radiandsToDegrees(toLatRadians);
    result.longitude = radiandsToDegrees(toLonRadians);
    return result;
}

@end
